## Representação VISUAL de um chunk. Não guarda regra de jogo.
##
## Cada nível usado recebe uma camada Ground (superfícies) e, quando necessário,
## uma camada Depth (faces verticais).
##
## [b]Ordenação de profundidade[/b]: superfícies, faces, estruturas, vegetação e
## atores dividem UM ÚNICO espaço de Y-Sort, todos em z 0. Quem decide quem fica
## na frente é sempre o pivô (`y_sort_origin`), nunca a classe da camada. A face
## usa como pivô a borda frontal do losango definida no TileSet.
class_name ChunkView
extends Node2D

@export var height_layer_scene: PackedScene
## Nó vazio usado como âncora de ordenação de árvores e estruturas.
@export var prop_anchor_scene: PackedScene
@export var catalog: TileCatalog
@export var settings: WorldSettings

@onready var ground_layers: Node2D = %GroundLayers
@onready var depth_layers: Node2D = %DepthLayers
@onready var overlay_layers: Node2D = %OverlayLayers
@onready var structures_root: Node2D = %Structures
@onready var decorations_root: Node2D = %Decorations

var chunk_coord: Vector2i = Vector2i.ZERO

var _ground_layers: Dictionary = {}
var _depth_layers: Dictionary = {}
var _base_tints: Dictionary = {}
var _visibility_tints: Dictionary = {}
var _owned_depth_nodes: Array[Node] = []
var _owned_ground_cells: Dictionary = {}
var _owned_depth_cells: Dictionary = {}
var _group_cache: Dictionary = {}
var _uses_shared_layers: bool = false
var _iso: IsoCoordinateSystem
var _world_data: WorldData
var _reference_level: int = 0


func build(
	chunk: ChunkData,
	p_settings: WorldSettings,
	p_catalog: TileCatalog,
	p_ground_root: Node2D = null,
	p_depth_root: Node2D = null,
	p_overlay_root: Node2D = null,
	p_world_data: WorldData = null,
	p_ground_layer_registry: Variant = null,
	p_depth_layer_registry: Variant = null
) -> void:
	_clear()
	settings = p_settings
	catalog = p_catalog
	chunk_coord = chunk.coord
	_iso = IsoCoordinateSystem.from_settings(settings)
	_world_data = p_world_data
	if p_ground_root != null:
		ground_layers = p_ground_root
	if p_depth_root != null:
		depth_layers = p_depth_root
		structures_root = p_depth_root
		decorations_root = p_depth_root
	if p_overlay_root != null:
		overlay_layers = p_overlay_root
	_uses_shared_layers = p_ground_layer_registry != null
	_ground_layers = p_ground_layer_registry if _uses_shared_layers else {}
	_depth_layers = p_depth_layer_registry if _uses_shared_layers else {}
	_paint_ground(chunk)


func _exit_tree() -> void:
	# As camadas visuais podem estar nas raízes globais, fora da árvore deste
	# ChunkView. Portanto o unload precisa libertá-las explicitamente.
	_clear()


func _clear() -> void:
	_erase_owned_cells(_ground_layers, _owned_ground_cells)
	_erase_owned_cells(_depth_layers, _owned_depth_cells)
	if not _uses_shared_layers:
		for layer: TileMapLayer in _ground_layers.values():
			layer.queue_free()
		for layer: TileMapLayer in _depth_layers.values():
			layer.queue_free()
		_ground_layers.clear()
		_depth_layers.clear()
	for owned: Node in _owned_depth_nodes:
		if is_instance_valid(owned):
			owned.queue_free()
	_owned_depth_nodes.clear()
	_base_tints.clear()
	_visibility_tints.clear()
	_group_cache.clear()


func _erase_owned_cells(registry: Dictionary, owned: Dictionary) -> void:
	for level: int in owned:
		var layer := registry.get(level, null) as TileMapLayer
		if layer == null:
			continue
		for cell_coord: Vector2i in owned[level]:
			layer.erase_cell(cell_coord)
	owned.clear()


func _remember_cell(owned: Dictionary, level: int, cell_coord: Vector2i) -> void:
	if not owned.has(level):
		var new_cells: Array[Vector2i] = []
		owned[level] = new_cells
	var cells: Array[Vector2i] = owned[level]
	if not cells.has(cell_coord):
		cells.append(cell_coord)


func _paint_ground(chunk: ChunkData) -> void:
	var size := chunk.size
	for y in size:
		for x in size:
			var cell := chunk.get_cell(Vector2i(x, y))
			if cell == null:
				continue
			var cell_coord := Vector2i(cell.world_xy.x, cell.world_xy.y)

			# 1) superfície top-only. Não precisa de tratamento especial quando o
			# vizinho de trás é mais alto: a face dele fica meio tile ATRÁS no
			# Y-Sort, então esta superfície já a recobre naturalmente.
			#
			# Numa fronteira de bioma o id desenhado é o da peça de transição.
			# Ele é VISUAL: `cell.ground_id` continua sendo o dado, e é ele que
			# gameplay, IA e save enxergam.
			var ground_visual := _ground_visual_for(chunk, cell)
			# A estrutura fornece a superfície destas células. Não desenhar o
			# chão do mundo evita que ele vença o Y-Sort e apareça entre as
			# tábuas/placas do piso. O dado e as faces continuam disponíveis.
			if not cell.ground_surface_hidden:
				_set_ground_tile(cell.height, cell_coord, ground_visual)

			# 2) faces independentes. Cada lado consulta seu próprio vizinho;
			# portanto uma borda reta não ganha uma lateral fantasma no outro lado.
			_paint_exposed_faces(chunk, cell, cell_coord, ground_visual)

			# 3) superfície de água
			if cell.is_liquid() and not cell.ground_surface_hidden:
				_set_ground_tile(settings.sea_level, cell_coord, settings.water_ground_id)


## Vizinhos frontais na projeção: +Y expõe a face esquerda; +X, a direita.
func _paint_exposed_faces(
	chunk: ChunkData,
	cell: WorldCell,
	cell_coord: Vector2i,
	ground_visual: StringName
) -> void:
	var left_height := _front_neighbor_height(chunk, cell, Vector2i(0, 1))
	var right_height := _front_neighbor_height(chunk, cell, Vector2i(1, 0))
	var lowest := mini(left_height, right_height)
	var bottom := maxi(lowest, cell.height - settings.max_wall_depth)
	for level in range(cell.height, bottom, -1):
		var show_left := level > left_height
		var show_right := level > right_height
		if not show_left and not show_right:
			continue
		var mask := TileCatalog.FaceMask.BOTH
		if show_left and not show_right:
			mask = TileCatalog.FaceMask.LEFT
		elif show_right and not show_left:
			mask = TileCatalog.FaceMask.RIGHT
		# O nível do topo usa a MESMA peça da superfície: numa transição, a
		# lateral tem que continuar a borda desenhada em cima dela.
		var tile_id: StringName = ground_visual if level == cell.height else cell.wall_id
		_set_depth_face(level, cell_coord, tile_id, mask)


func _front_neighbor_height(chunk: ChunkData, cell: WorldCell, offset: Vector2i) -> int:
	var neighbor := chunk.get_cell_world(cell.world_xy + offset)
	if neighbor != null:
		return neighbor.height
	# Consulta coordenadas globais em vez de inventar um degrau na borda do
	# chunk. WorldData usa o chunk carregado ou o sampler procedural determinista.
	if _world_data != null:
		return _world_data.height_at(cell.world_xy + offset)
	return cell.height


func _set_ground_tile(level: int, cell_coord: Vector2i, ground_id: StringName) -> void:
	if catalog == null:
		return
	var entry := catalog.find(ground_id)
	if entry == null:
		return
	# Peça de transição nunca espelha: o espelho trocaria esquerda por direita e
	# jogaria a borda do bioma para o lado errado da célula.
	var mirrored := not entry.directional and _mirrors_top(cell_coord)
	_ground_layer_for(level).set_cell(
		cell_coord,
		entry.source_id,
		entry.atlas_coords,
		catalog.alternative_for(level, mirrored)
	)
	_remember_cell(_owned_ground_cells, level, cell_coord)


## Peça de fronteira para esta célula, ou o chão dela quando não há fronteira.
##
## Só olha os 4 lados; as diagonais entram apenas quando nenhum lado difere,
## para a pontinha do canto não ficar em degrau. É consulta de leitura: nada
## aqui escreve na [WorldCell].
func _ground_visual_for(chunk: ChunkData, cell: WorldCell) -> StringName:
	# Chão assentado por uma construção não recebe peça de fronteira: a peça de
	# transição é desenhada com grama e ela transborda o losango — voltaria a
	# aparecer por cima do piso da célula de trás.
	if cell.ground_locked:
		return cell.ground_id
	if catalog == null or catalog.transitions == null or not catalog.transitions.enabled:
		return cell.ground_id
	var transitions := catalog.transitions
	var grupo := transitions.grupo_de(cell.biome_id)
	if grupo == &"":
		return cell.ground_id

	var lados: Array[StringName] = []
	for offset: Vector2i in BiomeTransitionCatalog.LADOS:
		lados.append(_neighbor_group(chunk, cell.world_xy + offset))
	var diagonais: Array[StringName] = []
	for offset: Vector2i in BiomeTransitionCatalog.DIAGONAIS:
		diagonais.append(_neighbor_group(chunk, cell.world_xy + offset))

	var tile := transitions.resolve(grupo, lados, diagonais)
	if tile == &"" or not catalog.has(tile):
		return cell.ground_id
	return tile


## Grupo de transição do vizinho. O cache existe porque cada célula consulta 8
## vizinhos e cada vizinho é consultado por até 8 células: sem ele, a borda de
## um chunk chamaria o amostrador milhares de vezes por carregamento.
func _neighbor_group(chunk: ChunkData, world_xy: Vector2i) -> StringName:
	if _group_cache.has(world_xy):
		return _group_cache[world_xy]
	var biome_id: StringName = &""
	var neighbor := chunk.get_cell_world(world_xy)
	if neighbor != null:
		biome_id = neighbor.biome_id
	elif _world_data != null:
		biome_id = _world_data.biome_at(world_xy)
	var grupo := catalog.transitions.grupo_de(biome_id)
	_group_cache[world_xy] = grupo
	return grupo


## Sorteio ESTÁVEL por célula: recarregar o chunk não pode mudar o desenho.
##
## Não depende da semente do mundo de propósito — espelhar é decoração, não
## conteúdo; assim dois mundos com a mesma semente continuam idênticos e o save
## não precisa guardar nada disso.
func _mirrors_top(cell_coord: Vector2i) -> bool:
	return WorldRandom.value_01(0, cell_coord, 1) < 0.5


func _set_depth_face(
	level: int,
	cell_coord: Vector2i,
	ground_id: StringName,
	mask: TileCatalog.FaceMask
) -> void:
	if catalog == null:
		return
	var entry := catalog.find(ground_id)
	if entry == null:
		return
	_depth_layer_for(level).set_cell(
		cell_coord,
		TileCatalog.DEPTH_FACE_SOURCE_ID,
		catalog.face_atlas_coords(entry, mask),
		catalog.alternative_for(level)
	)
	_remember_cell(_owned_depth_cells, level, cell_coord)


## Cria uma camada de altura.
##
## [b]Regra inegociável[/b]: TODAS as camadas nascem com [code]z_index = 0[/code]
## e [code]y_sort_enabled = true[/code], e as RAÍZES também. No Godot o Z-Index é
## resolvido ANTES do Y-Sort: basta uma classe de camada em outro Z para ela
## deixar de disputar profundidade com as demais e passar a ser desenhada sempre
## por cima. Foi exatamente isso que recortava a grama — as faces (Depth) em um
## Z acima das superfícies (Ground) apareciam furando o tile da frente.
func _create_layer(level: int, parent: Node2D, prefix: String) -> TileMapLayer:
	var layer: TileMapLayer = height_layer_scene.instantiate()
	layer.name = "%s_%d" % [prefix, level]
	layer.tile_set = catalog.tile_set
	layer.position = Vector2.ZERO
	layer.z_index = 0
	layer.y_sort_enabled = true
	# A compensação de cada nível pertence ao TileData.y_sort_origin. O layer
	# permanece neutro para não criar uma barreira única entre seus tiles.
	layer.y_sort_origin = 0
	layer.collision_enabled = false
	layer.navigation_enabled = false
	parent.add_child(layer)
	layer.set_meta(&"world_render_class", prefix)
	layer.set_meta(&"world_level", level)
	_sort_global_layers(parent, prefix)
	return layer


func _sort_global_layers(parent: Node2D, prefix: String) -> void:
	# O Y-Sort decide a profundidade entre tiles; a ordem dos nós só resolve
	# empates (mesma célula, níveis diferentes). Ainda assim precisa ser
	# estável: não pode depender de qual worker terminou primeiro.
	var matching: Array[Node] = []
	for child in parent.get_children():
		if child.get_meta(&"world_render_class", "") == prefix:
			matching.append(child)
	matching.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta(&"world_level", 0)) < int(b.get_meta(&"world_level", 0))
	)
	for child in matching:
		parent.move_child(child, parent.get_child_count() - 1)


func _ground_layer_for(level: int) -> TileMapLayer:
	if _ground_layers.has(level):
		return _ground_layers[level]
	var layer := _create_layer(level, ground_layers, "Ground")
	_ground_layers[level] = layer
	_apply_tint(level)
	return layer


func _depth_layer_for(level: int) -> TileMapLayer:
	if _depth_layers.has(level):
		return _depth_layers[level]
	var layer := _create_layer(level, depth_layers, "Depth")
	_depth_layers[level] = layer
	_apply_tint(level)
	return layer


func layer_levels() -> Array:
	var levels: Dictionary = {}
	for level in _owned_ground_cells:
		levels[level] = true
	for level in _owned_depth_cells:
		levels[level] = true
	return levels.keys()


func layer_at(level: int) -> TileMapLayer:
	return _ground_layers.get(level, null)


func depth_layer_at(level: int) -> TileMapLayer:
	return _depth_layers.get(level, null)


## Instancia uma decoração já decidida pelos dados.
func add_decoration(placement: DecorationPlacement) -> Node2D:
	if placement.definition == null or placement.definition.scene == null:
		return null
	var instance: Node2D = placement.definition.scene.instantiate()
	instance.scale = Vector2(
		-placement.scale_factor if placement.flip_h else placement.scale_factor,
		placement.scale_factor
	)
	instance.set_meta(&"object_id", placement.object_id)
	instance.set_meta(&"world_position", placement.world_pos)
	_anchor_prop(instance, placement.world_pos, decorations_root)
	return instance


## Instancia uma estrutura já planejada.
func add_structure(placement: StructurePlacement) -> Node2D:
	if placement.definition == null or placement.definition.scene == null:
		return null
	var instance: Node2D = placement.definition.scene.instantiate()
	var root := instance as StructureRoot
	if root != null:
		root.setup(placement)
	var uses_tilemap_layers := not instance.find_children(
		"*", "TileMapLayer", true, false
	).is_empty()
	_anchor_prop(
		instance,
		Vector3i(placement.origin_xy.x, placement.origin_xy.y, placement.foundation_height),
		structures_root,
		uses_tilemap_layers
	)
	return instance


## Pendura um objeto do mundo em uma âncora posicionada no plano da grade.
##
## A âncora carrega a posição PLANA da célula (é ela que entra no Y-Sort) e o
## objeto recebe só o deslocamento vertical da altura. Sem isso, um objeto em
## cima de um morro seria ordenado como se estivesse mais ao fundo.
##
## Estruturas feitas com TileMapLayer usam [param expose_y_sorted_children].
## Nesse modo, cada tile participa do Y-Sort global em vez de a casa inteira ser
## agrupada pela célula de origem. O y_sort_origin das camadas compensa o
## deslocamento visual da fundação para continuar ordenando no plano lógico.
func _anchor_prop(
	prop: Node2D,
	world_pos: Vector3i,
	parent: Node2D,
	expose_y_sorted_children: bool = false
) -> void:
	var cell := Vector2i(world_pos.x, world_pos.y)
	var anchor: Node2D = (
		prop_anchor_scene.instantiate() if prop_anchor_scene != null else Node2D.new()
	)
	anchor.name = "Anchor_%d_%d" % [cell.x, cell.y]
	anchor.y_sort_enabled = expose_y_sorted_children
	anchor.position = _iso.cell_to_local(cell) + Vector2(0.0, _iso.prop_sort_bias())
	parent.add_child(anchor)
	_owned_depth_nodes.append(anchor)
	anchor.add_child(prop)
	prop.position = Vector2(0.0, -float(world_pos.z * settings.height_pixels) - _iso.prop_sort_bias())
	prop.z_index = 0
	if expose_y_sorted_children:
		var height_sort_compensation := world_pos.z * settings.height_pixels
		for descendant: Node in prop.find_children("*", "TileMapLayer", true, false):
			var layer := descendant as TileMapLayer
			if layer != null:
				layer.y_sort_origin += height_sort_compensation
		# Mobília pintada é promovida para uma âncora Node2D direta. Deslocamos
		# somente o pivô de ordenação e aplicamos o inverso no conteúdo, mantendo
		# o sprite exatamente no mesmo pixel enquanto ele disputa o Y-Sort no
		# plano lógico da fundação.
		for descendant: Node in prop.find_children("*", "Node2D", true, false):
			var furniture_anchor := descendant as Node2D
			if (
				furniture_anchor == null
				or not furniture_anchor.get_meta(
					StructureRoot.FURNITURE_SORT_ANCHOR_META, false
				)
			):
				continue
			furniture_anchor.position.y += height_sort_compensation
			for child: Node in furniture_anchor.get_children():
				var visual_root := child as Node2D
				if visual_root != null:
					visual_root.position.y -= height_sort_compensation


## Usado pelo [HeightVisibilityManager]. Não altera dados, só aparência.
##
## A cor recebida é MULTIPLICADA pelo sombreamento de altura da camada, para os
## dois sistemas conviverem sem um apagar o outro.
func apply_level_modulation(level: int, color: Color, layer_visible: bool) -> void:
	if not _ground_layers.has(level) and not _depth_layers.has(level):
		return
	_visibility_tints[level] = color
	for layer: TileMapLayer in [
		_ground_layers.get(level, null),
		_depth_layers.get(level, null)
	]:
		if layer != null:
			layer.visible = layer_visible
	_apply_tint(level)


## Nível de referência do sombreamento (normalmente onde o jogador está).
func set_reference_level(level: int) -> void:
	if _reference_level == level:
		return
	_reference_level = level
	for existing_level: int in layer_levels():
		_apply_tint(existing_level)


func reference_level() -> int:
	return _reference_level


func _apply_tint(level: int) -> void:
	if settings == null:
		return
	var base := settings.tint_for_level(level, _reference_level)
	_base_tints[level] = base
	var overlay: Color = _visibility_tints.get(level, Color.WHITE)
	var tint := Color(
		base.r * overlay.r, base.g * overlay.g, base.b * overlay.b, base.a * overlay.a
	)
	for layer: TileMapLayer in [
		_ground_layers.get(level, null),
		_depth_layers.get(level, null)
	]:
		if layer != null:
			layer.modulate = tint

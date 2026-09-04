## Raiz de uma cena de estrutura.
##
## Coloque este script na raiz do `.tscn` da construção e ligue o
## [member definition]. Com [member draw_footprint] ligado, o editor desenha o
## losango do footprint para você posicionar paredes e móveis com precisão.
@tool
class_name StructureRoot
extends Node2D

signal vision_portal_changed(portal_id: StringName, is_open: bool)

@export var definition: StructureDefinition:
	set(value):
		definition = value
		queue_redraw()
		update_configuration_warnings()

## Usado pelo gizmo quando [member definition] está vazio (evita referência
## circular entre a cena e o `.tres`).
@export var footprint_preview: Vector2i = Vector2i(4, 4):
	set(value):
		footprint_preview = value
		queue_redraw()

@export var draw_footprint_gizmo: bool = true:
	set(value):
		draw_footprint_gizmo = value
		queue_redraw()

@export var gizmo_color: Color = Color(0.2, 1.0, 0.6, 0.55):
	set(value):
		gizmo_color = value
		queue_redraw()

@export_group("Projeção (só para o gizmo)")
@export var tile_size: Vector2i = Vector2i(128, 64):
	set(value):
		tile_size = value
		queue_redraw()

var _placement: StructurePlacement
var _wall_cells: Array[Dictionary] = []
var _active_door_animations: Dictionary = {}
var _active_window_animations: Dictionary = {}
var _roof_layer: TileMapLayer
var _roof_interior_polygon := PackedVector2Array()
var _roof_actors_inside: Dictionary = {}
var _vision_controlled := false
var _automatic_wall_rows: Dictionary = {}

const WALL_VISUAL_CATEGORIES: Array[String] = ["parede", "janela", "porta"]
const DOOR_STRUCTURE_GROUP: StringName = &"door_structures"
const DOOR_FRAME_COUNT := 9
const DOOR_FRAME_SECONDS := 0.075
const DOOR_ANIMATION_COLUMN_BASE := 16
const DOOR_DIRECTIONS: Array[String] = ["ne", "nw", "se", "sw"]
const WINDOW_FRAME_COUNT := 5
const WINDOW_FRAME_SECONDS := 0.09
const WINDOW_BASE_PART_COUNT := 8
const WINDOW_OPEN_COLUMN_BASE := WINDOW_BASE_PART_COUNT
const WINDOW_ANIMATION_COLUMN_BASE := WINDOW_BASE_PART_COUNT * 2
const WINDOW_BASE_PARTS: Array[String] = [
	"janela_ne", "janela_nw", "janela_se", "janela_sw",
	"janela_vazada_ne", "janela_vazada_nw", "janela_vazada_se", "janela_vazada_sw",
]
const FURNITURE_SORT_ANCHOR_META: StringName = &"structure_furniture_sort_anchor"
const STRUCTURE_GROUP: StringName = &"structure_roots"
const STRUCTURE_VISION_BAKER := preload(
	"res://world_generation/visibility/structure_vision_baker.gd"
)

@export_category("Estado inicial")
## Portas autoradas abertas ou em um quadro de animação são normalizadas para
## o tile fechado quando a estrutura entra no mundo.
@export var doors_start_closed: bool = true
## Janelas autoradas abertas ou em um quadro de animação também iniciam fechadas.
@export var windows_start_closed: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(DOOR_STRUCTURE_GROUP)
	add_to_group(STRUCTURE_GROUP)
	_sync_painted_marker_cells()
	_sync_painted_marker_cells.call_deferred()
	if doors_start_closed:
		_close_doors_at_start()
	if windows_start_closed:
		_close_windows_at_start()
	_promote_scene_furniture()
	cache_wall_cells()
	_setup_roof_visibility()
	var manager := get_node_or_null(^"/root/WallVisibilityManager")
	if manager != null:
		manager.register_target(self)


## Scene tiles de marcador são posicionados pela TileMapLayer. Converte essa
## posição autorada para a célula lógica relativa ao footprint da estrutura.
func _sync_painted_marker_cells() -> void:
	for node: Node in find_children("*", "StructureMarker", true, false):
		var marker := node as StructureMarker
		if marker == null or marker.marker_type != StructureMarker.MarkerType.PLAYER_SPAWN:
			continue
		var marker_layer := marker.get_parent() as TileMapLayer
		if marker_layer != null:
			marker.cell_offset = marker_layer.local_to_map(marker.position)


## Retorna diretamente as células pintadas na camada dedicada. O gameplay não
## depende do frame em que o Godot materializa os scene tiles para o editor.
func player_spawn_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var spawn_layer := get_node_or_null(^"SpawnPlayer") as TileMapLayer
	if spawn_layer == null or spawn_layer.tile_set == null:
		return result
	for cell: Vector2i in spawn_layer.get_used_cells():
		var source_id := spawn_layer.get_cell_source_id(cell)
		var source := spawn_layer.tile_set.get_source(source_id)
		if (
			source is TileSetScenesCollectionSource
			and source.resource_name == "Marcadores_Spawn_Player"
		):
			result.append(cell)
	return result


## O atlas mantém tiles abertos para a animação e para pré-visualização, mas o
## estado inicial de jogo é sempre o tile fechado da mesma direção/ambiente.
func _close_doors_at_start() -> void:
	for descendant: Node in find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or data.get_custom_data(&"categoria") != "porta":
				continue
			var state: String = data.get_custom_data(&"estado_porta")
			if state in ["fechada", "vao"]:
				continue
			var direction: String = data.get_custom_data(&"direcao")
			var direction_index := DOOR_DIRECTIONS.find(direction)
			if direction_index < 0:
				continue
			var source_id := layer.get_cell_source_id(cell)
			var current_coords := layer.get_cell_atlas_coords(cell)
			var closed_coords := Vector2i(direction_index * 3 + 1, current_coords.y)
			var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if source == null or not source.has_tile(closed_coords):
				continue
			layer.set_cell(
				cell, source_id, closed_coords, layer.get_cell_alternative_tile(cell)
			)


func _close_windows_at_start() -> void:
	for descendant: Node in find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or data.get_custom_data(&"categoria") != "janela":
				continue
			if data.get_custom_data(&"estado_janela") == "fechada":
				continue
			var base_index := WINDOW_BASE_PARTS.find(data.get_custom_data(&"peca"))
			if base_index < 0:
				continue
			var source_id := layer.get_cell_source_id(cell)
			var current_coords := layer.get_cell_atlas_coords(cell)
			var closed_coords := Vector2i(base_index, current_coords.y)
			var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if source == null or not source.has_tile(closed_coords):
				continue
			layer.set_cell(
				cell, source_id, closed_coords, layer.get_cell_alternative_tile(cell)
			)


## Tiles de cena funcionam como pincéis no editor, mas seus CanvasItems ficam
## confinados à TileMapLayer e não disputam o Y-Sort global corretamente quando
## a fundação da estrutura recebe compensação de altura. Em runtime, recriamos
## cada cena pintada sob uma âncora direta da estrutura. A célula continua sendo
## a fonte autoral; visual, colisões, sinais e scripts vêm da PackedScene original.
func _promote_scene_furniture() -> void:
	var furniture_layer := get_node_or_null(^"Mobilia") as TileMapLayer
	if furniture_layer == null or furniture_layer.tile_set == null:
		return
	var painted_cells := furniture_layer.get_used_cells()
	if painted_cells.is_empty():
		return

	var promoted_count := 0
	var promoted_cells: Array[Vector2i] = []
	for cell: Vector2i in painted_cells:
		var source_id := furniture_layer.get_cell_source_id(cell)
		var source := furniture_layer.tile_set.get_source(source_id) as TileSetScenesCollectionSource
		if source == null:
			continue
		# Em TileSetScenesCollectionSource o ID da cena ocupa o campo
		# alternative_tile; atlas_coords permanece (0,0) em todas as orientações.
		var scene_id := furniture_layer.get_cell_alternative_tile(cell)
		if not source.has_scene_tile_id(scene_id):
			continue
		var packed := source.get_scene_tile_scene(scene_id)
		if packed == null:
			continue
		var furniture := packed.instantiate() as Node2D
		if furniture == null:
			continue

		var authored_root_offset := furniture.position
		var sort_anchor := Node2D.new()
		sort_anchor.name = "Mobilia_%d_%d" % [cell.x, cell.y]
		sort_anchor.position = (
			furniture_layer.position
			+ furniture_layer.map_to_local(cell)
			+ authored_root_offset
		)
		sort_anchor.set_meta(FURNITURE_SORT_ANCHOR_META, true)
		sort_anchor.set_meta(&"tile_cell", cell)
		sort_anchor.set_meta(&"tile_source_id", source_id)
		sort_anchor.set_meta(&"scene_tile_id", scene_id)
		add_child(sort_anchor)
		furniture.position = Vector2.ZERO
		sort_anchor.add_child(furniture)
		promoted_count += 1
		promoted_cells.append(cell)

	# Remove somente as instâncias automáticas desta cópia runtime. O PackedScene
	# autorado e suas células permanecem intactos no editor e no arquivo .tscn.
	for cell: Vector2i in promoted_cells:
		furniture_layer.erase_cell(cell)
	if promoted_count == 0:
		push_warning("A camada Mobilia possui células, mas nenhuma cena pôde ser instanciada.")


## Configura em runtime a área que representa o interior pintado da casa.
## Estruturas sem uma camada `Telhado` simplesmente não usam esta mecânica.
func _setup_roof_visibility() -> void:
	_roof_layer = get_node_or_null(^"Telhado") as TileMapLayer
	if _roof_layer == null:
		return
	_roof_layer.z_index = 10
	var floor_layer := get_node_or_null(^"Piso") as TileMapLayer
	if floor_layer == null or floor_layer.get_used_cells().is_empty():
		push_warning("Estrutura com Telhado precisa de uma camada Piso pintada.")
		return
	var polygon := _interior_polygon_for(floor_layer)
	if polygon.size() < 3:
		return
	_roof_interior_polygon = polygon
	var detector := Area2D.new()
	detector.name = "InteriorDetector"
	detector.collision_layer = 0
	detector.collision_mask = 2 # Player
	detector.monitorable = false
	detector.monitoring = true
	add_child(detector)
	var collision := CollisionPolygon2D.new()
	collision.name = "InteriorShape"
	collision.polygon = polygon
	detector.add_child(collision)
	detector.body_entered.connect(_on_roof_body_entered)
	detector.body_exited.connect(_on_roof_body_exited)
	_set_roof_visible(true)


func _interior_polygon_for(floor_layer: TileMapLayer) -> PackedVector2Array:
	var used := floor_layer.get_used_rect()
	if not used.has_area() or floor_layer.tile_set == null:
		return PackedVector2Array()
	var first := used.position
	var last := used.end - Vector2i.ONE
	var half_tile := Vector2(floor_layer.tile_set.tile_size) * 0.5
	return PackedVector2Array([
		floor_layer.position + floor_layer.map_to_local(first) + Vector2(0.0, -half_tile.y),
		floor_layer.position + floor_layer.map_to_local(Vector2i(last.x, first.y))
			+ Vector2(half_tile.x, 0.0),
		floor_layer.position + floor_layer.map_to_local(last) + Vector2(0.0, half_tile.y),
		floor_layer.position + floor_layer.map_to_local(Vector2i(first.x, last.y))
			+ Vector2(-half_tile.x, 0.0),
	])


func _on_roof_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"depth_actor"):
		return
	_roof_actors_inside[body.get_instance_id()] = body
	if not _vision_controlled:
		_set_roof_visible(false)


func _on_roof_body_exited(body: Node2D) -> void:
	var actor_id := body.get_instance_id()
	if not _roof_actors_inside.has(actor_id):
		return
	# Dormir suspende a collision_layer do Player. Isso emite body_exited mesmo
	# com ele ainda dentro da planta e não pode fazer o telhado reaparecer.
	_settle_roof_body_exit.call_deferred(actor_id, body)


func _settle_roof_body_exit(actor_id: int, body: Node2D) -> void:
	if (
		is_instance_valid(body)
		and not _roof_interior_polygon.is_empty()
		and Geometry2D.is_point_in_polygon(to_local(body.global_position), _roof_interior_polygon)
	):
		_roof_actors_inside[actor_id] = body
		_set_roof_visible(false)
		return
	_roof_actors_inside.erase(actor_id)
	if _roof_actors_inside.is_empty():
		_set_roof_visible(true)


func _set_roof_visible(should_be_visible: bool) -> void:
	if is_instance_valid(_roof_layer):
		_roof_layer.visible = true if _vision_controlled else should_be_visible


func is_roof_visible() -> bool:
	return _roof_layer == null or _roof_layer.visible


## Quando o presenter de visão assume a estrutura, o detector legado deixa de
## esconder o telhado inteiro. A máscara local passa a controlar somente os
## pixels das células internas realmente visíveis.
func set_vision_controlled(enabled: bool) -> void:
	_vision_controlled = enabled
	if enabled:
		_set_roof_visible(true)
	elif not _roof_actors_inside.is_empty():
		_set_roof_visible(false)
	else:
		_set_roof_visible(true)


func roof_layer() -> TileMapLayer:
	return _roof_layer


func interior_floor_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var floor_layer := get_node_or_null(^"Piso") as TileMapLayer
	if floor_layer != null:
		result.assign(floor_layer.get_used_cells())
	return result


## Snapshot lógico autocontido consumido pelo VisionSystem. A estrutura expõe
## o contrato, mas toda a extração semântica permanece isolada no baker.
func vision_snapshot() -> StructureVisionSnapshot:
	return STRUCTURE_VISION_BAKER.new().bake(self, _placement)


## Refaz o registro depois que paredes, janelas ou portas forem alteradas em runtime.
func cache_wall_cells() -> void:
	_wall_cells.clear()
	for descendant: Node in find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var tile_data := layer.get_cell_tile_data(cell)
			if (
				tile_data == null
				or tile_data.get_custom_data(&"categoria") not in WALL_VISUAL_CATEGORIES
			):
				continue
			_wall_cells.append({
				"layer": layer,
				"cell": cell,
				"source_id": layer.get_cell_source_id(cell),
				"atlas_coords": layer.get_cell_atlas_coords(cell),
				"alternative": layer.get_cell_alternative_tile(cell),
			})


## Troca apenas a arte do tile. Paredes, janelas, portas e colisões continuam na mesma célula.
func apply_wall_view_mode(mode: int) -> void:
	# Atlas: linha 0 = baixa, 1 = cheia, 2 = fantasma.
	var state_row := 1
	match mode:
		1:
			state_row = 2
		2:
			state_row = 0
	for wall: Dictionary in _wall_cells:
		var layer := wall["layer"] as TileMapLayer
		if not is_instance_valid(layer):
			continue
		var current_data := layer.get_cell_tile_data(wall["cell"] as Vector2i)
		if (
			current_data == null
			or current_data.get_custom_data(&"categoria") not in WALL_VISUAL_CATEGORIES
		):
			continue
		# Lê a coluna atual para não restaurar uma porta aberta/fechada antiga
		# quando algum script de interação trocar seu estado em runtime.
		var source_id := layer.get_cell_source_id(wall["cell"] as Vector2i)
		var current_coords := layer.get_cell_atlas_coords(wall["cell"] as Vector2i)
		var target_row := state_row
		if mode == 3:
			target_row = int(_automatic_wall_rows.get(wall["cell"], 1))
		var target_coords := Vector2i(current_coords.x, target_row)
		var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or not source.has_tile(target_coords):
			continue
		layer.set_cell(
			wall["cell"] as Vector2i,
			source_id,
			target_coords,
			layer.get_cell_alternative_tile(wall["cell"] as Vector2i)
		)


## Recebe linhas do atlas por célula local: 0=baixa, 1=cheia, 2=fantasma.
## O override só aparece enquanto o WallVisibilityManager estiver em AUTO.
func set_automatic_wall_rows(rows: Dictionary) -> void:
	_automatic_wall_rows = rows.duplicate()
	var manager := get_node_or_null(^"/root/WallVisibilityManager")
	if manager != null and int(manager.current_mode) == 3:
		apply_wall_view_mode(3)


## Retorna a porta aberta/fechada cuja borda física toca a posição global.
## Vãos e portas que já estão animando não podem ser acionados.
func get_nearest_interactive_door(
	global_point: Vector2, maximum_distance: float
) -> Dictionary:
	var result: Dictionary = {}
	var best_distance_squared := maximum_distance * maximum_distance
	for descendant: Node in find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or data.get_custom_data(&"categoria") != "porta":
				continue
			if data.get_custom_data(&"estado_porta") not in ["aberta", "fechada"]:
				continue
			if _door_animation_key(layer, cell) in _active_door_animations:
				continue
			var direction: String = data.get_custom_data(&"direcao")
			var distance_squared := _distance_squared_to_wall_edge(
				global_point, layer, cell, direction
			)
			if distance_squared >= best_distance_squared:
				continue
			best_distance_squared = distance_squared
			result = {
				"structure": self,
				"layer": layer,
				"cell": cell,
				"distance_squared": distance_squared,
			}
	return result


## Retorna a janela aberta/fechada cuja borda física toca a posição global.
## Quadros em animação são ignorados.
func get_nearest_interactive_window(
	global_point: Vector2, maximum_distance: float
) -> Dictionary:
	var result: Dictionary = {}
	var best_distance_squared := maximum_distance * maximum_distance
	for descendant: Node in find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or data.get_custom_data(&"categoria") != "janela":
				continue
			if data.get_custom_data(&"estado_janela") not in ["aberta", "fechada"]:
				continue
			if _window_animation_key(layer, cell) in _active_window_animations:
				continue
			var direction: String = data.get_custom_data(&"direcao")
			var distance_squared := _distance_squared_to_wall_edge(
				global_point, layer, cell, direction
			)
			if distance_squared >= best_distance_squared:
				continue
			best_distance_squared = distance_squared
			result = {
				"structure": self,
				"layer": layer,
				"cell": cell,
				"distance_squared": distance_squared,
			}
	return result


func _distance_squared_to_wall_edge(
	global_point: Vector2, layer: TileMapLayer, cell: Vector2i, direction: String
) -> float:
	var endpoints: PackedVector2Array = _interaction_edge_endpoints(direction)
	if endpoints.size() != 2:
		return INF
	var cell_origin := layer.map_to_local(cell)
	var edge_start := layer.to_global(cell_origin + endpoints[0])
	var edge_end := layer.to_global(cell_origin + endpoints[1])
	var closest_point := Geometry2D.get_closest_point_to_segment(
		global_point, edge_start, edge_end
	)
	return global_point.distance_squared_to(closest_point)


func _interaction_edge_endpoints(direction: String) -> PackedVector2Array:
	var north := Vector2(0.0, -32.0)
	var east := Vector2(64.0, 0.0)
	var south := Vector2(0.0, 32.0)
	var west := Vector2(-64.0, 0.0)
	match direction:
		"ne":
			return PackedVector2Array([north, east])
		"nw":
			return PackedVector2Array([west, north])
		"se":
			return PackedVector2Array([east, south])
		"sw":
			return PackedVector2Array([south, west])
	return PackedVector2Array()


## Alterna uma porta e inicia a sequência visual. Retorna imediatamente para
## que o input possa ser consumido sem aguardar os nove quadros.
func toggle_door(layer: TileMapLayer, cell: Vector2i) -> bool:
	if not is_instance_valid(layer) or not is_ancestor_of(layer):
		return false
	var data := layer.get_cell_tile_data(cell)
	if data == null or data.get_custom_data(&"categoria") != "porta":
		return false
	var current_state: String = data.get_custom_data(&"estado_porta")
	if current_state not in ["aberta", "fechada"]:
		return false
	var key := _door_animation_key(layer, cell)
	if key in _active_door_animations:
		return false
	_active_door_animations[key] = true
	_animate_door(
		layer,
		cell,
		current_state == "fechada",
		key,
		vision_portal_id(layer, cell, &"door")
	)
	return true


func _animate_door(
	layer: TileMapLayer,
	cell: Vector2i,
	opening: bool,
	animation_key: String,
	portal_id: StringName
) -> void:
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		_active_door_animations.erase(animation_key)
		return
	var source_id := layer.get_cell_source_id(cell)
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	var alternative := layer.get_cell_alternative_tile(cell)
	var state_row := atlas_coords.y
	var direction: String = data.get_custom_data(&"direcao")
	var direction_base_column := atlas_coords.x - posmod(atlas_coords.x, 3)
	var target_column := direction_base_column if opening else direction_base_column + 1
	var direction_index := DOOR_DIRECTIONS.find(direction)
	if direction_index < 0:
		_active_door_animations.erase(animation_key)
		return
	var animation_column := DOOR_ANIMATION_COLUMN_BASE + direction_index * DOOR_FRAME_COUNT
	var state_emitted := false
	for animation_index in DOOR_FRAME_COUNT:
		if not is_instance_valid(layer):
			break
		var frame_index := animation_index if opening else DOOR_FRAME_COUNT - 1 - animation_index
		# Cada quadro é um tile real da mesma fonte. Portanto usa exatamente o
		# mesmo Z, texture_origin e y_sort_origin das paredes, sem Sprite2D auxiliar.
		var current_coords := layer.get_cell_atlas_coords(cell)
		if current_coords.y >= 0:
			state_row = current_coords.y
		layer.set_cell(
			cell,
			source_id,
			Vector2i(animation_column + frame_index, state_row),
			alternative
		)
		# A porta já liberou visual/fisicamente o centro no anim05. No sentido
		# inverso ela volta a bloquear ao entrar no anim04.
		if (opening and frame_index == 5) or (not opening and frame_index == 4):
			vision_portal_changed.emit(portal_id, opening)
			state_emitted = true
		await get_tree().create_timer(DOOR_FRAME_SECONDS).timeout

	if is_instance_valid(layer):
		layer.set_cell(cell, source_id, Vector2i(target_column, state_row), alternative)
	if not state_emitted:
		vision_portal_changed.emit(portal_id, opening)
	_active_door_animations.erase(animation_key)


func _door_animation_key(layer: TileMapLayer, cell: Vector2i) -> String:
	return "%d:%d:%d" % [layer.get_instance_id(), cell.x, cell.y]


## Alterna uma janela e toca os cinco quadros fornecidos pelo pacote de arte.
func toggle_window(layer: TileMapLayer, cell: Vector2i) -> bool:
	if not is_instance_valid(layer) or not is_ancestor_of(layer):
		return false
	var data := layer.get_cell_tile_data(cell)
	if data == null or data.get_custom_data(&"categoria") != "janela":
		return false
	var current_state: String = data.get_custom_data(&"estado_janela")
	if current_state not in ["aberta", "fechada"]:
		return false
	var base_index := WINDOW_BASE_PARTS.find(data.get_custom_data(&"peca"))
	if base_index < 0:
		return false
	var key := _window_animation_key(layer, cell)
	if key in _active_window_animations:
		return false
	_active_window_animations[key] = true
	_animate_window(
		layer,
		cell,
		base_index,
		current_state == "fechada",
		key,
		vision_portal_id(layer, cell, &"window")
	)
	return true


func _animate_window(
	layer: TileMapLayer,
	cell: Vector2i,
	base_index: int,
	opening: bool,
	animation_key: String,
	portal_id: StringName
) -> void:
	var source_id := layer.get_cell_source_id(cell)
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	var alternative := layer.get_cell_alternative_tile(cell)
	var state_row := atlas_coords.y
	var animation_column := WINDOW_ANIMATION_COLUMN_BASE + base_index * WINDOW_FRAME_COUNT
	# Fechar deve retirar informação imediatamente; o fade pertence somente à
	# apresentação. Abrir só transmite quando a folha alcança o quadro final.
	if not opening:
		vision_portal_changed.emit(portal_id, false)
	for animation_index in WINDOW_FRAME_COUNT:
		if not is_instance_valid(layer):
			break
		var frame_index := animation_index if opening else WINDOW_FRAME_COUNT - 1 - animation_index
		var current_coords := layer.get_cell_atlas_coords(cell)
		if current_coords.y >= 0:
			state_row = current_coords.y
		layer.set_cell(
			cell,
			source_id,
			Vector2i(animation_column + frame_index, state_row),
			alternative
		)
		await get_tree().create_timer(WINDOW_FRAME_SECONDS).timeout

	if is_instance_valid(layer):
		var target_column := WINDOW_OPEN_COLUMN_BASE + base_index if opening else base_index
		layer.set_cell(cell, source_id, Vector2i(target_column, state_row), alternative)
	if opening:
		vision_portal_changed.emit(portal_id, true)
	_active_window_animations.erase(animation_key)


func _window_animation_key(layer: TileMapLayer, cell: Vector2i) -> String:
	return "%d:%d:%d" % [layer.get_instance_id(), cell.x, cell.y]


## ID determinístico usado por visão e save. Nunca contém instance_id.
func vision_portal_id(
	layer: TileMapLayer, cell: Vector2i, kind: StringName = &""
) -> StringName:
	if layer == null:
		return &""
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return &""
	var resolved_kind := kind
	if resolved_kind == &"":
		resolved_kind = StringName(String(data.get_custom_data(&"categoria")))
	# O save, o baker e os eventos de animação compartilham este contrato.
	# Normalizar aqui impede que o mesmo portal receba IDs distintos conforme
	# tenha sido descoberto pelo TileSet (português) ou pela animação (inglês).
	if resolved_kind == &"porta":
		resolved_kind = &"door"
	elif resolved_kind == &"janela":
		resolved_kind = &"window"
	var direction := String(data.get_custom_data(&"direcao"))
	var placement_id := _placement.placement_id if _placement != null else 0
	return StringName(
		"%d|%d,%d|%s|%s"
		% [placement_id, cell.x, cell.y, direction, String(resolved_kind)]
	)


## Descritores runtime usados para restaurar save e conectar os eventos ao
## registro lógico. Vãos são retornados como permanentes e não são persistidos.
func vision_portals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var layer := get_node_or_null(^"Paredes") as TileMapLayer
	if layer == null:
		return result
	for cell: Vector2i in layer.get_used_cells():
		var data := layer.get_cell_tile_data(cell)
		if data == null:
			continue
		var category := String(data.get_custom_data(&"categoria"))
		if category not in ["porta", "janela"]:
			continue
		var direction := String(data.get_custom_data(&"direcao"))
		if direction not in DOOR_DIRECTIONS:
			continue
		var state_key := &"estado_porta" if category == "porta" else &"estado_janela"
		var state := String(data.get_custom_data(state_key))
		# Montantes usam categoria de porta para compartilhar arte/cutaway, mas
		# não atravessam uma borda e portanto nunca podem entrar na topologia.
		if state not in ["aberta", "fechada", "vao"]:
			continue
		var kind: StringName = &"door" if category == "porta" else &"window"
		var permanent := state == "vao"
		result.append({
			"id": vision_portal_id(layer, cell, kind),
			"kind": kind,
			"layer": layer,
			"cell": cell,
			"direction": StringName(direction),
			"is_open": permanent or state == "aberta",
			"permanent": permanent,
		})
	return result


## Restaura uma abertura sem animação antes do primeiro cálculo de visão.
func set_vision_portal_open(portal_id: StringName, is_open: bool) -> bool:
	for descriptor: Dictionary in vision_portals():
		if descriptor["id"] != portal_id or bool(descriptor["permanent"]):
			continue
		var layer := descriptor["layer"] as TileMapLayer
		var cell := descriptor["cell"] as Vector2i
		var direction := String(descriptor["direction"])
		var source_id := layer.get_cell_source_id(cell)
		var coords := layer.get_cell_atlas_coords(cell)
		var alternative := layer.get_cell_alternative_tile(cell)
		if descriptor["kind"] == &"door":
			var direction_index := DOOR_DIRECTIONS.find(direction)
			if direction_index < 0:
				return false
			var column := direction_index * 3 + (0 if is_open else 1)
			layer.set_cell(cell, source_id, Vector2i(column, coords.y), alternative)
		else:
			var data := layer.get_cell_tile_data(cell)
			var base_index := WINDOW_BASE_PARTS.find(data.get_custom_data(&"peca"))
			if base_index < 0:
				return false
			var column := base_index + (WINDOW_OPEN_COLUMN_BASE if is_open else 0)
			layer.set_cell(cell, source_id, Vector2i(column, coords.y), alternative)
		cache_wall_cells()
		return true
	return false


## Chamado pelo renderer logo após instanciar a cena.
func setup(p_placement: StructurePlacement) -> void:
	_placement = p_placement


func placement() -> StructurePlacement:
	return _placement


## Todos os marcadores da cena, por tipo.
func markers_of_type(marker_type: StructureMarker.MarkerType) -> Array[StructureMarker]:
	var result: Array[StructureMarker] = []
	_collect_markers(self, marker_type, result)
	return result


func _collect_markers(
	node: Node, marker_type: StructureMarker.MarkerType, out: Array[StructureMarker]
) -> void:
	for child in node.get_children():
		var marker := child as StructureMarker
		if marker != null and marker.marker_type == marker_type:
			out.append(marker)
		_collect_markers(child, marker_type, out)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not draw_footprint_gizmo:
		return
	var iso := IsoCoordinateSystem.new(tile_size, 26)
	var size := definition.footprint if definition != null else footprint_preview
	if size.x <= 0 or size.y <= 0:
		return
	var corners := PackedVector2Array([
		iso.cell_to_local(Vector2i(0, 0)) + Vector2(0.0, -tile_size.y * 0.5),
		iso.cell_to_local(Vector2i(size.x, 0)) + Vector2(tile_size.x * 0.5, 0.0),
		iso.cell_to_local(Vector2i(size.x, size.y)) + Vector2(0.0, tile_size.y * 0.5),
		iso.cell_to_local(Vector2i(0, size.y)) + Vector2(-tile_size.x * 0.5, 0.0),
	])
	draw_colored_polygon(corners, Color(gizmo_color.r, gizmo_color.g, gizmo_color.b, 0.18))
	corners.append(corners[0])
	draw_polyline(corners, gizmo_color, 2.0)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()

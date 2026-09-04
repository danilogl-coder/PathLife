## Valida o kit autorável de estruturas com TileMapLayer.
## Uso: godot --headless --path . --script res://tests/structure_tilemap_test.gd
extends SceneTree

const TILESET_PATH := "res://data/world/structures/casa_madeira_tileset.tres"
const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"
const ENVIRONMENTS := ["banheiro", "cozinha", "lazer", "sala"]
const STATES := ["baixa", "cheia", "fantasma"]
const PARTS := ["ne", "nw", "se", "sw", "quina_n", "quina_e", "quina_s", "quina_w", "canto"]
const WINDOW_PARTS := [
	"janela_ne", "janela_nw", "janela_se", "janela_sw",
	"janela_vazada_ne", "janela_vazada_nw", "janela_vazada_se", "janela_vazada_sw",
]

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	_check(tile_set != null, "TileSet carrega")
	if tile_set == null:
		_finish()
		return

	_check(tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "shape isométrico")
	_check(tile_set.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "layout Diamond Down")
	_check(tile_set.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL, "eixo horizontal")
	_check(tile_set.tile_size == Vector2i(128, 64), "grade 128x64")
	_check(not tile_set.uv_clipping, "paredes altas não usam UV clipping")
	_check(tile_set.get_physics_layers_count() == 1, "uma camada física")
	_check(tile_set.get_physics_layer_collision_layer(0) == 1, "física na layer World")
	_check(tile_set.get_physics_layer_collision_mask(0) == 2, "máscara física Player")
	_check(
		tile_set.get_source_count() == 17,
		"fontes de piso, paredes, janelas, portas, telhados, mobília e spawn configuradas"
	)

	var floor_source := tile_set.get_source(0) as TileSetAtlasSource
	_check(floor_source != null, "fonte de pisos existe")
	if floor_source != null:
		_check(floor_source.texture_region_size == Vector2i(128, 76), "região de piso 128x76")
		var floor_count := 0
		for environment_index in ENVIRONMENTS.size():
			for variant_index in 2:
				var coords := Vector2i(environment_index, variant_index)
				_check(floor_source.has_tile(coords), "piso %s existe" % coords)
				var data := floor_source.get_tile_data(coords, 0)
				if data != null:
					floor_count += 1
					_check(data.texture_origin == Vector2i(0, -6), "origem do piso %s" % coords)
					_check(data.get_collision_polygons_count(0) == 0, "piso sem colisão %s" % coords)
		_check(floor_count == 8, "oito pisos configurados")

	var roof_source := tile_set.get_source(30) as TileSetAtlasSource
	_check(roof_source != null, "fonte de telhados existe")
	if roof_source != null:
		_check(roof_source.texture_region_size == Vector2i(160, 112), "região de telhado 160x112")
		_check(roof_source.texture.get_size() == Vector2(5440, 336), "atlas de telhado 5440x336")
		var roof_count := 0
		for style_index in 3:
			for part_index in 34:
				var coords := Vector2i(part_index, style_index)
				_check(roof_source.has_tile(coords), "telhado %s existe" % coords)
				var data := roof_source.get_tile_data(coords, 0)
				if data == null:
					continue
				roof_count += 1
				_check(data.texture_origin == Vector2i(0, 96), "origem elevada de %s" % coords)
				_check(data.get_custom_data(&"categoria") == "telhado", "categoria de %s" % coords)
				_check(data.get_collision_polygons_count(0) == 0, "telhado sem colisão %s" % coords)
		_check(roof_count == 102, "102 tiles de telhado configurados")
	var complete_roof_source := tile_set.get_source(31) as TileSetAtlasSource
	_check(complete_roof_source != null, "fonte do telhado colonial completo existe")
	if complete_roof_source != null:
		_check(
			complete_roof_source.texture_region_size == Vector2i(1056, 536),
			"telhado completo tem dimensão natural para a casa"
		)
		var complete_data := complete_roof_source.get_tile_data(Vector2i.ZERO, 0)
		_check(complete_data != null, "tile do telhado completo existe")
		if complete_data != null:
			_check(complete_data.texture_origin == Vector2i(32, 80), "telhado completo centralizado e elevado")
			_check(complete_data.get_custom_data(&"categoria") == "telhado", "tile completo categorizado")

	# A fonte contém as quatro camas e as 60 orientações do catálogo de mobília.
	var furniture_source := tile_set.get_source(40) as TileSetScenesCollectionSource
	_check(furniture_source != null, "fonte de mobília existe")
	if furniture_source != null:
		_check(furniture_source.get_scene_tiles_count() == 64, "fonte possui 64 tiles de mobília")
		for scene_id in 64:
			var furniture_scene := furniture_source.get_scene_tile_scene(scene_id)
			_check(furniture_scene != null, "tile de mobília %d mantém sua PackedScene" % scene_id)
			_check(
				not furniture_source.get_scene_tile_display_placeholder(scene_id),
				"tile de mobília %d mostra a arte real no editor" % scene_id
			)
	var spawn_source := tile_set.get_source(41) as TileSetScenesCollectionSource
	_check(spawn_source != null, "fonte pintável de Spawn Player existe")
	if spawn_source != null:
		_check(spawn_source.get_scene_tiles_count() == 1, "fonte possui um tile Spawn Player")
		var marker_scene := spawn_source.get_scene_tile_scene(0)
		_check(marker_scene != null, "tile Spawn Player mantém sua PackedScene")
		if marker_scene != null:
			var marker := marker_scene.instantiate()
			_check(marker is PlayerSpawnMarker, "tile instancia PlayerSpawnMarker")
			marker.free()
		_check(not spawn_source.get_scene_tile_display_placeholder(0),
			"Spawn Player mostra o marcador real no editor")

	var wall_count := 0
	var polygon_count := 0
	for environment_index in ENVIRONMENTS.size():
		var source_id := 10 + environment_index
		var wall_source := tile_set.get_source(source_id) as TileSetAtlasSource
		_check(wall_source != null, "fonte de paredes %s" % ENVIRONMENTS[environment_index])
		if wall_source == null:
			continue
		_check(wall_source.texture_region_size == Vector2i(128, 158), "região de parede 128x158")
		_check(not wall_source.use_texture_padding, "parede transparente sem padding instável")
		var wall_atlas := wall_source.texture.get_image()
		for state_index in STATES.size():
			for part_index in PARTS.size():
				var part: String = PARTS[part_index]
				var coords := Vector2i(part_index, state_index)
				_check(wall_source.has_tile(coords), "parede %d:%s existe" % [source_id, coords])
				var data := wall_source.get_tile_data(coords, 0)
				if data == null:
					continue
				wall_count += 1
				_check(data.texture_origin == Vector2i(0, 46), "origem da parede %d:%s" % [source_id, coords])
				var expected_polygons := 1 if part in ["ne", "nw", "se", "sw"] else 2
				var actual_polygons := data.get_collision_polygons_count(0)
				polygon_count += actual_polygons
				_check(actual_polygons == expected_polygons, "colisão de %s em %d:%s" % [part, source_id, coords])
				if state_index == 2:
					_check(
						_has_uniform_ghost_alpha(wall_atlas, part_index),
						"fantasma de %s usa alpha uniforme" % part
					)
	_check(wall_count == 108, "108 paredes únicas configuradas")
	_check(polygon_count == 168, "168 polígonos de colisão configurados")

	var window_count := 0
	for environment_index in ENVIRONMENTS.size():
		var source_id := 24 + environment_index
		var window_source := tile_set.get_source(source_id) as TileSetAtlasSource
		_check(window_source != null, "fonte de janelas %s" % ENVIRONMENTS[environment_index])
		if window_source == null:
			continue
		_check(window_source.texture_region_size == Vector2i(128, 158), "região de janela 128x158")
		_check(not window_source.use_texture_padding, "janela transparente sem padding instável")
		var window_atlas := window_source.texture.get_image()
		for state_index in STATES.size():
			for part_index in WINDOW_PARTS.size():
				var coords := Vector2i(part_index, state_index)
				_check(window_source.has_tile(coords), "janela %d:%s existe" % [source_id, coords])
				var data := window_source.get_tile_data(coords, 0)
				if data == null:
					continue
				window_count += 1
				_check(data.texture_origin == Vector2i(0, 46), "origem da janela %d:%s" % [source_id, coords])
				_check(data.get_custom_data(&"categoria") == "janela", "categoria da janela %d:%s" % [source_id, coords])
				_check(data.get_collision_polygons_count(0) == 1, "colisão da janela %d:%s" % [source_id, coords])
				if state_index == 2:
					_check(
						_has_uniform_ghost_alpha(window_atlas, part_index),
						"fantasma de %s usa alpha uniforme" % WINDOW_PARTS[part_index]
					)
	_check(window_count == 96, "96 janelas configuradas")

	var packed_scene := load(SCENE_PATH) as PackedScene
	_check(packed_scene != null, "cena-base carrega")
	if packed_scene != null:
		var scene := packed_scene.instantiate()
		root.add_child(scene)
		_check(scene is StructureRoot, "raiz usa StructureRoot")
		var floor_layer := scene.get_node_or_null(^"Piso") as TileMapLayer
		var wall_layer := scene.get_node_or_null(^"Paredes") as TileMapLayer
		var overlay_layer := scene.get_node_or_null(^"ParedesSemColisao") as TileMapLayer
		var furniture_layer := scene.get_node_or_null(^"Mobilia") as TileMapLayer
		var spawn_layer := scene.get_node_or_null(^"SpawnPlayer") as TileMapLayer
		var roof_layer := scene.get_node_or_null(^"Telhado") as TileMapLayer
		_check(
			floor_layer != null and wall_layer != null and overlay_layer != null
			and furniture_layer != null and spawn_layer != null and roof_layer != null,
			"seis camadas autoráveis"
		)
		if floor_layer != null:
			_check(floor_layer.position == Vector2(-64.0, -32.0), "compensação Diamond Down no piso")
			_check(not floor_layer.get_used_cells().is_empty(), "estrutura possui piso pintado")
			print("[INFO] área pintada do piso: ", floor_layer.get_used_rect())
			_check(not floor_layer.collision_enabled, "piso sem física")
			_check(floor_layer.map_to_local(Vector2i.ZERO) + floor_layer.position == Vector2.ZERO, "célula 0,0 na origem local")
			_check(floor_layer.map_to_local(Vector2i(1, 0)) + floor_layer.position == Vector2(64, 32), "eixo X isométrico")
			_check(floor_layer.map_to_local(Vector2i(0, 1)) + floor_layer.position == Vector2(-64, 32), "eixo Y isométrico")
		if wall_layer != null:
			_check(wall_layer.position == Vector2(-64.0, -32.0), "compensação Diamond Down nas paredes")
			_check(not wall_layer.get_used_cells().is_empty(), "estrutura possui paredes pintadas")
			_check(wall_layer.collision_enabled, "paredes sólidas com física")
			var painted_windows := 0
			for cell: Vector2i in wall_layer.get_used_cells():
				var painted_data := wall_layer.get_cell_tile_data(cell)
				if painted_data != null and painted_data.get_custom_data(&"categoria") == "janela":
					painted_windows += 1
			_check(painted_windows == 6, "casa-base possui seis janelas pintadas")
		if overlay_layer != null:
			_check(not overlay_layer.collision_enabled, "sobreposição sem física")
		if furniture_layer != null:
			_check(furniture_layer.y_sort_enabled, "mobília participa do Y-Sort")
			_check(not furniture_layer.collision_enabled, "camada delega física às cenas de mobília")
			_check(furniture_layer.get_used_cells().is_empty(),
				"células de cena automáticas são removidas somente da cópia runtime")
		if roof_layer != null:
			_check(roof_layer.z_index == 10, "telhado fica acima da casa")
			_check(not roof_layer.collision_enabled, "telhado sem física")
			_check(roof_layer.get_used_cells() == [Vector2i(3, 3)], "telhado completo pintado no centro")
			_check(roof_layer.visible, "telhado oculto no editor volta a aparecer em runtime")
			_check(scene.get_node_or_null(^"InteriorDetector") is Area2D, "detector interno criado")
			var actor := Node2D.new()
			actor.add_to_group(&"depth_actor")
			scene.add_child(actor)
			(scene as StructureRoot)._on_roof_body_entered(actor)
			_check(not roof_layer.visible, "telhado some quando ator entra")
			# Suspender a colisão durante o sono emite body_exited sem o ator sair
			# geometricamente da casa.
			(scene as StructureRoot)._on_roof_body_exited(actor)
			await process_frame
			_check(not roof_layer.visible, "telhado permanece oculto enquanto ator dorme dentro")
			actor.position = Vector2(2048.0, 2048.0)
			(scene as StructureRoot)._on_roof_body_exited(actor)
			await process_frame
			_check(roof_layer.visible, "telhado volta quando ator sai")
			actor.queue_free()
		var entrance_marker := scene.get_node_or_null(^"Marcadores/EntranceMarker") as StructureMarker
		_check(
			entrance_marker != null and entrance_marker.cell_offset == Vector2i(1, 8),
			"marcador de entrada coincide com a porta principal"
		)
		await physics_frame
		var probe_shape := RectangleShape2D.new()
		probe_shape.size = Vector2(4.0, 4.0)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = probe_shape
		query.collision_mask = 1
		query.transform = Transform2D(0.0, Vector2(32.0, -16.0))
		var wall_hits: Array[Dictionary] = (
			scene.get_world_2d().direct_space_state.intersect_shape(query, 8)
		)
		_check(not wall_hits.is_empty(), "colisão pintada existe no servidor de física")
		query.transform = Transform2D(0.0, Vector2(0.0, 64.0))
		var floor_hits: Array[Dictionary] = (
			scene.get_world_2d().direct_space_state.intersect_shape(query, 8)
		)
		_check(floor_hits.is_empty(), "interior do piso permanece caminhável")
		scene.queue_free()
		await _test_painted_player_spawn_marker(packed_scene)
		_test_chunk_view_anchor(packed_scene)

	_test_procedural_registration()
	_finish()


func _test_painted_player_spawn_marker(structure_scene: PackedScene) -> void:
	var probe := structure_scene.instantiate() as StructureRoot
	var spawn_layer := probe.get_node(^"SpawnPlayer") as TileMapLayer
	var painted_cell := Vector2i(3, 6)
	spawn_layer.clear()
	spawn_layer.set_cell(painted_cell, 41, Vector2i.ZERO, 0)
	root.add_child(probe)
	_check(probe.player_spawn_cells() == [painted_cell],
		"gameplay lê diretamente a célula Spawn Player pintada")
	await process_frame
	var markers := probe.markers_of_type(StructureMarker.MarkerType.PLAYER_SPAWN)
	_check(markers.size() == 1, "tile pintado cria um marcador de spawn")
	if markers.size() == 1:
		_check(markers[0] is PlayerSpawnMarker, "marcador pintado preserva seu tipo")
		_check(markers[0].cell_offset == painted_cell,
			"marcador converte a posição pintada para a célula lógica")
		var preview := markers[0].get_node_or_null(^"EditorPreview") as CanvasItem
		_check(preview != null and not preview.visible,
			"ícone do spawn não aparece durante o jogo")
	probe.queue_free()


func _test_chunk_view_anchor(structure_scene: PackedScene) -> void:
	var packed_view := load("res://world_generation/rendering/chunk_view.tscn") as PackedScene
	var world_settings := load("res://data/world/world_settings.tres") as WorldSettings
	_check(packed_view != null and world_settings != null, "recursos de integração carregam")
	if packed_view == null or world_settings == null:
		return
	var view := packed_view.instantiate() as ChunkView
	root.add_child(view)
	view.settings = world_settings
	view._iso = IsoCoordinateSystem.from_settings(world_settings)
	var structure := structure_scene.instantiate() as Node2D
	var foundation_height := 3
	view._anchor_prop(
		structure,
		Vector3i(2, 3, foundation_height),
		view.structures_root,
		true
	)
	var anchor := structure.get_parent() as Node2D
	_check(anchor != null and anchor.y_sort_enabled, "âncora expõe tiles ao Y-Sort global")
	_check(structure.z_index == 0, "estrutura permanece no Z global")
	var expected_position := Vector2(
		0.0,
		-float(foundation_height * world_settings.height_pixels)
		- view._iso.prop_sort_bias()
	)
	_check(structure.position == expected_position, "fundação desloca a estrutura visualmente")
	for layer_name: StringName in [
		&"Piso", &"Paredes", &"ParedesSemColisao", &"Mobilia", &"SpawnPlayer", &"Telhado"
	]:
		var layer := structure.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		_check(
			layer != null
			and layer.y_sort_origin == foundation_height * world_settings.height_pixels,
			"%s compensa a fundação no Y-Sort" % layer_name
		)
	view.free()


func _test_procedural_registration() -> void:
	var definition := load(
		"res://data/world/structures/casa_madeira.tres"
	) as StructureDefinition
	_check(definition != null, "definição procedural da casa carrega")
	if definition == null:
		return
	_check(definition.id == &"casa_madeira", "id procedural da casa é único")
	_check(definition.scene != null, "definição aponta para a cena TileMap")
	var definition_instance := definition.scene.instantiate() if definition.scene != null else null
	var definition_floor := (
		definition_instance.get_node_or_null(^"Piso") as TileMapLayer
		if definition_instance != null else null
	)
	var painted_rect := definition_floor.get_used_rect() if definition_floor != null else Rect2i()
	_check(
		painted_rect.position == Vector2i.ZERO and definition.footprint == painted_rect.size,
		"footprint procedural acompanha a área pintada"
	)
	if definition_instance != null:
		definition_instance.free()
	_check(not definition.footprint_blocks_movement, "interior procedural permanece caminhável")

	var campo := load("res://data/world/biomes/campo.tres") as BiomeDefinition
	var registered := false
	if campo != null:
		for candidate: StructureDefinition in campo.structure_pool:
			if candidate != null and candidate.id == &"casa_madeira":
				registered = true
				break
	_check(registered, "casa está registrada na pool do bioma campo")

	var planner := load("res://data/world/structure_planner.tres") as StructurePlanner
	var world_settings := load("res://data/world/world_settings.tres") as WorldSettings
	_check(planner != null and world_settings != null, "planejador procedural carrega")
	if planner == null or world_settings == null:
		return
	planner.clear_cache()
	var occurrences := 0
	for region_y in range(-2, 3):
		for region_x in range(-2, 3):
			for placement: StructurePlacement in planner.plan_region(
				Vector2i(region_x, region_y), world_settings, world_settings.resolved_seed()
			):
				if placement.definition != null and placement.definition.id == &"casa_madeira":
					occurrences += 1
	_check(occurrences > 0, "planejador realmente posiciona a casa no mapa")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _has_uniform_ghost_alpha(atlas: Image, part_index: int) -> bool:
	if atlas == null:
		return false
	var full_origin := Vector2i(part_index * 128, 158)
	var ghost_origin := Vector2i(part_index * 128, 316)
	var found_visual_pixel := false
	for y in 158:
		for x in 128:
			var full := atlas.get_pixelv(full_origin + Vector2i(x, y))
			var ghost := atlas.get_pixelv(ghost_origin + Vector2i(x, y))
			if full.a <= 0.0:
				if ghost.a > 0.01:
					return false
				continue
			found_visual_pixel = true
			if ghost.a < 0.48 or ghost.a > 0.52:
				return false
	return found_visual_pixel


func _finish() -> void:
	if _failures == 0:
		print("\nSTRUCTURE TILEMAP TEST: OK")
		quit(0)
	else:
		printerr("\nSTRUCTURE TILEMAP TEST: %d falha(s)" % _failures)
		quit(1)

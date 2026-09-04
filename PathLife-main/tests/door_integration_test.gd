## Valida o kit reutilizável de portas das estruturas com TileMapLayer.
## Uso: godot --headless --path . --script res://tests/door_integration_test.gd
extends SceneTree

const TILESET_PATH := "res://data/world/structures/casa_madeira_tileset.tres"
const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"
const ENVIRONMENTS := ["banheiro", "cozinha", "lazer", "sala"]
const VISUAL_STATES := ["baixa", "cheia", "fantasma"]
const DOOR_PARTS := [
	"porta_ne_aberta", "porta_ne_fechada", "porta_ne_vao",
	"porta_nw_aberta", "porta_nw_fechada", "porta_nw_vao",
	"porta_se_aberta", "porta_se_fechada", "porta_se_vao",
	"porta_sw_aberta", "porta_sw_fechada", "porta_sw_vao",
	"montante_n", "montante_e", "montante_s", "montante_w",
	"porta_ne_anim00", "porta_ne_anim01", "porta_ne_anim02",
	"porta_ne_anim03", "porta_ne_anim04", "porta_ne_anim05",
	"porta_ne_anim06", "porta_ne_anim07", "porta_ne_anim08",
	"porta_nw_anim00", "porta_nw_anim01", "porta_nw_anim02",
	"porta_nw_anim03", "porta_nw_anim04", "porta_nw_anim05",
	"porta_nw_anim06", "porta_nw_anim07", "porta_nw_anim08",
	"porta_se_anim00", "porta_se_anim01", "porta_se_anim02",
	"porta_se_anim03", "porta_se_anim04", "porta_se_anim05",
	"porta_se_anim06", "porta_se_anim07", "porta_se_anim08",
	"porta_sw_anim00", "porta_sw_anim01", "porta_sw_anim02",
	"porta_sw_anim03", "porta_sw_anim04", "porta_sw_anim05",
	"porta_sw_anim06", "porta_sw_anim07", "porta_sw_anim08",
]
const SAMPLE_DOOR_CELL := Vector2i(1, 8)
const HOUSE_DOORS: Array[Dictionary] = [
	{"cell": Vector2i(1, 8), "environment": "sala", "direction": "ne"},
	{"cell": Vector2i(1, 4), "environment": "sala", "direction": "ne"},
	{"cell": Vector2i(4, 4), "environment": "cozinha", "direction": "nw"},
	{"cell": Vector2i(4, 6), "environment": "sala", "direction": "nw"},
]

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	_check(tile_set != null, "TileSet com portas carrega")
	if tile_set == null:
		_finish()
		return

	var tile_count := 0
	var polygon_count := 0
	for environment_index in ENVIRONMENTS.size():
		var source_id := 20 + environment_index
		var source := tile_set.get_source(source_id) as TileSetAtlasSource
		_check(source != null, "fonte de portas %s existe" % ENVIRONMENTS[environment_index])
		if source == null:
			continue
		_check(source.texture_region_size == Vector2i(128, 158), "região de porta 128x158")
		_check(not source.use_texture_padding, "porta transparente não usa padding instável")
		_check(source.texture.get_size() == Vector2(6656, 474), "atlas de porta 6656x474")
		var atlas := source.texture.get_image()
		for visual_state_index in VISUAL_STATES.size():
			for part_index in DOOR_PARTS.size():
				var part: String = DOOR_PARTS[part_index]
				var coords := Vector2i(part_index, visual_state_index)
				_check(source.has_tile(coords), "porta %d:%s existe" % [source_id, coords])
				var data := source.get_tile_data(coords, 0)
				if data == null:
					continue
				tile_count += 1
				_check(data.texture_origin == Vector2i(0, 46), "origem de %s" % part)
				_check(data.get_custom_data(&"categoria") == "porta", "categoria de %s" % part)
				var direction: String = data.get_custom_data(&"direcao")
				var expected_y_sort := 31 if direction in ["se", "sw", "e", "s", "w"] else 0
				_check(data.y_sort_origin == expected_y_sort, "Y-Sort de %s" % part)
				_check(
					data.get_custom_data(&"ambiente") == ENVIRONMENTS[environment_index],
					"ambiente de %s" % part
				)
				_check(data.get_custom_data(&"peca") == part, "nome de %s" % part)
				_check(
					data.get_custom_data(&"estado") == VISUAL_STATES[visual_state_index],
					"modo visual de %s" % part
				)
				var expected_polygons := _expected_collision_polygons(part)
				var actual_polygons := data.get_collision_polygons_count(0)
				polygon_count += actual_polygons
				_check(
					actual_polygons == expected_polygons,
					"colisão de %s em %s" % [part, VISUAL_STATES[visual_state_index]]
				)
				if visual_state_index == 2:
					_check(
						_has_uniform_ghost_alpha(atlas, part_index),
						"transparência uniforme de %s" % part
					)
	_check(tile_count == 624, "624 tiles estáticos e animados configurados")
	_check(polygon_count == 864, "864 polígonos preservam colisão durante a animação")

	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena da casa com porta carrega")
	if packed != null:
		var house := packed.instantiate() as StructureRoot
		root.add_child(house)
		await process_frame
		var walls := house.get_node_or_null(^"Paredes") as TileMapLayer
		_check(walls != null, "camada de paredes da casa existe")
		if walls != null:
			for expected: Dictionary in HOUSE_DOORS:
				var cell := expected["cell"] as Vector2i
				var data := walls.get_cell_tile_data(cell)
				_check(data != null, "vão %s possui uma porta" % cell)
				if data == null:
					continue
				_check(data.get_custom_data(&"categoria") == "porta", "tile %s é porta" % cell)
				_check(
					data.get_custom_data(&"ambiente") == expected["environment"],
					"porta %s combina com o ambiente" % cell
				)
				_check(
					data.get_custom_data(&"direcao") == expected["direction"],
					"porta %s acompanha a orientação da parede" % cell
				)
				_check(
					data.get_custom_data(&"estado_porta") == "fechada",
					"porta %s inicia fechada" % cell
				)
			var original_column := walls.get_cell_atlas_coords(SAMPLE_DOOR_CELL).x
			house.apply_wall_view_mode(1)
			_check(
				walls.get_cell_atlas_coords(SAMPLE_DOOR_CELL) == Vector2i(original_column, 2),
				"porta acompanha o modo transparente sem trocar abertura"
			)
			house.apply_wall_view_mode(2)
			_check(
				walls.get_cell_atlas_coords(SAMPLE_DOOR_CELL) == Vector2i(original_column, 0),
				"porta acompanha o modo cortado sem trocar abertura"
			)
			house.apply_wall_view_mode(0)
			_check(
				walls.get_cell_atlas_coords(SAMPLE_DOOR_CELL) == Vector2i(original_column, 1),
				"porta retorna ao modo inteiro"
			)
			await physics_frame
			await physics_frame
			_check(not _door_passage_is_clear(house, walls), "porta inicialmente fechada bloqueia o centro")
			_check(_door_jamb_still_blocks(house, walls), "parede ao lado do vão ainda bloqueia")
			house.apply_wall_view_mode(1)
			_check(
				walls.get_cell_atlas_coords(SAMPLE_DOOR_CELL) == Vector2i(1, 2),
				"modo transparente preserva uma troca runtime para porta fechada"
			)
			house.apply_wall_view_mode(0)
			var cell_origin := walls.map_to_local(SAMPLE_DOOR_CELL)
			var sample_global_position := walls.to_global(cell_origin)
			var nearest := house.get_nearest_interactive_door(sample_global_position, 40.0)
			_check(not nearest.is_empty(), "porta encostada é encontrada")
			_check(
				house.get_nearest_interactive_door(
					walls.to_global(cell_origin + Vector2(-64.0, 32.0)), 40.0
				).is_empty(),
				"porta não pode ser acionada à distância"
			)
			_check(
				house.toggle_door(walls, SAMPLE_DOOR_CELL),
				"porta fechada inicia animação de abertura"
			)
			_check(
				not house.toggle_door(walls, SAMPLE_DOOR_CELL),
				"porta ignora nova interação enquanto anima"
			)
			var animation_data := walls.get_cell_tile_data(SAMPLE_DOOR_CELL)
			_check(animation_data != null, "célula da porta permanece ocupada durante a animação")
			if animation_data != null:
				_check(
					String(animation_data.get_custom_data(&"estado_porta")).begins_with("anim"),
					"primeiro quadro é um tile animado do mesmo TileMap"
				)
			_check(
				walls.find_child("DoorAnimation_*", false, false) == null,
				"animação não usa Sprite2D com Z separado"
			)
			await create_timer(0.85).timeout
			_check(
				walls.get_cell_tile_data(SAMPLE_DOOR_CELL).get_custom_data(&"estado_porta")
					== "aberta",
				"animação termina no tile aberto"
			)
			await physics_frame
			_check(_door_passage_is_clear(house, walls), "abertura libera passagem")
			_check(
				house.toggle_door(walls, SAMPLE_DOOR_CELL),
				"porta aberta inicia animação de fechamento"
			)
			await create_timer(0.85).timeout
			_check(
				walls.get_cell_tile_data(SAMPLE_DOOR_CELL).get_custom_data(&"estado_porta")
					== "fechada",
				"animação termina no tile fechado"
			)
			await physics_frame
			_check(not _door_passage_is_clear(house, walls), "fechamento restaura colisão")
		house.queue_free()

	_finish()


func _expected_collision_polygons(part: String) -> int:
	if part.begins_with("montante_"):
		return 0
	if part.ends_with("_fechada"):
		return 1
	var state := part.get_slice("_", 2)
	if state.begins_with("anim") and int(state.trim_prefix("anim")) <= 4:
		return 1
	return 2


func _door_passage_is_clear(house: Node2D, layer: TileMapLayer) -> bool:
	var north := Vector2(0.0, -32.0)
	var east := Vector2(64.0, 0.0)
	var center := north.lerp(east, 0.5)
	return _physics_hits_at(house, layer.to_global(layer.map_to_local(SAMPLE_DOOR_CELL) + center)).is_empty()


func _door_jamb_still_blocks(house: Node2D, layer: TileMapLayer) -> bool:
	var north := Vector2(0.0, -32.0)
	var east := Vector2(64.0, 0.0)
	var jamb := north.lerp(east, 0.14)
	return not _physics_hits_at(house, layer.to_global(layer.map_to_local(SAMPLE_DOOR_CELL) + jamb)).is_empty()


func _physics_hits_at(house: Node2D, position: Vector2) -> Array[Dictionary]:
	var probe := RectangleShape2D.new()
	probe.size = Vector2(4.0, 4.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = 1
	query.transform = Transform2D(0.0, position)
	return house.get_world_2d().direct_space_state.intersect_shape(query, 8)


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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _finish() -> void:
	if _failures == 0:
		print("\nDOOR INTEGRATION TEST: OK")
		quit(0)
	else:
		printerr("\nDOOR INTEGRATION TEST: %d falha(s)" % _failures)
		quit(1)

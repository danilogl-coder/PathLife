## Valida as janelas interativas e sua animação dentro do TileMapLayer.
## Uso: godot --headless --path . --script res://tests/window_integration_test.gd
extends SceneTree

const TILESET_PATH := "res://data/world/structures/casa_madeira_tileset.tres"
const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"
const ENVIRONMENTS := ["banheiro", "cozinha", "lazer", "sala"]
const VISUAL_STATES := ["baixa", "cheia", "fantasma"]
const WINDOW_BASE_PARTS := [
	"janela_ne", "janela_nw", "janela_se", "janela_sw",
	"janela_vazada_ne", "janela_vazada_nw", "janela_vazada_se", "janela_vazada_sw",
]
const HOUSE_WINDOWS: Array[Dictionary] = [
	{"cell": Vector2i(2, 0), "environment": "lazer", "direction": "ne"},
	{"cell": Vector2i(0, 2), "environment": "lazer", "direction": "nw"},
	{"cell": Vector2i(5, 0), "environment": "cozinha", "direction": "ne"},
	{"cell": Vector2i(7, 2), "environment": "cozinha", "direction": "nw"},
	{"cell": Vector2i(3, 8), "environment": "sala", "direction": "ne"},
	{"cell": Vector2i(7, 6), "environment": "sala", "direction": "nw"},
]
const SAMPLE_WINDOW_CELL := Vector2i(3, 8)

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	_check(tile_set != null, "TileSet com janelas carrega")
	if tile_set == null:
		_finish()
		return

	var tile_count := 0
	for environment_index in ENVIRONMENTS.size():
		var source := tile_set.get_source(24 + environment_index) as TileSetAtlasSource
		_check(source != null, "fonte de janelas %s existe" % ENVIRONMENTS[environment_index])
		if source == null:
			continue
		_check(source.texture_region_size == Vector2i(128, 158), "região de janela 128x158")
		_check(source.texture.get_size() == Vector2(7168, 474), "atlas de janela 7168x474")
		for visual_state_index in VISUAL_STATES.size():
			for part_index in 56:
				var coords := Vector2i(part_index, visual_state_index)
				_check(source.has_tile(coords), "janela %d:%s existe" % [24 + environment_index, coords])
				var data := source.get_tile_data(coords, 0)
				if data == null:
					continue
				tile_count += 1
				_check(data.get_custom_data(&"categoria") == "janela", "categoria da janela")
				_check(
					data.get_custom_data(&"estado") == VISUAL_STATES[visual_state_index],
					"modo visual da janela"
				)
				_check(data.get_collision_polygons_count(0) == 1, "janela mantém colisão de parede")
	_check(tile_count == 672, "672 tiles de janela configurados")

	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena da casa com janelas carrega")
	if packed != null:
		var house := packed.instantiate() as StructureRoot
		root.add_child(house)
		await process_frame
		var walls := house.get_node_or_null(^"Paredes") as TileMapLayer
		_check(walls != null, "camada de paredes da casa existe")
		if walls != null:
			for expected: Dictionary in HOUSE_WINDOWS:
				var cell := expected["cell"] as Vector2i
				var data := walls.get_cell_tile_data(cell)
				_check(data != null, "célula %s possui janela" % cell)
				if data == null:
					continue
				_check(data.get_custom_data(&"categoria") == "janela", "tile %s é janela" % cell)
				_check(data.get_custom_data(&"estado_janela") == "fechada", "janela inicia fechada")
				_check(data.get_custom_data(&"ambiente") == expected["environment"], "ambiente correto")
				_check(data.get_custom_data(&"direcao") == expected["direction"], "direção correta")

			var cell_origin := walls.map_to_local(SAMPLE_WINDOW_CELL)
			var sample_position := walls.to_global(cell_origin)
			var nearest := house.get_nearest_interactive_window(sample_position, 40.0)
			_check(not nearest.is_empty(), "janela encostada é encontrada")
			_check(
				house.get_nearest_interactive_window(
					walls.to_global(cell_origin + Vector2(-64.0, 32.0)), 40.0
				).is_empty(),
				"janela não pode ser acionada à distância"
			)
			_check(house.toggle_window(walls, SAMPLE_WINDOW_CELL), "janela fechada começa a abrir")
			_check(not house.toggle_window(walls, SAMPLE_WINDOW_CELL), "janela ignora interação durante animação")
			var animation_data := walls.get_cell_tile_data(SAMPLE_WINDOW_CELL)
			_check(
				String(animation_data.get_custom_data(&"estado_janela")).begins_with("anim"),
				"primeiro quadro animado é aplicado"
			)
			await create_timer(0.6).timeout
			_check(
				walls.get_cell_tile_data(SAMPLE_WINDOW_CELL).get_custom_data(&"estado_janela") == "aberta",
				"animação termina aberta"
			)
			house.apply_wall_view_mode(1)
			_check(
				walls.get_cell_tile_data(SAMPLE_WINDOW_CELL).get_custom_data(&"estado_janela") == "aberta",
				"modo transparente preserva janela aberta"
			)
			house.apply_wall_view_mode(0)
			_check(house.toggle_window(walls, SAMPLE_WINDOW_CELL), "janela aberta começa a fechar")
			await create_timer(0.6).timeout
			_check(
				walls.get_cell_tile_data(SAMPLE_WINDOW_CELL).get_custom_data(&"estado_janela") == "fechada",
				"animação reversa termina fechada"
			)
		house.queue_free()

	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _finish() -> void:
	if _failures == 0:
		print("\nWINDOW INTEGRATION TEST: OK")
		quit(0)
	else:
		printerr("\nWINDOW INTEGRATION TEST: %d falha(s)" % _failures)
		quit(1)

## Contrato do save v2 de percepção e compatibilidade de leitura do save v1.
##
## Uso:
##   godot --headless --path . --script res://tests/vision_save_test.gd
extends SceneTree

var _passed := 0
var _failed := 0
var _paths: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[Save v2] portais, memória visual e compatibilidade")
	_test_v2_round_trip()
	_test_v1_backward_compatibility()
	_test_chunk_manager_persists_resolved_seed()
	_cleanup()
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_v2_round_trip() -> void:
	var path := _temporary_path("v2")
	var writer := WorldSaveManager.new()
	writer.autosave_on_exit = false
	writer.save_path = path
	writer.set_seed(90210)
	writer.set_portal_state(&"17|3,4|nw|window", true)
	writer.set_portal_state(&"17|1,8|ne|door", false)
	var seen_a := PackedByteArray([0b10100101, 0b00000011, 0b11110000])
	var seen_b := PackedByteArray([0b01010101])
	writer.set_seen_chunk(&"0:0:0", seen_a)
	writer.set_seen_chunk(&"-2:5:1", seen_b)
	_check(writer.save() == OK, "save v2 é gravado")

	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(typeof(raw) == TYPE_DICTIONARY, "save v2 contém JSON válido")
	if typeof(raw) == TYPE_DICTIONARY:
		var payload: Dictionary = raw
		_check(int(payload.get("version", 0)) == 2, "versão persistida é 2")
		_check(
			payload.get("portal_states", {}).size() == 2,
			"dois estados de portal persistidos"
		)
		_check(
			String(payload.get("seen_chunks", {}).get("0:0:0", ""))
			== Marshalls.raw_to_base64(seen_a),
			"bitset visual é compactado em Base64"
		)

	var reader := WorldSaveManager.new()
	reader.autosave_on_exit = false
	reader.save_path = path
	_check(reader.load_seed(7) == 90210, "semente v2 é restaurada")
	_check(reader.has_portal_state(&"17|3,4|nw|window"), "portal conhecido é encontrado")
	_check(reader.portal_state(&"17|3,4|nw|window"), "janela aberta é restaurada")
	_check(not reader.portal_state(&"17|1,8|ne|door", true), "porta fechada é restaurada")
	_check(
		reader.portal_state(&"portal-ausente", true),
		"portal ausente respeita fallback"
	)

	var restored := reader.seen_chunks()
	_check(restored.size() == 2, "dois chunks de memória são restaurados")
	_check(restored.get("0:0:0", PackedByteArray()) == seen_a, "bitset principal faz round-trip")
	_check(restored.get("-2:5:1", PackedByteArray()) == seen_b, "nível alternativo faz round-trip")

	# O chamador não pode alterar o estado interno por referência.
	var external_bits: PackedByteArray = restored["0:0:0"]
	external_bits[0] = 0
	var restored_again := reader.seen_chunks()
	_check(
		(restored_again["0:0:0"] as PackedByteArray)[0] == seen_a[0],
		"seen_chunks devolve cópia defensiva"
	)

	writer.free()
	reader.free()


func _test_v1_backward_compatibility() -> void:
	var path := _temporary_path("v1")
	var payload := {
		"version": 1,
		"seed": 31337,
		"patches": [{
			"x": 1,
			"y": 1,
			"z": 0,
			"height": 7,
			"ground": "pedra",
			"walkable": 0,
		}],
		"removed_objects": [987654],
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture v1 pode ser criada")
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()

	var reader := WorldSaveManager.new()
	reader.autosave_on_exit = false
	reader.save_path = path
	_check(reader.load_seed(0) == 31337, "save v1 mantém a semente")
	_check(not reader.has_portal_state(&"qualquer"), "save v1 inicia sem estado de portal")
	_check(reader.portal_state(&"qualquer", true), "fallback de portal funciona após v1")
	_check(reader.seen_chunks().is_empty(), "save v1 inicia sem memória visual")
	_check(reader.is_object_removed(987654), "objeto removido do v1 é preservado")

	var chunk := ChunkData.new(Vector2i.ZERO, 2)
	for y in 2:
		for x in 2:
			var world_xy := Vector2i(x, y)
			var cell := WorldCell.new(world_xy, 0)
			cell.ground_id = &"campo"
			cell.walkable = true
			chunk.set_cell(world_xy, cell)
	reader.apply_patches(chunk)
	var restored_cell := chunk.get_cell(Vector2i(1, 1))
	_check(restored_cell.height == 7, "patch de altura v1 continua aplicável")
	_check(restored_cell.ground_id == &"pedra", "patch de terreno v1 continua aplicável")
	_check(not restored_cell.walkable, "patch de caminhabilidade v1 continua aplicável")
	reader.free()


func _test_chunk_manager_persists_resolved_seed() -> void:
	var path := _temporary_path("resolved_seed")
	var writer := WorldSaveManager.new()
	writer.autosave_on_exit = false
	writer.save_path = path

	var runtime_settings: WorldSettings = load(
		"res://data/world/world_settings.tres"
	).duplicate(true)
	runtime_settings.world_seed = 0
	var manager := ChunkManager.new()
	manager.settings = runtime_settings
	manager.generator = load("res://data/world/world_generator.tres")
	manager.sampler = load("res://data/world/world_sampler.tres")
	manager.save_manager = writer
	manager.initialize()
	manager.set_process(false)

	var resolved_seed := manager.world_seed()
	_check(resolved_seed != 0, "seed aleatória é resolvida para um valor concreto")
	_check(writer.save() == OK, "ChunkManager permite persistir a seed resolvida")
	var reader := WorldSaveManager.new()
	reader.autosave_on_exit = false
	reader.save_path = path
	_check(
		reader.load_seed(-1) == resolved_seed,
		"save usa exatamente a seed que gerou o mundo"
	)

	manager.free()
	writer.free()
	reader.free()


func _temporary_path(suffix: String) -> String:
	var path := "user://__vision_save_test_%s_%d.json" % [suffix, Time.get_ticks_usec()]
	_paths.append(path)
	return path


func _cleanup() -> void:
	for path: String in _paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

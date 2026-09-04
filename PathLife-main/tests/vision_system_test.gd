## Integração do coordenador: eventos, streaming, save e codec de memória.
## Uso: godot --headless --path . --script res://tests/vision_system_test.gd
extends SceneTree

const HouseScene := preload("res://presentation/world/structures/casa_madeira_tilemap.tscn")
const HouseDefinition := preload("res://data/world/structures/casa_madeira.tres")


class FakeGridAgent:
	extends Node

	signal step_started(from_position: Vector3i, to_position: Vector3i, transition: int)
	signal step_finished(world_position: Vector3i)
	signal height_changed(level: int)


class FakePlayer:
	extends Node

	signal facing_changed(direction: StringName, logical_vector: Vector2i)

	var logical_position := Vector3i.ZERO
	var logical_facing := Vector2i(1, 0)
	var look_mouse_deadzone_pixels := 0.0
	var look_stick_deadzone := 0.0

	func world_position() -> Vector3i:
		return logical_position

	func get_facing_vector() -> Vector2i:
		return logical_facing


class FakeChunkManager:
	extends Node

	signal structure_integrated(owner_chunk: Vector2i, placement: Variant, structure: Node)
	signal structure_will_unload(owner_chunk: Vector2i, placement_id: int)

	var settings: WorldSettings


var _passed := 0
var _failed := 0
var _visibility_events := 0
var _temporary_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[VisionSystem] codec de memória")
	_test_memory_codec()
	print("\n[VisionSystem] coordenação de runtime")
	await _test_runtime_coordination()
	_cleanup()
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_memory_codec() -> void:
	var original := {
		Vector3i(-1, -1, 0): true,
		Vector3i(-16, 15, 2): true,
		Vector3i(16, 0, 0): true,
		Vector3i(31, 31, -3): true,
	}
	var packed := VisionMemoryCodec.encode_cells(original, 16)
	var decoded := VisionMemoryCodec.decode_chunks(packed, 16)
	_check(decoded == original, "round-trip preserva negativos e níveis", str(decoded))
	_check(packed.size() == 4, "células ocupam quatro chaves chunk/nível")
	var defensive := VisionMemoryCodec.duplicate_chunks(packed)
	var first_key := String(defensive.keys()[0])
	var external_bits := defensive[first_key] as PackedByteArray
	external_bits[0] = external_bits[0] ^ 0xff
	defensive[first_key] = external_bits
	_check(
		(defensive[first_key] as PackedByteArray)[0] != (packed[first_key] as PackedByteArray)[0],
		"cópia dos bitsets é defensiva"
	)


func _test_runtime_coordination() -> void:
	var host := Node.new()
	host.name = "VisionSystemProbe"
	root.add_child(host)

	var save := WorldSaveManager.new()
	save.autosave_on_exit = false
	_temporary_path = "user://__vision_system_test_%d.json" % Time.get_ticks_usec()
	save.save_path = _temporary_path
	host.add_child(save)

	var player := FakePlayer.new()
	player.name = "Player"
	var grid := FakeGridAgent.new()
	grid.name = "WorldGridAgent"
	player.add_child(grid)
	host.add_child(player)

	var manager := FakeChunkManager.new()
	manager.name = "ChunkManager"
	manager.settings = load("res://data/world/world_settings.tres")
	host.add_child(manager)

	var profile := VisionProfile.new()
	profile.maximum_range_cells = 4
	profile.front_cone_degrees = 360.0
	profile.peripheral_range_cells = 0
	profile.look_mouse_deadzone_px = 37.0
	profile.look_stick_deadzone = 0.47
	var system := VisionSystem.new()
	system.name = "VisionSystem"
	system.profile = profile
	system.visibility_changed.connect(_on_visibility_changed)
	host.add_child(system)
	await process_frame

	system.configure(player, manager, save)
	var initial := system.force_update()
	_check(initial != null and initial.origin == Vector3i.ZERO, "primeiro resultado usa posição do player")
	_check(initial.visible_cells.size() > 1, "primeiro cálculo produz campo de visão")
	_check(is_equal_approx(player.look_mouse_deadzone_pixels, 37.0), "profile configura deadzone do mouse")
	_check(is_equal_approx(player.look_stick_deadzone, 0.47), "profile configura deadzone do analógico")
	var profile_events: Array[VisionProfile] = []
	system.profile_changed.connect(func(updated: VisionProfile) -> void:
		profile_events.append(updated)
	)
	profile.look_mouse_deadzone_px = 41.0
	profile.look_stick_deadzone = 0.29
	system.apply_profile_changes()
	_check(is_equal_approx(player.look_mouse_deadzone_pixels, 41.0), "profile reaplica mouse em runtime")
	_check(is_equal_approx(player.look_stick_deadzone, 0.29), "profile reaplica analógico em runtime")
	_check(profile_events.size() == 1 and profile_events[0] == profile, "profile alterado é publicado aos presenters")
	_check(not save.seen_chunks().is_empty(), "células exploradas chegam ao save como bitset")
	var restored := VisionMemoryCodec.decode_chunks(save.seen_chunks(), manager.settings.chunk_size)
	_check(restored == system.export_memory(), "bitsets do save representam a memória do sistema")

	_visibility_events = 0
	system.invalidate(&"one")
	system.invalidate(&"two")
	system.invalidate(&"three")
	await process_frame
	_check(_visibility_events == 1, "invalidações do mesmo frame são agrupadas", str(_visibility_events))

	grid.step_started.emit(Vector3i.ZERO, Vector3i(4, -2, 1), 0)
	await process_frame
	_check(system.latest_result.origin == Vector3i(4, -2, 1), "passo iniciado antecipa célula lógica alvo")
	player.logical_position = Vector3i(4, -2, 1)
	grid.step_finished.emit(player.logical_position)
	await process_frame
	_check(system.latest_result.origin == player.logical_position, "passo concluído confirma posição")
	player.logical_facing = Vector2i(-1, 0)
	player.facing_changed.emit(&"nw", player.logical_facing)
	await process_frame
	_check(system.latest_result.facing == Vector2i(-1, 0), "mudança de direção invalida visão")

	var placement := StructurePlacement.new(HouseDefinition, Vector2i(4, -2))
	placement.foundation_height = 1
	placement.placement_id = 8844
	var house := HouseScene.instantiate() as StructureRoot
	house.setup(placement)
	host.add_child(house)
	await process_frame
	var descriptors := house.vision_portals()
	var window_descriptor: Dictionary = {}
	for descriptor: Dictionary in descriptors:
		if descriptor["kind"] == &"window":
			window_descriptor = descriptor
			break
	_check(not window_descriptor.is_empty(), "fixture contém janela restaurável")
	var portal_id := StringName(String(window_descriptor.get("id", "")))
	save.set_portal_state(portal_id, true)
	manager.structure_integrated.emit(Vector2i.ZERO, placement, house)
	_check(system.registry.has_structure(placement.placement_id), "streaming registra snapshot")
	var restored_portal := system.registry.portal(portal_id)
	_check(restored_portal != null and restored_portal.is_open, "save abre portal antes do bake")
	_check(_portal_state_in_structure(house, portal_id), "tile da estrutura também é restaurado")

	house.vision_portal_changed.emit(portal_id, false)
	_check(not system.registry.portal(portal_id).is_open, "evento de animação fecha portal lógico imediatamente")
	_check(not save.portal_state(portal_id, true), "evento de portal atualiza persistência")
	manager.structure_will_unload.emit(Vector2i.ZERO, placement.placement_id)
	_check(not system.registry.has_structure(placement.placement_id), "unload remove topologia antes do nó")

	var remembered_copy := system.export_memory()
	remembered_copy.clear()
	_check(not system.export_memory().is_empty(), "export_memory devolve cópia defensiva")
	system.clear_memory()
	_check(system.export_memory().is_empty(), "clear_memory limpa memória lógica")
	_check(save.seen_chunks().is_empty(), "clear_memory remove bitsets persistidos")

	house.queue_free()
	host.queue_free()
	await process_frame


func _portal_state_in_structure(house: StructureRoot, portal_id: StringName) -> bool:
	for descriptor: Dictionary in house.vision_portals():
		if descriptor["id"] == portal_id:
			return bool(descriptor["is_open"])
	return false


func _on_visibility_changed(_result: VisionResult) -> void:
	_visibility_events += 1


func _cleanup() -> void:
	if _temporary_path != "" and FileAccess.file_exists(_temporary_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary_path))


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

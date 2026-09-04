## Smoke test da cena real: player, streaming, fog, telhado e janela.
## Uso: godot --headless --path . --script res://tests/vision_main_integration_test.gd
extends SceneTree

var _passed := 0
var _failed := 0
var _save_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[VisionMain] integração da cena principal")
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var save := world.get_node(^"Systems/SaveManager") as WorldSaveManager
	_save_path = "user://__vision_main_test_%d.json" % Time.get_ticks_usec()
	save.save_path = _save_path
	save.autosave_on_exit = false
	root.add_child(scene)
	for _frame in 8:
		await process_frame

	var system := world.vision_system
	var presenter := world.visibility_presenter
	var player := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	var interface := scene.get_node(^"Interface") as CanvasLayer
	_check(system != null and system.profile.enabled, "VisionSystem ativo por profile")
	_check(system.latest_result != null, "primeiro VisionResult foi publicado")
	_check(system.registry.snapshots().size() > 0, "streaming registrou estruturas")
	_check(presenter.layer == 10, "fog usa CanvasLayer 10")
	_check(interface.layer == 20, "interface permanece acima no CanvasLayer 20")
	_check(presenter.mask_texture() != null, "máscara global possui render target")

	var target := _window_test_target(system)
	_check(not target.is_empty(), "streaming contém interior com janela externa")
	if not target.is_empty():
		var inside: Vector3i = target["inside"]
		player.grid_agent.teleport_to(Vector2i(inside.x, inside.y))
		for _frame in 3:
			await process_frame
		system.force_update()
	var player_position := player.world_position()
	var context := system.registry.internal_context_at(player_position)
	_check(not context.is_empty(), "player teleportado é reconhecido numa zona interna")
	if not context.is_empty():
		var snapshot := target["snapshot"] as StructureVisionSnapshot
		var placement_id := snapshot.placement_id
		var result := system.latest_result
		_check(
			result.visible_interior_by_structure.has(placement_id),
			"resultado separa interior por estrutura"
		)
		_check(result.forced_hidden_cells.size() > 0, "casa fechada força ocultação exterior")
		var structure := _structure_for_placement(placement_id)
		_check(structure != null, "instância visual da estrutura é localizada")
		if structure != null:
			var roof_controller := structure.get_node_or_null(^"VisionRoofReveal") as RoofRevealController
			_check(roof_controller != null, "telhado recebeu controlador local")
			var local_player := snapshot.world_to_local_cell(player_position)
			_check(
				roof_controller != null and roof_controller.is_local_cell_revealed(local_player),
				"telhado recorta a célula interna visível do player"
			)
			await _test_window_open_close(
				system,
				structure,
				snapshot,
				int(context["zone_id"]),
				target["portal"] as VisionPortal
			)

	scene.queue_free()
	await process_frame
	_cleanup()
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_window_open_close(
	system: VisionSystem,
	structure: StructureRoot,
	snapshot: StructureVisionSnapshot,
	zone_id: int,
	selected: VisionPortal
) -> void:
	_check(selected != null, "cômodo inicial possui janela para o exterior")
	if selected == null:
		return
	var outside := selected.cell_b if snapshot.is_internal_cell(selected.cell_a) else selected.cell_a
	var previous_cone := system.profile.front_cone_degrees
	system.profile.front_cone_degrees = 360.0
	_check(structure.set_vision_portal_open(selected.id, true), "janela abre no tile estático")
	structure.vision_portal_changed.emit(selected.id, true)
	var opened := system.force_update()
	_check(system.registry.can_zone_reach_exterior(snapshot.placement_id, zone_id), "janela aberta conecta zona ao exterior")
	_check(opened.is_visible(outside), "player vê a primeira célula externa pela janela")
	_check(opened.traversed_portal_ids.has(selected.id), "raycast registra a janela atravessada")

	_check(structure.set_vision_portal_open(selected.id, false), "janela fecha no tile estático")
	structure.vision_portal_changed.emit(selected.id, false)
	var closed := system.force_update()
	_check(not closed.is_visible(outside), "fechar janela oculta exterior imediatamente")
	_check(
		closed.state_at(outside) == VisionState.FORCED_HIDDEN,
		"exterior recém-visto não reaparece como memória através da casa fechada"
	)
	system.profile.front_cone_degrees = previous_cone


func _window_test_target(system: VisionSystem) -> Dictionary:
	for snapshot: StructureVisionSnapshot in system.registry.snapshots():
		for portal: VisionPortal in snapshot.portals.values():
			if portal.kind != &"window":
				continue
			var inside := portal.cell_a if snapshot.is_internal_cell(portal.cell_a) else portal.cell_b
			var outside := portal.cell_b if inside == portal.cell_a else portal.cell_a
			if not snapshot.is_internal_cell(inside) or snapshot.is_internal_cell(outside):
				continue
			return {
				"snapshot": snapshot,
				"portal": portal,
				"inside": inside,
			}
	return {}


func _structure_for_placement(placement_id: int) -> StructureRoot:
	for node: Node in get_nodes_in_group(StructureRoot.STRUCTURE_GROUP):
		var structure := node as StructureRoot
		if (
			structure != null
			and structure.placement() != null
			and structure.placement().placement_id == placement_id
		):
			return structure
	return null


func _cleanup() -> void:
	if _save_path != "" and FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

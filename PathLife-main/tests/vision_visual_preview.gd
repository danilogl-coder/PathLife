## Gera uma captura determinística da visão pela janela na cena principal.
##
## Uso:
##   godot --headless --path . --script res://tests/vision_visual_preview.gd -- \
##     --size=1280x720 --output=user://vision_preview_720p.png
extends SceneTree

var _requested_size := Vector2i(1280, 720)
var _output_path := "user://vision_preview.png"
var _save_path := ""


func _init() -> void:
	_parse_arguments()
	_capture.call_deferred()


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--size="):
			var dimensions := argument.trim_prefix("--size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(
					maxi(1, int(dimensions[0])),
					maxi(1, int(dimensions[1]))
				)
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")


func _capture() -> void:
	root.size = _requested_size
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var save := world.get_node(^"Systems/SaveManager") as WorldSaveManager
	_save_path = "user://__vision_preview_%d.json" % Time.get_ticks_usec()
	save.save_path = _save_path
	save.autosave_on_exit = false
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	for _frame in 10:
		await process_frame

	var system := world.vision_system
	var player := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	var target := _window_test_target(system)
	if target.is_empty():
		_fail("Nenhuma janela exterior ligada a uma zona interna foi encontrada.")
		return
	var snapshot := target["snapshot"] as StructureVisionSnapshot
	var portal := target["portal"] as VisionPortal
	var inside: Vector3i = target["inside"]
	var structure := _structure_for_placement(snapshot.placement_id)
	if structure == null:
		_fail("A instância visual da estrutura selecionada não foi encontrada.")
		return

	player.grid_agent.teleport_to(Vector2i(inside.x, inside.y))
	system.profile.front_cone_degrees = 360.0
	system.profile.transition_seconds = 0.0
	if not structure.set_vision_portal_open(portal.id, true):
		_fail("Não foi possível abrir a janela selecionada.")
		return
	structure.vision_portal_changed.emit(portal.id, true)
	system.force_update()
	for _frame in 12:
		await process_frame

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("O driver atual não disponibilizou pixels do viewport.")
		return
	if image.get_size() != _requested_size:
		_fail(
			"Viewport retornou %s; esperado %s."
			% [image.get_size(), _requested_size]
		)
		return
	var error := image.save_png(_output_path)
	if error != OK:
		_fail("Falha %d ao salvar %s." % [error, _output_path])
		return
	_cleanup(scene)
	print(
		"VISION PREVIEW %dx%d: %s"
		% [
			_requested_size.x,
			_requested_size.y,
			ProjectSettings.globalize_path(_output_path),
		]
	)
	quit(0)


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


func _cleanup(scene: Node) -> void:
	scene.queue_free()
	if _save_path != "" and FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _fail(message: String) -> void:
	printerr("VISION PREVIEW FALHOU: ", message)
	if _save_path != "" and FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	quit(1)

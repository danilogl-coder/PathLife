## Captura todos os quadros de um passo plano para diagnosticar cintilação.
## Uso (com driver gráfico):
##   godot --path . --resolution 640x360 \
##     --script res://tests/character_walk_flicker_preview.gd
extends SceneTree

const WORLD_OUTPUT := "user://character_walk_world_frames.png"
const RIG_OUTPUT := "user://character_walk_rig_frames.png"
const WORLD_CROP := Vector2i(96, 112)

var _world_frames: Array[Image] = []
var _rig_frames: Array[Image] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var player := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	var agent := player.grid_agent
	var composite := player.get_node(^"VisualAnchor") as CharacterViewportComposite
	for frame in 90:
		await process_frame

	var start := Vector2i.ZERO
	var direction := Vector2i.ZERO
	var found := false
	for y in range(-10, 11):
		for x in range(-10, 11):
			var cell := Vector2i(x, y)
			for candidate: Vector2i in [
				Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			]:
				if (
					_is_flat_and_clear(world.world_data(), cell)
					and _is_flat_and_clear(world.world_data(), cell + candidate)
					and MovementRules.evaluate_world(
					world.world_data(), cell, cell + candidate, agent.movement_context
					) == MovementRules.MovementTransition.WALK
				):
					start = cell
					direction = candidate
					found = true
					break
			if found:
				break
		if found:
			break
	if not found:
		printerr("FLICKER PREVIEW FAIL: sem passo plano")
		quit(1)
		return

	agent.respect_physics_obstacles = false
	agent.cells_per_second = 1.0
	agent.teleport_to(start)
	for frame in 12:
		await process_frame
	var transition := agent.request_step(direction)
	if transition == MovementRules.MovementTransition.BLOCKED:
		printerr("FLICKER PREVIEW FAIL: passo bloqueado")
		quit(1)
		return

	var guard := 0
	while agent.is_moving() and guard < 120:
		await process_frame
		_capture(composite)
		guard += 1
	if _world_frames.is_empty() or _rig_frames.is_empty():
		printerr("FLICKER PREVIEW FAIL: nenhuma captura")
		quit(1)
		return
	_save_sheet(_world_frames, WORLD_CROP, WORLD_OUTPUT)
	_save_sheet(_rig_frames, composite.character_viewport.size, RIG_OUTPUT)
	print("FLICKER WORLD: ", ProjectSettings.globalize_path(WORLD_OUTPUT))
	print("FLICKER RIG: ", ProjectSettings.globalize_path(RIG_OUTPUT))
	print("FLICKER FRAMES: ", _world_frames.size(), " direction=", direction)
	quit(0)


func _capture(composite: CharacterViewportComposite) -> void:
	var world_image := root.get_texture().get_image()
	var rig_image := composite.character_viewport.get_texture().get_image()
	if world_image == null or rig_image == null:
		return
	var origin := (world_image.get_size() - WORLD_CROP) / 2
	_world_frames.append(world_image.get_region(Rect2i(origin, WORLD_CROP)))
	_rig_frames.append(rig_image.duplicate())


func _save_sheet(frames: Array[Image], frame_size: Vector2i, path: String) -> void:
	var columns := 10
	var rows := ceili(float(frames.size()) / float(columns))
	var sheet := Image.create_empty(
		frame_size.x * columns, frame_size.y * rows, false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color.TRANSPARENT)
	for index in frames.size():
		sheet.blit_rect(
			frames[index], Rect2i(Vector2i.ZERO, frame_size),
			Vector2i((index % columns) * frame_size.x, (index / columns) * frame_size.y)
		)
	var error := sheet.save_png(path)
	if error != OK:
		printerr("FLICKER PREVIEW FAIL: erro ", error, " em ", path)


func _is_flat_and_clear(data: WorldData, center: Vector2i) -> bool:
	var level := data.height_at(center)
	for y in range(-2, 3):
		for x in range(-2, 3):
			if data.height_at(center + Vector2i(x, y)) != level:
				return false
	for coord: Vector2i in data.loaded_chunk_coords():
		var chunk := data.get_chunk(coord)
		for decoration: DecorationPlacement in chunk.decorations:
			var decoration_xy := Vector2i(decoration.world_pos.x, decoration.world_pos.y)
			if decoration_xy.distance_squared_to(center) <= 9:
				return false
		for structure: StructurePlacement in chunk.structures:
			if structure.rect().grow(2).has_point(center):
				return false
	return true

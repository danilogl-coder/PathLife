## Caminhada visual de regressão pelo mundo procedural.
##
## Executar com driver gráfico:
##   godot --path . --resolution 640x360 \
##     --script res://tests/world_roaming_visual_test.gd
extends SceneTree

const TOTAL_STEPS := 512
const CAPTURE_INTERVAL := 64
const OUTPUT := "user://world_roaming_contact_sheet.png"

var _captures: Array[Image] = []
var _positions: Array[Vector3i] = []


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
	# Mantém pelo menos um frame por transição, mas conclui os 512 passos antes
	# do watchdog do executor gráfico. Isto altera somente este teste.
	agent.cells_per_second = 40.0
	agent.respect_physics_obstacles = false

	for frame in 90:
		await process_frame
	if not agent.is_active():
		printerr("ROAM FAIL: agente inativo")
		quit(1)
		return

	_capture(agent)
	var visits: Dictionary = {agent.cell(): 1}
	var completed := 0
	for step in TOTAL_STEPS:
		var direction := _pick_direction(agent, world.world_data(), visits, step)
		if direction == Vector2i.ZERO:
			printerr("ROAM FAIL: sem vizinho válido em ", agent.world_position())
			quit(1)
			return
		var transition := agent.request_step(direction)
		if transition == MovementRules.MovementTransition.BLOCKED:
			printerr("ROAM FAIL: direção previamente válida foi bloqueada")
			quit(1)
			return
		var guard := 0
		while agent.is_moving() and guard < 120:
			await process_frame
			guard += 1
		if agent.is_moving():
			printerr("ROAM FAIL: passo não terminou")
			quit(1)
			return
		completed += 1
		visits[agent.cell()] = int(visits.get(agent.cell(), 0)) + 1
		if completed % CAPTURE_INTERVAL == 0:
			for frame in 3:
				await process_frame
			_capture(agent)

	for frame in 120:
		await process_frame
	var manager := world.chunk_manager
	if manager.views().size() != manager.world.loaded_chunk_coords().size():
		printerr("ROAM FAIL: views e chunks divergiram após streaming")
		quit(1)
		return
	var actual_tile_layers := 0
	for child in world.ground_root.get_children():
		if child is TileMapLayer:
			actual_tile_layers += 1
	for child in world.depth_root.get_children():
		if child is TileMapLayer:
			actual_tile_layers += 1
	var unique_layer_keys: Dictionary = {}
	for child in world.ground_root.get_children():
		if child is TileMapLayer:
			var key := "%s:%d" % [
				child.get_meta(&"world_render_class", ""),
				int(child.get_meta(&"world_level", 0)),
			]
			if unique_layer_keys.has(key):
				printerr("ROAM FAIL: layer global duplicado: ", key)
				quit(1)
				return
			unique_layer_keys[key] = true
	for child in world.depth_root.get_children():
		if child is TileMapLayer:
			var key := "%s:%d" % [
				child.get_meta(&"world_render_class", ""),
				int(child.get_meta(&"world_level", 0)),
			]
			if unique_layer_keys.has(key):
				printerr("ROAM FAIL: layer global duplicado: ", key)
				quit(1)
				return
			unique_layer_keys[key] = true
	if actual_tile_layers != unique_layer_keys.size():
		printerr(
			"ROAM FAIL: registro de layers inconsistente: ",
			actual_tile_layers, " != ", unique_layer_keys.size()
		)
		quit(1)
		return
	_save_contact_sheet()
	print(
		"ROAM OK: ", completed, " passos, ", actual_tile_layers,
		" layers ativos, posições ", _positions
	)
	print("ROAM PREVIEW: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _pick_direction(
	agent: WorldGridAgent,
	world: WorldData,
	visits: Dictionary,
	step: int
) -> Vector2i:
	# Quatro fases empurram o percurso para leste, sul, oeste e norte. Dentro
	# de cada fase, a célula menos visitada ganha para evitar ficar oscilando.
	var phase := (step / 128) % 4
	var priorities: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)
	]
	priorities = priorities.slice(phase) + priorities.slice(0, phase)
	var candidates: Array[Vector2i] = []
	for direction in priorities:
		var target := agent.cell() + direction
		var transition := MovementRules.evaluate_world(
			world, agent.cell(), target, agent.movement_context
		)
		if transition != MovementRules.MovementTransition.BLOCKED:
			candidates.append(direction)
	if candidates.is_empty():
		return Vector2i.ZERO
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(visits.get(agent.cell() + a, 0)) < int(visits.get(agent.cell() + b, 0))
	)
	return candidates[0]


func _capture(agent: WorldGridAgent) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		return
	_captures.append(image.duplicate())
	_positions.append(agent.world_position())


func _save_contact_sheet() -> void:
	if _captures.is_empty():
		printerr("ROAM FAIL: nenhuma captura disponível")
		return
	var columns := 3
	var rows := ceili(float(_captures.size()) / float(columns))
	var width := _captures[0].get_width()
	var height := _captures[0].get_height()
	var sheet := Image.create_empty(width * columns, height * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.04, 0.04, 0.04, 1.0))
	for index in _captures.size():
		var destination := Vector2i((index % columns) * width, (index / columns) * height)
		sheet.blit_rect(
			_captures[index],
			Rect2i(Vector2i.ZERO, _captures[index].get_size()),
			destination
		)
	var error := sheet.save_png(OUTPUT)
	if error != OK:
		printerr("ROAM FAIL: não salvou contact sheet, erro ", error)

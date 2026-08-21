## Renderiza a cena principal para inspeção da oclusão Ground/Depth.
## Uso:
##   godot --path . --script res://tests/world_depth_preview.gd
## Requer um driver de vídeo porque lê os pixels do viewport.
extends SceneTree

const OUTPUT := "user://world_depth_preview.png"
const CROP_SIZE := Vector2i(240, 240)

var _captures: Array[Image] = []


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	for frame in 60:
		await process_frame
	var world := scene.get_node_or_null(^"World/ProceduralWorld") as ProceduralWorld
	var player := scene.get_node_or_null(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	if world != null and player != null:
		var agent := player.grid_agent
		var data := world.world_data()
		var start := Vector2i.ZERO
		var target := Vector2i.ZERO
		var found := false
		# Procura um degrau real de um nível. A subida cruza horizontalmente a
		# face durante a interpolação, reproduzindo a sobreposição das imagens de
		# referência em vez de validar apenas centros de células.
		for y in range(-12, 13):
			for x in range(-12, 13):
				var cliff := Vector2i(x, y)
				# Vizinho frontal esquerdo: subir dele até `cliff` desloca o
				# personagem para a direita, como na comparação image1 -> image2.
				var lower := cliff + Vector2i(0, 1)
				if (
					data.height_at(cliff) == data.height_at(lower) + 1
					and MovementRules.evaluate_world(
						data, lower, cliff, agent.movement_context
					) == MovementRules.MovementTransition.STEP_UP
				):
					start = lower
					target = cliff
					found = true
					break
			if found:
				break
		if found:
			agent.respect_physics_obstacles = false
			agent.cells_per_second = 0.75
			agent.teleport_to(start)
			for frame in 12:
				await process_frame
			_capture_center()
			var transition := agent.request_step(target - start)
			if transition == MovementRules.MovementTransition.BLOCKED:
				printerr("A subida de teste foi bloqueada.")
				quit(1)
				return
			var anchor := player.get_parent() as Node2D
			var iso := IsoCoordinateSystem.from_settings(world.chunk_manager.settings)
			var from_sort := iso.cell_to_local(start) + Vector2(0.0, iso.prop_sort_bias())
			var to_sort := iso.cell_to_local(target) + Vector2(0.0, iso.prop_sort_bias())
			var distance := from_sort.distance_to(to_sort)
			var thresholds: Array[float] = [0.25, 0.5, 0.75, 0.99]
			var threshold_index := 0
			while agent.is_moving():
				await process_frame
				var progress := anchor.position.distance_to(from_sort) / distance
				if (
					threshold_index < thresholds.size()
					and progress >= thresholds[threshold_index]
				):
					_capture_center()
					threshold_index += 1
			while _captures.size() < 5:
				_capture_center()
			print("SUBIDA NA FACE: ", start, " -> ", target)
		else:
			printerr("Não foi encontrado degrau adequado para o preview.")
			quit(1)
			return
	if _captures.is_empty():
		printerr("Preview requer execução com driver de vídeo (sem --headless).")
		quit(1)
		return
	var sheet := Image.create_empty(
		CROP_SIZE.x * _captures.size(), CROP_SIZE.y, false, Image.FORMAT_RGBA8
	)
	for index in _captures.size():
		sheet.blit_rect(
			_captures[index],
			Rect2i(Vector2i.ZERO, CROP_SIZE),
			Vector2i(index * CROP_SIZE.x, 0)
		)
	var error := sheet.save_png(OUTPUT)
	if error != OK:
		printerr("Falha ao salvar preview: ", error)
		quit(1)
		return
	print("DEPTH PREVIEW: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _capture_center() -> void:
	var image := root.get_texture().get_image()
	if image == null:
		return
	var origin := (image.get_size() - CROP_SIZE) / 2
	_captures.append(image.get_region(Rect2i(origin, CROP_SIZE)))

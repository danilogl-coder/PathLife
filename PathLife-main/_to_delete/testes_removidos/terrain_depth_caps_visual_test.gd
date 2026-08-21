## Compara a composição nova (Ground -1 + DepthCaps) com a referência que já
## não recortava o terreno (Ground/Depth juntos em z 0).
##
## Requer driver gráfico:
##   godot --path . --resolution 640x360 \
##     --script res://tests/terrain_depth_caps_visual_test.gd
extends SceneTree

const OUTPUT := "user://terrain_depth_caps_comparison.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var player_visual := scene.get_node_or_null(
		^"World/DepthSort/Entities/PlayerAnchor/Player/VisualAnchor"
	) as CanvasItem
	if player_visual != null:
		player_visual.visible = false
	for frame in 60:
		await process_frame
	var player := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	var data := world.world_data()
	var lower_cell := Vector2i.ZERO
	var found_cliff := false
	for y in range(-12, 13):
		for x in range(-12, 13):
			var rear := Vector2i(x, y)
			var front := rear + Vector2i(0, 1)
			if data.height_at(rear) > data.height_at(front):
				lower_cell = front
				found_cliff = true
				break
		if found_cliff:
			break
	if not found_cliff:
		printerr("CAP VISUAL FAIL: nenhum penhasco na amostra")
		quit(1)
		return
	player.grid_agent.teleport_to(lower_cell)
	for frame in 20:
		await process_frame
	# Objetos animados não pertencem a esta comparação. A câmera continua ativa
	# dentro de Entities; apenas os props irmãos são escondidos.
	for child in world.depth_root.get_children():
		if child is CanvasItem and not child is TileMapLayer and child.name != &"Entities":
			(child as CanvasItem).visible = false
	await process_frame

	var cap_layers: Array[TileMapLayer] = []
	for child in world.depth_root.get_children():
		if child is TileMapLayer and child.get_meta(&"world_render_class", "") == "DepthCap":
			cap_layers.append(child)
	if cap_layers.is_empty():
		printerr("CAP VISUAL FAIL: nenhuma DepthCap ativa")
		quit(1)
		return

	# Nova composição, que mantém o piso fora da disputa com as pernas.
	RenderingServer.force_draw()
	var caps_image := root.get_texture().get_image()
	if caps_image == null:
		printerr("CAP VISUAL FAIL: viewport sem imagem")
		quit(1)
		return
	caps_image = caps_image.duplicate()

	# Referência visual: todas as superfícies e faces no mesmo Z, arquitetura que
	# fechava o terreno mas fazia o Ground engolir as pernas. Como uma superfície
	# pertence OU a Ground OU a DepthCap, as caps continuam visíveis aqui.
	world.ground_root.z_index = 0
	RenderingServer.force_draw()
	var reference_image := root.get_texture().get_image()
	if reference_image == null:
		printerr("CAP VISUAL FAIL: referência sem imagem")
		quit(1)
		return
	reference_image = reference_image.duplicate()

	# Controle negativo: reproduz deliberadamente o bug relatado colocando
	# também as tampas atrás das faces. As células continuam desenhadas, porém o
	# Z é resolvido antes do Y-Sort e as faixas atravessam seus topos.
	world.ground_root.z_index = -1
	for layer in cap_layers:
		layer.z_index = -1
	RenderingServer.force_draw()
	var broken_image := root.get_texture().get_image()
	if broken_image == null:
		printerr("CAP VISUAL FAIL: controle negativo sem imagem")
		quit(1)
		return
	broken_image = broken_image.duplicate()

	for layer in cap_layers:
		layer.z_index = 0
	RenderingServer.force_draw()
	var caps_difference := _difference(caps_image, reference_image)
	var broken_difference := _difference(broken_image, reference_image)

	var sheet := Image.create_empty(
		caps_image.get_width() * 5, caps_image.get_height(), false, Image.FORMAT_RGBA8
	)
	sheet.blit_rect(
		caps_image, Rect2i(Vector2i.ZERO, caps_image.get_size()), Vector2i.ZERO
	)
	sheet.blit_rect(
		reference_image, Rect2i(Vector2i.ZERO, reference_image.get_size()),
		Vector2i(caps_image.get_width(), 0)
	)
	sheet.blit_rect(
		broken_image, Rect2i(Vector2i.ZERO, broken_image.get_size()),
		Vector2i(caps_image.get_width() * 2, 0)
	)
	sheet.blit_rect(
		caps_difference.image, Rect2i(Vector2i.ZERO, caps_difference.image.get_size()),
		Vector2i(caps_image.get_width() * 3, 0)
	)
	sheet.blit_rect(
		broken_difference.image, Rect2i(Vector2i.ZERO, broken_difference.image.get_size()),
		Vector2i(caps_image.get_width() * 4, 0)
	)
	sheet.save_png(OUTPUT)
	print(
		"CAP PREVIEW: caps=", caps_difference.pixels,
		" pixels/run=", caps_difference.max_run, " erro=", caps_difference.error,
		"; quebrado=", broken_difference.pixels,
		" pixels/run=", broken_difference.max_run, " erro=", broken_difference.error, "; ",
		ProjectSettings.globalize_path(OUTPUT)
	)
	await process_frame
	# A prova automática da relação de ordem fica nos testes de lógica e
	# integração. Este arquivo é deliberadamente um contact sheet para inspeção
	# humana, pois os tiles animados avançam entre as três leituras.
	quit(0)


func _difference(image_a: Image, image_b: Image) -> Dictionary:
	var different_pixels := 0
	var maximum_horizontal_run := 0
	var total_error := 0.0
	var difference_image := Image.create_empty(
		image_a.get_width(), image_a.get_height(), false, Image.FORMAT_RGBA8
	)
	difference_image.fill(Color.TRANSPARENT)
	for y in image_a.get_height():
		var horizontal_run := 0
		for x in image_a.get_width():
			var color_a := image_a.get_pixel(x, y)
			var color_b := image_b.get_pixel(x, y)
			var difference := (
				absf(color_a.r - color_b.r)
				+ absf(color_a.g - color_b.g)
				+ absf(color_a.b - color_b.b)
				+ absf(color_a.a - color_b.a)
			)
			total_error += difference
			if difference > 0.08:
				different_pixels += 1
				horizontal_run += 1
				maximum_horizontal_run = maxi(maximum_horizontal_run, horizontal_run)
				difference_image.set_pixel(x, y, Color.RED)
			else:
				horizontal_run = 0
	return {
		"pixels": different_pixels,
		"max_run": maximum_horizontal_run,
		"error": total_error,
		"image": difference_image,
	}

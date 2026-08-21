## Mede, em pixels, por que piso e faces ficam no MESMO Z.
##
## Toda vez que alguém deu um `z_index` próprio ao piso, a intenção foi proteger
## as pernas do personagem — e o efeito colateral foi o terreno recortado. Este
## teste mede as duas coisas de uma vez, com render de verdade:
##
##   1. quantos pixels do personagem sobrevivem à composição, nos dois arranjos;
##   2. quanto o terreno muda quando o piso sai do Z comum.
##
## Requer driver gráfico:
##   godot --path . --resolution 400x300 \
##     --script res://tests/terrain_depth_composition_test.gd
extends SceneTree

const OUTPUT := "user://terrain_depth_composition.png"

var _passed := 0
var _failed := 0


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s %s" % [label, detail])
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	for name in ["TestBedAnchor", "BedAnchor", "Bed2Anchor", "Bed3Anchor", "TestWallAnchor"]:
		var node := scene.get_node_or_null(NodePath("World/DepthSort/Entities/" + name))
		if node != null:
			node.queue_free()
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var player := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	var visual := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player/VisualAnchor"
	) as CanvasItem
	var camera := scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player/Camera2D"
	) as Camera2D
	camera.zoom = Vector2(2.0, 2.0)
	var agent := player.grid_agent
	agent.respect_physics_obstacles = false
	for frame in 150:
		await process_frame

	print("\n[Composição] piso e faces no mesmo Z")
	_check(world.ground_root.z_index == world.depth_root.z_index,
		"o jogo roda com piso e faces no mesmo Z",
		"ground=%d depth=%d" % [world.ground_root.z_index, world.depth_root.z_index])

	# Três situações: plano, degrau descendo à frente, degrau subindo atrás.
	var data := world.world_data()
	var spots: Array[Vector2i] = []
	for radius in range(1, 26):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := Vector2i(x, y)
				var height := data.height_at(cell)
				if spots.size() < 1 and height == data.height_at(cell + Vector2i(1, 1)) \
					and height == data.height_at(cell - Vector2i(1, 1)):
					spots.append(cell)
				if spots.size() < 2 and data.height_at(cell + Vector2i(1, 1)) == height - 1:
					spots.append(cell)
				if spots.size() < 3 and data.height_at(cell - Vector2i(1, 1)) == height + 1:
					spots.append(cell)
		if spots.size() >= 3:
			break
	while spots.size() < 3:
		spots.append(Vector2i.ZERO)

	# As quatro leituras de cada ponto acontecem SEM avançar quadro: só
	# `force_draw()`. Assim a grama está exatamente na mesma fase nas duas
	# composições, e o que sobra na conta é composição, não animação.
	var visible_together := 0
	var visible_split := 0
	var terrain_shift := 0
	var shots: Array[Image] = []
	for spot in spots:
		agent.teleport_to(spot)
		for frame in 8:
			await process_frame

		world.ground_root.z_index = 0
		visual.visible = true
		RenderingServer.force_draw()
		var together_actor := root.get_texture().get_image().duplicate()
		visual.visible = false
		RenderingServer.force_draw()
		var together_terrain := root.get_texture().get_image().duplicate()

		world.ground_root.z_index = -1
		RenderingServer.force_draw()
		var split_terrain := root.get_texture().get_image().duplicate()
		visual.visible = true
		RenderingServer.force_draw()
		var split_actor := root.get_texture().get_image().duplicate()

		world.ground_root.z_index = 0
		visible_together += _difference(together_actor, together_terrain)
		visible_split += _difference(split_actor, split_terrain)
		terrain_shift += _difference(split_terrain, together_terrain)
		shots.append(together_terrain)

	# É uma troca, e é ela que o teste registra em números.
	#
	# Com o piso no Z comum o ator perde alguns pixels: a grama da célula da
	# frente encosta nos pés dele — o que é PROFUNDIDADE CORRETA, não defeito.
	# Tirar o piso do Z comum devolve esses pixels e, em troca, quebra o terreno
	# inteiro. O custo tem de ser pequeno perto do estrago.
	var actor_cost := maxi(0, visible_split - visible_together)
	_check(actor_cost < int(float(visible_split) * 0.05),
		"o piso no Z comum custa POUCO do personagem",
		"%d px de %d (%.1f%%)" % [
			actor_cost, visible_split, 100.0 * float(actor_cost) / float(visible_split)
		])
	_check(terrain_shift > actor_cost * 10,
		"e o estrago no terreno seria muito maior que esse custo",
		"terreno %d px vs ator %d px" % [terrain_shift, actor_cost])

	if not shots.is_empty():
		var width := shots[0].get_width()
		var height := shots[0].get_height()
		var sheet := Image.create_empty(
			width * shots.size(), height, false, shots[0].get_format()
		)
		for index in shots.size():
			sheet.blit_rect(
				shots[index], Rect2i(Vector2i.ZERO, shots[index].get_size()),
				Vector2i(index * width, 0)
			)
		sheet.save_png(OUTPUT)
		print("  preview: ", ProjectSettings.globalize_path(OUTPUT))

	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _difference(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count

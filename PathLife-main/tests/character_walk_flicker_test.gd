## Mede a CINTILAÇÃO das pernas durante um passo, com render de verdade.
##
## O método é comparativo, para não depender de um limiar inventado: a mesma
## caminhada é medida duas vezes — com o mundo visível e com o mundo escondido.
## A segunda medição é a variação da PRÓPRIA animação (braço e perna mudam a
## silhueta a cada quadro) e serve de linha de base.
##
## O sinal principal é o MÍNIMO de pixels visíveis no passo: cintilar é o
## personagem afundar atrás do tile de destino e reaparecer de uma vez. Com o
## viés errado esse mínimo cai para ~55% da linha de base; com o viés certo fica
## em ~99%. É uma separação grande o bastante para o teste não depender de sorte
## de amostragem. O salto entre quadros entra como reforço, com folga larga.
##
## Requer driver gráfico:
##   godot --path . --resolution 320x240 \
##     --script res://tests/character_walk_flicker_test.gd
extends SceneTree

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
## Quanto do rig pode ficar escondido no pior quadro do passo, comparado com a
## mesma caminhada sem mundo. 0.85 = pode perder 15% para a grama.
const MINIMUM_RATIO := 0.85
## Folga do salto entre quadros sobre o que a animação já faz sozinha.
const JUMP_TOLERANCE := 2.5

var _passed := 0
var _failed := 0
var _scene: Node
var _agent: WorldGridAgent
var _visual: CanvasItem
var _ground: Node2D
var _depth: Node2D


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
	_scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_scene)
	var interface := _scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	var world := _scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var player := _scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player"
	) as PlayerController
	_visual = _scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player/VisualAnchor"
	) as CanvasItem
	_ground = _scene.get_node(^"World/GroundRoot") as Node2D
	_depth = _scene.get_node(^"World/DepthSort") as Node2D
	var camera := _scene.get_node(
		^"World/DepthSort/Entities/PlayerAnchor/Player/Camera2D"
	) as Camera2D
	camera.zoom = Vector2(2.0, 2.0)
	_agent = player.grid_agent
	_agent.respect_physics_obstacles = false
	_agent.cells_per_second = 2.0
	for frame in 150:
		await process_frame

	var start := _flat_spot(world.world_data())
	print("\n[Cintilação] passo plano em ", start)

	var with_world: Dictionary = {}
	for direction in DIRECTIONS:
		with_world[direction] = await _walk(start, direction)
	_set_world_visible(false)
	var rig_only: Dictionary = {}
	for direction in DIRECTIONS:
		rig_only[direction] = await _walk(start, direction)
	_set_world_visible(true)

	# A animação é a mesma em qualquer sentido: o pior caso dela serve de base
	# para os quatro, e isso tira a sorte de qual quadro caiu na amostragem.
	var rig_jump := 0
	for direction in DIRECTIONS:
		rig_jump = maxi(rig_jump, int(rig_only[direction]["jump"]))
	for direction in DIRECTIONS:
		var minimum: int = with_world[direction]["min"]
		var base: int = rig_only[direction]["min"]
		var floor_value := int(float(base) * MINIMUM_RATIO)
		_check(minimum >= floor_value,
			"passo %s: o ator nao afunda atras do tile" % direction,
			"pior quadro %d px de %d sem mundo (piso %d)" % [minimum, base, floor_value])
		var world_jump: int = with_world[direction]["jump"]
		var limit := int(float(rig_jump) * JUMP_TOLERANCE)
		_check(world_jump <= limit,
			"passo %s sem pulo de profundidade" % direction,
			"salto %d px, animacao %d px, teto %d" % [world_jump, rig_jump, limit])

	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Célula com vizinhança plana, para o passo não medir degrau.
func _flat_spot(data: WorldData) -> Vector2i:
	for radius in range(1, 24):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := Vector2i(x, y)
				var flat := true
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						if data.height_at(cell + Vector2i(dx, dy)) != data.height_at(cell):
							flat = false
				if flat:
					return cell
	return Vector2i.ZERO


func _set_world_visible(value: bool) -> void:
	_ground.visible = value
	for child in _depth.get_children():
		if child is TileMapLayer:
			(child as CanvasItem).visible = value


func _walk(start: Vector2i, direction: Vector2i) -> Dictionary:
	_agent.teleport_to(start)
	for frame in 10:
		await process_frame
	_agent.request_step(direction)
	var counts: Array[int] = []
	var guard := 0
	while _agent.is_moving() and guard < 200:
		await process_frame
		guard += 1
		counts.append(_visible_actor_pixels())
	var jump := 0
	var minimum := counts[0] if not counts.is_empty() else 0
	for index in counts.size():
		minimum = mini(minimum, counts[index])
		if index > 0:
			jump = maxi(jump, absi(counts[index] - counts[index - 1]))
	return {"jump": jump, "min": minimum, "frames": counts.size()}


## Quantos pixels da tela pertencem ao ator, agora.
func _visible_actor_pixels() -> int:
	_visual.visible = true
	RenderingServer.force_draw()
	var with_actor := root.get_texture().get_image()
	_visual.visible = false
	RenderingServer.force_draw()
	var without := root.get_texture().get_image()
	_visual.visible = true
	var count := 0
	for y in with_actor.get_height():
		for x in with_actor.get_width():
			if with_actor.get_pixel(x, y) != without.get_pixel(x, y):
				count += 1
	return count

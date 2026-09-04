## Valida a regra genérica: móveis não bloqueiam antecipadamente a varredura
## entre células, mas o SolidCollision continua bloqueando o destino ocupado.
extends SceneTree

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var player := CharacterBody2D.new()
	player.collision_layer = 2
	player.collision_mask = 9 # World (1) + Furniture (8)
	var player_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 10.0
	player_shape.position = Vector2(0.0, -5.0)
	player_shape.shape = capsule
	player.add_child(player_shape)
	stage.add_child(player)
	var agent := WorldGridAgent.new()
	player.add_child(agent)

	var furniture := _make_obstacle(8, Vector2(18.0, -12.0), Vector2(16.0, 16.0))
	stage.add_child(furniture)
	await physics_frame
	await physics_frame

	# O móvel toca o começo do trajeto diagonal, mas não ocupa o destino.
	_expect(
		not agent._is_physically_blocked(Vector2(64.0, 32.0)),
		"Furniture fora do destino não deve cancelar o passo inteiro."
	)

	# No destino, o mesmo collider precisa continuar sendo um obstáculo real.
	furniture.position = Vector2(64.0, 32.0)
	await physics_frame
	_expect(
		agent._is_physically_blocked(Vector2(64.0, 32.0)),
		"Furniture sobre o destino precisa bloquear pela colisão real."
	)

	# Uma parede mantém a regra rígida e bloqueia mesmo no meio do percurso.
	furniture.position = Vector2(500.0, 500.0)
	var wall := _make_obstacle(1, Vector2(32.0, 16.0), Vector2(12.0, 80.0))
	stage.add_child(wall)
	await physics_frame
	_expect(
		agent._is_physically_blocked(Vector2(64.0, 32.0)),
		"World precisa continuar bloqueando durante toda a varredura."
	)
	_expect(player.collision_mask == 9, "A máscara física do Player precisa ser restaurada.")

	stage.queue_free()
	if _failures == 0:
		print("FURNITURE_GRID_EXCEPTION_TEST: OK")
	quit(_failures)


func _make_obstacle(layer: int, at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 2
	body.position = at
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	return body


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)

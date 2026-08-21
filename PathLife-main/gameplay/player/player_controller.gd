class_name PlayerController
extends CharacterBody2D

signal locomotion_changed(direction: StringName, is_moving: bool, is_running: bool)
signal crouch_changed(is_crouching: bool)
signal sleep_changed(is_sleeping: bool, direction: StringName)
signal health_changed(current_health: int, maximum_health: int)

@export_category("Configuration")
@export var config: PlayerConfig

@export_category("Mundo em grade")
## Componente que dá ao jogador uma posição lógica Vector3i no mundo.
##
## Com ele ligado, o movimento passa a ser célula a célula e obedece às
## [MovementRules] (mesmas regras usadas por NPCs e pathfinding). Sem ele, o
## controlador cai no movimento livre antigo — útil para cenas de teste que não
## carregam o mundo procedural.
@export var grid_agent: WorldGridAgent

var _current_health: int = 1
var _facing_direction: StringName = &"se"
var _was_moving: bool = false
var _was_running: bool = false
var _is_crouching: bool = false
var _is_sleeping: bool = false
var _controls_enabled: bool = true


func _ready() -> void:
	if config == null:
		push_error("Player precisa de um PlayerConfig no Inspector.")
		set_physics_process(false)
		return

	_current_health = config.maximum_health
	if grid_agent != null:
		grid_agent.step_blocked.connect(_on_step_blocked)


func is_grid_driven() -> bool:
	return grid_agent != null and grid_agent.is_active()


## Posição lógica no mundo. Fora do modo em grade, é derivada da posição visual.
func world_position() -> Vector3i:
	if grid_agent != null:
		return grid_agent.world_position()
	return Vector3i(0, 0, 0)


func _physics_process(_delta: float) -> void:
	if _is_sleeping:
		velocity = Vector2.ZERO
		return
	if not _controls_enabled:
		velocity = Vector2.ZERO
		return

	var wants_to_crouch := Input.is_action_pressed("crouch")
	if wants_to_crouch != _is_crouching:
		_is_crouching = wants_to_crouch
		crouch_changed.emit(_is_crouching)

	var raw_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var grid_input := _restrict_to_four_directions(raw_input)

	if is_grid_driven():
		_process_grid_movement(grid_input)
		return

	var isometric_input := _to_isometric(grid_input)

	var has_movement_input := grid_input != Vector2.ZERO
	var wants_to_run := (
		has_movement_input
		and not _is_crouching
		and Input.is_action_pressed("move_run")
	)
	var previous_direction := _facing_direction
	if has_movement_input:
		_facing_direction = _direction_from_grid_input(grid_input)

	var speed_multiplier := 1.0
	if _is_crouching:
		speed_multiplier = config.crouch_speed_multiplier
	elif wants_to_run:
		speed_multiplier = config.run_speed_multiplier
	velocity = isometric_input * config.movement_speed * speed_multiplier
	var position_before_move := global_position
	move_and_slide()

	var actual_displacement := global_position - position_before_move
	var is_moving := actual_displacement.length_squared() > 0.000001
	var is_running := is_moving and wants_to_run

	if (
		is_moving != _was_moving
		or is_running != _was_running
		or _facing_direction != previous_direction
	):
		locomotion_changed.emit(_facing_direction, is_moving, is_running)

	_was_moving = is_moving
	_was_running = is_running


## Movimento célula a célula. Quem autoriza o passo é [MovementRules] — o
## controlador nunca decide sozinho se pode subir, descer ou cair.
func _process_grid_movement(grid_input: Vector2) -> void:
	velocity = Vector2.ZERO

	var has_movement_input := grid_input != Vector2.ZERO
	var wants_to_run := (
		has_movement_input
		and not _is_crouching
		and Input.is_action_pressed("move_run")
	)
	var previous_direction := _facing_direction
	if has_movement_input:
		_facing_direction = _direction_from_grid_input(grid_input)

	if has_movement_input and not grid_agent.is_moving():
		var speed_scale := 1.0
		if _is_crouching:
			speed_scale = config.crouch_speed_multiplier
		elif wants_to_run:
			speed_scale = grid_agent.run_multiplier
		grid_agent.request_step(Vector2i(roundi(grid_input.x), roundi(grid_input.y)), speed_scale)

	var is_moving := grid_agent.is_moving()
	var is_running := is_moving and wants_to_run

	if (
		is_moving != _was_moving
		or is_running != _was_running
		or _facing_direction != previous_direction
	):
		locomotion_changed.emit(_facing_direction, is_moving, is_running)

	_was_moving = is_moving
	_was_running = is_running


func _on_step_blocked(_direction: Vector2i) -> void:
	if _was_moving:
		_was_moving = false
		_was_running = false
		locomotion_changed.emit(_facing_direction, false, false)


func set_controls_enabled(enabled: bool) -> void:
	if _controls_enabled == enabled:
		return
	_controls_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		if _is_crouching:
			_is_crouching = false
			crouch_changed.emit(false)
		if _was_moving or _was_running:
			locomotion_changed.emit(_facing_direction, false, false)
		_was_moving = false
		_was_running = false


func are_controls_enabled() -> bool:
	return _controls_enabled


func is_crouching() -> bool:
	return _is_crouching


func enter_sleep(direction: StringName) -> void:
	if _is_sleeping:
		return
	_is_sleeping = true
	_facing_direction = direction
	velocity = Vector2.ZERO
	if _is_crouching:
		_is_crouching = false
		crouch_changed.emit(false)
	_was_moving = false
	_was_running = false
	sleep_changed.emit(true, _facing_direction)


func exit_sleep() -> void:
	if not _is_sleeping:
		return
	_is_sleeping = false
	sleep_changed.emit(false, _facing_direction)
	locomotion_changed.emit(_facing_direction, false, false)


func is_sleeping() -> bool:
	return _is_sleeping


func damage(amount: int) -> void:
	if amount <= 0:
		return
	_current_health = maxi(_current_health - amount, 0)
	health_changed.emit(_current_health, config.maximum_health)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	_current_health = mini(_current_health + amount, config.maximum_health)
	health_changed.emit(_current_health, config.maximum_health)


func get_current_health() -> int:
	return _current_health


func get_maximum_health() -> int:
	return config.maximum_health if config != null else 1


func get_facing_direction() -> StringName:
	return _facing_direction


func _restrict_to_four_directions(input_vector: Vector2) -> Vector2:
	if input_vector == Vector2.ZERO:
		return Vector2.ZERO

	if absf(input_vector.x) > absf(input_vector.y):
		return Vector2(signf(input_vector.x), 0.0)
	return Vector2(0.0, signf(input_vector.y))


func _to_isometric(grid_input: Vector2) -> Vector2:
	if grid_input == Vector2.ZERO:
		return Vector2.ZERO

	var transformed := Vector2(
		grid_input.x - grid_input.y,
		(grid_input.x + grid_input.y) * config.isometric_vertical_ratio
	)
	return transformed.normalized()


func _direction_from_grid_input(grid_input: Vector2) -> StringName:
	if grid_input.y < 0.0:
		return &"ne"
	if grid_input.y > 0.0:
		return &"sw"
	if grid_input.x < 0.0:
		return &"nw"
	return &"se"

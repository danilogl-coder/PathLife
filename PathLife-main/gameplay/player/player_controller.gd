class_name PlayerController
extends CharacterBody2D

signal locomotion_changed(direction: StringName, is_moving: bool, is_running: bool)
signal health_changed(current_health: int, maximum_health: int)

@export_category("Configuration")
@export var config: PlayerConfig

var _current_health: int = 1
var _facing_direction: StringName = &"se"
var _was_moving: bool = false
var _was_running: bool = false


func _ready() -> void:
	if config == null:
		push_error("Player precisa de um PlayerConfig no Inspector.")
		set_physics_process(false)
		return

	_current_health = config.maximum_health


func _physics_process(_delta: float) -> void:
	var raw_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var grid_input := _restrict_to_four_directions(raw_input)
	var isometric_input := _to_isometric(grid_input)

	var has_movement_input := grid_input != Vector2.ZERO
	var wants_to_run := has_movement_input and Input.is_action_pressed("move_run")
	var previous_direction := _facing_direction
	if has_movement_input:
		_facing_direction = _direction_from_grid_input(grid_input)

	var speed_multiplier := config.run_speed_multiplier if wants_to_run else 1.0
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

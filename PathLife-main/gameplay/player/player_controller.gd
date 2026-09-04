class_name PlayerController
extends CharacterBody2D

signal locomotion_changed(direction: StringName, is_moving: bool, is_running: bool)
signal facing_changed(direction: StringName, logical_vector: Vector2i)
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

@export_category("Olhar independente")
## Segure este comando para orientar o personagem pelo cursor sem precisar andar.
@export var look_mode_action: StringName = &"look_mode"
@export var look_left_action: StringName = &"look_left"
@export var look_right_action: StringName = &"look_right"
@export var look_up_action: StringName = &"look_up"
@export var look_down_action: StringName = &"look_down"
@export_range(0.0, 128.0, 1.0) var look_mouse_deadzone_pixels: float = 24.0
@export_range(0.0, 1.0, 0.01) var look_stick_deadzone: float = 0.35

var _current_health: int = 1
var _age_speed_multiplier: float = 1.0
var _age_can_run: bool = true
var _age_can_crouch: bool = true
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

	var wants_to_crouch := Input.is_action_pressed("crouch") and _age_can_crouch
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
	var previous_direction := _facing_direction
	var look_direction := _requested_look_direction()
	var is_looking := look_direction != &""
	if is_looking:
		_set_facing_direction(look_direction)
	elif grid_input != Vector2.ZERO:
		_set_facing_direction(_direction_from_grid_input(grid_input))

	if is_grid_driven():
		_process_grid_movement(grid_input, previous_direction)
		return

	var isometric_input := _to_isometric(grid_input)

	var has_movement_input := grid_input != Vector2.ZERO
	var wants_to_run := (
		has_movement_input
		and not _is_crouching
		and _age_can_run
		and Input.is_action_pressed("move_run")
	)
	var speed_multiplier := 1.0
	if _is_crouching:
		speed_multiplier = config.crouch_speed_multiplier
	elif wants_to_run:
		speed_multiplier = config.run_speed_multiplier
	velocity = isometric_input * config.movement_speed * speed_multiplier * _age_speed_multiplier
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
func _process_grid_movement(grid_input: Vector2, previous_direction: StringName) -> void:
	velocity = Vector2.ZERO

	var has_movement_input := grid_input != Vector2.ZERO
	var wants_to_run := (
		has_movement_input
		and not _is_crouching
		and _age_can_run
		and Input.is_action_pressed("move_run")
	)
	if has_movement_input and not grid_agent.is_moving():
		var speed_scale := 1.0
		if _is_crouching:
			speed_scale = config.crouch_speed_multiplier
		elif wants_to_run:
			speed_scale = grid_agent.run_multiplier
		grid_agent.request_step(
			Vector2i(roundi(grid_input.x), roundi(grid_input.y)),
			speed_scale * _age_speed_multiplier
		)

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


## Ligado ao sinal age_body_changed do AgeBody. O controlador não conhece idade
## nenhuma: ele recebe três números e obedece.
func present_age_body(profile: AgeProfile) -> void:
	if profile == null:
		return
	_age_speed_multiplier = profile.multiplicador_velocidade
	_age_can_run = profile.pode_correr
	_age_can_crouch = profile.pode_agachar
	if _is_crouching and not _age_can_crouch:
		_is_crouching = false
		crouch_changed.emit(false)


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
	_set_facing_direction(direction)
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


func get_facing_vector() -> Vector2i:
	return _logical_vector_for_direction(_facing_direction)


## Atualiza a fonte única de verdade da orientação. Movimento, olhar, sono e
## futuras ações de combate devem passar por este método para manter a visão e
## a apresentação sincronizadas.
func _set_facing_direction(direction: StringName) -> void:
	if direction == _facing_direction or direction not in [&"ne", &"nw", &"se", &"sw"]:
		return
	_facing_direction = direction
	facing_changed.emit(_facing_direction, _logical_vector_for_direction(_facing_direction))


func _requested_look_direction() -> StringName:
	# Mouse tem precedência quando o botão de olhar está pressionado. A deadzone
	# é configurada em pixels de tela, portanto ambos os pontos precisam estar no
	# espaço do viewport (inclusive sob zoom e movimento da Camera2D).
	if Input.is_action_pressed(look_mode_action):
		var player_screen_position := get_viewport().get_canvas_transform() * global_position
		var mouse_delta := get_viewport().get_mouse_position() - player_screen_position
		if mouse_delta.length() >= look_mouse_deadzone_pixels:
			return _direction_from_screen_vector(mouse_delta)

	var stick := Input.get_vector(
		look_left_action,
		look_right_action,
		look_up_action,
		look_down_action,
		look_stick_deadzone
	)
	# Input.get_vector() já aplica e remapeia a deadzone passada acima. Comparar
	# novamente com o mesmo valor elevaria a zona morta efetiva (~0,58 para 0,35).
	if stick != Vector2.ZERO:
		return _direction_from_screen_vector(stick)
	return &""


func _direction_from_screen_vector(screen_vector: Vector2) -> StringName:
	if screen_vector == Vector2.ZERO:
		return _facing_direction
	var normalized := screen_vector.normalized()
	var best_direction: StringName = _facing_direction
	var best_dot := -INF
	var vertical_ratio := config.isometric_vertical_ratio if config != null else 0.5
	var candidates: Dictionary = {
		&"ne": Vector2(1.0, -vertical_ratio).normalized(),
		&"nw": Vector2(-1.0, -vertical_ratio).normalized(),
		&"se": Vector2(1.0, vertical_ratio).normalized(),
		&"sw": Vector2(-1.0, vertical_ratio).normalized(),
	}
	for direction: StringName in candidates:
		var score := normalized.dot(candidates[direction] as Vector2)
		if score > best_dot:
			best_dot = score
			best_direction = direction
	return best_direction


func _logical_vector_for_direction(direction: StringName) -> Vector2i:
	match direction:
		&"ne":
			return Vector2i(0, -1)
		&"nw":
			return Vector2i(-1, 0)
		&"sw":
			return Vector2i(0, 1)
	return Vector2i(1, 0)


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

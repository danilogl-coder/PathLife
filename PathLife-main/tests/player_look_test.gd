## Contrato headless do olhar independente do jogador.
##
## Uso:
##   godot --headless --path . --script res://tests/player_look_test.gd
extends SceneTree

const LOOK_ACTIONS: Array[StringName] = [
	&"look_mode", &"look_left", &"look_right", &"look_up", &"look_down",
]

var _passed := 0
var _failed := 0
var _facing_events: Array[Dictionary] = []
var _player: PlayerController


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[Player] InputMap e olhar independente")
	_release_test_actions()
	_test_input_map_contract()

	_player = PlayerController.new()
	_player.name = "PlayerLookProbe"
	_player.config = load("res://data/player/default_player_config.tres")
	_player.set_physics_process(false)
	_player.facing_changed.connect(_on_facing_changed)
	root.add_child(_player)
	await process_frame

	_check(_player.look_mode_action == &"look_mode", "ação de olhar por mouse configurada")
	_check(is_equal_approx(_player.look_mouse_deadzone_pixels, 24.0), "deadzone do mouse = 24 px")
	_check(is_equal_approx(_player.look_stick_deadzone, 0.35), "deadzone do analógico = 0.35")
	_test_direction_projection()
	_test_facing_signal_contract()
	_test_stick_and_persistence()

	_release_test_actions()
	_player.queue_free()
	await process_frame
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_input_map_contract() -> void:
	for action: StringName in LOOK_ACTIONS:
		_check(InputMap.has_action(action), "InputMap contém %s" % action)

	var right_mouse_bound := false
	for event: InputEvent in InputMap.action_get_events(&"look_mode"):
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_bound = true
	_check(right_mouse_bound, "look_mode usa botão direito do mouse")

	_check_joy_axis(&"look_left", JOY_AXIS_RIGHT_X, -1.0)
	_check_joy_axis(&"look_right", JOY_AXIS_RIGHT_X, 1.0)
	_check_joy_axis(&"look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_check_joy_axis(&"look_down", JOY_AXIS_RIGHT_Y, 1.0)
	for action: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		_check(
			is_equal_approx(InputMap.action_get_deadzone(action), 0.35),
			"deadzone de %s = 0.35" % action,
			str(InputMap.action_get_deadzone(action))
		)


func _check_joy_axis(action: StringName, expected_axis: JoyAxis, expected_value: float) -> void:
	var found := false
	for event: InputEvent in InputMap.action_get_events(action):
		var joy_event := event as InputEventJoypadMotion
		if (
			joy_event != null
			and joy_event.axis == expected_axis
			and is_equal_approx(signf(joy_event.axis_value), expected_value)
		):
			found = true
	_check(found, "%s usa eixo analógico direito correto" % action)


func _test_direction_projection() -> void:
	var samples: Dictionary = {
		&"ne": Vector2(1.0, -0.5),
		&"nw": Vector2(-1.0, -0.5),
		&"se": Vector2(1.0, 0.5),
		&"sw": Vector2(-1.0, 0.5),
	}
	for expected: StringName in samples:
		var actual: StringName = _player._direction_from_screen_vector(samples[expected])
		_check(actual == expected, "vetor de tela seleciona %s" % expected, String(actual))


func _test_facing_signal_contract() -> void:
	_facing_events.clear()
	_player._set_facing_direction(&"nw")
	_check(_player.get_facing_direction() == &"nw", "orientação pública acompanha mudança")
	_check(_player.get_facing_vector() == Vector2i(-1, 0), "NW expõe vetor lógico (-1, 0)")
	_check(_facing_events.size() == 1, "mudança emite facing_changed uma vez")
	if not _facing_events.is_empty():
		_check(
			_facing_events[0] == {"direction": &"nw", "vector": Vector2i(-1, 0)},
			"sinal carrega direção e vetor lógico"
		)

	_player._set_facing_direction(&"nw")
	_check(_facing_events.size() == 1, "direção repetida não duplica evento")
	_player._set_facing_direction(&"invalid")
	_check(_player.get_facing_direction() == &"nw", "direção inválida é ignorada")
	_check(_facing_events.size() == 1, "direção inválida não emite evento")


func _test_stick_and_persistence() -> void:
	_facing_events.clear()
	Input.action_press(&"look_right", 0.5)
	_check(
		_player._requested_look_direction() != &"",
		"deadzone do analógico é aplicada uma única vez"
	)
	Input.action_release(&"look_right")
	Input.action_press(&"look_right", 1.0)
	Input.action_press(&"look_up", 1.0)
	_player._physics_process(0.0)
	_check(_player.get_facing_direction() == &"ne", "analógico direito orienta para NE")
	_check(_player.get_facing_vector() == Vector2i(0, -1), "NE expõe vetor lógico (0, -1)")
	Input.action_release(&"look_right")
	Input.action_release(&"look_up")

	_player._physics_process(0.0)
	_check(_player.get_facing_direction() == &"ne", "orientação persiste ao soltar o olhar")
	_check(_facing_events.size() == 1, "soltar o olhar não produz evento espúrio")

	Input.action_press(&"move_down", 1.0)
	_player._physics_process(0.0)
	Input.action_release(&"move_down")
	_check(_player.get_facing_direction() == &"sw", "movimento seguinte substitui direção observada")
	_check(_player.get_facing_vector() == Vector2i(0, 1), "SW expõe vetor lógico (0, 1)")


func _on_facing_changed(direction: StringName, logical_vector: Vector2i) -> void:
	_facing_events.append({"direction": direction, "vector": logical_vector})


func _release_test_actions() -> void:
	for action: StringName in LOOK_ACTIONS + [
		&"move_left", &"move_right", &"move_up", &"move_down", &"move_run", &"crouch",
	]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

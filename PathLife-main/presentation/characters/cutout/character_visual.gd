class_name CharacterVisual
extends Node2D

@onready var rig: CharacterRig = $Skeleton2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export_category("Animation Transitions")
@export_range(0.0, 0.5, 0.01) var locomotion_blend_time: float = 0.08
@export_range(0.0, 0.5, 0.01) var stop_blend_time: float = 0.18

var _current_animation: StringName = &""
var _direction: StringName = &"se"
var _is_moving: bool = false
var _is_running: bool = false


func _ready() -> void:
	_direction = StringName(rig.initial_direction)
	_refresh_locomotion_animation()


func present_locomotion(direction: StringName, is_moving: bool, is_running: bool = false) -> void:
	_direction = direction
	_is_moving = is_moving
	_is_running = is_moving and is_running
	rig.set_direction(direction)
	_refresh_locomotion_animation()


func present_body(body_type: String) -> void:
	rig.set_body(body_type)
	_current_animation = &""
	_refresh_locomotion_animation()


func play_action(action: StringName) -> void:
	_play_action(action)


func _refresh_locomotion_animation() -> void:
	if not _is_moving:
		_play_action(&"idle")
	elif _is_running:
		_play_action(&"run")
	else:
		_play_action(&"walk")


func _play_action(action: StringName) -> void:
	var animation_name := StringName(
		"%s/%s_%s" % [rig.body_type, String(action), String(_direction)]
	)

	if (
		animation_name == _current_animation
		and animation_player.assigned_animation == animation_name
		and animation_player.is_playing()
	):
		return
	if not animation_player.has_animation(animation_name):
		push_error("Animação não encontrada: %s" % animation_name)
		return

	# Como todas as animações idle controlam o corpo inteiro, a transição pode
	# misturar naturalmente a pose atual de caminhada/corrida com a pose parada.
	if action == &"idle":
		animation_player.play(animation_name, stop_blend_time)
		animation_player.advance(0.0)
	else:
		animation_player.play(animation_name, locomotion_blend_time)
		animation_player.advance(0.0)
	_current_animation = animation_name

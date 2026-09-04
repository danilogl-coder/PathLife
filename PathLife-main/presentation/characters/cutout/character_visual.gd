class_name CharacterVisual
extends Node2D

@onready var rig: CharacterRig = $Skeleton2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var wardrobe: WardrobePresenter = $WardrobePresenter
@onready var hair: HairManager = $Skeleton2D/quadril/torso/cabeca/HairRig
@onready var color_presenter: CharacterColorPresenter = $CharacterColorPresenter
@onready var age_presenter: CharacterAgePresenter = $CharacterAgePresenter

@export_category("Animation Transitions")
@export_range(0.0, 0.5, 0.01) var locomotion_blend_time: float = 0.08
@export_range(0.0, 0.5, 0.01) var stop_blend_time: float = 0.18

var _current_animation: StringName = &""
var _direction: StringName = &"se"
var _is_moving: bool = false
var _is_running: bool = false
var _is_crouching: bool = false
var _is_sleeping: bool = false
var _appearance: CharacterAppearance = CharacterAppearance.new()


func _ready() -> void:
	rig.color_presenter = color_presenter
	wardrobe.color_presenter = color_presenter
	hair.color_presenter = color_presenter
	_direction = StringName(rig.initial_direction)
	_appearance.body_type = rig.body_type
	age_presenter.present(_appearance.age)
	rig.present_skin_color(_appearance.skin_color)
	_refresh_locomotion_animation()


func present_locomotion(direction: StringName, is_moving: bool, is_running: bool = false) -> void:
	_direction = direction
	_is_moving = is_moving
	_is_running = is_moving and is_running
	rig.set_direction(direction)
	wardrobe.present(_appearance, direction)
	hair.present(_appearance.hair_front, _appearance.hair_back, direction, _appearance.hair_color)
	_refresh_locomotion_animation()


func present_body(body_type: String) -> void:
	var updated := _appearance.snapshot()
	updated.body_type = body_type
	present_appearance(updated)


func present_crouch(is_crouching: bool) -> void:
	if _is_sleeping:
		return
	if _is_crouching == is_crouching:
		return
	_is_crouching = is_crouching
	if _is_crouching and not _is_moving:
		_play_action(&"croushed")
	else:
		_refresh_locomotion_animation()


func present_appearance(appearance: CharacterAppearance) -> void:
	if appearance == null:
		return
	_appearance = appearance.snapshot()
	rig.set_body(_appearance.body_type)
	# Antes do set_direction: é ele que reescreve a posição dos ossos, e a
	# proporção da idade precisa entrar na mesma passada.
	age_presenter.present(_appearance.age)
	rig.set_direction(_direction)
	rig.present_skin_color(_appearance.skin_color)
	wardrobe.invalidate()
	wardrobe.present(_appearance, _direction)
	hair.invalidate()
	hair.present(_appearance.hair_front, _appearance.hair_back, _direction, _appearance.hair_color)
	_current_animation = &""
	_refresh_locomotion_animation()


func play_action(action: StringName) -> void:
	_play_action(action)


func present_sleep(is_sleeping: bool, direction: StringName) -> void:
	_is_sleeping = is_sleeping
	_direction = direction
	_is_moving = false
	_is_running = false
	_is_crouching = false
	rig.set_direction(direction)
	wardrobe.present(_appearance, direction)
	hair.present(_appearance.hair_front, _appearance.hair_back, direction, _appearance.hair_color)
	if _is_sleeping:
		_play_action(&"sleep")
	else:
		_refresh_locomotion_animation()


func _refresh_locomotion_animation() -> void:
	if _is_sleeping:
		_play_action(&"sleep")
	elif _is_crouching:
		if _is_moving:
			_play_action(&"crouch_walk")
		else:
			var crouch_enter_name := _make_animation_name(&"croushed")
			if not (
				animation_player.assigned_animation == crouch_enter_name
				and animation_player.is_playing()
			):
				_play_action(&"crouch_idle")
	elif not _is_moving:
		_play_action(&"idle")
	elif _is_running:
		_play_action(&"run")
	else:
		_play_action(&"walk")


func _play_action(action: StringName) -> void:
	var animation_name := _make_animation_name(action)

	if (
		animation_name == _current_animation
		and animation_player.assigned_animation == animation_name
		and animation_player.is_playing()
	):
		return
	if not animation_player.has_animation(animation_name):
		# A idade pode ter biblioteca própria com só algumas ações gravadas. O
		# que faltar cai na biblioteca do corpo em vez de virar erro.
		var fallback := _fallback_animation_name(action)
		if not animation_player.has_animation(fallback):
			push_error("Animação não encontrada: %s" % animation_name)
			return
		animation_name = fallback

	# Como todas as animações idle controlam o corpo inteiro, a transição pode
	# misturar naturalmente a pose atual de caminhada/corrida com a pose parada.
	if action == &"idle":
		animation_player.play(animation_name, stop_blend_time)
		animation_player.advance(0.0)
	else:
		animation_player.play(animation_name, locomotion_blend_time)
		animation_player.advance(0.0)
	_current_animation = animation_name


func _make_animation_name(action: StringName) -> StringName:
	return StringName(
		"%s/%s_%s" % [
			age_presenter.animation_library(rig.body_type), String(action), String(_direction)
		]
	)


func _fallback_animation_name(action: StringName) -> StringName:
	return StringName("%s/%s_%s" % [rig.body_type, String(action), String(_direction)])


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if (
		animation_name != _make_animation_name(&"croushed")
		and animation_name != _fallback_animation_name(&"croushed")
	):
		return
	if _is_crouching and not _is_moving:
		_play_action(&"crouch_idle")

class_name BedSleepInteractor
extends Node2D

signal bed_became_available(bed: BedFurniture)
signal bed_became_unavailable(bed: BedFurniture)
signal sleep_started(bed: BedFurniture)
signal sleep_ended(bed: BedFurniture)

@export_category("Referências")
@export var player: PlayerController
@export var visual_anchor: Node2D
@export var character_visual: CharacterVisual

@export_category("Entrada")
@export var interact_action: StringName = &"interact"
@export var movement_actions: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
]

@export_category("Apresentação")
@export_range(-4096, 4096, 1) var sleeping_z_index: int = 2

var _nearby_beds: Array[BedFurniture] = []
var _current_bed: BedFurniture
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _saved_z_index: int = 0
var _saved_player_global_position: Vector2 = Vector2.ZERO
var _saved_visual_position: Vector2 = Vector2.ZERO
var _saved_visual_rotation: float = 0.0
var _saved_visual_scale: Vector2 = Vector2.ONE
var _can_wake_from_movement: bool = false


func _ready() -> void:
	if player == null:
		push_error("BedSleepInteractor precisa da referência Player no Inspector.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	if character_visual == null:
		push_error("BedSleepInteractor precisa da referência Character Visual no Inspector.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	if visual_anchor == null:
		push_error("BedSleepInteractor precisa da referência Visual Anchor no Inspector.")
		set_physics_process(false)
		set_process_unhandled_input(false)


func _physics_process(_delta: float) -> void:
	if _current_bed == null:
		return

	var has_movement_input := _has_movement_input()
	if not _can_wake_from_movement:
		_can_wake_from_movement = not has_movement_input
		return
	if has_movement_input:
		leave_bed()


func _unhandled_input(event: InputEvent) -> void:
	if _current_bed != null:
		return
	if not event.is_action_pressed(interact_action) or event.is_echo():
		return
	if try_sleep():
		get_viewport().set_input_as_handled()


func try_sleep() -> bool:
	if _current_bed != null or player == null or visual_anchor == null or character_visual == null:
		return false

	var bed := _find_closest_bed()
	if bed == null:
		return false

	_current_bed = bed
	_saved_collision_layer = player.collision_layer
	_saved_collision_mask = player.collision_mask
	_saved_z_index = player.z_index
	_saved_player_global_position = player.global_position
	_saved_visual_position = visual_anchor.position
	_saved_visual_rotation = visual_anchor.rotation
	_saved_visual_scale = visual_anchor.scale
	_can_wake_from_movement = not _has_movement_input()

	player.collision_layer = 0
	player.collision_mask = 0
	player.z_index = sleeping_z_index
	player.global_position = bed.get_sleep_position()
	visual_anchor.position = bed.get_sleep_visual_offset()
	visual_anchor.rotation = bed.get_sleep_visual_rotation()
	visual_anchor.scale = bed.get_sleep_visual_scale()
	player.enter_sleep(bed.get_sleep_animation_direction_for(_saved_player_global_position))
	bed.set_occupied(true)
	sleep_started.emit(bed)
	return true


func leave_bed() -> bool:
	if _current_bed == null or player == null:
		return false

	var bed := _current_bed
	player.global_position = _saved_player_global_position
	player.collision_layer = _saved_collision_layer
	player.collision_mask = _saved_collision_mask
	player.z_index = _saved_z_index
	visual_anchor.position = _saved_visual_position
	visual_anchor.rotation = _saved_visual_rotation
	visual_anchor.scale = _saved_visual_scale
	player.exit_sleep()
	bed.set_occupied(false)
	_current_bed = null
	_can_wake_from_movement = false
	sleep_ended.emit(bed)
	return true


func is_sleeping() -> bool:
	return _current_bed != null


func get_current_bed() -> BedFurniture:
	return _current_bed


func get_nearby_bed_count() -> int:
	_prune_invalid_beds()
	return _nearby_beds.size()


func _on_bed_detector_area_entered(area: Area2D) -> void:
	var bed := area.get_parent() as BedFurniture
	if bed == null or bed in _nearby_beds:
		return
	_nearby_beds.append(bed)
	bed_became_available.emit(bed)


func _on_bed_detector_area_exited(area: Area2D) -> void:
	var bed := area.get_parent() as BedFurniture
	if bed == null or bed not in _nearby_beds:
		return
	_nearby_beds.erase(bed)
	bed_became_unavailable.emit(bed)


func _find_closest_bed() -> BedFurniture:
	_prune_invalid_beds()
	var closest_bed: BedFurniture
	var closest_distance := INF
	for bed: BedFurniture in _nearby_beds:
		var distance := player.global_position.distance_squared_to(bed.get_sleep_position())
		if distance < closest_distance:
			closest_distance = distance
			closest_bed = bed
	return closest_bed


func _prune_invalid_beds() -> void:
	for index: int in range(_nearby_beds.size() - 1, -1, -1):
		if not is_instance_valid(_nearby_beds[index]):
			_nearby_beds.remove_at(index)


func _has_movement_input() -> bool:
	for action: StringName in movement_actions:
		if Input.is_action_pressed(action):
			return true
	return false


func _exit_tree() -> void:
	if is_instance_valid(_current_bed):
		_current_bed.set_occupied(false)

class_name BedFurniture
extends StaticBody2D

signal occupancy_changed(is_occupied: bool)

@export_category("Identidade")
@export var furniture_id: StringName = &"bed_basic"
@export var display_name: String = "Cama"

@export_category("Sono")
@export_enum("ne", "nw", "se", "sw") var sleep_direction: String = "ne"
@export var sleep_center: Marker2D
@export var pillow_anchor: Marker2D
@export var exit_anchor: Marker2D

@export_category("Apresentação do sono")
@export_enum("ne", "nw", "se", "sw") var sleep_animation_direction: String = "ne"
@export var sleep_visual_offset: Vector2 = Vector2(0, -40)
@export_range(-180.0, 180.0, 1.0, "degrees") var sleep_visual_rotation_degrees: float = 180.0
@export var sleep_visual_scale: Vector2 = Vector2.ONE

@export_category("Sono conforme o lado")
@export var use_interaction_side_direction: bool = false
@export var sleep_left_anchor: Marker2D
@export_enum("ne", "nw", "se", "sw") var sleep_left_direction: String = "se"
@export var sleep_right_anchor: Marker2D
@export_enum("ne", "nw", "se", "sw") var sleep_right_direction: String = "ne"

var _is_occupied: bool = false


func get_sleep_position() -> Vector2:
	return sleep_center.global_position


func get_pillow_position() -> Vector2:
	return pillow_anchor.global_position


func get_exit_position() -> Vector2:
	return exit_anchor.global_position


func get_sleep_direction() -> StringName:
	return StringName(sleep_direction)


func get_sleep_animation_direction() -> StringName:
	return StringName(sleep_animation_direction)


func get_sleep_animation_direction_for(interaction_global_position: Vector2) -> StringName:
	if (
		not use_interaction_side_direction
		or sleep_left_anchor == null
		or sleep_right_anchor == null
	):
		return get_sleep_animation_direction()

	var left_distance := interaction_global_position.distance_squared_to(
		sleep_left_anchor.global_position
	)
	var right_distance := interaction_global_position.distance_squared_to(
		sleep_right_anchor.global_position
	)
	return StringName(sleep_left_direction if left_distance <= right_distance else sleep_right_direction)


func get_sleep_visual_offset() -> Vector2:
	return sleep_visual_offset


func get_sleep_visual_rotation() -> float:
	return deg_to_rad(sleep_visual_rotation_degrees)


func get_sleep_visual_scale() -> Vector2:
	return sleep_visual_scale


func set_occupied(is_occupied: bool) -> void:
	if _is_occupied == is_occupied:
		return
	_is_occupied = is_occupied
	occupancy_changed.emit(_is_occupied)


func is_occupied() -> bool:
	return _is_occupied

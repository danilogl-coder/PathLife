class_name FurnitureTopOccluder
extends Area2D

signal occlusion_started(actor: Node2D)
signal occlusion_ended(actor: Node2D)
signal occlusion_changed(is_occluding: bool)

@export_category("Apresentação")
@export var visual_target: CanvasItem
@export_range(-4096, 4096, 1) var normal_z_index: int = 0
@export_range(-4096, 4096, 1) var occluding_z_index: int = 100

@export_category("Filtro")
@export var actor_group: StringName = &"depth_actor"

var _actors_inside: Dictionary = {}
var _is_occluding: bool = false


func _ready() -> void:
	if visual_target == null:
		push_error("FurnitureTopOccluder precisa de um Visual Target no Inspector.")
		set_deferred("monitoring", false)
		return
	_set_occluding(false)


func is_occluding() -> bool:
	return _is_occluding


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(actor_group):
		return

	_actors_inside[body.get_instance_id()] = body
	occlusion_started.emit(body)
	_set_occluding(true)


func _on_body_exited(body: Node2D) -> void:
	if not _actors_inside.erase(body.get_instance_id()):
		return

	occlusion_ended.emit(body)
	if _actors_inside.is_empty():
		_set_occluding(false)


func _set_occluding(should_occlude: bool) -> void:
	if visual_target == null:
		return
	var target_z := occluding_z_index if should_occlude else normal_z_index
	if _is_occluding == should_occlude and visual_target.z_index == target_z:
		return

	_is_occluding = should_occlude
	visual_target.z_index = target_z
	occlusion_changed.emit(_is_occluding)

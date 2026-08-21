class_name BedVisual
extends Node2D

@export_category("Referências")
@export var blanket: Sprite2D
@export var sleeping_headboard: Sprite2D


func _ready() -> void:
	if blanket == null:
		push_error("BedVisual precisa da referência Blanket no Inspector.")
		return
	blanket.visible = false
	if sleeping_headboard != null:
		sleeping_headboard.visible = false


func present_occupied(is_occupied: bool) -> void:
	if blanket != null:
		blanket.visible = is_occupied
	if sleeping_headboard != null:
		sleeping_headboard.visible = is_occupied and sleeping_headboard.texture != null

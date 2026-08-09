class_name MainScene
extends Node2D

@export_category("Scene References")
@export var player: PlayerController
@export var hud: PlayerHUD


func _ready() -> void:
	if not _references_are_valid():
		return

	player.locomotion_changed.connect(hud.present_locomotion)
	player.health_changed.connect(hud.present_health)

	hud.present_locomotion(player.get_facing_direction(), false, false)
	hud.present_health(player.get_current_health(), player.get_maximum_health())


func _references_are_valid() -> bool:
	if player == null:
		push_error("Main: referência Player não configurada.")
		return false
	if hud == null:
		push_error("Main: referência HUD não configurada.")
		return false
	return true

class_name PlayerHUD
extends Control

signal customization_requested

@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var movement_label: Label = %MovementLabel


func present_health(current_health: int, maximum_health: int) -> void:
	var safe_maximum := maxi(maximum_health, 1)
	health_bar.max_value = safe_maximum
	health_bar.value = clampi(current_health, 0, safe_maximum)
	health_label.text = "VIDA  %d / %d" % [current_health, safe_maximum]


func present_locomotion(direction: StringName, is_moving: bool, is_running: bool = false) -> void:
	var state_text := "PARADO"
	if is_moving:
		state_text = "CORRENDO" if is_running else "ANDANDO"
	movement_label.text = "%s  •  %s" % [state_text, String(direction).to_upper()]


func _on_customize_button_pressed() -> void:
	customization_requested.emit()

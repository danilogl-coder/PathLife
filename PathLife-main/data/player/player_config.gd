class_name PlayerConfig
extends Resource
#Movimento
@export_category("Movement")
@export_range(10.0, 500.0, 1.0) var movement_speed: float = 100.0
@export_range(1.0, 3.0, 0.05) var run_speed_multiplier: float = 1.65
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.45
@export_range(0.1, 1.0, 0.05) var isometric_vertical_ratio: float = 0.5
#Vida
@export_category("Vitals")
@export_range(1, 1000, 1) var maximum_health: int = 100

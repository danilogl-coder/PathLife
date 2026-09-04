## Parâmetros ajustáveis da percepção do jogador.
@tool
class_name VisionProfile
extends Resource

@export_category("Ativação")
@export var enabled: bool = true

@export_category("Campo de visão")
@export_range(1, 128, 1, "or_greater") var maximum_range_cells: int = 18
@export_range(1.0, 360.0, 1.0) var front_cone_degrees: float = 155.0
@export_range(0, 32, 1, "or_greater") var peripheral_range_cells: int = 2

@export_category("Portais")
@export_range(0, 64, 1, "or_greater") var window_reveal_depth_cells: int = 5
@export_range(0, 64, 1, "or_greater") var door_reveal_depth_cells: int = 8
@export_range(0, 16, 1, "or_greater") var maximum_portal_hops: int = 1
@export_range(0.0, 1.0, 0.05) var closed_window_transmission: float = 0.0
@export_range(0.0, 1.0, 0.05) var open_window_transmission: float = 1.0

@export_category("Estruturas")
@export var sealed_structure_blocks_memory: bool = true

@export_category("Apresentação")
@export_range(0.1, 1.0, 0.05) var mask_resolution_scale: float = 0.5
@export_range(0, 1024, 1, "or_greater") var visual_reveal_height_px: int = 192
@export_range(0.0, 64.0, 0.5, "or_greater") var edge_softness_px: float = 3.0
@export_range(0.0, 2.0, 0.01, "or_greater") var transition_seconds: float = 0.15
@export_range(0.0, 1.0, 0.01) var unknown_opacity: float = 1.0
@export_range(0.0, 1.0, 0.01) var remembered_opacity: float = 0.82
@export_range(0.0, 1.0, 0.01) var forced_hidden_opacity: float = 1.0
@export_range(0.0, 1.0, 0.01) var roof_revealed_alpha: float = 0.0

@export_category("Modo de olhar")
@export_range(0.0, 512.0, 1.0, "or_greater") var look_mouse_deadzone_px: float = 24.0
@export_range(0.0, 1.0, 0.01) var look_stick_deadzone: float = 0.35


func sanitize() -> void:
	maximum_range_cells = maxi(1, maximum_range_cells)
	front_cone_degrees = clampf(front_cone_degrees, 1.0, 360.0)
	peripheral_range_cells = maxi(0, peripheral_range_cells)
	window_reveal_depth_cells = maxi(0, window_reveal_depth_cells)
	door_reveal_depth_cells = maxi(0, door_reveal_depth_cells)
	maximum_portal_hops = maxi(0, maximum_portal_hops)
	closed_window_transmission = clampf(closed_window_transmission, 0.0, 1.0)
	open_window_transmission = clampf(open_window_transmission, 0.0, 1.0)
	mask_resolution_scale = clampf(mask_resolution_scale, 0.1, 1.0)
	visual_reveal_height_px = maxi(0, visual_reveal_height_px)
	edge_softness_px = maxf(0.0, edge_softness_px)
	transition_seconds = maxf(0.0, transition_seconds)
	unknown_opacity = clampf(unknown_opacity, 0.0, 1.0)
	remembered_opacity = clampf(remembered_opacity, 0.0, 1.0)
	forced_hidden_opacity = clampf(forced_hidden_opacity, 0.0, 1.0)
	roof_revealed_alpha = clampf(roof_revealed_alpha, 0.0, 1.0)
	look_mouse_deadzone_px = maxf(0.0, look_mouse_deadzone_px)
	look_stick_deadzone = clampf(look_stick_deadzone, 0.0, 1.0)

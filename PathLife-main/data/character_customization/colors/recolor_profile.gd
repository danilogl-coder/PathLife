class_name RecolorProfile
extends Resource

@export var id: StringName = &""
@export var source_colors: PackedColorArray = PackedColorArray()
@export var tone_positions: PackedFloat32Array = PackedFloat32Array()


func is_valid() -> bool:
	return not source_colors.is_empty() and source_colors.size() == tone_positions.size() and source_colors.size() <= 24

class_name HairSegment
extends Bone2D

@onready var sprite: Sprite2D = $Sprite


func configure(segment_data: Dictionary, texture_root: String, visual_z: int, color_material: Material) -> void:
	position = _vector(segment_data.get("posicao", []))
	rest = Transform2D(0.0, position)
	sprite.offset = _vector(segment_data.get("offset_sprite", []))
	sprite.z_index = visual_z
	sprite.material = color_material
	var file := String(segment_data.get("arquivo", ""))
	if not file.is_empty():
		sprite.texture = load(texture_root.path_join(file)) as Texture2D


func _vector(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

extends SceneTree

const CASES: Array[Dictionary] = [
	{
		"scene": "res://gameplay/furniture/bed/bed_r0.tscn",
		"left": &"se",
		"right": &"ne",
	},
	{
		"scene": "res://gameplay/furniture/bed/bed_r1.tscn",
		"left": &"nw",
		"right": &"sw",
	},
]


func _init() -> void:
	for entry: Dictionary in CASES:
		var bed := (load(entry.scene) as PackedScene).instantiate() as BedFurniture
		root.add_child(bed)
		bed.global_position = Vector2(320, 240)
		assert(bed.use_interaction_side_direction)
		assert(bed.get_sleep_animation_direction_for(
			bed.sleep_left_anchor.global_position
		) == entry.left)
		assert(bed.get_sleep_animation_direction_for(
			bed.sleep_right_anchor.global_position
		) == entry.right)
		bed.free()

	for scene_path: String in [
		"res://gameplay/furniture/bed/bed_r2.tscn",
		"res://gameplay/furniture/bed/bed_r3.tscn",
	]:
		var bed := (load(scene_path) as PackedScene).instantiate() as BedFurniture
		root.add_child(bed)
		assert(not bed.use_interaction_side_direction)
		assert(bed.get_sleep_animation_direction_for(Vector2(-9999, 9999))
			== bed.get_sleep_animation_direction())
		bed.free()

	print("BED_SIDE_SLEEP_DIRECTION_OK dynamic=r0,r1 fixed=r2,r3")
	quit()

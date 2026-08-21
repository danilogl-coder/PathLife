extends SceneTree

const BED_SCENES: Array[String] = [
	"res://gameplay/furniture/bed/bed_r0.tscn",
	"res://gameplay/furniture/bed/bed_r1.tscn",
	"res://gameplay/furniture/bed/bed_r2.tscn",
	"res://gameplay/furniture/bed/bed_r3.tscn",
]
const BODY_TYPES: Array[StringName] = [&"masc", &"fem"]


func _init() -> void:
	_render.call_deferred()


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 460)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("1b292e")
	background.size = viewport.size
	viewport.add_child(background)

	var player_scene := load("res://gameplay/player/player.tscn") as PackedScene
	for body_index: int in BODY_TYPES.size():
		for bed_index: int in BED_SCENES.size():
			var bed_position := Vector2(
				140 + bed_index * 270,
				130 + body_index * 220
			)
			var bed_scene := load(BED_SCENES[bed_index]) as PackedScene
			var bed := bed_scene.instantiate() as BedFurniture
			viewport.add_child(bed)
			bed.position = bed_position

			var player := player_scene.instantiate() as PlayerController
			viewport.add_child(player)
			var visual := player.get_node("VisualAnchor/CharacterViewport/CharacterStage/CharacterVisual") as CharacterVisual
			visual.present_body(String(BODY_TYPES[body_index]))
			player.global_position = bed.get_sleep_position()
			player.z_index = 2
			var visual_anchor := player.get_node("VisualAnchor") as Node2D
			visual_anchor.position = bed.get_sleep_visual_offset()
			visual_anchor.rotation = bed.get_sleep_visual_rotation()
			visual_anchor.scale = bed.get_sleep_visual_scale()
			player.enter_sleep(bed.get_sleep_animation_direction())
			bed.set_occupied(true)

			var label := Label.new()
			label.text = "%s R%d" % [BODY_TYPES[body_index], bed_index]
			label.position = bed_position + Vector2(-30, 40)
			viewport.add_child(label)

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var image := viewport.get_texture().get_image()
	var output_path := "res://.godot/bed_sleep_pose_preview.png"
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Não foi possível salvar o preview: %s" % error_string(error))
		quit(1)
		return
	print("BED_SLEEP_POSE_PREVIEW=%s" % ProjectSettings.globalize_path(output_path))
	quit(0)

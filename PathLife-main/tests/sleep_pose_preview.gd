extends SceneTree

const DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"se", &"sw"]
const BODY_TYPES: Array[StringName] = [&"masc", &"fem"]


func _init() -> void:
	_render.call_deferred()


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("263238")
	background.size = viewport.size
	viewport.add_child(background)

	var visual_scene := load(
		"res://presentation/characters/cutout/character_visual.tscn"
	) as PackedScene
	for body_index: int in BODY_TYPES.size():
		for direction_index: int in DIRECTIONS.size():
			var position := Vector2(80 + direction_index * 155, 105 + body_index * 170)
			var visual := visual_scene.instantiate() as CharacterVisual
			viewport.add_child(visual)
			visual.position = position
			visual.present_body(String(BODY_TYPES[body_index]))
			visual.present_locomotion(DIRECTIONS[direction_index], false, false)
			visual.play_action(&"sleep")
			visual.animation_player.seek(1.8, true)

			var label := Label.new()
			label.text = "%s %s" % [BODY_TYPES[body_index], DIRECTIONS[direction_index]]
			label.position = position + Vector2(-30, 45)
			viewport.add_child(label)

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var image := viewport.get_texture().get_image()
	var output_path := "res://.godot/sleep_pose_preview.png"
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Não foi possível salvar o preview: %s" % error_string(error))
		quit(1)
		return
	print("SLEEP_POSE_PREVIEW=%s" % ProjectSettings.globalize_path(output_path))
	quit(0)

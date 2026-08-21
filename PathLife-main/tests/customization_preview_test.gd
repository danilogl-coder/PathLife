extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var menu_scene := load(
		"res://interface/character_customization/character_customization_menu.tscn"
	) as PackedScene
	var appearance := load(
		"res://data/character_customization/default_character_appearance.tres"
	) as CharacterAppearance
	assert(menu_scene != null and appearance != null)
	var menu := menu_scene.instantiate() as CharacterCustomizationMenu
	viewport.add_child(menu)
	menu.open(appearance)
	await process_frame
	await process_frame

	var preview := menu.get_node("%PreviewCharacter") as CharacterVisual
	var preview_viewport := preview.get_viewport() as SubViewport
	assert(preview.position.is_equal_approx(Vector2(128, 125)))
	assert(preview.scale.is_equal_approx(Vector2(1.8, 1.8)))
	assert(preview_viewport.size == Vector2i(256, 170))

	RenderingServer.force_draw()
	await process_frame
	var image := viewport.get_texture().get_image()
	var output := "res://.godot/customization_preview.png"
	assert(image.save_png(ProjectSettings.globalize_path(output)) == OK)
	print("CUSTOMIZATION_PREVIEW_OK position=%s scale=%s" % [preview.position, preview.scale])
	quit()

extends SceneTree


func _init() -> void:
	var profile := load("res://data/character_customization/colors/profiles/skin.tres") as RecolorProfile
	var catalog := load("res://data/character_customization/colors/default_character_color_catalog.tres") as CharacterColorCatalog
	var shader := load("res://shaders/skin_palette_swap.gdshader") as Shader
	var presenter := CharacterColorPresenter.new()
	presenter.catalog = catalog
	presenter.palette_shader = shader
	presenter.skin_profile = profile
	root.add_child(presenter)

	var source := profile.source_colors[0]
	var untouched := Color(0.01960784, 0.03921569, 0.05882353, 1.0)
	var source_image := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	source_image.set_pixel(0, 0, source)
	source_image.set_pixel(1, 0, untouched)
	source_image.set_pixel(2, 0, Color(source.r, source.g, source.b, 0.5))

	var viewport := SubViewport.new()
	viewport.size = Vector2i(3, 1)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ImageTexture.create_from_image(source_image)
	sprite.material = presenter.get_skin_material(&"ebano")
	viewport.add_child(sprite)
	await process_frame
	await process_frame
	await process_frame
	var rendered := viewport.get_texture().get_image()
	var changed := rendered.get_pixel(0, 0)
	var preserved := rendered.get_pixel(1, 0)
	var half_alpha := rendered.get_pixel(2, 0)
	if _rgb_distance(changed, source) <= 0.05:
		_fail("O RGB conhecido não foi substituído: %s" % changed)
		return
	if _rgb_distance(preserved, untouched) >= 0.02:
		_fail("Pixel desconhecido foi alterado: %s" % preserved)
		return
	if absf(half_alpha.a - 0.5) >= 0.02:
		_fail("Alpha não foi preservado: %s" % half_alpha.a)
		return
	print("PALETTE_SHADER_RENDER_OK changed=", changed, " preserved=", preserved, " alpha=", half_alpha.a)
	quit()


func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

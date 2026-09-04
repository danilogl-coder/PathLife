extends SceneTree


func _init() -> void:
	var colors := load("res://data/character_customization/colors/default_character_color_catalog.tres") as CharacterColorCatalog
	var clothes := load("res://data/character_customization/default_clothing_catalog.tres") as ClothingCatalog
	var hairs := load("res://data/character_customization/hair/default_hair_catalog.tres") as HairCatalog
	var defaults := load("res://data/character_customization/default_character_appearance.tres") as CharacterAppearance
	var randomizer := load("res://data/character_customization/default_character_appearance_randomizer.tres") as CharacterAppearanceRandomizer
	assert(colors != null and clothes != null and hairs != null and defaults != null and randomizer != null)
	assert(clothes.items.size() == 9)
	var eyewear_items := clothes.get_items_for_slot(&"eyewear")
	assert(eyewear_items.size() == 1 and eyewear_items[0].id == &"oculos")
	_validate_palette_group(colors.skin_palettes, 20)
	_validate_palette_group(colors.hair_palettes, 20)
	_validate_palette_group(colors.clothing_palettes, 20)
	assert((load("res://data/character_customization/colors/profiles/skin.tres") as RecolorProfile).source_colors.size() == 6)
	assert((load("res://data/character_customization/colors/profiles/hair.tres") as RecolorProfile).source_colors.size() == 19)
	for item: ClothingItem in clothes.items:
		assert(item.recolor_profile != null and item.recolor_profile.is_valid(), "Perfil inválido: %s" % item.id)

	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 987654
	rng_b.seed = 987654
	var randomized_a := randomizer.generate(defaults, clothes, hairs, colors, rng_a)
	var randomized_b := randomizer.generate(defaults, clothes, hairs, colors, rng_b)
	assert(_signature(randomized_a) == _signature(randomized_b), "Seed fixa não foi determinística")
	for seed_value: int in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var generated := randomizer.generate(defaults, clothes, hairs, colors, rng)
		assert(generated.top != &"" and generated.bottom != &"" and generated.footwear != &"")
		assert(generated.hair_front != &"" and generated.hair_back != &"")
	var state := CharacterAppearanceState.new()
	state.default_appearance = defaults
	state.catalog = clothes
	state.hair_catalog = hairs
	state.color_catalog = colors
	state.age_catalog = load("res://data/character_customization/age/default_age_catalog.tres")
	root.add_child(state)
	var invalid_colors := defaults.snapshot()
	invalid_colors.skin_color = &"invalida"
	invalid_colors.hair_color = &"invalida"
	invalid_colors.top_color = &"invalida"
	state.apply_appearance(invalid_colors)
	assert(state.get_snapshot().skin_color == &"marfim")
	assert(state.get_snapshot().hair_color == &"castanho")
	assert(state.get_snapshot().top_color == &"branco")

	var visual_scene := load("res://presentation/characters/cutout/character_visual.tscn") as PackedScene
	var visual := visual_scene.instantiate() as CharacterVisual
	root.add_child(visual)
	await process_frame
	var colored := defaults.snapshot()
	colored.skin_color = &"ebano"
	colored.hair_color = &"roxo"
	colored.top_color = &"vermelho"
	colored.outerwear = &"jaqueta"
	colored.outerwear_color = &"ciano"
	colored.eyewear = &"oculos"
	colored.eyewear_color = &"amarelo"
	visual.present_appearance(colored)
	await process_frame
	assert(visual.rig.get_piece_bone(&"cabeca").get_node("Sprite").material is ShaderMaterial)
	assert(visual.hair.front_base.material is ShaderMaterial)
	assert(visual.hair.back_base.material is ShaderMaterial)
	assert(visual.wardrobe.get_spawned_piece_count() > 0)
	for sprite: Sprite2D in visual.wardrobe._spawned_pieces:
		assert(sprite.material is ShaderMaterial)
		assert(sprite.modulate == Color.WHITE and sprite.self_modulate == Color.WHITE)
	var first_skin_material: Material = (visual.rig.get_piece_bone(&"cabeca").get_node("Sprite") as Sprite2D).material
	for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
		visual.present_locomotion(direction, true, direction == &"nw")
		await process_frame
		assert((visual.rig.get_piece_bone(&"cabeca").get_node("Sprite") as Sprite2D).material == first_skin_material)
	var skirt_appearance := colored.snapshot()
	skirt_appearance.bottom = &"saia"
	skirt_appearance.bottom_color = &"magenta"
	visual.present_appearance(skirt_appearance)
	await process_frame
	assert(visual.wardrobe.skirt.painel_frente.material is ShaderMaterial)
	assert(visual.wardrobe.skirt.painel_tras.material == visual.wardrobe.skirt.painel_frente.material)
	var second_visual := visual_scene.instantiate() as CharacterVisual
	root.add_child(second_visual)
	await process_frame
	second_visual.present_appearance(colored)
	await process_frame
	assert(second_visual.color_presenter.get_skin_material(&"ebano") != first_skin_material,
		"Player e preview não podem compartilhar material mutável")

	var menu_scene := load("res://interface/character_customization/character_customization_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as CharacterCustomizationMenu
	root.add_child(menu)
	await process_frame
	menu.open(defaults)
	await process_frame
	assert(menu.palette_selectors.size() == 8)
	assert(menu.palette_selectors[0].swatches.get_child_count() == 20)
	var before := _signature(menu._working)
	menu._on_randomize_button_pressed()
	assert(_signature(menu._working) != before)
	menu._on_cancel_button_pressed()
	print("CHARACTER_COLOR_INTEGRATION_OK palettes=60 profiles=11 selectors=8")
	quit()


func _validate_palette_group(palettes: Array[CharacterColorPalette], expected: int) -> void:
	assert(palettes.size() == expected)
	var ids: Dictionary = {}
	for palette: CharacterColorPalette in palettes:
		assert(palette != null and palette.id != &"")
		ids[palette.id] = true
	assert(ids.size() == expected)


func _signature(a: CharacterAppearance) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		a.body_type, a.hair_front, a.hair_back, a.skin_color, a.hair_color,
		a.top, a.outerwear, a.bottom, a.footwear, a.eyewear, a.headwear,
		a.top_color, a.outerwear_color, a.bottom_color, a.footwear_color, a.headwear_color]

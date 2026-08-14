extends SceneTree

func _init() -> void:
	var catalog := load("res://data/character_customization/hair/default_hair_catalog.tres") as HairCatalog
	assert(catalog != null, "Catálogo de cabelo não carregou")
	assert(catalog.definitions.size() == 46, "Esperava 46 estilos")
	assert(catalog.get_selectable_definitions().size() == 45, "Careca deve virar Nenhum")
	var appearance := load("res://data/character_customization/default_character_appearance.tres") as CharacterAppearance
	assert(appearance.hair_front == &"basico_normal")
	assert(appearance.hair_back == &"basico_normal")
	var state := CharacterAppearanceState.new()
	state.default_appearance = appearance
	state.catalog = load("res://data/character_customization/default_clothing_catalog.tres")
	state.hair_catalog = catalog
	state.color_catalog = load("res://data/character_customization/colors/default_character_color_catalog.tres")
	root.add_child(state)
	var invalid := appearance.snapshot()
	invalid.hair_front = &"nao_existe"
	invalid.hair_back = &"careca"
	state.apply_appearance(invalid)
	assert(state.get_snapshot().hair_front == &"")
	assert(state.get_snapshot().hair_back == &"")
	var menu_scene := load("res://interface/character_customization/character_customization_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as CharacterCustomizationMenu
	root.add_child(menu)
	await process_frame
	menu.open(appearance)
	assert(menu.hair_rows.size() == 2, "Menu precisa de dois seletores de cabelo")
	assert(menu.hair_rows[0].selector.item_count == 46, "Nenhum + 45 estilos")
	menu._on_cancel_button_pressed()
	var visual_scene := load("res://presentation/characters/cutout/character_visual.tscn") as PackedScene
	var visual := visual_scene.instantiate() as CharacterVisual
	root.add_child(visual)
	await process_frame
	visual.present_appearance(appearance)
	for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
		visual.present_locomotion(direction, true, false)
		await process_frame
		assert(visual.hair.front_base.texture != null, "Frente sem textura em %s" % direction)
		assert(visual.hair.back_base.texture != null, "Trás sem textura em %s" % direction)
	var crossed := appearance.snapshot()
	crossed.hair_front = &"tigela"
	crossed.hair_back = &"longo"
	visual.present_appearance(crossed)
	await process_frame
	assert(visual.hair.front_base.texture != null)
	assert(visual.hair.back_base.texture != null)
	assert(not visual.hair.physics_controller.cadeias.is_empty(), "Cadeias físicas não foram criadas")
	for body_type: String in ["masc", "fem"]:
		crossed.body_type = body_type
		visual.present_appearance(crossed)
		await process_frame
		assert(visual.hair.front_base.texture != null)
		assert(visual.hair.back_base.texture != null)
	print("HAIR_INTEGRATION_OK definitions=", catalog.definitions.size(), " chains=", visual.hair.physics_controller.cadeias.size())
	quit()

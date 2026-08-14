class_name CharacterAppearanceRandomizer
extends Resource

@export_group("Optional equipment probabilities")
@export_range(0.0, 1.0, 0.01) var outerwear_probability: float = 0.45
@export_range(0.0, 1.0, 0.01) var eyewear_probability: float = 0.30
@export_range(0.0, 1.0, 0.01) var headwear_probability: float = 0.35
@export_range(0.0, 1.0, 0.01) var fantasy_hair_probability: float = 0.15


func generate(
	base: CharacterAppearance,
	clothing_catalog: ClothingCatalog,
	hair_catalog: HairCatalog,
	color_catalog: CharacterColorCatalog,
	rng: RandomNumberGenerator
) -> CharacterAppearance:
	var result := base.snapshot() if base != null else CharacterAppearance.new()
	result.body_type = "masc" if rng.randi_range(0, 1) == 0 else "fem"
	var hair_definitions := hair_catalog.get_selectable_definitions()
	result.hair_front = _pick_hair(hair_definitions, rng)
	result.hair_back = _pick_hair(hair_definitions, rng)
	result.hair_color = _pick_hair_color(color_catalog, rng)
	result.skin_color = _pick_palette(color_catalog.skin_palettes, rng)
	for slot: StringName in CharacterAppearance.SLOTS:
		var equip := slot in [&"top", &"bottom", &"footwear"] or rng.randf() < _optional_probability(slot)
		result.set_item(slot, _pick_item(clothing_catalog, slot, result.body_type, rng) if equip else &"")
		result.set_item_color(slot, _pick_palette(color_catalog.clothing_palettes, rng))
	return result


func _pick_item(catalog: ClothingCatalog, slot: StringName, body_type: String, rng: RandomNumberGenerator) -> StringName:
	var candidates: Array[ClothingItem] = []
	for item: ClothingItem in catalog.get_items_for_slot(slot):
		if catalog.is_item_complete(item.id, body_type):
			candidates.append(item)
	if candidates.is_empty():
		return &""
	return candidates[rng.randi_range(0, candidates.size() - 1)].id


func _pick_hair(definitions: Array[HairDefinition], rng: RandomNumberGenerator) -> StringName:
	if definitions.is_empty():
		return &""
	return definitions[rng.randi_range(0, definitions.size() - 1)].estilo


func _pick_hair_color(catalog: CharacterColorCatalog, rng: RandomNumberGenerator) -> StringName:
	var wanted_family := "fantasy" if rng.randf() < fantasy_hair_probability else "natural"
	var candidates: Array[CharacterColorPalette] = []
	for palette: CharacterColorPalette in catalog.hair_palettes:
		if palette.family == wanted_family:
			candidates.append(palette)
	return _pick_palette(candidates, rng)


func _pick_palette(palettes: Array[CharacterColorPalette], rng: RandomNumberGenerator) -> StringName:
	if palettes.is_empty():
		return &""
	return palettes[rng.randi_range(0, palettes.size() - 1)].id


func _optional_probability(slot: StringName) -> float:
	match slot:
		&"outerwear": return outerwear_probability
		&"eyewear": return eyewear_probability
		&"headwear": return headwear_probability
	return 0.0

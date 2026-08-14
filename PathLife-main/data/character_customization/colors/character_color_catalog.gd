class_name CharacterColorCatalog
extends Resource

const SKIN: StringName = &"skin"
const HAIR: StringName = &"hair"
const CLOTHING: StringName = &"clothing"

@export var skin_palettes: Array[CharacterColorPalette] = []
@export var hair_palettes: Array[CharacterColorPalette] = []
@export var clothing_palettes: Array[CharacterColorPalette] = []


func get_palettes(category: StringName) -> Array[CharacterColorPalette]:
	match category:
		SKIN: return skin_palettes
		HAIR: return hair_palettes
		CLOTHING: return clothing_palettes
	return []


func get_palette(category: StringName, palette_id: StringName) -> CharacterColorPalette:
	for palette: CharacterColorPalette in get_palettes(category):
		if palette != null and palette.id == palette_id:
			return palette
	return null


func normalize_id(category: StringName, palette_id: StringName) -> StringName:
	if get_palette(category, palette_id) != null:
		return palette_id
	return get_default_id(category)


func get_default_id(category: StringName) -> StringName:
	match category:
		SKIN: return &"marfim"
		HAIR: return &"castanho"
		CLOTHING: return &"branco"
	return &""

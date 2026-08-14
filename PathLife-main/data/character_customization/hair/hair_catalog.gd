class_name HairCatalog
extends Resource

@export var definitions: Array[HairDefinition] = []

var _by_id: Dictionary = {}


func get_definition(style_id: StringName) -> HairDefinition:
	_ensure_index()
	return _by_id.get(style_id) as HairDefinition


func has_style(style_id: StringName) -> bool:
	return style_id == &"" or get_definition(style_id) != null


func normalize_style_id(style_id: StringName) -> StringName:
	# "careca" é o mesmo estado visual de Nenhum; mantemos a definição no
	# catálogo de origem, mas persistimos apenas uma representação canônica.
	if style_id == &"" or style_id == &"careca":
		return &""
	return style_id if get_definition(style_id) != null else &""


func get_selectable_definitions() -> Array[HairDefinition]:
	var result: Array[HairDefinition] = []
	for definition: HairDefinition in definitions:
		if definition != null and definition.estilo != &"" and definition.estilo != &"careca":
			result.append(definition)
	result.sort_custom(func(a: HairDefinition, b: HairDefinition) -> bool:
		return get_display_name(a.estilo).naturalnocasecmp_to(get_display_name(b.estilo)) < 0)
	return result


func get_display_name(style_id: StringName) -> String:
	return String(style_id).replace("_", " ").capitalize()


func _ensure_index() -> void:
	if _by_id.size() == definitions.size():
		return
	_by_id.clear()
	for definition: HairDefinition in definitions:
		if definition != null and definition.estilo != &"":
			_by_id[definition.estilo] = definition

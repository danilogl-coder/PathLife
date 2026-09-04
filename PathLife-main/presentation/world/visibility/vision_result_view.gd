## Adaptador somente-leitura entre a apresentação e o domínio de visão.
##
## A apresentação aceita tanto VisionResult quanto Dictionary. Isso mantém os
## shaders e componentes visuais testáveis sem acoplá-los ao solver.
class_name VisionResultView
extends RefCounted

const UNKNOWN := 0
const REMEMBERED := 1
const FORCED_HIDDEN := 2
const VISIBLE := 3


## Retorna três conjuntos normalizados, sempre indexados por Vector3i.
static func extract(result: Variant) -> Dictionary:
	var visible: Dictionary = {}
	var remembered: Dictionary = {}
	var forced_hidden: Dictionary = {}
	_merge_cell_source(visible, read_first_member(
		result, [&"visible_cells", &"current_visible", &"visible"], {}
	))
	_merge_cell_source(remembered, read_first_member(
		result, [&"remembered_cells", &"remembered"], {}
	))
	_merge_cell_source(forced_hidden, read_first_member(
		result, [&"forced_hidden_cells", &"forced_hidden"], {}
	))
	var states: Variant = read_member(result, &"states", {})
	if states is Dictionary:
		for raw_cell: Variant in (states as Dictionary).keys():
			var cell: Variant = normalize_cell(raw_cell)
			if cell == null:
				continue
			var state: Variant = (states as Dictionary)[raw_cell]
			match _state_number(state):
				VISIBLE:
					visible[cell] = true
				REMEMBERED:
					remembered[cell] = true
				FORCED_HIDDEN:
					forced_hidden[cell] = true
	# A sobreposição é resolvida no shader, mas remover redundâncias reduz o
	# trabalho do renderer e deixa a prioridade explícita também na CPU.
	for cell: Variant in visible.keys():
		forced_hidden.erase(cell)
		remembered.erase(cell)
	for cell: Variant in forced_hidden.keys():
		remembered.erase(cell)
	return {
		&"visible": visible,
		&"remembered": remembered,
		&"forced_hidden": forced_hidden,
	}


## Obtém a máscara interna de uma estrutura sem confundir "campo ausente" com
## "estrutura presente, mas sem nenhuma célula visível".
static func extract_structure_interior(result: Variant, placement_id: int) -> Dictionary:
	var by_structure: Variant = read_member(result, &"visible_interior_by_structure", null)
	if not by_structure is Dictionary:
		return {&"found": false, &"cells": {}}
	var mapping := by_structure as Dictionary
	var keys: Array[Variant] = [placement_id, str(placement_id), StringName(str(placement_id))]
	for key: Variant in keys:
		if mapping.has(key):
			return {&"found": true, &"cells": _cell_set(mapping[key])}
	return {&"found": false, &"cells": {}}


static func traversed_portals(result: Variant) -> Dictionary:
	return _generic_set(read_first_member(
		result, [&"traversed_portal_ids", &"traversed_portals"], {}
	))


static func observer_placement_id(result: Variant) -> int:
	return int(read_member(result, &"observer_placement_id", -1))


static func observer_zone_id(result: Variant) -> int:
	return int(read_member(result, &"observer_zone_id", -1))


static func observer_zone_cells(result: Variant) -> Dictionary:
	return _cell_set(read_member(result, &"observer_zone_cells", {}))


static func revision(result: Variant) -> int:
	return int(read_member(result, &"revision", 0))


static func read_member(source: Variant, key: StringName, fallback: Variant = null) -> Variant:
	if source is Dictionary:
		var dictionary := source as Dictionary
		if dictionary.has(key):
			return dictionary[key]
		var string_key := String(key)
		if dictionary.has(string_key):
			return dictionary[string_key]
		return fallback
	if typeof(source) != TYPE_OBJECT or source == null or not is_instance_valid(source):
		return fallback
	var object := source as Object
	for property: Dictionary in object.get_property_list():
		if StringName(property.get(&"name", "")) == key:
			return object.get(key)
	return fallback


static func read_first_member(
	source: Variant, keys: Array[StringName], fallback: Variant = null
) -> Variant:
	for key: StringName in keys:
		if has_member(source, key):
			return read_member(source, key, fallback)
	return fallback


static func has_member(source: Variant, key: StringName) -> bool:
	if source is Dictionary:
		var dictionary := source as Dictionary
		return dictionary.has(key) or dictionary.has(String(key))
	if typeof(source) != TYPE_OBJECT or source == null or not is_instance_valid(source):
		return false
	var object := source as Object
	for property: Dictionary in object.get_property_list():
		if StringName(property.get(&"name", "")) == key:
			return true
	return false


static func normalize_cell(raw_cell: Variant) -> Variant:
	if raw_cell is Vector3i:
		return raw_cell
	if raw_cell is Vector2i:
		var cell_2d := raw_cell as Vector2i
		return Vector3i(cell_2d.x, cell_2d.y, 0)
	if raw_cell is Vector2:
		var cell_float := raw_cell as Vector2
		return Vector3i(roundi(cell_float.x), roundi(cell_float.y), 0)
	if raw_cell is Array:
		var parts := raw_cell as Array
		if parts.size() >= 2:
			return Vector3i(
				int(parts[0]), int(parts[1]), int(parts[2]) if parts.size() >= 3 else 0
			)
	return null


static func contains_cell(cell_set: Dictionary, cell: Vector3i) -> bool:
	return cell_set.has(cell) and bool(cell_set[cell])


static func _cell_set(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		for raw_cell: Variant in (source as Dictionary).keys():
			if not bool((source as Dictionary)[raw_cell]):
				continue
			var cell: Variant = normalize_cell(raw_cell)
			if cell != null:
				result[cell] = true
	elif source is Array:
		for raw_cell: Variant in source as Array:
			var cell: Variant = normalize_cell(raw_cell)
			if cell != null:
				result[cell] = true
	return result


static func _merge_cell_source(target: Dictionary, source: Variant) -> void:
	var cells := _cell_set(source)
	for cell: Variant in cells.keys():
		target[cell] = true


static func _generic_set(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		for key: Variant in (source as Dictionary).keys():
			if bool((source as Dictionary)[key]):
				result[key] = true
	elif source is Array:
		for key: Variant in source as Array:
			result[key] = true
	return result


static func _state_number(state: Variant) -> int:
	if state is int:
		return int(state)
	var label := String(state).to_upper()
	match label:
		"VISIBLE":
			return VISIBLE
		"REMEMBERED":
			return REMEMBERED
		"FORCED_HIDDEN":
			return FORCED_HIDDEN
		_:
			return UNKNOWN

class_name CharacterAppearance
extends Resource

const SLOTS: Array[StringName] = [&"top", &"outerwear", &"bottom", &"footwear", &"eyewear", &"headwear"]

@export_enum("masc", "fem") var body_type: String = "masc"
@export var top: StringName = &""
@export var outerwear: StringName = &""
@export var bottom: StringName = &""
@export var footwear: StringName = &""
@export var eyewear: StringName = &""
@export var headwear: StringName = &""

func set_body_type(new_body_type: String) -> void:
	if new_body_type not in ["masc", "fem"]:
		push_error("Corpo inválido: %s" % new_body_type)
		return
	body_type = new_body_type
	emit_changed()

func get_item(slot_name: StringName) -> StringName:
	match slot_name:
		&"top": return top
		&"outerwear": return outerwear
		&"bottom": return bottom
		&"footwear": return footwear
		&"eyewear": return eyewear
		&"headwear": return headwear
	push_error("Slot desconhecido: %s" % slot_name)
	return &""

func set_item(slot_name: StringName, item_id: StringName) -> void:
	match slot_name:
		&"top": top = item_id
		&"outerwear": outerwear = item_id
		&"bottom": bottom = item_id
		&"footwear": footwear = item_id
		&"eyewear": eyewear = item_id
		&"headwear": headwear = item_id
		_:
			push_error("Slot desconhecido: %s" % slot_name)
			return
	emit_changed()

func get_equipped_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_name: StringName in SLOTS:
		var item_id := get_item(slot_name)
		if item_id != &"": result.append(item_id)
	return result

func snapshot() -> CharacterAppearance:
	return duplicate(true) as CharacterAppearance

class_name CharacterAppearance
extends Resource

const SLOTS: Array[StringName] = [&"top", &"outerwear", &"bottom", &"footwear", &"eyewear", &"headwear"]
const HAIR_SIDES: Array[StringName] = [&"front", &"back"]

@export_enum("masc", "fem") var body_type: String = "masc"
@export var top: StringName = &""
@export var outerwear: StringName = &""
@export var bottom: StringName = &""
@export var footwear: StringName = &""
@export var eyewear: StringName = &""
@export var headwear: StringName = &""
@export var hair_front: StringName = &"basico_normal"
@export var hair_back: StringName = &"basico_normal"
@export var skin_color: StringName = &"marfim"
@export var hair_color: StringName = &"castanho"
@export var top_color: StringName = &"branco"
@export var outerwear_color: StringName = &"verde_oliva"
@export var bottom_color: StringName = &"azul_marinho"
@export var footwear_color: StringName = &"marrom"
@export var eyewear_color: StringName = &"preto"
@export var headwear_color: StringName = &"azul"

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

func get_hair(side: StringName) -> StringName:
	match side:
		&"front": return hair_front
		&"back": return hair_back
	push_error("Lado do cabelo desconhecido: %s" % side)
	return &""

func set_hair(side: StringName, style_id: StringName) -> void:
	match side:
		&"front": hair_front = style_id
		&"back": hair_back = style_id
		_:
			push_error("Lado do cabelo desconhecido: %s" % side)
			return
	emit_changed()

func get_item_color(slot_name: StringName) -> StringName:
	match slot_name:
		&"top": return top_color
		&"outerwear": return outerwear_color
		&"bottom": return bottom_color
		&"footwear": return footwear_color
		&"eyewear": return eyewear_color
		&"headwear": return headwear_color
	push_error("Slot de cor desconhecido: %s" % slot_name)
	return &""

func set_item_color(slot_name: StringName, color_id: StringName) -> void:
	match slot_name:
		&"top": top_color = color_id
		&"outerwear": outerwear_color = color_id
		&"bottom": bottom_color = color_id
		&"footwear": footwear_color = color_id
		&"eyewear": eyewear_color = color_id
		&"headwear": headwear_color = color_id
		_:
			push_error("Slot de cor desconhecido: %s" % slot_name)
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

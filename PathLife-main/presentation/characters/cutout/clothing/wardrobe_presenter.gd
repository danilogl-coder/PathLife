class_name WardrobePresenter
extends Node

@export var catalog: ClothingCatalog
@export var clothing_piece_scene: PackedScene
@export var rig: CharacterRig
@export var skirt: SaiaMalha

var _spawned_pieces: Array[Sprite2D] = []
var _last_signature: String = ""

func present(appearance: CharacterAppearance, direction: StringName) -> void:
	if appearance == null or catalog == null or clothing_piece_scene == null or rig == null or skirt == null:
		push_error("WardrobePresenter está sem referência obrigatória")
		return
	var signature := _make_signature(appearance, direction)
	if signature == _last_signature: return
	_clear_spawned_pieces()
	var equipped := appearance.get_equipped_items()
	equipped.sort_custom(_sort_items_by_layer)
	for item_id: StringName in equipped:
		_spawn_item(item_id, appearance.body_type, direction)
	_last_signature = signature

func invalidate() -> void:
	_last_signature = ""

func get_spawned_piece_count() -> int:
	return _spawned_pieces.size()

func _spawn_item(item_id: StringName, body_type: String, direction: StringName) -> void:
	var item := catalog.get_item(item_id)
	if item == null: return
	if item.visual_type == "deformable_skirt":
		skirt.equipar(StringName(body_type), direction)
		return
	var pieces := catalog.get_piece_data(item_id, body_type, direction)
	for piece_name: String in pieces:
		var bone := rig.get_piece_bone(StringName(piece_name))
		if bone == null: continue
		var data: Dictionary = pieces[piece_name]
		var sprite := clothing_piece_scene.instantiate() as Sprite2D
		sprite.name = "Clothing_%s_%s" % [item_id, piece_name]
		sprite.offset = _parse_vector2(data.get("offset_sprite", []))
		sprite.texture = catalog.load_piece_texture(String(data.get("arquivo", "")))
		bone.add_child(sprite)
		_spawned_pieces.append(sprite)

func _clear_spawned_pieces() -> void:
	skirt.remover()
	for sprite: Sprite2D in _spawned_pieces:
		if is_instance_valid(sprite):
			var parent := sprite.get_parent()
			if parent != null: parent.remove_child(sprite)
			sprite.queue_free()
	_spawned_pieces.clear()

func _sort_items_by_layer(a: StringName, b: StringName) -> bool:
	return catalog.get_layer_order(a) < catalog.get_layer_order(b)

func _make_signature(a: CharacterAppearance, direction: StringName) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [a.body_type, direction, a.top, a.outerwear, a.bottom, a.footwear, a.eyewear, a.headwear]

func _parse_vector2(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

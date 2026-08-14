class_name CharacterAppearanceState
extends Node

signal appearance_changed(appearance: CharacterAppearance)

@export var default_appearance: CharacterAppearance
@export var catalog: ClothingCatalog
@export var hair_catalog: HairCatalog
@export var color_catalog: CharacterColorCatalog

var _current: CharacterAppearance

func _ready() -> void:
	if default_appearance == null or catalog == null or hair_catalog == null or color_catalog == null:
		push_error("AppearanceState está sem configuração")
		return
	_current = default_appearance.snapshot()
	call_deferred("_publish_current")

func get_snapshot() -> CharacterAppearance:
	return _current.snapshot() if _current != null else CharacterAppearance.new()

func apply_appearance(candidate: CharacterAppearance) -> void:
	if candidate == null: return
	var validated := candidate.snapshot()
	if validated.body_type not in ["masc", "fem"]: validated.body_type = "masc"
	for slot_name: StringName in CharacterAppearance.SLOTS:
		var item_id := validated.get_item(slot_name)
		if item_id == &"": continue
		if not catalog.is_item_in_slot(item_id, slot_name) or not catalog.is_item_complete(item_id, validated.body_type):
			validated.set_item(slot_name, &"")
	for side: StringName in CharacterAppearance.HAIR_SIDES:
		var style_id := validated.get_hair(side)
		validated.set_hair(side, hair_catalog.normalize_style_id(style_id))
	validated.skin_color = color_catalog.normalize_id(CharacterColorCatalog.SKIN, validated.skin_color)
	validated.hair_color = color_catalog.normalize_id(CharacterColorCatalog.HAIR, validated.hair_color)
	for slot_name: StringName in CharacterAppearance.SLOTS:
		validated.set_item_color(slot_name, color_catalog.normalize_id(
			CharacterColorCatalog.CLOTHING, validated.get_item_color(slot_name)))
	_current = validated
	_publish_current()

func _publish_current() -> void:
	if _current != null: appearance_changed.emit(_current.snapshot())

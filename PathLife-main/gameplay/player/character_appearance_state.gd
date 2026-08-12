class_name CharacterAppearanceState
extends Node

signal appearance_changed(appearance: CharacterAppearance)

@export var default_appearance: CharacterAppearance
@export var catalog: ClothingCatalog

var _current: CharacterAppearance

func _ready() -> void:
	if default_appearance == null or catalog == null:
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
	_current = validated
	_publish_current()

func _publish_current() -> void:
	if _current != null: appearance_changed.emit(_current.snapshot())

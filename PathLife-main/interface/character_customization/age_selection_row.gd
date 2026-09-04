class_name AgeSelectionRow
extends HBoxContainer

signal selection_changed(age_id: StringName)

@export var label_text: String = "Idade"

@onready var slot_label: Label = %SlotLabel
@onready var selector: OptionButton = %Selector


func _ready() -> void:
	slot_label.text = label_text


func setup(catalog: AgeCatalog, selected_age: StringName) -> void:
	selector.clear()
	var selected_index := 0
	for profile: AgeProfile in catalog.get_sorted_profiles():
		selector.add_item(profile.display_name)
		var index := selector.item_count - 1
		selector.set_item_metadata(index, profile.id)
		if profile.id == selected_age:
			selected_index = index
	if selector.item_count > 0:
		selector.select(selected_index)


func _on_selector_item_selected(index: int) -> void:
	selection_changed.emit(StringName(selector.get_item_metadata(index)))

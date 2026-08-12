class_name CustomizationSlotRow
extends HBoxContainer

signal selection_changed(slot: StringName, item_id: StringName)

@export_enum("top", "outerwear", "bottom", "footwear", "eyewear", "headwear") var slot: String = "top"
@export var label_text: String = "Roupa"

@onready var slot_label: Label = %SlotLabel
@onready var selector: OptionButton = %Selector

func _ready() -> void:
	slot_label.text = label_text

func setup(catalog: ClothingCatalog, body_type: String, selected_item: StringName) -> void:
	selector.clear()
	selector.add_item("Nenhum")
	selector.set_item_metadata(0, &"")
	var selected_index := 0
	for item: ClothingItem in catalog.get_items_for_slot(StringName(slot)):
		if not catalog.is_item_complete(item.id, body_type): continue
		selector.add_item(item.display_name)
		var index := selector.item_count - 1
		selector.set_item_metadata(index, item.id)
		if item.id == selected_item: selected_index = index
	selector.select(selected_index)

func _on_selector_item_selected(index: int) -> void:
	selection_changed.emit(StringName(slot), StringName(selector.get_item_metadata(index)))

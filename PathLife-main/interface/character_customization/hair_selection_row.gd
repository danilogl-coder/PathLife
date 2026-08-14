class_name HairSelectionRow
extends HBoxContainer

signal selection_changed(side: StringName, style_id: StringName)

@export_enum("front", "back") var side: String = "front"
@export var label_text: String = "Cabelo"

@onready var slot_label: Label = %SlotLabel
@onready var selector: OptionButton = %Selector


func _ready() -> void:
	slot_label.text = label_text


func setup(catalog: HairCatalog, selected_style: StringName) -> void:
	selector.clear()
	selector.add_item("Nenhum")
	selector.set_item_metadata(0, &"")
	var selected_index := 0
	for definition: HairDefinition in catalog.get_selectable_definitions():
		selector.add_item(catalog.get_display_name(definition.estilo))
		var index := selector.item_count - 1
		selector.set_item_metadata(index, definition.estilo)
		if definition.estilo == selected_style:
			selected_index = index
	selector.select(selected_index)


func _on_selector_item_selected(index: int) -> void:
	selection_changed.emit(StringName(side), StringName(selector.get_item_metadata(index)))

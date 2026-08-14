class_name PaletteSelector
extends VBoxContainer

signal selection_changed(target: StringName, palette_id: StringName)

@export_enum("skin", "hair", "top", "outerwear", "bottom", "footwear", "eyewear", "headwear")
var target: String = "skin"
@export var label_text: String = "Cor"
@export var swatch_scene: PackedScene

@onready var title_label: Label = %TitleLabel
@onready var selected_label: Label = %SelectedLabel
@onready var swatches: HFlowContainer = %Swatches


func _ready() -> void:
	title_label.text = label_text


func setup(palettes: Array[CharacterColorPalette], selected_id: StringName) -> void:
	for child: Node in swatches.get_children():
		swatches.remove_child(child)
		child.queue_free()
	var selected_name := ""
	for palette: CharacterColorPalette in palettes:
		var button := swatch_scene.instantiate() as PaletteSwatchButton
		swatches.add_child(button)
		button.configure(palette, palette.id == selected_id)
		button.palette_pressed.connect(_on_palette_pressed)
		if palette.id == selected_id:
			selected_name = palette.display_name
	selected_label.text = selected_name


func _on_palette_pressed(palette_id: StringName) -> void:
	selection_changed.emit(StringName(target), palette_id)

class_name PaletteSwatchButton
extends Button

signal palette_pressed(palette_id: StringName)

var palette_id: StringName = &""


func configure(palette: CharacterColorPalette, selected: bool) -> void:
	palette_id = palette.id
	tooltip_text = palette.display_name
	button_pressed = selected
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = palette.preview_color
		box.corner_radius_top_left = 4
		box.corner_radius_top_right = 4
		box.corner_radius_bottom_left = 4
		box.corner_radius_bottom_right = 4
		var border_color := Color.WHITE if selected else Color(0.08, 0.09, 0.12, 1.0)
		var border_width := 3 if selected else 1
		box.border_color = border_color
		box.set_border_width_all(border_width)
		add_theme_stylebox_override(state, box)


func _on_pressed() -> void:
	palette_pressed.emit(palette_id)

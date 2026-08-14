class_name CharacterColorPalette
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var preview_color: Color = Color.WHITE
@export var shadow_color: Color = Color.BLACK
@export var base_color: Color = Color.WHITE
@export var highlight_color: Color = Color.WHITE
@export_enum("natural", "fantasy") var family: String = "natural"

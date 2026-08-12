class_name ClothingItem
extends Resource

@export_category("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var source_key: StringName = &""

@export_category("Equipment")
@export_enum("top", "outerwear", "bottom", "footwear", "eyewear", "headwear")
var slot: String = "top"
@export_enum("bone_sprites", "deformable_skirt")
var visual_type: String = "bone_sprites"

@export_category("Menu")
@export var icon: Texture2D

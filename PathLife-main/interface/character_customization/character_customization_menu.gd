class_name CharacterCustomizationMenu
extends Control

signal appearance_confirmed(appearance: CharacterAppearance)
signal customization_cancelled
signal menu_opened
signal menu_closed

@export var catalog: ClothingCatalog
@export var hair_catalog: HairCatalog
@export var color_catalog: CharacterColorCatalog
@export var randomizer: CharacterAppearanceRandomizer

@onready var preview: CharacterVisual = %PreviewCharacter
@onready var masc_button: Button = %MascButton
@onready var fem_button: Button = %FemButton
@onready var ne_button: Button = %NEButton
@onready var nw_button: Button = %NWButton
@onready var se_button: Button = %SEButton
@onready var sw_button: Button = %SWButton
@onready var rows: Array[CustomizationSlotRow] = [%TopRow, %OuterwearRow, %BottomRow, %FootwearRow, %EyewearRow, %HeadwearRow]
@onready var hair_rows: Array[HairSelectionRow] = [%HairFrontRow, %HairBackRow]
@onready var palette_selectors: Array[PaletteSelector] = [
	%SkinPalette, %HairPalette, %TopPalette, %OuterwearPalette,
	%BottomPalette, %FootwearPalette, %EyewearPalette, %HeadwearPalette]

var _working: CharacterAppearance
var _preview_direction: StringName = &"se"
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	hide()

func open(source: CharacterAppearance) -> void:
	if source == null or catalog == null or hair_catalog == null or color_catalog == null or randomizer == null:
		push_error("Menu recebeu aparência ou catálogo nulo")
		return
	_working = source.snapshot()
	_preview_direction = &"se"
	se_button.button_pressed = true
	_refresh_everything()
	show()
	menu_opened.emit()

func _refresh_everything() -> void:
	masc_button.button_pressed = _working.body_type == "masc"
	fem_button.button_pressed = _working.body_type == "fem"
	for row: CustomizationSlotRow in rows:
		row.setup(catalog, _working.body_type, _working.get_item(StringName(row.slot)))
	for row: HairSelectionRow in hair_rows:
		row.setup(hair_catalog, _working.get_hair(StringName(row.side)))
	for selector: PaletteSelector in palette_selectors:
		var target := StringName(selector.target)
		var category := _palette_category(target)
		var selected := _get_selected_color(target)
		selector.visible = target in [&"skin", &"hair"] or _working.get_item(target) != &""
		selector.setup(color_catalog.get_palettes(category), selected)
	_refresh_preview()

func _refresh_preview() -> void:
	preview.present_appearance(_working)
	preview.present_locomotion(_preview_direction, false, false)

func _on_slot_selection_changed(slot: StringName, item_id: StringName) -> void:
	_working.set_item(slot, item_id)
	_refresh_everything()

func _on_hair_selection_changed(side: StringName, style_id: StringName) -> void:
	_working.set_hair(side, style_id)
	_refresh_preview()

func _on_palette_selection_changed(target: StringName, palette_id: StringName) -> void:
	if target == &"skin":
		_working.skin_color = palette_id
	elif target == &"hair":
		_working.hair_color = palette_id
	else:
		_working.set_item_color(target, palette_id)
	_refresh_everything()

func _on_randomize_button_pressed() -> void:
	_working = randomizer.generate(_working, catalog, hair_catalog, color_catalog, _rng)
	_refresh_everything()

func _palette_category(target: StringName) -> StringName:
	if target == &"skin": return CharacterColorCatalog.SKIN
	if target == &"hair": return CharacterColorCatalog.HAIR
	return CharacterColorCatalog.CLOTHING

func _get_selected_color(target: StringName) -> StringName:
	if target == &"skin": return _working.skin_color
	if target == &"hair": return _working.hair_color
	return _working.get_item_color(target)

func _on_masc_button_pressed() -> void:
	_working.set_body_type("masc")
	_refresh_everything()

func _on_fem_button_pressed() -> void:
	_working.set_body_type("fem")
	_refresh_everything()

func _set_preview_direction(direction: StringName) -> void:
	_preview_direction = direction
	preview.present_locomotion(direction, false, false)

func _on_confirm_button_pressed() -> void:
	appearance_confirmed.emit(_working.snapshot())
	_close()

func _on_cancel_button_pressed() -> void:
	customization_cancelled.emit()
	_close()

func _close() -> void:
	hide()
	menu_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		customization_cancelled.emit()
		_close()
		get_viewport().set_input_as_handled()

class_name CharacterCustomizationMenu
extends Control

signal appearance_confirmed(appearance: CharacterAppearance)
signal customization_cancelled
signal menu_opened
signal menu_closed

@export var catalog: ClothingCatalog

@onready var preview: CharacterVisual = %PreviewCharacter
@onready var masc_button: Button = %MascButton
@onready var fem_button: Button = %FemButton
@onready var ne_button: Button = %NEButton
@onready var nw_button: Button = %NWButton
@onready var se_button: Button = %SEButton
@onready var sw_button: Button = %SWButton
@onready var rows: Array[CustomizationSlotRow] = [%TopRow, %OuterwearRow, %BottomRow, %FootwearRow, %EyewearRow, %HeadwearRow]

var _working: CharacterAppearance
var _preview_direction: StringName = &"se"

func _ready() -> void:
	hide()

func open(source: CharacterAppearance) -> void:
	if source == null or catalog == null:
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
	_refresh_preview()

func _refresh_preview() -> void:
	preview.present_appearance(_working)
	preview.present_locomotion(_preview_direction, false, false)

func _on_slot_selection_changed(slot: StringName, item_id: StringName) -> void:
	_working.set_item(slot, item_id)
	_refresh_preview()

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

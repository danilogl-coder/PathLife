class_name MainScene
extends Node2D

@export_category("Scene References")
@export var player: PlayerController
@export var hud: PlayerHUD
@export var appearance_state: CharacterAppearanceState
@export var customization_menu: CharacterCustomizationMenu
## Opcional. Sem ele o personagem simplesmente não envelhece sozinho.
@export var life_clock: LifeStageClock


func _ready() -> void:
	if not _references_are_valid():
		return

	player.locomotion_changed.connect(hud.present_locomotion)
	player.health_changed.connect(hud.present_health)
	hud.customization_requested.connect(_on_customization_requested)
	hud.wall_view_requested.connect(WallVisibilityManager.cycle_mode)
	WallVisibilityManager.mode_changed.connect(_on_wall_view_mode_changed)
	customization_menu.appearance_confirmed.connect(_on_appearance_confirmed)
	customization_menu.menu_opened.connect(_on_customization_menu_opened)
	customization_menu.menu_closed.connect(_on_customization_menu_closed)
	if life_clock != null:
		life_clock.stage_changed.connect(appearance_state.set_age)

	hud.present_locomotion(player.get_facing_direction(), false, false)
	hud.present_health(player.get_current_health(), player.get_maximum_health())
	hud.present_wall_view(WallVisibilityManager.get_mode_label())


func _on_wall_view_mode_changed(_mode: int, mode_label: String) -> void:
	hud.present_wall_view(mode_label)


func _on_customization_requested() -> void:
	customization_menu.open(appearance_state.get_snapshot())


func _on_appearance_confirmed(appearance: CharacterAppearance) -> void:
	appearance_state.apply_appearance(appearance)


func _on_customization_menu_opened() -> void:
	player.set_controls_enabled(false)


func _on_customization_menu_closed() -> void:
	player.set_controls_enabled(true)


func _references_are_valid() -> bool:
	if player == null:
		push_error("Main: referência Player não configurada.")
		return false
	if hud == null:
		push_error("Main: referência HUD não configurada.")
		return false
	if appearance_state == null:
		push_error("Main: referência AppearanceState não configurada.")
		return false
	if customization_menu == null:
		push_error("Main: referência CharacterCustomizationMenu não configurada.")
		return false
	return true

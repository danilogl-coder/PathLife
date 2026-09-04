## Controla, em um único lugar, o modo visual de todas as paredes do mundo.
extends Node

signal mode_changed(mode: WallViewMode, label: String)

enum WallViewMode {
	FULL,
	TRANSPARENT,
	CUTAWAY,
	AUTO,
}

const MODE_LABELS: Array[String] = ["Inteiras", "Transparentes", "Cortadas", "Automáticas"]

var current_mode: WallViewMode = WallViewMode.AUTO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_wall_view"):
		cycle_mode()
		get_viewport().set_input_as_handled()


func cycle_mode() -> WallViewMode:
	set_mode((int(current_mode) + 1) % WallViewMode.size())
	return current_mode


func set_mode(value: int) -> void:
	if value < WallViewMode.FULL or value >= WallViewMode.size():
		push_warning("Modo de parede inválido: %d" % value)
		return
	current_mode = value as WallViewMode
	for target: Node in get_tree().get_nodes_in_group(&"wall_view_targets"):
		if target.has_method(&"apply_wall_view_mode"):
			target.call(&"apply_wall_view_mode", current_mode)
	mode_changed.emit(current_mode, get_mode_label())


func register_target(target: Node) -> void:
	if not target.is_in_group(&"wall_view_targets"):
		target.add_to_group(&"wall_view_targets")
	if target.has_method(&"apply_wall_view_mode"):
		target.call_deferred(&"apply_wall_view_mode", current_mode)


func get_mode_label() -> String:
	return MODE_LABELS[int(current_mode)]

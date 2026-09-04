## Oculta uma entidade dinâmica quando sua célula não está VISIBLE.
##
## O componente altera somente CanvasItem.visible. IA, física, áudio e estado de
## gameplay permanecem ativos. Adicione-o como filho de NPCs/itens e indique o
## CanvasItem visual quando ele não for o próprio pai.
class_name VisionVisibilityTarget
extends Node

signal vision_visibility_changed(is_visible: bool, cell: Vector3i)

const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const TARGET_GROUP: StringName = &"vision_visibility_targets"

@export var target_path: NodePath
@export var logical_position_source_path: NodePath
@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_restore_target_visibility()
		elif _has_result:
			_apply_result(_last_result)
		_refresh_processing()

var _target: CanvasItem
var _position_source: Node
var _explicit_cell := Vector3i.ZERO
var _has_explicit_cell := false
var _has_result := false
var _last_result: Variant
var _hidden_by_vision := false
var _visibility_before_hide := true
var _warned_missing_target := false
var _warned_missing_cell := false
var _last_evaluated_cell: Variant = null
var _presenter_ref: WeakRef


func _ready() -> void:
	add_to_group(TARGET_GROUP)
	_resolve_references()
	_refresh_processing()
	_register_with_presenter.call_deferred()


func configure(target: CanvasItem, position_source: Node = null) -> void:
	_restore_target_visibility()
	_target = target
	_position_source = position_source if position_source != null else get_parent()
	if _has_result and enabled:
		_apply_result(_last_result)


func set_result(result: Variant) -> void:
	_last_result = result
	_has_result = result != null
	if not _has_result:
		_last_evaluated_cell = null
		_restore_target_visibility()
	elif enabled:
		_apply_result(result)
	_refresh_processing()


func set_logical_position(cell: Vector3i) -> void:
	_explicit_cell = cell
	_has_explicit_cell = true
	if _has_result and enabled:
		_apply_result(_last_result)


func clear_logical_position_override() -> void:
	_has_explicit_cell = false
	if _has_result and enabled:
		_apply_result(_last_result)


func logical_position() -> Variant:
	if _has_explicit_cell:
		return _explicit_cell
	if _position_source == null or not is_instance_valid(_position_source):
		_resolve_references()
	if _position_source == null:
		return null
	if _position_source.has_method(&"world_position"):
		return ResultView.normalize_cell(_position_source.call(&"world_position"))
	if _position_source.has_method(&"get_logical_position"):
		return ResultView.normalize_cell(_position_source.call(&"get_logical_position"))
	if _position_source.has_meta(&"world_position"):
		return ResultView.normalize_cell(_position_source.get_meta(&"world_position"))
	if _position_source.has_method(&"cell"):
		var cell_2d: Variant = _position_source.call(&"cell")
		if cell_2d is Vector2i:
			var level := 0
			if _position_source.has_method(&"height"):
				level = int(_position_source.call(&"height"))
			return Vector3i(cell_2d.x, cell_2d.y, level)
	return null


func is_visible_by_vision() -> bool:
	return not _hidden_by_vision


func _apply_result(result: Variant) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_references()
	if _target == null:
		_warn_missing_target_once()
		return
	var raw_cell: Variant = logical_position()
	if raw_cell == null:
		# Falhar aberto evita apagar definitivamente uma entidade mal configurada.
		_warn_missing_cell_once()
		_set_visible_by_vision(true, Vector3i.ZERO)
		_last_evaluated_cell = null
		return
	var cell := raw_cell as Vector3i
	_last_evaluated_cell = cell
	var sets := ResultView.extract(result)
	var currently_visible := ResultView.contains_cell(sets[&"visible"] as Dictionary, cell)
	_set_visible_by_vision(currently_visible, cell)


func _process(_delta: float) -> void:
	if not enabled or not _has_result:
		return
	var current: Variant = logical_position()
	if current is Vector3i and (
		not _last_evaluated_cell is Vector3i
		or (current as Vector3i) != (_last_evaluated_cell as Vector3i)
	):
		_apply_result(_last_result)


func _set_visible_by_vision(should_show: bool, cell: Vector3i) -> void:
	if should_show:
		if not _hidden_by_vision:
			return
		_target.visible = _visibility_before_hide
		_hidden_by_vision = false
		vision_visibility_changed.emit(_target.visible, cell)
		return
	if _hidden_by_vision:
		return
	_visibility_before_hide = _target.visible
	_target.visible = false
	_hidden_by_vision = true
	vision_visibility_changed.emit(false, cell)


func _resolve_references() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as CanvasItem
	if _target == null:
		_target = get_parent() as CanvasItem
	if logical_position_source_path != NodePath():
		_position_source = get_node_or_null(logical_position_source_path)
	if _position_source == null:
		_position_source = get_parent()
	if _position_source != null and not _position_source.has_method(&"world_position"):
		var agents := _position_source.find_children("*", "WorldGridAgent", true, false)
		if not agents.is_empty():
			_position_source = agents[0]


func _restore_target_visibility() -> void:
	if _hidden_by_vision and _target != null and is_instance_valid(_target):
		_target.visible = _visibility_before_hide
	_hidden_by_vision = false


func _refresh_processing() -> void:
	set_process(enabled and _has_result)


func _register_with_presenter() -> void:
	if not is_inside_tree():
		return
	var presenter := get_tree().get_first_node_in_group(&"visibility_presenter")
	if presenter != null and presenter.has_method(&"register_visibility_target"):
		presenter.call(&"register_visibility_target", self)
		_presenter_ref = weakref(presenter)


func _warn_missing_target_once() -> void:
	if _warned_missing_target:
		return
	_warned_missing_target = true
	push_warning("VisionVisibilityTarget sem CanvasItem alvo; componente ignorado.")


func _warn_missing_cell_once() -> void:
	if _warned_missing_cell:
		return
	_warned_missing_cell = true
	push_warning("VisionVisibilityTarget não encontrou posição lógica; mantendo entidade visível.")


func _exit_tree() -> void:
	var presenter: Node = _presenter_ref.get_ref() as Node if _presenter_ref != null else null
	if (
		presenter != null
		and is_instance_valid(presenter)
		and presenter.has_method(&"unregister_visibility_target")
	):
		presenter.call(&"unregister_visibility_target", self)
	_restore_target_visibility()

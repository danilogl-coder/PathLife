## Desenha a máscara de percepção em um SubViewport de baixa resolução.
##
## Canais: R = visível, G = memória, B = ocultação forçada. A projeção usa
## IsoCoordinateSystem, a mesma fonte de verdade usada pelo mundo.
class_name VisibilityMaskRenderer
extends Node2D

signal mask_redrawn

const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const IsoSystem = preload("res://world_generation/core/iso_coordinate_system.gd")

@export_range(0.1, 1.0, 0.05) var mask_resolution_scale := 0.5
@export var tile_size := Vector2i(128, 64)
@export_range(0, 512, 1) var visual_reveal_height_px := 192
@export_range(0.0, 2.0, 0.01) var transition_seconds := 0.15
@export var height_pixels := 26

var _source_viewport: Viewport
var _world_root: Node2D
var _mask_viewport: SubViewport
var _iso := IsoSystem.new()

var _visible: Dictionary = {}
var _remembered: Dictionary = {}
var _forced_hidden: Dictionary = {}
var _target_visible: Dictionary = {}
var _target_remembered: Dictionary = {}
var _target_forced_hidden: Dictionary = {}

var _last_source_size := Vector2i.ZERO
var _last_canvas_transform := Transform2D()
var _last_world_transform := Transform2D()
var _transitioning := false


func _ready() -> void:
	_mask_viewport = get_viewport() as SubViewport
	if _mask_viewport == null:
		push_error("VisibilityMaskRenderer precisa ser filho de um SubViewport.")
		set_process(false)
		return
	_mask_viewport.transparent_bg = true
	_mask_viewport.disable_3d = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_iso = IsoSystem.new(tile_size, height_pixels)
	_resize_mask()
	_request_redraw()


func configure(
	source_viewport: Viewport,
	world_root: Node2D = null,
	profile: Resource = null,
	projection_tile_size: Vector2i = Vector2i.ZERO,
	projection_height_pixels: int = -1
) -> void:
	_source_viewport = source_viewport
	_world_root = world_root
	if projection_tile_size.x > 0 and projection_tile_size.y > 0:
		tile_size = projection_tile_size
	if projection_height_pixels > 0:
		height_pixels = projection_height_pixels
	if profile != null:
		mask_resolution_scale = clampf(
			float(ResultView.read_member(profile, &"mask_resolution_scale", mask_resolution_scale)),
			0.1,
			1.0
		)
		visual_reveal_height_px = maxi(
			0,
			int(ResultView.read_member(profile, &"visual_reveal_height_px", visual_reveal_height_px))
		)
		transition_seconds = maxf(
			0.0,
			float(ResultView.read_member(profile, &"transition_seconds", transition_seconds))
		)
	_iso = IsoSystem.new(tile_size, height_pixels)
	_resize_mask()
	_request_redraw()


func set_result(result: Variant, immediate: bool = false) -> void:
	var sets := ResultView.extract(result)
	set_cell_sets(
		sets[&"visible"], sets[&"remembered"], sets[&"forced_hidden"], immediate
	)


func set_cell_sets(
	visible: Dictionary,
	remembered: Dictionary,
	forced_hidden: Dictionary,
	immediate: bool = false
) -> void:
	_target_visible = visible.duplicate()
	_target_remembered = remembered.duplicate()
	_target_forced_hidden = forced_hidden.duplicate()
	if immediate or is_zero_approx(transition_seconds):
		_visible = _full_strength_copy(_target_visible)
		_remembered = _full_strength_copy(_target_remembered)
		_forced_hidden = _full_strength_copy(_target_forced_hidden)
		_transitioning = false
	else:
		_seed_new_cells(_visible, _target_visible)
		_seed_new_cells(_remembered, _target_remembered)
		_seed_new_cells(_forced_hidden, _target_forced_hidden)
		_transitioning = true
	_request_redraw()


func clear(immediate: bool = true) -> void:
	set_cell_sets({}, {}, {}, immediate)


func mask_texture() -> Texture2D:
	return _mask_viewport.get_texture() if _mask_viewport != null else null


func is_transitioning() -> bool:
	return _transitioning


func visible_strength(cell: Vector3i) -> float:
	return float(_visible.get(cell, 0.0))


func _process(delta: float) -> void:
	if _mask_viewport == null:
		return
	var redraw := _sync_source_state()
	if _transitioning:
		var step := 1.0 if is_zero_approx(transition_seconds) else delta / transition_seconds
		var changed := false
		changed = _advance_channel(_visible, _target_visible, step) or changed
		changed = _advance_channel(_remembered, _target_remembered, step) or changed
		changed = _advance_channel(_forced_hidden, _target_forced_hidden, step) or changed
		_transitioning = (
			not _channel_matches(_visible, _target_visible)
			or not _channel_matches(_remembered, _target_remembered)
			or not _channel_matches(_forced_hidden, _target_forced_hidden)
		)
		redraw = redraw or changed
	if redraw:
		_request_redraw()


func _draw() -> void:
	if _mask_viewport == null:
		return
	var to_screen := _source_transform()
	var half := Vector2(tile_size) * 0.5
	var rise := Vector2(0.0, -float(visual_reveal_height_px))
	_draw_channel(_remembered, 1, to_screen, half, rise)
	_draw_channel(_forced_hidden, 2, to_screen, half, rise)
	_draw_channel(_visible, 0, to_screen, half, rise)
	mask_redrawn.emit()


func _draw_channel(
	channel: Dictionary,
	color_channel: int,
	to_screen: Transform2D,
	half: Vector2,
	rise: Vector2
) -> void:
	for raw_cell: Variant in channel:
		var strength := clampf(float(channel[raw_cell]), 0.0, 1.0)
		if strength <= 0.001:
			continue
		var cell: Variant = ResultView.normalize_cell(raw_cell)
		if cell == null:
			continue
		var color := Color(0.0, 0.0, 0.0, 1.0)
		if color_channel == 0:
			color.r = strength
		elif color_channel == 1:
			color.g = strength
		else:
			color.b = strength
		var polygon := _cell_polygon(cell as Vector3i, to_screen, half, rise)
		# Teleportes/streaming podem deixar a câmera vários milhões de pixels
		# distante das células durante alguns frames. Além de ser trabalho inútil,
		# enviar esses polígonos fora da tela perde precisão no triangulador 2D.
		if not _polygon_intersects_mask(polygon):
			continue
		draw_colored_polygon(polygon, color)


func _cell_polygon(
	cell: Vector3i,
	to_screen: Transform2D,
	half: Vector2,
	rise: Vector2
) -> PackedVector2Array:
	var center := _iso.world_to_local(cell)
	var projected := PackedVector2Array()
	projected.resize(6)
	projected[0] = (
		(to_screen * (center + Vector2(0.0, -half.y) + rise))
		* mask_resolution_scale
	)
	projected[1] = (
		(to_screen * (center + Vector2(half.x, 0.0) + rise))
		* mask_resolution_scale
	)
	projected[2] = (
		(to_screen * (center + Vector2(half.x, 0.0)))
		* mask_resolution_scale
	)
	projected[3] = (
		(to_screen * (center + Vector2(0.0, half.y)))
		* mask_resolution_scale
	)
	projected[4] = (
		(to_screen * (center + Vector2(-half.x, 0.0)))
		* mask_resolution_scale
	)
	projected[5] = (
		(to_screen * (center + Vector2(-half.x, 0.0) + rise))
		* mask_resolution_scale
	)
	return projected


func _polygon_intersects_mask(points: PackedVector2Array) -> bool:
	if points.size() < 3 or _mask_viewport == null:
		return false
	var minimum := points[0]
	var maximum := points[0]
	var doubled_area := 0.0
	for index in points.size():
		var point := points[index]
		if not point.is_finite():
			return false
		minimum = minimum.min(point)
		maximum = maximum.max(point)
		var next := points[(index + 1) % points.size()]
		doubled_area += point.x * next.y - next.x * point.y
	if absf(doubled_area) <= 0.01:
		return false
	var polygon_bounds := Rect2(minimum, maximum - minimum)
	var mask_bounds := Rect2(
		-Vector2.ONE,
		Vector2(_mask_viewport.size) + Vector2(2.0, 2.0)
	)
	return polygon_bounds.intersects(mask_bounds, true)


func _source_transform() -> Transform2D:
	var canvas := (
		_source_viewport.get_canvas_transform()
		if _source_viewport != null
		else Transform2D()
	)
	if _world_root != null and is_instance_valid(_world_root):
		return canvas * _world_root.global_transform
	return canvas


func _sync_source_state() -> bool:
	var changed := false
	var source_size := _source_size()
	if source_size != _last_source_size:
		_resize_mask()
		changed = true
	var canvas_transform := (
		_source_viewport.get_canvas_transform()
		if _source_viewport != null
		else Transform2D()
	)
	if not canvas_transform.is_equal_approx(_last_canvas_transform):
		_last_canvas_transform = canvas_transform
		changed = true
	var world_transform := (
		_world_root.global_transform
		if _world_root != null and is_instance_valid(_world_root)
		else Transform2D()
	)
	if not world_transform.is_equal_approx(_last_world_transform):
		_last_world_transform = world_transform
		changed = true
	return changed


func _resize_mask() -> void:
	if _mask_viewport == null:
		return
	var source_size := _source_size()
	_last_source_size = source_size
	_mask_viewport.size = Vector2i(
		maxi(1, ceili(float(source_size.x) * mask_resolution_scale)),
		maxi(1, ceili(float(source_size.y) * mask_resolution_scale))
	)


func _source_size() -> Vector2i:
	if _source_viewport != null:
		return Vector2i(_source_viewport.get_visible_rect().size)
	return Vector2i(get_tree().root.get_visible_rect().size)


func _request_redraw() -> void:
	queue_redraw()
	if _mask_viewport != null:
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _seed_new_cells(current: Dictionary, target: Dictionary) -> void:
	for cell: Variant in target.keys():
		if not current.has(cell):
			current[cell] = 0.0


func _advance_channel(current: Dictionary, target: Dictionary, step: float) -> bool:
	var changed := false
	for cell: Variant in target.keys():
		if not current.has(cell):
			current[cell] = 0.0
	for cell: Variant in current.keys():
		var before := float(current[cell])
		var desired := 1.0 if target.has(cell) else 0.0
		var after := move_toward(before, desired, step)
		if not is_equal_approx(before, after):
			current[cell] = after
			changed = true
		if after <= 0.001 and not target.has(cell):
			current.erase(cell)
	return changed


func _channel_matches(current: Dictionary, target: Dictionary) -> bool:
	if current.size() != target.size():
		return false
	for cell: Variant in target.keys():
		if not current.has(cell) or not is_equal_approx(float(current[cell]), 1.0):
			return false
	return true


func _full_strength_copy(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell: Variant in source.keys():
		result[cell] = 1.0
	return result

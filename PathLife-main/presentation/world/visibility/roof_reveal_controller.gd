## Controla a máscara de recorte de um único telhado.
##
## O componente é anexado como filho da StructureRoot em runtime. Cada
## instância possui ImageTexture e ShaderMaterial próprios; assim a máscara de
## uma casa nunca perfura outra casa que esteja sobreposta na tela.
class_name RoofRevealController
extends Node

signal readiness_changed(is_ready: bool)
signal mask_updated(placement_id: int, visible_cell_count: int)

const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const RoofRevealShader = preload("res://presentation/world/visibility/roof_reveal.gdshader")

@export var enabled := true:
	set(value):
		enabled = value
		_apply_enabled_state()
@export_range(0, 512, 1) var visual_reveal_height_px := 192:
	set(value):
		visual_reveal_height_px = maxi(0, value)
		_update_material_parameters()
@export_range(0.0, 1.0, 0.01) var revealed_alpha := 0.0:
	set(value):
		revealed_alpha = clampf(value, 0.0, 1.0)
		_update_material_parameters()

var placement_id: int = -1
var world_origin := Vector3i.ZERO

var _structure: Node2D
var _floor_layer: TileMapLayer
var _roof_layer: TileMapLayer
var _used_rect := Rect2i()
var _mask_image: Image
var _mask_texture: ImageTexture
var _roof_material: ShaderMaterial
var _original_material: Material
var _original_roof_visibility := true
var _roof_state_captured := false
var _local_visible: Dictionary = {}
var _wall_descriptors: Array[Dictionary] = []
var _warned_invalid := false
var _configured := false
var _setup_complete := false
var _last_roof_to_floor := Transform2D()
var _has_layer_transform := false


func _ready() -> void:
	if _structure == null:
		_structure = get_parent() as Node2D
	_resolve_placement_defaults()
	_setup_layers()


func configure(
	structure: Node2D,
	p_placement_id: int = -1,
	p_world_origin: Vector3i = Vector3i.ZERO,
	profile: Resource = null
) -> void:
	_structure = structure
	placement_id = p_placement_id
	world_origin = p_world_origin
	apply_profile(profile)
	_resolve_placement_defaults()
	if is_inside_tree():
		_setup_layers()


func apply_profile(profile: Resource) -> void:
	if profile == null:
		return
	visual_reveal_height_px = maxi(0, int(ResultView.read_member(
		profile, &"visual_reveal_height_px", visual_reveal_height_px
	)))
	revealed_alpha = clampf(float(ResultView.read_member(
		profile, &"roof_revealed_alpha", revealed_alpha
	)), 0.0, 1.0)
	enabled = bool(ResultView.read_member(profile, &"enabled", enabled))


func set_result(result: Variant) -> void:
	if not _setup_complete:
		_setup_layers()
	if not _configured and _wall_descriptors.is_empty():
		return
	if _configured:
		var interior := ResultView.extract_structure_interior(result, placement_id)
		var world_cells: Dictionary
		if bool(interior[&"found"]):
			world_cells = interior[&"cells"] as Dictionary
		elif not ResultView.has_member(result, &"visible_interior_by_structure"):
			# Compatibilidade para solvers anteriores: a interseção com as células
			# realmente pintadas no Piso ainda é segura e local à estrutura.
			world_cells = ResultView.extract(result)[&"visible"] as Dictionary
		else:
			# Um VisionResult atual sem entrada para esta casa significa explicitamente
			# zero células internas visíveis; não use o conjunto global como fallback.
			world_cells = {}
		set_visible_world_cells(world_cells)
	var observer_room: Dictionary = {}
	if ResultView.observer_placement_id(result) == placement_id:
		observer_room = ResultView.observer_zone_cells(result)
	_update_automatic_walls(observer_room, ResultView.traversed_portals(result))


func set_visible_world_cells(world_cells: Dictionary) -> void:
	if not _configured:
		_setup_layers()
	if not _configured:
		return
	var next_local: Dictionary = {}
	for raw_cell: Variant in world_cells.keys():
		var normalized: Variant = ResultView.normalize_cell(raw_cell)
		if normalized == null:
			continue
		var world_cell := normalized as Vector3i
		if world_cell.z != world_origin.z:
			continue
		var local_cell := Vector2i(
			world_cell.x - world_origin.x,
			world_cell.y - world_origin.y
		)
		if not _used_rect.has_point(local_cell):
			continue
		if _floor_layer.get_cell_source_id(local_cell) < 0:
			continue
		next_local[local_cell] = true
	if _sets_equal(_local_visible, next_local):
		return
	_local_visible = next_local
	_redraw_mask()


func clear() -> void:
	set_visible_world_cells({})
	_update_automatic_walls({}, {})


func is_ready_for_results() -> bool:
	return _configured or not _wall_descriptors.is_empty()


func is_local_cell_revealed(cell: Vector2i) -> bool:
	return _local_visible.has(cell)


func mask_value_at_local_cell(cell: Vector2i) -> float:
	if _mask_image == null or not _used_rect.has_point(cell):
		return 0.0
	return _mask_image.get_pixelv(cell - _used_rect.position).r


func set_vision_enabled(value: bool) -> void:
	enabled = value


func _setup_layers() -> void:
	if _setup_complete or _structure == null or not is_instance_valid(_structure):
		return
	_setup_complete = true
	_floor_layer = _structure.get_node_or_null(^"Piso") as TileMapLayer
	_roof_layer = _structure.get_node_or_null(^"Telhado") as TileMapLayer
	_cache_wall_descriptors()
	if _roof_layer != null and not _roof_state_captured:
		_original_material = _roof_layer.material
		_original_roof_visibility = _roof_layer.visible
		_roof_state_captured = true
	if _roof_layer == null:
		# Paredes sem telhado continuam usando o mesmo componente para AUTO;
		# simplesmente não há máscara local a configurar.
		_apply_enabled_state()
		readiness_changed.emit(is_ready_for_results())
		return
	if _floor_layer == null:
		_warn_invalid_once("Estrutura sem camadas Piso/Telhado; recorte local ignorado.")
		_apply_enabled_state()
		readiness_changed.emit(is_ready_for_results())
		return
	_used_rect = _floor_layer.get_used_rect()
	if not _used_rect.has_area():
		_warn_invalid_once("Estrutura com Telhado precisa de uma camada Piso pintada.")
		_apply_enabled_state()
		readiness_changed.emit(is_ready_for_results())
		return
	var tile_set := _floor_layer.tile_set
	if tile_set == null or tile_set.tile_size.x <= 0 or tile_set.tile_size.y <= 0:
		_warn_invalid_once("TileSet do Piso é inválido; telhado permanecerá opaco.")
		_apply_enabled_state()
		readiness_changed.emit(is_ready_for_results())
		return

	_mask_image = Image.create(
		_used_rect.size.x, _used_rect.size.y, false, Image.FORMAT_R8
	)
	_mask_image.fill(Color.BLACK)
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_roof_material = ShaderMaterial.new()
	_roof_material.shader = RoofRevealShader
	_roof_material.set_shader_parameter(&"reveal_mask", _mask_texture)
	_roof_material.set_shader_parameter(&"mask_size", Vector2(_used_rect.size))
	_roof_material.set_shader_parameter(&"used_rect_position", Vector2(_used_rect.position))
	_roof_material.set_shader_parameter(&"tile_size", Vector2(tile_set.tile_size))
	_update_layer_transform_parameters(true)
	_configured = true
	_update_material_parameters()
	_apply_enabled_state()
	readiness_changed.emit(true)


func _resolve_placement_defaults() -> void:
	if _structure == null or not is_instance_valid(_structure):
		return
	var placement: Variant = null
	if _structure.has_method(&"placement"):
		placement = _structure.call(&"placement")
	if placement == null:
		return
	if placement_id == -1:
		placement_id = int(ResultView.read_member(placement, &"placement_id", placement_id))
	var origin_value: Variant = ResultView.read_member(placement, &"origin_xy", null)
	if origin_value is Vector2i:
		var origin_xy := origin_value as Vector2i
		world_origin = Vector3i(
			origin_xy.x,
			origin_xy.y,
			int(ResultView.read_member(placement, &"foundation_height", world_origin.z))
		)


func _update_layer_transform_parameters(force: bool = false) -> void:
	if _roof_material == null or _floor_layer == null or _roof_layer == null:
		return
	var relative := _floor_layer.global_transform.affine_inverse() * _roof_layer.global_transform
	if not force and _has_layer_transform and relative.is_equal_approx(_last_roof_to_floor):
		return
	_last_roof_to_floor = relative
	_has_layer_transform = true
	_roof_material.set_shader_parameter(&"roof_to_floor_offset", relative.origin)
	_roof_material.set_shader_parameter(&"roof_to_floor_x", relative.x)
	_roof_material.set_shader_parameter(&"roof_to_floor_y", relative.y)


func _update_material_parameters() -> void:
	if _roof_material == null:
		return
	_roof_material.set_shader_parameter(
		&"visual_reveal_height_px", float(visual_reveal_height_px)
	)
	_roof_material.set_shader_parameter(&"revealed_alpha", revealed_alpha)
	_roof_material.set_shader_parameter(&"mask_valid", _configured and enabled)


func _apply_enabled_state() -> void:
	if not _setup_complete:
		return
	if _roof_layer != null and is_instance_valid(_roof_layer):
		if enabled:
			# Uma máscara inválida falha fechada: mantém a arte normal totalmente
			# visível e desativa o detector antigo que esconderia o telhado inteiro.
			_roof_layer.material = _roof_material if _configured else _original_material
			_roof_layer.visible = true
		else:
			_roof_layer.material = _original_material
			_roof_layer.visible = _original_roof_visibility
	if not enabled and _structure != null and _structure.has_method(&"set_automatic_wall_rows"):
		_structure.call(&"set_automatic_wall_rows", {})
	if _structure != null and _structure.has_method(&"set_vision_controlled"):
		_structure.call(&"set_vision_controlled", enabled)
	_update_material_parameters()
	set_process(enabled and _configured)


func _process(_delta: float) -> void:
	# Compatibilidade temporária com StructureRoot antigo, cujo detector interno
	# pode esconder a camada inteira depois de o componente ser instalado.
	if enabled and _configured and is_instance_valid(_roof_layer) and not _roof_layer.visible:
		_roof_layer.visible = true
	_update_layer_transform_parameters()


func _redraw_mask() -> void:
	if _mask_image == null or _mask_texture == null:
		return
	_mask_image.fill(Color.BLACK)
	for cell: Variant in _local_visible.keys():
		var local_cell := cell as Vector2i
		var pixel := local_cell - _used_rect.position
		_mask_image.set_pixelv(pixel, Color.WHITE)
	_mask_texture.update(_mask_image)
	mask_updated.emit(placement_id, _local_visible.size())


func _cache_wall_descriptors() -> void:
	_wall_descriptors.clear()
	if _structure == null:
		return
	var walls := _structure.get_node_or_null(^"Paredes") as TileMapLayer
	if walls == null:
		return
	for cell: Vector2i in walls.get_used_cells():
		var data := walls.get_cell_tile_data(cell)
		if data == null:
			continue
		var category := String(data.get_custom_data(&"categoria")).to_lower()
		if category not in ["parede", "porta", "janela"]:
			continue
		var directions: Array[String] = []
		var portal_direction := String(data.get_custom_data(&"direcao")).to_lower()
		if portal_direction in ["ne", "nw", "se", "sw"]:
			directions.append(portal_direction)
		else:
			# Nas paredes a orientação semântica mora em `peca`; `direcao` é
			# preenchida pelas portas/janelas. Cantos contribuem com duas bordas.
			var piece := String(data.get_custom_data(&"peca")).to_lower()
			match piece:
				"ne", "nw", "se", "sw":
					directions.append(piece)
				"quina_n", "canto":
					directions.assign(["ne", "nw"])
				"quina_e":
					directions.assign(["ne", "se"])
				"quina_s":
					directions.assign(["se", "sw"])
				"quina_w":
					directions.assign(["nw", "sw"])
		for direction: String in directions:
			_wall_descriptors.append({
				&"cell": cell,
				&"category": category,
				&"direction": direction,
			})


func _update_automatic_walls(
	visible_interior_world: Dictionary, traversed_portals: Dictionary
) -> void:
	if _structure == null or not _structure.has_method(&"set_automatic_wall_rows"):
		return
	if not enabled:
		_structure.call(&"set_automatic_wall_rows", {})
		return
	var rows: Dictionary = {}
	for descriptor: Dictionary in _wall_descriptors:
		var local_cell := descriptor[&"cell"] as Vector2i
		var direction := String(descriptor[&"direction"])
		var category := String(descriptor[&"category"])
		var row := 1
		var world_a := Vector3i(
			world_origin.x + local_cell.x,
			world_origin.y + local_cell.y,
			world_origin.z
		)
		var offset := _direction_offset(direction)
		var world_b := world_a + Vector3i(offset.x, offset.y, 0)
		# A arte pode autorar a mesma borda pelo lado oposto (por exemplo `nw`
		# numa célula externa). O que importa é ela ser SE/SW *vista a partir do
		# cômodo atual*, não o nome bruto gravado no tile.
		var room_on_a := visible_interior_world.has(world_a)
		var room_on_b := visible_interior_world.has(world_b)
		if (
			(direction == "se" and room_on_a)
			or (direction == "sw" and room_on_a)
			or (direction == "nw" and room_on_b)
			or (direction == "ne" and room_on_b)
		):
			row = 0
		if category in ["porta", "janela"]:
			var kind := "door" if category == "porta" else "window"
			var portal_id := StringName(
				"%d|%d,%d|%s|%s"
				% [placement_id, local_cell.x, local_cell.y, direction, kind]
			)
			if traversed_portals.has(portal_id) or traversed_portals.has(String(portal_id)):
				row = 2
		var current_row := int(rows.get(local_cell, 1))
		if row == 2 or (row == 0 and current_row != 2):
			rows[local_cell] = row
		elif not rows.has(local_cell):
			rows[local_cell] = current_row
	_structure.call(&"set_automatic_wall_rows", rows)


func _direction_offset(direction: String) -> Vector2i:
	match direction:
		"ne":
			return Vector2i(0, -1)
		"nw":
			return Vector2i(-1, 0)
		"se":
			return Vector2i(1, 0)
		"sw":
			return Vector2i(0, 1)
	return Vector2i.ZERO


func _sets_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key: Variant in left.keys():
		if not right.has(key):
			return false
	return true


func _warn_invalid_once(message: String) -> void:
	if _warned_invalid:
		return
	_warned_invalid = true
	push_warning("RoofRevealController: %s" % message)


func _exit_tree() -> void:
	if _roof_state_captured and is_instance_valid(_roof_layer):
		_roof_layer.material = _original_material
		_roof_layer.visible = _original_roof_visibility
	if _structure != null and is_instance_valid(_structure):
		if _structure.has_method(&"set_automatic_wall_rows"):
			_structure.call(&"set_automatic_wall_rows", {})
		if _structure.has_method(&"set_vision_controlled"):
			_structure.call(&"set_vision_controlled", false)

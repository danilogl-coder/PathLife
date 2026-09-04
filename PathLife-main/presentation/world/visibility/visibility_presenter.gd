## Ponte entre VisionSystem e a apresentação do mundo.
##
## Mantém três responsabilidades de renderização coordenadas, porém
## independentes do solver: fog global, recorte local de telhados e ocultação de
## entidades dinâmicas. Aceita VisionResult ou Dictionary através de
## VisionResultView.
class_name VisibilityPresenter
extends CanvasLayer

signal result_presented(revision: int)
signal structure_roof_registered(placement_id: int, controller: RoofRevealController)

const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const MaskRendererScript = preload(
	"res://presentation/world/visibility/visibility_mask_renderer.gd"
)
const RoofControllerScript = preload(
	"res://presentation/world/visibility/roof_reveal_controller.gd"
)
const CompositeShader = preload(
	"res://presentation/world/visibility/visibility_composite.gdshader"
)

@export var enabled := true:
	set(value):
		enabled = value
		_apply_enabled_state()
@export var profile: Resource
@export var vision_system_path: NodePath
@export var chunk_manager_path: NodePath
@export var world_root_path: NodePath
@export var auto_discover_dependencies := true

var _vision_system: Node
var _chunk_manager: Node
var _world_root: Node2D
var _mask_viewport: SubViewport
var _mask_renderer: VisibilityMaskRenderer
var _fog_overlay: TextureRect
var _fog_material: ShaderMaterial
var _roof_controllers: Dictionary = {}
var _explicit_targets: Dictionary = {}
var _last_result: Variant
var _has_result := false
var _ready_done := false
var _last_enabled_applied: Variant = null


func _ready() -> void:
	add_to_group(&"visibility_presenter")
	layer = 10
	_ensure_render_nodes()
	_resolve_paths()
	if profile == null and _vision_system != null:
		profile = ResultView.read_member(_vision_system, &"profile", null) as Resource
	_apply_profile()
	_configure_mask_renderer()
	_bind_system_signals()
	_bind_chunk_signals()
	_ready_done = true
	_apply_enabled_state()
	_register_existing_structures.call_deferred()
	_register_existing_targets.call_deferred()


func configure(
	vision_system: Node,
	world_root: Node2D = null,
	p_profile: Resource = null,
	chunk_manager: Node = null
) -> void:
	_unbind_system_signals()
	_unbind_chunk_signals()
	_vision_system = vision_system
	_world_root = world_root
	if p_profile != null:
		profile = p_profile
	elif profile == null and _vision_system != null:
		profile = ResultView.read_member(_vision_system, &"profile", null) as Resource
	_chunk_manager = chunk_manager
	if is_inside_tree():
		_ensure_render_nodes()
		_apply_profile()
		_configure_mask_renderer()
		_bind_system_signals()
		_bind_chunk_signals()
		_register_existing_structures()
		_register_existing_targets()


func set_result(result: Variant, immediate: bool = false) -> void:
	_last_result = result
	_has_result = result != null
	if _mask_renderer != null:
		_mask_renderer.set_result(result, immediate)
	_prune_roof_controllers()
	for reference: Variant in _roof_controllers.values():
		var controller := _weak_node(reference) as RoofRevealController
		if controller != null:
			controller.set_result(result)
	_apply_result_to_targets(result)
	_apply_enabled_state()
	result_presented.emit(ResultView.revision(result))


func clear(immediate: bool = true) -> void:
	_last_result = null
	_has_result = false
	if _mask_renderer != null:
		_mask_renderer.clear(immediate)
	for reference: Variant in _roof_controllers.values():
		var controller := _weak_node(reference) as RoofRevealController
		if controller != null:
			controller.clear()
	_apply_result_to_targets(null)
	_apply_enabled_state()


func set_vision_enabled(value: bool) -> void:
	enabled = value


## Reaplica valores visuais de um Resource editado em runtime sem recriar nós,
## materiais ou texturas locais das estruturas.
func apply_profile_changes(updated_profile: Resource = null) -> void:
	if updated_profile != null:
		profile = updated_profile
	if profile != null and profile.has_method(&"sanitize"):
		profile.call(&"sanitize")
	_apply_profile()
	_configure_mask_renderer()
	_prune_roof_controllers()
	for reference: Variant in _roof_controllers.values():
		var controller := _weak_node(reference) as RoofRevealController
		if controller != null:
			controller.apply_profile(profile)
	_apply_enabled_state()


func register_structure(
	structure: Node2D,
	p_placement_id: int = -1,
	p_world_origin: Vector3i = Vector3i.ZERO
) -> RoofRevealController:
	if structure == null or not is_instance_valid(structure):
		return null
	# Estruturas com paredes, mas sem telhado, ainda usam o componente para o
	# cutaway AUTO. Props de sprites sem nenhuma camada semântica são ignorados.
	var has_roof := structure.get_node_or_null(^"Telhado") is TileMapLayer
	var has_walls := structure.get_node_or_null(^"Paredes") is TileMapLayer
	if not has_roof and not has_walls:
		return null
	var identity := _structure_identity(structure, p_placement_id, p_world_origin)
	var resolved_id := int(identity[&"placement_id"])
	var resolved_origin := identity[&"world_origin"] as Vector3i
	var existing := structure.get_node_or_null(^"VisionRoofReveal") as RoofRevealController
	var controller: RoofRevealController = existing
	if controller == null:
		controller = RoofControllerScript.new() as RoofRevealController
		controller.name = "VisionRoofReveal"
		controller.set_meta(&"vision_presenter_owned", true)
		controller.configure(structure, resolved_id, resolved_origin, profile)
		structure.add_child(controller)
	else:
		if not controller.has_meta(&"vision_presenter_owned"):
			controller.set_meta(&"vision_presenter_owned", false)
		controller.configure(structure, resolved_id, resolved_origin, profile)
	controller.set_vision_enabled(enabled)
	_roof_controllers[resolved_id] = weakref(controller)
	if _has_result:
		controller.set_result(_last_result)
	structure_roof_registered.emit(resolved_id, controller)
	return controller


func unregister_structure(placement_id: int) -> void:
	var reference: Variant = _roof_controllers.get(placement_id)
	_roof_controllers.erase(placement_id)
	var controller := _weak_node(reference) as RoofRevealController
	if controller != null and controller.get_meta(&"vision_presenter_owned", true):
		controller.queue_free()


func register_visibility_target(target: VisionVisibilityTarget) -> void:
	if target == null or not is_instance_valid(target):
		return
	_explicit_targets[target.get_instance_id()] = weakref(target)
	if _has_result:
		target.set_result(_last_result)


func unregister_visibility_target(target: VisionVisibilityTarget) -> void:
	if target != null:
		_explicit_targets.erase(target.get_instance_id())


func bind_chunk_manager(chunk_manager: Node) -> void:
	_unbind_chunk_signals()
	_chunk_manager = chunk_manager
	_bind_chunk_signals()


## Compatível diretamente com ChunkManager.structure_integrated.
func on_structure_integrated(
	_owner_chunk: Vector2i, placement: Variant, structure: Node2D
) -> void:
	var placement_id := int(ResultView.read_member(placement, &"placement_id", -1))
	var origin_xy: Variant = ResultView.read_member(placement, &"origin_xy", Vector2i.ZERO)
	var foundation := int(ResultView.read_member(placement, &"foundation_height", 0))
	var origin := Vector3i.ZERO
	if origin_xy is Vector2i:
		var origin_2d := origin_xy as Vector2i
		origin = Vector3i(origin_2d.x, origin_2d.y, foundation)
	register_structure(structure, placement_id, origin)


## Compatível diretamente com ChunkManager.structure_will_unload.
func on_structure_will_unload(_owner_chunk: Vector2i, placement_id: int) -> void:
	unregister_structure(placement_id)


func mask_texture() -> Texture2D:
	return _mask_renderer.mask_texture() if _mask_renderer != null else null


func _on_visibility_changed(result: Variant) -> void:
	set_result(result)


func _on_profile_changed(updated_profile: VisionProfile) -> void:
	apply_profile_changes(updated_profile)


func _ensure_render_nodes() -> void:
	_mask_viewport = get_node_or_null(^"MaskViewport") as SubViewport
	if _mask_viewport == null:
		_mask_viewport = SubViewport.new()
		_mask_viewport.name = "MaskViewport"
		_mask_viewport.transparent_bg = true
		_mask_viewport.disable_3d = true
		add_child(_mask_viewport)
	_mask_renderer = _mask_viewport.get_node_or_null(^"MaskRenderer") as VisibilityMaskRenderer
	if _mask_renderer == null:
		_mask_renderer = MaskRendererScript.new() as VisibilityMaskRenderer
		_mask_renderer.name = "MaskRenderer"
		_mask_viewport.add_child(_mask_renderer)
	_fog_overlay = get_node_or_null(^"FogOverlay") as TextureRect
	if _fog_overlay == null:
		_fog_overlay = TextureRect.new()
		_fog_overlay.name = "FogOverlay"
		_fog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fog_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fog_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_fog_overlay)
	_fog_material = _fog_overlay.material as ShaderMaterial
	if _fog_material == null or _fog_material.shader != CompositeShader:
		_fog_material = ShaderMaterial.new()
		_fog_material.shader = CompositeShader
		_fog_overlay.material = _fog_material
	_fog_overlay.texture = _mask_renderer.mask_texture()


func _resolve_paths() -> void:
	if vision_system_path != NodePath():
		_vision_system = get_node_or_null(vision_system_path)
	if chunk_manager_path != NodePath():
		_chunk_manager = get_node_or_null(chunk_manager_path)
	if world_root_path != NodePath():
		_world_root = get_node_or_null(world_root_path) as Node2D
	if not auto_discover_dependencies:
		return
	if _vision_system == null:
		_vision_system = get_tree().get_first_node_in_group(&"vision_system")
	if _chunk_manager == null:
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager")
	if _world_root == null and get_tree().current_scene != null:
		_world_root = get_tree().current_scene.get_node_or_null(^"World") as Node2D


func _configure_mask_renderer() -> void:
	if _mask_renderer == null:
		return
	var settings: Variant = ResultView.read_member(_chunk_manager, &"settings", null)
	var projection_tile_size := ResultView.read_member(
		settings, &"tile_size", _mask_renderer.tile_size
	) as Vector2i
	var projection_height := int(ResultView.read_member(
		settings, &"height_pixels", _mask_renderer.height_pixels
	))
	_mask_renderer.configure(
		get_viewport(),
		_world_root,
		profile,
		projection_tile_size,
		projection_height
	)
	if _fog_overlay != null:
		_fog_overlay.texture = _mask_renderer.mask_texture()


func _apply_profile() -> void:
	if profile == null:
		return
	enabled = bool(ResultView.read_member(profile, &"enabled", enabled))
	if _fog_material == null:
		return
	var unknown_value: Variant = _fog_material.get_shader_parameter(&"unknown_color")
	var remembered_value: Variant = _fog_material.get_shader_parameter(&"remembered_color")
	var forced_value: Variant = _fog_material.get_shader_parameter(&"forced_hidden_color")
	var unknown := (
		unknown_value as Color
		if unknown_value is Color
		else Color(0.012, 0.016, 0.024, 1.0)
	)
	var remembered := (
		remembered_value as Color
		if remembered_value is Color
		else Color(0.035, 0.048, 0.065, 0.82)
	)
	var forced := (
		forced_value as Color
		if forced_value is Color
		else Color(0.008, 0.010, 0.016, 1.0)
	)
	unknown.a = clampf(float(ResultView.read_member(
		profile, &"unknown_opacity", unknown.a
	)), 0.0, 1.0)
	remembered.a = clampf(float(ResultView.read_member(
		profile, &"remembered_opacity", remembered.a
	)), 0.0, 1.0)
	forced.a = clampf(float(ResultView.read_member(
		profile, &"forced_hidden_opacity", forced.a
	)), 0.0, 1.0)
	_fog_material.set_shader_parameter(&"unknown_color", unknown)
	_fog_material.set_shader_parameter(&"remembered_color", remembered)
	_fog_material.set_shader_parameter(&"forced_hidden_color", forced)
	var resolution_scale := clampf(float(ResultView.read_member(
		profile, &"mask_resolution_scale", 0.5
	)), 0.1, 1.0)
	var softness_px := maxf(0.0, float(ResultView.read_member(
		profile, &"edge_softness_px", 3.0
	)))
	_fog_material.set_shader_parameter(
		&"edge_softness_texels", softness_px * resolution_scale
	)


func _apply_enabled_state() -> void:
	if not _ready_done:
		return
	var state_changed := (
		_last_enabled_applied == null or bool(_last_enabled_applied) != enabled
	)
	if _fog_overlay != null:
		_fog_overlay.visible = enabled and _has_result
	for reference: Variant in _roof_controllers.values():
		var controller := _weak_node(reference) as RoofRevealController
		if controller != null:
			controller.set_vision_enabled(enabled)
			if state_changed and enabled and _has_result:
				controller.set_result(_last_result)
	for target: VisionVisibilityTarget in _all_targets():
		target.enabled = enabled
	_last_enabled_applied = enabled


func _bind_system_signals() -> void:
	if _vision_system == null or not is_instance_valid(_vision_system):
		return
	var callable := Callable(self, "_on_visibility_changed")
	if _vision_system.has_signal(&"visibility_changed") and not _vision_system.is_connected(
		&"visibility_changed", callable
	):
		_vision_system.connect(&"visibility_changed", callable)
	var profile_callable := Callable(self, "_on_profile_changed")
	if _vision_system.has_signal(&"profile_changed") and not _vision_system.is_connected(
		&"profile_changed", profile_callable
	):
		_vision_system.connect(&"profile_changed", profile_callable)


func _unbind_system_signals() -> void:
	if _vision_system == null or not is_instance_valid(_vision_system):
		return
	var callable := Callable(self, "_on_visibility_changed")
	if _vision_system.has_signal(&"visibility_changed") and _vision_system.is_connected(
		&"visibility_changed", callable
	):
		_vision_system.disconnect(&"visibility_changed", callable)
	var profile_callable := Callable(self, "_on_profile_changed")
	if _vision_system.has_signal(&"profile_changed") and _vision_system.is_connected(
		&"profile_changed", profile_callable
	):
		_vision_system.disconnect(&"profile_changed", profile_callable)


func _bind_chunk_signals() -> void:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		return
	var integrated := Callable(self, "on_structure_integrated")
	var unloading := Callable(self, "on_structure_will_unload")
	if _chunk_manager.has_signal(&"structure_integrated") and not _chunk_manager.is_connected(
		&"structure_integrated", integrated
	):
		_chunk_manager.connect(&"structure_integrated", integrated)
	if _chunk_manager.has_signal(&"structure_will_unload") and not _chunk_manager.is_connected(
		&"structure_will_unload", unloading
	):
		_chunk_manager.connect(&"structure_will_unload", unloading)


func _unbind_chunk_signals() -> void:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		return
	var integrated := Callable(self, "on_structure_integrated")
	var unloading := Callable(self, "on_structure_will_unload")
	if _chunk_manager.has_signal(&"structure_integrated") and _chunk_manager.is_connected(
		&"structure_integrated", integrated
	):
		_chunk_manager.disconnect(&"structure_integrated", integrated)
	if _chunk_manager.has_signal(&"structure_will_unload") and _chunk_manager.is_connected(
		&"structure_will_unload", unloading
	):
		_chunk_manager.disconnect(&"structure_will_unload", unloading)


func _register_existing_structures() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"structure_roots"):
		var structure := node as Node2D
		if structure != null:
			register_structure(structure)


func _register_existing_targets() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"vision_visibility_targets"):
		var target := node as VisionVisibilityTarget
		if target != null:
			register_visibility_target(target)


func _apply_result_to_targets(result: Variant) -> void:
	for target: VisionVisibilityTarget in _all_targets():
		target.set_result(result)


func _all_targets() -> Array[VisionVisibilityTarget]:
	var result: Array[VisionVisibilityTarget] = []
	var seen: Dictionary = {}
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"vision_visibility_targets"):
			var target := node as VisionVisibilityTarget
			if target != null:
				result.append(target)
				seen[target.get_instance_id()] = true
	for id: Variant in _explicit_targets.keys():
		var target := _weak_node(_explicit_targets[id]) as VisionVisibilityTarget
		if target == null:
			_explicit_targets.erase(id)
		elif not seen.has(target.get_instance_id()):
			result.append(target)
	return result


func _structure_identity(
	structure: Node2D, requested_id: int, requested_origin: Vector3i
) -> Dictionary:
	var resolved_id := requested_id
	var resolved_origin := requested_origin
	var placement: Variant = null
	if structure.has_method(&"placement"):
		placement = structure.call(&"placement")
	if placement != null:
		if resolved_id == -1:
			resolved_id = int(ResultView.read_member(placement, &"placement_id", -1))
		var origin: Variant = ResultView.read_member(placement, &"origin_xy", null)
		if origin is Vector2i:
			var origin_xy := origin as Vector2i
			resolved_origin = Vector3i(
				origin_xy.x,
				origin_xy.y,
				int(ResultView.read_member(
					placement, &"foundation_height", resolved_origin.z
				))
			)
	if resolved_id == -1:
		# Fallback transitório para cenas de teste sem StructurePlacement. O
		# recorte ainda usa a interseção das células visíveis com o piso.
		resolved_id = structure.get_instance_id()
	return {&"placement_id": resolved_id, &"world_origin": resolved_origin}


func _prune_roof_controllers() -> void:
	for placement: Variant in _roof_controllers.keys():
		if _weak_node(_roof_controllers[placement]) == null:
			_roof_controllers.erase(placement)


func _weak_node(reference: Variant) -> Node:
	if reference is WeakRef:
		return (reference as WeakRef).get_ref() as Node
	return reference as Node


func _exit_tree() -> void:
	_unbind_system_signals()
	_unbind_chunk_signals()

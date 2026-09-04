## Coordenador de runtime do sistema de percepção.
##
## Agrupa invalidações do mesmo frame, liga jogador/streaming/save e mantém o
## solver puro separado da SceneTree. Estruturas são registradas por snapshot e
## removidas antes de seu ChunkView receber queue_free().
class_name VisionSystem
extends Node

signal visibility_changed(result: VisionResult)
signal profile_changed(updated_profile: VisionProfile)

const Baker := preload("res://world_generation/visibility/structure_vision_baker.gd")
const Registry := preload("res://world_generation/visibility/vision_topology_registry.gd")
const Solver := preload("res://gameplay/vision/vision_solver.gd")
const MemoryCodec := preload("res://gameplay/vision/vision_memory_codec.gd")

@export var profile: VisionProfile
@export var debug_invalidations := false

var registry: VisionTopologyRegistry = Registry.new()
var latest_result: VisionResult

var _solver: VisionSolver = Solver.new()
var _player: Node
var _grid_agent: Node
var _chunk_manager: Node
var _save_manager: Node
var _structure_refs: Dictionary = {}
var _structure_portal_callbacks: Dictionary = {}
var _memory: Dictionary = {}
var _packed_memory: Dictionary = {}
var _memory_cells_by_chunk: Dictionary = {}
var _chunk_size := 16
var _memory_loaded_from_save := false
var _update_queued := false
var _pending_reasons: Dictionary = {}
var _pending_observer_position: Variant = null
var _revision := 0
var _reported_warnings: Dictionary = {}
var _connected_profile: VisionProfile
var _applying_profile_changes := false


func _ready() -> void:
	add_to_group(&"vision_system")
	if profile == null:
		profile = VisionProfile.new()
	profile.sanitize()
	_bind_profile_signal()


func configure(
	player: Node,
	chunk_manager: Node,
	save_manager: Node = null
) -> void:
	_resolve_chunk_size_from(chunk_manager)
	_set_save_manager(save_manager)
	bind_player(player)
	bind_chunk_manager(chunk_manager)
	invalidate(&"configured")


## Reaplica um VisionProfile editado em runtime ao input, solver e presenters.
## Alterações diretas em Resources customizados devem terminar nesta chamada;
## `Resource.changed` também é aceito quando uma ferramenta emite o sinal.
func apply_profile_changes() -> void:
	if _applying_profile_changes:
		return
	if profile == null:
		profile = VisionProfile.new()
	_bind_profile_signal()
	_applying_profile_changes = true
	profile.sanitize()
	_apply_look_profile()
	_applying_profile_changes = false
	profile_changed.emit(profile)
	invalidate(&"profile_changed")


func bind_player(player: Node) -> void:
	_unbind_player_signals()
	_player = player
	_grid_agent = null
	_pending_observer_position = null
	if _player == null or not is_instance_valid(_player):
		return
	_connect_if_available(_player, &"facing_changed", Callable(self, "_on_facing_changed"))
	_grid_agent = _player.get_node_or_null(^"WorldGridAgent")
	if _grid_agent == null and _player.has_signal(&"step_finished"):
		_grid_agent = _player
	if _grid_agent != null:
		_connect_if_available(_grid_agent, &"step_started", Callable(self, "_on_step_started"))
		_connect_if_available(_grid_agent, &"step_finished", Callable(self, "_on_step_finished"))
		_connect_if_available(_grid_agent, &"height_changed", Callable(self, "_on_height_changed"))
	_apply_look_profile()
	invalidate(&"player_bound")


func bind_chunk_manager(chunk_manager: Node) -> void:
	_unbind_chunk_signals()
	_chunk_manager = chunk_manager
	_resolve_chunk_size()
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		return
	_connect_if_available(
		_chunk_manager,
		&"structure_integrated",
		Callable(self, "_on_structure_integrated")
	)
	_connect_if_available(
		_chunk_manager,
		&"structure_will_unload",
		Callable(self, "_on_structure_will_unload")
	)
	_register_existing_structures()
	invalidate(&"streaming_bound")


func register_structure(snapshot: StructureVisionSnapshot) -> void:
	if snapshot == null:
		return
	registry.register_structure(snapshot)
	for warning: String in snapshot.warnings:
		var warning_key := "%d|%s" % [snapshot.placement_id, warning]
		if _reported_warnings.has(warning_key):
			continue
		_reported_warnings[warning_key] = true
		push_warning("Visão estrutural: %s" % warning)
	invalidate(&"structure_registered")


func unregister_structure(placement_id: int) -> void:
	_disconnect_structure_portal_signal(placement_id)
	_structure_refs.erase(placement_id)
	registry.unregister_structure(placement_id)
	invalidate(&"structure_unregistered")


func set_portal_open(portal_id: StringName, is_open: bool) -> void:
	var portal := registry.portal(portal_id)
	if portal == null or portal.permanent:
		return
	registry.set_portal_open(portal_id, is_open)
	if _save_manager != null and _save_manager.has_method(&"set_portal_state"):
		_save_manager.call(&"set_portal_state", portal.id, is_open)
	invalidate(&"portal_changed")


## Marca o cálculo como sujo. Vários eventos no mesmo frame geram um único
## solve; force_update continua disponível para testes e primeiro frame visual.
func invalidate(reason: StringName = &"manual") -> void:
	_pending_reasons[reason] = true
	if _update_queued:
		return
	_update_queued = true
	call_deferred(&"_flush_invalidations")


func force_update() -> VisionResult:
	_update_queued = false
	if profile == null:
		profile = VisionProfile.new()
	_bind_profile_signal()
	profile.sanitize()
	if _player == null or not is_instance_valid(_player):
		return latest_result
	var origin := _observer_position()
	var facing := _observer_facing()
	var started_usec := Time.get_ticks_usec()
	var result := _solver.solve(
		origin, facing, registry, profile, _working_memory(origin, profile.maximum_range_cells)
	)
	_revision += 1
	result.revision = _revision
	_merge_new_memory(result.visible_cells)
	latest_result = result
	if debug_invalidations:
		print(
			"[Visão] revisão %d | %.3f ms | %d visíveis | motivos=%s"
			% [
				_revision,
				float(Time.get_ticks_usec() - started_usec) / 1000.0,
				result.visible_cells.size(),
				_pending_reasons.keys(),
			]
		)
	_pending_reasons.clear()
	visibility_changed.emit(result)
	return result


func import_memory(cells: Variant) -> void:
	var previous_chunk_keys := _packed_memory.keys()
	_memory.clear()
	_packed_memory.clear()
	_memory_cells_by_chunk.clear()
	if cells is Dictionary and _looks_like_packed_chunks(cells as Dictionary):
		_packed_memory = MemoryCodec.duplicate_chunks(cells as Dictionary)
		# JSON cru pode fornecer Base64; o decode aceita ambos, mas normalizamos
		# novamente para manter apenas PackedByteArray internamente.
		_memory = MemoryCodec.decode_chunks(cells as Dictionary, _chunk_size)
		_packed_memory = MemoryCodec.encode_cells(_memory, _chunk_size)
	else:
		if cells is Dictionary:
			for raw_cell: Variant in cells:
				if raw_cell is Vector3i and bool((cells as Dictionary)[raw_cell]):
					_memory[raw_cell] = true
		elif cells is Array:
			for raw_cell: Variant in cells:
				if raw_cell is Vector3i:
					_memory[raw_cell] = true
		_packed_memory = MemoryCodec.encode_cells(_memory, _chunk_size)
	_rebuild_memory_chunk_index()
	if _save_manager != null and _save_manager.has_method(&"set_seen_chunk"):
		for old_key: Variant in previous_chunk_keys:
			if not _packed_memory.has(String(old_key)):
				_save_manager.call(
					&"set_seen_chunk", StringName(String(old_key)), PackedByteArray()
				)
	_sync_all_packed_memory_to_save()
	invalidate(&"memory_imported")


func export_memory() -> Dictionary:
	return _memory.duplicate()


func export_packed_memory() -> Dictionary:
	return MemoryCodec.duplicate_chunks(_packed_memory)


func clear_memory() -> void:
	if _save_manager != null and _save_manager.has_method(&"set_seen_chunk"):
		for key: Variant in _packed_memory:
			_save_manager.call(&"set_seen_chunk", StringName(String(key)), PackedByteArray())
	_memory.clear()
	_packed_memory.clear()
	_memory_cells_by_chunk.clear()
	invalidate(&"memory_cleared")


func _flush_invalidations() -> void:
	if not _update_queued:
		return
	force_update()


func _set_save_manager(save_manager: Node) -> void:
	if _save_manager == save_manager and _memory_loaded_from_save:
		return
	var manager_changed := _save_manager != save_manager
	_save_manager = save_manager
	_memory_loaded_from_save = false
	if manager_changed:
		_memory.clear()
		_packed_memory.clear()
		_memory_cells_by_chunk.clear()
	if _save_manager == null or not is_instance_valid(_save_manager):
		return
	if _save_manager.has_method(&"seen_chunks"):
		var saved: Variant = _save_manager.call(&"seen_chunks")
		if saved is Dictionary:
			_memory = MemoryCodec.decode_chunks(saved as Dictionary, _chunk_size)
			_packed_memory = MemoryCodec.encode_cells(_memory, _chunk_size)
			_rebuild_memory_chunk_index()
	_memory_loaded_from_save = true


func _on_structure_integrated(
	_owner_chunk: Vector2i, placement: Variant, structure: Node
) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	# Props procedurais como decks de sprites também usam StructureRoot, mas não
	# autoram topologia. Sem Piso/Paredes semânticos não há contribuição a
	# registrar nem motivo para repetir warnings por placement.
	if (
		not structure.get_node_or_null(^"Piso") is TileMapLayer
		and not structure.get_node_or_null(^"Paredes") is TileMapLayer
	):
		return
	var placement_id := int(_read_property(placement, &"placement_id", 0))
	_restore_structure_portals(structure)
	_connect_structure_portal_signal(structure, placement_id)
	var snapshot: StructureVisionSnapshot
	if structure.has_method(&"vision_snapshot"):
		snapshot = structure.call(&"vision_snapshot") as StructureVisionSnapshot
	else:
		snapshot = Baker.new().bake(structure, placement)
	if snapshot == null:
		return
	_structure_refs[placement_id] = weakref(structure)
	register_structure(snapshot)


func _on_structure_will_unload(_owner_chunk: Vector2i, placement_id: int) -> void:
	unregister_structure(placement_id)


func _restore_structure_portals(structure: Node) -> void:
	if (
		_save_manager == null
		or not _save_manager.has_method(&"has_portal_state")
		or not structure.has_method(&"vision_portals")
		or not structure.has_method(&"set_vision_portal_open")
	):
		return
	var descriptors: Variant = structure.call(&"vision_portals")
	if not descriptors is Array:
		return
	for raw_descriptor: Variant in descriptors:
		if not raw_descriptor is Dictionary:
			continue
		var descriptor := raw_descriptor as Dictionary
		if bool(descriptor.get(&"permanent", false)):
			continue
		var portal_id := StringName(String(descriptor.get(&"id", "")))
		if portal_id == &"" or not bool(_save_manager.call(&"has_portal_state", portal_id)):
			continue
		var saved_open := bool(_save_manager.call(&"portal_state", portal_id, false))
		structure.call(&"set_vision_portal_open", portal_id, saved_open)


func _connect_structure_portal_signal(structure: Node, placement_id: int) -> void:
	_disconnect_structure_portal_signal(placement_id)
	if not structure.has_signal(&"vision_portal_changed"):
		return
	var callback := Callable(self, "_on_structure_portal_changed").bind(placement_id)
	structure.connect(&"vision_portal_changed", callback)
	_structure_portal_callbacks[placement_id] = callback
	_structure_refs[placement_id] = weakref(structure)


func _disconnect_structure_portal_signal(placement_id: int) -> void:
	var reference: Variant = _structure_refs.get(placement_id)
	var structure: Node = null
	if reference is WeakRef:
		structure = (reference as WeakRef).get_ref() as Node
	var callback: Callable = _structure_portal_callbacks.get(placement_id, Callable())
	if (
		structure != null
		and is_instance_valid(structure)
		and callback.is_valid()
		and structure.has_signal(&"vision_portal_changed")
		and structure.is_connected(&"vision_portal_changed", callback)
	):
		structure.disconnect(&"vision_portal_changed", callback)
	_structure_portal_callbacks.erase(placement_id)


func _on_structure_portal_changed(
	portal_id: StringName, is_open: bool, _placement_id: int
) -> void:
	set_portal_open(portal_id, is_open)


func _register_existing_structures() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"structure_roots"):
		var placement: Variant = node.call(&"placement") if node.has_method(&"placement") else null
		if placement != null:
			_on_structure_integrated(Vector2i.ZERO, placement, node)


func _on_facing_changed(_direction: StringName, _logical_vector: Vector2i) -> void:
	invalidate(&"facing_changed")


func _on_step_started(
	_from_position: Vector3i, to_position: Vector3i, _transition: int
) -> void:
	_pending_observer_position = to_position
	invalidate(&"step_started")


func _on_step_finished(_world_position: Vector3i) -> void:
	_pending_observer_position = null
	invalidate(&"step_finished")


func _on_height_changed(_level: int) -> void:
	invalidate(&"height_changed")


func _observer_position() -> Vector3i:
	if _pending_observer_position is Vector3i:
		return _pending_observer_position as Vector3i
	if _player != null and _player.has_method(&"world_position"):
		var position: Variant = _player.call(&"world_position")
		if position is Vector3i:
			return position
	if _grid_agent != null and _grid_agent.has_method(&"world_position"):
		var agent_position: Variant = _grid_agent.call(&"world_position")
		if agent_position is Vector3i:
			return agent_position
	return Vector3i.ZERO


func _observer_facing() -> Vector2i:
	if _player != null and _player.has_method(&"get_facing_vector"):
		var facing: Variant = _player.call(&"get_facing_vector")
		if facing is Vector2i and facing != Vector2i.ZERO:
			return facing
	return Vector2i(1, 0)


func _merge_new_memory(visible_cells: Dictionary) -> void:
	var changed_chunks: Dictionary = {}
	for raw_cell: Variant in visible_cells:
		if not raw_cell is Vector3i or _memory.has(raw_cell):
			continue
		var cell := raw_cell as Vector3i
		_memory[cell] = true
		_index_memory_cell(cell)
		var key := MemoryCodec.add_cell(_packed_memory, cell, _chunk_size)
		changed_chunks[String(key)] = true
	if _save_manager == null or not _save_manager.has_method(&"set_seen_chunk"):
		return
	for key: String in changed_chunks:
		_save_manager.call(
			&"set_seen_chunk",
			StringName(key),
			(_packed_memory[key] as PackedByteArray).duplicate()
		)


func _sync_all_packed_memory_to_save() -> void:
	if _save_manager == null or not _save_manager.has_method(&"set_seen_chunk"):
		return
	for key: String in _packed_memory:
		_save_manager.call(
			&"set_seen_chunk",
			StringName(key),
			(_packed_memory[key] as PackedByteArray).duplicate()
		)


func _working_memory(origin: Vector3i, radius: int) -> Dictionary:
	var result: Dictionary = {}
	var safe_radius := maxi(0, radius)
	var minimum_chunk := ChunkMath.world_to_chunk(
		Vector2i(origin.x - safe_radius, origin.y - safe_radius), _chunk_size
	)
	var maximum_chunk := ChunkMath.world_to_chunk(
		Vector2i(origin.x + safe_radius, origin.y + safe_radius), _chunk_size
	)
	for chunk_y in range(minimum_chunk.y, maximum_chunk.y + 1):
		for chunk_x in range(minimum_chunk.x, maximum_chunk.x + 1):
			var key := String(MemoryCodec.chunk_key(Vector2i(chunk_x, chunk_y), origin.z))
			var chunk_cells: Variant = _memory_cells_by_chunk.get(key)
			if not chunk_cells is Dictionary:
				continue
			for cell: Variant in chunk_cells:
				result[cell] = true
	return result


func _index_memory_cell(cell: Vector3i) -> void:
	var key := String(MemoryCodec.key_for_cell(cell, _chunk_size))
	var cells := _memory_cells_by_chunk.get(key, {}) as Dictionary
	cells[cell] = true
	_memory_cells_by_chunk[key] = cells


func _rebuild_memory_chunk_index() -> void:
	_memory_cells_by_chunk.clear()
	for raw_cell: Variant in _memory:
		if raw_cell is Vector3i:
			_index_memory_cell(raw_cell)


func _looks_like_packed_chunks(data: Dictionary) -> bool:
	for key: Variant in data:
		if key is String or key is StringName:
			var value: Variant = data[key]
			if value is PackedByteArray or value is String:
				return true
	return false


func _resolve_chunk_size() -> void:
	_resolve_chunk_size_from(_chunk_manager)


func _resolve_chunk_size_from(manager: Node) -> void:
	if manager == null:
		return
	var settings: Variant = _read_property(manager, &"settings", null)
	if settings is Object:
		_chunk_size = maxi(1, int(_read_property(settings, &"chunk_size", _chunk_size)))


func _apply_look_profile() -> void:
	if _player == null or profile == null:
		return
	_set_property_if_present(
		_player, &"look_mouse_deadzone_pixels", profile.look_mouse_deadzone_px
	)
	_set_property_if_present(_player, &"look_stick_deadzone", profile.look_stick_deadzone)


func _connect_if_available(source: Node, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _unbind_player_signals() -> void:
	_disconnect_if_available(_player, &"facing_changed", Callable(self, "_on_facing_changed"))
	_disconnect_if_available(_grid_agent, &"step_started", Callable(self, "_on_step_started"))
	_disconnect_if_available(_grid_agent, &"step_finished", Callable(self, "_on_step_finished"))
	_disconnect_if_available(_grid_agent, &"height_changed", Callable(self, "_on_height_changed"))


func _unbind_chunk_signals() -> void:
	_disconnect_if_available(
		_chunk_manager,
		&"structure_integrated",
		Callable(self, "_on_structure_integrated")
	)
	_disconnect_if_available(
		_chunk_manager,
		&"structure_will_unload",
		Callable(self, "_on_structure_will_unload")
	)


func _disconnect_if_available(
	source: Node, signal_name: StringName, callback: Callable
) -> void:
	if (
		source != null
		and is_instance_valid(source)
		and source.has_signal(signal_name)
		and source.is_connected(signal_name, callback)
	):
		source.disconnect(signal_name, callback)


func _read_property(source: Variant, property_name: StringName, fallback: Variant) -> Variant:
	if not source is Object or source == null or not is_instance_valid(source):
		return fallback
	var object := source as Object
	for descriptor: Dictionary in object.get_property_list():
		if StringName(descriptor.get(&"name", "")) == property_name:
			return object.get(property_name)
	return fallback


func _set_property_if_present(source: Object, property_name: StringName, value: Variant) -> void:
	for descriptor: Dictionary in source.get_property_list():
		if StringName(descriptor.get(&"name", "")) == property_name:
			source.set(property_name, value)
			return


func _bind_profile_signal() -> void:
	if _connected_profile == profile:
		return
	_unbind_profile_signal()
	_connected_profile = profile
	if _connected_profile != null:
		var callback := Callable(self, "_on_profile_resource_changed")
		if not _connected_profile.changed.is_connected(callback):
			_connected_profile.changed.connect(callback)


func _unbind_profile_signal() -> void:
	if _connected_profile == null:
		return
	var callback := Callable(self, "_on_profile_resource_changed")
	if _connected_profile.changed.is_connected(callback):
		_connected_profile.changed.disconnect(callback)
	_connected_profile = null


func _on_profile_resource_changed() -> void:
	apply_profile_changes()


func _exit_tree() -> void:
	_unbind_profile_signal()
	_unbind_player_signals()
	_unbind_chunk_signals()
	for placement_id: int in _structure_portal_callbacks.keys():
		_disconnect_structure_portal_signal(placement_id)

## Solver puro de campo de visão em grade.
##
## Não acessa SceneTree, física, TileMap ou renderização. Cada raio percorre
## bordas com DDA supercover; cruzamentos exatos de canto testam as duas bordas
## de forma conservadora.
class_name VisionSolver
extends RefCounted

const STATE := preload("res://gameplay/vision/vision_state.gd")
const RESULT := preload("res://gameplay/vision/vision_result.gd")
const PORTAL := preload("res://world_generation/visibility/vision_portal.gd")

const CORNER_EPSILON := 0.0000001


class RayStep:
	extends RefCounted

	var from_offset := Vector2i.ZERO
	var to_offset := Vector2i.ZERO
	var crossing_time := 0.0
	var is_corner := false
	var direction_index := 0


class RayCandidate:
	extends RefCounted

	var offset := Vector2i.ZERO
	var distance := 0.0
	var steps: Array[RayStep] = []


class CandidateSet:
	extends RefCounted

	var offsets: Array[Vector2i] = []
	var traced: Array[RayCandidate] = []


class SealedCandidateSet:
	extends RefCounted

	var interior: Array[RayCandidate] = []
	var guard_offsets: Array[Vector2i] = []


## Cache geométrico independente do mundo. Os mesmos offsets/raios são
## reutilizados enquanto o perfil e a direção não mudarem.
var _candidate_cache: Dictionary = {}
var _step_cache: Dictionary = {}
var _relative_edge_cache: Dictionary = {}
var _sealed_candidate_cache: Dictionary = {}
var _no_portals: Array[StringName] = []


func solve(
	origin: Vector3i,
	facing: Vector2i,
	registry: VisionTopologyRegistry,
	profile: VisionProfile,
	remembered: Variant = {}
) -> VisionResult:
	var result := RESULT.new()
	result.origin = origin
	result.facing = facing
	_seed_memory(result, remembered)
	if profile == null or not profile.enabled:
		return result

	var observer_context: Dictionary = {}
	if registry != null:
		observer_context = registry.internal_context_at(origin)
	_apply_observer_context(result, observer_context)
	var sealed_context: Dictionary = _sealed_context(observer_context, registry, profile)
	_apply_forced_memory(result, sealed_context)
	var radius := maxi(1, profile.maximum_range_cells)
	var relative_edges: Dictionary = {}
	if registry != null and registry.has_edges_near(origin, radius):
		relative_edges = _relative_edge_map(origin, radius, registry)
	var needs_edge_traces := not relative_edges.is_empty()
	var candidates := _candidates_for(facing, profile)
	if not needs_edge_traces and sealed_context.is_empty():
		for offset: Vector2i in candidates.offsets:
			result.mark_visible(origin + Vector3i(offset.x, offset.y, 0))
		if registry != null and registry.has_floor_cells():
			_populate_visible_interiors(result, registry)
		return result
	var traced_candidates: Array[RayCandidate] = candidates.traced
	if not sealed_context.is_empty():
		var sealed_snapshot := sealed_context["snapshot"] as StructureVisionSnapshot
		var sealed_candidates := _sealed_candidates(
			origin, facing, profile, registry, sealed_snapshot, candidates
		)
		traced_candidates = sealed_candidates.interior
		for guard_offset: Vector2i in sealed_candidates.guard_offsets:
			result.mark_forced_hidden(
				origin + Vector3i(guard_offset.x, guard_offset.y, 0)
			)
	for candidate: RayCandidate in traced_candidates:
		var target := origin + Vector3i(candidate.offset.x, candidate.offset.y, 0)
		var crossed_portals: Variant = _no_portals
		if needs_edge_traces:
			crossed_portals = _trace_steps(
				candidate.steps,
				candidate.distance,
				relative_edges,
				registry,
				profile,
				radius
			)
			if crossed_portals == null:
				continue
		result.mark_visible(target)
		for portal_id: StringName in crossed_portals as Array[StringName]:
			result.mark_portal_traversed(portal_id)

	_populate_visible_interiors(result, registry)
	return result


func has_line_of_sight(
	origin: Vector3i,
	target: Vector3i,
	registry: VisionTopologyRegistry,
	profile: VisionProfile
) -> bool:
	if origin.z != target.z or profile == null:
		return false
	var delta := Vector2(target.x - origin.x, target.y - origin.y)
	if delta.length_squared() > float(profile.maximum_range_cells * profile.maximum_range_cells):
		return false
	if registry == null or not registry.has_edges_near(origin, profile.maximum_range_cells):
		return true
	var relative_edges := _relative_edge_map(origin, profile.maximum_range_cells, registry)
	if relative_edges.is_empty():
		return true
	return _trace_steps(
		_steps_for_offset(Vector2i(target.x - origin.x, target.y - origin.y)),
		delta.length(),
		relative_edges,
		registry,
		profile,
		profile.maximum_range_cells
	) != null


func supercover_transitions(origin: Vector3i, target: Vector3i) -> Array:
	var result: Array = []
	if origin.z != target.z or origin == target:
		return result
	var target_offset := Vector2i(target.x - origin.x, target.y - origin.y)
	for step: RayStep in _steps_for_offset(target_offset):
		result.append({
			"from": origin + Vector3i(step.from_offset.x, step.from_offset.y, 0),
			"to": origin + Vector3i(step.to_offset.x, step.to_offset.y, 0),
			"t": step.crossing_time,
			"corner": step.is_corner,
		})
	return result


func _steps_for_offset(target_offset: Vector2i) -> Array[RayStep]:
	if _step_cache.has(target_offset):
		return _step_cache[target_offset] as Array[RayStep]
	var result: Array[RayStep] = []
	if target_offset == Vector2i.ZERO:
		_step_cache[target_offset] = result
		return result
	var dx := target_offset.x
	var dy := target_offset.y
	var step_x := signi(dx)
	var step_y := signi(dy)
	var absolute_x := absi(dx)
	var absolute_y := absi(dy)
	var t_delta_x := INF if absolute_x == 0 else 1.0 / float(absolute_x)
	var t_delta_y := INF if absolute_y == 0 else 1.0 / float(absolute_y)
	var t_max_x := INF if absolute_x == 0 else 0.5 * t_delta_x
	var t_max_y := INF if absolute_y == 0 else 0.5 * t_delta_y
	var current := Vector2i.ZERO

	while current != target_offset:
		if absf(t_max_x - t_max_y) <= CORNER_EPSILON:
			var cross_time := t_max_x
			var x_neighbor := current + Vector2i(step_x, 0)
			var y_neighbor := current + Vector2i(0, step_y)
			var diagonal := current + Vector2i(step_x, step_y)
			# O raio toca o vértice compartilhado por quatro células. Testar os
			# dois lados de saída e os dois de entrada evita vazamento diagonal
			# independentemente do lado em que o L de paredes foi autorado.
			result.append(_ray_step(current, x_neighbor, cross_time, true))
			result.append(_ray_step(current, y_neighbor, cross_time, true))
			result.append(_ray_step(x_neighbor, diagonal, cross_time, true))
			result.append(_ray_step(y_neighbor, diagonal, cross_time, true))
			current = diagonal
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			var next_x := current + Vector2i(step_x, 0)
			result.append(_ray_step(current, next_x, t_max_x, false))
			current = next_x
			t_max_x += t_delta_x
		else:
			var next_y := current + Vector2i(0, step_y)
			result.append(_ray_step(current, next_y, t_max_y, false))
			current = next_y
			t_max_y += t_delta_y
	_step_cache[target_offset] = result
	return result


func _ray_step(
	from_offset: Vector2i, to_offset: Vector2i, crossing_time: float, is_corner: bool
) -> RayStep:
	var step := RayStep.new()
	step.from_offset = from_offset
	step.to_offset = to_offset
	step.crossing_time = crossing_time
	step.is_corner = is_corner
	step.direction_index = _direction_index(to_offset - from_offset)
	return step


## Retorna null quando bloqueado; caso contrário, os portais atravessados.
func _trace_steps(
	steps: Array[RayStep],
	total_distance: float,
	relative_edges: Dictionary,
	registry: VisionTopologyRegistry,
	profile: VisionProfile,
	radius: int
) -> Variant:
	if steps.is_empty():
		return _no_portals
	if registry == null:
		return _no_portals

	var crossed_portals: Array[StringName] = []
	for step: RayStep in steps:
		var edge_key := _relative_step_key(step, radius)
		var edges := relative_edges.get(edge_key, []) as Array
		if edges.is_empty():
			continue
		# Qualquer contribuição opaca na mesma borda prevalece.
		for edge: VisionEdge in edges:
			if edge.opaque:
				return null
		for edge: VisionEdge in edges:
			if edge.portal_id == &"":
				continue
			var portal := registry.portal(edge.portal_id)
			if portal == null or not portal.transmits_sight(profile):
				return null
			if portal.id in crossed_portals:
				continue
			crossed_portals.append(portal.id)
			if crossed_portals.size() > profile.maximum_portal_hops:
				return null
			var remaining_distance := total_distance * maxf(
				0.0, 1.0 - step.crossing_time
			)
			if remaining_distance > float(portal.reveal_depth(profile)) + CORNER_EPSILON:
				return null
	return crossed_portals if not crossed_portals.is_empty() else _no_portals


func _relative_edge_map(
	origin: Vector3i, radius: int, registry: VisionTopologyRegistry
) -> Dictionary:
	var cache_key := "%d|%d|%d,%d,%d|%d" % [
		registry.get_instance_id(),
		registry.topology_revision,
		origin.x,
		origin.y,
		origin.z,
		radius,
	]
	if _relative_edge_cache.has(cache_key):
		return _relative_edge_cache[cache_key] as Dictionary
	if _relative_edge_cache.size() >= 64:
		_relative_edge_cache.clear()
	var result: Dictionary = {}
	for group_variant: Variant in registry.edge_groups_near(origin, radius):
		var contributions := group_variant as Array
		if contributions.is_empty():
			continue
		var edge := contributions[0] as VisionEdge
		var a := Vector2i(edge.cell_a.x - origin.x, edge.cell_a.y - origin.y)
		var b := Vector2i(edge.cell_b.x - origin.x, edge.cell_b.y - origin.y)
		if (
			absi(a.x) > radius or absi(a.y) > radius
			or absi(b.x) > radius or absi(b.y) > radius
		):
			continue
		result[_relative_edge_key(a, b, radius)] = contributions
		result[_relative_edge_key(b, a, radius)] = contributions
	_relative_edge_cache[cache_key] = result
	return result


func _relative_step_key(step: RayStep, radius: int) -> int:
	var width := radius * 2 + 1
	return (
		((step.from_offset.y + radius) * width + step.from_offset.x + radius) * 4
		+ step.direction_index
	)


func _relative_edge_key(a: Vector2i, b: Vector2i, radius: int) -> int:
	var width := radius * 2 + 1
	return (((a.y + radius) * width + a.x + radius) * 4 + _direction_index(b - a))


func _direction_index(delta: Vector2i) -> int:
	if delta.x > 0:
		return 0
	if delta.x < 0:
		return 1
	if delta.y > 0:
		return 2
	return 3


func _sealed_candidates(
	origin: Vector3i,
	facing: Vector2i,
	profile: VisionProfile,
	registry: VisionTopologyRegistry,
	snapshot: StructureVisionSnapshot,
	candidates: CandidateSet
) -> SealedCandidateSet:
	var cache_key := "%d|%d|%d|%d,%d,%d|%d,%d|%d|%.4f|%d" % [
		registry.get_instance_id(),
		registry.topology_revision,
		snapshot.placement_id,
		origin.x,
		origin.y,
		origin.z,
		facing.x,
		facing.y,
		profile.maximum_range_cells,
		profile.front_cone_degrees,
		profile.peripheral_range_cells,
	]
	if _sealed_candidate_cache.has(cache_key):
		return _sealed_candidate_cache[cache_key] as SealedCandidateSet
	if _sealed_candidate_cache.size() >= 64:
		_sealed_candidate_cache.clear()
	var partition := SealedCandidateSet.new()
	for candidate: RayCandidate in candidates.traced:
		var target := origin + Vector3i(candidate.offset.x, candidate.offset.y, 0)
		if snapshot.is_internal_cell(target):
			partition.interior.append(candidate)
	# A faixa azul protege a borda visual inteira da casa, inclusive atrás do
	# cone. Limitá-la aos candidatos do cone deixaria o blur do canal R sangrar
	# por paredes que coincidam com a borda angular.
	var radius_squared := profile.maximum_range_cells * profile.maximum_range_cells
	for guard_variant: Variant in snapshot.exterior_guard_cells:
		var guard := guard_variant as Vector3i
		if guard.z != origin.z:
			continue
		var offset := Vector2i(guard.x - origin.x, guard.y - origin.y)
		if offset.length_squared() <= radius_squared:
			partition.guard_offsets.append(offset)
	_sealed_candidate_cache[cache_key] = partition
	return partition


func _candidates_for(facing: Vector2i, profile: VisionProfile) -> CandidateSet:
	var key := "%d|%.4f|%d|%d,%d" % [
		profile.maximum_range_cells,
		profile.front_cone_degrees,
		profile.peripheral_range_cells,
		facing.x,
		facing.y,
	]
	if _candidate_cache.has(key):
		return _candidate_cache[key] as CandidateSet
	# Perfis editados repetidamente no Inspector não devem fazer o cache crescer
	# sem limite durante uma sessão longa.
	if _candidate_cache.size() >= 32:
		_candidate_cache.clear()
	var candidate_set := CandidateSet.new()
	var radius := maxi(1, profile.maximum_range_cells)
	var radius_squared := radius * radius
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var distance_squared := offset_x * offset_x + offset_y * offset_y
			if distance_squared > radius_squared:
				continue
			if not _inside_view_cone(offset_x, offset_y, facing, profile):
				continue
			var candidate := RayCandidate.new()
			candidate.offset = Vector2i(offset_x, offset_y)
			candidate.distance = sqrt(float(distance_squared))
			candidate.steps = _steps_for_offset(candidate.offset)
			candidate_set.offsets.append(candidate.offset)
			candidate_set.traced.append(candidate)
	_candidate_cache[key] = candidate_set
	return candidate_set


func _inside_view_cone(
	offset_x: int,
	offset_y: int,
	facing: Vector2i,
	profile: VisionProfile
) -> bool:
	var distance_squared := offset_x * offset_x + offset_y * offset_y
	if distance_squared == 0:
		return true
	if distance_squared <= profile.peripheral_range_cells * profile.peripheral_range_cells:
		return true
	if profile.front_cone_degrees >= 359.999 or facing == Vector2i.ZERO:
		return true
	var view := Vector2(facing).normalized()
	var direction := Vector2(float(offset_x), float(offset_y)).normalized()
	var threshold := cos(deg_to_rad(profile.front_cone_degrees * 0.5))
	return view.dot(direction) >= threshold


func _seed_memory(result: VisionResult, remembered: Variant) -> void:
	if remembered is Dictionary:
		for cell_variant: Variant in remembered:
			if cell_variant is Vector3i and bool(remembered[cell_variant]):
				result.mark_remembered(cell_variant)
	elif remembered is Array:
		for cell_variant: Variant in remembered:
			if cell_variant is Vector3i:
				result.mark_remembered(cell_variant)


func _apply_observer_context(result: VisionResult, context: Dictionary) -> void:
	if context.is_empty():
		return
	var snapshot := context["snapshot"] as StructureVisionSnapshot
	var zone_id := int(context["zone_id"])
	result.observer_placement_id = snapshot.placement_id
	result.observer_zone_id = zone_id
	var zone := snapshot.zone_by_id(zone_id) as VisionZone
	if zone != null:
		result.observer_zone_cells = zone.cells.duplicate()


func _sealed_context(
	context: Dictionary,
	registry: VisionTopologyRegistry,
	profile: VisionProfile
) -> Dictionary:
	if registry == null or not profile.sealed_structure_blocks_memory:
		return {}
	if context.is_empty():
		return {}
	var snapshot: StructureVisionSnapshot = context["snapshot"]
	var zone_id := int(context["zone_id"])
	if registry.can_zone_reach_exterior(snapshot.placement_id, zone_id, profile):
		return {}
	return {
		"snapshot": snapshot,
		"placement_id": snapshot.placement_id,
	}


func _is_forced_outside(target: Vector3i, context: Dictionary) -> bool:
	if context.is_empty():
		return false
	var snapshot: StructureVisionSnapshot = context["snapshot"]
	return not snapshot.is_internal_cell(target)


func _apply_forced_memory(result: VisionResult, context: Dictionary) -> void:
	if context.is_empty():
		return
	var explored := result.explored_cells.keys()
	for cell_variant: Variant in explored:
		if cell_variant is Vector3i and _is_forced_outside(cell_variant, context):
			result.mark_forced_hidden(cell_variant)


func _populate_visible_interiors(
	result: VisionResult,
	registry: VisionTopologyRegistry
) -> void:
	if registry == null:
		return
	for cell_variant: Variant in result.visible_cells:
		var cell: Vector3i = cell_variant
		for placement_id: int in registry.internal_owner_ids(cell):
			result.mark_interior_visible(placement_id, cell)

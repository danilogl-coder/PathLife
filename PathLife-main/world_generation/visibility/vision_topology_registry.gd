## Índice mundial das contribuições de estruturas carregadas.
##
## Mantém contribuições separadas por placement_id para que unload seja
## reversível. Sobreposições são conservadoras: qualquer parede opaca vence.
class_name VisionTopologyRegistry
extends RefCounted

const EDGE := preload("res://world_generation/visibility/vision_edge.gd")
const PORTAL := preload("res://world_generation/visibility/vision_portal.gd")
const ZONE := preload("res://world_generation/visibility/vision_zone.gd")

var _snapshots: Dictionary = {}
## edge key -> Array[VisionEdge]
var _edges: Dictionary = {}
## Índice quente do solver: célula A -> célula B -> contribuições. Evita criar
## StringName formatada para cada passo de cada raio.
var _edge_neighbors: Dictionary = {}
## bucket Vector3i -> Dictionary[edge key, Array[VisionEdge]]. Permite montar
## um índice relativo pequeno por solve, sem consultar toda a topologia global.
var _edge_groups_by_bucket: Dictionary = {}
var _portals: Dictionary = {}
var _portal_aliases: Dictionary = {}
## Vector3i -> Array[int]
var _floor_owners: Dictionary = {}
var topology_revision: int = 0


func register_structure(snapshot: StructureVisionSnapshot) -> void:
	if snapshot == null:
		return
	_snapshots[snapshot.placement_id] = snapshot
	_rebuild_indexes()
	topology_revision += 1


func unregister_structure(placement_id: int) -> void:
	if _snapshots.erase(placement_id):
		_rebuild_indexes()
		topology_revision += 1


func clear() -> void:
	_snapshots.clear()
	_edges.clear()
	_edge_neighbors.clear()
	_edge_groups_by_bucket.clear()
	_portals.clear()
	_portal_aliases.clear()
	_floor_owners.clear()
	topology_revision += 1


func has_structure(placement_id: int) -> bool:
	return _snapshots.has(placement_id)


func snapshot(placement_id: int) -> StructureVisionSnapshot:
	return _snapshots.get(placement_id) as StructureVisionSnapshot


func snapshots() -> Array:
	var ids := _snapshots.keys()
	ids.sort()
	var result: Array = []
	for placement_id: Variant in ids:
		result.append(_snapshots[placement_id])
	return result


func edges_between(a: Vector3i, b: Vector3i) -> Array:
	var neighbors: Variant = _edge_neighbors.get(a)
	if neighbors is Dictionary:
		return (neighbors as Dictionary).get(b, []) as Array
	return []


func has_edges_near(origin: Vector3i, radius: int) -> bool:
	var safe_radius := maxi(0, radius)
	var minimum := Vector2i(origin.x - safe_radius, origin.y - safe_radius)
	var maximum := Vector2i(origin.x + safe_radius, origin.y + safe_radius)
	var minimum_bucket := Vector2i(
		floori(float(minimum.x) / 16.0), floori(float(minimum.y) / 16.0)
	)
	var maximum_bucket := Vector2i(
		floori(float(maximum.x) / 16.0), floori(float(maximum.y) / 16.0)
	)
	for bucket_y in range(minimum_bucket.y, maximum_bucket.y + 1):
		for bucket_x in range(minimum_bucket.x, maximum_bucket.x + 1):
			if _edge_groups_by_bucket.has(Vector3i(bucket_x, bucket_y, origin.z)):
				return true
	return false


func edge_groups_near(origin: Vector3i, radius: int) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var safe_radius := maxi(0, radius)
	var minimum_bucket := Vector2i(
		floori(float(origin.x - safe_radius) / 16.0),
		floori(float(origin.y - safe_radius) / 16.0)
	)
	var maximum_bucket := Vector2i(
		floori(float(origin.x + safe_radius) / 16.0),
		floori(float(origin.y + safe_radius) / 16.0)
	)
	for bucket_y in range(minimum_bucket.y, maximum_bucket.y + 1):
		for bucket_x in range(minimum_bucket.x, maximum_bucket.x + 1):
			var bucket_key := Vector3i(bucket_x, bucket_y, origin.z)
			var bucket: Variant = _edge_groups_by_bucket.get(bucket_key)
			if not bucket is Dictionary:
				continue
			for edge_key: Variant in bucket:
				if seen.has(edge_key):
					continue
				seen[edge_key] = true
				result.append((bucket as Dictionary)[edge_key])
	return result


func most_restrictive_edge_between(a: Vector3i, b: Vector3i) -> VisionEdge:
	var candidates := edges_between(a, b)
	for edge: VisionEdge in candidates:
		if edge.opaque:
			return edge
	return candidates[0] as VisionEdge if not candidates.is_empty() else null


func portal(portal_id: StringName) -> VisionPortal:
	if _portals.has(portal_id):
		return _portals[portal_id] as VisionPortal
	var stem := _portal_stem(String(portal_id))
	var canonical: StringName = _portal_aliases.get(stem, &"")
	return _portals.get(canonical) as VisionPortal


func set_portal_open(portal_id: StringName, is_open: bool) -> bool:
	var target := portal(portal_id)
	if target == null or target.permanent:
		return false
	target.is_open = is_open
	return true


func floor_owner_ids(cell: Vector3i) -> Array[int]:
	var result: Array[int] = []
	result.assign(_floor_owners.get(cell, []))
	return result


func has_floor_cells() -> bool:
	return not _floor_owners.is_empty()


func internal_owner_ids(cell: Vector3i) -> Array[int]:
	var result: Array[int] = []
	for placement_id: int in floor_owner_ids(cell):
		var candidate := snapshot(placement_id)
		if candidate != null and candidate.is_internal_cell(cell):
			result.append(placement_id)
	return result


## Retorna a primeira zona interna determinística que contém a célula.
func internal_context_at(cell: Vector3i) -> Dictionary:
	for placement_id: int in internal_owner_ids(cell):
		var candidate := snapshot(placement_id)
		return {
			"snapshot": candidate,
			"zone_id": candidate.zone_id_at(cell),
		}
	return {}


func can_zone_reach_exterior(
	placement_id: int,
	start_zone: int,
	profile: VisionProfile = null
) -> bool:
	var structure := snapshot(placement_id)
	if structure == null or start_zone == ZONE.EXTERIOR_ID:
		return true
	var start: VisionZone = structure.zone_by_id(start_zone) as VisionZone
	if start == null or start.is_exterior:
		return true

	var visited: Dictionary = {start_zone: true}
	var queue: Array[int] = [start_zone]
	var read_index := 0
	while read_index < queue.size():
		var zone_id := queue[read_index]
		read_index += 1
		for candidate: VisionPortal in structure.portals.values():
			if not candidate.transmits_sight(profile):
				continue
			var blocked_by_overlap := false
			for edge: VisionEdge in edges_between(candidate.cell_a, candidate.cell_b):
				if _edge_blocks_sight(edge, profile):
					blocked_by_overlap = true
					break
			if blocked_by_overlap:
				continue
			var next_zone := ZONE.EXTERIOR_ID
			if candidate.zone_a == zone_id:
				next_zone = candidate.zone_b
			elif candidate.zone_b == zone_id:
				next_zone = candidate.zone_a
			else:
				continue
			if next_zone == ZONE.EXTERIOR_ID:
				return true
			var next: VisionZone = structure.zone_by_id(next_zone) as VisionZone
			if next == null or next.is_exterior:
				return true
			if not visited.has(next_zone):
				visited[next_zone] = true
				queue.append(next_zone)
	return false


func _edge_blocks_sight(edge: VisionEdge, profile: VisionProfile) -> bool:
	if edge.opaque:
		return true
	if edge.portal_id == &"":
		return false
	var edge_portal := _portals.get(edge.portal_id) as VisionPortal
	return edge_portal == null or not edge_portal.transmits_sight(profile)


func _rebuild_indexes() -> void:
	_edges.clear()
	_edge_neighbors.clear()
	_edge_groups_by_bucket.clear()
	_portals.clear()
	_portal_aliases.clear()
	_floor_owners.clear()
	for structure: StructureVisionSnapshot in snapshots():
		for cell_variant: Variant in structure.floor_cells:
			var cell: Vector3i = cell_variant
			var owners := _floor_owners.get(cell, []) as Array
			owners.append(structure.placement_id)
			owners.sort()
			_floor_owners[cell] = owners
		for edge: VisionEdge in structure.edges.values():
			var key := edge.key()
			var contributions := _edges.get(key, []) as Array
			contributions.append(edge)
			contributions.sort_custom(_edge_less)
			_edges[key] = contributions
		for candidate: VisionPortal in structure.portals.values():
			_portals[candidate.id] = candidate
			_portal_aliases[_portal_stem(String(candidate.id))] = candidate.id
	for contributions_variant: Variant in _edges.values():
		var contributions := contributions_variant as Array
		if contributions.is_empty():
			continue
		var representative := contributions[0] as VisionEdge
		_index_neighbor(representative.cell_a, representative.cell_b, contributions)
		_index_neighbor(representative.cell_b, representative.cell_a, contributions)
		_index_edge_bucket(representative.cell_a, representative.key(), contributions)
		_index_edge_bucket(representative.cell_b, representative.key(), contributions)


func _index_neighbor(a: Vector3i, b: Vector3i, contributions: Array) -> void:
	var neighbors := _edge_neighbors.get(a, {}) as Dictionary
	neighbors[b] = contributions
	_edge_neighbors[a] = neighbors


func _index_edge_bucket(
	cell: Vector3i, edge_key: StringName, contributions: Array
) -> void:
	var bucket_key := Vector3i(
		floori(float(cell.x) / 16.0),
		floori(float(cell.y) / 16.0),
		cell.z
	)
	var bucket := _edge_groups_by_bucket.get(bucket_key, {}) as Dictionary
	bucket[edge_key] = contributions
	_edge_groups_by_bucket[bucket_key] = bucket


func _edge_less(a: VisionEdge, b: VisionEdge) -> bool:
	if a.opaque != b.opaque:
		return a.opaque
	if a.placement_id != b.placement_id:
		return a.placement_id < b.placement_id
	return String(a.portal_id) < String(b.portal_id)


func _portal_stem(id_text: String) -> String:
	var separator := id_text.rfind("|")
	return id_text.left(separator) if separator >= 0 else id_text

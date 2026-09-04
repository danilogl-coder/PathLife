## Contribuição lógica autocontida de uma instância de estrutura.
class_name StructureVisionSnapshot
extends RefCounted

const EDGE := preload("res://world_generation/visibility/vision_edge.gd")
const ZONE := preload("res://world_generation/visibility/vision_zone.gd")

var placement_id: int = 0
var structure_instance_id: int = 0
var origin: Vector3i = Vector3i.ZERO
var used_rect: Rect2i = Rect2i()
var tile_size: Vector2i = Vector2i(128, 64)

var local_floor_cells: Dictionary = {}
var floor_cells: Dictionary = {}
var floor_environments: Dictionary = {}
## StringName(edge key) -> VisionEdge.
var edges: Dictionary = {}
## StringName(stable id) -> VisionPortal.
var portals: Dictionary = {}
var zones: Array = []
## Vector3i(world cell) -> local zone id.
var cell_to_zone: Dictionary = {}
## Set quente do solver; evita procurar a VisionZone a cada candidato.
var internal_cells: Dictionary = {}
## Primeira faixa externa ao piso interno. O renderer usa FORCED_HIDDEN nela
## para que a suavização do fog não atravesse a parede de uma casa selada.
var exterior_guard_cells: Dictionary = {}
var warnings: PackedStringArray = PackedStringArray()


func local_to_world_cell(local_cell: Vector2i) -> Vector3i:
	return Vector3i(
		origin.x + local_cell.x,
		origin.y + local_cell.y,
		origin.z
	)


func world_to_local_cell(world_cell: Vector3i) -> Vector2i:
	return Vector2i(world_cell.x - origin.x, world_cell.y - origin.y)


func add_floor(local_cell: Vector2i, environment: StringName = &"") -> void:
	var world_cell := local_to_world_cell(local_cell)
	local_floor_cells[local_cell] = true
	floor_cells[world_cell] = true
	floor_environments[world_cell] = environment


func has_floor_cell(world_cell: Vector3i) -> bool:
	return floor_cells.has(world_cell)


func add_edge(edge: Variant) -> bool:
	if edge == null or not EDGE.are_adjacent(edge.cell_a, edge.cell_b):
		warnings.append("Borda inválida ignorada em placement %d." % placement_id)
		return false
	var edge_key: StringName = edge.key()
	if not edges.has(edge_key):
		edges[edge_key] = edge
		return true
	var current: Variant = edges[edge_key]
	if bool(current.opaque):
		if not bool(edge.opaque):
			warnings.append("Parede opaca prevaleceu sobre portal em %s." % edge_key)
		return false
	if bool(edge.opaque):
		warnings.append("Parede opaca prevaleceu sobre portal em %s." % edge_key)
		edges[edge_key] = edge
		if current.portal_id != &"":
			# Mantém o grafo de zonas coerente com a borda efetiva. Sem isto,
			# um portal substituído continuaria conectando cômodos no segundo
			# estágio do solver, embora o raycast já enxergasse uma parede.
			portals.erase(current.portal_id)
		return true
	# Dois portais na mesma borda: o primeiro, obtido em ordem determinística,
	# define a abertura.
	if current.portal_id != edge.portal_id:
		warnings.append("Portais duplicados na borda %s; o primeiro foi mantido." % edge_key)
	return false


func add_portal(portal: Variant, edge: Variant) -> bool:
	if portal == null or portal.id == &"":
		warnings.append("Portal sem ID ignorado em placement %d." % placement_id)
		return false
	if not add_edge(edge):
		return false
	portals[portal.id] = portal
	return true


func edge_between(a: Vector3i, b: Vector3i) -> Variant:
	return edges.get(EDGE.key_for(a, b))


func zone_id_at(world_cell: Vector3i) -> int:
	return int(cell_to_zone.get(world_cell, ZONE.EXTERIOR_ID))


func zone_at(world_cell: Vector3i) -> Variant:
	var zone_id := zone_id_at(world_cell)
	return zone_by_id(zone_id)


func zone_by_id(zone_id: int) -> Variant:
	for zone: Variant in zones:
		if int(zone.id) == zone_id:
			return zone
	return null


func is_internal_cell(world_cell: Vector3i) -> bool:
	if not internal_cells.is_empty():
		return internal_cells.has(world_cell)
	# Mantém snapshots sintéticos/testes e extensões antigas compatíveis.
	var zone: Variant = zone_at(world_cell)
	return zone != null and not bool(zone.is_exterior)


func opaque_edge_count() -> int:
	var count := 0
	for edge: Variant in edges.values():
		if bool(edge.opaque):
			count += 1
	return count


func portal_count(kind: StringName = &"") -> int:
	if kind == &"":
		return portals.size()
	var count := 0
	for portal: Variant in portals.values():
		if portal.kind == kind:
			count += 1
	return count


func internal_zones() -> Array:
	var result: Array = []
	for zone: Variant in zones:
		if not bool(zone.is_exterior):
			result.append(zone)
	return result

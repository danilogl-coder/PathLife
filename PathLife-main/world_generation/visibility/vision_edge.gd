## Uma borda da grade entre duas células adjacentes.
class_name VisionEdge
extends RefCounted

enum Kind {
	WALL,
	PORTAL,
}

var kind: Kind = Kind.WALL
var cell_a: Vector3i = Vector3i.ZERO
var cell_b: Vector3i = Vector3i.ZERO
var opaque: bool = true
var portal_id: StringName = &""
var direction: StringName = &""
var placement_id: int = 0
var authored_cell: Vector2i = Vector2i.ZERO


static func create_wall(
	a: Vector3i,
	b: Vector3i,
	p_placement_id: int = 0,
	p_direction: StringName = &"",
	p_authored_cell: Vector2i = Vector2i.ZERO
) -> VisionEdge:
	var edge := VisionEdge.new()
	edge.kind = Kind.WALL
	edge.cell_a = a
	edge.cell_b = b
	edge.opaque = true
	edge.placement_id = p_placement_id
	edge.direction = p_direction
	edge.authored_cell = p_authored_cell
	return edge


static func create_portal(
	a: Vector3i,
	b: Vector3i,
	p_portal_id: StringName,
	p_placement_id: int = 0,
	p_direction: StringName = &"",
	p_authored_cell: Vector2i = Vector2i.ZERO
) -> VisionEdge:
	var edge := VisionEdge.new()
	edge.kind = Kind.PORTAL
	edge.cell_a = a
	edge.cell_b = b
	edge.opaque = false
	edge.portal_id = p_portal_id
	edge.placement_id = p_placement_id
	edge.direction = p_direction
	edge.authored_cell = p_authored_cell
	return edge


func key() -> StringName:
	return key_for(cell_a, cell_b)


func other(cell: Vector3i) -> Vector3i:
	if cell == cell_a:
		return cell_b
	if cell == cell_b:
		return cell_a
	return cell


static func key_for(a: Vector3i, b: Vector3i) -> StringName:
	var first := a
	var second := b
	if _cell_less(second, first):
		first = b
		second = a
	return StringName(
		"%d,%d,%d>%d,%d,%d"
		% [first.x, first.y, first.z, second.x, second.y, second.z]
	)


static func are_adjacent(a: Vector3i, b: Vector3i) -> bool:
	return a.z == b.z and absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return a.z < b.z
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


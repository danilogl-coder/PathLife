## Componente conexo de piso delimitado por paredes e portais.
class_name VisionZone
extends RefCounted

const EXTERIOR_ID: int = -1

var id: int = EXTERIOR_ID
var placement_id: int = 0
var level: int = 0
var environment: StringName = &""
var is_exterior: bool = false
## Dictionary[Vector3i, bool].
var cells: Dictionary = {}


func add_cell(cell: Vector3i) -> void:
	cells[cell] = true


func has_cell(cell: Vector3i) -> bool:
	return cells.has(cell)


func size() -> int:
	return cells.size()


func sorted_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for value: Variant in cells:
		result.append(value as Vector3i)
	result.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return result


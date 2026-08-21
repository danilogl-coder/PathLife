## Dados de um chunk. NÃO é Node: pode ser criado em worker thread.
class_name ChunkData
extends RefCounted

var coord: Vector2i = Vector2i.ZERO
var size: int = 16
var cells: Array[WorldCell] = []
var structures: Array[StructurePlacement] = []
var decorations: Array[DecorationPlacement] = []
## Preenchido pelo gerador para o renderer não precisar varrer tudo de novo.
var min_height: int = 0
var max_height: int = 0


func _init(p_coord: Vector2i = Vector2i.ZERO, p_size: int = 16) -> void:
	coord = p_coord
	size = p_size
	cells.resize(size * size)


func index(local: Vector2i) -> int:
	return local.y * size + local.x


func contains_local(local: Vector2i) -> bool:
	return local.x >= 0 and local.y >= 0 and local.x < size and local.y < size


func set_cell(local: Vector2i, cell: WorldCell) -> void:
	cells[index(local)] = cell


func get_cell(local: Vector2i) -> WorldCell:
	return cells[index(local)]


func origin() -> Vector2i:
	return coord * size


## Acesso por coordenada mundial. Retorna null se estiver fora deste chunk.
func get_cell_world(world_xy: Vector2i) -> WorldCell:
	var local := world_xy - origin()
	if not contains_local(local):
		return null
	return cells[index(local)]


func refresh_height_bounds() -> void:
	var lo := 2147483647
	var hi := -2147483648
	for cell in cells:
		if cell == null:
			continue
		lo = mini(lo, cell.height)
		hi = maxi(hi, cell.height)
	if lo > hi:
		lo = 0
		hi = 0
	min_height = lo
	max_height = hi

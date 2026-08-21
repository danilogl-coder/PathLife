## Pathfinding sobre a grade lógica. Sempre consulta [MovementRules].
##
## Nenhum NPC implementa a própria subida de degrau.
class_name WorldNavigation
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var world: WorldData
var context: MovementContext
## Trava de segurança: não deixa o A* explorar o mundo inteiro.
var max_visited_cells: int = 4000


func _init(p_world: WorldData = null, p_context: MovementContext = null) -> void:
	world = p_world
	context = p_context


func can_enter(from_xy: Vector2i, to_xy: Vector2i) -> bool:
	return MovementRules.allows_movement(
		MovementRules.evaluate_world(world, from_xy, to_xy, context)
	)


func neighbors(world_xy: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		var candidate := world_xy + direction
		if can_enter(world_xy, candidate):
			result.append(candidate)
	return result


## A* sobre as células caminháveis. Retorna posições lógicas completas.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if world == null:
		return path
	if from == to:
		path.append(world.ground_position(from))
		return path

	var open: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	var visited := 0

	while not open.is_empty():
		visited += 1
		if visited > max_visited_cells:
			return path
		var best_index := 0
		for i in open.size():
			if float(f_score.get(open[i], INF)) < float(f_score.get(open[best_index], INF)):
				best_index = i
		var current: Vector2i = open[best_index]
		if current == to:
			return _rebuild(came_from, current)
		open.remove_at(best_index)

		for neighbor in neighbors(current):
			var tentative: int = int(g_score.get(current, 0)) + 1
			if tentative < int(g_score.get(neighbor, 2147483647)):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + _heuristic(neighbor, to)
				if not open.has(neighbor):
					open.append(neighbor)
	return path


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _rebuild(came_from: Dictionary, current: Vector2i) -> Array[Vector3i]:
	var cells: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	var result: Array[Vector3i] = []
	for cell in cells:
		result.append(world.ground_position(cell))
	return result

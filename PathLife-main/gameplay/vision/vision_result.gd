## Resultado imutável por convenção de uma atualização de visão.
##
## Todas as chaves espaciais usam coordenadas mundiais Vector3i. Os dicionários
## auxiliares funcionam como sets e tornam presenter/save independentes do solver.
class_name VisionResult
extends RefCounted

const STATE := preload("res://gameplay/vision/vision_state.gd")

var origin: Vector3i = Vector3i.ZERO
var facing: Vector2i = Vector2i(0, 1)
var revision: int = 0
## Contexto interno do observador nesta revisão. `observer_zone_cells` permite
## que presenters façam cutaway apenas no cômodo atual sem conhecer o registry.
var observer_placement_id: int = -1
var observer_zone_id: int = -1
var observer_zone_cells: Dictionary = {}

var states: Dictionary = {}
var visible_cells: Dictionary = {}
var remembered_cells: Dictionary = {}
var forced_hidden_cells: Dictionary = {}
## Conjunto histórico relevante para esta revisão (o coordenador mantém o
## histórico global compactado e fornece somente os chunks próximos ao solver).
var explored_cells: Dictionary = {}

## placement_id -> Dictionary[Vector3i, bool]. As células são mundiais.
var visible_interior_by_structure: Dictionary = {}
## StringName -> true para portais atravessados por ao menos um raio bem-sucedido.
var traversed_portal_ids: Dictionary = {}


func state_at(cell: Vector3i) -> int:
	return int(states.get(cell, STATE.UNKNOWN))


func is_visible(cell: Vector3i) -> bool:
	return visible_cells.has(cell)


func was_explored(cell: Vector3i) -> bool:
	return explored_cells.has(cell)


func set_state(cell: Vector3i, state: int) -> bool:
	if not STATE.is_valid(state):
		return false
	var current := state_at(cell)
	if STATE.priority(state) < STATE.priority(current):
		return false
	_set_state_unchecked(cell, state)
	return true


func replace_state(cell: Vector3i, state: int) -> bool:
	if not STATE.is_valid(state):
		return false
	_set_state_unchecked(cell, state)
	return true


func mark_visible(cell: Vector3i) -> void:
	# Caminho quente do solver: VISIBLE é a prioridade máxima, então não precisa
	# consultar/comparar o estado anterior antes de substituir seus índices.
	remembered_cells.erase(cell)
	forced_hidden_cells.erase(cell)
	states[cell] = STATE.VISIBLE
	visible_cells[cell] = true
	explored_cells[cell] = true


func mark_remembered(cell: Vector3i) -> void:
	if visible_cells.has(cell) or forced_hidden_cells.has(cell):
		return
	states[cell] = STATE.REMEMBERED
	remembered_cells[cell] = true
	explored_cells[cell] = true


func mark_forced_hidden(cell: Vector3i) -> void:
	if visible_cells.has(cell):
		return
	remembered_cells.erase(cell)
	states[cell] = STATE.FORCED_HIDDEN
	forced_hidden_cells[cell] = true


func mark_interior_visible(placement_id: int, cell: Vector3i) -> void:
	var cells := visible_interior_by_structure.get(placement_id, {}) as Dictionary
	cells[cell] = true
	visible_interior_by_structure[placement_id] = cells


func mark_portal_traversed(portal_id: StringName) -> void:
	if portal_id != &"":
		traversed_portal_ids[portal_id] = true


func memory_snapshot() -> Dictionary:
	return explored_cells.duplicate()


func rebuild_indexes() -> void:
	visible_cells.clear()
	remembered_cells.clear()
	forced_hidden_cells.clear()
	for cell_variant: Variant in states:
		var cell := cell_variant as Vector3i
		_index_cell(cell, int(states[cell]))


func _set_state_unchecked(cell: Vector3i, state: int) -> void:
	visible_cells.erase(cell)
	remembered_cells.erase(cell)
	forced_hidden_cells.erase(cell)
	if state == STATE.UNKNOWN:
		states.erase(cell)
		return
	states[cell] = state
	_index_cell(cell, state)


func _index_cell(cell: Vector3i, state: int) -> void:
	match state:
		STATE.VISIBLE:
			visible_cells[cell] = true
		STATE.REMEMBERED:
			remembered_cells[cell] = true
		STATE.FORCED_HIDDEN:
			forced_hidden_cells[cell] = true

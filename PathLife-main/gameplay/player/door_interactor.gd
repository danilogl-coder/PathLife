class_name DoorInteractor
extends Node

## Faz a ponte entre o comando de interação do Player e portas/janelas que vivem
## dentro de StructureRoot. A busca global permite que estruturas procedurais
## entrem e saiam da árvore sem precisar conectar sinais manualmente.

@export var interact_action: StringName = &"interact"
## O centro de uma célula isométrica adjacente fica a ~29 px da borda da
## parede. 40 px aceita somente as duas células que realmente tocam essa borda.
@export_range(1.0, 64.0, 0.5) var maximum_distance: float = 40.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(interact_action) or event.is_echo():
		return
	var actor := get_parent() as Node2D
	if actor == null:
		return
	var closest: Dictionary = {}
	var closest_distance_squared := maximum_distance * maximum_distance
	for node: Node in get_tree().get_nodes_in_group(StructureRoot.DOOR_STRUCTURE_GROUP):
		var structure := node as StructureRoot
		if structure == null:
			continue
		var candidates := [
			{
				"kind": &"door",
				"value": structure.get_nearest_interactive_door(
					actor.global_position, maximum_distance
				),
			},
			{
				"kind": &"window",
				"value": structure.get_nearest_interactive_window(
					actor.global_position, maximum_distance
				),
			},
		]
		for entry: Dictionary in candidates:
			var candidate: Dictionary = entry["value"]
			if candidate.is_empty():
				continue
			var candidate_distance := float(candidate.get("distance_squared", INF))
			if candidate_distance >= closest_distance_squared:
				continue
			closest = candidate
			closest["kind"] = entry["kind"]
			closest_distance_squared = candidate_distance
	if closest.is_empty():
		return
	var structure := closest["structure"] as StructureRoot
	if structure == null:
		return
	var interacted := false
	if closest["kind"] == &"window":
		interacted = structure.toggle_window(
			closest["layer"] as TileMapLayer, closest["cell"] as Vector2i
		)
	else:
		interacted = structure.toggle_door(
			closest["layer"] as TileMapLayer, closest["cell"] as Vector2i
		)
	if interacted:
		get_viewport().set_input_as_handled()

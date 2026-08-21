## Uma alteração do jogador sobre o mundo procedural.
##
## Salvar o mundo inteiro não escala. Salva-se a semente + as diferenças.
class_name CellPatch
extends RefCounted

var world_pos: Vector3i = Vector3i.ZERO
var height_override: int = 2147483647      ## sentinela = "sem override"
var ground_override: StringName = &""
var walkable_override: int = -1            ## -1 sem override, 0 falso, 1 verdadeiro


func has_height_override() -> bool:
	return height_override != 2147483647


func to_dictionary() -> Dictionary:
	return {
		"x": world_pos.x,
		"y": world_pos.y,
		"z": world_pos.z,
		"height": height_override,
		"ground": String(ground_override),
		"walkable": walkable_override,
	}


static func from_dictionary(data: Dictionary) -> CellPatch:
	var patch := CellPatch.new()
	patch.world_pos = Vector3i(int(data.get("x", 0)), int(data.get("y", 0)), int(data.get("z", 0)))
	patch.height_override = int(data.get("height", 2147483647))
	patch.ground_override = StringName(String(data.get("ground", "")))
	patch.walkable_override = int(data.get("walkable", -1))
	return patch

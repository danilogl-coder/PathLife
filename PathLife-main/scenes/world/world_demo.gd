## Cena-laboratório do mundo procedural (rode com F6).
##
## Também serve de exemplo mínimo de "como dirigir um [WorldGridAgent]":
## o controlador lê a entrada e pede um passo; quem decide se o passo é válido
## são as [MovementRules].
extends Node2D

@export var world: ProceduralWorld
@export var agent: WorldGridAgent
@export var info_label: Label

const DIRECTIONS := {
	"move_up": Vector2i(0, -1),
	"move_down": Vector2i(0, 1),
	"move_left": Vector2i(-1, 0),
	"move_right": Vector2i(1, 0),
}


func _process(_delta: float) -> void:
	_drive_agent()
	_update_info()


func _drive_agent() -> void:
	if agent == null or agent.is_moving() or not agent.is_active():
		return
	for action: String in DIRECTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			var scale := agent.run_multiplier if Input.is_action_pressed("move_run") else 1.0
			agent.request_step(DIRECTIONS[action], scale)
			return


func _update_info() -> void:
	if info_label == null or world == null or agent == null:
		return
	var data := world.world_data()
	if data == null:
		return
	var cell := data.get_cell(agent.cell())
	var biome := "?" if cell == null else String(cell.biome_id)
	var terrain := "?" if cell == null else String(cell.terrain_id)
	info_label.text = "célula %s   altura %d\nbioma %s   relevo %s\nchunks %d" % [
		agent.cell(), agent.height(), biome, terrain, data.loaded_chunk_coords().size()
	]

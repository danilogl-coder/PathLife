## Regra ÚNICA de movimento do jogo. Player, NPC e pathfinding chamam isto.
class_name MovementRules
extends RefCounted

enum MovementTransition {
	WALK,       ## mesma altura
	STEP_UP,    ## sobe automaticamente
	STEP_DOWN,  ## desce automaticamente
	FALL,       ## desnível grande para baixo
	SWIM,       ## entra na água
	BLOCKED,    ## proibido
}

const DEFAULT_CONTEXT_STEP_UP := 1
const DEFAULT_CONTEXT_STEP_DOWN := 1
const DEFAULT_MAX_SAFE_FALL := 4


static func evaluate(
	from_height: int,
	to_height: int,
	destination_walkable: bool,
	destination_liquid: bool = false,
	context: MovementContext = null
) -> MovementTransition:
	var max_up := DEFAULT_CONTEXT_STEP_UP
	var max_down := DEFAULT_CONTEXT_STEP_DOWN
	var max_fall := DEFAULT_MAX_SAFE_FALL
	var can_swim := false
	if context != null:
		max_up = context.max_step_up
		max_down = context.max_step_down
		max_fall = context.max_safe_fall
		can_swim = context.can_swim

	if destination_liquid:
		if not can_swim:
			return MovementTransition.BLOCKED
		return MovementTransition.SWIM

	if not destination_walkable:
		return MovementTransition.BLOCKED

	var delta := to_height - from_height
	if delta == 0:
		return MovementTransition.WALK
	if delta > 0:
		return MovementTransition.STEP_UP if delta <= max_up else MovementTransition.BLOCKED
	var drop := -delta
	if drop <= max_down:
		return MovementTransition.STEP_DOWN
	if drop <= max_fall:
		return MovementTransition.FALL
	return MovementTransition.BLOCKED


static func allows_movement(transition: MovementTransition) -> bool:
	return transition != MovementTransition.BLOCKED


## Avalia direto sobre o mundo — evita duplicar a leitura de células.
static func evaluate_world(
	world: WorldData, from_xy: Vector2i, to_xy: Vector2i, context: MovementContext = null
) -> MovementTransition:
	var to_cell := world.get_cell(to_xy)
	if to_cell == null:
		return MovementTransition.BLOCKED
	return evaluate(
		world.height_at(from_xy),
		to_cell.height,
		to_cell.walkable,
		to_cell.is_liquid(),
		context
	)

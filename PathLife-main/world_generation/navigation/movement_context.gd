## Capacidades de movimento de uma entidade.
##
## Player, NPC e pathfinding usam o MESMO contexto e as MESMAS regras. Se amanhã
## uma escada permitir subir 3 níveis, muda-se um valor aqui — não três scripts.
class_name MovementContext
extends Resource

@export_range(0, 16, 1) var max_step_up: int = 1
@export_range(0, 16, 1) var max_step_down: int = 1
## Queda maior que isto é considerada letal/proibida pelo pathfinding.
@export_range(0, 64, 1) var max_safe_fall: int = 4
@export var can_swim: bool = false
@export var can_climb: bool = false
@export var ignores_obstacles: bool = false

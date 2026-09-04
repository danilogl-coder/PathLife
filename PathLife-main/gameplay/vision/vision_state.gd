## Estados lógicos de uma célula no sistema de visão.
##
## A ordem numérica também é a prioridade de composição. Uma célula
## visível sempre vence; ocultação estrutural vence a memória.
class_name VisionState
extends RefCounted

enum {
	UNKNOWN = 0,
	REMEMBERED = 1,
	FORCED_HIDDEN = 2,
	VISIBLE = 3,
}


static func priority(state: int) -> int:
	match state:
		VISIBLE:
			return 3
		FORCED_HIDDEN:
			return 2
		REMEMBERED:
			return 1
		_:
			return 0


static func is_valid(state: int) -> bool:
	return state >= UNKNOWN and state <= VISIBLE


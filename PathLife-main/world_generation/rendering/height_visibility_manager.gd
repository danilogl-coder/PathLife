## Esconde/esmaece níveis acima do jogador. NÃO altera [WorldData].
##
## Ocultar é responsabilidade do renderer, nunca do dado.
class_name HeightVisibilityManager
extends Node

enum HeightVisibility { VISIBLE, FADED, HIDDEN }

## Liga o corte/esmaecimento dos níveis acima do jogador (interiores, subsolo).
@export var enabled: bool = false
## Liga o sombreamento por altura relativo ao nível do jogador. É o indicativo
## visual de "este patamar está acima/abaixo de mim".
@export var relative_height_shading: bool = true
## Quantos níveis acima do jogador ficam translúcidos antes de sumir.
@export_range(0, 8, 1) var fade_above_levels: int = 1
@export_range(0.0, 1.0, 0.01) var faded_alpha: float = 0.35
## Em ambiente subterrâneo tudo acima do jogador some.
@export var underground: bool = false

var _player_level: int = 0


func set_player_level(level: int) -> void:
	_player_level = level


func player_level() -> int:
	return _player_level


func get_height_visibility(object_height: int) -> HeightVisibility:
	if not enabled:
		return HeightVisibility.VISIBLE
	if underground:
		return HeightVisibility.HIDDEN if object_height > _player_level else HeightVisibility.VISIBLE
	if object_height <= _player_level:
		return HeightVisibility.VISIBLE
	if object_height <= _player_level + fade_above_levels:
		return HeightVisibility.FADED
	return HeightVisibility.HIDDEN


func apply_to(views: Array) -> void:
	for view: ChunkView in views:
		if relative_height_shading:
			view.set_reference_level(_player_level)
		for level: int in view.layer_levels():
			match get_height_visibility(level):
				HeightVisibility.VISIBLE:
					view.apply_level_modulation(level, Color.WHITE, true)
				HeightVisibility.FADED:
					view.apply_level_modulation(level, Color(1, 1, 1, faded_alpha), true)
				HeightVisibility.HIDDEN:
					view.apply_level_modulation(level, Color.WHITE, false)

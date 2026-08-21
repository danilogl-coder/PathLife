## Dessincroniza a animação de uma decoração animada (árvore, arbusto...).
##
## [b]Por que existe[/b]: todas as instâncias de uma cena começam no quadro 0.
## Sem isto o mundo inteiro solta folha no mesmo instante e a floresta lê como
## um objeto repetido em vez de várias árvores.
##
## O quadro inicial vem da POSIÇÃO da decoração, nunca do relógio nem de
## `randi()`: assim, quando o chunk é descarregado e volta, a árvore reaparece
## no mesmo ponto da animação em vez de dar um salto. O `ChunkView` grava a
## posição do mundo como metadado ao instanciar; objetos colocados à mão na cena
## caem no `global_position`.
class_name VegetationAnimation
extends Node2D

## Nome da animação dentro do [SpriteFrames].
@export var animation: StringName = &"queda"
## Quem toca a animação. Fica exposto para a cena decidir, sem caminho frágil.
@export var sprite: AnimatedSprite2D
## Variação de velocidade entre indivíduos, em fração. 0 = todas iguais.
@export_range(0.0, 0.5, 0.01) var speed_jitter: float = 0.12


func _ready() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(animation):
		push_warning("Animacao %s nao existe no SpriteFrames." % animation)
		return
	var cell := _identity_cell()
	var total := sprite.sprite_frames.get_frame_count(animation)
	var start := WorldRandom.value_01(0, cell, 11)
	var jitter := WorldRandom.value_01(0, cell, 29) * 2.0 - 1.0
	sprite.speed_scale = 1.0 + jitter * speed_jitter
	sprite.play(animation)
	# `set_frame_and_progress` entra no MEIO do quadro, então duas árvores no
	# mesmo quadro ainda ficam defasadas.
	sprite.set_frame_and_progress(
		mini(total - 1, int(start * float(total))),
		WorldRandom.value_01(0, cell, 47)
	)


## Coordenada estável que identifica esta decoração.
func _identity_cell() -> Vector2i:
	var meta: Variant = get_meta(&"world_position", null)
	if meta is Vector3i:
		return Vector2i(meta.x, meta.y)
	return Vector2i(roundi(global_position.x), roundi(global_position.y))

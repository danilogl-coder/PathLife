class_name CharacterViewportComposite
extends Node2D

## Mantém o rig recortado (que usa vários Z internos) fora do canvas do mundo.
## Para Ground/Depth existe apenas o Sprite2D composto, em z_index 0.

@export var character_viewport: SubViewport
@export var character_stage: Node2D
@export var composite_sprite: Sprite2D
@export var texture_foot := Vector2(96.0, 144.0)

var _motion_source: Node2D
var _motion_origin := Vector2.ZERO
var _motion_origin_ready := false


func _ready() -> void:
	_motion_source = get_parent() as Node2D
	if (
		character_viewport == null
		or character_stage == null
		or composite_sprite == null
		or _motion_source == null
	):
		push_error("CharacterViewportComposite precisa do viewport, stage, sprite e fonte de movimento.")
		return
	composite_sprite.texture = character_viewport.get_texture()
	_sync_internal_motion()


func _process(_delta: float) -> void:
	_sync_internal_motion()


func _physics_process(_delta: float) -> void:
	_sync_internal_motion()


## O rig permanece visualmente parado dentro da textura, mas o Stage percorre
## a mesma distância que o Player no mundo. Assim cabelo e saia continuam
## recebendo a translação real pelas suas `global_position`, mesmo dentro do
## canvas isolado do SubViewport.
func _sync_internal_motion() -> void:
	if character_viewport == null or character_stage == null or _motion_source == null:
		return
	if not _motion_origin_ready:
		_motion_origin = _motion_source.global_position
		_motion_origin_ready = true
	var stage_motion := _motion_source.global_position - _motion_origin
	character_stage.position = stage_motion
	character_viewport.canvas_transform = Transform2D(
		0.0,
		texture_foot - stage_motion
	)

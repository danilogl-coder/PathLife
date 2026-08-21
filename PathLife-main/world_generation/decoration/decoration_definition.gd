## Um objeto de decoração espalhado proceduralmente (árvore, pedra, arbusto...).
##
## Adicionar vegetação nova = criar a cena + um `.tres` deste tipo e arrastar
## para o array `decorations` do bioma.
class_name DecorationDefinition
extends Resource

@export var id: StringName = &"nova_decoracao"
@export var scene: PackedScene

@export_group("Densidade")
## Chance por célula (0..1). Valores pequenos: 0.02 já é bastante coisa.
@export_range(0.0, 1.0, 0.001) var density: float = 0.02
@export_range(0.0, 16.0, 0.05) var weight: float = 1.0
## Distância mínima entre duas decorações deste tipo, em células.
@export_range(1, 32, 1) var minimum_spacing: int = 2

@export_group("Condições")
@export var min_world_height: int = -999
@export var max_world_height: int = 999
@export_range(0.0, 32.0, 0.5) var max_slope: float = 2.0
@export var allowed_terrains: Array[StringName] = []
@export var allow_on_water: bool = false
## Só nasce onde o bioma é dominante (blend do secundário abaixo deste valor).
@export_range(0.0, 1.0, 0.01) var max_biome_blend: float = 1.0

@export_group("Visual")
@export var random_flip_h: bool = true
@export_range(0.5, 2.0, 0.01) var min_scale: float = 1.0
@export_range(0.5, 2.0, 0.01) var max_scale: float = 1.0
## A decoração bloqueia passagem?
@export var blocks_movement: bool = false

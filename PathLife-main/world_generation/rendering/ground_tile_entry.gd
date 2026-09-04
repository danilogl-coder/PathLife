## Liga um id lógico de chão (ex.: &"campo") a um tile concreto do TileSet.
class_name GroundTileEntry
extends Resource

@export var ground_id: StringName = &"campo"
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0
## Tile cuja arte aponta para um lado — as peças de transição de bioma.
##
## Estes NUNCA podem ser espelhados: o espelhamento troca a esquerda pela
## direita e um `aresta_frente_dir` viraria um `aresta_frente_esq`, com a borda
## do bioma caindo no lado errado da célula.
@export var directional: bool = false

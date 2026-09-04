## UMA fronteira com arte desenhada.
##
## Uma fronteira nova é um `.tres` deste tipo na lista do
## [BiomeTransitionCatalog] — nenhuma linha de código muda.
class_name BiomeTransitionRule
extends Resource

## Grupo da célula que RECEBE o tile misto.
@export var de_grupo: StringName = &"campo"
## Grupo do vizinho que invade a célula.
@export var para_grupo: StringName = &"floresta"
## Prefixo das 12 peças no atlas. O id de cada peça é
## `<prefixo>_<forma>`, ex.: `campo_para_musgo_aresta_tras_esq`.
@export var prefixo: StringName = &"campo_para_musgo"

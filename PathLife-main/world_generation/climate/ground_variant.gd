## Uma variante de chão de um bioma.
##
## Cada bioma da pasta original tem várias artes de grama (alta, densa, rala,
## rasteira...). Registrar todas aqui é o que tira o terreno da monotonia: o
## mundo alterna entre elas em manchas, em vez de repetir um tile só.
class_name GroundVariant
extends Resource

## Precisa existir no [TileCatalog].
@export var ground_id: StringName = &"campo_baixo"
## Peso relativo. Quanto maior, mais área o bioma dá para esta variante.
@export_range(0.0, 8.0, 0.05) var weight: float = 1.0

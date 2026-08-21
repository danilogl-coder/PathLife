## Tipo de relevo (plano, colina, montanha, penhasco...).
##
## É independente do bioma: uma célula pode ser `Floresta + Montanha`.
class_name TerrainDefinition
extends Resource

@export var id: StringName = &"plano"
@export var display_name: String = "Plano"

@export_group("Faixas")
@export_range(0.0, 1.0) var min_roughness: float = 0.0
@export_range(0.0, 1.0) var max_roughness: float = 1.0
## Declividade medida em níveis de diferença para os vizinhos.
@export_range(0.0, 16.0, 0.1) var min_slope: float = 0.0
@export_range(0.0, 16.0, 0.1) var max_slope: float = 16.0
@export_range(0.0, 4.0) var weight: float = 1.0

@export_group("Regras")
## Se preenchido, sobrescreve o chão do bioma por um id fixo.
@export var ground_override_id: StringName = &""
## Usa o bloco de TERRA do próprio bioma como chão (encosta com solo exposto).
##
## Melhor que [member ground_override_id] para relevo íngreme: cada bioma
## mostra a terra da sua própria arte, em vez de um tile genérico.
@export var expose_biome_wall: bool = false
@export var walkable: bool = true
## Estruturas só podem nascer aqui se este tipo estiver liberado.
@export var allows_structures: bool = true

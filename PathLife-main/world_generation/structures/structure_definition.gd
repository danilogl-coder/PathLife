## Regras procedurais de uma estrutura. O VISUAL fica no `.tscn`.
##
## Adicionar uma construção nova = criar `minha_casa.tscn` (com um
## [StructureRoot] na raiz) + `minha_casa.tres` deste tipo, e arrastar o `.tres`
## para a pool de um bioma. Nenhum script do núcleo muda.
class_name StructureDefinition
extends Resource

enum TerrainAdaptationMode {
	NONE,        ## o terreno não muda
	FLATTEN,     ## achata o footprint e mistura a borda
	PLATEAU,     ## platô com borda mais marcada
	EMBED,       ## encaixa na encosta (usa a altura mais alta)
	CARVE,       ## escava (usa a altura mais baixa) — minas, cavernas
	WATER_EDGE,  ## procura a margem: fundação no nível do mar
}

@export var id: StringName = &"nova_estrutura"
@export var display_name: String = "Nova estrutura"
@export var scene: PackedScene

@export_group("Footprint")
## Área ocupada em células.
@export var footprint: Vector2i = Vector2i(4, 4)
## Margem ao redor onde o terreno é misturado gradualmente.
@export_range(0, 32, 1) var adaptation_margin: int = 4

@export_group("Spawn")
@export_range(0.0, 16.0, 0.05) var spawn_weight: float = 1.0
## Chance de a região sortear esta estrutura em cada tentativa.
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.35
@export var min_world_height: int = -999
@export var max_world_height: int = 999
## Vazio = qualquer bioma.
@export var allowed_biomes: Array[StringName] = []
## Vazio = qualquer relevo.
@export var allowed_terrains: Array[StringName] = []
## Distância mínima (em células) para outra estrutura.
@export_range(1, 512, 1) var minimum_spacing: int = 24
## Declive máximo tolerado no footprint antes de descartar o local.
@export_range(0.0, 32.0, 0.5) var max_slope: float = 6.0
@export var allow_on_water: bool = false

@export_group("Terreno")
@export var adaptation_mode: TerrainAdaptationMode = TerrainAdaptationMode.FLATTEN
@export_range(-16, 16, 1) var preferred_foundation_offset: int = 0
## Marca as células do footprint como não-caminháveis (a cena cuida do chão).
@export var footprint_blocks_movement: bool = false


func allows_biome(biome_id: StringName) -> bool:
	return allowed_biomes.is_empty() or allowed_biomes.has(biome_id)


func allows_terrain(terrain_id: StringName) -> bool:
	return allowed_terrains.is_empty() or allowed_terrains.has(terrain_id)

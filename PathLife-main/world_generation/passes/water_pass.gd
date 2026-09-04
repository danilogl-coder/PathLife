## Passe 7 — lâmina d'água. Não altera o relevo: só marca líquido.
class_name WaterPass
extends WorldGenerationPass

@export var sampler: WorldSampler
## Chão usado no fundo quando o bioma não define um específico.
@export var water_ground_id: StringName = &"campo_terra"
@export var water_is_walkable: bool = false



func rebind_shared(shared: Dictionary) -> void:
	sampler = WorldGenerationPass.shared_clone(shared, sampler)


## Garante que o amostrador esteja semeado antes de qualquer geração.
func prepare(settings: WorldSettings, world_seed: int) -> void:
	if sampler != null:
		sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
	var settings := context.settings
	var size := settings.chunk_size
	for y in size:
		for x in size:
			var cell := context.cell(Vector2i(x, y))
			if cell.terrain_locked or cell.ground_locked or cell.height >= settings.sea_level:
				cell.liquid_depth = 0
				continue
			cell.liquid_depth = settings.sea_level - cell.height
			cell.walkable = water_is_walkable
			cell.ground_id = water_ground_id
			if sampler != null and sampler.biome_resolver != null:
				var biome := sampler.biome_resolver.find_by_id(cell.biome_id)
				if biome != null and biome.underwater_ground_id != &"":
					cell.ground_id = biome.underwater_ground_id

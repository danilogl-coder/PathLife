## Passe 2 — resolve bioma principal + secundário (transição gradual).
class_name BiomePass
extends WorldGenerationPass

@export var sampler: WorldSampler



func rebind_shared(shared: Dictionary) -> void:
	sampler = WorldGenerationPass.shared_clone(shared, sampler)


## Garante que o amostrador esteja semeado antes de qualquer geração.
func prepare(settings: WorldSettings, world_seed: int) -> void:
	if sampler != null:
		sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
	if sampler == null or sampler.biome_resolver == null:
		return
	var size := context.settings.chunk_size
	var origin := context.origin()
	for y in size:
		for x in size:
			var local := Vector2i(x, y)
			var cell := context.cell(local)
			var sample := sampler.sample_climate(origin + local)
			var resolution := sampler.biome_resolver.resolve(sample)
			if resolution.primary == null:
				continue
			cell.biome_id = resolution.primary.id
			cell.biome_blend = resolution.blend
			cell.secondary_biome_id = resolution.primary.id
			if resolution.secondary != null:
				cell.secondary_biome_id = resolution.secondary.id
			# A variante de grama vem de um ruído próprio: manchas de mato
			# fechado, grama rala e rasteira dentro do mesmo bioma.
			cell.ground_id = resolution.primary.pick_ground(
				sampler.ground_variation(origin + local)
			)
			cell.wall_id = resolution.primary.wall_id

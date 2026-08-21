## Passe 1 — grava o clima macro em cada célula.
class_name ClimatePass
extends WorldGenerationPass

@export var sampler: WorldSampler



func rebind_shared(shared: Dictionary) -> void:
	sampler = WorldGenerationPass.shared_clone(shared, sampler)


## Garante que o amostrador esteja semeado antes de qualquer geração.
func prepare(settings: WorldSettings, world_seed: int) -> void:
	if sampler != null:
		sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
	if sampler == null:
		return
	var size := context.settings.chunk_size
	var origin := context.origin()
	for y in size:
		for x in size:
			var local := Vector2i(x, y)
			var sample := sampler.sample_climate(origin + local)
			var cell := context.cell(local)
			cell.temperature = sample.temperature
			cell.humidity = sample.humidity
			cell.continentalness = sample.continentalness

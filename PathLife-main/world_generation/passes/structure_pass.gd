## Passe 6 — insere as estruturas planejadas e adapta o terreno a elas.
##
## Roda ANTES do terreno final: o mundo nasce já adaptado às construções.
class_name StructurePass
extends WorldGenerationPass

@export var planner: StructurePlanner


func rebind_shared(shared: Dictionary) -> void:
	if planner == null:
		return
	var original_sampler := planner.sampler
	planner = planner.duplicate(false)
	planner.clear_cache()
	planner.sampler = WorldGenerationPass.shared_clone(shared, original_sampler)


func prepare(settings: WorldSettings, world_seed: int) -> void:
	if planner == null:
		return
	if planner.sampler != null:
		planner.sampler.prepare(settings, world_seed)
	planner.clear_cache()


func run(context: GenerationContext) -> void:
	if planner == null:
		return
	var placements := planner.placements_for_chunk(
		context.chunk_coord, context.settings, context.world_seed
	)
	context.planned_structures = placements
	TerrainAdapter.apply(context, placements)

	# Só o chunk que contém a origem do footprint instancia a cena — assim uma
	# estrutura que atravessa vários chunks nunca é duplicada.
	var chunk_size := context.settings.chunk_size
	for placement in placements:
		if ChunkMath.world_to_chunk(placement.origin_xy, chunk_size) == context.chunk_coord:
			context.chunk_data.structures.append(placement)

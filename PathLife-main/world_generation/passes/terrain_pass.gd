## Passe 4 — classifica o relevo (plano/colina/montanha) e aplica overrides.
##
## Bioma e relevo são independentes: "Floresta + Montanha" é um estado válido.
class_name TerrainPass
extends WorldGenerationPass

@export var sampler: WorldSampler



func rebind_shared(shared: Dictionary) -> void:
	sampler = WorldGenerationPass.shared_clone(shared, sampler)


## Garante que o amostrador esteja semeado antes de qualquer geração.
func prepare(settings: WorldSettings, world_seed: int) -> void:
	if sampler != null:
		sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
	if sampler == null or sampler.terrain_resolver == null:
		return
	var size := context.settings.chunk_size
	var origin := context.origin()
	for y in size:
		for x in size:
			var local := Vector2i(x, y)
			var cell := context.cell(local)
			var world_xy := origin + local
			var slope := _slope(context, local)
			var terrain := sampler.terrain_resolver.resolve(sampler.roughness(world_xy), slope)
			if terrain == null:
				continue
			cell.terrain_id = terrain.id
			# Célula trancada por uma construção mantém o chão que ela assentou:
			# devolver a arte do relevo aqui traria a grama de volta para debaixo
			# do piso.
			if not cell.ground_locked:
				if terrain.ground_override_id != &"":
					cell.ground_id = terrain.ground_override_id
				elif terrain.expose_biome_wall and cell.wall_id != &"":
					cell.ground_id = cell.wall_id
			if not terrain.walkable:
				cell.walkable = false


## Declive usando as células já geradas; nas bordas cai para o amostrador
## global, para que o resultado não dependa do recorte do chunk.
func _slope(context: GenerationContext, local: Vector2i) -> float:
	var height := context.cell(local).height
	var worst := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor := local + offset
		var neighbor_height := 0
		if context.chunk_data.contains_local(neighbor):
			neighbor_height = context.cell(neighbor).height
		else:
			neighbor_height = sampler.base_height(context.origin() + neighbor)
		worst = maxi(worst, absi(neighbor_height - height))
	return float(worst)

## Planeja estruturas por REGIÃO (várias chunks), nunca por chunk.
##
## Isso resolve o problema clássico de dois chunks vizinhos decidirem estruturas
## diferentes no mesmo lugar, e permite que uma estrutura atravesse chunks.
class_name StructurePlanner
extends Resource

@export var sampler: WorldSampler
## Tentativas de posicionamento por região.
@export_range(0, 64, 1) var attempts_per_region: int = 10
## Pool global (além das pools por bioma).
@export var global_pool: Array[StructureDefinition] = []
## Quantas regiões ficam em cache antes de a memória ser reciclada.
@export_range(4, 512, 1) var cache_capacity: int = 64

var _cache: Dictionary = {}


## Estruturas planejadas de uma região. Determinístico: mesma semente e mesma
## região sempre produzem exatamente a mesma lista.
func plan_region(region_coord: Vector2i, settings: WorldSettings, world_seed: int) -> Array[StructurePlacement]:
	if _cache.has(region_coord):
		return _cache[region_coord]

	var result: Array[StructurePlacement] = []
	if sampler == null:
		_store_in_cache(region_coord, result)
		return result

	var region_cells := settings.generation_region_size_chunks * settings.chunk_size
	var region_origin := region_coord * region_cells
	var region_seed := WorldRandom.sub_seed(world_seed, &"structures")
	var rng := WorldRandom.rng_for(region_seed, region_coord)

	for attempt in attempts_per_region:
		var local := Vector2i(rng.randi_range(0, region_cells - 1), rng.randi_range(0, region_cells - 1))
		var world_xy := region_origin + local
		var biome := sampler.resolve_biome(world_xy)
		if biome == null:
			continue

		var candidates := _candidates_for(biome)
		if candidates.is_empty():
			continue

		var definition := _pick_weighted(candidates, rng)
		if definition == null:
			continue
		if rng.randf() > definition.spawn_chance:
			continue
		if not _fits(definition, world_xy, settings):
			continue
		if _too_close(result, definition, world_xy):
			continue

		var placement := StructurePlacement.new(definition, world_xy)
		placement.foundation_height = _foundation_height(definition, world_xy)
		placement.placement_id = WorldRandom.coordinate_seed(region_seed, world_xy)
		result.append(placement)

	_store_in_cache(region_coord, result)
	return result


func _store_in_cache(region_coord: Vector2i, value: Array[StructurePlacement]) -> void:
	if _cache.size() >= cache_capacity:
		_cache.erase(_cache.keys()[0])
	_cache[region_coord] = value


## Todas as estruturas que influenciam um chunk (varre as regiões vizinhas).
func placements_for_chunk(
	chunk_coord: Vector2i, settings: WorldSettings, world_seed: int
) -> Array[StructurePlacement]:
	var result: Array[StructurePlacement] = []
	var region := ChunkMath.chunk_to_region(chunk_coord, settings.generation_region_size_chunks)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for placement in plan_region(region + Vector2i(dx, dy), settings, world_seed):
				if placement.overlaps_chunk(chunk_coord, settings.chunk_size):
					result.append(placement)
	return result


func clear_cache() -> void:
	_cache.clear()


func _candidates_for(biome: BiomeDefinition) -> Array[StructureDefinition]:
	var candidates: Array[StructureDefinition] = []
	for definition in biome.structure_pool:
		if definition != null:
			candidates.append(definition)
	for definition in global_pool:
		if definition != null and definition.allows_biome(biome.id):
			candidates.append(definition)
	return candidates


func _pick_weighted(
	candidates: Array[StructureDefinition], rng: RandomNumberGenerator
) -> StructureDefinition:
	var total := 0.0
	for definition in candidates:
		total += maxf(definition.spawn_weight, 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for definition in candidates:
		roll -= maxf(definition.spawn_weight, 0.0)
		if roll <= 0.0:
			return definition
	return candidates[candidates.size() - 1]


func _fits(definition: StructureDefinition, origin_xy: Vector2i, settings: WorldSettings) -> bool:
	var heights := _footprint_heights(definition, origin_xy)
	if heights.is_empty():
		return false
	var lo := heights[0]
	var hi := heights[0]
	for h in heights:
		lo = mini(lo, h)
		hi = maxi(hi, h)
	if float(hi - lo) > definition.max_slope:
		return false
	if lo < definition.min_world_height or hi > definition.max_world_height:
		return false
	if not definition.allow_on_water and lo < settings.sea_level:
		return false

	var biome := sampler.resolve_biome(origin_xy)
	if biome != null and not definition.allows_biome(biome.id):
		return false
	if sampler.terrain_resolver != null and not definition.allowed_terrains.is_empty():
		var terrain := sampler.terrain_resolver.resolve(
			sampler.roughness(origin_xy), sampler.base_slope(origin_xy)
		)
		if terrain != null and not definition.allows_terrain(terrain.id):
			return false
	return true


func _too_close(
	existing: Array[StructurePlacement], definition: StructureDefinition, origin_xy: Vector2i
) -> bool:
	for placement in existing:
		var spacing := maxi(definition.minimum_spacing, placement.definition.minimum_spacing)
		var delta := placement.origin_xy - origin_xy
		if maxi(absi(delta.x), absi(delta.y)) < spacing:
			return true
	return false


func _footprint_heights(definition: StructureDefinition, origin_xy: Vector2i) -> Array[int]:
	var heights: Array[int] = []
	for y in definition.footprint.y:
		for x in definition.footprint.x:
			heights.append(sampler.base_height(origin_xy + Vector2i(x, y)))
	return heights


## Mediana das alturas do footprint: um pico isolado não distorce a fundação.
func _foundation_height(definition: StructureDefinition, origin_xy: Vector2i) -> int:
	var heights := _footprint_heights(definition, origin_xy)
	if heights.is_empty():
		return 0
	heights.sort()
	var median := heights[floori(float(heights.size()) / 2.0)]
	match definition.adaptation_mode:
		StructureDefinition.TerrainAdaptationMode.EMBED:
			median = heights[heights.size() - 1]
		StructureDefinition.TerrainAdaptationMode.CARVE:
			median = heights[0]
		StructureDefinition.TerrainAdaptationMode.WATER_EDGE:
			median = sampler.settings().sea_level if sampler.settings() != null else median
		_:
			pass
	return median + definition.preferred_foundation_offset

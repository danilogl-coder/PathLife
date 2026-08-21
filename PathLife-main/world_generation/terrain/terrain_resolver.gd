## Escolhe o [TerrainDefinition] de cada célula a partir de rugosidade+declive.
class_name TerrainResolver
extends Resource

@export var terrains: Array[TerrainDefinition] = []
@export var fallback_terrain: TerrainDefinition


func resolve(roughness: float, slope: float) -> TerrainDefinition:
	var best: TerrainDefinition = null
	var best_score := -1.0
	for terrain in terrains:
		if terrain == null:
			continue
		var r := BiomeResolver.range_score(roughness, terrain.min_roughness, terrain.max_roughness, 0.08)
		var s := BiomeResolver.range_score(slope, terrain.min_slope, terrain.max_slope, 0.5)
		var score := r * s * terrain.weight
		if score > best_score:
			best_score = score
			best = terrain
	if best == null or best_score <= 0.0:
		return fallback_terrain if fallback_terrain != null else best
	return best


func find_by_id(terrain_id: StringName) -> TerrainDefinition:
	for terrain in terrains:
		if terrain != null and terrain.id == terrain_id:
			return terrain
	return fallback_terrain

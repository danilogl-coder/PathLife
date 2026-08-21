## Escolhe o bioma de uma célula pontuando todos os biomas registrados.
##
## Adicionar bioma = adicionar um `.tres` na lista. Não existe cadeia de `if`.
class_name BiomeResolver
extends Resource

@export var biomes: Array[BiomeDefinition] = []
## Bioma usado quando nenhum pontua (rede de segurança).
@export var fallback_biome: BiomeDefinition

## Resultado da resolução (bioma principal + segundo colocado para transições).
class Resolution extends RefCounted:
	var primary: BiomeDefinition
	var secondary: BiomeDefinition
	var blend: float = 0.0


static func range_score(value: float, min_value: float, max_value: float, fade: float) -> float:
	if value >= min_value and value <= max_value:
		return 1.0
	if fade <= 0.0:
		return 0.0
	if value < min_value:
		return clampf(1.0 - (min_value - value) / fade, 0.0, 1.0)
	return clampf(1.0 - (value - max_value) / fade, 0.0, 1.0)


func score_biome(biome: BiomeDefinition, climate: ClimateSample) -> float:
	var temperature_score := range_score(
		climate.temperature, biome.temperature_min, biome.temperature_max, biome.transition_width
	)
	var humidity_score := range_score(
		climate.humidity, biome.humidity_min, biome.humidity_max, biome.transition_width
	)
	var continent_score := range_score(
		climate.continentalness,
		biome.continentalness_min,
		biome.continentalness_max,
		biome.transition_width
	)
	return temperature_score * humidity_score * continent_score * biome.weight


func resolve(climate: ClimateSample) -> Resolution:
	var result := Resolution.new()
	var best := -1.0
	var second := -1.0
	for biome in biomes:
		if biome == null:
			continue
		var score := score_biome(biome, climate)
		if score > best:
			second = best
			result.secondary = result.primary
			best = score
			result.primary = biome
		elif score > second:
			second = score
			result.secondary = biome
	if result.primary == null:
		result.primary = fallback_biome
	if result.secondary == null:
		result.secondary = result.primary
	var total := best + maxf(second, 0.0)
	result.blend = 0.0 if total <= 0.0 else clampf(maxf(second, 0.0) / total, 0.0, 1.0)
	return result


func find_by_id(biome_id: StringName) -> BiomeDefinition:
	for biome in biomes:
		if biome != null and biome.id == biome_id:
			return biome
	return fallback_biome

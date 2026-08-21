## Gera os mapas macro de clima. Biomas grandes = ruídos de baixa frequência.
class_name ClimateGenerator
extends Resource

@export_group("Ruídos")
@export var temperature_noise: FastNoiseLite
@export var humidity_noise: FastNoiseLite
@export var continentalness_noise: FastNoiseLite
@export var weirdness_noise: FastNoiseLite

@export_group("Escala")
## Quanto maior, maiores os biomas. É um divisor aplicado à coordenada mundial.
@export_range(1.0, 4096.0, 1.0) var biome_scale: float = 420.0
## Escala independente para o mapa de continentalidade (oceanos/continentes).
@export_range(1.0, 8192.0, 1.0) var continent_scale: float = 1400.0
## Ganho aplicado antes de normalizar para 0..1.
##
## O FastNoiseLite fractal raramente passa de ±0.35, então sem ganho os valores
## ficam presos perto de 0.5 e biomas extremos (deserto, neve, montanha) nunca
## aparecem. Suba para climas mais extremos, baixe para um mundo mais ameno.
@export_range(0.5, 6.0, 0.05) var contrast: float = 2.3


func prepare(world_seed: int) -> void:
	_seed_noise(temperature_noise, WorldRandom.sub_seed(world_seed, &"climate/temperature"))
	_seed_noise(humidity_noise, WorldRandom.sub_seed(world_seed, &"climate/humidity"))
	_seed_noise(continentalness_noise, WorldRandom.sub_seed(world_seed, &"climate/continentalness"))
	_seed_noise(weirdness_noise, WorldRandom.sub_seed(world_seed, &"climate/weirdness"))


func _seed_noise(noise: FastNoiseLite, value: int) -> void:
	if noise != null:
		noise.seed = value


func sample(world_xy: Vector2i) -> ClimateSample:
	var result := ClimateSample.new()
	var bx := float(world_xy.x) / biome_scale
	var by := float(world_xy.y) / biome_scale
	var cx := float(world_xy.x) / continent_scale
	var cy := float(world_xy.y) / continent_scale
	result.temperature = _sample01(temperature_noise, bx, by)
	result.humidity = _sample01(humidity_noise, bx, by)
	result.continentalness = _sample01(continentalness_noise, cx, cy)
	result.weirdness = _sample01(weirdness_noise, bx * 2.0, by * 2.0)
	return result


func _sample01(noise: FastNoiseLite, x: float, y: float) -> float:
	if noise == null:
		return 0.5
	return clampf(noise.get_noise_2d(x, y) * contrast * 0.5 + 0.5, 0.0, 1.0)


## Cópia independente para uso em outra thread.
##
## Só os [FastNoiseLite] precisam ser copiados: são os únicos objetos com estado
## interno tocado durante a geração. O resto é somente leitura e pode ser
## compartilhado sem risco.
func clone_for_thread() -> ClimateGenerator:
	var copy: ClimateGenerator = duplicate(false)
	copy.temperature_noise = _copy_noise(temperature_noise)
	copy.humidity_noise = _copy_noise(humidity_noise)
	copy.continentalness_noise = _copy_noise(continentalness_noise)
	copy.weirdness_noise = _copy_noise(weirdness_noise)
	return copy


static func _copy_noise(noise: FastNoiseLite) -> FastNoiseLite:
	return null if noise == null else noise.duplicate(false)

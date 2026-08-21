## Relevo base. Independente de bioma: montanha pode existir em qualquer bioma.
class_name HeightGenerator
extends Resource

@export_group("Ruídos")
@export var continentalness_noise: FastNoiseLite
@export var elevation_noise: FastNoiseLite
@export var mountain_noise: FastNoiseLite
@export var roughness_noise: FastNoiseLite
@export var detail_noise: FastNoiseLite

@export_group("Escalas")
@export_range(1.0, 8192.0, 1.0) var continent_scale: float = 1400.0
@export_range(1.0, 4096.0, 1.0) var elevation_scale: float = 260.0
@export_range(1.0, 4096.0, 1.0) var mountain_scale: float = 180.0
@export_range(1.0, 1024.0, 1.0) var roughness_scale: float = 90.0
@export_range(1.0, 512.0, 1.0) var detail_scale: float = 22.0

@export_group("Pesos")
@export_range(0.0, 1.0, 0.01) var continent_weight: float = 0.46
@export_range(0.0, 1.0, 0.01) var elevation_weight: float = 0.30
@export_range(0.0, 1.0, 0.01) var mountain_weight: float = 0.18
@export_range(0.0, 1.0, 0.01) var detail_weight: float = 0.06
## Expoente aplicado à crista de montanha (>1 deixa picos mais raros/afiados).
@export_range(0.5, 6.0, 0.1) var mountain_sharpness: float = 2.4
## Ganho aplicado ao valor final. O FastNoiseLite fractal raramente chega perto
## de -1/1; sem ganho o mundo fica quase plano. Suba para relevo mais dramático.
@export_range(0.5, 8.0, 0.05) var contrast: float = 3.2


func prepare(world_seed: int) -> void:
	_seed_noise(continentalness_noise, WorldRandom.sub_seed(world_seed, &"terrain/continent"))
	_seed_noise(elevation_noise, WorldRandom.sub_seed(world_seed, &"terrain/elevation"))
	_seed_noise(mountain_noise, WorldRandom.sub_seed(world_seed, &"terrain/mountain"))
	_seed_noise(roughness_noise, WorldRandom.sub_seed(world_seed, &"terrain/roughness"))
	_seed_noise(detail_noise, WorldRandom.sub_seed(world_seed, &"terrain/detail"))


func _seed_noise(noise: FastNoiseLite, value: int) -> void:
	if noise != null:
		noise.seed = value


func _n(noise: FastNoiseLite, x: float, y: float, scale: float) -> float:
	if noise == null:
		return 0.0
	return noise.get_noise_2d(float(x) / scale, float(y) / scale)


## Valor contínuo do relevo em -1..1. Sempre em coordenada MUNDIAL.
func sample_raw(world_xy: Vector2i) -> float:
	var fx := float(world_xy.x)
	var fy := float(world_xy.y)
	var continent := _n(continentalness_noise, fx, fy, continent_scale)
	var elevation := _n(elevation_noise, fx, fy, elevation_scale)
	var mountain_raw := _n(mountain_noise, fx, fy, mountain_scale)
	var mountain := pow(maxf(mountain_raw, 0.0), mountain_sharpness)
	var detail := _n(detail_noise, fx, fy, detail_scale)
	var value := (
		continent * continent_weight
		+ elevation * elevation_weight
		+ mountain * mountain_weight
		+ detail * detail_weight
	)
	var total := continent_weight + elevation_weight + mountain_weight + detail_weight
	if total <= 0.0:
		return 0.0
	return clampf(value / total * contrast, -1.0, 1.0)


## Rugosidade local em 0..1 (usada pelo [TerrainResolver]).
func sample_roughness(world_xy: Vector2i) -> float:
	return clampf(
		_n(roughness_noise, float(world_xy.x), float(world_xy.y), roughness_scale) * 0.5 + 0.5,
		0.0,
		1.0
	)


## Converte o valor contínuo em nível inteiro de altura.
func to_level(raw: float, settings: WorldSettings, bias: float = 0.0, amplitude: float = 1.0) -> int:
	var normalized := (raw + 1.0) * 0.5
	var value := lerpf(float(settings.min_height), float(settings.max_height), normalized)
	value = float(settings.sea_level) + (value - float(settings.sea_level)) * amplitude + bias
	return clampi(roundi(value), settings.min_height, settings.max_height)


## Cópia independente para uso em outra thread (ver ClimateGenerator).
func clone_for_thread() -> HeightGenerator:
	var copy: HeightGenerator = duplicate(false)
	copy.continentalness_noise = ClimateGenerator._copy_noise(continentalness_noise)
	copy.elevation_noise = ClimateGenerator._copy_noise(elevation_noise)
	copy.mountain_noise = ClimateGenerator._copy_noise(mountain_noise)
	copy.roughness_noise = ClimateGenerator._copy_noise(roughness_noise)
	copy.detail_noise = ClimateGenerator._copy_noise(detail_noise)
	return copy

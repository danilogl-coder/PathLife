## Amostrador global do mundo.
##
## Concentra clima + bioma + relevo base em um único recurso, para que TODOS os
## sistemas (passes, planejador de estruturas, minimapa, debug) enxerguem
## exatamente os mesmos valores em qualquer coordenada mundial, sem depender de
## chunk. É o que garante continuidade entre chunks e determinismo.
class_name WorldSampler
extends Resource

@export var climate: ClimateGenerator
@export var biome_resolver: BiomeResolver
@export var height_generator: HeightGenerator
@export var terrain_resolver: TerrainResolver

@export_group("Patamares")
## Um degrau de UMA célula solta no meio do campo não vira penhasco: vira um
## risco de terra no meio da grama — foi o que deixava o mundo "recortado".
## O filtro de mediana apaga esses picos e covas de uma célula e mantém as
## bordas longas, transformando ruído em PATAMARES contínuos.
@export var plateau_filter_enabled: bool = true
## Raio da vizinhança usada na mediana, em células. 1 = 3x3.
@export_range(1, 3, 1) var plateau_filter_radius: int = 2
## Quantas passadas de mediana. 2 remove também as línguas de duas células.
@export_range(1, 3, 1) var plateau_filter_passes: int = 2
## Teto do cache de níveis usado pelo filtro. Sem ele a mediana recalcularia a
## mesma célula centenas de vezes.
@export_range(1024, 262144, 1024) var height_cache_limit: int = 65536

@export_group("Variação de chão")
## Ruído que define as MANCHAS de variante de grama dentro de um bioma.
@export var variation_noise: FastNoiseLite
## Tamanho das manchas grandes, em células.
@export_range(2.0, 512.0, 1.0) var variation_scale: float = 26.0
## Tamanho do detalhe que quebra a borda das manchas.
@export_range(1.0, 128.0, 1.0) var variation_detail_scale: float = 7.0
@export_range(0.0, 1.0, 0.01) var variation_detail_weight: float = 0.28
## Ruído POR CÉLULA. Sem ele uma mancha inteira usa exatamente o mesmo tile, e
## qualquer detalhe da arte (uma falha de terra, uma pedra) se repete numa grade
## perfeita — é o que faz o campo parecer quadriculado. Um empurrãozinho por
## célula faz vizinhos sortearem variantes diferentes perto da fronteira e
## quebra a grade sem inventar arte nenhuma.
@export_range(0.0, 0.5, 0.01) var variation_cell_jitter: float = 0.14

var _settings: WorldSettings
var _world_seed: int = 0
## Cache de níveis por passada do filtro (chave = x, y, passada). Cada thread
## tem seu próprio amostrador (ver [method clone_for_thread]), sem disputa.
var _level_cache: Dictionary = {}


func prepare(p_settings: WorldSettings, p_world_seed: int) -> void:
	_settings = p_settings
	_world_seed = p_world_seed
	_level_cache.clear()
	if climate != null:
		climate.prepare(p_world_seed)
	if height_generator != null:
		height_generator.prepare(p_world_seed)
	if variation_noise != null:
		variation_noise.seed = WorldRandom.sub_seed(p_world_seed, &"ground_variation")


func settings() -> WorldSettings:
	return _settings


func world_seed() -> int:
	return _world_seed


func sample_climate(world_xy: Vector2i) -> ClimateSample:
	if climate == null:
		return ClimateSample.new()
	return climate.sample(world_xy)


func resolve_biome(world_xy: Vector2i) -> BiomeDefinition:
	if biome_resolver == null:
		return null
	return biome_resolver.resolve(sample_climate(world_xy)).primary


## Altura base (antes de qualquer estrutura/estrada). Determinística e global.
##
## Continua sendo função PURA da coordenada mundial: o filtro de patamares só
## olha o ruído bruto da vizinhança, nunca o chunk. Por isso não existe costura
## entre chunks nem diferença entre threads.
func base_height(world_xy: Vector2i) -> int:
	if height_generator == null or _settings == null:
		return 0
	if not plateau_filter_enabled:
		return _raw_level(world_xy)
	return _plateau_level(world_xy, plateau_filter_passes)


## Nível bruto da célula, sem filtro. É a quantização direta do ruído.
func _raw_level(world_xy: Vector2i) -> int:
	var key := Vector3i(world_xy.x, world_xy.y, 0)
	if _level_cache.has(key):
		return int(_level_cache[key])
	var bias := 0.0
	var amplitude := 1.0
	var biome := resolve_biome(world_xy)
	if biome != null:
		bias = biome.height_bias
		amplitude = biome.height_amplitude
	var level := height_generator.to_level(
		height_generator.sample_raw(world_xy), _settings, bias, amplitude
	)
	_store_level(key, level)
	return level


## Mediana da vizinhança, aplicada em passadas.
##
## É o filtro clássico para "achatar" ruído quantizado: apaga o que aparece em
## uma célula só e preserva bordas longas e retas. Cada passada é memorizada,
## senão a recursão reamostraria a mesma célula centenas de vezes.
func _plateau_level(world_xy: Vector2i, pass_index: int) -> int:
	if pass_index <= 0:
		return _raw_level(world_xy)
	var key := Vector3i(world_xy.x, world_xy.y, pass_index)
	if _level_cache.has(key):
		return int(_level_cache[key])
	var samples: Array[int] = []
	var radius := plateau_filter_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			samples.append(_plateau_level(world_xy + Vector2i(dx, dy), pass_index - 1))
	samples.sort()
	var level := samples[floori(float(samples.size()) / 2.0)]
	_store_level(key, level)
	return level


func _store_level(key: Vector3i, level: int) -> void:
	if _level_cache.size() >= height_cache_limit:
		_level_cache.clear()
	_level_cache[key] = level


## Valor 0..1 que escolhe a variante de grama da célula.
func ground_variation(world_xy: Vector2i) -> float:
	if variation_noise == null:
		return 0.5
	var broad := variation_noise.get_noise_2d(
		float(world_xy.x) / variation_scale, float(world_xy.y) / variation_scale
	)
	var detail := variation_noise.get_noise_2d(
		float(world_xy.x) / variation_detail_scale + 512.0,
		float(world_xy.y) / variation_detail_scale - 512.0
	)
	var mixed := lerpf(broad, detail, variation_detail_weight)
	# O ruído fractal raramente encosta em -1/1: o ganho espalha o valor pela
	# faixa toda, senão as variantes das pontas nunca apareceriam.
	var value := clampf(mixed * 1.9 * 0.5 + 0.5, 0.0, 1.0)
	if variation_cell_jitter > 0.0:
		var jitter := WorldRandom.value_01(
			WorldRandom.sub_seed(_world_seed, &"ground_variant"), world_xy
		)
		value += (jitter - 0.5) * variation_cell_jitter
	return clampf(value, 0.0, 1.0)


func roughness(world_xy: Vector2i) -> float:
	if height_generator == null:
		return 0.5
	return height_generator.sample_roughness(world_xy)


## Declive base considerando os 4 vizinhos cardeais (independe de chunk).
func base_slope(world_xy: Vector2i) -> float:
	var height := base_height(world_xy)
	var worst := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		worst = maxi(worst, absi(base_height(world_xy + offset) - height))
	return float(worst)


## Cópia independente, para rodar em outra thread sem disputa.
##
## Atenção: `Resource.duplicate(true)` no Godot 4.4+ só copia sub-recursos
## INTERNOS (os que não têm arquivo próprio). Como aqui todos os recursos são
## arquivos `.tres`, a clonagem precisa ser explícita — é isso que este método
## faz. Biomas e terrenos continuam compartilhados de propósito: são apenas
## leitura.
func clone_for_thread() -> WorldSampler:
	var copy: WorldSampler = duplicate(false)
	if climate != null:
		copy.climate = climate.clone_for_thread()
	if height_generator != null:
		copy.height_generator = height_generator.clone_for_thread()
	if variation_noise != null:
		copy.variation_noise = variation_noise.duplicate(false)
	copy.biome_resolver = biome_resolver
	copy.terrain_resolver = terrain_resolver
	copy._level_cache = {}
	copy.prepare(_settings, _world_seed)
	return copy

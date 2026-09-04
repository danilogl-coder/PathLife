## Ferramenta: (re)cria todos os `.tres` do mundo procedural.
##
## Uso:
##   godot --headless --path . --script res://tools/build_world_resources.gd
##
## Os arquivos gerados são recursos normais: depois de criados, edite tudo pelo
## Inspector. Este script serve para recriar a base do zero ou versionar
## mudanças grandes de configuração.
extends SceneTree

const OUT := "res://data/world/"
## Os `SpriteFrames` das árvores ficam junto das cenas que os usam, como já
## acontece com as animações do personagem.
const VEGETATION_OUT := "res://presentation/world/vegetation/"
## Manifesto escrito por `tools/gen_tree_atlases.py`.
const TREE_MANIFEST := "res://assets/world/vegetation/arvores_atlas.json"

var _saved: Array[String] = []


func _init() -> void:
	_ensure_dirs()
	if "--tiles-only" in OS.get_cmdline_user_args():
		var rebuilt_tile_set := _build_tileset()
		_save(rebuilt_tile_set, OUT + "tiles/ground_tileset.tres")
		_save(_build_catalog(rebuilt_tile_set), OUT + "tiles/ground_catalog.tres")
		print("\n--- TileSet, catálogo e transições atualizados ---")
		for path in _saved:
			print("  ", path)
		quit(0)
		return
	# Atualiza somente o catálogo quando o atlas/manifesto mudou. Evita recriar
	# biomas, configurações e outros Resources que podem ter sido ajustados pelo
	# Inspector desde a geração inicial.
	if "--catalog-only" in OS.get_cmdline_user_args():
		var existing_tile_set := load(OUT + "tiles/ground_tileset.tres") as TileSet
		if existing_tile_set == null:
			push_error("TileSet existente não encontrado; execute a geração completa.")
			quit(1)
			return
		_save(_build_catalog(existing_tile_set), OUT + "tiles/ground_catalog.tres")
		print("\n--- catálogo de tiles e transições atualizado ---")
		for path in _saved:
			print("  ", path)
		quit(0)
		return
	var noises := _build_noises()
	var climate: ClimateGenerator = _save(_build_climate(noises), OUT + "climate_generator.tres")
	var height: HeightGenerator = _save(_build_height(noises), OUT + "height_generator.tres")
	var terrains := _build_terrains()
	var terrain_resolver: TerrainResolver = _save(_build_terrain_resolver(terrains), OUT + "terrain_resolver.tres")
	var decorations := _build_decorations()
	var structures := _build_structures()
	var biomes := _build_biomes(decorations, structures)
	var biome_resolver: BiomeResolver = _save(_build_biome_resolver(biomes), OUT + "biome_resolver.tres")

	var sampler := WorldSampler.new()
	sampler.climate = climate
	sampler.biome_resolver = biome_resolver
	sampler.height_generator = height
	sampler.terrain_resolver = terrain_resolver
	sampler.variation_noise = noises["ground_variation"]
	sampler.resource_name = "WorldSampler"
	_save(sampler, OUT + "world_sampler.tres")

	var settings := WorldSettings.new()
	# Sem arte de água fornecida: a lâmina d'água fica abaixo do piso do mundo,
	# então nenhuma célula é submersa. Basta subir isto (e catalogar um tile de
	# água) para ligar oceanos e lagos.
	settings.sea_level = settings.min_height
	settings.water_ground_id = &"campo_terra"
	settings.resource_name = "WorldSettings"
	_save(settings, OUT + "world_settings.tres")

	var planner := StructurePlanner.new()
	planner.sampler = sampler
	planner.resource_name = "StructurePlanner"
	_save(planner, OUT + "structure_planner.tres")

	var generator := _build_generator(sampler, planner)
	_save(generator, OUT + "world_generator.tres")

	_build_vegetation_frames()

	var tile_set := _build_tileset()
	_save(tile_set, OUT + "tiles/ground_tileset.tres")
	_save(_build_catalog(tile_set), OUT + "tiles/ground_catalog.tres")

	var movement := MovementContext.new()
	movement.resource_name = "PlayerMovementContext"
	_save(movement, OUT + "player_movement_context.tres")

	print("\n--- %d recursos gravados ---" % _saved.size())
	for path in _saved:
		print("  ", path)
	quit(0)


# -------------------------------------------------------------- vegetação
## Monta um [SpriteFrames] por árvore a partir do atlas de quadros.
##
## Os quadros são [AtlasTexture] recortados de UMA textura — o Godot não carrega
## 48 imagens soltas por árvore, e trocar a arte é trocar um PNG.
func _build_vegetation_frames() -> void:
	var text := FileAccess.get_file_as_string(TREE_MANIFEST)
	if text.is_empty():
		push_error(
			"Manifesto das arvores nao encontrado em %s. Rode tools/gen_tree_atlases.py."
			% TREE_MANIFEST
		)
		return
	var manifest: Variant = JSON.parse_string(text)
	if not (manifest is Dictionary):
		push_error("Manifesto das arvores invalido.")
		return
	DirAccess.make_dir_recursive_absolute(VEGETATION_OUT)
	var animation := StringName(manifest.get("animation", "queda"))
	var fps := float(manifest.get("fps", 9.09))
	for tree: Dictionary in manifest.get("trees", []):
		var texture: Texture2D = load(String(tree["texture"]))
		if texture == null:
			push_error("Textura da arvore %s nao carregou." % tree["id"])
			continue
		var size: Array = tree["frame_size"]
		var frame_size := Vector2(float(size[0]), float(size[1]))
		var columns := int(tree["columns"])
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, fps)
		for index in int(tree["frames"]):
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(
				Vector2(float(index % columns), float(index / columns)) * frame_size,
				frame_size
			)
			# Sem isto o filtro pode puxar um pixel do quadro vizinho na borda.
			region.filter_clip = true
			frames.add_frame(animation, region)
		frames.resource_name = "arvore_%s" % tree["id"]
		_save(frames, VEGETATION_OUT + "arvore_%s_frames.tres" % tree["id"])


# ------------------------------------------------------------------ helpers
func _ensure_dirs() -> void:
	for sub in [
		"", "noise/", "biomes/", "variants/", "terrains/", "decorations/", "structures/",
		"passes/", "tiles/", "tiles/transicoes/",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + sub))
		DirAccess.make_dir_recursive_absolute(OUT + sub)


func _save(resource: Resource, path: String) -> Resource:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Falha ao gravar %s (erro %d)" % [path, error])
	else:
		resource.take_over_path(path)
		_saved.append(path)
	return resource


func _noise(
	name: String,
	frequency: float,
	noise_type: int,
	octaves: int = 4,
	lacunarity: float = 2.0,
	gain: float = 0.5
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain
	noise.resource_name = name
	var saved: FastNoiseLite = _save(noise, OUT + "noise/%s.tres" % name)
	return saved


func _build_noises() -> Dictionary:
	return {
		"temperature": _noise("temperature", 0.9, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3),
		"humidity": _noise("humidity", 1.1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3),
		"continentalness": _noise("continentalness", 0.8, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3),
		"weirdness": _noise("weirdness", 1.4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2),
		"elevation": _noise("elevation", 1.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4),
		"mountain": _noise("mountain", 1.0, FastNoiseLite.TYPE_SIMPLEX, 4, 2.1, 0.55),
		"roughness": _noise("roughness", 1.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3),
		"detail": _noise("detail", 1.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2),
		"ground_variation": _noise("ground_variation", 1.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3),
	}


func _build_climate(noises: Dictionary) -> ClimateGenerator:
	var climate := ClimateGenerator.new()
	climate.temperature_noise = noises["temperature"]
	climate.humidity_noise = noises["humidity"]
	climate.continentalness_noise = noises["continentalness"]
	climate.weirdness_noise = noises["weirdness"]
	climate.biome_scale = 420.0
	climate.continent_scale = 1400.0
	climate.resource_name = "ClimateGenerator"
	return climate


func _build_height(noises: Dictionary) -> HeightGenerator:
	var height := HeightGenerator.new()
	height.continentalness_noise = noises["continentalness"]
	height.elevation_noise = noises["elevation"]
	height.mountain_noise = noises["mountain"]
	height.roughness_noise = noises["roughness"]
	height.detail_noise = noises["detail"]
	height.resource_name = "HeightGenerator"
	return height


# ------------------------------------------------------------------ terrenos
func _terrain(
	id: StringName,
	display: String,
	roughness: Vector2,
	slope: Vector2,
	weight: float,
	override_ground: StringName = &"",
	walkable: bool = true,
	allows_structures: bool = true,
	expose_biome_wall: bool = false
) -> TerrainDefinition:
	var terrain := TerrainDefinition.new()
	terrain.id = id
	terrain.display_name = display
	terrain.min_roughness = roughness.x
	terrain.max_roughness = roughness.y
	terrain.min_slope = slope.x
	terrain.max_slope = slope.y
	terrain.weight = weight
	terrain.ground_override_id = override_ground
	terrain.walkable = walkable
	terrain.allows_structures = allows_structures
	terrain.expose_biome_wall = expose_biome_wall
	terrain.resource_name = String(id)
	var saved: TerrainDefinition = _save(terrain, OUT + "terrains/%s.tres" % id)
	return saved


func _build_terrains() -> Array[TerrainDefinition]:
	var result: Array[TerrainDefinition] = []
	result.append(_terrain(&"plano", "Plano", Vector2(0.0, 0.60), Vector2(0.0, 1.0), 1.0))
	result.append(_terrain(&"colina", "Colina", Vector2(0.35, 0.85), Vector2(1.0, 2.5), 1.0))
	# `expose_biome_wall` faz o relevo íngreme mostrar a terra do próprio bioma
	# em vez da grama. Vem DESLIGADO para o mundo continuar coberto de grama;
	# ligue no `.tres` do terreno se quiser encostas de solo exposto.
	result.append(_terrain(
		&"montanha", "Montanha", Vector2(0.60, 1.0), Vector2(2.0, 16.0), 1.0, &"", true, false, false
	))
	result.append(_terrain(
		&"penhasco", "Penhasco", Vector2(0.0, 1.0), Vector2(4.0, 16.0), 1.2, &"", true, false, false
	))
	return result


func _build_terrain_resolver(terrains: Array[TerrainDefinition]) -> TerrainResolver:
	var resolver := TerrainResolver.new()
	resolver.terrains = terrains
	resolver.fallback_terrain = terrains[0]
	resolver.resource_name = "TerrainResolver"
	return resolver


# --------------------------------------------------------------- decorações
func _decoration(
	id: StringName,
	scene_path: String,
	density: float,
	spacing: int,
	max_slope: float = 1.0,
	weight: float = 1.0
) -> DecorationDefinition:
	var decoration := DecorationDefinition.new()
	decoration.id = id
	decoration.scene = load(scene_path)
	decoration.density = density
	decoration.minimum_spacing = spacing
	decoration.max_slope = max_slope
	decoration.weight = weight
	decoration.resource_name = String(id)
	var saved: DecorationDefinition = _save(decoration, OUT + "decorations/%s.tres" % id)
	return saved


func _build_decorations() -> Dictionary:
	const BASE := "res://presentation/world/vegetation/"
	return {
		"alamo": _decoration(&"alamo", BASE + "arvore_alamo.tscn", 0.05, 3),
		"baoba": _decoration(&"baoba", BASE + "arvore_baoba.tscn", 0.025, 6),
		"ipe": _decoration(&"ipe", BASE + "arvore_ipe.tscn", 0.05, 3),
		"palmeira": _decoration(&"palmeira", BASE + "arvore_palmeira.tscn", 0.03, 5),
		"salgueiro": _decoration(&"salgueiro", BASE + "arvore_salgueiro.tscn", 0.05, 3),
		"sequoia": _decoration(&"sequoia", BASE + "arvore_sequoia.tscn", 0.09, 2),
	}


# --------------------------------------------------------------- estruturas
func _build_structures() -> Dictionary:
	var deck := StructureDefinition.new()
	deck.id = &"deck_madeira"
	deck.display_name = "Deck de madeira"
	deck.scene = load("res://presentation/world/structures/deck_madeira.tscn")
	deck.footprint = Vector2i(4, 4)
	deck.adaptation_margin = 5
	deck.spawn_weight = 1.0
	deck.spawn_chance = 0.6
	deck.minimum_spacing = 40
	deck.max_slope = 6.0
	deck.adaptation_mode = StructureDefinition.TerrainAdaptationMode.FLATTEN
	# Piso aberto: sem parede na borda, a grama da célula da frente encostaria
	# na última fileira de tábuas. Um anel de terra ao redor resolve.
	deck.bare_ground_margin = 1
	deck.allowed_biomes = [&"campo", &"campo_claro", &"campo_florido", &"floresta"]
	deck.resource_name = "deck_madeira"
	_save(deck, OUT + "structures/deck_madeira.tres")

	# Estrutura-base autorável pelo TileMap. Os valores altos de peso/chance são
	# intencionais no ambiente de trabalho: facilitam encontrar o exemplo.
	var casa := StructureDefinition.new()
	casa.id = &"casa_madeira"
	casa.display_name = "Casa de madeira"
	casa.scene = load("res://presentation/world/structures/casa_madeira_tilemap.tscn")
	casa.footprint = Vector2i(7, 8)
	casa.adaptation_margin = 5
	casa.spawn_weight = 16.0
	casa.spawn_chance = 1.0
	casa.minimum_spacing = 8
	casa.max_slope = 32.0
	casa.allowed_biomes = [&"campo"]
	casa.allowed_terrains = [&"plano", &"colina"]
	casa.adaptation_mode = StructureDefinition.TerrainAdaptationMode.FLATTEN
	casa.footprint_blocks_movement = false
	casa.resource_name = "casa_madeira"
	_save(casa, OUT + "structures/casa_madeira.tres")
	return {"deck": deck, "casa": casa}


# ------------------------------------------------------------------- biomas
func _biome(
	id: StringName,
	display: String,
	temperature: Vector2,
	humidity: Vector2,
	continentalness: Vector2,
	ground: StringName,
	wall: StringName,
	height_bias: float,
	amplitude: float,
	decorations: Array[DecorationDefinition],
	structures: Array[StructureDefinition] = [],
	weight: float = 1.0,
	variants: Array[GroundVariant] = []
) -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.id = id
	biome.display_name = display
	biome.temperature_min = temperature.x
	biome.temperature_max = temperature.y
	biome.humidity_min = humidity.x
	biome.humidity_max = humidity.y
	biome.continentalness_min = continentalness.x
	biome.continentalness_max = continentalness.y
	biome.ground_id = ground
	biome.wall_id = wall
	biome.underwater_ground_id = wall
	biome.height_bias = height_bias
	biome.height_amplitude = amplitude
	biome.weight = weight
	biome.ground_variants = variants
	biome.decorations = decorations
	biome.structure_pool = structures
	biome.resource_name = String(id)
	var saved: BiomeDefinition = _save(biome, OUT + "biomes/%s.tres" % id)
	return saved


## Variantes de grama de um bioma, da mais densa para a mais rala.
##
## A ORDEM importa: o sorteio percorre o array conforme o ruído sobe, então
## variantes vizinhas no array viram manchas vizinhas no mapa.
func _variants(entries: Array) -> Array[GroundVariant]:
	var result: Array[GroundVariant] = []
	for entry: Array in entries:
		var variant := GroundVariant.new()
		variant.ground_id = entry[0]
		variant.weight = entry[1]
		variant.resource_name = String(entry[0])
		_save(variant, OUT + "variants/%s.tres" % entry[0])
		result.append(variant)
	return result


## Um bioma por PASTA de bioma da arte original — cada um com as suas variantes.
## Um bioma por PASTA de bioma da arte original — cada um com as suas variantes.
##
## A LISTA de variantes vem do manifesto do atlas, na ordem da escala: da mais
## escura/densa para a mais clara/rala, com as transições geradas entre elas. É
## isso que faz o ruído caminhar pela escala em vez de pular de um extremo ao
## outro — sem essa ordem, as intermediárias não suavizariam nada.
func _build_biomes(d: Dictionary, s: Dictionary) -> Array[BiomeDefinition]:
	var deck: Array[StructureDefinition] = [s["deck"]]
	var deck_e_casa: Array[StructureDefinition] = [s["deck"], s["casa"]]
	var result: Array[BiomeDefinition] = []

	result.append(_biome(&"campo_claro", "Campo claro", Vector2(0.0, 0.36), Vector2(0.0, 1.0),
		Vector2(0.0, 1.0), &"claro", &"campo_claro_terra", 0.8, 1.15,
		[d["alamo"]] as Array[DecorationDefinition], deck, 1.0,
		_biome_variants(&"campo_claro")))

	result.append(_biome(&"campo", "Campo", Vector2(0.36, 0.68), Vector2(0.0, 0.55),
		Vector2(0.0, 1.0), &"campo_baixo", &"campo_terra", 0.0, 1.0,
		[d["ipe"], d["alamo"]] as Array[DecorationDefinition], deck_e_casa, 1.15,
		_biome_variants(&"campo")))

	result.append(_biome(&"floresta", "Floresta", Vector2(0.30, 0.68), Vector2(0.55, 1.0),
		Vector2(0.0, 1.0), &"musgo", &"floresta_terra", 0.4, 1.1,
		[d["sequoia"], d["salgueiro"], d["ipe"]] as Array[DecorationDefinition], deck, 1.05,
		_biome_variants(&"floresta")))

	result.append(_biome(&"campo_florido", "Campo florido", Vector2(0.68, 1.0), Vector2(0.48, 1.0),
		Vector2(0.0, 1.0), &"florida_baixa", &"campo_florido_terra", 0.0, 0.95,
		[d["ipe"]] as Array[DecorationDefinition], deck, 1.0,
		_biome_variants(&"campo_florido")))

	result.append(_biome(&"savana", "Savana", Vector2(0.68, 1.0), Vector2(0.0, 0.48),
		Vector2(0.0, 1.0), &"savana_baixa", &"savana_terra", 0.0, 0.85,
		[d["baoba"], d["palmeira"]] as Array[DecorationDefinition], [], 1.05,
		_biome_variants(&"savana")))
	return result


## Variantes de um bioma, direto do manifesto do atlas.
func _biome_variants(biome_id: StringName) -> Array[GroundVariant]:
	for entry: Dictionary in _atlas().get("biomes", []):
		if StringName(entry["id"]) != biome_id:
			continue
		var rows: Array = []
		for variant: Dictionary in entry["variants"]:
			rows.append([StringName(variant["id"]), float(variant["weight"])])
		return _variants(rows)
	push_error("Bioma %s nao esta no manifesto do atlas." % biome_id)
	return [] as Array[GroundVariant]


func _build_biome_resolver(biomes: Array[BiomeDefinition]) -> BiomeResolver:
	var resolver := BiomeResolver.new()
	resolver.biomes = biomes
	for biome in biomes:
		if biome.id == &"campo":
			resolver.fallback_biome = biome
	resolver.resource_name = "BiomeResolver"
	return resolver


# ---------------------------------------------------------------- pipeline
func _build_generator(sampler: WorldSampler, planner: StructurePlanner) -> WorldGenerator:
	var passes: Array[WorldGenerationPass] = []

	var climate_pass := ClimatePass.new()
	climate_pass.pass_name = "1 - Clima macro"
	climate_pass.sampler = sampler
	_save(climate_pass, OUT + "passes/01_climate.tres")
	passes.append(climate_pass)

	var biome_pass := BiomePass.new()
	biome_pass.pass_name = "2 - Biomas"
	biome_pass.sampler = sampler
	_save(biome_pass, OUT + "passes/02_biome.tres")
	passes.append(biome_pass)

	var height_pass := HeightPass.new()
	height_pass.pass_name = "3 - Relevo base"
	height_pass.sampler = sampler
	_save(height_pass, OUT + "passes/03_height.tres")
	passes.append(height_pass)

	var structure_pass := StructurePass.new()
	structure_pass.pass_name = "4 - Estruturas + adaptacao do terreno"
	structure_pass.planner = planner
	_save(structure_pass, OUT + "passes/04_structures.tres")
	passes.append(structure_pass)

	var terrain_pass := TerrainPass.new()
	terrain_pass.pass_name = "5 - Classificacao de relevo"
	terrain_pass.sampler = sampler
	_save(terrain_pass, OUT + "passes/05_terrain.tres")
	passes.append(terrain_pass)

	var water_pass := WaterPass.new()
	water_pass.pass_name = "6 - Agua (desligado: falta arte de agua)"
	water_pass.sampler = sampler
	water_pass.water_ground_id = &"campo_terra"
	water_pass.enabled = false
	_save(water_pass, OUT + "passes/06_water.tres")
	passes.append(water_pass)

	var decoration_pass := DecorationPass.new()
	decoration_pass.pass_name = "7 - Decoracao"
	decoration_pass.sampler = sampler
	_save(decoration_pass, OUT + "passes/07_decoration.tres")
	passes.append(decoration_pass)

	var generator := WorldGenerator.new()
	generator.passes = passes
	generator.resource_name = "WorldGenerator"
	return generator


# ------------------------------------------------------------------- tiles
## Manifesto escrito por `tools/gen_ground_atlas.py`.
##
## As linhas do atlas, quais delas animam e as variantes de cada bioma saem
## TODAS daqui. Antes essa lista vivia repetida na mão neste arquivo: bastava
## acrescentar um tile na arte para as duas versões saírem de sincronia e o
## mundo desenhar o tile errado. Agora quem gera a arte também descreve a arte.
const ATLAS_MANIFEST := "res://assets/world/tiles/ground_atlas.json"

## Deslocamento do losango dentro da região 128x106 do atlas.
const TILE_ART_OFFSET := -5
## Altura em pixels de um nível (precisa bater com WorldSettings.height_pixels).
const HEIGHT_PIXELS := 26
## Faixa de níveis para a qual são geradas alternativas de tile.
const LEVEL_MIN := -16
const LEVEL_MAX := 24

var _manifest: Dictionary = {}


func _atlas() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	var text := FileAccess.get_file_as_string(ATLAS_MANIFEST)
	if text.is_empty():
		push_error(
			"Manifesto do atlas nao encontrado em %s. Rode tools/gen_ground_atlas.py."
			% ATLAS_MANIFEST
		)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_manifest = parsed
	return _manifest


func _ground_rows() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in _atlas().get("rows", []):
		ids.append(StringName(entry["id"]))
	return ids


func _animated_rows() -> int:
	return int(_atlas().get("animated_rows", 0))


## Quantas colunas de tile separam um recorte de face do seguinte no atlas.
func _face_kind_stride() -> int:
	var atlas: Dictionary = _atlas().get("atlas", {})
	return int(atlas.get("face_kind_stride", 3))


func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = Vector2i(128, 64)
	tile_set.resource_name = "GroundTileSet"

	var ground_rows := _ground_rows()
	var animated_rows := _animated_rows()

	var source := TileSetAtlasSource.new()
	# Ground principal contém apenas a superfície. Assim tiles planos não
	# exibem laterais internas nem repetem a lateral no meio do campo.
	source.texture = load("res://assets/world/tiles/ground_top_atlas.png")
	source.texture_region_size = Vector2i(128, 106)
	source.resource_name = "GroundSurfaceAtlas"

	for row in ground_rows.size():
		var coords := Vector2i(0, row)
		source.create_tile(coords)
		if row < animated_rows:
			source.set_tile_animation_columns(coords, 3)
			source.set_tile_animation_frames_count(coords, 3)
			source.set_tile_animation_speed(coords, 1.4)
			for frame in 3:
				source.set_tile_animation_frame_duration(coords, frame, 1.0)
		# Alternativa 0 = nível 0 (base).
		var base := source.get_tile_data(coords, 0)
		base.texture_origin = Vector2i(0, TILE_ART_OFFSET)
		base.y_sort_origin = 0

		# Uma alternativa por nível de altura. Ground não participa do Y-Sort;
		# texture_origin serve somente para elevar a superfície visualmente.
		for level in range(LEVEL_MIN, LEVEL_MAX + 1):
			var alternative := source.create_alternative_tile(coords, 1 + level - LEVEL_MIN)
			var data := source.get_tile_data(coords, alternative)
			# texture_origin é SUBTRAÍDO da posição de desenho, então para subir
			# o bloco em `level * HEIGHT_PIXELS` o valor precisa ser POSITIVO.
			data.texture_origin = Vector2i(0, TILE_ART_OFFSET + level * HEIGHT_PIXELS)
			data.y_sort_origin = 0
	tile_set.add_source(source, 0)

	# Faces verticais ficam em uma fonte independente e entram no DepthSort.
	# Para cada linha lógica: esquerda, direita e ambas.
	var stride := _face_kind_stride()
	var face_source := TileSetAtlasSource.new()
	face_source.texture = load("res://assets/world/tiles/depth_face_atlas.png")
	face_source.texture_region_size = Vector2i(128, 106)
	face_source.resource_name = "DepthFaceAtlas"
	for row in ground_rows.size():
		for face_kind in 3:
			# Os três recortes ficam LADO A LADO no atlas. Empilhados em linhas,
			# a textura passaria de 13 000 px de altura — perto do teto de
			# muitas GPUs — assim que o número de variantes cresceu.
			var coords := Vector2i(face_kind * stride, row)
			face_source.create_tile(coords)
			if row < animated_rows:
				face_source.set_tile_animation_columns(coords, 3)
				face_source.set_tile_animation_frames_count(coords, 3)
				face_source.set_tile_animation_speed(coords, 1.4)
				for frame in 3:
					face_source.set_tile_animation_frame_duration(coords, frame, 1.0)
			var base := face_source.get_tile_data(coords, 0)
			base.texture_origin = Vector2i(0, TILE_ART_OFFSET)
			# Base/frente do losango: é este pivô, em pixels, que decide se a
			# parede cobre o ator. Não confundir com o número do Z-Level.
			base.y_sort_origin = tile_set.tile_size.y / 2 - 1
			for level in range(LEVEL_MIN, LEVEL_MAX + 1):
				var alternative := face_source.create_alternative_tile(
					coords, 1 + level - LEVEL_MIN
				)
				var data := face_source.get_tile_data(coords, alternative)
				data.texture_origin = Vector2i(0, TILE_ART_OFFSET + level * HEIGHT_PIXELS)
				data.y_sort_origin = tile_set.tile_size.y / 2 - 1
	tile_set.add_source(face_source, 1)

	# Bloco completo mantido como fonte de compatibilidade para ferramentas e
	# cenas antigas. O renderer atual usa apenas TOP em Ground e FACE em Depth;
	# não cria underlay por chunk, pois isso reintroduziria barreiras de desenho.
	var underlay_source := TileSetAtlasSource.new()
	underlay_source.texture = load("res://assets/world/tiles/ground_atlas.png")
	underlay_source.texture_region_size = Vector2i(128, 106)
	underlay_source.resource_name = "GroundEdgeUnderlayAtlas"
	for row in ground_rows.size():
		var coords := Vector2i(0, row)
		underlay_source.create_tile(coords)
		if row < animated_rows:
			underlay_source.set_tile_animation_columns(coords, 3)
			underlay_source.set_tile_animation_frames_count(coords, 3)
			underlay_source.set_tile_animation_speed(coords, 1.4)
			for frame in 3:
				underlay_source.set_tile_animation_frame_duration(coords, frame, 1.0)
		var base := underlay_source.get_tile_data(coords, 0)
		base.texture_origin = Vector2i(0, TILE_ART_OFFSET)
		base.y_sort_origin = 0
		for level in range(LEVEL_MIN, LEVEL_MAX + 1):
			var alternative := underlay_source.create_alternative_tile(
				coords, 1 + level - LEVEL_MIN
			)
			var data := underlay_source.get_tile_data(coords, alternative)
			data.texture_origin = Vector2i(0, TILE_ART_OFFSET + level * HEIGHT_PIXELS)
			data.y_sort_origin = 0
	tile_set.add_source(underlay_source, 2)
	return tile_set


func _build_catalog(tile_set: TileSet) -> TileCatalog:
	var catalog := TileCatalog.new()
	catalog.tile_set = tile_set
	catalog.fallback_ground_id = &"campo_terra"
	catalog.level_min = LEVEL_MIN
	catalog.level_max = LEVEL_MAX
	catalog.resource_name = "GroundCatalog"
	catalog.face_kind_stride = _face_kind_stride()
	var directional := _directional_rows()
	var entries: Array[GroundTileEntry] = []
	var ground_rows := _ground_rows()
	for row in ground_rows.size():
		var entry := GroundTileEntry.new()
		entry.ground_id = ground_rows[row]
		entry.source_id = 0
		entry.atlas_coords = Vector2i(0, row)
		entry.alternative_tile = 0
		entry.directional = directional.has(entry.ground_id)
		entry.resource_name = String(ground_rows[row])
		entries.append(entry)
	catalog.entries = entries
	var transitions: BiomeTransitionCatalog = _save(
		_build_transitions(), OUT + "tiles/biome_transitions.tres"
	)
	catalog.transitions = transitions
	return catalog


## Ids cuja arte aponta para um lado — as peças de fronteira. Elas não podem ser
## espelhadas; quem respeita isso é o [ChunkView], lendo esta marca.
func _directional_rows() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _atlas().get("rows", []):
		if String(entry.get("kind", "")) == "transicao_bioma":
			result[StringName(entry["id"])] = true
	return result


## Bioma -> grupo de fronteira.
##
## Vários biomas compartilham a mesma arte de borda: campo, campo claro e campo
## florido são todos `campo`, então `campo_para_musgo` serve para os três. Um
## bioma fora deste mapa simplesmente não ganha transição — é assim que
## floresta↔savana continua no corte seco enquanto não existir arte para ela.
const TRANSITION_GROUPS := {
	&"campo": &"campo",
	&"campo_claro": &"campo",
	&"campo_florido": &"campo",
	&"floresta": &"floresta",
	&"savana": &"savana",
}


## Catálogo de fronteiras: os pares vêm do manifesto do atlas (quem tem arte),
## os grupos vêm da tabela acima (quem usa qual arte).
func _build_transitions() -> BiomeTransitionCatalog:
	var transitions := BiomeTransitionCatalog.new()
	var grupos: Dictionary[StringName, StringName] = {}
	for biome_id: StringName in TRANSITION_GROUPS:
		grupos[biome_id] = TRANSITION_GROUPS[biome_id]
	transitions.grupos = grupos

	var rules: Array[BiomeTransitionRule] = []
	var section: Dictionary = _atlas().get("transicoes", {})
	for entry: Dictionary in section.get("pares", []):
		var rule := BiomeTransitionRule.new()
		rule.de_grupo = StringName(entry["de"])
		rule.para_grupo = StringName(entry["para"])
		rule.prefixo = StringName(entry["prefixo"])
		rule.resource_name = String(rule.prefixo)
		var saved: BiomeTransitionRule = _save(
			rule, OUT + "tiles/transicoes/%s.tres" % rule.prefixo
		)
		rules.append(saved)
	transitions.rules = rules
	transitions.enabled = true
	transitions.resource_name = "BiomeTransitions"
	if rules.is_empty():
		push_warning(
			"Nenhum par de transicao no manifesto. Rode tools/gen_ground_atlas.py."
		)
	return transitions

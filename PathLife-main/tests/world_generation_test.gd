## Bateria de testes do módulo de mundo procedural.
##
## Uso:
##   godot --headless --path . --script res://tests/world_generation_test.gd
extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_chunk_math()
	_test_iso_matches_tilemap()
	_test_movement_rules()
	_test_biome_scoring()
	_test_terrain_adapter()
	_test_determinism()
	_test_no_seams_between_chunks()
	_test_generation_pipeline()
	_test_structure_planner_is_region_stable()
	_test_navigation()
	_test_save_patches()
	_test_depth_sorting_setup()
	_test_plateau_filter()
	_test_world_object_anchor()
	_test_vegetation_animation()
	_test_front_surface_covers_rear_face()
	_test_depth_swap_lands_on_cell_border()

	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Trava de regressão da ORDENAÇÃO DE PROFUNDIDADE.
##
## Se alguém voltar a colocar o deslocamento de altura na posição do nó (ou
## trocar o sinal do texture_origin), o mundo volta a desenhar terreno alto por
## cima do jogador — e/ou de cabeça para baixo. Estes testes pegam isso.
func _test_depth_sorting_setup() -> void:
	print("\n[Profundidade] alternativas de tile por altura")
	var settings := _settings()
	var catalog: TileCatalog = load("res://data/world/tiles/ground_catalog.tres")
	var source: TileSetAtlasSource = catalog.tile_set.get_source(TileCatalog.GROUND_SOURCE_ID)
	var face_source: TileSetAtlasSource = catalog.tile_set.get_source(
		TileCatalog.DEPTH_FACE_SOURCE_ID
	)
	var entry := catalog.find(&"campo")
	_check(entry != null, "catalogo resolve o chao campo")

	var ok_origin := true
	var ground_sort_ok := true
	var face_sort_ok := true
	var art_offset := -5
	for level in [settings.min_height, -1, 0, 1, settings.max_height]:
		var alternative := catalog.alternative_for(level)
		if not source.has_alternative_tile(entry.atlas_coords, alternative):
			ok_origin = false
			continue
		var data := source.get_tile_data(entry.atlas_coords, alternative)
		# POSITIVO: texture_origin é subtraído na hora de desenhar, então é
		# assim que o bloco sobe na tela conforme o nível aumenta.
		if data.texture_origin != Vector2i(0, art_offset + level * settings.height_pixels):
			ok_origin = false
		if data.y_sort_origin != 0:
			ground_sort_ok = false
		for mask in TileCatalog.FaceMask.values():
			var face_coords := catalog.face_atlas_coords(entry, mask)
			if not face_source.has_alternative_tile(face_coords, alternative):
				face_sort_ok = false
				continue
			var face_data := face_source.get_tile_data(face_coords, alternative)
			if face_data.y_sort_origin != settings.tile_size.y / 2 - 1:
				face_sort_ok = false
			if face_data.texture_origin != Vector2i(
				0, art_offset + level * settings.height_pixels
			):
				face_sort_ok = false
	_check(ok_origin, "texture_origin sobe o bloco conforme o nivel")
	_check(ground_sort_ok, "Ground nao usa altura como chave de Y-Sort")
	_check(face_sort_ok, "faces usam a base frontal como pivo de Y-Sort")
	_check(catalog.tile_set.get_source_count() == 3,
		"topos e faces ficam separados; fonte completa permanece compativel")

	# Uma face não pode ser mais alta que um Z-Level. Se a saia inteira do tile
	# original vazar para Depth, ela invade o patamar inferior porque Ground está
	# numa classe Z atrás e não consegue recobrir o excesso.
	# Lê o PNG-fonte, não a textura importada (o importador pode expandir a
	# borda de alpha em 1 px para evitar halos).
	var face_image := Image.new()
	var face_file := FileAccess.open(
		"res://assets/world/tiles/depth_face_atlas.png", FileAccess.READ
	)
	if face_file != null:
		face_image.load_png_from_buffer(face_file.get_buffer(face_file.get_length()))
	var face_height_ok := not face_image.is_empty()
	var maximum_face_span := 0
	var maximum_face_detail := ""
	var region_size := face_source.texture_region_size
	if not face_image.is_empty():
		for row in catalog.entries.size():
			for mask in TileCatalog.FaceMask.values():
				for frame in 3:
					for local_x in region_size.x:
						var first_alpha := -1
						var last_alpha := -1
						# Coordenada vinda do próprio catálogo: se o layout do
						# atlas mudar, o teste acompanha em vez de mentir.
						var face_coords := catalog.face_atlas_coords(
							catalog.entries[row], mask
						)
						var atlas_x := (face_coords.x + frame) * region_size.x + local_x
						var atlas_y := face_coords.y * region_size.y
						for local_y in region_size.y:
							# A importação GPU pode introduzir resíduos de alpha muito baixos
							# nos pixels transparentes; só pixel visualmente sólido conta.
							if face_image.get_pixel(atlas_x, atlas_y + local_y).a > 0.5:
								if first_alpha < 0:
									first_alpha = local_y
								last_alpha = local_y
						if first_alpha >= 0:
							var span := last_alpha - first_alpha + 1
							if span > maximum_face_span:
								maximum_face_span = span
								maximum_face_detail = "row=%d mask=%d frame=%d x=%d y=%d..%d" % [
									row, int(mask), frame, local_x, first_alpha, last_alpha,
								]
							if span > settings.height_pixels:
								face_height_ok = false
	_check(face_height_ok, "cada fatia vertical cabe exatamente em um Z-Level",
		"max=%d (%s)" % [maximum_face_span, maximum_face_detail])
	var iso_for_sort := IsoCoordinateSystem.from_settings(settings)
	var cliff := Vector2i(4, 7)
	var face_sort_y := iso_for_sort.cell_to_local(cliff).y + float(settings.tile_size.y / 2 - 1)
	var actor_behind_y := iso_for_sort.cell_to_local(cliff).y + iso_for_sort.prop_sort_bias()
	var front_cell := cliff + Vector2i(1, 0)
	var cap_sort_y := iso_for_sort.cell_to_local(front_cell).y
	var actor_in_front_y := cap_sort_y + iso_for_sort.prop_sort_bias()
	_check(actor_behind_y < face_sort_y,
		"face desenha depois do ator que esta atras")
	_check(face_sort_y < cap_sort_y,
		"tampa frontal recobre a sobra horizontal da face")
	_check(cap_sort_y < actor_in_front_y,
		"ator na celula frontal desenha depois da tampa")

	# A chave de ordenação não depende da altura. A face usa a borda frontal do
	# losango; a alternativa usa texture_origin apenas para elevação visual.
	var iso := IsoCoordinateSystem.from_settings(settings)
	var flat_a := iso.cell_to_local(Vector2i(4, 7))
	var flat_b := iso.cell_to_local(Vector2i(4, 7))
	_check(flat_a == flat_b, "posicao plana e estavel")
	var low := iso.world_to_local(Vector3i(4, 7, 0))
	var high := iso.world_to_local(Vector3i(4, 7, 6))
	_check(low.y > high.y, "altura maior desenha mais acima na tela")
	_check(is_equal_approx(flat_a.y, low.y), "plano == nivel 0")
	# Dentro de uma célula a ordem tem de ser: superfície -> objeto -> parede
	# frontal. Se o viés empatar com a superfície (0) ou alcançar a próxima
	# diagonal (meia altura), objeto e chão trocam de lugar.
	var bias := iso.prop_sort_bias()
	_check(bias > 0.0, "objeto nao empata com a superficie em que pisa", str(bias))
	_check(bias < float(settings.tile_size.y) * 0.5,
		"objeto continua sendo coberto pela proxima diagonal", str(bias))

	# Sombreamento por altura precisa dar contraste entre patamares vizinhos.
	var here := settings.tint_for_level(3, 3)
	var below := settings.tint_for_level(2, 3)
	var above := settings.tint_for_level(4, 3)
	_check(here == Color.WHITE, "o nivel do jogador fica com a cor original", str(here))
	_check(below.v < 1.0 and above.v < 1.0, "niveis acima e abaixo recebem sombreamento")
	_check(below.v < above.v, "abaixo escurece mais que acima")
	_check(1.0 - below.v > 0.05, "contraste entre niveis vizinhos e perceptivel",
		"delta %f" % (1.0 - below.v))

	# Só a arte fornecida anima. O manifesto do atlas é a fonte da verdade:
	# quando você acrescenta um tile na pasta de arte, é ele que muda — o teste
	# acompanha em vez de travar num número escrito à mão.
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/world/tiles/ground_atlas.json")
	)
	var art_ids: Dictionary = {}
	var blend_ids: Dictionary = {}
	var dirt_ids: Dictionary = {}
	for row_info: Dictionary in manifest.get("rows", []):
		match String(row_info["kind"]):
			"arte": art_ids[StringName(row_info["id"])] = true
			"transicao": blend_ids[StringName(row_info["id"])] = true
			_: dirt_ids[StringName(row_info["id"])] = true
	var expected_animated := art_ids.size() + blend_ids.size()
	_check(art_ids.size() == 16, "as 16 variantes fornecidas continuam catalogadas",
		"%d" % art_ids.size())
	_check(blend_ids.size() > 0, "existem variantes de transicao entre as fornecidas",
		"%d" % blend_ids.size())

	var animated := 0
	var static_tiles := 0
	for row in catalog.entries.size():
		var coords := Vector2i(0, row)
		if source.get_tile_animation_frames_count(coords) > 1:
			animated += 1
		else:
			static_tiles += 1
	_check(animated == expected_animated,
		"grama fornecida e transicoes animam; nada mais",
		"%d de %d" % [animated, expected_animated])
	_check(static_tiles == dirt_ids.size(), "os blocos de terra derivados sao estaticos",
		"%d estaticos" % static_tiles)

	# Cada bioma precisa de um bloco de terra proprio catalogado.
	var resolver_check: BiomeResolver = load("res://data/world/biome_resolver.tres")
	var walls_ok := true
	for biome in resolver_check.biomes:
		if biome.wall_id == &"" or not catalog.has(biome.wall_id):
			walls_ok = false
		if biome.wall_id == biome.ground_id:
			walls_ok = false
	_check(walls_ok, "cada bioma tem bloco de terra proprio embaixo da grama")

	# Variantes de grama: todas catalogadas e todas alcançáveis.
	var variants_ok := true
	var total_variants := 0
	for biome in resolver_check.biomes:
		if biome.ground_variants.size() < 2:
			variants_ok = false
		for variant in biome.ground_variants:
			total_variants += 1
			if variant == null or not catalog.has(variant.ground_id):
				variants_ok = false
	_check(variants_ok, "todo bioma tem 2+ variantes catalogadas")
	_check(total_variants == expected_animated,
		"toda variante do atlas (arte + transicao) esta em uso",
		"%d de %d" % [total_variants, expected_animated])
	# O que motiva as transições: entre duas variantes vizinhas na escala do
	# bioma o salto de luminosidade tem de ser pequeno. Sem isso o campo troca
	# de tom de uma célula para a outra.
	var worst_jump := 0.0
	for biome in resolver_check.biomes:
		for index in range(biome.ground_variants.size() - 1):
			var a := _tile_luma(catalog, biome.ground_variants[index].ground_id)
			var b := _tile_luma(catalog, biome.ground_variants[index + 1].ground_id)
			worst_jump = maxf(worst_jump, absf(a - b))
	_check(worst_jump < 0.075, "vizinhas na escala do bioma tem contraste suave",
		"maior salto %.3f" % worst_jump)

	var reachable_variants := 0
	for biome in resolver_check.biomes:
		var seen: Dictionary = {}
		for step in 200:
			seen[biome.pick_ground(float(step) / 199.0)] = true
		reachable_variants += seen.size()
		if seen.size() != biome.ground_variants.size():
			variants_ok = false
	_check(reachable_variants == expected_animated,
		"toda variante e alcancavel pelo sorteio",
		"%d de %d" % [reachable_variants, expected_animated])


## Luminosidade média da face de cima de um tile, lida do atlas.
func _tile_luma(catalog: TileCatalog, ground_id: StringName) -> float:
	var entry := catalog.find(ground_id)
	if entry == null:
		return 0.0
	var source := catalog.tile_set.get_source(TileCatalog.GROUND_SOURCE_ID) as TileSetAtlasSource
	var image := source.texture.get_image()
	var region := source.get_tile_texture_region(entry.atlas_coords, 0)
	var total := 0.0
	var count := 0
	# Só o miolo do losango: as bordas e a saia são terra em todo tile.
	for y in range(region.position.y + 30, region.position.y + 66, 2):
		for x in range(region.position.x + 44, region.position.x + 84, 2):
			var color := image.get_pixel(x, y)
			if color.a < 0.8:
				continue
			total += color.get_luminance()
			count += 1
	return total / maxf(1.0, float(count))


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])


func _settings() -> WorldSettings:
	var settings: WorldSettings = load("res://data/world/world_settings.tres")
	return settings.duplicate(true)


# ---------------------------------------------------------------------------
func _test_chunk_math() -> void:
	print("\n[ChunkMath] coordenadas negativas")
	var size := 32
	_check(ChunkMath.world_to_chunk(Vector2i(-1, -1), size) == Vector2i(-1, -1), "chunk de (-1,-1)")
	_check(ChunkMath.world_to_local(Vector2i(-1, -1), size) == Vector2i(31, 31), "local de (-1,-1)")
	_check(ChunkMath.world_to_chunk(Vector2i(0, 0), size) == Vector2i(0, 0), "chunk de (0,0)")
	_check(ChunkMath.world_to_local(Vector2i(33, -33), size) == Vector2i(1, 31), "local de (33,-33)")
	var round_trip := ChunkMath.chunk_local_to_world(
		ChunkMath.world_to_chunk(Vector2i(-70, 45), size),
		ChunkMath.world_to_local(Vector2i(-70, 45), size),
		size
	)
	_check(round_trip == Vector2i(-70, 45), "ida e volta world->chunk->world")
	_check(ChunkMath.chunk_to_region(Vector2i(-1, 0), 4) == Vector2i(-1, 0), "chunk -> regiao")


func _test_iso_matches_tilemap() -> void:
	print("\n[Isometria] IsoCoordinateSystem x TileMapLayer")
	var settings := _settings()
	var iso := IsoCoordinateSystem.from_settings(settings)
	var layer := TileMapLayer.new()
	layer.tile_set = load("res://data/world/tiles/ground_tileset.tres")
	var all_match := true
	var sample := Vector2i.ZERO
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-3, 5), Vector2i(7, -2)]:
		if layer.map_to_local(cell) != iso.cell_to_local(cell):
			all_match = false
			sample = cell
	_check(all_match, "map_to_local == cell_to_local", "divergiu em %s" % sample)

	var back_ok := true
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(4, 9), Vector2i(-6, -7)]:
		if iso.local_to_cell(iso.cell_to_local(cell)) != cell:
			back_ok = false
	_check(back_ok, "local_to_cell inverte cell_to_local")

	var high := iso.world_to_local(Vector3i(3, 3, 4))
	var low := iso.world_to_local(Vector3i(3, 3, 0))
	_check(is_equal_approx(low.y - high.y, 4.0 * settings.height_pixels), "altura Z desloca no eixo Y")
	layer.free()


func _test_movement_rules() -> void:
	print("\n[MovementRules] regras de degrau")
	var T := MovementRules.MovementTransition
	_check(MovementRules.evaluate(0, 0, true) == T.WALK, "mesma altura anda")
	_check(MovementRules.evaluate(0, 1, true) == T.STEP_UP, "+1 sobe")
	_check(MovementRules.evaluate(0, -1, true) == T.STEP_DOWN, "-1 desce")
	_check(MovementRules.evaluate(0, 2, true) == T.BLOCKED, "+2 bloqueado")
	_check(MovementRules.evaluate(0, -3, true) == T.FALL, "-3 e queda")
	_check(MovementRules.evaluate(0, -99, true) == T.BLOCKED, "queda absurda bloqueia")
	_check(MovementRules.evaluate(0, 0, false) == T.BLOCKED, "destino nao caminhavel bloqueia")
	_check(MovementRules.evaluate(0, 0, true, true) == T.BLOCKED, "agua bloqueia quem nao nada")

	var swimmer := MovementContext.new()
	swimmer.can_swim = true
	swimmer.max_step_up = 3
	_check(MovementRules.evaluate(0, 0, true, true, swimmer) == T.SWIM, "contexto permite nadar")
	_check(MovementRules.evaluate(0, 3, true, false, swimmer) == T.STEP_UP, "contexto permite +3")


func _test_biome_scoring() -> void:
	print("\n[Biomas] pontuacao e transicao")
	_check(is_equal_approx(BiomeResolver.range_score(0.5, 0.4, 0.6, 0.1), 1.0), "dentro da faixa = 1")
	_check(is_equal_approx(BiomeResolver.range_score(0.35, 0.4, 0.6, 0.1), 0.5), "meia transicao = 0.5")
	_check(is_equal_approx(BiomeResolver.range_score(0.2, 0.4, 0.6, 0.1), 0.0), "fora da transicao = 0")

	var resolver: BiomeResolver = load("res://data/world/biome_resolver.tres")
	_check(resolver.biomes.size() == 5, "um bioma para cada pasta de bioma da arte")
	var reachable: Dictionary = {}
	for ti in 21:
		for hi in 21:
			for ci in [0.15, 0.36, 0.6, 0.95]:
				var sample := ClimateSample.new()
				sample.temperature = ti / 20.0
				sample.humidity = hi / 20.0
				sample.continentalness = ci
				var resolution := resolver.resolve(sample)
				if resolution.primary != null:
					reachable[resolution.primary.id] = true
	_check(reachable.size() == resolver.biomes.size(), "todos os biomas sao alcancaveis",
		str(reachable.keys()))


func _test_terrain_adapter() -> void:
	print("\n[TerrainAdapter] mistura de altura")
	_check(is_equal_approx(TerrainAdapter.blend_height(10.0, 4.0, 0.0, 5.0), 4.0), "no footprint vira alvo")
	_check(is_equal_approx(TerrainAdapter.blend_height(10.0, 4.0, 5.0, 5.0), 10.0), "no fim da margem mantem")
	var mid := TerrainAdapter.blend_height(10.0, 4.0, 2.5, 5.0)
	_check(mid > 4.0 and mid < 10.0, "no meio interpola", str(mid))
	var rect := Rect2i(Vector2i(4, 4), Vector2i(4, 4))
	_check(is_equal_approx(TerrainAdapter.distance_to_rect(Vector2i(5, 5), rect), 0.0), "dentro = 0")
	_check(is_equal_approx(TerrainAdapter.distance_to_rect(Vector2i(9, 5), rect), 2.0), "2 celulas fora")


func _build_generator(settings: WorldSettings, world_seed: int) -> WorldGenerator:
	var source: WorldGenerator = load("res://data/world/world_generator.tres")
	var generator := source.clone()
	generator.prepare(settings, world_seed)
	return generator


func _test_determinism() -> void:
	print("\n[Determinismo] mesma semente = mesmo chunk")
	var settings := _settings()
	var a := _build_generator(settings, 12345)
	var b := _build_generator(settings, 12345)
	var c := _build_generator(settings, 999)

	var chunk_a := a.generate_chunk(Vector2i(-3, 2))
	var chunk_b := b.generate_chunk(Vector2i(-3, 2))
	var chunk_c := c.generate_chunk(Vector2i(-3, 2))

	var identical := true
	var different := false
	for i in chunk_a.cells.size():
		if chunk_a.cells[i].height != chunk_b.cells[i].height:
			identical = false
		if chunk_a.cells[i].biome_id != chunk_b.cells[i].biome_id:
			identical = false
		if chunk_a.cells[i].height != chunk_c.cells[i].height:
			different = true
	_check(identical, "mesma semente reproduz o chunk")
	_check(different, "semente diferente muda o mundo")

	var again := a.generate_chunk(Vector2i(-3, 2))
	var stable := true
	for i in chunk_a.cells.size():
		if again.cells[i].height != chunk_a.cells[i].height:
			stable = false
	_check(stable, "regerar o mesmo chunk repete o resultado")


func _test_no_seams_between_chunks() -> void:
	print("\n[Chunks] continuidade nas bordas")
	var settings := _settings()
	var generator := _build_generator(settings, 4242)
	var left := generator.generate_chunk(Vector2i(0, 0))
	var right := generator.generate_chunk(Vector2i(1, 0))
	var below := generator.generate_chunk(Vector2i(0, 1))

	var max_step := 0
	for y in settings.chunk_size:
		var a := left.get_cell(Vector2i(settings.chunk_size - 1, y))
		var b := right.get_cell(Vector2i(0, y))
		max_step = maxi(max_step, absi(a.height - b.height))
	for x in settings.chunk_size:
		var a := left.get_cell(Vector2i(x, settings.chunk_size - 1))
		var b := below.get_cell(Vector2i(x, 0))
		max_step = maxi(max_step, absi(a.height - b.height))
	# Um degrau grande na costura significaria ruido em coordenada local.
	_check(max_step <= 3, "sem costura de ruido entre chunks", "degrau maximo %d" % max_step)

	var biome_ok := true
	for y in settings.chunk_size:
		var a := left.get_cell(Vector2i(settings.chunk_size - 1, y))
		var b := right.get_cell(Vector2i(0, y))
		if a.biome_id != b.biome_id and a.biome_blend < 0.2 and b.biome_blend < 0.2:
			biome_ok = false
	_check(biome_ok, "biomas nao seguem a borda do chunk")


func _test_generation_pipeline() -> void:
	print("\n[Pipeline] conteudo gerado")
	var settings := _settings()
	var generator := _build_generator(settings, 777)
	var filled := 0
	var heights: Dictionary = {}
	var biomes: Dictionary = {}
	var decorations := 0
	var liquid := 0
	var terrains: Dictionary = {}
	var grounds: Dictionary = {}

	for cy in range(-2, 3):
		for cx in range(-2, 3):
			var chunk := generator.generate_chunk(Vector2i(cx, cy))
			decorations += chunk.decorations.size()
			for cell in chunk.cells:
				if cell == null:
					continue
				filled += 1
				heights[cell.height] = true
				biomes[cell.biome_id] = true
				terrains[cell.terrain_id] = true
				grounds[cell.ground_id] = true
				if cell.is_liquid():
					liquid += 1
				if cell.height < settings.min_height or cell.height > settings.max_height:
					_failed += 1

	_check(filled == 25 * settings.chunk_size * settings.chunk_size, "todas as celulas preenchidas")
	_check(heights.size() >= 5, "relevo variado", "%d alturas" % heights.size())
	_check(biomes.size() >= 2, "mais de um bioma na amostra", str(biomes.keys()))
	_check(terrains.size() >= 2, "mais de um tipo de relevo", str(terrains.keys()))
	_check(decorations > 0, "vegetacao gerada", "%d decoracoes" % decorations)
	_check(grounds.size() >= 4, "variantes de grama aparecem no mundo", str(grounds.keys()))
	print("     (agua em %d celulas, alturas %s)" % [liquid, str(heights.keys().size())])


func _test_structure_planner_is_region_stable() -> void:
	print("\n[Estruturas] planejamento por regiao")
	var settings := _settings()
	var planner: StructurePlanner = load("res://data/world/structure_planner.tres").duplicate(true)
	planner.sampler = planner.sampler.duplicate(true)
	planner.sampler.prepare(settings, 2026)
	planner.clear_cache()

	var first := planner.plan_region(Vector2i(0, 0), settings, 2026)
	planner.clear_cache()
	var second := planner.plan_region(Vector2i(0, 0), settings, 2026)
	var same := first.size() == second.size()
	if same:
		for i in first.size():
			if first[i].origin_xy != second[i].origin_xy:
				same = false
			if first[i].foundation_height != second[i].foundation_height:
				same = false
	_check(same, "regiao replaneja identica")

	# Uma estrutura na borda deve aparecer no plano dos dois chunks vizinhos,
	# mas ser instanciada apenas uma vez.
	var generator := _build_generator(settings, 2026)
	var instantiated: Dictionary = {}
	var duplicated := false
	for cy in range(-3, 4):
		for cx in range(-3, 4):
			var chunk := generator.generate_chunk(Vector2i(cx, cy))
			for placement in chunk.structures:
				if instantiated.has(placement.origin_xy):
					duplicated = true
				instantiated[placement.origin_xy] = true
	_check(not duplicated, "estrutura nunca instanciada duas vezes")
	print("     (%d estruturas em 7x7 chunks)" % instantiated.size())

	# O terreno deve estar plano sob o footprint.
	var flat_ok := true
	var checked := 0
	for cy in range(-3, 4):
		for cx in range(-3, 4):
			var chunk := generator.generate_chunk(Vector2i(cx, cy))
			for placement in chunk.structures:
				checked += 1
				for y in placement.definition.footprint.y:
					for x in placement.definition.footprint.x:
						var cell := chunk.get_cell_world(placement.origin_xy + Vector2i(x, y))
						if cell != null and cell.height != placement.foundation_height:
							flat_ok = false
	_check(flat_ok, "terreno adaptado ao footprint", "%d estruturas verificadas" % checked)


func _test_navigation() -> void:
	print("\n[Navegacao] A* usa as MovementRules")
	var settings := _settings()
	var sampler: WorldSampler = load("res://data/world/world_sampler.tres").duplicate(true)
	sampler.prepare(settings, 555)
	var generator := _build_generator(settings, 555)
	var world := WorldData.new(settings, sampler)
	for cy in range(-1, 2):
		for cx in range(-1, 2):
			world.add_chunk(generator.generate_chunk(Vector2i(cx, cy)))

	var navigation := WorldNavigation.new(world, load("res://data/world/player_movement_context.tres"))
	var start := Vector2i.ZERO
	# Procura um ponto de partida caminhável.
	for radius in 12:
		var found := false
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if world.is_walkable(Vector2i(x, y)):
					start = Vector2i(x, y)
					found = true
					break
			if found:
				break
		if found:
			break

	var reachable := navigation.neighbors(start)
	_check(reachable.size() > 0, "celula inicial tem vizinhos caminhaveis")

	var goal := start
	var path: Array[Vector3i] = []
	for attempt in 24:
		var candidate := start + Vector2i(attempt - 12, 6)
		if not world.is_walkable(candidate):
			continue
		path = navigation.find_path(start, candidate)
		if path.size() > 1:
			goal = candidate
			break
	_check(path.size() > 1, "encontrou um caminho", "de %s ate %s" % [start, goal])

	var legal := true
	for i in range(1, path.size()):
		var from := Vector2i(path[i - 1].x, path[i - 1].y)
		var to := Vector2i(path[i].x, path[i].y)
		if not MovementRules.allows_movement(MovementRules.evaluate_world(world, from, to, null)):
			legal = false
		if absi(path[i].z - path[i - 1].z) > 1:
			legal = false
	_check(legal, "todo passo do caminho respeita as regras")


func _test_save_patches() -> void:
	print("\n[Save] semente + diferencas")
	var settings := _settings()
	var generator := _build_generator(settings, 31337)
	var chunk := generator.generate_chunk(Vector2i(0, 0))
	var target := chunk.get_cell(Vector2i(3, 3))
	var original_height := target.height

	var manager := WorldSaveManager.new()
	manager.save_path = "user://__test_world_save.json"
	manager.set_seed(31337)
	var patch := CellPatch.new()
	patch.world_pos = Vector3i(3, 3, 0)
	patch.height_override = original_height + 5
	patch.ground_override = &"pedra"
	manager.patch_cell(patch)
	if not chunk.decorations.is_empty():
		manager.remove_object(chunk.decorations[0].object_id)
	var decorations_before := chunk.decorations.size()
	_check(manager.save() == OK, "gravou o save")

	var reloaded := WorldSaveManager.new()
	reloaded.save_path = "user://__test_world_save.json"
	_check(reloaded.load_seed(0) == 31337, "semente persistiu")

	var regenerated := generator.generate_chunk(Vector2i(0, 0))
	reloaded.apply_patches(regenerated)
	var patched := regenerated.get_cell(Vector2i(3, 3))
	_check(patched.height == original_height + 5, "altura alterada persistiu")
	_check(patched.ground_id == &"pedra", "chao alterado persistiu")
	if decorations_before > 0:
		_check(
			regenerated.decorations.size() == decorations_before - 1,
			"objeto removido nao volta"
		)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://__test_world_save.json"))
	manager.free()
	reloaded.free()


## Trava de regressão dos PATAMARES.
##
## Um degrau de uma célula solta no meio do campo não vira penhasco: vira um
## risco de terra na grama, e é isso que faz o mundo parecer recortado. O filtro
## de mediana existe para que isso não aconteça — e precisa continuar sendo
## função pura da coordenada (sem costura entre chunks).
func _test_plateau_filter() -> void:
	print("\n[Patamares] relevo sem degraus de uma célula")
	var settings := _settings()
	var sampler: WorldSampler = load("res://data/world/world_sampler.tres")
	sampler = sampler.clone_for_thread()
	sampler.prepare(settings, 4242)
	_check(sampler.plateau_filter_enabled, "filtro de patamares ligado por padrao")

	var spikes_raw := 0
	var spikes_filtered := 0
	for y in range(-24, 25):
		for x in range(-24, 25):
			var cell := Vector2i(x, y)
			sampler.plateau_filter_enabled = false
			if _is_isolated(sampler, cell):
				spikes_raw += 1
			sampler.plateau_filter_enabled = true
			if _is_isolated(sampler, cell):
				spikes_filtered += 1
	_check(spikes_raw > 0, "o ruido cru realmente produz degraus soltos",
		"%d celulas" % spikes_raw)
	_check(spikes_filtered == 0, "nenhum degrau de uma celula sobrevive ao filtro",
		"%d celulas" % spikes_filtered)

	# Pureza: o mesmo ponto tem de dar o mesmo valor vindo de qualquer ordem de
	# consulta, senão a borda de um chunk não bate com a do vizinho.
	var other: WorldSampler = load("res://data/world/world_sampler.tres")
	other = other.clone_for_thread()
	other.prepare(settings, 4242)
	var equal := true
	for y in range(-3, 4):
		for x in range(-3, 4):
			var cell := Vector2i(x * 7, y * 7)
			if other.base_height(cell) != sampler.base_height(cell):
				equal = false
	_check(equal, "filtro e deterministico entre amostradores independentes")


## Verdadeiro quando a célula é um pico/cova de UMA célula só.
func _is_isolated(sampler: WorldSampler, cell: Vector2i) -> bool:
	var height := sampler.base_height(cell)
	var higher := 0
	var lower := 0
	for offset: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]:
		var neighbor := sampler.base_height(cell + offset)
		if neighbor > height:
			higher += 1
		elif neighbor < height:
			lower += 1
	return higher == 4 or lower == 4


## Trava de regressão da ÂNCORA DE OBJETO.
##
## Objeto do mundo é ordenado pela célula, não pela posição visual. Se a âncora
## voltar a somar a altura na própria posição, a mobília passa a ser desenhada
## atrás da grama que deveria estar atrás dela.
func _test_world_object_anchor() -> void:
	print("\n[Âncora] mobília assentada na grade")
	var settings := _settings()
	var iso := IsoCoordinateSystem.from_settings(settings)
	var anchor := WorldObjectAnchor.new()
	var child := Node2D.new()
	anchor.add_child(child)
	anchor.derive_cell_from_position = false
	anchor.follow_terrain = false
	anchor.world_cell = Vector2i(5, 9)
	anchor.height_level = 4
	anchor.snap_to_world(null, settings)

	var flat := iso.cell_to_local(Vector2i(5, 9)) + Vector2(0.0, iso.prop_sort_bias())
	_check(anchor.position.is_equal_approx(flat),
		"ancora carrega a posicao PLANA da celula",
		"%s vs %s" % [anchor.position, flat])
	_check(
		anchor.position.y + child.position.y
		== iso.cell_to_local(Vector2i(5, 9)).y - float(4 * settings.height_pixels),
		"o filho recebe apenas o deslocamento de altura",
		"%s" % child.position
	)
	_check(anchor.level() == 4, "altura fixa respeitada quando nao segue o relevo")
	anchor.free()


## Trava de regressão da VEGETAÇÃO ANIMADA.
##
## As árvores vieram com 48 quadros de queda de folha. Se alguém trocar a cena
## por um Sprite2D estático, ou o SpriteFrames perder o loop, a floresta congela
## sem ninguém perceber até rodar o jogo.
func _test_vegetation_animation() -> void:
	print("\n[Vegetação] árvores animadas")
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/world/vegetation/arvores_atlas.json")
	)
	var animation := StringName(manifest.get("animation", "queda"))
	var first_tree: Dictionary = manifest.get("trees", [{}])[0]
	var expected := int(first_tree.get("frames", 0))
	_check(expected > 1, "manifesto das arvores encontrado", "%d quadros" % expected)

	var animated := 0
	var looping := 0
	var scenes_ok := true
	for tree: Dictionary in manifest.get("trees", []):
		var path := "res://presentation/world/vegetation/arvore_%s.tscn" % tree["id"]
		var scene: PackedScene = load(path)
		if scene == null:
			scenes_ok = false
			continue
		var instance: Node = scene.instantiate()
		var sprite := instance.get_node_or_null(^"Sprite") as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null:
			scenes_ok = false
			instance.free()
			continue
		if sprite.sprite_frames.get_frame_count(animation) == int(tree["frames"]):
			animated += 1
		if sprite.sprite_frames.get_animation_loop(animation):
			looping += 1
		# A âncora do desenho não pode mudar: o tronco fica no (0, 0) da célula.
		if sprite.centered or sprite.offset != Vector2(-64.0, -198.0):
			scenes_ok = false
		instance.free()

	var tree_list: Array = manifest.get("trees", [])
	var total := tree_list.size()
	_check(scenes_ok, "toda arvore e um AnimatedSprite2D ancorado no tronco")
	_check(animated == total, "todas as arvores tem os %d quadros da arte" % expected,
		"%d de %d" % [animated, total])
	_check(looping == total, "a animacao das arvores repete em loop",
		"%d de %d" % [looping, total])

	# A DESSINCRONIZAÇÃO depende de `_ready`, então é conferida no teste de
	# integração (`player_grid_integration_test.gd`), com a SceneTree rodando.


## Trava de regressão da REGRA que já quebrou duas vezes.
##
## Uma face vertical pertence à borda FRONTAL da sua célula, e a superfície da
## célula seguinte está meio tile à frente dela. Logo a superfície tem de ser
## desenhada DEPOIS — é isso que impede a lasca de terra de furar a grama.
##
## O teste calcula a chave de Y-Sort como o Godot calcula (posição da célula
## somada ao `y_sort_origin` do tile) e confere a ordem em todas as vizinhanças
## que importam. Não depende de render nem de driver gráfico.
func _test_front_surface_covers_rear_face() -> void:
	print("\n[Profundidade] superfície da frente cobre a face de trás")
	var settings := _settings()
	var catalog: TileCatalog = load("res://data/world/tiles/ground_catalog.tres")
	var iso := IsoCoordinateSystem.from_settings(settings)
	var entry := catalog.find(&"campo_baixo")
	var ground_source := catalog.tile_set.get_source(
		TileCatalog.GROUND_SOURCE_ID
	) as TileSetAtlasSource
	var face_source := catalog.tile_set.get_source(
		TileCatalog.DEPTH_FACE_SOURCE_ID
	) as TileSetAtlasSource
	var level := 4
	var alternative := catalog.alternative_for(level)
	var surface_pivot := ground_source.get_tile_data(
		entry.atlas_coords, alternative
	).y_sort_origin
	var face_pivot := face_source.get_tile_data(
		catalog.face_atlas_coords(entry, TileCatalog.FaceMask.BOTH), alternative
	).y_sort_origin

	var rear := Vector2i(6, 9)
	var rear_face_key := iso.cell_to_local(rear).y + float(face_pivot)
	var ordered := true
	var worst := ""
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var front_key := iso.cell_to_local(rear + offset).y + float(surface_pivot)
		if front_key <= rear_face_key:
			ordered = false
			worst = "%s: frente %.1f <= face %.1f" % [offset, front_key, rear_face_key]
	_check(ordered, "superficie do vizinho da frente vence a face de tras", worst)

	# E, dentro da MESMA célula, a face vence a própria superfície: ela está na
	# borda frontal do losango, mais perto da câmera que o miolo.
	var own_surface_key := iso.cell_to_local(rear).y + float(surface_pivot)
	_check(rear_face_key > own_surface_key,
		"a face vence a superficie da propria celula",
		"face %.1f vs superficie %.1f" % [rear_face_key, own_surface_key])

	# O ator apoiado na célula precisa caber entre as duas.
	var actor_key := iso.cell_to_local(rear).y + iso.prop_sort_bias()
	_check(actor_key > own_surface_key,
		"o ator vence a superficie em que pisa", "%.1f vs %.1f" % [actor_key, own_surface_key])
	_check(actor_key < iso.cell_to_local(rear + Vector2i(1, 1)).y + float(surface_pivot),
		"o ator continua sendo coberto pela diagonal seguinte")

	# As duas fontes precisam existir no MESMO TileSet: classes separadas em Z
	# diferentes é justamente o que quebra tudo isso.
	_check(ground_source != null and face_source != null,
		"superficie e face saem do mesmo TileSet")


## Trava de regressão da CINTILAÇÃO DAS PERNAS.
##
## A chave de um tile de superfície é o CENTRO do losango, não a borda da
## frente. Como o ator é interpolado linearmente entre duas células, a troca de
## profundidade só cai na fronteira das duas se o viés dele for um quarto do
## tile. Com um viés pequeno demais a troca escorrega para o fim do passo: o
## personagem atravessa o passo inteiro ATRÁS da grama de destino e reaparece de
## uma vez no último quadro — que é a cintilação relatada.
##
## O teste resolve `t` (a fração do passo em que a troca acontece) para os
## quatro sentidos e exige que caia no meio.
func _test_depth_swap_lands_on_cell_border() -> void:
	print("\n[Profundidade] a troca acontece na fronteira da célula")
	var settings := _settings()
	var iso := IsoCoordinateSystem.from_settings(settings)
	var bias := iso.prop_sort_bias()
	var origin := Vector2i(5, 8)
	var from_y := iso.cell_to_local(origin).y
	var worst := 0.0
	var detail := ""
	for direction: Vector2i in [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)
	]:
		var to_y := iso.cell_to_local(origin + direction).y
		var travel := to_y - from_y
		if is_zero_approx(travel):
			continue
		# chave do ator em t:  from_y + travel * t + bias
		# chave do tile alvo:  to_y  (superfície tem y_sort_origin 0)
		# quando o ator ANDA PARA TRÁS o alvo é a célula que ele deixa.
		var target := to_y if travel > 0.0 else from_y
		var swap_t := (target - bias - from_y) / travel
		var error := absf(swap_t - 0.5)
		if error > worst:
			worst = error
			detail = "%s troca em t=%.3f" % [direction, swap_t]
	_check(worst < 0.02, "a troca de profundidade cai no meio do passo", detail)
	_check(is_equal_approx(bias, float(settings.tile_size.y) * 0.25),
		"o vies do ator e um quarto do tile", "%.2f" % bias)

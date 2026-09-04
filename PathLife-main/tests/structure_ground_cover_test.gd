## Garante que o chão do mundo nunca seja desenhado por cima do piso de uma
## construção.
##
## [b]Por que este teste existe[/b]: a arte de chão tem 128x106 px para um
## losango de 128x64. A sobra de cima são as folhas — elas transbordam a célula
## de propósito, para a grama ter volume. Entre células de grama isso é
## invisível. Sob uma casa não: a célula da FRENTE é desenhada depois da de
## trás, então as folhas caem sobre o PISO e a sala aparece com mato entre as
## tábuas. Trocar grama por terra nua reduz o problema, mas não o elimina: a
## própria arte da terra também tem alguns pixels fora do losango. A regra que
## resolve de vez é de DADO — a construção marca a superfície como oculta onde
## pinta piso próprio — e é ela que este teste protege.
##
## O teste vai até o fim da corrente: gera chunks de verdade, acha as estruturas
## que nasceram neles e confere que toda célula de piso está trancada e oculta
## para o renderizador.
##
## Uso: godot --headless --path . --script res://tests/structure_ground_cover_test.gd
extends SceneTree

const ATLAS_MANIFEST := "res://assets/world/tiles/ground_atlas.json"
const CATALOG_PATH := "res://data/world/tiles/ground_catalog.tres"
const SETTINGS_PATH := "res://data/world/world_settings.tres"
const GENERATOR_PATH := "res://data/world/world_generator.tres"
const CASA_PATH := "res://data/world/structures/casa_madeira.tres"
## Quantos chunks varrer procurando estruturas no mundo gerado.
const SCAN_RADIUS := 2

var _failures := 0
var _catalog: TileCatalog
var _ground_image: Image
var _region: Vector2i = Vector2i(128, 106)
var _diamond_top: int = 16
var _frames: int = 3
var _overflow_cache: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_load_art()
	_test_terrain_adapter()
	_test_definitions()
	_test_art_overflow()
	_test_generated_world()
	_finish()


# ------------------------------------------------------- regra, em isolamento
## Monta um chunk de laboratório: tudo grama, sem depender de ruído nem semente.
func _fake_context(chunk_size: int) -> GenerationContext:
	var settings := WorldSettings.new()
	settings.chunk_size = chunk_size
	var context := GenerationContext.new()
	context.settings = settings
	context.chunk_coord = Vector2i.ZERO
	context.chunk_data = ChunkData.new(Vector2i.ZERO, chunk_size)
	for y in chunk_size:
		for x in chunk_size:
			context.chunk_data.set_cell(Vector2i(x, y), _grass_cell(Vector2i(x, y)))
	return context


func _grass_cell(world_xy: Vector2i) -> WorldCell:
	var cell := WorldCell.new(world_xy, 0)
	cell.biome_id = &"campo"
	cell.ground_id = &"campo_alto"
	cell.wall_id = &"campo_terra"
	return cell


func _definition(footprint: Vector2i, margin: int, clears: bool) -> StructureDefinition:
	var definition := StructureDefinition.new()
	definition.id = &"laboratorio"
	definition.footprint = footprint
	definition.adaptation_margin = 2
	definition.adaptation_mode = StructureDefinition.TerrainAdaptationMode.FLATTEN
	definition.clears_ground_cover = clears
	definition.bare_ground_margin = margin
	return definition


func _apply(definition: StructureDefinition, chunk_size: int = 12) -> GenerationContext:
	var context := _fake_context(chunk_size)
	var placement := StructurePlacement.new(definition, Vector2i(2, 2))
	placement.foundation_height = 0
	var placements: Array[StructurePlacement] = [placement]
	TerrainAdapter.apply(context, placements)
	return context


func _test_terrain_adapter() -> void:
	print("\n[Regra] chão nu sob o footprint")
	var context := _apply(_definition(Vector2i(4, 4), 0, true))
	# Footprint = (2,2)..(5,5).
	_check(context.cell(Vector2i(2, 2)).ground_id == &"campo_terra", "canto do footprint vira terra")
	_check(context.cell(Vector2i(5, 5)).ground_id == &"campo_terra", "canto oposto vira terra")
	_check(context.cell(Vector2i(3, 4)).ground_locked, "célula do footprint fica trancada")
	_check(
		not context.cell(Vector2i(3, 4)).ground_surface_hidden,
		"footprint sem piso desenhado conserva a superfície"
	)
	_check(context.cell(Vector2i(6, 5)).ground_id == &"campo_alto", "vizinha continua com grama")
	_check(not context.cell(Vector2i(6, 5)).ground_locked, "vizinha não fica trancada")

	print("\n[Regra] margem opcional")
	var with_margin := _apply(_definition(Vector2i(4, 4), 1, true))
	_check(with_margin.cell(Vector2i(6, 5)).ground_id == &"campo_terra", "margem 1 limpa o anel")
	_check(with_margin.cell(Vector2i(7, 5)).ground_id == &"campo_alto", "margem 1 para no anel")

	print("\n[Regra] desligada")
	var disabled := _apply(_definition(Vector2i(4, 4), 0, false))
	_check(disabled.cell(Vector2i(3, 3)).ground_id == &"campo_alto", "sem limpeza a grama fica")
	_check(not disabled.cell(Vector2i(3, 3)).ground_locked, "sem limpeza não tranca")
	_check(disabled.cell(Vector2i(3, 3)).terrain_locked, "altura continua sendo assentada")

	print("\n[Regra] bioma sem terra própria")
	var context_without_bare := _fake_context(8)
	for y in 8:
		for x in 8:
			context_without_bare.cell(Vector2i(x, y)).wall_id = &""
	var placement := StructurePlacement.new(_definition(Vector2i(2, 2), 0, true), Vector2i(1, 1))
	var placements: Array[StructurePlacement] = [placement]
	TerrainAdapter.apply(context_without_bare, placements)
	_check(
		context_without_bare.cell(Vector2i(1, 1)).ground_id == &"campo_alto",
		"sem terra no bioma, mantém o chão em vez de apagar a arte"
	)

	print("\n[Regra] terreno intocado ainda limpa o chão")
	var untouched := _definition(Vector2i(3, 3), 0, true)
	untouched.adaptation_mode = StructureDefinition.TerrainAdaptationMode.NONE
	var no_adapt := _apply(untouched)
	_check(no_adapt.cell(Vector2i(3, 3)).ground_id == &"campo_terra", "adaptação NONE limpa o chão")
	_check(not no_adapt.cell(Vector2i(3, 3)).terrain_locked, "adaptação NONE não mexe na altura")

	print("\n[Regra] casa atravessando a fronteira de dois chunks")
	var wide := _definition(Vector2i(7, 8), 0, true)
	var straddling := StructurePlacement.new(wide, Vector2i(14, 6))
	straddling.foundation_height = 0
	var straddling_list: Array[StructurePlacement] = [straddling]
	var cleared := 0
	for chunk_coord: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		_check(
			straddling.overlaps_chunk(chunk_coord, 16),
			"o chunk %s recebe a estrutura" % chunk_coord
		)
		var chunk_context := _fake_context(16)
		chunk_context.chunk_coord = chunk_coord
		chunk_context.chunk_data = ChunkData.new(chunk_coord, 16)
		var chunk_origin := chunk_coord * 16
		for y in 16:
			for x in 16:
				chunk_context.chunk_data.set_cell(
					Vector2i(x, y), _grass_cell(chunk_origin + Vector2i(x, y))
				)
		TerrainAdapter.apply(chunk_context, straddling_list)
		for y in 16:
			for x in 16:
				if chunk_context.chunk_data.get_cell(Vector2i(x, y)).ground_id == &"campo_terra":
					cleared += 1
	_check(cleared == 7 * 8, "as duas metades do footprint ficam limpas", "%d células" % cleared)

	print("\n[Regra] a tranca sobrevive à cópia da célula")
	var locked := WorldCell.new(Vector2i.ZERO, 0)
	locked.ground_id = &"campo_terra"
	locked.ground_locked = true
	_check(locked.duplicate_cell().ground_locked, "a cópia da célula preserva a tranca")


# --------------------------------------------------------- dados do projeto
func _test_definitions() -> void:
	print("\n[Dados] estruturas do jogo")
	var casa := load(CASA_PATH) as StructureDefinition
	_check(casa != null, "casa_madeira.tres carrega")
	if casa == null:
		return
	_check(casa.clears_ground_cover, "a casa assenta chão nu")

	print("\n[Cena] o piso desenhado é quem manda")
	var floor_cells := StructureFloorMask.cells_for(casa)
	_check(not floor_cells.is_empty(), "a cena da casa tem piso", "%d células" % floor_cells.size())
	# Cada célula que a CENA pinta de piso precisa perder a grama. É esta a
	# armadilha que o teste existe para pegar: pintar uma sala a mais na cena e
	# esquecer de subir o `footprint` deixava aquelas células com grama.
	var placement := StructurePlacement.new(casa, Vector2i(37, -19))
	var uncovered := 0
	for local: Vector2i in floor_cells:
		if not TerrainAdapter.clears_cell(placement, placement.origin_xy + local):
			uncovered += 1
	_check(uncovered == 0, "toda célula de piso da cena perde a grama", "%d de fora" % uncovered)
	var scene_context := _fake_context(16)
	var local_placement := StructurePlacement.new(casa, Vector2i(2, 2))
	var local_placements: Array[StructurePlacement] = [local_placement]
	TerrainAdapter.apply(scene_context, local_placements)
	var visible_world_surfaces := 0
	for local: Vector2i in floor_cells:
		if not scene_context.cell(Vector2i(2, 2) + local).ground_surface_hidden:
			visible_world_surfaces += 1
	_check(
		visible_world_surfaces == 0,
		"todo piso da casa marca a superfície do mundo como oculta",
		"%d superfícies ainda visíveis" % visible_world_surfaces
	)
	_test_hidden_surface_rendering(scene_context, floor_cells, Vector2i(2, 2))
	var expected := casa.footprint.x * casa.footprint.y
	_check(
		floor_cells.size() == expected,
		"piso da cena e footprint declarado batem",
		"%d pintadas, %d declaradas" % [floor_cells.size(), expected]
	)


func _test_hidden_surface_rendering(
	context: GenerationContext,
	floor_cells: Dictionary,
	placement_origin: Vector2i
) -> void:
	var packed_view := load("res://world_generation/rendering/chunk_view.tscn") as PackedScene
	var settings := load(SETTINGS_PATH) as WorldSettings
	var catalog := load(CATALOG_PATH) as TileCatalog
	_check(
		packed_view != null and settings != null and catalog != null,
		"recursos do renderizador carregam"
	)
	if packed_view == null or settings == null or catalog == null:
		return
	var view := packed_view.instantiate() as ChunkView
	root.add_child(view)
	view.build(context.chunk_data, settings, catalog)
	var ground_layer := view.layer_at(0)
	var painted_under_floor := 0
	for local: Vector2i in floor_cells:
		var world_xy := placement_origin + local
		if ground_layer != null and ground_layer.get_cell_source_id(world_xy) != -1:
			painted_under_floor += 1
	_check(
		painted_under_floor == 0,
		"renderizador não pinta chão sob o piso da casa",
		"%d tiles indevidos" % painted_under_floor
	)
	_check(
		ground_layer != null and ground_layer.get_cell_source_id(Vector2i.ZERO) != -1,
		"o terreno fora da casa continua visível"
	)
	view.free()


# --------------------------------------------------------------------- arte
func _load_art() -> void:
	_catalog = load(CATALOG_PATH) as TileCatalog
	if _catalog == null or _catalog.tile_set == null:
		return
	var source := _catalog.tile_set.get_source(TileCatalog.GROUND_SOURCE_ID) as TileSetAtlasSource
	if source == null or source.texture == null:
		return
	_ground_image = source.texture.get_image()
	_region = source.texture_region_size
	_frames = maxi(1, _ground_image.get_width() / _region.x)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_MANIFEST))
	if manifest is Dictionary:
		var tile_info: Dictionary = (manifest as Dictionary).get("tile", {})
		_diamond_top = int(tile_info.get("diamond_top", 16))


## Quantos pixels da arte deste chão ficam ACIMA do losango da célula.
##
## Todo pixel contado aqui é desenhado FORA da própria célula, sobre o que
## estiver atrás dela — inclusive o piso de uma construção.
func _overflow_pixels(ground_id: StringName) -> int:
	if _overflow_cache.has(ground_id):
		return _overflow_cache[ground_id]
	var count := -1
	var entry := _catalog.find(ground_id) if _catalog != null else null
	if entry != null and _ground_image != null:
		count = 0
		var origin_y := entry.atlas_coords.y * _region.y
		for frame in _frames:
			var origin_x := (entry.atlas_coords.x + frame) * _region.x
			for y in _diamond_top:
				for x in _region.x:
					if _ground_image.get_pixel(origin_x + x, origin_y + y).a > 0.0:
						count += 1
	_overflow_cache[ground_id] = count
	return count


## A regra é necessária porque a arte vegetal transborda. Terra nua também pode
## ter alguns pixels fora do losango, por isso ela não substitui a ocultação da
## superfície sob o piso.
func _test_art_overflow() -> void:
	print("\n[Arte] transbordo acima do losango")
	if _catalog == null or _ground_image == null:
		_check(false, "catálogo e atlas de chão carregam")
		return
	_check(_overflow_pixels(&"campo_alto") > 0, "a grama transborda o losango",
		"%d px" % _overflow_pixels(&"campo_alto"))
	_check(_overflow_pixels(&"musgo") > 0, "o musgo também transborda",
		"%d px" % _overflow_pixels(&"musgo"))


# ------------------------------------------------------------ mundo gerado
## Fecha o ciclo: gera chunks de verdade e confere as casas que nasceram neles.
func _test_generated_world() -> void:
	print("\n[Mundo] estruturas geradas de verdade")
	var settings := load(SETTINGS_PATH) as WorldSettings
	var generator := load(GENERATOR_PATH) as WorldGenerator
	if settings == null or generator == null:
		_check(false, "recursos do mundo carregam")
		return
	generator.prepare(settings, settings.resolved_seed())

	var inspected := 0
	for chunk_y in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
		for chunk_x in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
			var chunk := generator.generate_chunk(Vector2i(chunk_x, chunk_y))
			for placement: StructurePlacement in chunk.structures:
				if placement.definition == null or not placement.definition.clears_ground_cover:
					continue
				inspected += 1
				_check_placement(chunk, placement)
	if inspected == 0:
		print("  nota  nenhuma estrutura nos %d chunks varridos" % int(pow(SCAN_RADIUS * 2 + 1, 2)))
	else:
		print("  nota  %d estrutura(s) conferida(s)" % inspected)


func _check_placement(chunk: ChunkData, placement: StructurePlacement) -> void:
	var unlocked := 0
	var checked := 0
	var visible_floor_surfaces := 0
	for world_xy: Vector2i in _covered_cells(placement):
		var cell := chunk.get_cell_world(world_xy)
		if cell == null:
			continue  # a estrutura atravessa a borda deste chunk
		checked += 1
		if not cell.ground_locked:
			unlocked += 1
	_check(
		unlocked == 0,
		"chão de %s assentado e trancado" % placement.definition.id,
		"%d células, %d destrancadas" % [checked, unlocked]
	)
	for local: Vector2i in StructureFloorMask.cells_for(placement.definition):
		var cell := chunk.get_cell_world(placement.origin_xy + local)
		if cell != null and not cell.ground_surface_hidden:
			visible_floor_surfaces += 1
	_check(
		visible_floor_surfaces == 0,
		"superfície oculta sob o piso de %s" % placement.definition.id,
		"%d células de piso ainda visíveis" % visible_floor_surfaces
	)


## Footprint + piso desenhado pela cena, em coordenadas do mundo.
func _covered_cells(placement: StructurePlacement) -> Array[Vector2i]:
	var cells: Dictionary = {}
	var rect := placement.rect()
	for y in rect.size.y:
		for x in rect.size.x:
			cells[rect.position + Vector2i(x, y)] = true
	for local: Vector2i in StructureFloorMask.cells_for(placement.definition):
		cells[placement.origin_xy + local] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell)
	return result


# ------------------------------------------------------------------ relatório
func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		_failures += 1
		printerr("  FALHA %s %s" % [label, detail])


func _finish() -> void:
	if _failures == 0:
		print("\nSTRUCTURE GROUND COVER TEST: OK")
		quit(0)
	else:
		printerr("\nSTRUCTURE GROUND COVER TEST: %d falha(s)" % _failures)
		quit(1)

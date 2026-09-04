## Gera os atlas, o TileSet isométrico e a cena-base da casa de madeira.
##
## Uso em duas etapas (os PNGs precisam ser importados entre elas):
##   godot --headless --path . --script res://tools/build_structure_tileset.gd -- --atlases
##   godot --headless --editor --path . --import
##   godot --headless --path . --script res://tools/build_structure_tileset.gd -- --resources
##   godot --headless --path . --script res://tools/build_structure_tileset.gd -- --install-sample-doors
##   godot --headless --path . --script res://tools/build_structure_tileset.gd -- --install-sample-windows
##   godot --headless --path . --script res://tools/build_structure_tileset.gd -- --install-house-roof
extends SceneTree

const ART_ROOT := "res://assets/world/structures/casa_madeira"
const ATLAS_ROOT := ART_ROOT + "/atlases"
const FLOOR_ATLAS_PATH := ATLAS_ROOT + "/casa_madeira_pisos_atlas.png"
const ROOF_ATLAS_PATH := ATLAS_ROOT + "/casa_madeira_telhados_atlas.png"
const COMPLETE_ROOF_SOURCE_PATH := ART_ROOT + "/telhados/referencias/telhado_colonial_piramide_demo.png"
const COMPLETE_ROOF_PATH := ATLAS_ROOT + "/casa_madeira_telhado_colonial_completo.png"
const TILESET_PATH := "res://data/world/structures/casa_madeira_tileset.tres"
const TILESET_UID := "uid://2moaq6ru4dj0"
const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"

const TILE_SIZE := Vector2i(128, 64)
const FLOOR_REGION_SIZE := Vector2i(128, 76)
const WALL_REGION_SIZE := Vector2i(128, 158)
const ROOF_REGION_SIZE := Vector2i(160, 112)

const FLOOR_SOURCE_ID := 0
const WALL_SOURCE_BASE_ID := 10
const DOOR_SOURCE_BASE_ID := 20
const WINDOW_SOURCE_BASE_ID := 24
const ROOF_SOURCE_ID := 30
const COMPLETE_ROOF_SOURCE_ID := 31
const FURNITURE_SOURCE_ID := 40
const PLAYER_SPAWN_SOURCE_ID := 41
const PLAYER_SPAWN_SCENE := "res://presentation/world/markers/player_spawn_marker.tscn"
const STARTER_FOOTPRINT := Vector2i(7, 8)
const SAMPLE_DOOR_CELL := Vector2i(1, 8)
const SAMPLE_PLAYER_SPAWN_CELL := Vector2i(1, 9)
const SAMPLE_DOORS: Array[Dictionary] = [
	{"cell": Vector2i(1, 8), "environment": "sala", "part": "porta_ne_fechada"},
	{"cell": Vector2i(1, 4), "environment": "sala", "part": "porta_ne_fechada"},
	{"cell": Vector2i(4, 4), "environment": "cozinha", "part": "porta_nw_fechada"},
	{"cell": Vector2i(4, 6), "environment": "sala", "part": "porta_nw_fechada"},
]
const SAMPLE_WINDOWS: Array[Dictionary] = [
	{"cell": Vector2i(2, 0), "environment": "lazer", "part": "janela_ne"},
	{"cell": Vector2i(0, 2), "environment": "lazer", "part": "janela_nw"},
	{"cell": Vector2i(5, 0), "environment": "cozinha", "part": "janela_ne"},
	{"cell": Vector2i(7, 2), "environment": "cozinha", "part": "janela_nw"},
	{"cell": Vector2i(3, 8), "environment": "sala", "part": "janela_ne"},
	{"cell": Vector2i(7, 6), "environment": "sala", "part": "janela_nw"},
]

const ENVIRONMENTS: Array[String] = ["banheiro", "cozinha", "lazer", "sala"]
## Uma entrada por orientação de cada móvel, na ordem em que devem virar scene
## tiles. Móvel novo = quatro cenas novas aqui.
const FURNITURE_SCENES: Array[String] = [
	"res://gameplay/furniture/pieces/cama_r0.tscn",
	"res://gameplay/furniture/pieces/cama_r1.tscn",
	"res://gameplay/furniture/pieces/cama_r2.tscn",
	"res://gameplay/furniture/pieces/cama_r3.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r0.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r1.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r2.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r3.tscn",
	"res://gameplay/furniture/pieces/espelho_r0.tscn",
	"res://gameplay/furniture/pieces/espelho_r1.tscn",
	"res://gameplay/furniture/pieces/espelho_r2.tscn",
	"res://gameplay/furniture/pieces/espelho_r3.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r0.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r1.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r2.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r3.tscn",
	"res://gameplay/furniture/pieces/bancada_r0.tscn",
	"res://gameplay/furniture/pieces/bancada_r1.tscn",
	"res://gameplay/furniture/pieces/bancada_r2.tscn",
	"res://gameplay/furniture/pieces/bancada_r3.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r0.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r1.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r2.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r3.tscn",
	"res://gameplay/furniture/pieces/fogao_r0.tscn",
	"res://gameplay/furniture/pieces/fogao_r1.tscn",
	"res://gameplay/furniture/pieces/fogao_r2.tscn",
	"res://gameplay/furniture/pieces/fogao_r3.tscn",
	"res://gameplay/furniture/pieces/geladeira_r0.tscn",
	"res://gameplay/furniture/pieces/geladeira_r1.tscn",
	"res://gameplay/furniture/pieces/geladeira_r2.tscn",
	"res://gameplay/furniture/pieces/geladeira_r3.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r0.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r1.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r2.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r3.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r0.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r1.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r2.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r3.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r0.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r1.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r2.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r3.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r0.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r1.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r2.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r3.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r0.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r1.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r2.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r3.tscn",
	"res://gameplay/furniture/pieces/armario_r0.tscn",
	"res://gameplay/furniture/pieces/armario_r1.tscn",
	"res://gameplay/furniture/pieces/armario_r2.tscn",
	"res://gameplay/furniture/pieces/armario_r3.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r0.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r1.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r2.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r3.tscn",
	"res://gameplay/furniture/pieces/quadro_r0.tscn",
	"res://gameplay/furniture/pieces/quadro_r1.tscn",
	"res://gameplay/furniture/pieces/quadro_r2.tscn",
	"res://gameplay/furniture/pieces/quadro_r3.tscn",
]
const ROOF_STYLES: Array[String] = ["colonial", "palha", "shingle"]
const ROOF_PARTS: Array[String] = [
	"agua_ne_beira", "agua_ne_meio", "agua_nw_beira", "agua_nw_meio",
	"agua_se_beira", "agua_se_meio", "agua_sw_beira", "agua_sw_meio",
	"cume_ne_sw_beira", "cume_ne_sw_meio", "cume_nw_se_beira", "cume_nw_se_meio",
	"espigao_e_beira", "espigao_e_meio", "espigao_n_beira", "espigao_n_meio",
	"espigao_s_beira", "espigao_s_meio", "espigao_w_beira", "espigao_w_meio",
	"piramide_beira", "piramide_meio",
	"ponta_ne_beira", "ponta_ne_meio", "ponta_nw_beira", "ponta_nw_meio",
	"ponta_se_beira", "ponta_se_meio", "ponta_sw_beira", "ponta_sw_meio",
	"rincao_e_meio", "rincao_n_meio", "rincao_s_meio", "rincao_w_meio",
]
const FLOOR_VARIANTS: Array[String] = ["bloco", "topo"]
const WALL_STATES: Array[String] = ["baixa", "cheia", "fantasma"]
const WALL_PARTS: Array[String] = [
	"ne", "nw", "se", "sw", "quina_n", "quina_e", "quina_s", "quina_w", "canto"
]
const DOOR_PARTS: Array[String] = [
	"porta_ne_aberta", "porta_ne_fechada", "porta_ne_vao",
	"porta_nw_aberta", "porta_nw_fechada", "porta_nw_vao",
	"porta_se_aberta", "porta_se_fechada", "porta_se_vao",
	"porta_sw_aberta", "porta_sw_fechada", "porta_sw_vao",
	"montante_n", "montante_e", "montante_s", "montante_w",
	"porta_ne_anim00", "porta_ne_anim01", "porta_ne_anim02",
	"porta_ne_anim03", "porta_ne_anim04", "porta_ne_anim05",
	"porta_ne_anim06", "porta_ne_anim07", "porta_ne_anim08",
	"porta_nw_anim00", "porta_nw_anim01", "porta_nw_anim02",
	"porta_nw_anim03", "porta_nw_anim04", "porta_nw_anim05",
	"porta_nw_anim06", "porta_nw_anim07", "porta_nw_anim08",
	"porta_se_anim00", "porta_se_anim01", "porta_se_anim02",
	"porta_se_anim03", "porta_se_anim04", "porta_se_anim05",
	"porta_se_anim06", "porta_se_anim07", "porta_se_anim08",
	"porta_sw_anim00", "porta_sw_anim01", "porta_sw_anim02",
	"porta_sw_anim03", "porta_sw_anim04", "porta_sw_anim05",
	"porta_sw_anim06", "porta_sw_anim07", "porta_sw_anim08",
]
const WINDOW_BASE_PARTS: Array[String] = [
	"janela_ne", "janela_nw", "janela_se", "janela_sw",
	"janela_vazada_ne", "janela_vazada_nw", "janela_vazada_se", "janela_vazada_sw",
]
const WINDOW_FRAME_COUNT := 5


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var mode := arguments[0] if not arguments.is_empty() else "--resources"
	var succeeded := false
	match mode:
		"--atlases":
			succeeded = _build_atlases()
		"--resources":
			succeeded = _build_resources(false)
		"--resources-force-scene":
			succeeded = _build_resources(true)
		"--install-sample-door", "--install-sample-doors":
			succeeded = _install_sample_doors()
		"--install-sample-window", "--install-sample-windows":
			succeeded = _install_sample_windows()
		"--install-house-roof":
			succeeded = _install_house_roof()
		_:
			push_error("Modo desconhecido: %s" % mode)
	if succeeded:
		print("[StructureTileSetBuilder] Concluído: %s" % mode)
	quit(0 if succeeded else 1)


func _build_atlases() -> bool:
	var absolute_atlas_root := ProjectSettings.globalize_path(ATLAS_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_atlas_root)
	if directory_error != OK:
		push_error("Não foi possível criar %s: erro %d" % [ATLAS_ROOT, directory_error])
		return false
	if not _build_floor_atlas():
		return false
	if not _build_roof_atlas():
		return false
	if not _build_complete_roof_texture():
		return false
	for environment: String in ENVIRONMENTS:
		if not _build_wall_atlas(environment):
			return false
		if not _build_door_atlas(environment):
			return false
		if not _build_window_atlas(environment):
			return false
	return true


func _build_roof_atlas() -> bool:
	var atlas := Image.create_empty(
		ROOF_REGION_SIZE.x * ROOF_PARTS.size(),
		ROOF_REGION_SIZE.y * ROOF_STYLES.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for style_index in ROOF_STYLES.size():
		var style := ROOF_STYLES[style_index]
		for part_index in ROOF_PARTS.size():
			var part := ROOF_PARTS[part_index]
			var path := "%s/telhados/%s/%s_%s.png" % [ART_ROOT, style, style, part]
			var tile := _load_source_image(path)
			if tile == null:
				return false
			if tile.get_size() != ROOF_REGION_SIZE:
				push_error("Dimensão inesperada em %s: %s" % [path, tile.get_size()])
				return false
			atlas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile.get_size()),
				Vector2i(part_index * ROOF_REGION_SIZE.x, style_index * ROOF_REGION_SIZE.y)
			)
	var error := atlas.save_png(ProjectSettings.globalize_path(ROOF_ATLAS_PATH))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [ROOF_ATLAS_PATH, error])
		return false
	print("[StructureTileSetBuilder] Atlas de telhados: %s" % ROOF_ATLAS_PATH)
	return true


func _build_complete_roof_texture() -> bool:
	var source := _load_source_image(COMPLETE_ROOF_SOURCE_PATH)
	if source == null:
		return false
	var background := source.get_pixel(0, 0)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			if color.r == background.r and color.g == background.g and color.b == background.b:
				color.a = 0.0
				source.set_pixel(x, y, color)
	var used_rect := source.get_used_rect()
	if not used_rect.has_area():
		push_error("A referência do telhado completo ficou vazia.")
		return false
	var roof := source.get_region(used_rect)
	if roof.get_size() != Vector2i(1056, 536):
		push_error("Dimensão inesperada no telhado completo: %s" % roof.get_size())
		return false
	var error := roof.save_png(ProjectSettings.globalize_path(COMPLETE_ROOF_PATH))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [COMPLETE_ROOF_PATH, error])
		return false
	print("[StructureTileSetBuilder] Telhado colonial completo: %s" % COMPLETE_ROOF_PATH)
	return true


func _build_floor_atlas() -> bool:
	var atlas := Image.create_empty(
		FLOOR_REGION_SIZE.x * ENVIRONMENTS.size(),
		FLOOR_REGION_SIZE.y * FLOOR_VARIANTS.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for environment_index in ENVIRONMENTS.size():
		var environment := ENVIRONMENTS[environment_index]
		for variant_index in FLOOR_VARIANTS.size():
			var variant := FLOOR_VARIANTS[variant_index]
			var path := "%s/pisos/%s/%s_%s.png" % [
				ART_ROOT, environment, environment, variant
			]
			var tile := _load_source_image(path)
			if tile == null:
				return false
			var expected := Vector2i(128, 76) if variant == "bloco" else Vector2i(128, 64)
			if tile.get_size() != expected:
				push_error("Dimensão inesperada em %s: %s (esperado %s)" % [
					path, tile.get_size(), expected
				])
				return false
			atlas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile.get_size()),
				Vector2i(environment_index * FLOOR_REGION_SIZE.x, variant_index * FLOOR_REGION_SIZE.y)
			)
	var error := atlas.save_png(ProjectSettings.globalize_path(FLOOR_ATLAS_PATH))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [FLOOR_ATLAS_PATH, error])
		return false
	print("[StructureTileSetBuilder] Atlas de pisos: %s" % FLOOR_ATLAS_PATH)
	return true


func _wall_atlas_path(environment: String) -> String:
	return ATLAS_ROOT + "/casa_madeira_paredes_%s_alpha_atlas.png" % environment


func _build_wall_atlas(environment: String) -> bool:
	var atlas := Image.create_empty(
		WALL_REGION_SIZE.x * WALL_PARTS.size(),
		WALL_REGION_SIZE.y * WALL_STATES.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for state_index in WALL_STATES.size():
		var state := WALL_STATES[state_index]
		for part_index in WALL_PARTS.size():
			var part := WALL_PARTS[part_index]
			var file_name := (
				"%s_canto.png" % environment
				if part == "canto"
				else "%s_%s_%s.png" % [environment, part, state]
			)
			var path := "%s/paredes/%s/%s" % [ART_ROOT, environment, file_name]
			var tile: Image
			if state == "fantasma":
				# Os PNGs fantasma usam dithering xadrez de 1 px. No TileMapLayer
				# esse padrão muda de fase durante o movimento e parece piscar. Alpha
				# uniforme mantém a mesma cobertura visual sem cintilação.
				var full_file := (
					"%s_canto.png" % environment
					if part == "canto"
					else "%s_%s_cheia.png" % [environment, part]
				)
				var full_path := "%s/paredes/%s/%s" % [
					ART_ROOT, environment, full_file
				]
				tile = _with_uniform_alpha(_load_source_image(full_path), 0.5)
			elif part == "canto" and state == "baixa":
				tile = _compose_corner(environment, state)
			else:
				tile = _load_source_image(path)
			if tile == null:
				return false
			if tile.get_size() != WALL_REGION_SIZE:
				push_error("Dimensão inesperada em %s: %s" % [path, tile.get_size()])
				return false
			atlas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile.get_size()),
				Vector2i(part_index * WALL_REGION_SIZE.x, state_index * WALL_REGION_SIZE.y)
			)
	var output_path := _wall_atlas_path(environment)
	var error := atlas.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [output_path, error])
		return false
	print("[StructureTileSetBuilder] Atlas de paredes: %s" % output_path)
	return true


func _door_atlas_path(environment: String) -> String:
	return ATLAS_ROOT + "/casa_madeira_portas_%s_alpha_atlas.png" % environment


func _window_atlas_path(environment: String) -> String:
	return ATLAS_ROOT + "/casa_madeira_janelas_%s_alpha_atlas.png" % environment


func _build_window_atlas(environment: String) -> bool:
	var window_parts := _window_parts()
	var atlas := Image.create_empty(
		WALL_REGION_SIZE.x * window_parts.size(),
		WALL_REGION_SIZE.y * WALL_STATES.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for state_index in WALL_STATES.size():
		var state := WALL_STATES[state_index]
		for part_index in window_parts.size():
			var part := window_parts[part_index]
			var path := _window_source_path(environment, part, state)
			var tile: Image
			if state == "fantasma":
				var full_path := _window_source_path(environment, part, "cheia")
				tile = _with_uniform_alpha(_load_source_image(full_path), 0.5)
			else:
				tile = _load_source_image(path)
			if tile == null:
				return false
			if tile.get_size() != WALL_REGION_SIZE:
				push_error("Dimensão inesperada em %s: %s" % [path, tile.get_size()])
				return false
			atlas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile.get_size()),
				Vector2i(part_index * WALL_REGION_SIZE.x, state_index * WALL_REGION_SIZE.y)
			)
	var output_path := _window_atlas_path(environment)
	var error := atlas.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [output_path, error])
		return false
	print("[StructureTileSetBuilder] Atlas de janelas: %s" % output_path)
	return true


func _build_door_atlas(environment: String) -> bool:
	var atlas := Image.create_empty(
		WALL_REGION_SIZE.x * DOOR_PARTS.size(),
		WALL_REGION_SIZE.y * WALL_STATES.size(),
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for state_index in WALL_STATES.size():
		var state := WALL_STATES[state_index]
		for part_index in DOOR_PARTS.size():
			var part := DOOR_PARTS[part_index]
			# A arte antiga de `aberta` era somente o vão. O pacote novo traz
			# `abertaporta`, que mantém a folha visível no quadro final da animação.
			var source_part := part.replace("_aberta", "_abertaporta")
			var file_name := "%s_%s_%s.png" % [environment, source_part, state]
			var path := "%s/portas/%s/%s" % [ART_ROOT, environment, file_name]
			var tile: Image
			if state == "fantasma":
				# Assim como as paredes, as portas fantasma originais usam um
				# xadrez de 1 px que cintila quando a câmera se move.
				var full_path := "%s/portas/%s/%s_%s_cheia.png" % [
					ART_ROOT, environment, environment, source_part
				]
				tile = _with_uniform_alpha(_load_source_image(full_path), 0.5)
			else:
				tile = _load_source_image(path)
			if tile == null:
				return false
			if tile.get_size() != WALL_REGION_SIZE:
				push_error("Dimensão inesperada em %s: %s" % [path, tile.get_size()])
				return false
			atlas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile.get_size()),
				Vector2i(part_index * WALL_REGION_SIZE.x, state_index * WALL_REGION_SIZE.y)
			)
	var output_path := _door_atlas_path(environment)
	var error := atlas.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Falha ao salvar %s: erro %d" % [output_path, error])
		return false
	print("[StructureTileSetBuilder] Atlas de portas: %s" % output_path)
	return true


func _compose_corner(environment: String, state: String) -> Image:
	var result := Image.create_empty(
		WALL_REGION_SIZE.x, WALL_REGION_SIZE.y, false, Image.FORMAT_RGBA8
	)
	result.fill(Color.TRANSPARENT)
	for part: String in ["ne", "nw"]:
		var path := "%s/paredes/%s/%s_%s_%s.png" % [
			ART_ROOT, environment, environment, part, state
		]
		var side := _load_source_image(path)
		if side == null:
			return null
		result.blend_rect(side, Rect2i(Vector2i.ZERO, side.get_size()), Vector2i.ZERO)
	return result


func _with_uniform_alpha(source: Image, alpha: float) -> Image:
	if source == null:
		return null
	var result := source.duplicate()
	for y in result.get_height():
		for x in result.get_width():
			var color: Color = result.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			color.a *= alpha
			result.set_pixel(x, y, color)
	return result


func _load_source_image(path: String) -> Image:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Não foi possível ler %s: erro %d" % [path, error])
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _build_resources(force_scene: bool) -> bool:
	var floor_texture := load(FLOOR_ATLAS_PATH) as Texture2D
	var roof_texture := load(ROOF_ATLAS_PATH) as Texture2D
	var complete_roof_texture := load(COMPLETE_ROOF_PATH) as Texture2D
	var wall_textures: Array[Texture2D] = []
	var door_textures: Array[Texture2D] = []
	var window_textures: Array[Texture2D] = []
	for environment: String in ENVIRONMENTS:
		var wall_texture := load(_wall_atlas_path(environment)) as Texture2D
		if wall_texture != null:
			wall_textures.append(wall_texture)
		var door_texture := load(_door_atlas_path(environment)) as Texture2D
		if door_texture != null:
			door_textures.append(door_texture)
		var window_texture := load(_window_atlas_path(environment)) as Texture2D
		if window_texture != null:
			window_textures.append(window_texture)
	if (
		floor_texture == null
		or roof_texture == null
		or complete_roof_texture == null
		or wall_textures.size() != ENVIRONMENTS.size()
		or door_textures.size() != ENVIRONMENTS.size()
		or window_textures.size() != ENVIRONMENTS.size()
	):
		push_error(
			"Os atlas ainda não foram importados. Rode --atlases, depois o import do editor, "
			+ "e por fim --resources."
		)
		return false

	var tile_set := TileSet.new()
	tile_set.resource_name = "CasaMadeiraTileSet"
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = TILE_SIZE
	tile_set.uv_clipping = false
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1) # World
	tile_set.set_physics_layer_collision_mask(0, 2) # Player
	_add_custom_data_layers(tile_set)

	var floor_source := _create_floor_source(tile_set, floor_texture)
	if floor_source == null:
		return false
	var roof_source := _create_roof_source(tile_set, roof_texture)
	if roof_source == null:
		return false
	var complete_roof_source := _create_complete_roof_source(tile_set, complete_roof_texture)
	if complete_roof_source == null:
		return false
	var furniture_source := _create_furniture_source(tile_set)
	if furniture_source == null:
		return false
	var player_spawn_source := _create_player_spawn_source(tile_set)
	if player_spawn_source == null:
		return false
	for environment_index in ENVIRONMENTS.size():
		var wall_source := _create_wall_source(
			tile_set, wall_textures[environment_index], environment_index
		)
		if wall_source == null:
			return false
		var door_source := _create_door_source(
			tile_set, door_textures[environment_index], environment_index
		)
		if door_source == null:
			return false
		var window_source := _create_window_source(
			tile_set, window_textures[environment_index], environment_index
		)
		if window_source == null:
			return false

	var save_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if save_error != OK:
		push_error("Falha ao salvar %s: erro %d" % [TILESET_PATH, save_error])
		return false
	# A cena autorada referencia este UID estável. ResourceSaver gera o arquivo
	# sem UID ao recriar um Resource novo, então ele precisa ser restaurado.
	ResourceSaver.set_uid(TILESET_PATH, ResourceUID.text_to_id(TILESET_UID))
	print("[StructureTileSetBuilder] TileSet: %s" % TILESET_PATH)

	var saved_tile_set := load(TILESET_PATH) as TileSet
	if saved_tile_set == null:
		push_error("Não foi possível recarregar %s" % TILESET_PATH)
		return false
	if FileAccess.file_exists(SCENE_PATH) and not force_scene:
		print(
			"[StructureTileSetBuilder] Cena existente preservada: %s " % SCENE_PATH
			+ "(use --resources-force-scene para recriá-la)"
		)
		return true
	return _build_editor_scene(saved_tile_set)


func _add_custom_data_layers(tile_set: TileSet) -> void:
	var layers := [
		"categoria", "ambiente", "peca", "estado", "direcao",
		"estado_porta", "estado_janela",
	]
	for layer_name: String in layers:
		tile_set.add_custom_data_layer()
		var index := tile_set.get_custom_data_layers_count() - 1
		tile_set.set_custom_data_layer_name(index, layer_name)
		tile_set.set_custom_data_layer_type(index, TYPE_STRING)


func _create_floor_source(tile_set: TileSet, texture: Texture2D) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.resource_name = "Pisos_Banheiro_Cozinha_Lazer_Sala"
	source.texture = texture
	source.texture_region_size = FLOOR_REGION_SIZE
	source.use_texture_padding = true
	# TileData só conhece camadas físicas/customizadas depois que sua fonte
	# pertence ao TileSet.
	tile_set.add_source(source, FLOOR_SOURCE_ID)
	for environment_index in ENVIRONMENTS.size():
		for variant_index in FLOOR_VARIANTS.size():
			var coords := Vector2i(environment_index, variant_index)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			# A região tem 76 px de altura. -6 desloca o losango 6 px para baixo
			# e reproduz o offset Sprite2D (-64, -32) usado pelo deck antigo.
			data.texture_origin = Vector2i(0, -6)
			data.y_sort_origin = 0
			data.set_custom_data("categoria", "piso")
			data.set_custom_data("ambiente", ENVIRONMENTS[environment_index])
			data.set_custom_data("peca", FLOOR_VARIANTS[variant_index])
			data.set_custom_data("estado", "")
	return source


func _create_roof_source(tile_set: TileSet, texture: Texture2D) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.resource_name = "Telhados_Colonial_Palha_Shingle"
	source.texture = texture
	source.texture_region_size = ROOF_REGION_SIZE
	source.use_texture_padding = false
	tile_set.add_source(source, ROOF_SOURCE_ID)
	for style_index in ROOF_STYLES.size():
		for part_index in ROOF_PARTS.size():
			var coords := Vector2i(part_index, style_index)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			# Os PNGs reservam 32 px acima do losango. Subir 96 px coloca o
			# plano do telhado no topo das paredes de madeira.
			data.texture_origin = Vector2i(0, 96)
			data.set_custom_data("categoria", "telhado")
			data.set_custom_data("ambiente", ROOF_STYLES[style_index])
			data.set_custom_data("peca", ROOF_PARTS[part_index])
			data.set_custom_data("estado", "")
	return source


func _create_complete_roof_source(
	tile_set: TileSet, texture: Texture2D
) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.resource_name = "Telhado_Colonial_Completo"
	source.texture = texture
	source.texture_region_size = Vector2i(texture.get_size())
	source.use_texture_padding = false
	tile_set.add_source(source, COMPLETE_ROOF_SOURCE_ID)
	source.create_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	# Pintado na célula central (3,3): estes offsets centralizam o beiral no
	# footprint 7x8 e elevam o conjunto até o topo das paredes.
	data.texture_origin = Vector2i(32, 80)
	data.set_custom_data("categoria", "telhado")
	data.set_custom_data("ambiente", "colonial")
	data.set_custom_data("peca", "piramide_completa")
	data.set_custom_data("estado", "")
	return source


func _create_furniture_source(tile_set: TileSet) -> TileSetScenesCollectionSource:
	# Scene tiles em vez de sprites de atlas: pintar um tile instancia a cena
	# completa do móvel, com colisão, interação, âncoras e ordenação próprias.
	#
	# Móvel novo entra em FURNITURE_SCENES; nada mais muda aqui.
	var source := TileSetScenesCollectionSource.new()
	source.resource_name = "Mobilia"
	tile_set.add_source(source, FURNITURE_SOURCE_ID)
	for index in FURNITURE_SCENES.size():
		var piece_scene := load(FURNITURE_SCENES[index]) as PackedScene
		if piece_scene == null:
			push_error("Não foi possível carregar o móvel %s" % FURNITURE_SCENES[index])
			return null
		var scene_tile_id := source.create_scene_tile(piece_scene, index)
		if scene_tile_id < 0:
			push_error("Não foi possível registrar o móvel %s no TileSet." % FURNITURE_SCENES[index])
			return null
		# Mostra a arte real no editor e instancia a mesma cena durante o jogo.
		source.set_scene_tile_display_placeholder(scene_tile_id, false)
	return source


func _create_player_spawn_source(tile_set: TileSet) -> TileSetScenesCollectionSource:
	var marker_scene := load(PLAYER_SPAWN_SCENE) as PackedScene
	if marker_scene == null:
		push_error("Não foi possível carregar o marcador Spawn Player.")
		return null
	var source := TileSetScenesCollectionSource.new()
	source.resource_name = "Marcadores_Spawn_Player"
	tile_set.add_source(source, PLAYER_SPAWN_SOURCE_ID)
	var scene_tile_id := source.create_scene_tile(marker_scene, 0)
	if scene_tile_id < 0:
		push_error("Não foi possível registrar Spawn Player no TileSet.")
		return null
	source.set_scene_tile_display_placeholder(scene_tile_id, false)
	return source


func _create_wall_source(
	tile_set: TileSet, texture: Texture2D, environment_index: int
) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	var environment := ENVIRONMENTS[environment_index]
	source.resource_name = "Paredes_%s" % environment.capitalize()
	source.texture = texture
	source.texture_region_size = WALL_REGION_SIZE
	# Com filtro Nearest e margens transparentes o padding é desnecessário; além
	# disso, ele ativa o bug de transparência godotengine/godot#78743/#103803.
	source.use_texture_padding = false
	tile_set.add_source(source, WALL_SOURCE_BASE_ID + environment_index)
	for state_index in WALL_STATES.size():
		for part_index in WALL_PARTS.size():
			var part := WALL_PARTS[part_index]
			var state := WALL_STATES[state_index]
			var coords := Vector2i(part_index, state_index)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			# O TileMapLayer centraliza a região de 158 px. +46 move a arte
			# para cima e equivale ao offset Sprite2D (-64, -125).
			data.texture_origin = Vector2i(0, 46)
			data.y_sort_origin = 31 if _uses_front_edge(part) else 0
			data.set_custom_data("categoria", "parede")
			data.set_custom_data("ambiente", environment)
			data.set_custom_data("peca", part)
			data.set_custom_data("estado", state)
			_add_wall_collision(data, part)
	return source


func _create_door_source(
	tile_set: TileSet, texture: Texture2D, environment_index: int
) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	var environment := ENVIRONMENTS[environment_index]
	source.resource_name = "Portas_%s" % environment.capitalize()
	source.texture = texture
	source.texture_region_size = WALL_REGION_SIZE
	source.use_texture_padding = false
	tile_set.add_source(source, DOOR_SOURCE_BASE_ID + environment_index)
	for state_index in WALL_STATES.size():
		for part_index in DOOR_PARTS.size():
			var part := DOOR_PARTS[part_index]
			var state := WALL_STATES[state_index]
			var coords := Vector2i(part_index, state_index)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			data.texture_origin = Vector2i(0, 46)
			var direction := _door_part_direction(part)
			data.y_sort_origin = 31 if direction in ["se", "sw", "e", "s", "w"] else 0
			data.set_custom_data("categoria", "porta")
			data.set_custom_data("ambiente", environment)
			data.set_custom_data("peca", part)
			data.set_custom_data("estado", state)
			data.set_custom_data("direcao", direction)
			data.set_custom_data("estado_porta", _door_part_open_state(part))
			_add_door_collision(data, part)
	return source


func _create_window_source(
	tile_set: TileSet, texture: Texture2D, environment_index: int
) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	var environment := ENVIRONMENTS[environment_index]
	source.resource_name = "Janelas_%s" % environment.capitalize()
	source.texture = texture
	source.texture_region_size = WALL_REGION_SIZE
	source.use_texture_padding = false
	tile_set.add_source(source, WINDOW_SOURCE_BASE_ID + environment_index)
	var window_parts := _window_parts()
	for state_index in WALL_STATES.size():
		for part_index in window_parts.size():
			var part := window_parts[part_index]
			var base_part := _window_part_base(part)
			var state := WALL_STATES[state_index]
			var coords := Vector2i(part_index, state_index)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			var direction := _window_part_direction(base_part)
			data.texture_origin = Vector2i(0, 46)
			data.y_sort_origin = 31 if _uses_front_edge(direction) else 0
			data.set_custom_data("categoria", "janela")
			data.set_custom_data("ambiente", environment)
			data.set_custom_data("peca", base_part)
			data.set_custom_data("estado", state)
			data.set_custom_data("direcao", direction)
			data.set_custom_data("estado_janela", _window_part_open_state(part))
			_add_wall_collision(data, direction)
	return source


func _window_parts() -> Array[String]:
	# Mantém as oito colunas fechadas nas posições históricas para que cenas já
	# pintadas continuem válidas depois de regenerar o TileSet.
	var result: Array[String] = []
	result.append_array(WINDOW_BASE_PARTS)
	for part: String in WINDOW_BASE_PARTS:
		result.append(part + "_aberta")
	for part: String in WINDOW_BASE_PARTS:
		for frame_index in WINDOW_FRAME_COUNT:
			result.append("%s_abrindo_%02d" % [part, frame_index])
	return result


func _window_source_path(environment: String, part: String, state: String) -> String:
	var base_part := _window_part_base(part)
	var root := "%s/janelas/%s" % [ART_ROOT, environment]
	if part.ends_with("_aberta"):
		return "%s/aberta/%s_%s_%s_aberta.png" % [root, environment, base_part, state]
	if "_abrindo_" in part:
		var frame := part.get_slice("_abrindo_", 1)
		return "%s/abrindo/%s_%s_%s_abrindo_%s.png" % [
			root, environment, base_part, state, frame
		]
	return "%s/%s_%s_%s.png" % [root, environment, base_part, state]


func _window_part_base(part: String) -> String:
	if part.ends_with("_aberta"):
		return part.trim_suffix("_aberta")
	if "_abrindo_" in part:
		return part.get_slice("_abrindo_", 0)
	return part


func _window_part_open_state(part: String) -> String:
	if part.ends_with("_aberta"):
		return "aberta"
	if "_abrindo_" in part:
		return "anim" + part.get_slice("_abrindo_", 1)
	return "fechada"


func _window_part_direction(part: String) -> String:
	var segments := part.split("_")
	return segments[-1] if segments.size() >= 2 else ""


func _door_part_direction(part: String) -> String:
	var segments := part.split("_")
	return segments[1] if segments.size() >= 2 else ""


func _door_part_open_state(part: String) -> String:
	if not part.begins_with("porta_"):
		return "montante"
	var segments := part.split("_")
	return segments[2] if segments.size() >= 3 else ""


func _add_door_collision(data: TileData, part: String) -> void:
	if not part.begins_with("porta_"):
		return
	var direction := _door_part_direction(part)
	var open_state := _door_part_open_state(part)
	var animation_frame := int(open_state.trim_prefix("anim")) if open_state.begins_with("anim") else -1
	if open_state == "fechada" or animation_frame in range(0, 5):
		_add_wall_collision(data, direction)
		return
	var endpoints := _wall_edge_endpoints(direction)
	if endpoints.size() != 2:
		return
	var start := endpoints[0]
	var finish := endpoints[1]
	# Preserva colisão nos dois trechos de parede, mas deixa o centro do
	# batente livre para o Player atravessar portas abertas e vãos.
	_add_segment_collision(data, start, start.lerp(finish, 0.27))
	_add_segment_collision(data, start.lerp(finish, 0.66), finish)


func _wall_edge_endpoints(part: String) -> PackedVector2Array:
	var north := Vector2(0.0, -32.0)
	var east := Vector2(64.0, 0.0)
	var south := Vector2(0.0, 32.0)
	var west := Vector2(-64.0, 0.0)
	match part:
		"ne":
			return PackedVector2Array([north, east])
		"nw":
			return PackedVector2Array([north, west])
		"se":
			return PackedVector2Array([east, south])
		"sw":
			return PackedVector2Array([west, south])
	return PackedVector2Array()


func _uses_front_edge(part: String) -> bool:
	return part in ["se", "sw", "quina_e", "quina_s", "quina_w"]


func _add_wall_collision(data: TileData, part: String) -> void:
	var north := Vector2(0.0, -32.0)
	var east := Vector2(64.0, 0.0)
	var south := Vector2(0.0, 32.0)
	var west := Vector2(-64.0, 0.0)
	match part:
		"ne":
			_add_segment_collision(data, north, east)
		"nw":
			_add_segment_collision(data, north, west)
		"se":
			_add_segment_collision(data, east, south)
		"sw":
			_add_segment_collision(data, west, south)
		"canto", "quina_n":
			_add_segment_collision(data, north, east)
			_add_segment_collision(data, north, west)
		"quina_e":
			_add_segment_collision(data, north, east)
			_add_segment_collision(data, east, south)
		"quina_s":
			_add_segment_collision(data, east, south)
			_add_segment_collision(data, west, south)
		"quina_w":
			_add_segment_collision(data, north, west)
			_add_segment_collision(data, west, south)


func _add_segment_collision(data: TileData, start: Vector2, finish: Vector2) -> void:
	var direction := (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x) * 5.0
	var polygon := PackedVector2Array([
		start + normal,
		finish + normal,
		finish - normal,
		start - normal,
	])
	data.add_collision_polygon(0)
	var polygon_index := data.get_collision_polygons_count(0) - 1
	data.set_collision_polygon_points(0, polygon_index, polygon)


func _install_sample_doors() -> bool:
	var tile_set := load(TILESET_PATH) as TileSet
	var packed_scene := load(SCENE_PATH) as PackedScene
	if tile_set == null or packed_scene == null:
		push_error("TileSet ou cena-base ausente; gere os recursos antes de instalar a porta.")
		return false
	# Preserve subscene ownership while editing so inherited signals are not
	# serialized again into the house scene.
	var scene := packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var wall_layer := scene.get_node_or_null(^"Paredes") as TileMapLayer
	if wall_layer == null:
		push_error("A cena-base não possui a camada Paredes.")
		scene.free()
		return false
	wall_layer.tile_set = tile_set
	for door: Dictionary in SAMPLE_DOORS:
		var environment_index := ENVIRONMENTS.find(door["environment"] as String)
		var part_index := DOOR_PARTS.find(door["part"] as String)
		if environment_index < 0 or part_index < 0:
			push_error("Configuração inválida de porta: %s" % door)
			scene.free()
			return false
		wall_layer.set_cell(
			door["cell"] as Vector2i,
			DOOR_SOURCE_BASE_ID + environment_index,
			Vector2i(part_index, WALL_STATES.find("cheia")),
			0
		)
	var result := PackedScene.new()
	var pack_error := result.pack(scene)
	if pack_error != OK:
		push_error("Falha ao empacotar a cena com as portas: erro %d" % pack_error)
		scene.free()
		return false
	var save_error := ResourceSaver.save(result, SCENE_PATH)
	scene.free()
	if save_error != OK:
		push_error("Falha ao salvar as portas em %s: erro %d" % [SCENE_PATH, save_error])
		return false
	print("[StructureTileSetBuilder] %d portas fechadas instaladas" % SAMPLE_DOORS.size())
	return true


func _install_sample_windows() -> bool:
	var tile_set := load(TILESET_PATH) as TileSet
	var packed_scene := load(SCENE_PATH) as PackedScene
	if tile_set == null or packed_scene == null:
		push_error("TileSet ou cena-base ausente; gere os recursos antes de instalar as janelas.")
		return false
	var scene := packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var wall_layer := scene.get_node_or_null(^"Paredes") as TileMapLayer
	if wall_layer == null:
		push_error("A cena-base não possui a camada Paredes.")
		scene.free()
		return false
	wall_layer.tile_set = tile_set
	for window: Dictionary in SAMPLE_WINDOWS:
		var environment_index := ENVIRONMENTS.find(window["environment"] as String)
		var part_index := WINDOW_BASE_PARTS.find(window["part"] as String)
		if environment_index < 0 or part_index < 0:
			push_error("Configuração inválida de janela: %s" % window)
			scene.free()
			return false
		wall_layer.set_cell(
			window["cell"] as Vector2i,
			WINDOW_SOURCE_BASE_ID + environment_index,
			Vector2i(part_index, WALL_STATES.find("cheia")),
			0
		)
	var result := PackedScene.new()
	var pack_error := result.pack(scene)
	if pack_error != OK:
		push_error("Falha ao empacotar a cena com janelas: erro %d" % pack_error)
		scene.free()
		return false
	var save_error := ResourceSaver.save(result, SCENE_PATH)
	scene.free()
	if save_error != OK:
		push_error("Falha ao salvar as janelas em %s: erro %d" % [SCENE_PATH, save_error])
		return false
	print("[StructureTileSetBuilder] %d janelas instaladas" % SAMPLE_WINDOWS.size())
	return true


func _install_house_roof() -> bool:
	var tile_set := load(TILESET_PATH) as TileSet
	var packed_scene := load(SCENE_PATH) as PackedScene
	if tile_set == null or packed_scene == null:
		push_error("TileSet ou cena-base ausente; gere os recursos antes de instalar o telhado.")
		return false
	var scene := packed_scene.instantiate()
	var roof_layer := scene.get_node_or_null(^"Telhado") as TileMapLayer
	if roof_layer == null:
		push_error("A cena-base não possui a camada Telhado.")
		scene.free()
		return false
	roof_layer.tile_set = tile_set
	roof_layer.clear()
	roof_layer.set_cell(Vector2i(3, 3), COMPLETE_ROOF_SOURCE_ID, Vector2i.ZERO, 0)
	var result := PackedScene.new()
	var pack_error := result.pack(scene)
	if pack_error != OK:
		push_error("Falha ao empacotar a cena com telhado: erro %d" % pack_error)
		scene.free()
		return false
	var save_error := ResourceSaver.save(result, SCENE_PATH)
	scene.free()
	if save_error != OK:
		push_error("Falha ao salvar o telhado em %s: erro %d" % [SCENE_PATH, save_error])
		return false
	print("[StructureTileSetBuilder] Telhado colonial completo instalado")
	return true


func _build_editor_scene(tile_set: TileSet) -> bool:
	var root := Node2D.new()
	root.name = "CasaMadeiraTileMap"
	root.y_sort_enabled = true
	root.set_script(load("res://world_generation/structures/structure_root.gd"))
	root.set("footprint_preview", STARTER_FOOTPRINT)
	root.set("draw_footprint_gizmo", false)
	root.editor_description = (
		"Cena-base editável. Pinte piso, paredes, janelas e portas selecionando cada TileMapLayer."
	)

	var floor_layer := _new_layer("Piso", tile_set, false)
	root.add_child(floor_layer)
	floor_layer.owner = root
	floor_layer.editor_description = "Use a fonte Pisos do TileSet para pintar o chão."

	var wall_layer := _new_layer("Paredes", tile_set, true)
	root.add_child(wall_layer)
	wall_layer.owner = root
	wall_layer.editor_description = "Paredes, janelas e portas: a colisão já vem do TileSet."

	var overlay_layer := _new_layer("ParedesSemColisao", tile_set, false)
	root.add_child(overlay_layer)
	overlay_layer.owner = root
	overlay_layer.editor_description = (
		"Use para fantasmas, prévias ou paredes que não devem bloquear o Player."
	)

	var furniture_layer := _new_layer("Mobilia", tile_set, false)
	root.add_child(furniture_layer)
	furniture_layer.owner = root
	furniture_layer.editor_description = (
		"Pinte aqui os móveis da fonte Mobilia. Cada tile instancia a cena "
		+ "completa do móvel, com colisão, interação e ordenação próprias."
	)
	var spawn_layer := _new_layer("SpawnPlayer", tile_set, false)
	root.add_child(spawn_layer)
	spawn_layer.owner = root
	spawn_layer.z_index = 100
	spawn_layer.editor_description = (
		"Pinte uma célula da fonte Marcadores_Spawn_Player para definir onde o Player inicia."
	)

	var roof_layer := _new_layer("Telhado", tile_set, false)
	root.add_child(roof_layer)
	roof_layer.owner = root
	# Autorar piso, paredes e mobília com um telhado opaco por cima é inviável.
	# Em runtime StructureRoot o torna visível antes de o Player entrar na casa.
	roof_layer.visible = false
	roof_layer.z_index = 10
	roof_layer.editor_description = (
		"Pinte aqui com a fonte Telhados. Em jogo, cobre a casa por fora e some no interior."
	)

	_paint_starter_room(floor_layer, wall_layer, spawn_layer)
	_add_markers(root)

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("Falha ao empacotar a cena-base: erro %d" % pack_error)
		return false
	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		push_error("Falha ao salvar %s: erro %d" % [SCENE_PATH, save_error])
		root.free()
		return false
	print("[StructureTileSetBuilder] Cena-base: %s" % SCENE_PATH)
	root.free()
	return true


func _new_layer(layer_name: String, tile_set: TileSet, has_collision: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	# Diamond Down centraliza a célula (0, 0) em (64, 32). A estrutura já é
	# ancorada nesse centro pelo ChunkView, então removemos o meio tile local.
	layer.position = Vector2(-64.0, -32.0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.y_sort_enabled = true
	layer.y_sort_origin = 0
	layer.z_index = 0
	layer.collision_enabled = has_collision
	layer.navigation_enabled = false
	return layer


func _paint_starter_room(
	floor_layer: TileMapLayer, wall_layer: TileMapLayer, spawn_layer: TileMapLayer
) -> void:
	# Sala = coluna 3. Bloco = linha 0.
	var sala_floor := Vector2i(3, 0)
	for y in STARTER_FOOTPRINT.y:
		for x in STARTER_FOOTPRINT.x:
			floor_layer.set_cell(Vector2i(x, y), FLOOR_SOURCE_ID, sala_floor, 0)

	# Em cada fonte de parede: baixa=0, cheia=1 e fantasma=2.
	var sala_full_row := 1
	var sala_wall_source := WALL_SOURCE_BASE_ID + 3
	wall_layer.set_cell(Vector2i(0, 0), sala_wall_source, Vector2i(8, sala_full_row), 0)
	for x in range(1, STARTER_FOOTPRINT.x):
		wall_layer.set_cell(Vector2i(x, 0), sala_wall_source, Vector2i(0, sala_full_row), 0)
	for y in range(1, STARTER_FOOTPRINT.y):
		wall_layer.set_cell(Vector2i(0, y), sala_wall_source, Vector2i(1, sala_full_row), 0)
	# Porta fechada NE na entrada. Em jogo, E executa a animação de abertura.
	wall_layer.set_cell(
		SAMPLE_DOOR_CELL,
		DOOR_SOURCE_BASE_ID + 3,
		Vector2i(DOOR_PARTS.find("porta_ne_fechada"), sala_full_row),
		0
	)
	# Exemplo seguro: uma célula fora da porta fechada. O autor pode mover ou
	# apagar este tile livremente pela camada SpawnPlayer.
	spawn_layer.set_cell(
		SAMPLE_PLAYER_SPAWN_CELL, PLAYER_SPAWN_SOURCE_ID, Vector2i.ZERO, 0
	)


func _add_markers(root: Node2D) -> void:
	var marker_script := load("res://world_generation/structures/structure_marker.gd")
	var markers := Node2D.new()
	markers.name = "Marcadores"
	root.add_child(markers)
	markers.owner = root

	var entrance := Marker2D.new()
	entrance.name = "EntranceMarker"
	entrance.position = Vector2(-448.0, 288.0)
	entrance.set_script(marker_script)
	entrance.set("marker_type", 0)
	entrance.set("cell_offset", Vector2i(1, 8))
	markers.add_child(entrance)
	entrance.owner = root

	var road := Marker2D.new()
	road.name = "RoadMarker"
	road.position = Vector2(-448.0, 352.0)
	road.set_script(marker_script)
	road.set("marker_type", 1)
	road.set("cell_offset", Vector2i(2, 9))
	markers.add_child(road)
	road.owner = root

	var npc := Marker2D.new()
	npc.name = "NPCSpawnMarker"
	npc.position = Vector2(-256.0, 192.0)
	npc.set_script(marker_script)
	npc.set("marker_type", 2)
	npc.set("cell_offset", Vector2i(1, 5))
	markers.add_child(npc)
	npc.owner = root

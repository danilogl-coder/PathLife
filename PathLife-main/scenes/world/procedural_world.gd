## Raiz da cena do mundo procedural.
##
## Só faz fiação: liga o foco (jogador) ao [ChunkManager] e a altura do jogador
## ao [HeightVisibilityManager]. Nenhuma regra de jogo mora aqui.
class_name ProceduralWorld
extends Node2D

signal world_ready

@export_category("Referências externas")
## Quem define o centro de carregamento — normalmente o Player.
@export var focus: Node2D
## Podem apontar para raízes globais da cena principal. Se vazias, a cena usa
## suas raízes internas (útil no laboratório e em testes isolados).
@export var ground_root: Node2D
@export var depth_root: Node2D
@export var overlay_root: Node2D

@export_category("Comportamento")
## Gera os chunks ao redor do foco de forma síncrona antes do primeiro frame.
@export var preload_around_focus: bool = true
@export_range(0, 4, 1) var preload_radius: int = 1

@onready var chunk_container: Node = %ChunkContainer
@onready var fallback_ground_root: Node2D = %GroundRoot
@onready var fallback_depth_root: Node2D = %DepthSort
@onready var fallback_overlay_root: Node2D = %OverlayRoot
@onready var chunk_manager: ChunkManager = %ChunkManager
@onready var height_visibility: HeightVisibilityManager = %HeightVisibility
@onready var save_manager: WorldSaveManager = %SaveManager

var _agent: WorldGridAgent


func _ready() -> void:
	if ground_root == null:
		ground_root = fallback_ground_root
	if depth_root == null:
		depth_root = fallback_depth_root
	if overlay_root == null:
		overlay_root = fallback_overlay_root
	_normalize_sorting_space()
	chunk_manager.focus = focus
	chunk_manager.chunk_container = chunk_container
	chunk_manager.ground_root = ground_root
	chunk_manager.depth_root = depth_root
	chunk_manager.overlay_root = overlay_root
	chunk_manager.save_manager = save_manager
	chunk_manager.world_ready.connect(func() -> void: world_ready.emit())
	chunk_manager.chunk_integrated.connect(_on_chunk_integrated)

	if focus != null:
		_agent = focus.get_node_or_null(^"WorldGridAgent") as WorldGridAgent
		if _agent != null:
			_agent.height_changed.connect(_on_focus_height_changed)

	if preload_around_focus:
		chunk_manager.generate_around_now(chunk_manager.current_center_chunk(), preload_radius)
	# Objetos autorados na cena (mobília, marcos) só sabem em que célula estão
	# depois que o terreno existe. Assentar aqui evita que fiquem no nível 0,
	# afundados no relevo e ordenados como se estivessem lá atrás.
	snap_world_objects()


## Força Ground e Depth para o MESMO espaço de ordenação.
##
## No Godot o Z-Index é resolvido ANTES do Y-Sort. Se o piso e as faces ficarem
## em Z diferentes, eles param de disputar profundidade entre si: TODA face de
## terra passa a ser desenhada por cima de TODA superfície de grama, inclusive a
## da célula que está na frente dela — e o campo aparece recortado, com lascas de
## terra furando a grama.
##
## Isso já regrediu duas vezes, sempre por alguém dar um Z próprio ao piso na
## tentativa de proteger as pernas do personagem. Foi medido: com as duas classes
## no mesmo Z o ator fica com MAIS pixels visíveis, não menos (ver
## `tests/terrain_depth_composition_test.gd`). Por isso a normalização acontece
## aqui, em código, e não depende de ninguém lembrar de conferir a cena.
##
## `overlay_root` é a única exceção proposital: ele existe justamente para o que
## deve ficar incondicionalmente à frente.
func _normalize_sorting_space() -> void:
	for node: Node2D in [ground_root, depth_root]:
		if node == null:
			continue
		if node.z_index != 0:
			push_warning(
				"%s estava em z_index %d. Piso e faces precisam do MESMO Z, "
				% [node.name, node.z_index]
				+ "senão o terreno aparece recortado."
			)
			node.z_index = 0
		node.y_sort_enabled = true


## Assenta no relevo todo objeto marcado como [constant WorldObjectAnchor.GROUP].
func snap_world_objects() -> void:
	var settings := chunk_manager.settings
	if settings == null:
		return
	for node in get_tree().get_nodes_in_group(WorldObjectAnchor.GROUP):
		var anchor := node as WorldObjectAnchor
		if anchor != null:
			anchor.snap_to_world(world_data(), settings)


func world_data() -> WorldData:
	return chunk_manager.world


func navigation(context: MovementContext = null) -> WorldNavigation:
	return WorldNavigation.new(world_data(), context)


func _on_focus_height_changed(level: int) -> void:
	height_visibility.set_player_level(level)
	height_visibility.apply_to(chunk_manager.views())


## Chunk novo entra já com o sombreamento certo, sem piscar.
func _on_chunk_integrated(chunk_coord: Vector2i) -> void:
	var view := chunk_manager.view_for(chunk_coord)
	if view != null:
		height_visibility.apply_to([view])

## Dá a um [Node2D] uma posição LÓGICA Vector3i(x, y, z) no mundo.
##
## A posição visual (`position`) passa a ser apenas o resultado da projeção
## isométrica — nunca a fonte da verdade. Player, NPC e qualquer entidade usam
## este mesmo componente e, portanto, as mesmas [MovementRules].
class_name WorldGridAgent
extends Node

signal step_started(from_position: Vector3i, to_position: Vector3i, transition: int)
signal step_finished(world_position: Vector3i)
signal height_changed(level: int)
signal step_blocked(direction: Vector2i)

@export_category("Referências")
## Corpo que será movido. Vazio = o nó pai.
@export var body_path: NodePath
## Vazio = procura um [ChunkManager] no grupo "chunk_manager".
@export var chunk_manager_path: NodePath
## Âncora de ordenação: um [Node2D] pai do corpo, SEM Y-Sort.
##
## Ela recebe a posição PLANA da célula (é a chave do Y-Sort) enquanto o corpo
## recebe apenas o deslocamento vertical da altura. É isso que faz o terreno
## alto ATRÁS da entidade não desenhar por cima dela — e o terreno alto À FRENTE
## recortar as pernas dela, que é o que dá a leitura de "estou um nível abaixo".
##
## Se ficar vazio, o componente procura um pai [Node2D] no grupo
## [code]grid_sort_anchor[/code]. Sem âncora nenhuma, o corpo carrega a posição
## completa e a ordenação fica aproximada (o jeito antigo).
@export var sort_anchor_path: NodePath
## Nome do grupo usado na busca automática da âncora.
@export var sort_anchor_group: StringName = &"grid_sort_anchor"

@export_category("Movimento")
@export var movement_context: MovementContext
@export_range(0.5, 20.0, 0.1) var cells_per_second: float = 3.2
## Multiplicador aplicado ao correr.
@export_range(1.0, 4.0, 0.05) var run_multiplier: float = 1.7
## Multiplicador aplicado ao agachar.
@export_range(0.1, 1.0, 0.05) var crouch_multiplier: float = 0.55
## Consulta a física antes do passo (respeita móveis e paredes já existentes).
@export var respect_physics_obstacles: bool = true
## Móveis são obstáculos locais, não paredes entre células. A varredura do
## passo inteiro ignora estas camadas e testa o corpo somente no destino. Assim
## um móvel não bloqueia antecipadamente uma célula livre ao lado, mas continua
## impedindo que o Player termine o passo dentro de seu SolidCollision.
@export_flags_2d_physics var furniture_collision_mask: int = 8
## Legado: ajustava o z_index pela altura. Mantenha DESLIGADO — o mundo agora
## usa um único Y-Sort por profundidade e todo mundo fica em z_index 0.
@export var drive_z_index: bool = false

@export_category("Início")
@export var start_cell: Vector2i = Vector2i.ZERO

var _body: Node2D
var _anchor: Node2D
var _manager: ChunkManager
var _iso: IsoCoordinateSystem
var _cell: Vector2i = Vector2i.ZERO
var _height: int = 0
var _moving: bool = false
var _from_flat: Vector2 = Vector2.ZERO
var _to_flat: Vector2 = Vector2.ZERO
var _from_height: float = 0.0
var _to_height: float = 0.0
var _progress: float = 0.0
var _step_time: float = 0.3
var _target_cell: Vector2i = Vector2i.ZERO
var _target_height: int = 0
var _ready_done: bool = false
var _extra_sort_bias: float = 0.0
var _last_flat: Vector2 = Vector2.ZERO
var _last_height_levels: float = 0.0
var _visual_applied: bool = false


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node2D
	if _body == null:
		_body = get_parent() as Node2D
	_anchor = get_node_or_null(sort_anchor_path) as Node2D
	if _anchor == null and _body != null:
		var parent := _body.get_parent() as Node2D
		if parent != null and parent.is_in_group(sort_anchor_group):
			_anchor = parent
	_resolve_manager()
	_cell = start_cell
	set_process(true)


func _resolve_manager() -> void:
	if chunk_manager_path != NodePath():
		_manager = get_node_or_null(chunk_manager_path) as ChunkManager
	if _manager == null:
		var found := get_tree().get_first_node_in_group(&"chunk_manager")
		_manager = found as ChunkManager
	if _manager != null and _manager.settings != null:
		_iso = IsoCoordinateSystem.from_settings(_manager.settings)


func is_active() -> bool:
	return _manager != null and _manager.world != null and _iso != null


func world() -> WorldData:
	return _manager.world if _manager != null else null


func cell() -> Vector2i:
	return _cell


func height() -> int:
	return _height


func world_position() -> Vector3i:
	return Vector3i(_cell.x, _cell.y, _height)


func is_moving() -> bool:
	return _moving


## Coloca a entidade em uma célula, sem animação.
func teleport_to(target_cell: Vector2i) -> void:
	if not is_active():
		_cell = target_cell
		return
	_cell = target_cell
	_height = world().height_at(target_cell)
	_moving = false
	_progress = 0.0
	_apply_visual(_iso.cell_to_local(_cell), float(_height))
	height_changed.emit(_height)
	step_finished.emit(world_position())


## Tenta andar uma célula. Retorna a transição avaliada pelas MovementRules.
func request_step(direction: Vector2i, speed_scale: float = 1.0) -> MovementRules.MovementTransition:
	if _moving or not is_active():
		return MovementRules.MovementTransition.BLOCKED
	if direction == Vector2i.ZERO:
		return MovementRules.MovementTransition.BLOCKED

	var target := _cell + direction
	var transition := MovementRules.evaluate_world(world(), _cell, target, movement_context)
	if transition == MovementRules.MovementTransition.BLOCKED:
		step_blocked.emit(direction)
		return transition

	var target_height := world().height_at(target)
	var target_visual := _iso.world_to_local(Vector3i(target.x, target.y, target_height))
	if respect_physics_obstacles and _is_physically_blocked(target_visual):
		step_blocked.emit(direction)
		return MovementRules.MovementTransition.BLOCKED

	_target_cell = target
	_target_height = target_height
	_from_flat = _iso.cell_to_local(_cell)
	_to_flat = _iso.cell_to_local(target)
	_from_height = float(_height)
	_to_height = float(target_height)
	_progress = 0.0
	_step_time = 1.0 / maxf(cells_per_second * maxf(speed_scale, 0.05), 0.01)
	_moving = true
	step_started.emit(world_position(), Vector3i(target.x, target.y, target_height), int(transition))
	return transition


func _is_physically_blocked(target_visual: Vector2) -> bool:
	var physics_body := _body as PhysicsBody2D
	if physics_body == null:
		return false
	var motion := target_visual - physics_body.global_position
	var original_mask := physics_body.collision_mask
	var furniture_mask := original_mask & furniture_collision_mask
	var swept_mask := original_mask & ~furniture_collision_mask
	var blocked := false

	# Paredes, portas e demais obstáculos estruturais bloqueiam qualquer ponto
	# do percurso entre as duas células.
	if swept_mask != 0:
		physics_body.collision_mask = swept_mask
		blocked = physics_body.test_move(physics_body.global_transform, motion)

	# Furniture é avaliada pelo footprint real apenas no destino. Usar
	# recovery_as_collision faz uma sobreposição sem movimento contar como
	# bloqueio, inclusive quando a cápsula já nasce tocando o polígono.
	if not blocked and furniture_mask != 0:
		physics_body.collision_mask = furniture_mask
		var target_transform := physics_body.global_transform
		target_transform.origin += motion
		blocked = physics_body.test_move(
			target_transform, Vector2.ZERO, null, 0.08, true
		)

	physics_body.collision_mask = original_mask
	return blocked


func _process(delta: float) -> void:
	if not _ready_done:
		if _manager == null or _iso == null:
			_resolve_manager()
		if is_active() and world().is_loaded(_cell):
			_ready_done = true
			teleport_to(_cell)
		return

	if not _moving:
		return
	_progress = minf(_progress + delta / _step_time, 1.0)
	# Plano e altura interpolam separados: o corpo sobe/desce o degrau enquanto
	# anda, e a ORDENAÇÃO continua usando só a posição plana.
	_apply_visual(
		_from_flat.lerp(_to_flat, _progress),
		lerpf(_from_height, _to_height, _progress)
	)
	if _progress < 1.0:
		return

	_moving = false
	_cell = _target_cell
	if _target_height != _height:
		_height = _target_height
		height_changed.emit(_height)
	else:
		_height = _target_height
	step_finished.emit(world_position())


## Separa "plano" (chave do Y-Sort) de "altura" (deslocamento visual).
##
## Sem essa separação, uma entidade em cima de um morro seria ordenada como se
## estivesse mais ao fundo — e o terreno alto atrás dela apareceria por cima.
func _apply_visual(flat: Vector2, height_levels: float) -> void:
	if _body == null:
		return
	_last_flat = flat
	_last_height_levels = height_levels
	_visual_applied = true
	var offset := height_levels * float(_iso.height_pixels)
	if _anchor == null:
		_body.position = flat - Vector2(0.0, offset)
		_body.z_index = clampi(_height, -4000, 4000) if drive_z_index else 0
		return

	var bias := _iso.prop_sort_bias() + _extra_sort_bias
	_anchor.position = flat + Vector2(0.0, bias)
	_body.position = Vector2(0.0, -offset - bias)
	_body.z_index = clampi(_height, -4000, 4000) if drive_z_index else 0


## Viés EXTRA somado à chave do Y-Sort desta entidade, em pixels.
##
## Serve para móveis compridos (ver [FurnitureFrontOccluder]). Um móvel de mais
## de uma célula precisa ser ordenado pelo ponto mais baixo do desenho, senão o
## piso das células da frente passa por cima dele — e isso faz o ator que está
## ao LADO do móvel, visivelmente à frente, ficar com chave menor e ser desenhado
## atrás. A faixa da frente do móvel empurra a chave do ator meia célula, só
## enquanto ele está lá.
##
## O desenho não se move: como no viés padrão, o valor entra na âncora e sai do
## corpo. Ninguém muda de z_index.
func set_extra_sort_bias(value: float) -> void:
	if is_equal_approx(_extra_sort_bias, value):
		return
	_extra_sort_bias = value
	if _visual_applied:
		_apply_visual(_last_flat, _last_height_levels)


func extra_sort_bias() -> float:
	return _extra_sort_bias

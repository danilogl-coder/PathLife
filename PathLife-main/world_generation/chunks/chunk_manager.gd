## Carrega, gera e descarrega chunks ao redor do jogador.
##
## Geração acontece em [WorkerThreadPool] (só DADOS). A SceneTree é tocada
## exclusivamente na main thread, ao integrar o resultado.
class_name ChunkManager
extends Node

signal world_ready
signal chunk_generated(chunk_coord: Vector2i)
signal chunk_integrated(chunk_coord: Vector2i)
signal chunk_unloaded(chunk_coord: Vector2i)

@export_category("Configuração")
@export var settings: WorldSettings
@export var generator: WorldGenerator
@export var sampler: WorldSampler
@export var catalog: TileCatalog

@export_category("Cenas")
@export var chunk_view_scene: PackedScene

@export_category("Referências")
## Nó que define o centro de carregamento (normalmente o Player).
@export var focus: Node2D
## Onde as ChunkViews são penduradas. Deve ter Y-Sort ligado.
@export var chunk_container: Node
## Raízes visuais globais. Ground e Depth dividem o MESMO espaço de Y-Sort (as
## duas em z 0); a separação é só de conteúdo. Overlay é a única exceção: fica em
## outro Z, reservado ao que deve aparecer incondicionalmente à frente.
@export var ground_root: Node2D
@export var depth_root: Node2D
@export var overlay_root: Node2D
@export var save_manager: WorldSaveManager

var world: WorldData

var _views: Dictionary = {}
var _requested: Dictionary = {}
var _ready_chunks: Array[ChunkData] = []
var _ready_mutex := Mutex.new()
var _generator_pool: Array[WorldGenerator] = []
var _pool_mutex := Mutex.new()
var _busy_slots: Dictionary = {}
var _tasks: Dictionary = {}
var _world_ready_emitted: bool = false
var _world_seed: int = 0
var _last_center: Vector2i = Vector2i(2147483647, 2147483647)
var _initialized: bool = false
## Registros visuais globais. Um único TileMapLayer por classe/nível evita que
## a borda de um chunk vire uma barreira de desenho sobre o chunk vizinho.
var _ground_layer_registry: Dictionary = {}
var _depth_layer_registry: Dictionary = {}


func _ready() -> void:
	if settings == null or generator == null or sampler == null:
		push_error("ChunkManager: configure settings, generator e sampler no Inspector.")
		set_process(false)
		return
	initialize()


func initialize() -> void:
	_world_seed = settings.resolved_seed()
	if save_manager != null and save_manager.has_save():
		_world_seed = save_manager.load_seed(_world_seed)

	sampler.prepare(settings, _world_seed)
	generator.prepare(settings, _world_seed)

	world = WorldData.new(settings, sampler)

	_generator_pool.clear()
	var copies := maxi(settings.max_parallel_generations, 1)
	for i in copies:
		var copy: WorldGenerator = generator.clone() if i > 0 else generator
		copy.prepare(settings, _world_seed)
		_generator_pool.append(copy)

	_initialized = true
	set_process(true)


func world_seed() -> int:
	return _world_seed


func _process(_delta: float) -> void:
	if not _initialized:
		return
	var center := current_center_chunk()
	_request_required_chunks(center)
	if center != _last_center:
		_last_center = center
		_unload_far_chunks(center)
	_integrate_ready_chunks()


func current_center_chunk() -> Vector2i:
	if focus == null:
		return Vector2i.ZERO
	var agent := focus.get_node_or_null(^"WorldGridAgent") as WorldGridAgent
	if agent != null:
		return ChunkMath.world_to_chunk(agent.cell(), settings.chunk_size)
	var iso := IsoCoordinateSystem.from_settings(settings)
	return ChunkMath.world_to_chunk(iso.local_to_cell(focus.position), settings.chunk_size)


func _request_required_chunks(center: Vector2i) -> void:
	var radius := settings.render_distance
	var pending: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var coord := center + Vector2i(x, y)
			if world.has_chunk(coord) or _requested.has(coord):
				continue
			pending.append(coord)
	# Do centro para fora: o jogador vê primeiro o que está perto.
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ChunkMath.chebyshev_distance(a, center) < ChunkMath.chebyshev_distance(b, center)
	)
	# Nunca dispara mais tarefas do que existem cópias do gerador: cada tarefa
	# precisa de uma cópia própria para não disputar os mesmos FastNoiseLite.
	for coord in pending:
		if _requested.size() >= settings.max_parallel_generations:
			return
		_requested[coord] = true
		_request_chunk(coord)


func _request_chunk(coord: Vector2i) -> void:
	if not settings.use_worker_threads or OS.get_processor_count() <= 1:
		_push_ready_chunk(_generate(coord, 0))
		return
	_tasks[coord] = WorkerThreadPool.add_task(
		_generate_task.bind(coord), false, "world_chunk_%s" % coord
	)


func _generate_task(coord: Vector2i) -> void:
	var slot := _take_generator()
	var chunk := _generate(coord, slot)
	_release_generator(slot)
	_push_ready_chunk(chunk)


func _generate(coord: Vector2i, slot: int) -> ChunkData:
	var chunk := _generator_pool[slot].generate_chunk(coord)
	if save_manager != null:
		save_manager.apply_patches(chunk)
	return chunk


func _take_generator() -> int:
	while true:
		_pool_mutex.lock()
		for i in _generator_pool.size():
			if not _busy_slots.has(i):
				_busy_slots[i] = true
				_pool_mutex.unlock()
				return i
		_pool_mutex.unlock()
		OS.delay_msec(1)
	return 0


func _release_generator(slot: int) -> void:
	_pool_mutex.lock()
	_busy_slots.erase(slot)
	_pool_mutex.unlock()


func _push_ready_chunk(chunk: ChunkData) -> void:
	_ready_mutex.lock()
	_ready_chunks.append(chunk)
	_ready_mutex.unlock()


func _pop_ready_chunks() -> Array[ChunkData]:
	var result: Array[ChunkData] = []
	_ready_mutex.lock()
	result.assign(_ready_chunks)
	_ready_chunks.clear()
	_ready_mutex.unlock()
	return result


## Espera as tarefas em voo antes de sair de cena. Sem isto, uma worker pode
## continuar escrevendo em um ChunkManager já liberado.
func _exit_tree() -> void:
	for task_id: int in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_tasks.clear()


func _collect_finished_tasks() -> void:
	var finished: Array[Vector2i] = []
	for coord: Vector2i in _tasks:
		if WorkerThreadPool.is_task_completed(_tasks[coord]):
			finished.append(coord)
	for coord in finished:
		WorkerThreadPool.wait_for_task_completion(_tasks[coord])
		_tasks.erase(coord)


func _integrate_ready_chunks() -> void:
	_collect_finished_tasks()
	var pending := _pop_ready_chunks()
	if pending.is_empty():
		return
	var budget := settings.max_chunk_integrations_per_frame
	var leftovers: Array[ChunkData] = []
	for chunk in pending:
		if budget <= 0:
			leftovers.append(chunk)
			continue
		_integrate(chunk)
		budget -= 1
	if not leftovers.is_empty():
		_ready_mutex.lock()
		_ready_chunks.append_array(leftovers)
		_ready_mutex.unlock()


func _integrate(chunk: ChunkData) -> void:
	_requested.erase(chunk.coord)
	if world.has_chunk(chunk.coord):
		return
	world.add_chunk(chunk)
	chunk_generated.emit(chunk.coord)

	if chunk_view_scene == null or chunk_container == null:
		return
	var view: ChunkView = chunk_view_scene.instantiate()
	chunk_container.add_child(view)
	view.build(
		chunk, settings, catalog, ground_root, depth_root, overlay_root, world,
		_ground_layer_registry, _depth_layer_registry
	)
	for placement in chunk.structures:
		view.add_structure(placement)
	for placement in chunk.decorations:
		view.add_decoration(placement)
	_views[chunk.coord] = view
	chunk_integrated.emit(chunk.coord)

	if not _world_ready_emitted and _views.size() >= _expected_view_count():
		_world_ready_emitted = true
		world_ready.emit()


func _expected_view_count() -> int:
	var side := settings.render_distance * 2 + 1
	return side * side


func _unload_far_chunks(center: Vector2i) -> void:
	var limit := settings.render_distance + settings.unload_margin
	var to_remove: Array[Vector2i] = []
	for coord: Vector2i in world.loaded_chunk_coords():
		if ChunkMath.chebyshev_distance(coord, center) > limit:
			to_remove.append(coord)
	for coord in to_remove:
		unload_chunk(coord)


func unload_chunk(coord: Vector2i) -> void:
	world.remove_chunk(coord)
	var view: ChunkView = _views.get(coord, null)
	if view != null:
		view.queue_free()
		_views.erase(coord)
	chunk_unloaded.emit(coord)


func views() -> Array:
	return _views.values()


func view_for(coord: Vector2i) -> ChunkView:
	return _views.get(coord, null)


## Força a geração síncrona dos chunks ao redor do centro (útil em testes e no
## carregamento inicial, antes de soltar o jogador no mundo).
func generate_around_now(center: Vector2i, radius: int) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var coord := center + Vector2i(x, y)
			if world.has_chunk(coord):
				continue
			_requested.erase(coord)
			_integrate(_generate(coord, 0))
	_last_center = center

## Estressa o streaming do mundo e registra limites de memória/SceneTree/filas.
## Uso: godot --headless --path . --script res://tests/world_streaming_stress_test.gd
extends SceneTree

const SEQUENTIAL_CHUNKS := 600
const SETTLE_FRAMES := 240
const REPORT_INTERVAL := 50

var _failures := 0
var _peak_memory := 0.0
var _peak_nodes := 0
var _peak_objects := 0
var _peak_views := 0
var _peak_world_chunks := 0
var _peak_ground_cells := 0
var _peak_depth_cells := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	if "--single-thread" in user_args:
		var stress_settings := load("res://data/world/world_settings.tres") as WorldSettings
		stress_settings.use_worker_threads = false
		print("STRESS MODE: single-thread")
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	var world := scene.get_node(^"World/ProceduralWorld") as ProceduralWorld
	var player := scene.get_node(^"World/DepthSort/Entities/PlayerAnchor/Player") as PlayerController
	var manager := world.chunk_manager
	var agent := player.grid_agent
	for frame in 120:
		await process_frame
	_check(agent.is_active(), "agente inicializado")
	_test_generator_isolation(manager)
	_report("inicial", manager)

	# Vai 300 chunks a leste e cruza todo o caminho até 300 chunks a oeste.
	# Cada salto equivale exatamente a uma fronteira de chunk; o streaming passa
	# pelo mesmo ciclo que ocorreria caminhando, mas sem gastar animação por célula.
	for index in SEQUENTIAL_CHUNKS + 1:
		var chunk_x := SEQUENTIAL_CHUNKS / 2 - index
		agent.teleport_to(Vector2i(chunk_x * manager.settings.chunk_size, 0))
		await process_frame
		await process_frame
		if index % REPORT_INTERVAL == 0:
			_report("sequencial %d/%d" % [index, SEQUENTIAL_CHUNKS], manager)

	# Coordenadas grandes isolam falhas de conversão/precisão de falhas por
	# acúmulo. Inclui quadrantes positivos e negativos.
	for target: Vector2i in [
		Vector2i(100000, 100000),
		Vector2i(-100000, 100000),
		Vector2i(-100000, -100000),
		Vector2i(100000, -100000),
		Vector2i.ZERO,
	]:
		agent.teleport_to(target)
		for frame in 30:
			await process_frame
		_report("coordenada %s" % target, manager)

	var settle_deadline := Time.get_ticks_msec() + 30000
	while not _streaming_idle(manager) and Time.get_ticks_msec() < settle_deadline:
		await create_timer(0.01).timeout
	for frame in SETTLE_FRAMES:
		await process_frame
	_report("estabilizado", manager)
	var active_side := manager.settings.render_distance * 2 + 1
	var unload_side := (
		(manager.settings.render_distance + manager.settings.unload_margin) * 2 + 1
	)
	_check(manager.views().size() <= unload_side * unload_side, "views limitadas pela janela ativa")
	_check(
		manager.world.loaded_chunk_coords().size() <= unload_side * unload_side,
		"dados de chunks limitados pela janela ativa"
	)
	_check(manager._requested.size() <= manager.settings.max_parallel_generations, "fila solicitada limitada")
	_check(manager._tasks.size() <= manager.settings.max_parallel_generations, "tarefas limitadas")
	_check(manager._ready_chunks.size() <= manager.settings.max_parallel_generations, "fila pronta limitada")
	_check(_streaming_idle(manager), "streaming conclui enquanto o jogador está parado")
	_check(manager.views().size() == active_side * active_side, "janela ativa volta a ficar completa")
	_check(active_side > 0, "configuração de renderização válida")
	print(
		"STRESS PEAKS | RAM %.1f MiB | Nodes %d | Objects %d | Views %d | Chunks %d"
		% [_peak_memory, _peak_nodes, _peak_objects, _peak_views, _peak_world_chunks]
	)
	print("STRESS TILE PEAKS | Ground %d | Depth %d" % [_peak_ground_cells, _peak_depth_cells])
	scene.queue_free()
	await process_frame
	await process_frame
	if _failures == 0:
		print("WORLD STREAMING STRESS TEST: OK")
		quit(0)
	else:
		printerr("WORLD STREAMING STRESS TEST: %d falha(s)" % _failures)
		quit(1)


func _report(label: String, manager: ChunkManager) -> void:
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var physics := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	var ground_cells := _cell_count(manager.ground_root)
	var depth_cells := _cell_count(manager.depth_root)
	var views := manager.views().size()
	var chunks := manager.world.loaded_chunk_coords().size()
	_peak_memory = maxf(_peak_memory, memory)
	_peak_nodes = maxi(_peak_nodes, nodes)
	_peak_objects = maxi(_peak_objects, objects)
	_peak_views = maxi(_peak_views, views)
	_peak_world_chunks = maxi(_peak_world_chunks, chunks)
	_peak_ground_cells = maxi(_peak_ground_cells, ground_cells)
	_peak_depth_cells = maxi(_peak_depth_cells, depth_cells)
	print(
		"STRESS %-24s | RAM %7.1f MiB | Nodes %5d | Objects %6d | Physics %4d"
		% [label, memory, nodes, objects, physics]
	)
	print(
		"       Views %3d | Chunks %3d | Requested %2d | Tasks %2d | Ready %2d"
		% [views, chunks, manager._requested.size(), manager._tasks.size(), manager._ready_chunks.size()]
	)
	print("       Ground cells %6d | Depth cells %6d" % [ground_cells, depth_cells])


func _cell_count(parent: Node) -> int:
	var result := 0
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer != null:
			result += layer.get_used_cells().size()
	return result


func _streaming_idle(manager: ChunkManager) -> bool:
	var active_side := manager.settings.render_distance * 2 + 1
	return (
		manager.views().size() == active_side * active_side
		and manager._requested.is_empty()
		and manager._tasks.is_empty()
		and manager._ready_chunks.is_empty()
	)


func _test_generator_isolation(manager: ChunkManager) -> void:
	var samplers: Array[WorldSampler] = []
	for worker_generator: WorldGenerator in manager._generator_pool:
		var worker_sampler: WorldSampler = null
		for generation_pass: WorldGenerationPass in worker_generator.passes:
			if generation_pass is HeightPass:
				worker_sampler = (generation_pass as HeightPass).sampler
				break
		_check(worker_sampler != null, "worker possui sampler")
		_check(worker_sampler != manager.sampler, "worker não compartilha sampler com a main thread")
		_check(not samplers.has(worker_sampler), "sampler não é compartilhado entre workers")
		if worker_sampler != null:
			samplers.append(worker_sampler)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		printerr("  FALHA ", label)

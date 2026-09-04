## Contrato dos sinais usados para registrar e remover topologia de estruturas.
##
## Uso:
##   godot --headless --path . --script res://tests/vision_streaming_signal_test.gd
extends SceneTree

const TEST_CHUNK := Vector2i(11, -7)
const TEST_PLACEMENT_ID := 424242

var _passed := 0
var _failed := 0
var _order: Array[StringName] = []
var _integrated_records: Array[Dictionary] = []
var _unload_records: Array[Dictionary] = []
var _integrated_structure: StructureRoot


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[Streaming] sinais de ciclo de vida de estruturas")
	var host := Node2D.new()
	host.name = "VisionStreamingProbe"
	var chunk_container := Node.new()
	chunk_container.name = "Chunks"
	var ground_root := Node2D.new()
	ground_root.name = "Ground"
	var depth_root := Node2D.new()
	depth_root.name = "Depth"
	depth_root.y_sort_enabled = true
	var overlay_root := Node2D.new()
	overlay_root.name = "Overlay"
	host.add_child(chunk_container)
	host.add_child(ground_root)
	host.add_child(depth_root)
	host.add_child(overlay_root)

	var manager := ChunkManager.new()
	manager.name = "ChunkManager"
	manager.settings = load("res://data/world/world_settings.tres")
	manager.generator = load("res://data/world/world_generator.tres")
	manager.sampler = load("res://data/world/world_sampler.tres")
	manager.catalog = load("res://data/world/tiles/ground_catalog.tres")
	manager.chunk_view_scene = load("res://world_generation/rendering/chunk_view.tscn")
	manager.chunk_container = chunk_container
	manager.ground_root = ground_root
	manager.depth_root = depth_root
	manager.overlay_root = overlay_root
	manager.structure_integrated.connect(_on_structure_integrated)
	manager.structure_will_unload.connect(_on_structure_will_unload)
	manager.chunk_unloaded.connect(_on_chunk_unloaded)
	host.add_child(manager)
	root.add_child(host)
	# _ready inicializa dados e workers; este teste conduz a integração de modo
	# determinístico e não deixa o streaming automático solicitar outros chunks.
	manager.set_process(false)

	var chunk := ChunkData.new(TEST_CHUNK, 0)
	var placement := StructurePlacement.new(
		load("res://data/world/structures/casa_madeira.tres"),
		TEST_CHUNK * manager.settings.chunk_size
	)
	placement.foundation_height = 0
	placement.placement_id = TEST_PLACEMENT_ID
	chunk.structures.append(placement)

	manager._integrate(chunk)
	_check(_integrated_records.size() == 1, "integração emite um sinal por estrutura")
	if not _integrated_records.is_empty():
		var record := _integrated_records[0]
		_check(record.owner_chunk == TEST_CHUNK, "sinal informa chunk proprietário")
		_check(record.placement == placement, "sinal entrega o mesmo placement")
		_check(record.structure is StructureRoot, "sinal entrega StructureRoot instanciada")
		_check(record.structure.placement() == placement, "estrutura já recebeu setup no sinal")
	_check(manager.world.has_chunk(TEST_CHUNK), "chunk está registrado após integração")
	_check(manager.view_for(TEST_CHUNK) != null, "view existe após integração")

	manager.unload_chunk(TEST_CHUNK)
	_check(_unload_records.size() == 1, "unload emite sinal para a estrutura registrada")
	if not _unload_records.is_empty():
		var unload := _unload_records[0]
		_check(unload.owner_chunk == TEST_CHUNK, "unload informa chunk proprietário")
		_check(unload.placement_id == TEST_PLACEMENT_ID, "unload usa placement_id persistente")
		_check(unload.structure_alive, "sinal de remoção ocorre antes de queue_free")
	_check(
		_order == [&"integrated", &"will_unload", &"chunk_unloaded"],
		"ordem permite remover topologia antes da view",
		str(_order)
	)
	_check(not manager.world.has_chunk(TEST_CHUNK), "dados do chunk são removidos")
	_check(manager.view_for(TEST_CHUNK) == null, "registro da view é removido")

	host.queue_free()
	await process_frame
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _on_structure_integrated(
	owner_chunk: Vector2i, placement: StructurePlacement, structure: StructureRoot
) -> void:
	_order.append(&"integrated")
	_integrated_structure = structure
	_integrated_records.append({
		"owner_chunk": owner_chunk,
		"placement": placement,
		"structure": structure,
	})


func _on_structure_will_unload(owner_chunk: Vector2i, placement_id: int) -> void:
	_order.append(&"will_unload")
	_unload_records.append({
		"owner_chunk": owner_chunk,
		"placement_id": placement_id,
		"structure_alive": (
			is_instance_valid(_integrated_structure)
			and _integrated_structure.is_inside_tree()
		),
	})


func _on_chunk_unloaded(_owner_chunk: Vector2i) -> void:
	_order.append(&"chunk_unloaded")


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

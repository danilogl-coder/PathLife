## Teste de integração: mundo + jogador em grade dentro de uma SceneTree real.
##
## Uso:
##   godot --headless --path . --script res://tests/player_grid_integration_test.gd
extends SceneTree

var _passed := 0
var _failed := 0
var _world: ProceduralWorld
var _player: PlayerController
var _agent: WorldGridAgent


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])


func _init() -> void:
	root.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	_build_scene.call_deferred()


func _build_scene() -> void:
	var container := Node2D.new()
	container.name = "Container"
	container.y_sort_enabled = true
	root.add_child(container)

	var anchor: Node2D = load("res://tests/player_grid_probe.tscn").instantiate()
	_player = anchor.get_node(^"Player")
	_agent = _player.get_node(^"WorldGridAgent")

	_world = load("res://scenes/world/procedural_world.tscn").instantiate()
	_world.focus = _player
	container.add_child(_world)
	container.add_child(anchor)

	await process_frame
	await process_frame
	await process_frame
	_run_checks()
	_test_vegetation_desync()


func _run_checks() -> void:
	print("\n[Integração] mundo + jogador em grade")
	var data := _world.world_data()
	_check(data != null, "WorldData disponivel")
	_check(data.loaded_chunk_coords().size() > 0, "chunks carregados",
		"%d" % data.loaded_chunk_coords().size())
	_check(_agent.is_active(), "agente ativo")
	_check(_player.is_grid_driven(), "jogador dirigido pela grade")

	var iso := IsoCoordinateSystem.from_settings(_world.chunk_manager.settings)
	var expected := iso.world_to_local(_agent.world_position())
	_check(_player.global_position.is_equal_approx(expected),
		"posicao visual = projecao da logica",
		"%s vs %s" % [_player.global_position, expected])
	_check(_player.z_index == 0, "entidade fica em z_index 0 (ordenacao por Y-Sort)")
	var anchor_node := _player.get_parent() as Node2D
	var flat := iso.cell_to_local(_agent.cell()) + Vector2(0.0, iso.prop_sort_bias())
	_check(anchor_node.position.is_equal_approx(flat),
		"ancora carrega a posicao plana (chave de profundidade)",
		"%s vs %s" % [anchor_node.position, flat])

	var chunk_views := _world.chunk_manager.views()
	_check(chunk_views.size() > 0, "ChunkViews instanciadas", "%d" % chunk_views.size())
	var layers := 0
	var tiles := 0
	var depth_layers := 0
	var depth_tiles := 0
	var classes_ok := true
	var ground_instance_by_level: Dictionary = {}
	var depth_instance_by_level: Dictionary = {}
	var layers_shared_across_chunks := true
	for view: ChunkView in chunk_views:
		layers += view.layer_levels().size()
		for level: int in view.layer_levels():
			var ground_layer := view.layer_at(level)
			if ground_layer != null:
				tiles += ground_layer.get_used_cells().size()
				# Toda camada precisa dividir o MESMO espaço de ordenação: z 0 e
				# Y-Sort ligado. Basta uma classe em outro Z para ela deixar de
				# disputar profundidade e passar a ser desenhada sempre por cima
				# — foi isso que recortou a grama, duas vezes.
				classes_ok = classes_ok and ground_layer.y_sort_enabled
				classes_ok = classes_ok and ground_layer.z_index == 0
				var ground_id := ground_layer.get_instance_id()
				if ground_instance_by_level.has(level):
					layers_shared_across_chunks = (
						layers_shared_across_chunks
						and ground_instance_by_level[level] == ground_id
					)
				else:
					ground_instance_by_level[level] = ground_id
			var depth_layer := view.depth_layer_at(level)
			if depth_layer != null:
				depth_layers += 1
				depth_tiles += depth_layer.get_used_cells().size()
				classes_ok = classes_ok and depth_layer.y_sort_enabled
				classes_ok = classes_ok and depth_layer.z_index == 0
				var depth_id := depth_layer.get_instance_id()
				if depth_instance_by_level.has(level):
					layers_shared_across_chunks = (
						layers_shared_across_chunks
						and depth_instance_by_level[level] == depth_id
					)
				else:
					depth_instance_by_level[level] = depth_id
	_check(layers > 0, "camadas de altura criadas", "%d camadas" % layers)
	_check(tiles > 0, "tiles pintados", "%d tiles" % tiles)
	_check(depth_layers > 0 and depth_tiles > 0,
		"faces verticais criadas em Depth", "%d camadas / %d faces" % [depth_layers, depth_tiles])
	_check(classes_ok, "Ground, Depth e ator dividem um unico espaco de Y-Sort em z 0")
	_check(layers_shared_across_chunks,
		"chunks compartilham layers globais por classe e nivel")
	_check(_world.ground_root.z_index == _world.depth_root.z_index,
		"piso e faces no MESMO Z — Z-Index e resolvido antes do Y-Sort",
		"ground=%d depth=%d" % [_world.ground_root.z_index, _world.depth_root.z_index])
	_check(_world.ground_root.y_sort_enabled and _world.ground_root.z_index == 0,
		"GroundRoot divide o mesmo Y-Sort das faces e dos atores (z 0)",
		"ysort=%s z=%d" % [_world.ground_root.y_sort_enabled, _world.ground_root.z_index])
	_check(_world.depth_root.y_sort_enabled and _world.depth_root.z_index == 0,
		"faces, props e atores compartilham o DepthSort",
		"ysort=%s z=%d" % [_world.depth_root.y_sort_enabled, _world.depth_root.z_index])
	var physical_layers := 0
	for child in _world.ground_root.get_children():
		if child is TileMapLayer:
			physical_layers += 1
	for child in _world.depth_root.get_children():
		if child is TileMapLayer:
			physical_layers += 1
	_check(
		physical_layers <= (
			ground_instance_by_level.size() + depth_instance_by_level.size()
		),
		"quantidade de layers independe da quantidade de chunks",
		"%d fisicos / %d niveis-classe" % [
			physical_layers,
			ground_instance_by_level.size() + depth_instance_by_level.size(),
		]
	)

	# Passo válido de verdade: procura uma direção liberada.
	var start := _agent.cell()
	var moved := false
	for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var transition := _agent.request_step(direction)
		if transition != MovementRules.MovementTransition.BLOCKED:
			moved = true
			break
	_check(moved, "conseguiu dar um passo valido")
	if moved:
		var guard := 0
		while _agent.is_moving() and guard < 600:
			await process_frame
			guard += 1
		_check(not _agent.is_moving(), "passo terminou")
		_check(_agent.cell() != start, "celula logica mudou", "%s -> %s" % [start, _agent.cell()])
		var target := iso.world_to_local(_agent.world_position())
		_check(_player.global_position.is_equal_approx(target), "visual reancorado na celula nova",
			"%s vs %s" % [_player.global_position, target])

	# Passo impossível: nunca deve mover.
	var before := _agent.cell()
	var blocked_count := 0
	for i in 40:
		var far := Vector2i(0, 0)
		var transition := _agent.request_step(far)
		if transition == MovementRules.MovementTransition.BLOCKED:
			blocked_count += 1
	_check(blocked_count == 40, "direcao zero sempre bloqueada")
	_check(_agent.cell() == before, "celula nao muda quando bloqueado")

	# Descarregamento não deixa nós órfãos.
	var any_coord: Vector2i = _world.chunk_manager.world.loaded_chunk_coords()[0]
	_world.chunk_manager.unload_chunk(any_coord)
	_check(_world.chunk_manager.view_for(any_coord) == null, "view do chunk descarregada")
	_check(not _world.chunk_manager.world.has_chunk(any_coord), "dados do chunk removidos")

	await _test_streaming()

	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Árvores vizinhas não podem soltar folha no mesmo instante.
##
## Precisa de `SceneTree` rodando: o quadro inicial é escolhido no `_ready` da
## decoração, e no `_init` de um script de ferramenta o `_ready` ainda não
## aconteceu.
func _test_vegetation_desync() -> void:
	print("\n[Vegetação] árvores dessincronizadas")
	var scene: PackedScene = load("res://presentation/world/vegetation/arvore_ipe.tscn")
	if scene == null:
		_check(false, "cena da arvore carrega")
		return
	var holder := Node2D.new()
	root.add_child(holder)
	var frames_seen: Dictionary = {}
	for index in 40:
		var instance: Node2D = scene.instantiate()
		instance.set_meta(&"world_position", Vector3i(index * 3, index * 7 + 2, 0))
		holder.add_child(instance)
		var sprite := instance.get_node(^"Sprite") as AnimatedSprite2D
		frames_seen[sprite.frame] = true
		if index == 0:
			_check(sprite.is_playing(), "a arvore ja entra tocando a animacao")
	_check(frames_seen.size() > 10,
		"arvores vizinhas nao soltam folha no mesmo instante",
		"%d quadros iniciais distintos em 40" % frames_seen.size())

	# Estabilidade: recarregar o chunk não pode fazer a árvore saltar.
	var first := -1
	var stable := true
	for index in 4:
		var instance: Node2D = scene.instantiate()
		instance.set_meta(&"world_position", Vector3i(9, -4, 3))
		holder.add_child(instance)
		var frame := (instance.get_node(^"Sprite") as AnimatedSprite2D).frame
		if first < 0:
			first = frame
		elif frame != first:
			stable = false
	_check(stable, "a mesma celula cai sempre no mesmo quadro", "quadro %d" % first)
	holder.queue_free()


## Anda bastante em linha reta e confere que o mundo continua carregando e
## descarregando sem sobrar (nem faltar) chunk.
func _test_streaming() -> void:
	print("\n[Streaming] atravessando chunks")
	var manager := _world.chunk_manager
	var settings := manager.settings
	var start_chunk := manager.current_center_chunk()
	var steps := settings.chunk_size * 2 + 4
	var teleports := 0
	for i in steps:
		_agent.teleport_to(_agent.cell() + Vector2i(1, 0))
		teleports += 1
		await process_frame
	# Espera o streaming ASSENTAR, em vez de contar frames na esperança de que
	# dê tempo. Geração roda em worker thread: um número fixo de frames
	# transforma o teste num jogo de sorte assim que o mundo fica mais pesado.
	# Assentado = nada carregado longe demais E nada faltando dentro do raio.
	var end_chunk := manager.current_center_chunk()
	var limit := settings.render_distance + settings.unload_margin
	var too_far := 0
	var missing := 0
	var guard := 0
	while guard < 1800:
		await process_frame
		guard += 1
		end_chunk = manager.current_center_chunk()
		too_far = 0
		for coord: Vector2i in manager.world.loaded_chunk_coords():
			if ChunkMath.chebyshev_distance(coord, end_chunk) > limit:
				too_far += 1
		missing = 0
		for y in range(-settings.render_distance, settings.render_distance + 1):
			for x in range(-settings.render_distance, settings.render_distance + 1):
				if not manager.world.has_chunk(end_chunk + Vector2i(x, y)):
					missing += 1
		if too_far == 0 and missing == 0:
			break
	_check(end_chunk != start_chunk, "o foco mudou de chunk", "%s -> %s" % [start_chunk, end_chunk])
	_check(too_far == 0, "nenhum chunk distante ficou carregado", "%d sobraram" % too_far)
	_check(missing == 0, "raio de renderizacao completo", "%d faltando" % missing)
	# Um frame a mais: as views são integradas logo depois dos dados.
	await process_frame
	_check(manager.views().size() == manager.world.loaded_chunk_coords().size(),
		"views e dados em sincronia",
		"%d views / %d chunks" % [manager.views().size(), manager.world.loaded_chunk_coords().size()])

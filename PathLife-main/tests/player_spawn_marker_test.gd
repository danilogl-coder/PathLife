## Teste de integração do marcador pintável com o mundo procedural real.
## Uso: godot --headless --path . --script res://tests/player_spawn_marker_test.gd
extends SceneTree

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	_expect(packed != null, "Main precisa carregar.")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	for frame in 30:
		await process_frame
		await physics_frame

	var player := root.find_children("*", "PlayerController", true, false).front() as PlayerController
	var procedural := root.find_children("*", "ProceduralWorld", true, false).front() as ProceduralWorld
	var structures := root.find_children("*", "StructureRoot", true, false)
	_expect(player != null and player.grid_agent != null and procedural != null,
		"Mundo real precisa possuir Player e ProceduralWorld.")
	_expect(not structures.is_empty(), "Mundo real precisa instanciar uma estrutura.")
	if player == null or player.grid_agent == null or procedural == null or structures.is_empty():
		_finish()
		return

	var expected := Vector2i.ZERO
	var best_distance_squared := INF
	var found := false
	for node: Node in structures:
		var house := node as StructureRoot
		if house == null or house.placement() == null:
			continue
		for local_spawn: Vector2i in house.player_spawn_cells():
			var candidate := house.placement().origin_xy + local_spawn
			var distance_squared := float(candidate.distance_squared_to(Vector2i.ZERO))
			if distance_squared >= best_distance_squared:
				continue
			best_distance_squared = distance_squared
			expected = candidate
			found = true
	_expect(found, "Ao menos uma casa carregada precisa ter Spawn Player pintado.")
	_expect(player.grid_agent.cell() == expected,
		"Player precisa usar a célula pintada como spawn (%s != %s)." % [
			player.grid_agent.cell(), expected
		])
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PLAYER_SPAWN_MARKER_TEST: OK")
	quit(_failures)

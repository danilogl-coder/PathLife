extends SceneTree

var _failed: bool = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var bed_scene := load("res://gameplay/furniture/bed/bed_r0.tscn") as PackedScene
	var player_scene := load("res://gameplay/player/player.tscn") as PackedScene
	if bed_scene == null or player_scene == null:
		_fail("As cenas de cama e Player precisam carregar.")
		_finish(world)
		return

	var bed := bed_scene.instantiate() as BedFurniture
	var player := player_scene.instantiate() as PlayerController
	world.add_child(bed)
	world.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(-140, -50)

	await physics_frame
	await physics_frame

	var collision := player.move_and_collide(Vector2(300, 0), true)
	if collision == null:
		_fail("O Player atravessou a colisão sólida da cama.")
	else:
		var collider := collision.get_collider() as BedFurniture
		if collider != bed:
			_fail("O Player colidiu com um corpo diferente da cama.")

	var bed_visual := bed.get_node("Visual") as CanvasItem
	var top_occluder := bed.get_node("TopOcclusionArea") as FurnitureTopOccluder
	player.position = Vector2(-70, -50)
	await physics_frame
	await physics_frame
	if bed_visual.z_index != top_occluder.occluding_z_index:
		_fail("A borda superior não aplicou o Z de sobreposição configurado.")

	player.position = Vector2(0, 35)
	await physics_frame
	await physics_frame
	if bed_visual.z_index != 0:
		_fail("A cama não voltou para Z 0 após sair da borda superior.")

	_finish(world)


func _finish(world: Node2D) -> void:
	world.queue_free()
	if not _failed:
		print("BED_COLLISION_PHYSICS_OK")
	quit(1 if _failed else 0)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)

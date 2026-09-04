## Valida a troca global entre paredes cheias, baixas e transparentes.
## Uso: godot --headless --path . --script res://tests/wall_visibility_test.gd
extends SceneTree

const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena de paredes carrega")
	if packed == null:
		_finish()
		return

	var house := packed.instantiate() as StructureRoot
	root.add_child(house)
	await process_frame
	var manager := root.get_node(^"WallVisibilityManager")
	_check(manager != null, "controlador global está ativo")
	_check(house.is_in_group(&"wall_view_targets"), "estrutura se registra automaticamente")

	_check(
		ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false),
		"movimento do canvas fica alinhado aos pixels"
	)
	manager.set_mode(1)
	_check(_all_walls_use_row(house, 2), "todas as paredes usam os tiles transparentes")

	# Uma casa criada depois da troca deve nascer no modo global atual.
	var late_house := packed.instantiate() as StructureRoot
	late_house.position = Vector2(2048.0, 0.0)
	root.add_child(late_house)
	await process_frame
	_check(_all_walls_use_row(late_house, 2), "nova estrutura herda o modo atual")

	await physics_frame
	_check(_has_wall_collision(house), "paredes transparentes preservam a colisão")
	manager.set_mode(2)
	_check(_all_walls_use_row(house, 0), "todas as paredes usam os tiles cortados")
	manager.set_mode(0)
	_check(_all_walls_use_row(house, 1), "modo inteiro restaura todas as paredes")

	house.queue_free()
	late_house.queue_free()
	_finish()


func _all_walls_use_row(structure: StructureRoot, expected_row: int) -> bool:
	var count := 0
	for descendant: Node in structure.find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if (
				data == null
				or data.get_custom_data(&"categoria") not in ["parede", "janela", "porta"]
			):
				continue
			count += 1
			if layer.get_cell_atlas_coords(cell).y != expected_row:
				return false
	return count > 0


func _has_wall_collision(structure: StructureRoot) -> bool:
	var probe := RectangleShape2D.new()
	probe.size = Vector2(4.0, 4.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = 1
	query.transform = Transform2D(0.0, Vector2(32.0, -16.0))
	return not structure.get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _finish() -> void:
	if _failures == 0:
		print("\nWALL VISIBILITY TEST: OK")
		quit(0)
	else:
		printerr("\nWALL VISIBILITY TEST: %d falha(s)" % _failures)
		quit(1)

## Uso:
## Godot --headless --path . --script \
##   res://world_generation/visibility/tests/structure_vision_baker_test.gd
extends SceneTree

const SCENE_PATH := "res://presentation/world/structures/casa_madeira_tilemap.tscn"
const BAKER := preload("res://world_generation/visibility/structure_vision_baker.gd")
const PORTAL := preload("res://world_generation/visibility/vision_portal.gd")

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena da casa carrega")
	if packed == null:
		_finish()
		return
	var structure := packed.instantiate()
	root.add_child(structure)
	await process_frame

	var placement := StructurePlacement.new()
	placement.placement_id = 771
	placement.origin_xy = Vector2i(-12, 23)
	placement.foundation_height = 4
	var snapshot := BAKER.new().bake(structure, placement)
	_check(snapshot.origin == Vector3i(-12, 23, 4), "origem mundial vem do placement")
	_check(snapshot.floor_cells.size() == 56, "casa possui 56 pisos")
	_check(snapshot.edges.size() == 45, "casa possui 45 bordas canônicas")
	_check(snapshot.opaque_edge_count() == 35, "casa possui 35 bordas opacas")
	_check(snapshot.portal_count(PORTAL.DOOR) == 4, "casa possui quatro portas")
	_check(snapshot.portal_count(PORTAL.WINDOW) == 6, "casa possui seis janelas")
	var zone_sizes: Array[int] = []
	for zone: VisionZone in snapshot.internal_zones():
		zone_sizes.append(zone.size())
	zone_sizes.sort()
	_check(zone_sizes == [9, 15, 16, 16], "zonas internas têm tamanhos 9/15/16/16")
	_check(snapshot.zones.size() == 4, "casa não cria zona exterior falsa")
	for zone: VisionZone in snapshot.zones:
		_check(not zone.is_exterior, "zona %d é estruturalmente fechada" % zone.id)
	for portal: VisionPortal in snapshot.portals.values():
		_check(
			String(portal.id).begins_with("771|"),
			"ID de portal usa placement estável"
		)
		_check(portal.cell_a.z == 4 and portal.cell_b.z == 4, "portal preserva altura")
		_check(portal.zone_a >= 0 or portal.zone_b >= 0, "portal toca uma zona")
	_check(snapshot.warnings.is_empty(), "bake da casa não gera avisos")

	_test_overlay_is_ignored(structure, placement, snapshot.edges.size())
	_test_corner_and_mountant(structure, placement)
	structure.queue_free()
	await process_frame
	_finish()


func _test_overlay_is_ignored(
	structure: Node,
	placement: StructurePlacement,
	expected_edges: int
) -> void:
	var overlay := structure.get_node(^"ParedesSemColisao") as TileMapLayer
	overlay.set_cell(Vector2i(30, 30), 10, Vector2i(0, 1), 0)
	var snapshot := BAKER.new().bake(structure, placement)
	_check(snapshot.edges.size() == expected_edges, "ParedesSemColisao é ignorada")
	overlay.erase_cell(Vector2i(30, 30))


func _test_corner_and_mountant(structure: Node, placement: StructurePlacement) -> void:
	var walls := structure.get_node(^"Paredes") as TileMapLayer
	var original: Array[Dictionary] = []
	for cell: Vector2i in walls.get_used_cells():
		original.append({
			"cell": cell,
			"source": walls.get_cell_source_id(cell),
			"coords": walls.get_cell_atlas_coords(cell),
			"alternative": walls.get_cell_alternative_tile(cell),
		})
	walls.clear()
	# quina_e: ne + se.
	walls.set_cell(Vector2i(2, 2), 10, Vector2i(5, 1), 0)
	# montante_n: não representa borda nem portal.
	walls.set_cell(Vector2i(4, 4), 20, Vector2i(12, 1), 0)
	var snapshot := BAKER.new().bake(structure, placement)
	_check(snapshot.edges.size() == 2, "quina gera exatamente duas bordas")
	_check(snapshot.portals.is_empty(), "montante não vira portal")
	walls.clear()
	for entry: Dictionary in original:
		walls.set_cell(entry.cell, entry.source, entry.coords, entry.alternative)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _finish() -> void:
	if _failures == 0:
		print("\nSTRUCTURE VISION BAKER TEST: OK")
		quit(0)
	else:
		printerr("\nSTRUCTURE VISION BAKER TEST: %d falha(s)" % _failures)
		quit(1)


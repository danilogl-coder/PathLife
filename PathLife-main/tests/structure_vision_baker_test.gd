## Contrato da extração semântica da casa de referência.
## Uso: godot --headless --path . --script res://tests/structure_vision_baker_test.gd
extends SceneTree

const HouseScene := preload("res://presentation/world/structures/casa_madeira_tilemap.tscn")
const HouseDefinition := preload("res://data/world/structures/casa_madeira.tres")

var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[VisionBaker] topologia da casa de referência")
	var placement := StructurePlacement.new(HouseDefinition, Vector2i(31, -27))
	placement.foundation_height = 2
	placement.placement_id = 99173
	var house := HouseScene.instantiate() as StructureRoot
	house.setup(placement)
	root.add_child(house)
	await process_frame

	var snapshot := house.vision_snapshot()
	_check(snapshot != null, "snapshot é criado")
	if snapshot != null:
		_check(snapshot.placement_id == placement.placement_id, "placement_id é preservado")
		_check(snapshot.origin == Vector3i(31, -27, 2), "origem mundial inclui altura")
		_check(snapshot.floor_cells.size() == 56, "56 células de piso", str(snapshot.floor_cells.size()))
		_check(snapshot.edges.size() == 45, "45 bordas canônicas", str(snapshot.edges.size()))
		_check(snapshot.opaque_edge_count() == 35, "35 bordas opacas", str(snapshot.opaque_edge_count()))
		_check(snapshot.portal_count(&"door") == 4, "quatro portas")
		_check(snapshot.portal_count(&"window") == 6, "seis janelas")
		_check(snapshot.portals.size() == 10, "dez portais no total")

		var internal_sizes: Array[int] = []
		for zone: VisionZone in snapshot.internal_zones():
			internal_sizes.append(zone.size())
		internal_sizes.sort()
		_check(internal_sizes == [9, 15, 16, 16], "zonas internas 16/16/15/9", str(internal_sizes))
		_check(snapshot.zones.size() == 4, "somente quatro zonas de piso")
		_check(_has_authored_edge_at(snapshot, Vector2i(7, 2)), "parede em x=7 não é cortada pelo footprint")
		_check(_has_authored_edge_at(snapshot, Vector2i(3, 8)), "parede em y=8 não é cortada pelo footprint")
		_check(_all_edges_are_adjacent(snapshot), "todas as bordas ligam células adjacentes")
		_check(_all_portals_have_matching_edges(snapshot), "todo portal ocupa sua borda canônica")
		_check(_portals_exclude_mounts(snapshot, house), "montantes não viram portais")
		_check(snapshot.warnings.is_empty(), "casa de referência não gera avisos", str(snapshot.warnings))
		_benchmark_house(snapshot)
	_test_wall_only_structure(placement)

	house.queue_free()
	await process_frame
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _has_authored_edge_at(snapshot: StructureVisionSnapshot, local_cell: Vector2i) -> bool:
	for edge: VisionEdge in snapshot.edges.values():
		if edge.authored_cell == local_cell:
			return true
	return false


func _all_edges_are_adjacent(snapshot: StructureVisionSnapshot) -> bool:
	for edge: VisionEdge in snapshot.edges.values():
		if not VisionEdge.are_adjacent(edge.cell_a, edge.cell_b):
			return false
	return true


func _all_portals_have_matching_edges(snapshot: StructureVisionSnapshot) -> bool:
	for portal: VisionPortal in snapshot.portals.values():
		var edge := snapshot.edge_between(portal.cell_a, portal.cell_b) as VisionEdge
		if edge == null or edge.portal_id != portal.id or edge.opaque:
			return false
	return true


func _portals_exclude_mounts(
	snapshot: StructureVisionSnapshot, house: StructureRoot
) -> bool:
	var walls := house.get_node(^"Paredes") as TileMapLayer
	for portal: VisionPortal in snapshot.portals.values():
		var data := walls.get_cell_tile_data(portal.authored_cell)
		if data == null or String(data.get_custom_data(&"peca")).begins_with("montante_"):
			return false
	return true


func _test_wall_only_structure(placement: StructurePlacement) -> void:
	var wall_only := HouseScene.instantiate() as StructureRoot
	var floor_layer := wall_only.get_node_or_null(^"Piso")
	if floor_layer != null:
		wall_only.remove_child(floor_layer)
		floor_layer.free()
	var snapshot := StructureVisionBaker.new().bake(wall_only, placement)
	_check(snapshot.floor_cells.is_empty(), "estrutura só com paredes não inventa piso")
	_check(snapshot.zones.is_empty(), "estrutura só com paredes não cria zonas")
	_check(snapshot.edges.size() == 45, "estrutura só com paredes ainda bloqueia LOS")
	_check(snapshot.opaque_edge_count() == 35, "paredes opacas sobrevivem sem Piso")
	var warned_about_floor := false
	for warning: String in snapshot.warnings:
		if warning.contains("Piso"):
			warned_about_floor = true
			break
	_check(warned_about_floor, "Piso ausente gera aviso diagnóstico")
	wall_only.free()


func _benchmark_house(snapshot: StructureVisionSnapshot) -> void:
	var registry := VisionTopologyRegistry.new()
	registry.register_structure(snapshot)
	var profile := VisionProfile.new()
	var origin := snapshot.origin + Vector3i(1, 1, 0)
	var solver := VisionSolver.new()
	solver.solve(origin, Vector2i(1, 0), registry, profile)
	var iterations := 20
	var started := Time.get_ticks_usec()
	for _index in iterations:
		solver.solve(origin, Vector2i(1, 0), registry, profile)
	var average_ms := float(Time.get_ticks_usec() - started) / 1000.0 / iterations
	print("  PERF raio 18 (45 bordas): %.3f ms/invalidação" % average_ms)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

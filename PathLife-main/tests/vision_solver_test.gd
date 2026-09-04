## Testes adversariais do solver puro de visão.
## Uso: godot --headless --path . --script res://tests/vision_solver_test.gd
extends SceneTree

var _passed := 0
var _failed := 0
var _solver := VisionSolver.new()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[VisionSolver] cone e periferia")
	_test_cone_and_periphery()
	print("\n[VisionSolver] paredes e supercover")
	_test_walls_bidirectional()
	_test_all_corner_quadrants()
	print("\n[VisionSolver] portas e janelas")
	_test_window_contract()
	_test_door_depth()
	_test_portal_hop_limit()
	_test_opaque_overlap_wins()
	_test_closed_portal_overlap_wins()
	_test_snapshot_opaque_conflict_orders()
	print("\n[VisionSolver] estrutura selada")
	_test_sealed_memory()
	_test_open_window_connects_exterior()
	_benchmark_default_radius()
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_cone_and_periphery() -> void:
	var profile := _profile(8)
	profile.front_cone_degrees = 90.0
	profile.peripheral_range_cells = 2
	var result := _solver.solve(
		Vector3i.ZERO, Vector2i(1, 0), VisionTopologyRegistry.new(), profile
	)
	_check(result.is_visible(Vector3i(6, 0, 0)), "alvo frontal entra no cone")
	_check(not result.is_visible(Vector3i(-3, 0, 0)), "alvo traseiro distante sai do cone")
	_check(result.is_visible(Vector3i(-2, 0, 0)), "periferia enxerga duas células atrás")
	_check(result.is_visible(Vector3i(0, -2, 0)), "periferia é 360 graus")
	_check(not result.is_visible(Vector3i(0, -3, 0)), "periferia não ultrapassa duas células")
	_check(result.is_visible(Vector3i.ZERO), "célula do observador sempre é visível")


func _test_walls_bidirectional() -> void:
	var a := Vector3i.ZERO
	var b := Vector3i(1, 0, 0)
	var registry := _registry_with_wall(a, b)
	var profile := _profile(6)
	var from_a := _solver.solve(a, Vector2i(1, 0), registry, profile)
	var from_b := _solver.solve(b, Vector2i(-1, 0), registry, profile)
	_check(not from_a.is_visible(b), "parede bloqueia A → B")
	_check(not from_b.is_visible(a), "parede bloqueia B → A")
	_check(not _solver.has_line_of_sight(a, b, registry, profile), "LOS pública respeita parede")


func _test_all_corner_quadrants() -> void:
	var targets: Array[Vector3i] = [
		Vector3i(2, 2, 0), Vector3i(-2, 2, 0),
		Vector3i(2, -2, 0), Vector3i(-2, -2, 0),
	]
	for target: Vector3i in targets:
		var x_step := signi(target.x)
		var y_step := signi(target.y)
		var registry := _registry_with_wall(
			Vector3i.ZERO, Vector3i(x_step, 0, 0)
		)
		_check(
			not _solver.has_line_of_sight(Vector3i.ZERO, target, registry, _profile(8)),
			"canto exato bloqueia no quadrante %s" % target
		)
		var target_side_registry := _registry_with_wall(
			Vector3i(x_step, 0, 0), Vector3i(x_step, y_step, 0)
		)
		_check(
			not _solver.has_line_of_sight(
				Vector3i.ZERO, target, target_side_registry, _profile(8)
			),
			"canto bloqueia também pelo L no lado do alvo %s" % target
		)
	var transitions := _solver.supercover_transitions(Vector3i.ZERO, Vector3i(2, 2, 0))
	_check(transitions.size() == 8, "diagonal 2×2 testa quatro bordas por canto")
	_check(bool((transitions[0] as Dictionary).get("corner", false)), "transição diagonal é marcada como canto")


func _test_window_contract() -> void:
	var closed := _registry_with_portals([
		_make_portal(&"window-a", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), false),
	])
	var profile := _profile(12)
	_check(
		not _solver.has_line_of_sight(Vector3i.ZERO, Vector3i(1, 0, 0), closed, profile),
		"janela fechada é opaca"
	)
	var opened := _registry_with_portals([
		_make_portal(&"window-a", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), true),
	])
	_check(
		_solver.has_line_of_sight(Vector3i.ZERO, Vector3i(5, 0, 0), opened, profile),
		"janela aberta revela cinco células"
	)
	_check(
		not _solver.has_line_of_sight(Vector3i.ZERO, Vector3i(6, 0, 0), opened, profile),
		"janela aberta para na profundidade cinco"
	)
	_check(
		_solver.has_line_of_sight(Vector3i(1, 0, 0), Vector3i(-4, 0, 0), opened, profile),
		"janela transmite nos dois sentidos"
	)
	profile.open_window_transmission = 0.0
	_check(
		not _solver.has_line_of_sight(Vector3i.ZERO, Vector3i(1, 0, 0), opened, profile),
		"transmissão configurável zero torna janela opaca"
	)


func _test_door_depth() -> void:
	var registry := _registry_with_portals([
		_make_portal(&"door-a", &"door", Vector3i.ZERO, Vector3i(1, 0, 0), true),
	])
	var profile := _profile(12)
	_check(
		_solver.has_line_of_sight(Vector3i.ZERO, Vector3i(8, 0, 0), registry, profile),
		"porta aberta revela oito células"
	)
	_check(
		not _solver.has_line_of_sight(Vector3i.ZERO, Vector3i(9, 0, 0), registry, profile),
		"porta aberta para na profundidade oito"
	)


func _test_portal_hop_limit() -> void:
	var registry := _registry_with_portals([
		_make_portal(&"window-a", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), true),
		_make_portal(&"window-b", &"window", Vector3i(2, 0, 0), Vector3i(3, 0, 0), true),
	])
	var profile := _profile(8)
	profile.maximum_portal_hops = 1
	_check(
		not _solver.has_line_of_sight(Vector3i.ZERO, Vector3i(3, 0, 0), registry, profile),
		"duas janelas alinhadas não atravessam um hop"
	)
	profile.maximum_portal_hops = 2
	_check(
		_solver.has_line_of_sight(Vector3i.ZERO, Vector3i(3, 0, 0), registry, profile),
		"limite de hops é configurável"
	)


func _test_opaque_overlap_wins() -> void:
	var registry := VisionTopologyRegistry.new()
	var portal_snapshot := StructureVisionSnapshot.new()
	portal_snapshot.placement_id = 1
	var portal := _make_portal(
		&"overlap-window", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), true
	)
	portal.zone_a = 0
	portal.zone_b = VisionZone.EXTERIOR_ID
	portal_snapshot.add_floor(Vector2i.ZERO, &"room")
	var room := VisionZone.new()
	room.id = 0
	room.placement_id = portal_snapshot.placement_id
	room.is_exterior = false
	room.add_cell(Vector3i.ZERO)
	portal_snapshot.zones.append(room)
	portal_snapshot.cell_to_zone[Vector3i.ZERO] = 0
	portal_snapshot.internal_cells[Vector3i.ZERO] = true
	portal_snapshot.add_portal(
		portal,
		VisionEdge.create_portal(portal.cell_a, portal.cell_b, portal.id, 1)
	)
	registry.register_structure(portal_snapshot)
	var wall_snapshot := StructureVisionSnapshot.new()
	wall_snapshot.placement_id = 2
	wall_snapshot.add_edge(VisionEdge.create_wall(Vector3i.ZERO, Vector3i(1, 0, 0), 2))
	registry.register_structure(wall_snapshot)
	_check(
		not _solver.has_line_of_sight(
			Vector3i.ZERO, Vector3i(1, 0, 0), registry, _profile(5)
		),
		"parede opaca sobreposta vence portal aberto"
	)
	_check(
		not registry.can_zone_reach_exterior(1, 0, _profile(5)),
		"parede sobreposta também impede conexão do grafo ao exterior"
	)


func _test_closed_portal_overlap_wins() -> void:
	var registry := VisionTopologyRegistry.new()
	var room_snapshot := StructureVisionSnapshot.new()
	room_snapshot.placement_id = 20
	room_snapshot.add_floor(Vector2i.ZERO, &"room")
	var room := VisionZone.new()
	room.id = 0
	room.placement_id = room_snapshot.placement_id
	room.is_exterior = false
	room.add_cell(Vector3i.ZERO)
	room_snapshot.zones.append(room)
	room_snapshot.cell_to_zone[Vector3i.ZERO] = 0
	room_snapshot.internal_cells[Vector3i.ZERO] = true
	var open_portal := _make_portal(
		&"open-overlap", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), true
	)
	open_portal.placement_id = room_snapshot.placement_id
	open_portal.zone_a = 0
	open_portal.zone_b = VisionZone.EXTERIOR_ID
	room_snapshot.add_portal(
		open_portal,
		VisionEdge.create_portal(
			open_portal.cell_a,
			open_portal.cell_b,
			open_portal.id,
			room_snapshot.placement_id
		)
	)
	registry.register_structure(room_snapshot)

	var closed_snapshot := StructureVisionSnapshot.new()
	closed_snapshot.placement_id = 21
	var closed_portal := _make_portal(
		&"closed-overlap", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), false
	)
	closed_portal.placement_id = closed_snapshot.placement_id
	closed_snapshot.add_portal(
		closed_portal,
		VisionEdge.create_portal(
			closed_portal.cell_a,
			closed_portal.cell_b,
			closed_portal.id,
			closed_snapshot.placement_id
		)
	)
	registry.register_structure(closed_snapshot)
	var profile := _profile(5)
	_check(
		not _solver.has_line_of_sight(
			Vector3i.ZERO, Vector3i(1, 0, 0), registry, profile
		),
		"portal fechado sobreposto vence portal aberto no LOS"
	)
	_check(
		not registry.can_zone_reach_exterior(20, 0, profile),
		"portal fechado sobreposto preserva selamento no grafo"
	)


func _test_snapshot_opaque_conflict_orders() -> void:
	var a := Vector3i.ZERO
	var b := Vector3i(1, 0, 0)
	var portal_first := StructureVisionSnapshot.new()
	portal_first.placement_id = 10
	var displaced := _make_portal(&"displaced", &"window", a, b, true)
	portal_first.add_portal(
		displaced,
		VisionEdge.create_portal(a, b, displaced.id, portal_first.placement_id)
	)
	portal_first.add_edge(VisionEdge.create_wall(a, b, portal_first.placement_id))
	_check(
		not portal_first.portals.has(displaced.id),
		"parede posterior remove portal órfão do grafo"
	)
	_check(portal_first.edge_between(a, b).opaque, "parede posterior permanece efetiva")

	var wall_first := StructureVisionSnapshot.new()
	wall_first.placement_id = 11
	wall_first.add_edge(VisionEdge.create_wall(a, b, wall_first.placement_id))
	var rejected := _make_portal(&"rejected", &"window", a, b, true)
	var portal_added := wall_first.add_portal(
		rejected,
		VisionEdge.create_portal(a, b, rejected.id, wall_first.placement_id)
	)
	_check(not portal_added, "portal posterior é rejeitado pela parede existente")
	_check(not wall_first.portals.has(rejected.id), "portal rejeitado não entra no grafo")


func _test_sealed_memory() -> void:
	var registry := _sealed_one_cell_registry(false)
	var remembered := {Vector3i(3, 0, 0): true}
	var profile := _profile(6)
	profile.front_cone_degrees = 45.0
	var result := _solver.solve(
		Vector3i.ZERO, Vector2i(1, 0), registry, profile, remembered
	)
	_check(
		result.state_at(Vector3i(3, 0, 0)) == VisionState.FORCED_HIDDEN,
		"exterior já explorado vira FORCED_HIDDEN dentro da estrutura selada"
	)
	_check(
		not result.remembered_cells.has(Vector3i(3, 0, 0)),
		"memória exterior não vaza pela estrutura selada"
	)
	_check(result.is_visible(Vector3i.ZERO), "interior atual continua visível")
	_check(result.observer_placement_id == 300, "resultado identifica estrutura do observador")
	_check(result.observer_zone_id == 0, "resultado identifica cômodo atual")
	_check(result.observer_zone_cells.has(Vector3i.ZERO), "resultado transporta células do cômodo")
	_check(
		result.state_at(Vector3i(-1, 0, 0)) == VisionState.FORCED_HIDDEN,
		"faixa estrutural protege o fog também atrás do cone"
	)


func _test_open_window_connects_exterior() -> void:
	var registry := _sealed_one_cell_registry(true)
	var profile := _profile(6)
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(result.is_visible(Vector3i(1, 0, 0)), "janela aberta revela o exterior adjacente")
	_check(result.is_visible(Vector3i(5, 0, 0)), "janela aberta revela somente sua faixa de cinco")
	_check(not result.is_visible(Vector3i(6, 0, 0)), "faixa da janela não ultrapassa cinco")
	_check(result.traversed_portal_ids.has(&"sealed-window"), "resultado informa portal atravessado")
	profile.open_window_transmission = 0.0
	var opaque_result := _solver.solve(
		Vector3i.ZERO,
		Vector2i(1, 0),
		registry,
		profile,
		{Vector3i(1, 0, 0): true}
	)
	_check(
		opaque_result.state_at(Vector3i(1, 0, 0)) == VisionState.FORCED_HIDDEN,
		"transmissão zero também mantém a zona logicamente selada"
	)


func _benchmark_default_radius() -> void:
	var profile := _profile(18)
	profile.front_cone_degrees = 155.0
	profile.peripheral_range_cells = 2
	var registry := VisionTopologyRegistry.new()
	# Aquecimento excluído da medição para não contar carga/compilação de script.
	_solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	var iterations := 20
	var started := Time.get_ticks_usec()
	for index in iterations:
		_solver.solve(Vector3i(index, 0, 0), Vector2i(1, 0), registry, profile)
	var average_ms := float(Time.get_ticks_usec() - started) / 1000.0 / iterations
	print("  PERF raio 18 (sem bordas): %.3f ms/invalidação" % average_ms)


func _profile(maximum_range: int) -> VisionProfile:
	var profile := VisionProfile.new()
	profile.maximum_range_cells = maximum_range
	profile.front_cone_degrees = 360.0
	profile.peripheral_range_cells = 0
	profile.window_reveal_depth_cells = 5
	profile.door_reveal_depth_cells = 8
	profile.maximum_portal_hops = 1
	return profile


func _registry_with_wall(a: Vector3i, b: Vector3i) -> VisionTopologyRegistry:
	var snapshot := StructureVisionSnapshot.new()
	snapshot.placement_id = 100
	snapshot.add_edge(VisionEdge.create_wall(a, b, snapshot.placement_id))
	var registry := VisionTopologyRegistry.new()
	registry.register_structure(snapshot)
	return registry


func _registry_with_portals(portals: Array) -> VisionTopologyRegistry:
	var snapshot := StructureVisionSnapshot.new()
	snapshot.placement_id = 200
	for raw_portal: Variant in portals:
		var portal := raw_portal as VisionPortal
		portal.placement_id = snapshot.placement_id
		snapshot.add_portal(
			portal,
			VisionEdge.create_portal(
				portal.cell_a, portal.cell_b, portal.id, snapshot.placement_id
			)
		)
	var registry := VisionTopologyRegistry.new()
	registry.register_structure(snapshot)
	return registry


func _make_portal(
	id: StringName,
	kind: StringName,
	a: Vector3i,
	b: Vector3i,
	is_open: bool
) -> VisionPortal:
	var portal := VisionPortal.new()
	portal.id = id
	portal.kind = kind
	portal.cell_a = a
	portal.cell_b = b
	portal.is_open = is_open
	return portal


func _sealed_one_cell_registry(open_window: bool) -> VisionTopologyRegistry:
	var snapshot := StructureVisionSnapshot.new()
	snapshot.placement_id = 300
	snapshot.add_floor(Vector2i.ZERO, &"room")
	var zone := VisionZone.new()
	zone.id = 0
	zone.placement_id = snapshot.placement_id
	zone.is_exterior = false
	zone.add_cell(Vector3i.ZERO)
	snapshot.zones.append(zone)
	snapshot.cell_to_zone[Vector3i.ZERO] = 0
	snapshot.internal_cells[Vector3i.ZERO] = true
	for guard: Vector3i in [
		Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
		Vector3i(0, -1, 0), Vector3i(0, 1, 0),
	]:
		snapshot.exterior_guard_cells[guard] = true
	for neighbor: Vector3i in [
		Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0),
	]:
		snapshot.add_edge(VisionEdge.create_wall(Vector3i.ZERO, neighbor, 300))
	if open_window:
		var portal := _make_portal(
			&"sealed-window", &"window", Vector3i.ZERO, Vector3i(1, 0, 0), true
		)
		portal.placement_id = 300
		portal.zone_a = 0
		portal.zone_b = VisionZone.EXTERIOR_ID
		snapshot.add_portal(
			portal,
			VisionEdge.create_portal(
				portal.cell_a, portal.cell_b, portal.id, snapshot.placement_id
			)
		)
	else:
		snapshot.add_edge(
			VisionEdge.create_wall(Vector3i.ZERO, Vector3i(1, 0, 0), 300)
		)
	var registry := VisionTopologyRegistry.new()
	registry.register_structure(snapshot)
	return registry


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])

## Uso:
## Godot --headless --path . --script res://gameplay/vision/tests/vision_solver_test.gd
extends SceneTree

const STATE := preload("res://gameplay/vision/vision_state.gd")
const PROFILE := preload("res://gameplay/vision/vision_profile.gd")
const SOLVER := preload("res://gameplay/vision/vision_solver.gd")
const EDGE := preload("res://world_generation/visibility/vision_edge.gd")
const PORTAL := preload("res://world_generation/visibility/vision_portal.gd")
const ZONE := preload("res://world_generation/visibility/vision_zone.gd")
const SNAPSHOT := preload("res://world_generation/visibility/structure_vision_snapshot.gd")
const REGISTRY := preload("res://world_generation/visibility/vision_topology_registry.gd")

var _failures := 0
var _solver := SOLVER.new()


func _init() -> void:
	_run()


func _run() -> void:
	_test_cone_and_periphery()
	_test_opaque_edge()
	_test_conservative_corner()
	_test_window_depth_and_state()
	_test_portal_hop_limit()
	_test_sealed_structure_memory()
	_test_opening_unseals_structure()
	_finish()


func _profile() -> VisionProfile:
	var profile := PROFILE.new()
	profile.maximum_range_cells = 12
	profile.front_cone_degrees = 90.0
	profile.peripheral_range_cells = 0
	profile.maximum_portal_hops = 1
	profile.window_reveal_depth_cells = 5
	profile.door_reveal_depth_cells = 8
	return profile


func _test_cone_and_periphery() -> void:
	var profile := _profile()
	var registry := REGISTRY.new()
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(result.is_visible(Vector3i(4, 0, 0)), "cone revela à frente")
	_check(not result.is_visible(Vector3i(-4, 0, 0)), "cone oculta atrás")
	profile.peripheral_range_cells = 2
	result = _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(result.is_visible(Vector3i(-2, 0, 0)), "periferia revela duas células em 360 graus")


func _test_opaque_edge() -> void:
	var snapshot := _empty_snapshot(1)
	snapshot.add_edge(EDGE.create_wall(Vector3i(1, 0, 0), Vector3i(2, 0, 0), 1, &"se"))
	var registry := _registry_with(snapshot)
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, _profile())
	_check(result.is_visible(Vector3i(1, 0, 0)), "célula anterior à parede fica visível")
	_check(not result.is_visible(Vector3i(2, 0, 0)), "parede bloqueia a célula oposta")


func _test_conservative_corner() -> void:
	var snapshot := _empty_snapshot(2)
	snapshot.add_edge(EDGE.create_wall(Vector3i.ZERO, Vector3i(1, 0, 0), 2, &"se"))
	var transitions := _solver.supercover_transitions(Vector3i.ZERO, Vector3i(2, 2, 0))
	_check(transitions.size() == 8, "supercover diagonal testa quatro bordas por canto")
	var result := _solver.solve(
		Vector3i.ZERO, Vector2i(1, 1), _registry_with(snapshot), _profile()
	)
	_check(not result.is_visible(Vector3i(2, 2, 0)), "uma borda no canto bloqueia conservadoramente")


func _test_window_depth_and_state() -> void:
	var snapshot := _empty_snapshot(3)
	var window := _portal(
		&"3|1,0|se|window",
		PORTAL.WINDOW,
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		3,
		false
	)
	_add_portal(snapshot, window)
	var registry := _registry_with(snapshot)
	var profile := _profile()
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(not result.is_visible(Vector3i(3, 0, 0)), "janela fechada é opaca")
	_check(registry.set_portal_open(window.id, true), "janela mutável abre pelo registry")
	result = _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(result.is_visible(Vector3i(6, 0, 0)), "janela aberta revela até cinco células")
	_check(not result.is_visible(Vector3i(7, 0, 0)), "janela limita profundidade após a abertura")
	_check(result.traversed_portal_ids.has(window.id), "resultado registra portal atravessado")


func _test_portal_hop_limit() -> void:
	var snapshot := _empty_snapshot(4)
	var first := _portal(
		&"4|1,0|se|door", PORTAL.DOOR,
		Vector3i(1, 0, 0), Vector3i(2, 0, 0), 4, true
	)
	var second := _portal(
		&"4|3,0|se|door", PORTAL.DOOR,
		Vector3i(3, 0, 0), Vector3i(4, 0, 0), 4, true
	)
	_add_portal(snapshot, first)
	_add_portal(snapshot, second)
	var registry := _registry_with(snapshot)
	var profile := _profile()
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(not result.is_visible(Vector3i(5, 0, 0)), "um raio não atravessa dois portais por padrão")
	profile.maximum_portal_hops = 2
	result = _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, profile)
	_check(result.is_visible(Vector3i(5, 0, 0)), "limite de portais é ajustável")


func _test_sealed_structure_memory() -> void:
	var snapshot := _room_snapshot(5, false)
	var registry := _registry_with(snapshot)
	var memory := {Vector3i(5, 0, 0): true}
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, _profile(), memory)
	_check(
		result.state_at(Vector3i(5, 0, 0)) == STATE.FORCED_HIDDEN,
		"estrutura selada sobrepõe a memória exterior"
	)
	_check(result.is_visible(Vector3i(1, 0, 0)), "interior atual permanece visível")
	_check(
		(result.visible_interior_by_structure[5] as Dictionary).has(Vector3i(1, 0, 0)),
		"resultado agrupa interior visível por placement"
	)


func _test_opening_unseals_structure() -> void:
	var snapshot := _room_snapshot(6, true)
	var registry := _registry_with(snapshot)
	var memory := {Vector3i(3, 0, 0): true}
	var result := _solver.solve(Vector3i.ZERO, Vector2i(1, 0), registry, _profile(), memory)
	_check(result.is_visible(Vector3i(3, 0, 0)), "janela exterior aberta revela de dentro para fora")
	_check(result.state_at(Vector3i(3, 0, 0)) != STATE.FORCED_HIDDEN, "abertura remove ocultamento forçado")


func _empty_snapshot(placement_id: int) -> StructureVisionSnapshot:
	var snapshot := SNAPSHOT.new()
	snapshot.placement_id = placement_id
	return snapshot


func _registry_with(snapshot: StructureVisionSnapshot) -> VisionTopologyRegistry:
	var registry := REGISTRY.new()
	registry.register_structure(snapshot)
	return registry


func _portal(
	id: StringName,
	kind: StringName,
	a: Vector3i,
	b: Vector3i,
	placement_id: int,
	is_open: bool
) -> VisionPortal:
	var portal := PORTAL.new()
	portal.id = id
	portal.kind = kind
	portal.cell_a = a
	portal.cell_b = b
	portal.placement_id = placement_id
	portal.is_open = is_open
	return portal


func _add_portal(snapshot: StructureVisionSnapshot, portal: VisionPortal) -> void:
	snapshot.add_portal(
		portal,
		EDGE.create_portal(
			portal.cell_a, portal.cell_b, portal.id, portal.placement_id, &"se"
		)
	)


func _room_snapshot(placement_id: int, open_to_outside: bool) -> StructureVisionSnapshot:
	var snapshot := _empty_snapshot(placement_id)
	for x in 2:
		var cell := Vector3i(x, 0, 0)
		snapshot.floor_cells[cell] = true
		snapshot.local_floor_cells[Vector2i(x, 0)] = true
		snapshot.floor_environments[cell] = &"sala"
		snapshot.cell_to_zone[cell] = 0
	var zone := ZONE.new()
	zone.id = 0
	zone.placement_id = placement_id
	zone.add_cell(Vector3i(0, 0, 0))
	zone.add_cell(Vector3i(1, 0, 0))
	snapshot.zones.append(zone)
	# A abertura ocupa a borda leste do último piso e liga à zona exterior.
	var window := _portal(
		StringName("%d|1,0|se|window" % placement_id),
		PORTAL.WINDOW,
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		placement_id,
		open_to_outside
	)
	window.zone_a = 0
	window.zone_b = ZONE.EXTERIOR_ID
	_add_portal(snapshot, window)
	return snapshot


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		_failures += 1
		printerr("[FALHA] ", label)


func _finish() -> void:
	if _failures == 0:
		print("\nVISION SOLVER TEST: OK")
		quit(0)
	else:
		printerr("\nVISION SOLVER TEST: %d falha(s)" % _failures)
		quit(1)

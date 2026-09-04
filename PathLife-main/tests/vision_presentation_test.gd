## Teste headless do adaptador e dos componentes visuais de visão.
## Uso: godot --headless --path . --script res://tests/vision_presentation_test.gd
extends SceneTree

const ResultData = preload("res://gameplay/vision/vision_result.gd")
const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const OverlayScene = preload("res://presentation/world/visibility/vision_overlay.tscn")
const HouseScene = preload("res://presentation/world/structures/casa_madeira_tilemap.tscn")
const VisibilityTargetScript = preload(
	"res://presentation/world/visibility/vision_visibility_target.gd"
)


class MovingVisionSource:
	extends Node
	var logical_cell := Vector3i.ZERO

	func world_position() -> Vector3i:
		return logical_cell


class ProjectionManager:
	extends Node
	var settings: WorldSettings

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_result_priority_and_aliases()
	await _test_overlay_and_local_roofs()
	await _test_wall_only_auto_cutaway()
	await _test_invalid_roof_fails_closed()
	await _test_dynamic_target()
	await _test_profile_and_projection_refresh()
	if _failures == 0:
		print("[VisionPresentationTest] PASS")
		quit(0)
	else:
		printerr("[VisionPresentationTest] FAIL: %d erro(s)" % _failures)
		quit(1)


func _test_result_priority_and_aliases() -> void:
	var cell := Vector3i(4, 5, 0)
	var extracted := ResultView.extract({
		"visible_cells": {cell: true},
		"remembered_cells": {cell: true},
		"forced_hidden_cells": {cell: true},
	})
	_check((extracted[&"visible"] as Dictionary).has(cell), "VISIBLE é extraído")
	_check(
		not (extracted[&"remembered"] as Dictionary).has(cell),
		"VISIBLE vence REMEMBERED"
	)
	_check(
		not (extracted[&"forced_hidden"] as Dictionary).has(cell),
		"VISIBLE vence FORCED_HIDDEN"
	)
	var domain_result := ResultData.new()
	domain_result.states[cell] = 2
	domain_result.rebuild_indexes()
	var domain_extracted := ResultView.extract(domain_result)
	_check(
		(domain_extracted[&"forced_hidden"] as Dictionary).has(cell),
		"estado numérico 2 continua FORCED_HIDDEN"
	)
	_check(
		not (domain_extracted[&"visible"] as Dictionary).has(cell),
		"FORCED_HIDDEN numérico não vaza como VISIBLE"
	)


func _test_overlay_and_local_roofs() -> void:
	var overlay := OverlayScene.instantiate() as VisibilityPresenter
	root.add_child(overlay)
	await process_frame
	_check(overlay.mask_texture() != null, "overlay cria sua textura de máscara")
	_test_mask_renderer_projection_and_culling(overlay._mask_renderer)

	var first_house := HouseScene.instantiate() as Node2D
	var second_house := HouseScene.instantiate() as Node2D
	root.add_child(first_house)
	root.add_child(second_house)
	await process_frame

	var first_origin := Vector3i(100, 100, 0)
	var second_origin := Vector3i(200, 200, 0)
	var first_controller := overlay.register_structure(first_house, 101, first_origin)
	var second_controller := overlay.register_structure(second_house, 202, second_origin)
	await process_frame
	_check(first_controller != null and first_controller.is_ready_for_results(), "primeiro telhado configurado")
	_check(second_controller != null and second_controller.is_ready_for_results(), "segundo telhado configurado")

	var result := ResultData.new()
	var revealed_cell := first_origin
	result.mark_visible(revealed_cell)
	result.mark_interior_visible(101, revealed_cell)
	result.visible_interior_by_structure[202] = {}
	var baked := StructureVisionBaker.new().bake(first_house, 101, first_origin)
	var current_zone: VisionZone
	var expected_low: Dictionary = {}
	for candidate: VisionZone in baked.internal_zones():
		var candidate_low := _expected_low_wall_cells(first_controller, candidate.cells)
		if not candidate_low.is_empty():
			current_zone = candidate
			expected_low = candidate_low
			break
	_check(current_zone != null, "fixture possui paredes frontais num cômodo interno")
	if current_zone == null:
		current_zone = baked.internal_zones()[0] as VisionZone
	result.observer_placement_id = 101
	result.observer_zone_id = current_zone.id
	result.observer_zone_cells = current_zone.cells.duplicate()
	overlay.set_result(result, true)
	await process_frame

	var first_roof := first_house.get_node(^"Telhado") as TileMapLayer
	var second_roof := second_house.get_node(^"Telhado") as TileMapLayer
	var first_material := first_roof.material as ShaderMaterial
	var second_material := second_roof.material as ShaderMaterial
	_check(first_material != null and second_material != null, "cada telhado recebe material")
	if first_material != null and second_material != null:
		var first_texture := first_material.get_shader_parameter(&"reveal_mask") as ImageTexture
		var second_texture := second_material.get_shader_parameter(&"reveal_mask") as ImageTexture
		_check(first_texture != second_texture, "telhados não compartilham máscara")
		if first_texture != null and second_texture != null:
			var first_image := first_texture.get_image()
			var second_image := second_texture.get_image()
			_check(
				first_controller.mask_value_at_local_cell(Vector2i.ZERO) > 0.9,
				"célula interna aparece apenas na primeira máscara"
			)
			_check(second_image.get_pixel(0, 0).r < 0.1, "segunda máscara permanece opaca")
	var actual_low: Dictionary = {}
	for local_cell: Variant in first_house._automatic_wall_rows:
		if int(first_house._automatic_wall_rows[local_cell]) == 0:
			actual_low[local_cell] = true
	_check(actual_low == expected_low, "AUTO reduz somente paredes do cômodo atual")

	var roof_actor := Node2D.new()
	roof_actor.add_to_group(&"depth_actor")
	root.add_child(roof_actor)
	first_house._on_roof_body_entered(roof_actor)
	first_controller.set_vision_enabled(false)
	_check(not first_house.is_roof_visible(), "fallback conhece ator que entrou durante visão ativa")
	first_controller.set_vision_enabled(true)
	roof_actor.global_position = Vector2(100000.0, 100000.0)
	first_house._on_roof_body_exited(roof_actor)
	await process_frame
	await process_frame
	roof_actor.queue_free()

	overlay.queue_free()
	first_house.queue_free()
	second_house.queue_free()
	await process_frame


func _test_mask_renderer_projection_and_culling(
	renderer: VisibilityMaskRenderer
) -> void:
	if renderer == null:
		_check(false, "renderer da máscara está disponível")
		return
	var cell := Vector3i(3, 4, 1)
	var to_screen := Transform2D(
		Vector2(1.25, 0.2),
		Vector2(-0.1, 0.75),
		Vector2(14.0, -9.0)
	)
	var half := Vector2(renderer.tile_size) * 0.5
	var rise := Vector2(0.0, -float(renderer.visual_reveal_height_px))
	var center := renderer._iso.world_to_local(cell)
	var local_points := PackedVector2Array([
		center + Vector2(0.0, -half.y) + rise,
		center + Vector2(half.x, 0.0) + rise,
		center + Vector2(half.x, 0.0),
		center + Vector2(0.0, half.y),
		center + Vector2(-half.x, 0.0),
		center + Vector2(-half.x, 0.0) + rise,
	])
	var polygon := renderer._cell_polygon(cell, to_screen, half, rise)
	var projection_matches := polygon.size() == local_points.size()
	for index in mini(polygon.size(), local_points.size()):
		var expected := (to_screen * local_points[index]) * renderer.mask_resolution_scale
		projection_matches = projection_matches and polygon[index].is_equal_approx(expected)
	_check(projection_matches, "máscara preserva os seis vértices projetados")

	var inside := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(8.0, 0.0),
		Vector2(0.0, 8.0),
	])
	var outside_origin := Vector2(renderer._mask_viewport.size) + Vector2(10.0, 10.0)
	var outside := PackedVector2Array([
		outside_origin,
		outside_origin + Vector2(8.0, 0.0),
		outside_origin + Vector2(0.0, 8.0),
	])
	var degenerate := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(4.0, 4.0),
		Vector2(8.0, 8.0),
	])
	_check(renderer._polygon_intersects_mask(inside), "culling mantém polígono na máscara")
	_check(not renderer._polygon_intersects_mask(outside), "culling rejeita polígono fora da máscara")
	_check(not renderer._polygon_intersects_mask(degenerate), "culling rejeita polígono degenerado")


func _test_wall_only_auto_cutaway() -> void:
	var overlay := OverlayScene.instantiate() as VisibilityPresenter
	root.add_child(overlay)
	await process_frame
	var house := HouseScene.instantiate() as StructureRoot
	var roof := house.get_node_or_null(^"Telhado")
	if roof != null:
		house.remove_child(roof)
		roof.free()
	root.add_child(house)
	await process_frame
	var origin := Vector3i(300, 300, 0)
	var controller := overlay.register_structure(house, 303, origin)
	await process_frame
	_check(controller != null, "estrutura sem telhado ainda registra controle AUTO")
	_check(
		controller != null and controller.is_ready_for_results(),
		"controle de paredes funciona sem máscara de telhado"
	)
	if controller != null:
		var baked := StructureVisionBaker.new().bake(house, 303, origin)
		var zone: VisionZone
		var expected_low: Dictionary = {}
		for candidate: VisionZone in baked.internal_zones():
			var candidate_low := _expected_low_wall_cells(controller, candidate.cells)
			if not candidate_low.is_empty():
				zone = candidate
				expected_low = candidate_low
				break
		_check(zone != null, "fixture sem telhado mantém cômodo com paredes frontais")
		if zone != null:
			var result := ResultData.new()
			result.observer_placement_id = 303
			result.observer_zone_id = zone.id
			result.observer_zone_cells = zone.cells.duplicate()
			overlay.set_result(result, true)
			var actual_low: Dictionary = {}
			for local_cell: Variant in house._automatic_wall_rows:
				if int(house._automatic_wall_rows[local_cell]) == 0:
					actual_low[local_cell] = true
			_check(actual_low == expected_low, "AUTO recorta paredes mesmo sem Telhado")
	overlay.queue_free()
	house.queue_free()
	await process_frame


func _test_invalid_roof_fails_closed() -> void:
	var structure := Node2D.new()
	var roof := TileMapLayer.new()
	roof.name = "Telhado"
	roof.visible = false
	structure.add_child(roof)
	root.add_child(structure)
	var controller := RoofRevealController.new()
	controller.configure(structure, 404, Vector3i.ZERO)
	structure.add_child(controller)
	await process_frame
	_check(roof.visible, "máscara inválida força telhado opaco e visível")
	controller.set_vision_enabled(false)
	_check(not roof.visible, "desabilitar visão restaura visibilidade autoral")
	controller.set_vision_enabled(true)
	_check(roof.visible, "reativar visão volta ao fallback fechado")
	structure.queue_free()
	await process_frame


func _test_dynamic_target() -> void:
	var actor := Node2D.new()
	root.add_child(actor)
	var target := VisibilityTargetScript.new() as VisionVisibilityTarget
	actor.add_child(target)
	target.set_logical_position(Vector3i(8, 9, 0))
	await process_frame

	var visible_result := ResultData.new()
	visible_result.mark_visible(Vector3i(8, 9, 0))
	target.set_result(visible_result)
	_check(actor.visible, "entidade VISIBLE é desenhada")

	var hidden_result := ResultData.new()
	target.set_result(hidden_result)
	_check(not actor.visible, "entidade fora de VISIBLE é ocultada")
	_check(actor.process_mode == Node.PROCESS_MODE_INHERIT, "visão não pausa a entidade")
	target.enabled = false
	_check(actor.visible, "desabilitar componente restaura visibilidade autoral")
	target.enabled = true
	_check(not actor.visible, "reativar componente reaplica o último resultado")
	target.set_result(null)
	_check(actor.visible, "limpar resultado restaura visibilidade da entidade")
	actor.queue_free()
	await process_frame

	var overlay := OverlayScene.instantiate() as VisibilityPresenter
	root.add_child(overlay)
	await process_frame
	var first_cell := Vector3i(2, 3, 0)
	var moving_result := ResultData.new()
	moving_result.mark_visible(first_cell)
	overlay.set_result(moving_result, true)
	var moving_actor := Node2D.new()
	var source := MovingVisionSource.new()
	source.logical_cell = first_cell
	var moving_target := VisibilityTargetScript.new() as VisionVisibilityTarget
	moving_actor.add_child(source)
	moving_actor.add_child(moving_target)
	moving_target.configure(moving_actor, source)
	root.add_child(moving_actor)
	await process_frame
	await process_frame
	_check(moving_actor.visible, "entidade tardia recebe o último resultado automaticamente")
	source.logical_cell = Vector3i(20, 20, 0)
	await process_frame
	_check(not moving_actor.visible, "entidade móvel reavalia visão ao trocar de célula")
	overlay.clear()
	_check(moving_actor.visible, "limpar presenter restaura alvos dinâmicos")
	moving_actor.queue_free()
	overlay.queue_free()
	await process_frame


func _test_profile_and_projection_refresh() -> void:
	var profile := VisionProfile.new()
	var manager := ProjectionManager.new()
	manager.settings = WorldSettings.new()
	manager.settings.tile_size = Vector2i(96, 48)
	manager.settings.height_pixels = 19
	root.add_child(manager)
	var overlay := OverlayScene.instantiate() as VisibilityPresenter
	root.add_child(overlay)
	await process_frame
	overlay.configure(null, null, profile, manager)
	_check(overlay._mask_renderer.tile_size == Vector2i(96, 48), "máscara usa tile_size do mundo")
	_check(overlay._mask_renderer.height_pixels == 19, "máscara usa altura de nível do mundo")
	profile.mask_resolution_scale = 0.75
	profile.enabled = false
	overlay.apply_profile_changes(profile)
	_check(is_equal_approx(overlay._mask_renderer.mask_resolution_scale, 0.75), "profile visual reaplica resolução")
	_check(not overlay.enabled, "profile visual alterna fallback em runtime")
	overlay.queue_free()
	manager.queue_free()
	await process_frame


func _expected_low_wall_cells(
	controller: RoofRevealController,
	zone_cells: Dictionary
) -> Dictionary:
	var expected: Dictionary = {}
	for descriptor: Dictionary in controller._wall_descriptors:
		var direction := String(descriptor[&"direction"])
		var local_cell := descriptor[&"cell"] as Vector2i
		var world_a := Vector3i(
			controller.world_origin.x + local_cell.x,
			controller.world_origin.y + local_cell.y,
			controller.world_origin.z
		)
		var delta := controller._direction_offset(direction)
		var world_b := world_a + Vector3i(delta.x, delta.y, 0)
		if (
			(direction in ["se", "sw"] and zone_cells.has(world_a))
			or (direction in ["ne", "nw"] and zone_cells.has(world_b))
		):
			expected[local_cell] = true
	return expected


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [OK] %s" % label)
		return
	_failures += 1
	printerr("  [ERRO] %s" % label)

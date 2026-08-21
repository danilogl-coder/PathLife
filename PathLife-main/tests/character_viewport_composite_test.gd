## Trava de regressão do agrupamento visual do personagem.
## Uso:
##   godot --headless --path . --script res://tests/character_viewport_composite_test.gd
extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   ", label)
	else:
		_failed += 1
		printerr("  FALHA ", label, " ", detail)


func _run() -> void:
	var world := Node2D.new()
	world.y_sort_enabled = true
	root.add_child(world)
	var player := (load("res://gameplay/player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	for frame in 4:
		await process_frame

	var composite := player.get_node_or_null(^"VisualAnchor") as CharacterViewportComposite
	_check(composite != null, "VisualAnchor usa composição por SubViewport")
	if composite == null:
		_finish()
		return

	var visual := player.get_node_or_null(
		^"VisualAnchor/CharacterViewport/CharacterStage/CharacterVisual"
	) as CharacterVisual
	_check(visual != null, "rig continua acessível para animação e personalização")
	_check(composite.character_viewport.transparent_bg,
		"viewport do rig preserva transparência")
	_check(composite.composite_sprite.texture == composite.character_viewport.get_texture(),
		"sprite do mundo usa a textura viva do viewport")
	_check(composite.composite_sprite.z_index == 0,
		"personagem composto permanece no mesmo z_index das faces")
	_check(composite.character_viewport.is_ancestor_of(visual),
		"todas as partes de Z interno ficam isoladas do canvas do mundo")
	_check(
		(composite.character_stage.position
		+ composite.character_viewport.canvas_transform.origin).is_equal_approx(
			composite.texture_foot
		),
		"stage e canvas se compensam sem mover o desenho"
	)

	var stage_before := composite.character_stage.position
	player.global_position += Vector2(64.0, -32.0)
	await physics_frame
	await process_frame
	_check(
		(composite.character_stage.position - stage_before).is_equal_approx(
			Vector2(64.0, -32.0)
		),
		"stage interno recebe o movimento real para cabelo e saia",
		str(composite.character_stage.position - stage_before)
	)
	_check(
		(composite.character_stage.position
		+ composite.character_viewport.canvas_transform.origin).is_equal_approx(
			composite.texture_foot
		),
		"composição continua imóvel dentro da textura depois do movimento"
	)

	_finish()


func _finish() -> void:
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

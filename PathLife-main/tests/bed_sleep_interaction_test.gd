extends SceneTree

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	_expect(InputMap.has_action(&"interact"), "A ação interact precisa existir no Input Map.")
	var interact_has_e := false
	for input_event: InputEvent in InputMap.action_get_events(&"interact"):
		var key_event := input_event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_E:
			interact_has_e = true
			break
	_expect(interact_has_e, "A ação interact precisa estar vinculada à tecla E.")

	var bed_scene := load("res://gameplay/furniture/bed/bed_r0.tscn") as PackedScene
	var player_scene := load("res://gameplay/player/player.tscn") as PackedScene
	_expect(bed_scene != null, "A cena da cama precisa carregar.")
	_expect(player_scene != null, "A cena do Player precisa carregar.")
	if bed_scene == null or player_scene == null:
		_finish(world)
		return

	var bed := bed_scene.instantiate() as BedFurniture
	var player := player_scene.instantiate() as PlayerController
	world.add_child(bed)
	world.add_child(player)
	bed.position = Vector2(300, 200)
	player.position = bed.position + Vector2(25, 12)

	await physics_frame
	await physics_frame

	var interactor := player.get_node("BedSleepInteractor") as BedSleepInteractor
	var visual_anchor := player.get_node("VisualAnchor") as Node2D
	var visual := player.get_node("VisualAnchor/CharacterViewport/CharacterStage/CharacterVisual") as CharacterVisual
	var blanket := bed.get_node("Visual/BedFront") as Sprite2D
	var original_visual_position := visual_anchor.position
	var original_visual_rotation := visual_anchor.rotation
	var original_visual_scale := visual_anchor.scale
	var interaction_position := player.global_position
	_expect(interactor.get_nearby_bed_count() == 1,
		"O detector precisa encontrar a cama próxima.")
	_expect(interactor.try_sleep(), "A interação precisa iniciar o sono.")
	await process_frame

	_expect(player.is_sleeping(), "O Player precisa entrar no estado de sono.")
	_expect(interactor.get_current_bed() == bed, "A cama atual precisa ser preservada.")
	_expect(player.global_position.is_equal_approx(bed.get_sleep_position()),
		"O Player precisa ser posicionado no SleepCenter.")
	_expect(player.collision_layer == 0 and player.collision_mask == 0,
		"A colisão corporal precisa ficar suspensa durante o sono.")
	_expect(player.z_index == 2, "O Player precisa permanecer visível sobre a cama.")
	_expect(bed.is_occupied(), "A cama precisa ficar ocupada durante o sono.")
	_expect(blanket.visible, "O lençol precisa aparecer quando o Player deita.")
	_expect(blanket.z_index > player.z_index,
		"O lençol precisa ser desenhado acima do Player.")
	_expect(visual_anchor.position.is_equal_approx(bed.get_sleep_visual_offset()),
		"O deslocamento visual da orientação da cama precisa ser aplicado.")
	_expect(is_equal_approx(visual_anchor.rotation, bed.get_sleep_visual_rotation()),
		"A rotação visual da orientação da cama precisa ser aplicada.")
	_expect(visual_anchor.scale.is_equal_approx(bed.get_sleep_visual_scale()),
		"A escala visual da orientação da cama precisa ser aplicada.")
	var expected_masc_animation := StringName(
		"masc/sleep_%s" % bed.get_sleep_animation_direction_for(interaction_position)
	)
	_expect(visual.animation_player.assigned_animation == expected_masc_animation,
		"A animação masculina configurada pela cama precisa estar ativa.")

	await physics_frame
	Input.action_press(&"move_right")
	await physics_frame
	Input.action_release(&"move_right")

	_expect(not player.is_sleeping(), "Movimento precisa retirar o Player da cama.")
	_expect(not interactor.is_sleeping(), "O interator precisa encerrar o sono.")
	_expect(player.global_position.is_equal_approx(interaction_position),
		"O Player precisa reaparecer exatamente onde interagiu com a cama.")
	_expect(player.collision_layer == 2 and player.collision_mask == 9,
		"As camadas físicas precisam ser restauradas.")
	_expect(player.z_index == 0, "O Z normal do Player precisa ser restaurado.")
	_expect(not bed.is_occupied(), "A cama precisa ficar livre ao levantar.")
	_expect(not blanket.visible, "O lençol precisa sumir quando o Player levanta.")
	_expect(visual_anchor.position.is_equal_approx(original_visual_position),
		"A posição do VisualAnchor precisa ser restaurada ao levantar.")
	_expect(is_equal_approx(visual_anchor.rotation, original_visual_rotation),
		"A rotação do VisualAnchor precisa ser restaurada ao levantar.")
	_expect(visual_anchor.scale.is_equal_approx(original_visual_scale),
		"A escala do VisualAnchor precisa ser restaurada ao levantar.")
	_expect(not String(visual.animation_player.assigned_animation).contains("sleep_"),
		"Ao levantar, a animação de sono precisa ser encerrada.")

	visual.present_body("fem")
	player.position = bed.position + Vector2(25, 12)
	var female_interaction_position := player.global_position
	await physics_frame
	await physics_frame
	_expect(interactor.try_sleep(), "O corpo feminino também precisa conseguir dormir.")
	await process_frame
	var expected_fem_animation := StringName(
		"fem/sleep_%s" % bed.get_sleep_animation_direction_for(female_interaction_position)
	)
	_expect(visual.animation_player.assigned_animation == expected_fem_animation,
		"A animação feminina configurada pela cama precisa estar ativa.")
	interactor.leave_bed()
	_expect(player.global_position.is_equal_approx(female_interaction_position),
		"A saída manual também precisa restaurar a posição de interação.")

	_finish(world)


func _finish(world: Node2D) -> void:
	Input.action_release(&"move_right")
	world.queue_free()
	if _failures == 0:
		print("BED_SLEEP_INTERACTION_OK")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)

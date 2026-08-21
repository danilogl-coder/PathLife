extends SceneTree

const LIBRARY_PATH := "res://presentation/characters/cutout/animation/animacoes_masc.tres"
const FEM_LIBRARY_PATH := "res://presentation/characters/cutout/animation/animacoes_fem.tres"
const VISUAL_SCENE_PATH := "res://presentation/characters/cutout/character_visual.tscn"
const PLAYER_SCENE_PATH := "res://gameplay/player/player.tscn"
const HIP_POSITION_PATH := NodePath("Skeleton2D/quadril:position")
const HIP_ROTATION_PATH := NodePath("Skeleton2D/quadril:rotation")
const VISUAL_Y_PATH := NodePath(".:position:y")

var _failed := false


func _init() -> void:
	var library := load(LIBRARY_PATH) as AnimationLibrary
	_assert(library != null, "Biblioteca masculina não carregou.")
	if library == null:
		quit(1)
		return

	var fem_library := load(FEM_LIBRARY_PATH) as AnimationLibrary
	_assert(fem_library != null, "Biblioteca feminina não carregou.")
	_validate_library(library, &"masc")
	_validate_crouch_idle_library(library, &"masc")
	_validate_crouch_walk_library(library, &"masc")
	if fem_library != null:
		_validate_library(fem_library, &"fem")
		_validate_crouch_idle_library(fem_library, &"fem")
		_validate_crouch_walk_library(fem_library, &"fem")
		_validate_gender_copies(library, fem_library)

	var visual_scene := load(VISUAL_SCENE_PATH) as PackedScene
	var visual := visual_scene.instantiate() as CharacterVisual
	root.add_child(visual)
	await process_frame

	for body_type: String in ["masc", "fem"]:
		visual.present_body(body_type)
		for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
			visual.present_locomotion(direction, false, false)
			visual.present_crouch(true)
			_assert(
				visual.animation_player.assigned_animation == StringName(
					"%s/croushed_%s" % [body_type, direction]
				),
				"Agachamento incorreto para %s/%s." % [body_type, direction]
			)
			visual.present_crouch(false)

	visual.queue_free()
	await _validate_ctrl_input()
	if _failed:
		quit(1)
		return
	print("CROUSHED_MIRROR_TEST_OK")
	quit()


func _validate_library(library: AnimationLibrary, body_type: StringName) -> void:
	for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
		var animation_name := StringName("croushed_%s" % direction)
		var idle_name := StringName("idle_%s" % direction)
		_assert(library.has_animation(animation_name), "%s/%s ausente." % [body_type, animation_name])
		var animation := library.get_animation(animation_name)
		var idle := library.get_animation(idle_name)
		if animation == null or idle == null:
			continue
		_assert(
			animation.find_track(HIP_POSITION_PATH, Animation.TYPE_VALUE) < 0,
			"%s/%s sobrescreve a posição direcional do quadril." % [body_type, animation_name]
		)
		_assert(
			animation.find_track(VISUAL_Y_PATH, Animation.TYPE_VALUE) >= 0,
			"%s/%s não possui descida visual." % [body_type, animation_name]
		)
		for idle_track in idle.get_track_count():
			var path := idle.track_get_path(idle_track)
			var type := idle.track_get_type(idle_track)
			_assert(
				animation.find_track(path, type) >= 0,
				"%s/%s não herdou de %s: %s" % [body_type, animation_name, idle_name, path]
			)
		_assert(
			animation.find_track(HIP_ROTATION_PATH, Animation.TYPE_VALUE) >= 0,
			"%s/%s não recebeu a rotação do quadril." % [body_type, animation_name]
		)
		for track in animation.get_track_count():
			if not String(animation.track_get_path(track)).ends_with(":rotation"):
				continue
			for key in animation.track_get_key_count(track):
				var rotation_value := float(animation.track_get_key_value(track, key))
				_assert(
					is_finite(rotation_value) and absf(rotation_value) <= TAU,
					"Rotação inválida em %s/%s: %s" % [body_type, animation_name, rotation_value]
				)


func _validate_ctrl_input() -> void:
	var ctrl_is_configured := false
	for event: InputEvent in InputMap.action_get_events("crouch"):
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_CTRL:
			ctrl_is_configured = true
	_assert(ctrl_is_configured, "A ação crouch não está configurada na tecla Ctrl.")

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate() as PlayerController
	root.add_child(player)
	await physics_frame
	Input.action_press("crouch")
	await physics_frame
	_assert(player.is_crouching(), "Ctrl não ativou o estado de agachamento.")
	var visual := player.get_node("VisualAnchor/CharacterViewport/CharacterStage/CharacterVisual") as CharacterVisual
	_assert(
		visual.animation_player.assigned_animation == &"masc/croushed_se",
		"Ctrl não reproduziu masc/croushed_se."
	)
	visual.animation_player.advance(visual.animation_player.current_animation_length + 0.01)
	_assert(
		visual.animation_player.assigned_animation == &"masc/crouch_idle_se",
		"Terminar croushed_se não ativou crouch_idle_se."
	)
	var position_before_walk := player.global_position
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	_assert(
		player.global_position != position_before_walk,
		"Ctrl + movimento não deslocou o personagem."
	)
	_assert(
		is_equal_approx(
			player.velocity.length(),
			player.config.movement_speed * player.config.crouch_speed_multiplier
		),
		"A caminhada agachada não usou a velocidade reduzida."
	)
	_assert(
		visual.animation_player.assigned_animation == &"masc/crouch_walk_se",
		"Ctrl + movimento não reproduziu masc/crouch_walk_se."
	)
	Input.action_release("move_right")
	await physics_frame
	_assert(
		visual.animation_player.assigned_animation == &"masc/crouch_idle_se",
		"Parar com Ctrl pressionado não ativou crouch_idle_se."
	)
	Input.action_release("crouch")
	await physics_frame
	_assert(not player.is_crouching(), "Soltar Ctrl não encerrou o agachamento.")
	_assert(
		visual.animation_player.assigned_animation == &"masc/idle_se",
		"Soltar Ctrl não restaurou idle_se."
	)
	player.queue_free()


func _validate_gender_copies(masc: AnimationLibrary, fem: AnimationLibrary) -> void:
	for animation_name: StringName in [
		&"croushed_ne",
		&"croushed_nw",
		&"croushed_se",
		&"croushed_sw",
		&"crouch_walk_ne",
		&"crouch_walk_nw",
		&"crouch_walk_se",
		&"crouch_walk_sw",
		&"crouch_idle_ne",
		&"crouch_idle_nw",
		&"crouch_idle_se",
		&"crouch_idle_sw",
	]:
		var source := masc.get_animation(animation_name)
		var target := fem.get_animation(animation_name)
		_assert(source != null and target != null, "Cópia feminina ausente: %s" % animation_name)
		if source == null or target == null:
			continue
		_assert(source.length == target.length, "Duração diferente em fem/%s." % animation_name)
		_assert(source.loop_mode == target.loop_mode, "Loop diferente em fem/%s." % animation_name)
		_assert(source.step == target.step, "Step diferente em fem/%s." % animation_name)
		_assert(
			source.get_track_count() == target.get_track_count(),
			"Tracks diferentes em fem/%s." % animation_name
		)
		for track in mini(source.get_track_count(), target.get_track_count()):
			_assert(
				source.track_get_path(track) == target.track_get_path(track),
				"Caminho de track diferente em fem/%s, track %d." % [animation_name, track]
			)
			_assert(
				source.track_get_key_count(track) == target.track_get_key_count(track),
				"Quantidade de chaves diferente em fem/%s, track %d." % [animation_name, track]
			)
			for key in mini(
				source.track_get_key_count(track),
				target.track_get_key_count(track)
			):
				_assert(
					source.track_get_key_time(track, key) == target.track_get_key_time(track, key),
					"Tempo diferente em fem/%s, track %d, chave %d." % [animation_name, track, key]
				)
				_assert(
					source.track_get_key_value(track, key) == target.track_get_key_value(track, key),
					"Valor diferente em fem/%s, track %d, chave %d." % [animation_name, track, key]
				)


func _validate_crouch_walk_library(
	library: AnimationLibrary,
	body_type: StringName
) -> void:
	for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
		var animation_name := StringName("crouch_walk_%s" % direction)
		_assert(
			library.has_animation(animation_name),
			"%s/%s ausente." % [body_type, animation_name]
		)
		var animation := library.get_animation(animation_name)
		if animation == null:
			continue
		_assert(animation.loop_mode == Animation.LOOP_LINEAR, "%s/%s não está em loop." % [body_type, animation_name])
		_assert(is_equal_approx(animation.length, 0.8), "%s/%s possui duração incorreta." % [body_type, animation_name])
		var lower_body_moves := false
		for track in animation.get_track_count():
			if animation.track_get_key_count(track) < 2:
				continue
			var first_value: Variant = animation.track_get_key_value(track, 0)
			var last_value: Variant = animation.track_get_key_value(
				track,
				animation.track_get_key_count(track) - 1
			)
			_assert(
				first_value == last_value,
				"Loop com tranco em %s/%s, track %s." % [body_type, animation_name, animation.track_get_path(track)]
			)
			var path := String(animation.track_get_path(track))
			if "/coxa_" in path or "/perna_" in path or "/pe_" in path:
				for key in animation.track_get_key_count(track):
					if animation.track_get_key_value(track, key) != first_value:
						lower_body_moves = true
		_assert(
			lower_body_moves,
			"%s/%s não movimenta as pernas." % [body_type, animation_name]
		)


func _validate_crouch_idle_library(
	library: AnimationLibrary,
	body_type: StringName
) -> void:
	for direction: StringName in [&"ne", &"nw", &"se", &"sw"]:
		var enter_name := StringName("croushed_%s" % direction)
		var idle_name := StringName("crouch_idle_%s" % direction)
		var enter := library.get_animation(enter_name)
		var idle := library.get_animation(idle_name)
		_assert(enter != null and idle != null, "%s/%s ausente." % [body_type, idle_name])
		if enter == null or idle == null:
			continue
		_assert(idle.loop_mode == Animation.LOOP_LINEAR, "%s/%s não está em loop." % [body_type, idle_name])
		_assert(enter.get_track_count() == idle.get_track_count(), "%s/%s perdeu tracks." % [body_type, idle_name])
		for track in mini(enter.get_track_count(), idle.get_track_count()):
			var final_enter: Variant = enter.track_get_key_value(
				track,
				enter.track_get_key_count(track) - 1
			)
			_assert(idle.track_get_key_count(track) == 2, "%s/%s deve ter duas chaves por track." % [body_type, idle_name])
			_assert(
				idle.track_get_key_value(track, 0) == final_enter
				and idle.track_get_key_value(track, 1) == final_enter,
				"%s/%s não conserva a pose final agachada." % [body_type, idle_name]
			)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

extends SceneTree

const BODY_TYPES: Array[StringName] = [&"masc", &"fem"]
const DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"se", &"sw"]
const CHECKED_PIECES: Array[StringName] = [&"quadril", &"torso", &"cabeca", &"pe_e", &"pe_d"]

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var visual_scene := load(
		"res://presentation/characters/cutout/character_visual.tscn"
	) as PackedScene
	_expect(visual_scene != null, "CharacterVisual precisa carregar.")
	if visual_scene == null:
		quit(_failures)
		return

	for body_type: StringName in BODY_TYPES:
		var visual := visual_scene.instantiate() as CharacterVisual
		root.add_child(visual)
		await process_frame
		visual.present_body(String(body_type))
		for direction: StringName in DIRECTIONS:
			visual.present_sleep(true, direction)
			await process_frame
			_expect(visual.rig.get_current_direction() == direction,
				"O rig %s precisa assumir a direção %s durante o sono." % [body_type, direction])
			_expect(visual.animation_player.assigned_animation == StringName(
				"%s/sleep_%s" % [body_type, direction]
			), "A animação de sono incorreta foi selecionada para %s/%s." % [body_type, direction])
			for piece_name: StringName in CHECKED_PIECES:
				var bone := visual.rig.get_piece_bone(piece_name)
				var sprite := bone.get_node("Sprite") as Sprite2D
				var expected_suffix := "/%s/%s/%s.png" % [body_type, direction, piece_name]
				_expect(sprite.texture.resource_path.ends_with(expected_suffix),
					"%s/%s ainda usa textura de outra direção: %s" % [
						body_type, direction, sprite.texture.resource_path,
					])
		visual.queue_free()
		await process_frame

	if _failures == 0:
		print("SLEEP_DIRECTION_TEXTURE_OK bodies=2 directions=4")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)

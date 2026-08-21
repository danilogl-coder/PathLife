## Roda a cena de demonstração por alguns frames e salva um print.
extends Node

@export var frames_to_wait: int = 24
@export var output_path: String = "user://world_preview.png"

var _frames := 0


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < frames_to_wait:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(output_path)
	print("PRINT SALVO: ", ProjectSettings.globalize_path(output_path))
	get_tree().quit()

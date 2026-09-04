## Renderiza a casa procedural para inspeção visual do piso sobre o terreno.
## Uso: godot --path . --resolution 840x510 \
##   --script res://tests/structure_ground_preview.gd
extends SceneTree

const OUTPUT := "user://structure_ground_preview.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var interface := scene.get_node_or_null(^"Interface") as CanvasLayer
	if interface != null:
		interface.visible = false
	for frame in 120:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		printerr("STRUCTURE GROUND PREVIEW: viewport sem imagem")
		quit(1)
		return
	var error := image.save_png(OUTPUT)
	if error != OK:
		printerr("STRUCTURE GROUND PREVIEW: erro ao salvar: ", error)
		quit(1)
		return
	print("STRUCTURE GROUND PREVIEW: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)

## Renderiza a casa-base para inspeção visual da porta da entrada.
## Uso: godot --path . --rendering-method gl_compatibility --script res://tests/door_structure_preview.gd
extends SceneTree

const OUTPUT := "res://.godot/casa_madeira_porta_preview.png"


func _init() -> void:
	_render.call_deferred()


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("25212b")
	background.size = viewport.size
	viewport.add_child(background)

	var stage := Node2D.new()
	stage.y_sort_enabled = true
	viewport.add_child(stage)
	var packed := load(
		"res://presentation/world/structures/casa_madeira_tilemap.tscn"
	) as PackedScene
	assert(packed != null)
	var house := packed.instantiate() as StructureRoot
	house.position = Vector2(720.0, 180.0)
	stage.add_child(house)

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	assert(error == OK)
	print("DOOR_STRUCTURE_PREVIEW=%s" % ProjectSettings.globalize_path(OUTPUT))
	quit(0)

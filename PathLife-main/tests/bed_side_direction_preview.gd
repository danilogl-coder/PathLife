extends SceneTree

const CASES: Array[Dictionary] = [
	{"scene": "res://gameplay/furniture/bed/bed_r0.tscn", "direction": &"ne", "label": "R0 NE"},
	{"scene": "res://gameplay/furniture/bed/bed_r0.tscn", "direction": &"se", "label": "R0 SE"},
	{"scene": "res://gameplay/furniture/bed/bed_r1.tscn", "direction": &"nw", "label": "R1 NW"},
	{"scene": "res://gameplay/furniture/bed/bed_r1.tscn", "direction": &"sw", "label": "R1 SW"},
]


func _init() -> void:
	_render.call_deferred()


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("1b292e")
	background.size = viewport.size
	viewport.add_child(background)
	var player_scene := load("res://gameplay/player/player.tscn") as PackedScene

	for index: int in CASES.size():
		var entry := CASES[index]
		var bed := (load(entry.scene) as PackedScene).instantiate() as BedFurniture
		viewport.add_child(bed)
		bed.position = Vector2(135 + index * 270, 140)
		var player := player_scene.instantiate() as PlayerController
		viewport.add_child(player)
		player.global_position = bed.get_sleep_position()
		player.z_index = 2
		var anchor := player.get_node("VisualAnchor") as Node2D
		anchor.position = bed.get_sleep_visual_offset()
		anchor.rotation = bed.get_sleep_visual_rotation()
		anchor.scale = bed.get_sleep_visual_scale()
		player.enter_sleep(entry.direction)
		var label := Label.new()
		label.text = entry.label
		label.position = bed.position + Vector2(-25, 40)
		viewport.add_child(label)

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var output := "res://.godot/bed_side_direction_preview.png"
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output)) == OK)
	print("BED_SIDE_DIRECTION_PREVIEW=%s" % ProjectSettings.globalize_path(output))
	quit()

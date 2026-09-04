## Salva as cenas de mobília com textura, posição e polígonos já montados.
## Isso permite que o TileSet mostre miniaturas reais sem depender de executar
## o script da peça durante a geração da prévia do editor.
##
## Uso:
## godot --headless --path . --script res://tools/bake_furniture_scenes.gd
extends SceneTree

const PIECES_DIRECTORY := "res://gameplay/furniture/pieces"


func _init() -> void:
	var failures := 0
	var baked_count := 0
	var files := DirAccess.get_files_at(PIECES_DIRECTORY)
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".tscn"):
			continue
		var path := PIECES_DIRECTORY.path_join(file_name)
		var source := load(path) as PackedScene
		if source == null:
			push_error("Não foi possível carregar %s." % path)
			failures += 1
			continue
		var piece := source.instantiate() as FurniturePiece
		if piece == null:
			push_error("%s não instancia FurniturePiece." % path)
			failures += 1
			continue
		var visual := piece.get_node_or_null(^"Visual")
		if visual != null and visual.scene_file_path != "":
			piece.set_editable_instance(visual, true)
		piece.build()
		piece.draw_gizmo = false
		var baked := PackedScene.new()
		var pack_error := baked.pack(piece)
		if pack_error != OK:
			push_error("Falha ao empacotar %s: erro %d." % [path, pack_error])
			piece.free()
			failures += 1
			continue
		var save_error := ResourceSaver.save(baked, path)
		piece.free()
		if save_error != OK:
			push_error("Falha ao salvar %s: erro %d." % [path, save_error])
			failures += 1
			continue
		baked_count += 1
	print("FURNITURE_SCENES_BAKED=%d" % baked_count)
	quit(failures)

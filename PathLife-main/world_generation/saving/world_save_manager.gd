## Save incremental: semente + diferenças + objetos removidos.
class_name WorldSaveManager
extends Node

@export_file("*.json") var save_path: String = "user://pathlife_world.json"
@export var autosave_on_exit: bool = true

var _seed: int = 0
var _patches: Dictionary = {}          ## Vector2i -> CellPatch
var _removed_objects: Dictionary = {}  ## int (object_id) -> true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_seed(fallback: int) -> int:
	_load()
	return _seed if _seed != 0 else fallback


func set_seed(value: int) -> void:
	_seed = value


## Registra uma alteração do jogador.
func patch_cell(patch: CellPatch) -> void:
	_patches[Vector2i(patch.world_pos.x, patch.world_pos.y)] = patch


## Registra que um objeto procedural foi removido (árvore cortada, etc.).
func remove_object(object_id: int) -> void:
	_removed_objects[object_id] = true


func is_object_removed(object_id: int) -> bool:
	return _removed_objects.has(object_id)


## Aplica as diferenças sobre um chunk recém-gerado.
func apply_patches(chunk: ChunkData) -> void:
	if _patches.is_empty() and _removed_objects.is_empty():
		return
	for patch: CellPatch in _patches.values():
		var world_xy := Vector2i(patch.world_pos.x, patch.world_pos.y)
		var cell := chunk.get_cell_world(world_xy)
		if cell == null:
			continue
		if patch.has_height_override():
			cell.height = patch.height_override
		if patch.ground_override != &"":
			cell.ground_id = patch.ground_override
		if patch.walkable_override >= 0:
			cell.walkable = patch.walkable_override == 1
	if not _removed_objects.is_empty():
		var kept: Array[DecorationPlacement] = []
		for placement in chunk.decorations:
			if not _removed_objects.has(placement.object_id):
				kept.append(placement)
		chunk.decorations = kept


func save() -> Error:
	var patch_list: Array = []
	for patch: CellPatch in _patches.values():
		patch_list.append(patch.to_dictionary())
	var payload := {
		"version": 1,
		"seed": _seed,
		"patches": patch_list,
		"removed_objects": _removed_objects.keys(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file.close()
	return OK


func _load() -> void:
	if not has_save():
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	_seed = int(data.get("seed", 0))
	_patches.clear()
	for entry: Variant in data.get("patches", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var patch := CellPatch.from_dictionary(entry)
			_patches[Vector2i(patch.world_pos.x, patch.world_pos.y)] = patch
	_removed_objects.clear()
	for object_id: Variant in data.get("removed_objects", []):
		_removed_objects[int(object_id)] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_on_exit:
		save()

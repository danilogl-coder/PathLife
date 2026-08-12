class_name ClothingCatalog
extends Resource

const DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"se", &"sw"]

@export_file("*.json") var metadata_path: String = ""
@export_dir var textures_root: String = ""
@export var deformable_skirt: SaiaRecurso
@export var items: Array[ClothingItem] = []

var _clothes_data: Dictionary = {}
var _skirt_data: Dictionary = {}

func get_item(item_id: StringName) -> ClothingItem:
	for item: ClothingItem in items:
		if item != null and item.id == item_id: return item
	return null

func get_items_for_slot(slot_name: StringName) -> Array[ClothingItem]:
	var result: Array[ClothingItem] = []
	for item: ClothingItem in items:
		if item != null and StringName(item.slot) == slot_name: result.append(item)
	return result

func is_item_in_slot(item_id: StringName, slot_name: StringName) -> bool:
	var item := get_item(item_id)
	return item != null and StringName(item.slot) == slot_name

func get_piece_data(item_id: StringName, body_type: String, direction: StringName) -> Dictionary:
	if not _ensure_loaded(): return {}
	var item := get_item(item_id)
	if item == null or item.visual_type != "bone_sprites": return {}
	var item_data: Dictionary = _clothes_data.get(String(item.source_key), {})
	var bodies: Dictionary = item_data.get("corpos", {})
	var directions: Dictionary = bodies.get(body_type, {})
	return directions.get(String(direction), {}) as Dictionary

func load_piece_texture(relative_path: String) -> Texture2D:
	var full_path := textures_root.path_join(relative_path)
	if not ResourceLoader.exists(full_path):
		push_error("PNG de roupa não encontrado: %s" % full_path)
		return null
	return load(full_path) as Texture2D

func get_layer_order(item_id: StringName) -> int:
	if not _ensure_loaded(): return 0
	var item := get_item(item_id)
	if item == null: return 0
	if item.visual_type == "deformable_skirt": return 1
	return int((_clothes_data.get(String(item.source_key), {}) as Dictionary).get("ordem", 0))

func is_item_complete(item_id: StringName, body_type: String) -> bool:
	if not _ensure_loaded(): return false
	var item := get_item(item_id)
	if item == null: return false
	if item.visual_type == "deformable_skirt": return _is_skirt_complete(body_type)
	var item_data: Dictionary = _clothes_data.get(String(item.source_key), {})
	var expected: Array = item_data.get("ossos", [])
	if expected.is_empty(): return false
	for direction: StringName in DIRECTIONS:
		var pieces := get_piece_data(item_id, body_type, direction)
		if pieces.size() != expected.size(): return false
		for bone_name: Variant in expected:
			var piece: Dictionary = pieces.get(String(bone_name), {})
			if not piece.has("arquivo") or not piece.has("offset_sprite"): return false
			if not ResourceLoader.exists(textures_root.path_join(String(piece["arquivo"]))): return false
	return true

func _is_skirt_complete(body_type: String) -> bool:
	if deformable_skirt == null or not FileAccess.file_exists(deformable_skirt.dados): return false
	if _skirt_data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(deformable_skirt.dados))
		if not parsed is Dictionary: return false
		_skirt_data = parsed
	var directions: Dictionary = (_skirt_data.get("corpos", {}) as Dictionary).get(body_type, {})
	for direction: StringName in DIRECTIONS:
		var entry: Dictionary = directions.get(String(direction), {})
		if entry.is_empty(): return false
		for key: String in ["textura_frente", "textura_tras"]:
			if not ResourceLoader.exists(deformable_skirt.pasta_texturas.path_join(String(entry.get(key, "")))): return false
	return true

func _ensure_loaded() -> bool:
	if not _clothes_data.is_empty(): return true
	if not FileAccess.file_exists(metadata_path):
		push_error("roupas.json não encontrado: %s" % metadata_path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("roupas") is Dictionary:
		push_error("JSON de roupas inválido: %s" % metadata_path)
		return false
	_clothes_data = (parsed as Dictionary)["roupas"]
	return true

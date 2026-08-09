class_name CharacterRig
extends Skeleton2D

@export_enum("masc", "fem") var body_type: String = "masc"
@export_enum("se", "sw", "ne", "nw") var initial_direction: String = "se"
@export_dir var assets_root: String = "res://assets/characters/cutout"

var _rig_data: Dictionary = {}
var _pieces: Dictionary = {}
var _current_direction: StringName = &""


func _ready() -> void:
	_cache_piece_nodes()
	_load_body_data()
	set_direction(initial_direction)


func set_direction(direction: StringName) -> void:
	if direction == _current_direction or _rig_data.is_empty():
		return

	var directions: Dictionary = _rig_data["direcoes"]
	var direction_key := String(direction)
	if not directions.has(direction_key):
		push_error("Direção inexistente no rig: %s" % direction_key)
		return

	var direction_data: Dictionary = directions[direction_key]
	var pieces_data: Dictionary = direction_data["pecas"]

	for piece_name: String in pieces_data:
		if not _pieces.has(piece_name):
			push_error("Bone2D ausente na cena: %s" % piece_name)
			continue

		var nodes: Dictionary = _pieces[piece_name]
		var bone: Bone2D = nodes["bone"]
		var sprite: Sprite2D = nodes["sprite"]
		var piece: Dictionary = pieces_data[piece_name]

		bone.position = _parse_vector2(piece["posicao"])
		bone.z_index = int(piece["z_index"])
		sprite.offset = _parse_vector2(piece["offset_sprite"])
		sprite.texture = load("%s/%s" % [assets_root, piece["arquivo"]]) as Texture2D

	_apply_markers(direction_data["pontas"])
	_current_direction = direction


func set_body(new_body: String) -> void:
	if new_body != "masc" and new_body != "fem":
		push_error("Corpo inválido: %s" % new_body)
		return
	if new_body == body_type:
		return

	var direction_to_preserve := _current_direction
	body_type = new_body
	_current_direction = &""
	_load_body_data()
	set_direction(direction_to_preserve if direction_to_preserve != &"" else StringName(initial_direction))


func _cache_piece_nodes() -> void:
	_pieces.clear()
	_collect_bones(self)


func _collect_bones(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Bone2D:
			var bone := child as Bone2D
			# O rig.json fornece uma ordem absoluta de profundidade (0 a 14).
			# Se o Z for relativo, o Godot soma o valor de todos os ossos pais.
			bone.z_as_relative = false
			var sprite := bone.get_node_or_null("Sprite") as Sprite2D
			if sprite != null:
				_pieces[String(bone.name)] = {
					"bone": bone,
					"sprite": sprite,
				}
		_collect_bones(child)


func _load_body_data() -> void:
	var json_path := "%s/%s/rig.json" % [assets_root, body_type]
	if not FileAccess.file_exists(json_path):
		push_error("rig.json não encontrado: %s" % json_path)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error("JSON inválido: %s" % json_path)
		return

	_rig_data = parsed as Dictionary


func _apply_markers(markers_data: Dictionary) -> void:
	for marker_name: String in markers_data:
		var marker := find_child(marker_name, true, false) as Marker2D
		if marker != null:
			marker.position = _parse_vector2(markers_data[marker_name]["posicao"])


func _parse_vector2(value: Variant) -> Vector2:
	if value is Array:
		var coordinates := value as Array
		if coordinates.size() == 2:
			return Vector2(float(coordinates[0]), float(coordinates[1]))

	if value is String:
		var parts := String(value).split(" ", false)
		if parts.size() == 2:
			return Vector2(float(parts[0]), float(parts[1]))

	push_error("Vector2 inválido no rig.json: %s" % value)
	return Vector2.ZERO

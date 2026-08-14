class_name HairManager
extends Node2D

@export var catalog: HairCatalog
@export var chain_visual_scene: PackedScene
@export var anchor: Node2D
@export var back_base: Sprite2D
@export var back_chains: Node2D
@export var front_base: Sprite2D
@export var front_chains: Node2D
@export var physics_controller: HairPhysicsController

var _front_style: StringName = &""
var _back_style: StringName = &""
var _direction: StringName = &""
var _color_id: StringName = &""
var _json_cache: Dictionary = {}
var color_presenter: CharacterColorPresenter


func _ready() -> void:
	physics_controller.ancora = anchor


func present(front_style: StringName, back_style: StringName, direction: StringName, color_id: StringName) -> void:
	if front_style == _front_style and back_style == _back_style and direction == _direction and color_id == _color_id:
		return
	_front_style = front_style
	_back_style = back_style
	_direction = direction
	_color_id = color_id
	_clear_container(front_chains)
	_clear_container(back_chains)
	physics_controller.cadeias.clear()
	_build_side(back_style, direction, &"tras", back_base, back_chains)
	_build_side(front_style, direction, &"frente", front_base, front_chains)
	physics_controller.reset_physics()


func invalidate() -> void:
	_front_style = &"__invalid__"
	_back_style = &"__invalid__"
	_direction = &"__invalid__"
	_color_id = &"__invalid__"


func _build_side(style_id: StringName, direction: StringName, side: StringName, base: Sprite2D, container: Node2D) -> void:
	base.texture = null
	if style_id == &"" or catalog == null:
		return
	var definition := catalog.get_definition(style_id)
	if definition == null:
		return
	var style_data := _get_style_data(definition)
	var color_material: Material = color_presenter.get_hair_material(_color_id) if color_presenter != null else null
	var directions: Dictionary = style_data.get("direcoes", {})
	var direction_data: Dictionary = directions.get(String(direction), {})
	var base_data: Dictionary = direction_data.get("base", {}).get(String(side), {})
	var file := String(base_data.get("arquivo", ""))
	if not file.is_empty():
		base.texture = load(definition.pasta_texturas.path_join(file)) as Texture2D
		base.offset = _vector(base_data.get("offset_sprite", [])) + definition.deslocamento
		base.material = color_material
	for chain_value: Variant in direction_data.get("cadeias", []):
		var chain_data: Dictionary = chain_value
		if StringName(chain_data.get("peca", "")) != side:
			continue
		var visual := chain_visual_scene.instantiate() as HairChainVisual
		visual.name = "Chain_%s" % String(chain_data.get("nome", "hair"))
		visual.position = definition.deslocamento
		container.add_child(visual)
		physics_controller.cadeias.append(visual.build(chain_data, definition, color_material))


func _get_style_data(definition: HairDefinition) -> Dictionary:
	if not _json_cache.has(definition.dados):
		var file := FileAccess.open(definition.dados, FileAccess.READ)
		if file == null:
			push_error("Não foi possível abrir os dados de cabelo: %s" % definition.dados)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		_json_cache[definition.dados] = parsed if parsed is Dictionary else {}
	var root: Dictionary = _json_cache[definition.dados]
	return root.get("estilos", {}).get(String(definition.estilo), {})


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _vector(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

class_name CharacterRig
extends Skeleton2D

## Raízes de cadeia. Escalar a RAIZ é o que faz roupa, mão, pé, sapato e cabelo
## acompanharem a idade sem uma linha a mais: todos eles são filhos.
const OSSO_TRONCO: StringName = &"torso"
const OSSO_CABECA: StringName = &"cabeca"
const OSSOS_BRACO: Array[StringName] = [&"braco_sup_e", &"braco_sup_d"]
const OSSOS_PERNA: Array[StringName] = [&"coxa_e", &"coxa_d"]

@export_enum("masc", "fem") var body_type: String = "masc"
@export_enum("se", "sw", "ne", "nw") var initial_direction: String = "se"
@export_dir var assets_root: String = "res://assets/characters/cutout"
## Y do dedo do pé no espaço do Skeleton2D com o rig em escala 1. Sem ele, o
## personagem encolhido flutua: a escala puxa o pé para perto da origem.
## Como medir: selecione ponta_pe_e no editor, na pose de repouso, e leia o Y
## dele relativo ao Skeleton2D.
@export_range(-32.0, 32.0, 0.01) var apoio_pes_y: float = 3.34

var _rig_data: Dictionary = {}
var _pieces: Dictionary = {}
var _current_direction: StringName = &""
var color_presenter: CharacterColorPresenter
var _age: AgeProfile
var _rig_base_position := Vector2.ZERO
var _quadril_base := Vector2.ZERO
var _perna_escalavel: float = 0.0
var _medidas_prontas: bool = false


func get_piece_bone(piece_name: StringName) -> Bone2D:
	var nodes: Dictionary = _pieces.get(String(piece_name), {})
	return nodes.get("bone") as Bone2D


func get_current_direction() -> StringName:
	return _current_direction


func present_skin_color(color_id: StringName) -> void:
	if color_presenter == null:
		return
	var skin_material := color_presenter.get_skin_material(color_id)
	for nodes_value: Variant in _pieces.values():
		var nodes: Dictionary = nodes_value
		var sprite := nodes.get("sprite") as Sprite2D
		if sprite != null:
			sprite.material = skin_material


func _ready() -> void:
	_rig_base_position = position
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

	_quadril_base = _parse_vector2(pieces_data["quadril"]["posicao"])
	# A parte da perna que a escala do osso coxa realmente encolhe: joelho,
	# tornozelo e ponta do pé. O offset quadril->coxa não entra, porque é filho
	# do quadril e não da coxa.
	_perna_escalavel = (
		_parse_vector2(pieces_data["perna_e"]["posicao"]).y
		+ _parse_vector2(pieces_data["pe_e"]["posicao"]).y
		+ _parse_vector2(direction_data["pontas"]["ponta_pe_e"]["posicao"]).y
	)
	_medidas_prontas = true

	apply_age_shape()
	_apply_core_layering()
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


## Troca de idade. Recarrega a arte só quando a pasta muda; o resto é escala.
func set_age_profile(profile: AgeProfile) -> void:
	var art_changed := _resolve_art_key(profile) != _resolve_art_key(_age)
	_age = profile
	if not art_changed:
		apply_age_shape()
		return
	var direction_to_preserve := _current_direction
	_current_direction = &""
	_load_body_data()
	set_direction(
		direction_to_preserve if direction_to_preserve != &"" else StringName(initial_direction)
	)


## Só as escalas — sem tocar em JSON nem em textura. Barato o bastante para
## rodar todo quadro durante a transição de idade.
func set_age_shape(profile: AgeProfile) -> void:
	_age = profile
	apply_age_shape()


func get_age_profile() -> AgeProfile:
	return _age


func get_art_key() -> String:
	return _resolve_art_key(_age)


## A proporção da idade, aplicada por escala nas raízes de cadeia. As animações
## só escrevem `rotation` nos ossos, então `scale` e `position` são nossos.
func apply_age_shape() -> void:
	var escala := 1.0
	var largura := 1.0
	var tronco := 1.0
	var pernas := 1.0
	var bracos := 1.0
	var cabeca := 1.0
	if _age != null:
		escala = _age.escala_global
		largura = _age.fator_largura
		tronco = maxf(_age.fator_tronco, 0.01)
		pernas = _age.fator_pernas
		bracos = _age.fator_bracos
		cabeca = _age.escala_cabeca

	# A largura é a única escala não uniforme, e por isso mora na RAIZ: aqui
	# nenhum osso girado a herdou ainda de um pai já rotacionado.
	scale = Vector2(escala * largura, escala)
	# Escalar aproxima o pé da origem. Isto devolve o contato com o chão.
	position.y = _rig_base_position.y + apoio_pes_y * (1.0 - escala)

	_escalar_osso(OSSO_TRONCO, tronco)
	# cabeça e ombros são FILHOS do tronco: dividir cancela a herança e deixa
	# cada fator significar exatamente o que o nome diz.
	_escalar_osso(OSSO_CABECA, cabeca / tronco)
	for bone_name: StringName in OSSOS_BRACO:
		_escalar_osso(bone_name, bracos / tronco)
	for bone_name: StringName in OSSOS_PERNA:
		_escalar_osso(bone_name, pernas)

	var quadril := get_piece_bone(&"quadril")
	if quadril != null and _medidas_prontas:
		# Encurtar a perna sem descer o quadril deixa o personagem no ar. O
		# quadril compensa exatamente o que a cadeia da perna perdeu.
		quadril.position = Vector2(
			_quadril_base.x,
			_quadril_base.y + _perna_escalavel * (1.0 - pernas)
		)


func _escalar_osso(bone_name: StringName, factor: float) -> void:
	var bone := get_piece_bone(bone_name)
	if bone != null:
		bone.scale = Vector2(factor, factor)


## "bebe" + "masc" -> "bebe_masc" SE a pasta existir; senão "masc". É o fallback
## que deixa uma idade nascer só com proporção e ganhar arte dedicada depois.
func _resolve_art_key(profile: AgeProfile) -> String:
	if profile != null and profile.pasta_arte != &"":
		var candidate := "%s_%s" % [String(profile.pasta_arte), body_type]
		if FileAccess.file_exists("%s/%s/rig.json" % [assets_root, candidate]):
			return candidate
	return body_type


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
	var json_path := "%s/%s/rig.json" % [assets_root, _resolve_art_key(_age)]
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


func _apply_core_layering() -> void:
	var hip := get_piece_bone(&"quadril")
	var torso := get_piece_bone(&"torso")
	var head := get_piece_bone(&"cabeca")
	if hip == null or torso == null:
		return

	# A frente da saia usa no máximo Z 12. O torso começa em 13 para cobrir a
	# cintura da saia, e a cadeia do braço frontal continua acima dele. Alterar
	# apenas o torso faria o peitoral encobrir o braço em algumas direções.
	const SKIRT_FOREGROUND_Z := 12
	torso.z_index = maxi(maxi(torso.z_index, hip.z_index + 1), SKIRT_FOREGROUND_Z + 1)
	if head != null:
		head.z_index = maxi(head.z_index, torso.z_index + 1)

	var left_upper := get_piece_bone(&"braco_sup_e")
	var right_upper := get_piece_bone(&"braco_sup_d")
	if left_upper == null or right_upper == null:
		return
	var front_side := &"e" if left_upper.z_index > right_upper.z_index else &"d"
	var front_upper := get_piece_bone(StringName("braco_sup_%s" % front_side))
	var front_lower := get_piece_bone(StringName("braco_inf_%s" % front_side))
	var front_hand := get_piece_bone(StringName("mao_%s" % front_side))
	front_upper.z_index = maxi(front_upper.z_index, torso.z_index + 2)
	if front_lower != null:
		front_lower.z_index = maxi(front_lower.z_index, front_upper.z_index + 1)
	if front_hand != null and front_lower != null:
		front_hand.z_index = maxi(front_hand.z_index, front_lower.z_index + 1)


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

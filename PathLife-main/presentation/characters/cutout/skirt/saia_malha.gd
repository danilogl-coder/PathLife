class_name SaiaMalha
extends Node2D
## Monta a saia deformavel: dois Polygon2D com pesos no Skeleton2D do personagem.
##
## POR QUE OS OSSOS SAO CRIADOS POR CODIGO E OS POLIGONOS NAO
## Os dois Polygon2D existem na cena e sao editaveis no Inspector -- eles nao
## mudam de lugar. Os Bone2D da saia, sim: a posicao de repouso de cada um muda
## por DIRECAO, porque a silhueta da saia muda. Nao ha' como isso viver estatico
## na cena; entao os sete ossos sao criados uma vez e reposicionados a cada troca
## de direcao, exatamente como o CharacterRig ja' faz com o resto do corpo.
##
## FRENTE E TRAS SAO O MESMO POLIGONO, DUAS TEXTURAS
## A perna fica DENTRO do cone da saia. Entao o que resolve a ordem visual e' um
## painel na frente da perna e outro atras, os dois com a silhueta inteira. Em
## repouso o da frente cobre o de tras. Quando a malha deforma, o de tras aparece
## na fresta -- e ele e' a face interna do tecido. Sem colisao nenhuma.

const MEIO: Array[StringName] = [&"SaiaEsq", &"SaiaCen", &"SaiaDir"]
const BARRA: Array[StringName] = [&"BarraEsq", &"BarraCen", &"BarraDir"]
const ORDEM: Array[StringName] = [&"SaiaRaiz", &"SaiaEsq", &"SaiaCen", &"SaiaDir",
	&"BarraEsq", &"BarraCen", &"BarraDir"]

@export var recurso: SaiaRecurso
## O Skeleton2D do personagem. Os pesos do Polygon2D apontam para ossos dele.
@export var esqueleto: Skeleton2D
## O Bone2D do quadril. E' onde a raiz da saia pendura.
@export var osso_quadril: Bone2D
## Os Bone2D das coxas, para o pano ser arrastado por elas. Os nomes tem que
## bater com as chaves de 'pesos' no JSON.
@export var osso_coxa_esq: Bone2D
@export var osso_coxa_dir: Bone2D
## Os dois paineis. Ficam na cena, fora do Skeleton2D, com 'skeleton' apontando
## para ele.
@export var painel_tras: Polygon2D
@export var painel_frente: Polygon2D

var _dados: Dictionary = {}
var _ossos: Dictionary = {}          # StringName -> Bone2D
var _corpo: StringName = &""
var _direcao: StringName = &""
var _texturas: Dictionary = {}       # cache: caminho -> Texture2D
var _montado := false
var _color_material: Material

signal reconfigurada


func _ready() -> void:
	_montar()


func equipar(corpo: StringName, direcao: StringName) -> void:
	show()
	configurar(corpo, direcao)
	if painel_tras != null:
		painel_tras.show()
	if painel_frente != null:
		painel_frente.show()
	var balanco := get_node_or_null("SaiaBalanco") as SaiaBalanco
	if balanco != null:
		balanco.repousar()


func remover() -> void:
	var balanco := get_node_or_null("SaiaBalanco") as SaiaBalanco
	if balanco != null:
		balanco.repousar()
	if painel_tras != null:
		painel_tras.hide()
	if painel_frente != null:
		painel_frente.hide()
	hide()


func set_color_material(new_material: Material) -> void:
	_color_material = new_material
	if painel_tras != null:
		painel_tras.material = _color_material
	if painel_frente != null:
		painel_frente.material = _color_material


func _montar() -> void:
	if _montado or recurso == null or esqueleto == null or osso_quadril == null:
		return
	var f := FileAccess.open(recurso.dados, FileAccess.READ)
	if f == null:
		push_error("SaiaMalha: nao abriu %s" % recurso.dados)
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(j) != TYPE_DICTIONARY:
		push_error("SaiaMalha: JSON invalido em %s" % recurso.dados)
		return
	_dados = j
	# Os painéis precisam herdar diretamente a transformação animada do quadril.
	# A malha gerada originalmente usava caminhos de skin incompatíveis com este
	# rig e colapsava para uma área invisível.
	for painel: Polygon2D in [painel_tras, painel_frente]:
		if painel != null:
			painel.reparent(osso_quadril, false)
			painel.hide()
	# os sete ossos, criados UMA vez. Reposicionados a cada troca de direcao.
	var raiz_b := Bone2D.new()
	raiz_b.name = "SaiaRaiz"
	raiz_b.auto_calculate_length_and_angle = false
	raiz_b.rest = Transform2D.IDENTITY
	osso_quadril.add_child(raiz_b)
	_ossos[&"SaiaRaiz"] = raiz_b
	for i in 3:
		var m := Bone2D.new()
		m.name = String(MEIO[i])
		m.auto_calculate_length_and_angle = false
		m.rest = Transform2D.IDENTITY
		raiz_b.add_child(m)
		_ossos[MEIO[i]] = m
		var b := Bone2D.new()
		b.name = String(BARRA[i])
		b.auto_calculate_length_and_angle = false
		b.rest = Transform2D.IDENTITY
		m.add_child(b)
		_ossos[BARRA[i]] = b
	_montado = true


## Aplica a malha, os pesos, as texturas e a ordem visual de um corpo e direcao.
## Chame do mesmo lugar em que o resto do rig ja' troca de direcao.
func configurar(corpo: StringName, direcao: StringName) -> void:
	if not _montado:
		_montar()
	if not _montado or (corpo == _corpo and direcao == _direcao):
		return
	var c: Dictionary = _dados.get("corpos", {}).get(String(corpo), {})
	var e: Dictionary = c.get(String(direcao), {})
	if e.is_empty():
		push_error("SaiaMalha: sem dados para %s/%s" % [corpo, direcao])
		return
	_corpo = corpo
	_direcao = direcao

	# ---- ossos: posicao de repouso desta direcao
	var org := Vector2(e["ossos"]["SaiaRaiz"][0], e["ossos"]["SaiaRaiz"][1])
	# tudo no JSON esta em px do canvas do personagem. 'quadril_canvas' e' onde o
	# osso do quadril fica nesse mesmo canvas, entao a raiz da saia nasce na
	# diferenca entre a cintura e ele.
	_pos(&"SaiaRaiz", org - Vector2(e["quadril_canvas"][0], e["quadril_canvas"][1]))
	for i in 3:
		var m := Vector2(e["ossos"][String(MEIO[i])][0], e["ossos"][String(MEIO[i])][1])
		var b := Vector2(e["ossos"][String(BARRA[i])][0], e["ossos"][String(BARRA[i])][1])
		_pos(MEIO[i], m - org)
		_pos(BARRA[i], b - m)
	for o in _ossos.values():
		(o as Bone2D).rotation = 0.0
		(o as Bone2D).rest = (o as Bone2D).transform

	# ---- malha
	_aplicar(painel_tras, e, String(e["textura_tras"]), int(e["z_tras"]))
	_aplicar(painel_frente, e, String(e["textura_frente"]), int(e["z_frente"]))
	reconfigurada.emit()


func _pos(nome: StringName, p: Vector2) -> void:
	var b: Bone2D = _ossos.get(nome)
	if b != null:
		b.position = p


func _aplicar(pg: Polygon2D, e: Dictionary, tex: String, z: int) -> void:
	if pg == null:
		return
	pg.clear_bones()
	pg.skeleton = NodePath("")
	pg.position = Vector2.ZERO
	pg.rotation = 0.0
	pg.z_as_relative = false
	var textura := _textura(tex)
	pg.texture = textura
	var tamanho := textura.get_size()
	var origem := Vector2(e["origem"][0], e["origem"][1])
	var quadril_canvas := Vector2(e["quadril_canvas"][0], e["quadril_canvas"][1])
	var canto := origem - quadril_canvas
	pg.polygon = PackedVector2Array([
		canto,
		canto + Vector2(tamanho.x, 0.0),
		canto + tamanho,
		canto + Vector2(0.0, tamanho.y),
	])
	pg.uv = PackedVector2Array([
		Vector2.ZERO,
		Vector2(tamanho.x, 0.0),
		tamanho,
		Vector2(0.0, tamanho.y),
	])
	pg.polygons = []
	pg.texture_offset = Vector2.ZERO
	pg.z_index = z


func aplicar_balanco(angulo_graus: float) -> void:
	var angulo := deg_to_rad(angulo_graus)
	if painel_tras != null:
		painel_tras.rotation = angulo
	if painel_frente != null:
		painel_frente.rotation = angulo


func _osso(nome: String) -> Bone2D:
	match nome:
		"coxa_e": return osso_coxa_esq
		"coxa_d": return osso_coxa_dir
		_: return _ossos.get(StringName(nome))


func _textura(caminho: String) -> Texture2D:
	if not _texturas.has(caminho):
		_texturas[caminho] = load(recurso.pasta_texturas.path_join(caminho))
	return _texturas[caminho]


## Os tres ossos de barra e os tres do meio, para o SaiaBalanco. Devolver em vez
## de o balanco procurar por nome evita busca de no' a cada quadro.
func ossos_balanco() -> Array[Bone2D]:
	var r: Array[Bone2D] = []
	for n in MEIO:
		r.append(_ossos.get(n))
	for n in BARRA:
		r.append(_ossos.get(n))
	return r


func raiz() -> Bone2D:
	return _ossos.get(&"SaiaRaiz")


func visivel() -> bool:
	return painel_frente != null and painel_frente.is_visible_in_tree()

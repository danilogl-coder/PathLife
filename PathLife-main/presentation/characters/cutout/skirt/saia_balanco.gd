class_name SaiaBalanco
extends Node
## Movimento secundario da saia: mola amortecida nos seis ossos proprios dela.
##
## O CONTORNO DA PERNA NAO VEM DAQUI
## As coxas ja' entram na malha com peso, entao o pano perto da perna e'
## arrastado pela propria animacao, sem script. Este no' so' acrescenta o
## BALANCO -- e por isso ele pode ser discreto, com teto baixo, sem competir com
## a deformacao que ja' esta acontecendo.
##
## PENDULO DE TELA, SEM TABELA POR DIRECAO
## A saia pendura para baixo na TELA, e a gravidade projeta para baixo na tela.
## Entao o que balanca o pano e' a componente HORIZONTAL da aceleracao do
## quadril, medida na tela. A conta ja' acontece no espaco certo -- nao existe
## coeficiente por guinada, e trocar de direcao nao muda nada aqui.
##
## NAO DISPUTA OSSO COM O AnimationPlayer
## Estes seis ossos sao criados pelo SaiaMalha e nao existem em nenhuma
## AnimationLibrary. E o no' roda com process_priority alto, entao le' o quadril
## depois que a animacao ja' escreveu a pose do quadro.

@export var malha: SaiaMalha

var _rec: SaiaRecurso
var _meio: Array[Bone2D] = []
var _barra: Array[Bone2D] = []
var _raiz: Bone2D

var _ang := Vector3.ZERO          # corpo da saia, em graus (esq, cen, dir)
var _vel_ang := Vector3.ZERO
var _bar := Vector3.ZERO          # barra, angulo de MUNDO em graus
var _vel_bar := Vector3.ZERO
var _pos_ant := Vector2.ZERO
var _vel := Vector2.ZERO
var _acel := Vector2.ZERO
var _ligado := false


func _ready() -> void:
	# depois da AnimationPlayer: o quadril so' esta na pose do quadro depois que
	# a animacao escreveu nele.
	process_priority = 100
	set_process(false)
	if malha != null:
		malha.reconfigurada.connect(_pegar_ossos)
		_pegar_ossos()


func _pegar_ossos() -> void:
	if malha == null:
		return
	_rec = malha.recurso
	var os := malha.ossos_balanco()
	if os.size() < 6:
		set_process(false)
		return
	_meio = [os[0], os[1], os[2]]
	_barra = [os[3], os[4], os[5]]
	_raiz = malha.raiz()
	# trocar de direcao reposiciona os ossos: o estado anterior nao vale mais.
	repousar()
	set_process(_raiz != null)


## Zera o balanco. Chame ao equipar, remover, teleportar e trocar de direcao --
## um salto de posicao vira um chute de aceleracao e a saia da' um pulo.
func repousar() -> void:
	_ang = Vector3.ZERO
	_vel_ang = Vector3.ZERO
	_bar = Vector3.ZERO
	_vel_bar = Vector3.ZERO
	_vel = Vector2.ZERO
	_acel = Vector2.ZERO
	_ligado = false
	if malha != null:
		malha.aplicar_balanco(0.0)
	for i in 3:
		if i < _meio.size() and _meio[i] != null:
			_meio[i].rotation = 0.0
		if i < _barra.size() and _barra[i] != null:
			_barra[i].rotation = 0.0


func _process(delta: float) -> void:
	if _raiz == null or _rec == null or delta <= 0.0:
		return
	# nada a calcular se a saia nao esta na tela -- varios NPCs de saia nao podem
	# custar seis molas cada um o tempo todo.
	if not malha.visivel():
		return

	var pos := _raiz.global_position
	if not _ligado:
		_pos_ant = pos
		_ligado = true
	var v := (pos - _pos_ant) / delta
	_pos_ant = pos
	# duas medias exponenciais: diferenca finita crua de posicao e' ruido puro.
	# O filtro e' o que separa balanco de tremor.
	var k := 1.0 - exp(-delta * 18.0)
	var v_ant := _vel
	_vel = _vel.lerp(v, k)
	_acel = _acel.lerp((_vel - v_ant) / delta, k)

	# PARADO NAO TREME. Abaixo do limiar o alvo e' exatamente zero, entao a mola
	# converge para o repouso em vez de perseguir ruido de subpixel.
	var a := _acel.x
	if _vel.length() < _rec.limiar_parado:
		a = 0.0

	# os tres nao se movem em bloco -- a fase muda de coluna para coluna, e e'
	# isso que separa pano de placa.
	var base := clampf(-_rec.ganho * a, -_rec.limite, _rec.limite)
	var alvo := Vector3(base * 1.06, base, base * 0.94)
	var w := TAU * _rec.rigidez
	_vel_ang += (w * w * (alvo - _ang) - 2.0 * _rec.amortecimento * w * _vel_ang) * delta
	_ang += _vel_ang * delta
	_ang = _limitar(_ang, _rec.limite)

	# segundo estagio: a barra persegue o corpo da saia com mola mais mole e
	# menos amortecida. Ela chega depois e passa do ponto -- e' o atraso que faz
	# a barra ler como tecido em vez de aba rigida.
	var wb := TAU * _rec.rigidez_barra
	_vel_bar += (wb * wb * (_ang - _bar)
		- 2.0 * _rec.amortecimento_barra * wb * _vel_bar) * delta
	_bar += _vel_bar * delta
	var atraso := _limitar(_bar - _ang, _rec.limite_barra)
	_bar = _ang + atraso          # devolve o teto ao estado: nao acumula energia

	for i in 3:
		if _meio[i] != null:
			_meio[i].rotation = deg_to_rad(_ang[i])
		if _barra[i] != null:
			_barra[i].rotation = deg_to_rad(atraso[i])
	malha.aplicar_balanco(_ang.y * 0.35)


func _limitar(v: Vector3, lim: float) -> Vector3:
	return Vector3(clampf(v.x, -lim, lim), clampf(v.y, -lim, lim),
		clampf(v.z, -lim, lim))

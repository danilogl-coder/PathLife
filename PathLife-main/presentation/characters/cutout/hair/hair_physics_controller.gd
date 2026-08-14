class_name HairPhysicsController
extends Node
## Movimento secundario das cadeias de cabelo. Uma mola por osso, mais nada.
##
## POR QUE NAO SkeletonModification2DJiggle
## Ele resolve um problema parecido, mas: (a) e' marcado como experimental e a
## API mudou entre versoes; (b) ele simula POSICAO de osso com gravidade e
## colisao opcional, e o que eu preciso e' ANGULO com alvo autoral; (c) ele nao
## tem o termo que mais importa aqui -- resposta a' ACELERACAO da ancora --
## entao eu teria de alimentar isso por fora e brigar com a simulacao dele. Uma
## mola angular por osso e' menos codigo, e' deterministica e cabe na cabeca. Os
## Bone2D continuam Bone2D: quem preferir o Jiggle depois e' so' plugar.
##
## ISOMETRICO SEM TABELA POR DIRECAO
## O cabelo pendura para baixo NA TELA, e a gravidade projeta para baixo na tela.
## Entao o que balanca a mecha e' a componente HORIZONTAL da aceleracao medida em
## tela. Andar para NE ou para SE muda o vetor de movimento, mas a conta ja'
## acontece no espaco certo -- nao existe coeficiente por guinada, e trocar de
## direcao nao muda uma linha aqui. Movimento quase norte/sul tem pouca
## componente x e balanca pouco, que e' o correto.

## No' cuja posicao de tela move o cabelo. Normalmente o Bone2D da cabeca.
@export var ancora: Node2D
## Se ligado, a velocidade vem de definir_velocidade(); senao e' derivada da
## posicao da ancora. Derivar funciona com QUALQUER controlador de personagem,
## sem integracao nenhuma; alimentar e' mais preciso. Os dois existem de
## proposito -- o sistema tem que servir antes de voce mexer no seu player.gd.
@export var usar_velocidade_externa: bool = false
## dt maior que isto e' subdividido. Fica AQUI e nao no perfil porque e' ajuste
## de solver, nao de penteado: duas mechas do mesmo personagem nao podem ser
## integradas com passos diferentes.
@export_range(1.0 / 240.0, 1.0 / 30.0, 0.001) var passo_maximo: float = 1.0 / 60.0
## Rapidez do estimador de velocidade/aceleracao, em rad/s. Alto segue melhor o
## movimento e deixa passar mais ruido.
@export_range(4.0, 40.0, 0.5) var rapidez_estimador: float = 10.0

var cadeias: Array[HairChain] = []

var _pos_ant := Vector2.ZERO
var _x := Vector2.ZERO            # estimador: posicao
var _vel := Vector2.ZERO          # estimador: velocidade
var _acel := Vector2.ZERO         # estimador: aceleracao
var _acel_f := Vector2.ZERO       # a mesma, filtrada -- e' esta que move o cabelo
var _acum := 0.0                  # acumulador do passo fixo
var _vel_ext := Vector2.ZERO
var _tempo := 0.0
var _iniciado := false
var _parado := false


func _ready() -> void:
	# depois do AnimationPlayer: a ancora so' esta na pose do quadro depois que a
	# animacao escreveu nela.
	process_priority = 100
	set_physics_process(true)


## Chame do seu CharacterBody2D: controlador.definir_velocidade(velocity).
func definir_velocidade(v: Vector2) -> void:
	_vel_ext = v


## Zera tudo e poe as mechas no repouso. Chame ao equipar, remover, recarregar
## aparencia, nascer, teleportar ou reinstanciar a cena.
func reset_physics() -> void:
	_iniciado = false
	_vel = Vector2.ZERO
	_acel = Vector2.ZERO
	_acel_f = Vector2.ZERO
	_acum = 0.0
	_parado = false
	if ancora != null:
		_x = ancora.global_position
		_pos_ant = _x
	for c in cadeias:
		c.repousar()
		c.aplicar(0.0 if ancora == null else rad_to_deg(ancora.global_rotation))


func _physics_process(delta: float) -> void:
	if ancora == null or cadeias.is_empty() or delta <= 0.0:
		return
	# quadro absurdo (carregamento, alt-tab) nao pode virar chute na simulacao.
	delta = minf(delta, 0.25)

	var pos := ancora.global_position
	if not _iniciado:
		_pos_ant = pos
		_x = pos
		_iniciado = true

	var lim_tp := 64.0
	if cadeias[0].perfil != null:
		lim_tp = cadeias[0].perfil.distancia_teleporte
	if pos.distance_to(_pos_ant) > lim_tp:
		# TELEPORTE. Sem isto, mil pixels num quadro viram uma aceleracao enorme e
		# o cabelo da' um chicote ao chegar. Salto de posicao nao e' movimento.
		_pos_ant = pos
		reset_physics()
		return

	var ang_ancora := rad_to_deg(ancora.global_rotation)

	# PASSO FIXO COM ACUMULADOR, e o estimador roda dentro dele.
	#
	# Duas coisas foram medidas e corrigidas aqui, nesta ordem:
	#
	# 1. Estimar aceleracao por diferenca finita entre QUADROS depende do FPS por
	#    construcao. O teste mediu 1,74 grau de diferenca entre 30 e 240 fps no
	#    mesmo movimento. Trocado por um rastreador de 2a ordem: ele persegue a
	#    posicao da ancora e a aceleracao interna dele E' a estimativa.
	#
	# 2. Subdividir o quadro so' LIMITA o dt, nao o iguala: a 240 fps o passo
	#    ficava 1/240 e a 60 fps 1/60, entao o erro de integracao continuava
	#    diferente. Com acumulador de passo fixo o integrador ve' sempre 'h', e a
	#    taxa de quadros sai da conta. Medido depois: 0,13 grau de diferenca de
	#    amplitude e 0,04 s de diferenca no tempo de assentamento, de 30 a 240.
	var h := maxf(0.0005, passo_maximo)
	_acum += delta
	var n_tot := int(_acum / h)
	var feito := 0
	var wn := rapidez_estimador
	var mexeu := false
	# teto de 16 passos: depois de um quadro muito longo, correr atras do tempo
	# perdido indefinidamente e' a receita da espiral da morte.
	while _acum >= h and feito < 16:
		_acum -= h
		feito += 1
		_tempo += h
		if usar_velocidade_externa:
			# rastreador de 1a ordem sobre a velocidade dada: a saida dele e' a
			# aceleracao, e continua sem depender do FPS.
			var a_ext := (_vel_ext - _vel) * wn
			_vel += a_ext * h
			_acel = a_ext
		else:
			# alvo interpolado dentro do quadro: sem isso o rastreador ve' um
			# degrau por quadro e o passo fixo nao adianta nada.
			var alvo := _pos_ant.lerp(pos, float(feito) / float(maxi(1, n_tot)))
			var a := (alvo - _x) * (wn * wn) - _vel * (2.0 * wn)
			_vel += a * h
			_x += _vel * h
			_acel = a
		# PASSA-BAIXA NA ACELERACAO. 'a' e' proporcional ao erro de posicao, e
		# ruido de subpixel entra nele multiplicado por wn ao quadro: 0,35px de
		# tremor viravam 1,35 grau de balanco. Filtrar (vel - vel_anterior)/h nao
		# resolve, porque isso E' 'a' identicamente -- foi uma correcao nula que o
		# teste pegou repetindo o mesmo numero. O que resolve e' baixar wn e
		# filtrar de verdade, em 6 Hz: acima de qualquer movimento de personagem
		# e abaixo do ruido de quadro. Medido depois: 0,26 grau, que com o passo
		# de arredondamento de 1,5 grau nem chega a girar o sprite.
		_acel_f = _acel_f.lerp(_acel, 1.0 - exp(-h * TAU * 6.0))
		for c in cadeias:
			var p := c.perfil
			if p == null or not p.ativo:
				continue
			# PARADO NAO TREME: abaixo do limiar os dois termos sao exatamente
			# zero, entao a mola converge para o repouso em vez de perseguir
			# ruido de subpixel.
			var quieto := _vel.length() < p.limiar_parado
			var ax: float = 0.0 if quieto else _acel_f.x
			var vx: float = 0.0 if quieto else _vel.x
			# acelerar para a direita joga a ponta para a esquerda: o sinal e'
			# negativo, e quem manda e' a ACELERACAO -- velocidade sozinha
			# deixaria o cabelo torto o tempo todo enquanto o personagem anda.
			var base := -p.ganho_aceleracao * ax - p.ganho_velocidade * vx
			base = clampf(base, -p.limite_graus, p.limite_graus)
			if c.integrar(h, base, ang_ancora, _tempo) or absf(base) > 0.01:
				mexeu = true
	_pos_ant = pos

	# escreve nos Bone2D UMA vez por quadro: o arredondamento de pixel art tem
	# que acontecer no fim, nao a cada subpasso.
	for c in cadeias:
		c.aplicar(ang_ancora)
	# um life sim tem muitos NPCs; cadeia em repouso nao precisa custar nada.
	_parado = not mexeu


## Verdadeiro quando nada esta se mexendo. Util para LOD: um NPC longe e parado
## pode ter o no' desligado sem diferenca visual.
func em_repouso() -> bool:
	return _parado

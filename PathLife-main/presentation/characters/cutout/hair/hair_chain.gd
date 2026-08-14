class_name HairChain
extends RefCounted
## Estado vivo de UMA cadeia (uma mecha, um rabo, uma trenca).
##
## O ESTADO E' EM ANGULO DE MUNDO, NAO LOCAL
## Guardar o angulo local de cada osso parece natural e da' errado: cabelo nao
## acompanha a cabeca, acompanha a GRAVIDADE. Com o estado em mundo, "cair" e'
## simplesmente perseguir o angulo zero de tela, e a rotacao local vira o que
## falta para chegar la' a partir do pai. E' um so' termo -- influencia_gravidade
## -- e ele cobre desde franja colada na testa ate' rabo pendular.

var ossos: Array[Bone2D] = []
var perfil: HairPhysicsProfile
var nome: StringName = &""

var _ang := PackedFloat32Array()      # angulo de MUNDO por osso, em graus
var _vel := PackedFloat32Array()
var _amp := PackedFloat32Array()      # 0 na raiz, 1 na ponta
var _fase := 0.0
var _escala_limite := 1.0


func preparar(p: HairPhysicsProfile, escala_limite: float, semente: int) -> void:
	perfil = p
	_escala_limite = escala_limite
	var n := ossos.size()
	_ang.resize(n); _vel.resize(n); _amp.resize(n)
	# fase propria por cadeia: duas chiquinhas com a mesma fase balancam como uma
	# peca so'. O deslocamento e' deterministico (vem do nome), nao aleatorio --
	# a mesma cena tem que ficar igual em toda execucao.
	_fase = float(semente % 617) * 0.0101
	for i in n:
		var t := 0.0 if n <= 1 else float(i) / float(n - 1)
		if p != null and p.curva_amplitude != null:
			_amp[i] = clampf(p.curva_amplitude.sample_baked(t), 0.0, 1.0)
		else:
			var e: float = 1.6 if p == null else p.expoente_amplitude
			_amp[i] = pow(t, e)
	repousar()


func repousar() -> void:
	for i in _ang.size():
		_ang[i] = 0.0
		_vel[i] = 0.0
	for b in ossos:
		if b != null:
			b.rotation = 0.0


## Um passo ja' subdividido. 'base' e' o balanco em graus vindo do movimento;
## 'ang_ancora' e' o angulo de mundo do osso pai da cadeia, em graus.
func integrar(dt: float, base: float, ang_ancora: float, tempo: float) -> bool:
	if perfil == null or not perfil.ativo:
		return false
	var n := _ang.size()
	var idle := 0.0
	if perfil.idle_graus > 0.0:
		var w := TAU * perfil.idle_hz * tempo + _fase
		# duas senoides de razao irracional: o ciclo nunca fecha, entao o olho
		# nao pega o padrao e o idle nao le' como animacao em loop.
		idle = perfil.idle_graus * (sin(w) * 0.6 + sin(w * 1.6180339 + _fase) * 0.4)
	var lim := perfil.limite_graus * _escala_limite
	var mexeu := false
	var pai := ang_ancora
	for i in n:
		# neutro: entre "acompanhar o pai" e "cair na vertical da tela".
		var neutro: float = lerpf(pai, 0.0, perfil.influencia_gravidade)
		var alvo: float = neutro + _amp[i] * (base + idle)
		alvo = clampf(alvo, neutro - lim * _amp[i], neutro + lim * _amp[i])
		# cada osso mais mole que o anterior: o atraso se acumula pela cadeia.
		var f: float = perfil.frequencia * pow(perfil.maciez_por_osso, i)
		var om := TAU * f
		_vel[i] += (om * om * (alvo - _ang[i])
			- 2.0 * perfil.amortecimento * om * _vel[i]) * dt
		_ang[i] += _vel[i] * dt
		# teto absoluto e teto ENTRE ossos. O segundo impede o cotovelo: sem ele
		# dois ossos podem parar em extremos opostos e a mecha dobra no meio.
		_ang[i] = clampf(_ang[i], neutro - lim * _amp[i], neutro + lim * _amp[i])
		var d: float = clampf(_ang[i] - pai, -perfil.limite_entre_ossos,
			perfil.limite_entre_ossos)
		_ang[i] = pai + d
		# TRAVA DE SEGURANCA, absoluta e contra a ANCORA. As duas travas acima
		# sao relativas ao neutro e ao osso anterior, e nenhuma das duas impede
		# a cadeia de somar: com quatro ossos e 8 graus entre eles, a ponta podia
		# chegar a 32. Medido, chegava a 15,2 com teto declarado de 13. Esta
		# ultima e' a que garante a promessa "nunca gira 90 graus".
		_ang[i] = clampf(_ang[i], ang_ancora - lim, ang_ancora + lim)
		if absf(_vel[i]) > 0.05 or absf(_ang[i] - neutro) > 0.02:
			mexeu = true
		pai = _ang[i]
	return mexeu


## Escreve nos Bone2D. Separado da integracao porque a integracao roda varias
## vezes por quadro (subpassos) e escrever no no' uma vez so' e' mais barato --
## e porque o arredondamento de pixel art tem que acontecer UMA vez, no fim.
func aplicar(ang_ancora: float) -> void:
	if perfil == null:
		return
	var passo := perfil.passo_angulo_graus
	var pai_ap := ang_ancora
	for i in ossos.size():
		var a := _ang[i]
		# PIXEL ART: arredonda o angulo de MUNDO, nao o local. E' o de mundo que
		# decide como o Sprite2D reamostra; travando ele, a peca so' troca de
		# pose em degraus e os pixels param de rastejar entre quadros.
		var ap: float = a if passo <= 0.0 else snappedf(a, passo)
		if ossos[i] != null:
			ossos[i].rotation = deg_to_rad(ap - pai_ap)
		pai_ap = ap

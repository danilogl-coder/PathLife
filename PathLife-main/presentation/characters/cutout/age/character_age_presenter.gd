class_name CharacterAgePresenter
extends Node
## Traduz uma idade (StringName) em proporção, postura e ritmo de animação.
## Não decide nada: quem escolhe a idade é o estado, quem guarda os números é o
## .tres do catálogo. Este nó só aplica.
##
## POR QUE A POSTURA É APLICADA TODO QUADRO
## `rotation` é território do AnimationPlayer: ele reescreve os 15 ossos a cada
## quadro. Uma coluna curvada de idoso posta no _ready() ou no .tscn dura um
## quadro e some. Então a curvatura é SOMADA depois da animação, com
## process_priority alto — o mesmo caminho que o HairPhysicsController já usa.

signal profile_changed(profile: AgeProfile)

@export var catalog: AgeCatalog
@export var rig: CharacterRig
@export var animation_player: AnimationPlayer
## 0 = troca seca. Acima disso, o personagem CRESCE até a idade nova. Só vale
## entre idades que compartilham a mesma arte: não há como interpolar dois
## conjuntos de PNG diferentes com uma escala.
@export_range(0.0, 8.0, 0.1) var transicao_segundos: float = 0.0

var _profile: AgeProfile
var _anterior: AgeProfile
var _mistura := AgeProfile.new()
var _postura_alvo := Vector2.ZERO
var _postura_aplicada := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	# Depois do AnimationPlayer. A rotação deste quadro só existe depois que a
	# animação escreveu nela.
	process_priority = 100


func present(age_id: StringName) -> void:
	if catalog == null or rig == null:
		push_error("CharacterAgePresenter está sem catálogo ou rig")
		return
	var profile := catalog.get_profile(catalog.normalize_id(age_id))
	if profile == null or profile == _profile:
		return
	_anterior = _profile
	_profile = profile
	if animation_player != null:
		animation_player.speed_scale = profile.velocidade_animacao

	var pode_interpolar := (
		_anterior != null
		and transicao_segundos > 0.0
		and _anterior.pasta_arte == profile.pasta_arte
	)
	if pode_interpolar:
		_iniciar_transicao()
	else:
		_parar_transicao()
		_postura_alvo = Vector2(profile.curvatura_tronco, profile.curvatura_cabeca)
		rig.set_age_profile(profile)
	profile_changed.emit(profile)


func get_profile() -> AgeProfile:
	return _profile


func invalidate() -> void:
	_profile = null


## Biblioteca de animação da idade, com fallback para a do corpo. É isso que
## deixa uma idade nova funcionar ANTES de existir animação própria para ela.
func animation_library(body_type: String) -> String:
	if _profile != null and _profile.biblioteca_animacao != &"":
		return String(_profile.biblioteca_animacao)
	return body_type


func _process(_delta: float) -> void:
	if rig == null:
		return
	# Nada a fazer se não há postura nem resíduo de postura para desfazer.
	if _postura_alvo.is_equal_approx(Vector2.ZERO) and _postura_aplicada.is_equal_approx(Vector2.ZERO):
		return
	var tronco := rig.get_piece_bone(&"torso")
	var cabeca := rig.get_piece_bone(&"cabeca")
	if tronco == null or cabeca == null:
		return
	# Com animação tocando, o valor lido já é o do quadro (a animação apagou o
	# nosso offset). Sem animação tocando, ele ainda carrega o offset anterior.
	# Descontar antes de somar deixa a conta idempotente nos dois casos.
	if animation_player == null or not animation_player.is_playing():
		tronco.rotation -= _postura_aplicada.x
		cabeca.rotation -= _postura_aplicada.y
	tronco.rotation += _postura_alvo.x
	cabeca.rotation += _postura_alvo.y
	_postura_aplicada = _postura_alvo


func _iniciar_transicao() -> void:
	_parar_transicao()
	_tween = create_tween()
	_tween.tween_method(_aplicar_peso, 0.0, 1.0, transicao_segundos)
	# No fim, o rig volta a apontar para o recurso de verdade em vez da mistura.
	_tween.finished.connect(_assentar_perfil)


func _parar_transicao() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _assentar_perfil() -> void:
	if _profile != null and rig != null:
		rig.set_age_profile(_profile)


func _aplicar_peso(peso: float) -> void:
	rig.set_age_shape(_mistura_em(peso))


func _mistura_em(peso: float) -> AgeProfile:
	_mistura.id = _profile.id
	_mistura.pasta_arte = _profile.pasta_arte
	_mistura.biblioteca_animacao = _profile.biblioteca_animacao
	_mistura.escala_global = lerpf(_anterior.escala_global, _profile.escala_global, peso)
	_mistura.escala_cabeca = lerpf(_anterior.escala_cabeca, _profile.escala_cabeca, peso)
	_mistura.fator_tronco = lerpf(_anterior.fator_tronco, _profile.fator_tronco, peso)
	_mistura.fator_pernas = lerpf(_anterior.fator_pernas, _profile.fator_pernas, peso)
	_mistura.fator_bracos = lerpf(_anterior.fator_bracos, _profile.fator_bracos, peso)
	_mistura.fator_largura = lerpf(_anterior.fator_largura, _profile.fator_largura, peso)
	_postura_alvo = Vector2(
		lerpf(_anterior.curvatura_tronco, _profile.curvatura_tronco, peso),
		lerpf(_anterior.curvatura_cabeca, _profile.curvatura_cabeca, peso)
	)
	return _mistura

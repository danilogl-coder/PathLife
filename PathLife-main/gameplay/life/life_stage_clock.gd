class_name LifeStageClock
extends Node
## O tempo da vida. Só conta e anuncia — não sabe o que uma idade faz, não
## conhece rig, colisão nem menu. Quem escuta stage_changed é o
## CharacterAppearanceState, e dali a mudança desce pelos sinais que já existem.
##
## O Timer é um nó da cena, não criado por código: é previsível e você vai
## querer ajustar o wait_time pelo editor enquanto acerta o ritmo.

signal stage_changed(age_id: StringName)
signal life_ended(age_id: StringName)

@export var catalog: AgeCatalog
@export var idade_inicial: StringName = &"adulto"
@export_range(5.0, 3600.0, 1.0) var segundos_por_estagio: float = 120.0
## Desligado, o relógio existe mas não avança sozinho: chame advance() de um
## aniversário, de um item ou de um botão de debug.
@export var iniciar_automaticamente: bool = false
@export var timer: Timer

var _current: StringName = &""


func _ready() -> void:
	if catalog == null or timer == null:
		push_error("LifeStageClock precisa de catálogo e Timer no Inspector.")
		return
	_current = catalog.normalize_id(idade_inicial)
	timer.wait_time = segundos_por_estagio
	timer.one_shot = false
	if iniciar_automaticamente:
		timer.start()
	# call_deferred: o AppearanceState também publica no _ready dele, e quem
	# chega depois vence. A idade inicial tem que ser a última palavra.
	_publicar.call_deferred()


func get_age() -> StringName:
	return _current


## Avança uma fase. Serve para o Timer, para um item, para um evento de história
## ou para um botão de debug — o gatilho não muda nada aqui.
func advance() -> void:
	if catalog == null:
		return
	if catalog.is_last(_current):
		if timer != null:
			timer.stop()
		life_ended.emit(_current)
		return
	_current = catalog.next_id(_current)
	_publicar()


func set_age(age_id: StringName) -> void:
	if catalog == null:
		return
	var normalized := catalog.normalize_id(age_id)
	if normalized == _current:
		return
	_current = normalized
	_publicar()


func _on_timer_timeout() -> void:
	advance()


func _publicar() -> void:
	stage_changed.emit(_current)

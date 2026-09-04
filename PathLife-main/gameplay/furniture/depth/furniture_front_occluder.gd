## Faixa da frente de um móvel comprido: aqui quem passa por cima é o ATOR.
##
## [b]Por que isto existe[/b]: o Y-Sort ordena cada objeto por UM único ponto.
## Isso descreve bem um objeto de uma célula, mas não uma cama, que ocupa cerca
## de 1,4 célula. A âncora da cama precisa ficar no ponto mais baixo do desenho,
## senão o PISO das células da frente — que é desenhado depois — passa por cima
## dela. O efeito colateral é a cama disputar profundidade como se estivesse
## inteira na fileira da frente: o ator parado ao LADO DA CABECEIRA, que está
## visivelmente à frente, tem chave menor e acaba desenhado ATRÁS da cama.
##
## Esta área marca exatamente as células onde isso acontece. Enquanto o ator está
## dentro dela, o componente empurra a CHAVE DE ORDENAÇÃO do ator meia célula
## para a frente, através de [method WorldGridAgent.set_extra_sort_bias]. O
## desenho não se move um pixel — o viés entra na âncora e sai do corpo — e
## ninguém muda de z_index: o mundo continua com um único plano de Y-Sort.
##
## É o espelho do [FurnitureTopOccluder], que resolve o caso contrário: o ator
## caminha por trás da borda de cima e é o MÓVEL que precisa cobri-lo.
##
## Uso: desenhe o polígono cobrindo as células vizinhas em que o ator está à
## frente do móvel mas seria ordenado atrás. Uma célula (o losango de
## 128 × 64 px) costuma bastar para a cama.
class_name FurnitureFrontOccluder
extends Area2D

signal actor_entered(actor: Node2D)
signal actor_exited(actor: Node2D)
signal front_changed(is_active: bool)

@export_category("Ordenação")
## Quanto o ator avança na chave do Y-Sort enquanto está na faixa.
## 32 px = meia célula = uma fileira isométrica.
@export_range(0.0, 256.0, 1.0) var actor_sort_bias: float = 32.0

@export_category("Filtro")
@export var actor_group: StringName = &"depth_actor"

var _agents_inside: Dictionary = {}


func is_active() -> bool:
	return not _agents_inside.is_empty()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(actor_group):
		return
	var agent := _agent_of(body)
	if agent == null:
		return

	_agents_inside[body.get_instance_id()] = agent
	agent.set_extra_sort_bias(actor_sort_bias)
	actor_entered.emit(body)
	front_changed.emit(true)


func _on_body_exited(body: Node2D) -> void:
	var body_id := body.get_instance_id()
	if not _agents_inside.has(body_id):
		return

	var agent: WorldGridAgent = _agents_inside[body_id]
	_agents_inside.erase(body_id)
	if agent != null and is_instance_valid(agent):
		agent.set_extra_sort_bias(0.0)
	actor_exited.emit(body)
	front_changed.emit(is_active())


## O ator carrega a posição lógica no [WorldGridAgent]; é ele quem sabe somar o
## viés sem mexer no desenho.
func _agent_of(body: Node2D) -> WorldGridAgent:
	for node: Node in body.find_children("*", "WorldGridAgent", true, false):
		var agent := node as WorldGridAgent
		if agent != null:
			return agent
	return null

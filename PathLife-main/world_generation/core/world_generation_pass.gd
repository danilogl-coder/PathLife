## Interface de um passe da pipeline de geração.
##
## Cada passe é um [Resource]: você monta a pipeline no Inspector, arrastando
## passes para o array do [WorldGenerator]. Adicionar um sistema novo (rios,
## estradas, minério) = criar um novo script que herda daqui e arrastar para a
## lista. O núcleo não muda.
@abstract
class_name WorldGenerationPass
extends Resource

## Nome exibido só para organização no Inspector.
@export var pass_name: String = ""
## Desligue para testar a pipeline sem remover o passe.
@export var enabled: bool = true


## Sobrescreva. NUNCA toque na SceneTree aqui: roda em worker thread.
func run(_context: GenerationContext) -> void:
	pass


## Chamado uma vez na main thread antes de qualquer geração.
func prepare(_settings: WorldSettings, _world_seed: int) -> void:
	pass


## Cópia independente do passe, para rodar em outra thread sem disputa.
##
## `Resource.duplicate(true)` NÃO copia recursos dentro de arrays, então a
## clonagem da pipeline é explícita. O dicionário `shared` preserva a
## identidade: se dois passes apontam para o mesmo amostrador, os clones também
## apontarão para um único clone dele.
func clone_pass(shared: Dictionary) -> WorldGenerationPass:
	var copy: WorldGenerationPass = duplicate(false)
	copy.rebind_shared(shared)
	return copy


## Sobrescreva para reapontar os recursos compartilhados do passe.
func rebind_shared(_shared: Dictionary) -> void:
	pass


## Clona um recurso compartilhado apenas uma vez por pipeline.
##
## Se o recurso souber se clonar para thread (`clone_for_thread`), usa esse
## caminho — mais barato e mais correto do que `duplicate(true)`, que no Godot
## 4.4+ não copia sub-recursos externos.
static func shared_clone(shared: Dictionary, resource: Resource) -> Resource:
	if resource == null:
		return null
	if not shared.has(resource):
		if resource.has_method(&"clone_for_thread"):
			shared[resource] = resource.call(&"clone_for_thread")
		else:
			shared[resource] = resource.duplicate(true)
	return shared[resource]

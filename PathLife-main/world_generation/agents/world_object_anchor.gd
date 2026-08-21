## Ancora um objeto estático (mobília, prédio, marco) na grade isométrica.
##
## [b]Por que isto existe[/b]: no mundo procedural, desenhar e ordenar são
## coisas diferentes. Um objeto no alto de um morro aparece 26px acima por
## nível, mas continua ocupando a MESMA célula do chão — e é a célula que decide
## quem fica na frente de quem. Um [Node2D] solto, posicionado direto em pixels,
## não sabe disso: ele é ordenado pela posição visual e acaba coberto pela grama
## que deveria estar atrás dele.
##
## A âncora separa as duas coisas: o NÓ fica na posição PLANA da célula (é ela
## que entra no Y-Sort) e os FILHOS recebem só o deslocamento vertical da altura
## do terreno. É o mesmo princípio do [WorldGridAgent] do jogador.
##
## Uso: coloque o objeto como filho desta cena e arraste a âncora onde quiser.
## Com [member derive_cell_from_position] ligado, a célula é lida da própria
## posição — o fluxo de trabalho no editor continua sendo "arrastar e soltar".
class_name WorldObjectAnchor
extends Node2D

## Grupo consultado pelo [ProceduralWorld] para assentar os objetos assim que o
## terreno existe. Sem isto a âncora não teria como saber a altura do chão.
const GROUP := &"world_object_anchor"

@export_category("Posição na grade")
## Célula usada quando [member derive_cell_from_position] está desligado.
@export var world_cell: Vector2i = Vector2i.ZERO
## Lê a célula da posição em que o nó foi colocado no editor.
@export var derive_cell_from_position: bool = true

@export_category("Altura")
## Acompanha o relevo: a altura vem do terreno gerado sob a célula.
@export var follow_terrain: bool = true
## Altura fixa, usada quando [member follow_terrain] está desligado.
@export var height_level: int = 0

var _authored_offsets: Dictionary = {}
var _cell: Vector2i = Vector2i.ZERO
var _level: int = 0
var _placed: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	# A âncora carrega a posição da célula; quem gira o Y-Sort é o pai.
	y_sort_enabled = false
	_remember_children()


## Chamado pelo [ProceduralWorld] quando o terreno da região já foi gerado.
func snap_to_world(world: WorldData, settings: WorldSettings) -> void:
	if settings == null:
		return
	var iso := IsoCoordinateSystem.from_settings(settings)
	if not _placed and derive_cell_from_position:
		world_cell = iso.local_to_cell(position)
	_cell = world_cell
	_level = height_level
	if follow_terrain and world != null:
		_level = world.height_at(_cell)
	_placed = true

	var bias := iso.prop_sort_bias()
	position = iso.cell_to_local(_cell) + Vector2(0.0, bias)
	var offset := Vector2(0.0, -float(_level * iso.height_pixels) - bias)
	_remember_children()
	for child in get_children():
		var node := child as Node2D
		if node != null:
			node.position = _authored_offsets.get(node.get_instance_id(), Vector2.ZERO) + offset


func cell() -> Vector2i:
	return _cell


func level() -> int:
	return _level


## Guarda o deslocamento com que cada filho foi autorado, para a âncora somar a
## altura sem apagar um ajuste fino feito no editor.
func _remember_children() -> void:
	for child in get_children():
		var node := child as Node2D
		if node != null and not _authored_offsets.has(node.get_instance_id()):
			_authored_offsets[node.get_instance_id()] = node.position

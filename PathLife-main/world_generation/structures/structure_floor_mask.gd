## Quais células a CENA de uma construção cobre com piso próprio.
##
## O footprint é um número na definição; o piso é um desenho na cena. Quando os
## dois discordam — alguém pintou uma sala a mais e esqueceu de subir o
## `footprint` —, quem manda no chão do mundo tem que ser o DESENHO. Senão a
## célula extra continua com grama e a grama volta a aparecer sobre as tábuas.
##
## A leitura é cara (instancia a cena uma vez) e por isso acontece uma única vez
## por definição, na thread principal, durante o `prepare()` do passe. Depois
## disso os workers só LEEM o dicionário.
class_name StructureFloorMask
extends RefCounted

## Categorias do TileSet que contam como piso da construção.
const FLOOR_CATEGORIES: Array[String] = ["piso"]

static var _cells_cache: Dictionary = {}
static var _reach_cache: Dictionary = {}


## Células locais (relativas à origem do footprint) cobertas por piso.
##
## Fora da thread principal responde SÓ pelo cache. Ler a cena instancia nós, e
## instanciar cena em worker é receita de erro silencioso: a geração do chunk
## morreria no meio e a casa simplesmente não nasceria. Quem enche o cache é o
## [method warm], chamado no `prepare()` do passe.
static func cells_for(definition: StructureDefinition) -> Dictionary:
	if definition == null or definition.scene == null:
		return {}
	var key := _key(definition)
	if _cells_cache.has(key):
		return _cells_cache[key]
	if not _on_main_thread():
		return {}
	var cells := _read(definition)
	_cells_cache[key] = cells
	return cells


## Quantas células o piso desenhado passa do footprint declarado.
##
## Vale 0 quando a cena não passa do footprint — o caso normal. É este número
## que o varredor do chunk usa para saber até onde precisa olhar.
static func reach_for(definition: StructureDefinition) -> int:
	if definition == null:
		return 0
	var key := _key(definition)
	if _reach_cache.has(key):
		return _reach_cache[key]
	if not _on_main_thread():
		return 0
	var footprint := Rect2i(Vector2i.ZERO, definition.footprint)
	var reach := 0
	for cell: Vector2i in cells_for(definition):
		reach = maxi(reach, int(TerrainAdapter.distance_to_rect(cell, footprint)))
	_reach_cache[key] = reach
	return reach


## Lê todas as definições de uma vez, na thread principal, antes da geração.
static func warm(definitions: Array[StructureDefinition]) -> void:
	for definition in definitions:
		if definition != null:
			reach_for(definition)


static func clear_cache() -> void:
	_cells_cache.clear()
	_reach_cache.clear()


static func _on_main_thread() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()


static func _key(definition: StructureDefinition) -> String:
	if definition.scene != null and definition.scene.resource_path != "":
		return definition.scene.resource_path
	return str(definition.get_instance_id())


static func _read(definition: StructureDefinition) -> Dictionary:
	var cells: Dictionary = {}
	var instance := definition.scene.instantiate()
	for descendant: Node in instance.find_children("*", "TileMapLayer", true, false):
		var layer := descendant as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null:
				continue
			if String(data.get_custom_data(&"categoria")) in FLOOR_CATEGORIES:
				cells[cell] = true
	instance.free()
	return cells

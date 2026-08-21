## Tudo que um passe de geração precisa. Passado de passe em passe.
class_name GenerationContext
extends RefCounted

var world_seed: int = 0
var settings: WorldSettings
var chunk_coord: Vector2i = Vector2i.ZERO
var chunk_data: ChunkData
## Estruturas planejadas pela região macro que tocam este chunk.
var planned_structures: Array[StructurePlacement] = []
## Espaço livre para passes trocarem informação sem alterar o núcleo.
var scratch: Dictionary = {}


func chunk_size() -> int:
	return settings.chunk_size


func origin() -> Vector2i:
	return chunk_coord * settings.chunk_size


func world_of(local: Vector2i) -> Vector2i:
	return origin() + local


func cell(local: Vector2i) -> WorldCell:
	return chunk_data.get_cell(local)


## Itera todas as células locais do chunk.
func each_local() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var s := settings.chunk_size
	result.resize(s * s)
	var i := 0
	for y in s:
		for x in s:
			result[i] = Vector2i(x, y)
			i += 1
	return result

## Uma estrutura JÁ decidida: onde fica, em que altura e com que definição.
## É dado puro — quem instancia a cena é o renderer, na main thread.
class_name StructurePlacement
extends RefCounted

var definition: StructureDefinition
## Célula do canto (mínimo x, mínimo y) do footprint, em coordenada mundial.
var origin_xy: Vector2i = Vector2i.ZERO
var foundation_height: int = 0
## Id determinístico: mesma semente + mesma região = mesmo id.
var placement_id: int = 0


func _init(p_definition: StructureDefinition = null, p_origin: Vector2i = Vector2i.ZERO) -> void:
	definition = p_definition
	origin_xy = p_origin


func footprint() -> Vector2i:
	return definition.footprint if definition != null else Vector2i.ONE


func rect() -> Rect2i:
	return Rect2i(origin_xy, footprint())


## Retângulo incluindo a margem de adaptação do terreno.
func influence_rect() -> Rect2i:
	var margin := definition.adaptation_margin if definition != null else 0
	return rect().grow(margin)


func center_cell() -> Vector2i:
	var size := footprint()
	return origin_xy + Vector2i(size.x / 2, size.y / 2)


func world_position() -> Vector3i:
	var center := center_cell()
	return Vector3i(center.x, center.y, foundation_height)


func overlaps_chunk(chunk_coord: Vector2i, chunk_size: int) -> bool:
	var chunk_rect := Rect2i(chunk_coord * chunk_size, Vector2i(chunk_size, chunk_size))
	return influence_rect().intersects(chunk_rect)

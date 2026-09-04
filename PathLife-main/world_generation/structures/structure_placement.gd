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


## Retângulo com TODO o alcance da estrutura sobre o mundo.
##
## Inclui a margem de adaptação do relevo e a de limpeza do chão — é por este
## retângulo que o chunk decide se precisa aplicar a estrutura, então uma margem
## esquecida aqui viraria meia casa com grama e meia sem, na borda do chunk.
func influence_rect() -> Rect2i:
	if definition == null:
		return rect()
	var margin := definition.adaptation_margin
	if definition.clears_ground_cover:
		margin = maxi(margin, definition.bare_ground_margin)
		margin = maxi(margin, StructureFloorMask.reach_for(definition))
	return rect().grow(margin)


func center_cell() -> Vector2i:
	var size := footprint()
	return origin_xy + Vector2i(
		floori(float(size.x) / 2.0),
		floori(float(size.y) / 2.0)
	)


func world_position() -> Vector3i:
	var center := center_cell()
	return Vector3i(center.x, center.y, foundation_height)


func overlaps_chunk(chunk_coord: Vector2i, chunk_size: int) -> bool:
	var chunk_rect := Rect2i(chunk_coord * chunk_size, Vector2i(chunk_size, chunk_size))
	return influence_rect().intersects(chunk_rect)

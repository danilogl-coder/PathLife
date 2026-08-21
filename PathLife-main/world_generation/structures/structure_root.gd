## Raiz de uma cena de estrutura.
##
## Coloque este script na raiz do `.tscn` da construção e ligue o
## [member definition]. Com [member draw_footprint] ligado, o editor desenha o
## losango do footprint para você posicionar paredes e móveis com precisão.
@tool
class_name StructureRoot
extends Node2D

@export var definition: StructureDefinition:
	set(value):
		definition = value
		queue_redraw()
		update_configuration_warnings()

## Usado pelo gizmo quando [member definition] está vazio (evita referência
## circular entre a cena e o `.tres`).
@export var footprint_preview: Vector2i = Vector2i(4, 4):
	set(value):
		footprint_preview = value
		queue_redraw()

@export var draw_footprint_gizmo: bool = true:
	set(value):
		draw_footprint_gizmo = value
		queue_redraw()

@export var gizmo_color: Color = Color(0.2, 1.0, 0.6, 0.55):
	set(value):
		gizmo_color = value
		queue_redraw()

@export_group("Projeção (só para o gizmo)")
@export var tile_size: Vector2i = Vector2i(128, 64):
	set(value):
		tile_size = value
		queue_redraw()

var _placement: StructurePlacement


## Chamado pelo renderer logo após instanciar a cena.
func setup(placement: StructurePlacement) -> void:
	_placement = placement


func placement() -> StructurePlacement:
	return _placement


## Todos os marcadores da cena, por tipo.
func markers_of_type(marker_type: StructureMarker.MarkerType) -> Array[StructureMarker]:
	var result: Array[StructureMarker] = []
	_collect_markers(self, marker_type, result)
	return result


func _collect_markers(
	node: Node, marker_type: StructureMarker.MarkerType, out: Array[StructureMarker]
) -> void:
	for child in node.get_children():
		var marker := child as StructureMarker
		if marker != null and marker.marker_type == marker_type:
			out.append(marker)
		_collect_markers(child, marker_type, out)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not draw_footprint_gizmo:
		return
	var iso := IsoCoordinateSystem.new(tile_size, 26)
	var size := definition.footprint if definition != null else footprint_preview
	if size.x <= 0 or size.y <= 0:
		return
	var corners := PackedVector2Array([
		iso.cell_to_local(Vector2i(0, 0)) + Vector2(0.0, -tile_size.y * 0.5),
		iso.cell_to_local(Vector2i(size.x, 0)) + Vector2(tile_size.x * 0.5, 0.0),
		iso.cell_to_local(Vector2i(size.x, size.y)) + Vector2(0.0, tile_size.y * 0.5),
		iso.cell_to_local(Vector2i(0, size.y)) + Vector2(-tile_size.x * 0.5, 0.0),
	])
	draw_colored_polygon(corners, Color(gizmo_color.r, gizmo_color.g, gizmo_color.b, 0.18))
	corners.append(corners[0])
	draw_polyline(corners, gizmo_color, 2.0)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()

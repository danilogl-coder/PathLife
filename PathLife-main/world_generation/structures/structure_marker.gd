## Ponto de referência dentro de uma cena de estrutura.
##
## Visível e arrastável no editor. Outros sistemas (estradas, NPCs, entregas)
## consultam esses marcadores em vez de adivinhar posições.
@tool
class_name StructureMarker
extends Marker2D

enum MarkerType {
	ENTRANCE,
	ROAD,
	NPC_SPAWN,
	DELIVERY,
	INTERACTION,
	CUSTOM,
}

@export var marker_type: MarkerType = MarkerType.ENTRANCE:
	set(value):
		marker_type = value
		update_configuration_warnings()
## Usado quando [member marker_type] é CUSTOM.
@export var custom_tag: StringName = &""
## Deslocamento lógico em células, relativo à origem do footprint.
@export var cell_offset: Vector2i = Vector2i.ZERO


func tag() -> StringName:
	if marker_type == MarkerType.CUSTOM:
		return custom_tag
	return StringName(MarkerType.keys()[marker_type])


func _get_configuration_warnings() -> PackedStringArray:
	if marker_type == MarkerType.CUSTOM and custom_tag == &"":
		return PackedStringArray(["Marcador CUSTOM precisa de um custom_tag."])
	return PackedStringArray()

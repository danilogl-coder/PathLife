@tool
class_name PlayerSpawnMarker
extends StructureMarker


func _ready() -> void:
	marker_type = MarkerType.PLAYER_SPAWN
	var preview := get_node_or_null(^"EditorPreview") as CanvasItem
	if preview != null:
		preview.visible = Engine.is_editor_hint()
	_sync_cell_from_tilemap.call_deferred()


func _sync_cell_from_tilemap() -> void:
	var marker_layer := get_parent() as TileMapLayer
	if marker_layer != null:
		cell_offset = marker_layer.local_to_map(position)

## Liga um id lógico de chão (ex.: &"campo") a um tile concreto do TileSet.
class_name GroundTileEntry
extends Resource

@export var ground_id: StringName = &"campo"
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0

## Abertura mutável que ocupa uma VisionEdge.
class_name VisionPortal
extends RefCounted

const DOOR: StringName = &"door"
const WINDOW: StringName = &"window"
const EXTERIOR_ZONE: int = -1

var id: StringName = &""
var kind: StringName = DOOR
var cell_a: Vector3i = Vector3i.ZERO
var cell_b: Vector3i = Vector3i.ZERO
var direction: StringName = &""
var placement_id: int = 0
var authored_cell: Vector2i = Vector2i.ZERO
var environment: StringName = &""
var is_open: bool = false
var permanent: bool = false
var zone_a: int = EXTERIOR_ZONE
var zone_b: int = EXTERIOR_ZONE


func transmits_sight(profile: Resource = null) -> bool:
	if permanent:
		return true
	if not is_open:
		return false
	if kind == WINDOW and profile != null:
		return float(profile.get("open_window_transmission")) > 0.0
	return true


func reveal_depth(profile: Resource) -> int:
	if profile == null:
		return 0
	if kind == WINDOW:
		return int(profile.get("window_reveal_depth_cells"))
	return int(profile.get("door_reveal_depth_cells"))


func other_zone(zone_id: int) -> int:
	if zone_id == zone_a:
		return zone_b
	if zone_id == zone_b:
		return zone_a
	return EXTERIOR_ZONE


func edge_key() -> StringName:
	return preload("res://world_generation/visibility/vision_edge.gd").key_for(cell_a, cell_b)


func stable_stem() -> String:
	var text := String(id)
	var separator := text.rfind("|")
	return text.left(separator) if separator >= 0 else text


static func normalize_kind(value: Variant) -> StringName:
	var text := String(value).to_lower()
	if text in ["janela", "window"]:
		return WINDOW
	return DOOR


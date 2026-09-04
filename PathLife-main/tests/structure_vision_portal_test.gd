## Contrato dos portais de visão expostos por StructureRoot.
##
## Uso:
##   godot --headless --path . --script res://tests/structure_vision_portal_test.gd
extends SceneTree

const HOUSE_SCENE := "res://presentation/world/structures/casa_madeira_tilemap.tscn"
const HOUSE_DEFINITION := "res://data/world/structures/casa_madeira.tres"
const PLACEMENT_ID := 7355608

var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n[StructureRoot] contrato dos portais de visão")
	var packed := load(HOUSE_SCENE) as PackedScene
	_check(packed != null, "cena da casa carrega")
	if packed == null:
		_finish()
		return

	var house := packed.instantiate() as StructureRoot
	_check(house != null, "raiz da casa é StructureRoot")
	if house == null:
		_finish()
		return
	var placement := StructurePlacement.new(load(HOUSE_DEFINITION), Vector2i(21, -9))
	placement.placement_id = PLACEMENT_ID
	house.setup(placement)
	root.add_child(house)
	await process_frame

	var portals := house.vision_portals()
	_check(portals.size() == 10, "casa expõe exatamente dez portais", str(portals.size()))
	var door_count := 0
	var window_count := 0
	var contains_jamb := false
	var ids: Dictionary = {}
	var door: Dictionary = {}
	var window: Dictionary = {}
	for descriptor: Dictionary in portals:
		var kind := StringName(descriptor.get("kind", &""))
		var portal_id := StringName(descriptor.get("id", &""))
		var layer := descriptor.get("layer") as TileMapLayer
		var cell := descriptor.get("cell", Vector2i.ZERO) as Vector2i
		var data := layer.get_cell_tile_data(cell) if layer != null else null
		var piece := String(data.get_custom_data(&"peca")) if data != null else ""
		contains_jamb = contains_jamb or piece.begins_with("montante_")

		if kind == &"door":
			door_count += 1
			if door.is_empty():
				door = descriptor
		elif kind == &"window":
			window_count += 1
			if window.is_empty():
				window = descriptor

		_check(
			String(portal_id).ends_with("|%s" % String(kind)),
			"ID %s termina no tipo normalizado" % portal_id
		)
		_check(
			String(portal_id).begins_with("%d|" % PLACEMENT_ID),
			"ID %s usa placement_id estável" % portal_id
		)
		_check(
			layer != null and house.vision_portal_id(layer, cell) == portal_id,
			"descriptor e vision_portal_id coincidem em %s" % cell
		)
		ids[portal_id] = true

	_check(door_count == 4, "casa expõe quatro portas", str(door_count))
	_check(window_count == 6, "casa expõe seis janelas", str(window_count))
	_check(not contains_jamb, "montantes nunca são retornados como portal")
	_check(ids.size() == portals.size(), "todos os IDs de portal são únicos")
	var original_ids := _sorted_ids(portals)

	_test_direct_round_trip(house, door, &"door", original_ids)
	_test_direct_round_trip(house, window, &"window", original_ids)

	house.queue_free()
	await process_frame
	_finish()


func _test_direct_round_trip(
	house: StructureRoot,
	descriptor: Dictionary,
	kind: StringName,
	original_ids: Array[String]
) -> void:
	_check(not descriptor.is_empty(), "há %s disponível para o round-trip" % kind)
	if descriptor.is_empty():
		return
	var portal_id := StringName(descriptor["id"])
	_check(not bool(descriptor["permanent"]), "%s de teste não é permanente" % kind)
	_check(not bool(descriptor["is_open"]), "%s de teste inicia fechada" % kind)

	_check(
		house.set_vision_portal_open(portal_id, true),
		"set_vision_portal_open abre %s sem animação" % kind
	)
	var opened := _portal_by_id(house.vision_portals(), portal_id)
	_check(not opened.is_empty() and bool(opened["is_open"]), "%s fica aberta no mesmo frame" % kind)
	_check(StringName(opened.get("id", &"")) == portal_id, "ID de %s é preservado ao abrir" % kind)
	_check(_tile_state(opened) == &"aberta", "%s usa tile estático aberto" % kind)
	_check(_sorted_ids(house.vision_portals()) == original_ids, "abrir %s não altera conjunto de IDs" % kind)

	_check(
		house.set_vision_portal_open(portal_id, false),
		"set_vision_portal_open fecha %s sem animação" % kind
	)
	var closed := _portal_by_id(house.vision_portals(), portal_id)
	_check(not closed.is_empty() and not bool(closed["is_open"]), "%s fica fechada no mesmo frame" % kind)
	_check(StringName(closed.get("id", &"")) == portal_id, "ID de %s é preservado ao fechar" % kind)
	_check(_tile_state(closed) == &"fechada", "%s usa tile estático fechado" % kind)
	_check(_sorted_ids(house.vision_portals()) == original_ids, "fechar %s não altera conjunto de IDs" % kind)


func _portal_by_id(portals: Array[Dictionary], portal_id: StringName) -> Dictionary:
	for descriptor: Dictionary in portals:
		if StringName(descriptor.get("id", &"")) == portal_id:
			return descriptor
	return {}


func _tile_state(descriptor: Dictionary) -> StringName:
	if descriptor.is_empty():
		return &""
	var layer := descriptor.get("layer") as TileMapLayer
	var cell := descriptor.get("cell", Vector2i.ZERO) as Vector2i
	if layer == null:
		return &""
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return &""
	var state_key := &"estado_porta" if descriptor["kind"] == &"door" else &"estado_janela"
	return StringName(String(data.get_custom_data(state_key)))


func _sorted_ids(portals: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for descriptor: Dictionary in portals:
		result.append(String(descriptor.get("id", "")))
	result.sort()
	return result


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])


func _finish() -> void:
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

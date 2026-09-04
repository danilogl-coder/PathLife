## Extrai a topologia de visão das camadas semânticas Piso e Paredes.
##
## O baker nunca consulta colisão ou arte e ignora deliberadamente
## ParedesSemColisao. Isso torna o resultado determinístico e testável em
## headless.
class_name StructureVisionBaker
extends RefCounted

const EDGE := preload("res://world_generation/visibility/vision_edge.gd")
const PORTAL := preload("res://world_generation/visibility/vision_portal.gd")
const ZONE := preload("res://world_generation/visibility/vision_zone.gd")
const SNAPSHOT := preload("res://world_generation/visibility/structure_vision_snapshot.gd")

const CARDINAL_DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"se", &"sw"]
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
]


## placement_context aceita StructurePlacement, um placement_id inteiro ou null.
## explicit_origin, quando fornecido, prevalece e deve ser Vector3i.
func bake(
	structure: Node,
	placement_context: Variant = null,
	explicit_origin: Variant = null
) -> StructureVisionSnapshot:
	var snapshot := SNAPSHOT.new()
	if structure == null:
		snapshot.warnings.append("Estrutura nula; snapshot vazio.")
		return snapshot

	var resolved_context: Variant = placement_context
	if resolved_context == null and structure.has_method("placement"):
		resolved_context = structure.call("placement")
	_resolve_placement(snapshot, resolved_context, explicit_origin)
	snapshot.structure_instance_id = structure.get_instance_id()

	var floor_layer := structure.get_node_or_null(^"Piso") as TileMapLayer
	var wall_layer := structure.get_node_or_null(^"Paredes") as TileMapLayer
	if floor_layer == null:
		snapshot.warnings.append("Camada Piso ausente em %s." % structure.name)
	if wall_layer == null:
		snapshot.warnings.append("Camada Paredes ausente em %s." % structure.name)

	if floor_layer != null:
		snapshot.used_rect = floor_layer.get_used_rect()
		if floor_layer.tile_set != null:
			snapshot.tile_size = floor_layer.tile_set.tile_size
		_bake_floor(floor_layer, snapshot)
	elif wall_layer != null:
		# Cercas e divisórias podem contribuir apenas arestas. Elas não criam
		# zonas internas, mas ainda precisam bloquear os raios do solver.
		snapshot.used_rect = wall_layer.get_used_rect()
		if wall_layer.tile_set != null:
			snapshot.tile_size = wall_layer.tile_set.tile_size
	if wall_layer != null:
		_bake_edges(wall_layer, snapshot)
	_bake_zones(snapshot)
	_bake_exterior_guard(snapshot)
	_bind_portal_zones(snapshot)
	return snapshot


func _resolve_placement(
	snapshot: StructureVisionSnapshot,
	placement_context: Variant,
	explicit_origin: Variant
) -> void:
	if placement_context is int:
		snapshot.placement_id = int(placement_context)
	elif placement_context is Object:
		snapshot.placement_id = int(
			_read_property(placement_context as Object, &"placement_id", 0)
		)
		var origin_xy: Variant = _read_property(
			placement_context as Object, &"origin_xy", Vector2i.ZERO
		)
		var height := int(
			_read_property(placement_context as Object, &"foundation_height", 0)
		)
		if origin_xy is Vector2i:
			snapshot.origin = Vector3i(origin_xy.x, origin_xy.y, height)
	if explicit_origin is Vector3i:
		snapshot.origin = explicit_origin


func _read_property(object: Object, property_name: StringName, fallback: Variant) -> Variant:
	for descriptor: Dictionary in object.get_property_list():
		if StringName(descriptor.get("name", &"")) == property_name:
			return object.get(property_name)
	return fallback


func _bake_floor(layer: TileMapLayer, snapshot: StructureVisionSnapshot) -> void:
	var cells := layer.get_used_cells()
	cells.sort_custom(_cell_less)
	for local_cell: Vector2i in cells:
		var data := layer.get_cell_tile_data(local_cell)
		if data == null:
			continue
		var category := String(data.get_custom_data(&"categoria"))
		if category != "" and category != "piso":
			snapshot.warnings.append(
				"Tile não-piso ignorado em Piso %s: %s." % [local_cell, category]
			)
			continue
		var environment := StringName(String(data.get_custom_data(&"ambiente")))
		snapshot.add_floor(local_cell, environment)


func _bake_edges(layer: TileMapLayer, snapshot: StructureVisionSnapshot) -> void:
	var cells := layer.get_used_cells()
	cells.sort_custom(_cell_less)
	for local_cell: Vector2i in cells:
		var data := layer.get_cell_tile_data(local_cell)
		if data == null:
			continue
		var category := String(data.get_custom_data(&"categoria")).to_lower()
		var piece := String(data.get_custom_data(&"peca")).to_lower()
		match category:
			"parede":
				_bake_wall_piece(local_cell, piece, snapshot)
			"porta", "door", "janela", "window":
				_bake_portal_piece(local_cell, category, piece, data, snapshot)


func _bake_wall_piece(
	local_cell: Vector2i,
	piece: String,
	snapshot: StructureVisionSnapshot
) -> void:
	var directions: Array[StringName] = []
	match piece:
		"ne", "nw", "se", "sw":
			directions.append(StringName(piece))
		"quina_n", "canto":
			directions.assign([&"ne", &"nw"])
		"quina_e":
			directions.assign([&"ne", &"se"])
		"quina_s":
			directions.assign([&"se", &"sw"])
		"quina_w":
			directions.assign([&"nw", &"sw"])
		_:
			snapshot.warnings.append(
				"Peça de parede desconhecida em %s: %s." % [local_cell, piece]
			)
	for direction: StringName in directions:
		var endpoints := _world_endpoints(snapshot, local_cell, direction)
		var edge := EDGE.create_wall(
			endpoints[0], endpoints[1], snapshot.placement_id, direction, local_cell
		)
		snapshot.add_edge(edge)


func _bake_portal_piece(
	local_cell: Vector2i,
	category: String,
	piece: String,
	data: TileData,
	snapshot: StructureVisionSnapshot
) -> void:
	# Montantes são postes decorativos sem uma borda atravessável própria.
	if piece.begins_with("montante_"):
		return
	var direction := StringName(String(data.get_custom_data(&"direcao")).to_lower())
	if direction not in CARDINAL_DIRECTIONS:
		direction = _direction_from_piece(piece)
	if direction not in CARDINAL_DIRECTIONS:
		snapshot.warnings.append(
			"Portal sem direção cardinal em %s: %s." % [local_cell, piece]
		)
		return

	var kind := PORTAL.normalize_kind(category)
	var state_key: StringName = &"estado_janela" if kind == PORTAL.WINDOW else &"estado_porta"
	var state := String(data.get_custom_data(state_key)).to_lower()
	var permanent := state == "vao" or piece.ends_with("_vao")
	var is_open := permanent or _state_is_logically_open(kind, state)
	var portal_id := StringName(
		"%d|%d,%d|%s|%s"
		% [snapshot.placement_id, local_cell.x, local_cell.y, String(direction), String(kind)]
	)
	var endpoints := _world_endpoints(snapshot, local_cell, direction)
	var portal := PORTAL.new()
	portal.id = portal_id
	portal.kind = kind
	portal.cell_a = endpoints[0]
	portal.cell_b = endpoints[1]
	portal.direction = direction
	portal.placement_id = snapshot.placement_id
	portal.authored_cell = local_cell
	portal.environment = StringName(String(data.get_custom_data(&"ambiente")))
	portal.permanent = permanent
	portal.is_open = is_open
	var edge := EDGE.create_portal(
		portal.cell_a,
		portal.cell_b,
		portal.id,
		snapshot.placement_id,
		direction,
		local_cell
	)
	snapshot.add_portal(portal, edge)


func _state_is_logically_open(kind: StringName, state: String) -> bool:
	if state == "aberta" or state == "open":
		return true
	if kind == PORTAL.DOOR and state.begins_with("anim"):
		return int(state.trim_prefix("anim")) >= 5
	return false


func _direction_from_piece(piece: String) -> StringName:
	var segments := piece.split("_")
	for segment: String in segments:
		if segment in ["ne", "nw", "se", "sw"]:
			return StringName(segment)
	return &""


func _world_endpoints(
	snapshot: StructureVisionSnapshot,
	local_cell: Vector2i,
	direction: StringName
) -> Array[Vector3i]:
	var offset := _direction_offset(direction)
	var first := snapshot.local_to_world_cell(local_cell)
	var second := first + Vector3i(offset.x, offset.y, 0)
	return [first, second]


func _direction_offset(direction: StringName) -> Vector2i:
	match direction:
		&"ne":
			return Vector2i(0, -1)
		&"nw":
			return Vector2i(-1, 0)
		&"se":
			return Vector2i(1, 0)
		&"sw":
			return Vector2i(0, 1)
	return Vector2i.ZERO


func _bake_zones(snapshot: StructureVisionSnapshot) -> void:
	var unvisited := snapshot.floor_cells.duplicate()
	var next_zone_id := 0
	while not unvisited.is_empty():
		var seed: Vector3i = _first_sorted_world_cell(unvisited)
		var zone := ZONE.new()
		zone.id = next_zone_id
		zone.placement_id = snapshot.placement_id
		zone.level = snapshot.origin.z
		next_zone_id += 1

		var queue: Array[Vector3i] = [seed]
		var read_index := 0
		unvisited.erase(seed)
		var environments: Dictionary = {}
		while read_index < queue.size():
			var cell := queue[read_index]
			read_index += 1
			zone.add_cell(cell)
			snapshot.cell_to_zone[cell] = zone.id
			var environment := StringName(snapshot.floor_environments.get(cell, &""))
			environments[environment] = int(environments.get(environment, 0)) + 1
			for offset: Vector2i in NEIGHBORS:
				var neighbor := cell + Vector3i(offset.x, offset.y, 0)
				if not unvisited.has(neighbor):
					continue
				if snapshot.edge_between(cell, neighbor) != null:
					continue
				unvisited.erase(neighbor)
				queue.append(neighbor)

		zone.environment = _majority_environment(environments)
		zone.is_exterior = _zone_is_exposed(zone, snapshot)
		snapshot.zones.append(zone)
		if not zone.is_exterior:
			for internal_cell: Variant in zone.cells:
				snapshot.internal_cells[internal_cell] = true


func _zone_is_exposed(zone: VisionZone, snapshot: StructureVisionSnapshot) -> bool:
	for cell_variant: Variant in zone.cells:
		var cell: Vector3i = cell_variant
		for offset: Vector2i in NEIGHBORS:
			var neighbor := cell + Vector3i(offset.x, offset.y, 0)
			if snapshot.floor_cells.has(neighbor):
				continue
			if snapshot.edge_between(cell, neighbor) == null:
				return true
	return false


func _bind_portal_zones(snapshot: StructureVisionSnapshot) -> void:
	for portal: VisionPortal in snapshot.portals.values():
		portal.zone_a = snapshot.zone_id_at(portal.cell_a)
		portal.zone_b = snapshot.zone_id_at(portal.cell_b)


func _bake_exterior_guard(snapshot: StructureVisionSnapshot) -> void:
	for cell_variant: Variant in snapshot.internal_cells:
		var cell := cell_variant as Vector3i
		for offset: Vector2i in NEIGHBORS:
			var neighbor := cell + Vector3i(offset.x, offset.y, 0)
			if not snapshot.internal_cells.has(neighbor):
				snapshot.exterior_guard_cells[neighbor] = true


func _majority_environment(counts: Dictionary) -> StringName:
	var best: StringName = &""
	var best_count := -1
	var names: Array[StringName] = []
	for name_variant: Variant in counts:
		names.append(StringName(name_variant))
	names.sort()
	for name: StringName in names:
		var count := int(counts[name])
		if count > best_count:
			best_count = count
			best = name
	return best


func _first_sorted_world_cell(cells: Dictionary) -> Vector3i:
	var result: Array[Vector3i] = []
	for cell_variant: Variant in cells:
		result.append(cell_variant)
	result.sort_custom(_world_cell_less)
	return result[0]


func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


func _world_cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return a.z < b.z
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

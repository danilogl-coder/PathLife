## Passe 8 — espalha vegetação/objetos. Gera DADOS, não Nodes.
class_name DecorationPass
extends WorldGenerationPass

@export var sampler: WorldSampler



func rebind_shared(shared: Dictionary) -> void:
	sampler = WorldGenerationPass.shared_clone(shared, sampler)


## Garante que o amostrador esteja semeado antes de qualquer geração.
func prepare(settings: WorldSettings, world_seed: int) -> void:
	if sampler != null:
		sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
	if sampler == null or sampler.biome_resolver == null:
		return
	var settings := context.settings
	var size := settings.chunk_size
	var origin := context.origin()
	var decoration_seed := WorldRandom.sub_seed(context.world_seed, &"decoration")
	var taken: Dictionary = {}

	for y in size:
		for x in size:
			var local := Vector2i(x, y)
			var cell := context.cell(local)
			if cell.terrain_locked:
				continue
			var biome := sampler.biome_resolver.find_by_id(cell.biome_id)
			if biome == null or biome.decorations.is_empty():
				continue

			var world_xy := origin + local
			var roll := WorldRandom.value_01(decoration_seed, world_xy, 1)
			var definition := _pick(biome.decorations, decoration_seed, world_xy)
			if definition == null or roll > definition.density:
				continue
			if not _accepts(definition, cell, context, local):
				continue
			if _occupied(taken, world_xy, definition.minimum_spacing):
				continue

			var placement := DecorationPlacement.new()
			placement.definition = definition
			placement.world_pos = Vector3i(world_xy.x, world_xy.y, cell.height)
			placement.object_id = WorldRandom.coordinate_seed(decoration_seed, world_xy)
			placement.flip_h = (
				definition.random_flip_h
				and WorldRandom.value_01(decoration_seed, world_xy, 2) > 0.5
			)
			placement.scale_factor = lerpf(
				definition.min_scale,
				definition.max_scale,
				WorldRandom.value_01(decoration_seed, world_xy, 3)
			)
			context.chunk_data.decorations.append(placement)
			taken[world_xy] = true
			if definition.blocks_movement:
				cell.walkable = false


func _pick(
	definitions: Array[DecorationDefinition], base_seed: int, world_xy: Vector2i
) -> DecorationDefinition:
	var total := 0.0
	for definition in definitions:
		if definition != null:
			total += maxf(definition.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := WorldRandom.value_01(base_seed, world_xy, 11) * total
	for definition in definitions:
		if definition == null:
			continue
		roll -= maxf(definition.weight, 0.0)
		if roll <= 0.0:
			return definition
	return definitions[definitions.size() - 1]


func _accepts(
	definition: DecorationDefinition,
	cell: WorldCell,
	context: GenerationContext,
	local: Vector2i
) -> bool:
	if cell.height < definition.min_world_height or cell.height > definition.max_world_height:
		return false
	if cell.is_liquid() and not definition.allow_on_water:
		return false
	if cell.biome_blend > definition.max_biome_blend:
		return false
	if not definition.allowed_terrains.is_empty() and not definition.allowed_terrains.has(cell.terrain_id):
		return false
	var slope := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor := local + offset
		if context.chunk_data.contains_local(neighbor):
			slope = maxi(slope, absi(context.cell(neighbor).height - cell.height))
	return float(slope) <= definition.max_slope


func _occupied(taken: Dictionary, world_xy: Vector2i, spacing: int) -> bool:
	for dy in range(-spacing + 1, spacing):
		for dx in range(-spacing + 1, spacing):
			if taken.has(world_xy + Vector2i(dx, dy)):
				return true
	return false

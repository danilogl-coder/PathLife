## O terreno se adapta à estrutura — nunca o contrário.
##
## Dentro do footprint a altura vira exatamente a fundação. Da borda do
## footprint até o fim da margem, mistura-se suavemente com o relevo original,
## evitando "paredões" artificiais ao redor das construções.
class_name TerrainAdapter
extends RefCounted


static func blend_height(original: float, target: float, distance: float, radius: float) -> float:
	if radius <= 0.0:
		return target if distance <= 0.0 else original
	var t := clampf(1.0 - distance / radius, 0.0, 1.0)
	t = smoothstep(0.0, 1.0, t)
	return lerpf(original, target, t)


## Distância de Chebyshev de um ponto até um retângulo (0 se estiver dentro).
static func distance_to_rect(point: Vector2i, rect: Rect2i) -> float:
	var dx := maxi(maxi(rect.position.x - point.x, 0), point.x - (rect.position.x + rect.size.x - 1))
	var dy := maxi(maxi(rect.position.y - point.y, 0), point.y - (rect.position.y + rect.size.y - 1))
	return float(maxi(dx, dy))


## Aplica todas as estruturas planejadas sobre as células de um chunk.
static func apply(context: GenerationContext, placements: Array[StructurePlacement]) -> void:
	if placements.is_empty():
		return
	var size := context.settings.chunk_size
	var origin := context.origin()

	for placement in placements:
		var definition := placement.definition
		if definition == null:
			continue
		if definition.adaptation_mode == StructureDefinition.TerrainAdaptationMode.NONE:
			continue
		var footprint_rect := placement.rect()
		var radius := float(definition.adaptation_margin)
		var target := float(placement.foundation_height)

		for y in size:
			for x in size:
				var local := Vector2i(x, y)
				var world_xy := origin + local
				var distance := distance_to_rect(world_xy, footprint_rect)
				if distance > radius:
					continue
				var cell := context.cell(local)
				if distance <= 0.0:
					cell.height = placement.foundation_height
					cell.terrain_locked = true
					cell.liquid_depth = 0
					if definition.footprint_blocks_movement:
						cell.walkable = false
					continue
				if cell.terrain_locked:
					continue
				var blended := blend_height(float(cell.height), target, distance, radius)
				if definition.adaptation_mode == StructureDefinition.TerrainAdaptationMode.PLATEAU:
					blended = lerpf(float(cell.height), blended, 0.65)
				cell.height = roundi(blended)
				if cell.height >= context.settings.sea_level:
					cell.liquid_depth = 0

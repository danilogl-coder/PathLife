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
##
## Faz duas coisas independentes na mesma varredura: assenta a ALTURA (footprint
## + mistura da borda) e assenta a COBERTURA do chão (grama vira terra nua sob a
## construção). São independentes de propósito: uma estrutura pode nascer em
## terreno intocado e ainda assim precisar do chão nu, e vice-versa.
static func apply(context: GenerationContext, placements: Array[StructurePlacement]) -> void:
	if placements.is_empty():
		return
	var size := context.settings.chunk_size
	var origin := context.origin()

	for placement in placements:
		var definition := placement.definition
		if definition == null:
			continue
		var footprint_rect := placement.rect()
		var radius := float(definition.adaptation_margin)
		var target := float(placement.foundation_height)
		var adapts := (
			definition.adaptation_mode != StructureDefinition.TerrainAdaptationMode.NONE
		)
		# O piso DESENHADO na cena manda no chão do mundo; o footprint é só o
		# atalho para quem não usa TileMapLayer (o deck, por exemplo).
		var floor_cells: Dictionary = {}
		if definition.clears_ground_cover:
			floor_cells = StructureFloorMask.cells_for(definition)
		# -1 significa "não limpa nada": nem a distância 0 (dentro do footprint)
		# entra, porque nenhuma distância é negativa.
		var cover_radius := (
			float(definition.bare_ground_margin) if definition.clears_ground_cover else -1.0
		)
		var cover_reach := 0.0
		if definition.clears_ground_cover:
			cover_reach = maxf(cover_radius, float(StructureFloorMask.reach_for(definition)))
		var reach := maxf(radius if adapts else 0.0, cover_reach)

		for y in size:
			for x in size:
				var local := Vector2i(x, y)
				var world_xy := origin + local
				var distance := distance_to_rect(world_xy, footprint_rect)
				if distance > reach:
					continue
				var cell := context.cell(local)
				var has_structure_floor := floor_cells.has(world_xy - placement.origin_xy)
				if distance <= cover_radius or has_structure_floor:
					clear_ground_cover(cell, definition)
				# Não basta colocar terra nua embaixo do piso. Ground e estruturas
				# dividem o Y-Sort e o tile do mundo pode ganhar o empate, sendo
				# desenhado por cima nas frestas. A superfície só some onde a cena
				# realmente pinta um piso; margem e footprint sem piso continuam
				# mostrando terreno normalmente.
				if has_structure_floor:
					cell.ground_surface_hidden = true
				if not adapts or distance > radius:
					continue
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


## O chão do mundo ainda é grama nesta célula depois da construção?
##
## Serve de conferência para testes e ferramentas: responde a MESMA pergunta que
## o laço de [method apply] responde ao gerar o chunk.
static func clears_cell(placement: StructurePlacement, world_xy: Vector2i) -> bool:
	var definition := placement.definition
	if definition == null or not definition.clears_ground_cover:
		return false
	if distance_to_rect(world_xy, placement.rect()) <= float(definition.bare_ground_margin):
		return true
	return StructureFloorMask.cells_for(definition).has(world_xy - placement.origin_xy)


## Chão nu que a construção usa: o da própria definição ou o do bioma da célula.
static func bare_ground_for(cell: WorldCell, definition: StructureDefinition) -> StringName:
	if definition == null:
		return &""
	if definition.bare_ground_id != &"":
		return definition.bare_ground_id
	# `wall_id` é a terra exposta do bioma — a mesma arte das faces de barranco.
	return cell.wall_id


## Troca a grama por terra nua e TRANCA a célula.
##
## O trancamento importa tanto quanto a troca: sem ele o passe de relevo ou a
## peça de fronteira entre biomas devolveriam uma arte de grama para a célula, e
## o mato voltaria ao redor da construção. A ocultação da superfície sob o piso
## é feita separadamente em [method apply].
static func clear_ground_cover(cell: WorldCell, definition: StructureDefinition) -> void:
	var bare := bare_ground_for(cell, definition)
	if bare == &"":
		# Bioma sem terra própria: grama é melhor do que um chão sem arte.
		return
	cell.ground_id = bare
	cell.ground_locked = true

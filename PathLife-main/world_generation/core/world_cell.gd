## Uma célula lógica do mundo. É DADO, não visual.
##
## O TileMapLayer nunca é a fonte da verdade: ele apenas desenha o que existe
## aqui.
class_name WorldCell
extends RefCounted

## Coordenada mundial (x, y). A altura fica em [member height].
var world_xy: Vector2i = Vector2i.ZERO
var height: int = 0

## Identificadores lógicos (data-driven, resolvidos por Resources).
var biome_id: StringName = &""
var secondary_biome_id: StringName = &""
var biome_blend: float = 0.0
var terrain_id: StringName = &""
var ground_id: StringName = &""
var wall_id: StringName = &""

## Regras de jogo.
var walkable: bool = true
var liquid_depth: int = 0
## Marcada por estruturas/estradas: o relevo procedural não pode mais mexer.
var terrain_locked: bool = false
## Marcada por estruturas: a COBERTURA do chão já foi decidida.
##
## Enquanto [member terrain_locked] protege a ALTURA, esta marca protege o
## DESENHO: nem a variante de bioma, nem o relevo, nem a peça de fronteira podem
## trocar [member ground_id] depois que uma construção assentou o terreno dela.
var ground_locked: bool = false
## Uma estrutura desenha piso próprio nesta célula.
##
## O chão continua existindo como dado (e ainda pode fornecer as faces do
## relevo), mas sua superfície não deve ser pintada. Apenas trocar grama por
## terra não basta: com Y-Sort, qualquer tile do mundo na mesma célula pode ser
## desenhado depois do piso e aparecer nas juntas da arte da construção.
var ground_surface_hidden: bool = false

## Clima amostrado (útil para vegetação, clima dinâmico, etc.).
var temperature: float = 0.0
var humidity: float = 0.0
var continentalness: float = 0.0


func _init(p_world_xy: Vector2i = Vector2i.ZERO, p_height: int = 0) -> void:
	world_xy = p_world_xy
	height = p_height


func world_position() -> Vector3i:
	return Vector3i(world_xy.x, world_xy.y, height)


func is_liquid() -> bool:
	return liquid_depth > 0


func duplicate_cell() -> WorldCell:
	var copy := WorldCell.new(world_xy, height)
	copy.biome_id = biome_id
	copy.secondary_biome_id = secondary_biome_id
	copy.biome_blend = biome_blend
	copy.terrain_id = terrain_id
	copy.ground_id = ground_id
	copy.wall_id = wall_id
	copy.walkable = walkable
	copy.liquid_depth = liquid_depth
	copy.terrain_locked = terrain_locked
	copy.ground_locked = ground_locked
	copy.ground_surface_hidden = ground_surface_hidden
	copy.temperature = temperature
	copy.humidity = humidity
	copy.continentalness = continentalness
	return copy

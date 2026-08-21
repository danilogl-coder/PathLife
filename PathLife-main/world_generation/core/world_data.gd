## Camada de leitura do mundo já gerado.
##
## É a ÚNICA fonte da verdade consultada por gameplay, IA e pathfinding.
## O TileMapLayer nunca é consultado para decidir regra de jogo.
class_name WorldData
extends RefCounted

signal chunk_added(chunk_coord: Vector2i)
signal chunk_removed(chunk_coord: Vector2i)

var settings: WorldSettings
## Amostrador global: responde altura mesmo fora dos chunks carregados.
var sampler: WorldSampler

var _chunks: Dictionary = {}


func _init(p_settings: WorldSettings = null, p_sampler: WorldSampler = null) -> void:
	settings = p_settings
	sampler = p_sampler


func add_chunk(chunk: ChunkData) -> void:
	_chunks[chunk.coord] = chunk
	chunk_added.emit(chunk.coord)


func remove_chunk(chunk_coord: Vector2i) -> void:
	if _chunks.erase(chunk_coord):
		chunk_removed.emit(chunk_coord)


func has_chunk(chunk_coord: Vector2i) -> bool:
	return _chunks.has(chunk_coord)


func get_chunk(chunk_coord: Vector2i) -> ChunkData:
	return _chunks.get(chunk_coord, null)


func loaded_chunk_coords() -> Array:
	return _chunks.keys()


func clear() -> void:
	for coord in _chunks.keys():
		chunk_removed.emit(coord)
	_chunks.clear()


func get_cell(world_xy: Vector2i) -> WorldCell:
	var chunk := get_chunk(ChunkMath.world_to_chunk(world_xy, settings.chunk_size))
	if chunk == null:
		return null
	return chunk.get_cell(ChunkMath.world_to_local(world_xy, settings.chunk_size))


## Altura do chão. Se o chunk não estiver carregado, cai no amostrador global.
func height_at(world_xy: Vector2i) -> int:
	var cell := get_cell(world_xy)
	if cell != null:
		return cell.height
	if sampler != null:
		return sampler.base_height(world_xy)
	return 0


func is_walkable(world_xy: Vector2i) -> bool:
	var cell := get_cell(world_xy)
	if cell == null:
		return false
	return cell.walkable


func is_loaded(world_xy: Vector2i) -> bool:
	return get_cell(world_xy) != null


## Posição lógica completa (x, y, altura do chão).
func ground_position(world_xy: Vector2i) -> Vector3i:
	return Vector3i(world_xy.x, world_xy.y, height_at(world_xy))

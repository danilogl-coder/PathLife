## Conversões World <-> Chunk <-> Local.
##
## Usa floor/posmod para funcionar corretamente com coordenadas negativas.
class_name ChunkMath
extends RefCounted


static func world_to_chunk(world_xy: Vector2i, chunk_size: int) -> Vector2i:
	return Vector2i(
		floori(float(world_xy.x) / float(chunk_size)),
		floori(float(world_xy.y) / float(chunk_size))
	)


static func world_to_local(world_xy: Vector2i, chunk_size: int) -> Vector2i:
	return Vector2i(
		posmod(world_xy.x, chunk_size),
		posmod(world_xy.y, chunk_size)
	)


static func chunk_local_to_world(chunk_coord: Vector2i, local: Vector2i, chunk_size: int) -> Vector2i:
	return chunk_coord * chunk_size + local


static func chunk_origin(chunk_coord: Vector2i, chunk_size: int) -> Vector2i:
	return chunk_coord * chunk_size


static func chunk_to_region(chunk_coord: Vector2i, region_size: int) -> Vector2i:
	return Vector2i(
		floori(float(chunk_coord.x) / float(region_size)),
		floori(float(chunk_coord.y) / float(region_size))
	)


static func world_to_region(world_xy: Vector2i, chunk_size: int, region_size: int) -> Vector2i:
	return chunk_to_region(world_to_chunk(world_xy, chunk_size), region_size)


static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

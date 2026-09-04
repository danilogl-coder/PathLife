## Conversão pura entre memória visual por célula e bitsets agrupados por chunk.
##
## As chaves persistidas usam `chunk_x:chunk_y:nivel`. Cada bit representa a
## célula local `y * chunk_size + x`; floor/posmod preservam coordenadas
## negativas. O codec não conhece SceneTree nem WorldSaveManager.
class_name VisionMemoryCodec
extends RefCounted


static func encode_cells(cells: Variant, chunk_size: int) -> Dictionary:
	var encoded: Dictionary = {}
	for cell: Vector3i in _normalized_cells(cells):
		add_cell(encoded, cell, chunk_size)
	return encoded


static func decode_chunks(chunks: Dictionary, chunk_size: int) -> Dictionary:
	var decoded: Dictionary = {}
	var safe_size := maxi(1, chunk_size)
	var cell_count := safe_size * safe_size
	for raw_key: Variant in chunks:
		var parsed := _parse_chunk_key(String(raw_key))
		if not bool(parsed.get(&"valid", false)):
			continue
		var chunk_position := parsed[&"position"] as Vector3i
		var raw_bits: Variant = chunks[raw_key]
		var bits := PackedByteArray()
		if raw_bits is PackedByteArray:
			bits = (raw_bits as PackedByteArray).duplicate()
		elif raw_bits is String and String(raw_bits) != "":
			bits = Marshalls.base64_to_raw(String(raw_bits))
		for bit_index in mini(cell_count, bits.size() * 8):
			if (bits[bit_index >> 3] & (1 << (bit_index & 7))) == 0:
				continue
			var local := Vector2i(bit_index % safe_size, bit_index / safe_size)
			var world_xy := Vector2i(chunk_position.x, chunk_position.y) * safe_size + local
			decoded[Vector3i(world_xy.x, world_xy.y, chunk_position.z)] = true
	return decoded


## Acrescenta uma célula sem reconstruir os demais chunks. Retorna a chave
## alterada, permitindo que o coordenador sincronize apenas aquele bitset.
static func add_cell(
	packed_chunks: Dictionary, cell: Vector3i, chunk_size: int
) -> StringName:
	var safe_size := maxi(1, chunk_size)
	var chunk_xy := ChunkMath.world_to_chunk(Vector2i(cell.x, cell.y), safe_size)
	var local := ChunkMath.world_to_local(Vector2i(cell.x, cell.y), safe_size)
	var key := chunk_key(chunk_xy, cell.z)
	var bytes_required := ceili(float(safe_size * safe_size) / 8.0)
	var bits := PackedByteArray()
	var existing: Variant = packed_chunks.get(String(key), PackedByteArray())
	if existing is PackedByteArray:
		bits = (existing as PackedByteArray).duplicate()
	if bits.size() < bytes_required:
		bits.resize(bytes_required)
	var bit_index := local.y * safe_size + local.x
	var byte_index := bit_index >> 3
	bits[byte_index] = bits[byte_index] | (1 << (bit_index & 7))
	packed_chunks[String(key)] = bits
	return key


static func chunk_key(chunk_xy: Vector2i, level: int) -> StringName:
	return StringName("%d:%d:%d" % [chunk_xy.x, chunk_xy.y, level])


static func key_for_cell(cell: Vector3i, chunk_size: int) -> StringName:
	return chunk_key(
		ChunkMath.world_to_chunk(Vector2i(cell.x, cell.y), maxi(1, chunk_size)),
		cell.z
	)


static func duplicate_chunks(chunks: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for raw_key: Variant in chunks:
		var bits: Variant = chunks[raw_key]
		if bits is PackedByteArray:
			copy[String(raw_key)] = (bits as PackedByteArray).duplicate()
	return copy


static func _normalized_cells(source: Variant) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if source is Dictionary:
		for raw_cell: Variant in source:
			if raw_cell is Vector3i and bool((source as Dictionary)[raw_cell]):
				cells.append(raw_cell)
	elif source is Array:
		for raw_cell: Variant in source:
			if raw_cell is Vector3i:
				cells.append(raw_cell)
	return cells


static func _parse_chunk_key(key: String) -> Dictionary:
	var parts := key.split(":", false)
	if parts.size() != 3:
		return {&"valid": false}
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {&"valid": false}
	return {
		&"valid": true,
		&"position": Vector3i(int(parts[0]), int(parts[1]), int(parts[2])),
	}

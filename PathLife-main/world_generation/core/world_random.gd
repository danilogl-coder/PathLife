## Geração de sub-sementes determinísticas.
##
## Regra: nunca use um RandomNumberGenerator global compartilhado entre
## sistemas. Cada sistema deriva a própria sub-semente a partir da semente do
## mundo, para que adicionar conteúdo em um sistema não desloque os outros.
class_name WorldRandom
extends RefCounted

const MASK := 0x7FFFFFFF


static func _mix(value: int) -> int:
	var h := value & 0xFFFFFFFF
	h = (h ^ (h >> 16)) * 0x7FEB352D & 0xFFFFFFFF
	h = (h ^ (h >> 15)) * 0x846CA68B & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return h


## Sub-semente estável para um sistema (ex.: &"terrain", &"climate").
static func sub_seed(world_seed: int, name_space: StringName) -> int:
	return _mix(world_seed ^ _mix(String(name_space).hash())) & MASK


## Semente estável para uma coordenada específica.
static func coordinate_seed(base_seed: int, coord: Vector2i) -> int:
	var h := _mix(base_seed ^ _mix(coord.x * 73856093 ^ coord.y * 19349663))
	return h & MASK


## Valor pseudoaleatório determinístico em [0, 1) para uma coordenada.
static func value_01(base_seed: int, coord: Vector2i, salt: int = 0) -> float:
	var h := _mix(coordinate_seed(base_seed, coord) ^ _mix(salt))
	return float(h & 0xFFFFFF) / 16777216.0


## RandomNumberGenerator já semeado para uma coordenada.
static func rng_for(base_seed: int, coord: Vector2i, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix(coordinate_seed(base_seed, coord) ^ _mix(salt))
	return rng

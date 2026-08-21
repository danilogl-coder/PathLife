## Executa a pipeline de passes. Não conhece renderização nem SceneTree.
class_name WorldGenerator
extends Resource

@export var passes: Array[WorldGenerationPass] = []

var _world_seed: int = 0
var _settings: WorldSettings
var _prepared: bool = false


func prepare(settings: WorldSettings, world_seed: int) -> void:
	_settings = settings
	_world_seed = world_seed
	for generation_pass in passes:
		if generation_pass != null:
			generation_pass.prepare(settings, world_seed)
	_prepared = true


func is_prepared() -> bool:
	return _prepared


func generate_chunk(chunk_coord: Vector2i) -> ChunkData:
	var context := GenerationContext.new()
	context.world_seed = _world_seed
	context.settings = _settings
	context.chunk_coord = chunk_coord
	context.chunk_data = ChunkData.new(chunk_coord, _settings.chunk_size)

	# Todas as células nascem existindo; os passes só preenchem propriedades.
	var origin := chunk_coord * _settings.chunk_size
	for y in _settings.chunk_size:
		for x in _settings.chunk_size:
			var local := Vector2i(x, y)
			context.chunk_data.set_cell(local, WorldCell.new(origin + local, 0))

	for generation_pass in passes:
		if generation_pass == null or not generation_pass.enabled:
			continue
		generation_pass.run(context)

	context.chunk_data.refresh_height_bounds()
	return context.chunk_data


## Cópia totalmente independente da pipeline (usada por thread).
func clone() -> WorldGenerator:
	var copy := WorldGenerator.new()
	var shared: Dictionary = {}
	var cloned: Array[WorldGenerationPass] = []
	for generation_pass in passes:
		if generation_pass == null:
			continue
		cloned.append(generation_pass.clone_pass(shared))
	copy.passes = cloned
	copy.resource_name = resource_name
	return copy

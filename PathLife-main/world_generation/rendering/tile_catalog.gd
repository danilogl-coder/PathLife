## Catálogo que traduz ids lógicos em coordenadas do TileSet.
##
## É aqui — e só aqui — que "dado" vira "tile". Trocar a arte do mundo inteiro
## significa trocar este `.tres`, sem tocar em geração, IA ou save.
##
## [b]Altura e ordenação[/b]: Ground e Depth usam fontes separadas. A fonte 0
## contém superfícies top-only; a fonte 1 contém faces esquerda/direita/ambas;
## e a fonte 2 conserva os blocos completos apenas para compatibilidade de
## recursos/ferramentas. O renderer atual não desenha underlays por chunk: eles
## reintroduziriam barreiras de ordenação. O Z-Level nunca vira `z_index`.
class_name TileCatalog
extends Resource

enum FaceMask {
	LEFT,
	RIGHT,
	BOTH,
}

const GROUND_SOURCE_ID := 0
const DEPTH_FACE_SOURCE_ID := 1
const GROUND_UNDERLAY_SOURCE_ID := 2

@export var tile_set: TileSet
@export var entries: Array[GroundTileEntry] = []
## Usado quando um id não está catalogado (evita mundo invisível por engano).
@export var fallback_ground_id: StringName = &"campo_terra"

## Espelha o topo de metade das células, na horizontal.
##
## Uma mancha de bioma usa a MESMA arte em todas as suas células. Qualquer
## detalhe desenhado no topo — uma falha de terra, uma pedra — se repete então
## numa grade perfeita, e o campo ganha cara de azulejo. Espelhando metade das
## células o padrão perde o passo sem alterar arte nenhuma.
##
## Só o TOPO é espelhado. As faces continuam como foram desenhadas: nelas o
## artista sombreou lado esquerdo e direito de formas diferentes, e trocá-los
## inverteria a luz do penhasco.
@export var mirror_variation: bool = true

## Quantas colunas de tile separam um recorte de face do seguinte no atlas.
## Os três recortes (esquerda, direita, ambas) ficam LADO A LADO; empilhados em
## linhas, a textura de faces passaria de 13 000 px de altura.
@export var face_kind_stride: int = 3

@export_group("Alturas suportadas")
## Menor nível com alternativa gerada no TileSet.
@export var level_min: int = -16
## Maior nível com alternativa gerada no TileSet.
@export var level_max: int = 24

var _lookup: Dictionary = {}


func _ensure_lookup() -> void:
	if not _lookup.is_empty():
		return
	for entry in entries:
		if entry != null:
			_lookup[entry.ground_id] = entry


func find(ground_id: StringName) -> GroundTileEntry:
	_ensure_lookup()
	if _lookup.has(ground_id):
		return _lookup[ground_id]
	if _lookup.has(fallback_ground_id):
		return _lookup[fallback_ground_id]
	return null


func has(ground_id: StringName) -> bool:
	_ensure_lookup()
	return _lookup.has(ground_id)


## Id da alternativa que desenha o tile no nível informado.
##
## O espelhamento não gasta uma alternativa própria: o Godot aceita os bits de
## transformação somados ao id em `TileMapLayer.set_cell()`.
func alternative_for(level: int, mirrored: bool = false) -> int:
	var index := 1 + clampi(level, level_min, level_max) - level_min
	if mirrored and mirror_variation:
		index |= TileSetAtlasSource.TRANSFORM_FLIP_H
	return index


func supports_level(level: int) -> bool:
	return level >= level_min and level <= level_max


func face_atlas_coords(entry: GroundTileEntry, mask: FaceMask) -> Vector2i:
	return Vector2i(entry.atlas_coords.x + int(mask) * face_kind_stride, entry.atlas_coords.y)


func rebuild() -> void:
	_lookup.clear()
	_ensure_lookup()

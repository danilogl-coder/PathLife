## Único ponto do projeto que conhece a projeção isométrica.
##
## Nenhum outro script deve calcular `(x - y) * largura / 2` na mão. Se um dia
## a projeção mudar, só este arquivo muda.
class_name IsoCoordinateSystem
extends RefCounted

var tile_size: Vector2i
var height_pixels: int


func _init(p_tile_size: Vector2i = Vector2i(128, 64), p_height_pixels: int = 26) -> void:
	tile_size = p_tile_size
	height_pixels = p_height_pixels


static func from_settings(settings: WorldSettings) -> IsoCoordinateSystem:
	return IsoCoordinateSystem.new(settings.tile_size, settings.height_pixels)


## Centro da face superior do tile (x, y) no nível 0, em pixels locais.
##
## Usa a MESMA convenção de `TileMapLayer.map_to_local()` com
## `TILE_LAYOUT_DIAMOND_DOWN` (a célula (0,0) fica centrada em meio tile), para
## que tiles, decoração, estruturas e entidades caiam exatamente na mesma
## grade. Existe um teste automatizado garantindo essa igualdade.
func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x - cell.y + 1) * float(tile_size.x) * 0.5,
		float(cell.x + cell.y + 1) * float(tile_size.y) * 0.5
	)


## Mesma coisa, considerando a altura lógica Z.
func world_to_local(world_pos: Vector3i) -> Vector2:
	var base := cell_to_local(Vector2i(world_pos.x, world_pos.y))
	base.y -= float(world_pos.z) * float(height_pixels)
	return base


## Deslocamento vertical em pixels de um nível de altura.
func height_offset(level: int) -> Vector2:
	return Vector2(0.0, -float(level) * float(height_pixels))


## Converte um ponto de tela/local para a célula do chão no nível informado.
func local_to_cell(local_pos: Vector2, level: int = 0) -> Vector2i:
	var p := local_pos
	p.y += float(level) * float(height_pixels)
	var half_w := float(tile_size.x) * 0.5
	var half_h := float(tile_size.y) * 0.5
	p -= Vector2(half_w, half_h)
	var fx := (p.x / half_w + p.y / half_h) * 0.5
	var fy := (p.y / half_h - p.x / half_w) * 0.5
	return Vector2i(floori(fx + 0.5), floori(fy + 0.5))


## Chave de profundidade usada para ordenar desenho (trás para frente).
static func depth_key(world_pos: Vector3i) -> int:
	return (world_pos.x + world_pos.y) * 64 + world_pos.z


## Ajuste da chave de Y-Sort dos objetos apoiados no chão.
##
## [b]Não é um número escolhido a olho: é o único que faz a troca de
## profundidade acontecer na fronteira entre duas células.[/b]
##
## A chave de um tile de superfície é o CENTRO do losango (`y_sort_origin = 0`),
## não a borda da frente. Ao dar um passo de C para C+(1,0), o ator percorre
## meia altura de tile e cruza a fronteira entre as duas células exatamente no
## meio do caminho. Como o ator é interpolado linearmente, sua chave no instante
## `t` vale `centro_de_C + meia_altura * t + viés`, e a do tile de destino vale
## `centro_de_C + meia_altura`. Igualando as duas em `t = 0,5`:
##
##     meia_altura * 0,5 + viés = meia_altura   =>   viés = meia_altura / 2
##
## ou seja, [b]um quarto do tile[/b].
##
## Com um viés menor (já foi tentado 0,5 px, "para o ator ordenar pelos pés"), a
## igualdade só acontece em `t = 0,98`: o personagem atravessa o passo inteiro
## ATRÁS da grama para a qual está andando e só reaparece no último quadro. É a
## cintilação das pernas. Com um viés maior, ele pisaria na célula seguinte antes
## de chegar nela.
##
## O viés some do desenho: quem o aplica soma na âncora e subtrai no corpo.
func prop_sort_bias() -> float:
	return float(tile_size.y) * 0.25

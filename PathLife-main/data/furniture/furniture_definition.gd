## Um móvel do jogo. É DADO: a cena não sabe de medidas, ela lê tudo daqui.
##
## Criar um móvel novo = desenhar a arte + criar um `.tres` deste tipo. As
## quatro orientações compartilham a mesma definição; cada cena de orientação só
## escolhe o índice.
##
## [b]A regra que mantém o cômodo livre[/b]: o móvel ocupa exatamente as células
## de [member footprint_cells] e nenhuma a mais. A colisão é medida da BASE do
## sprite (a parte que encosta no chão), então o que bloqueia é exatamente o que
## se vê — e qualquer célula vizinha continua caminhável.
@tool
class_name FurnitureDefinition
extends Resource

enum Orientation { NE, NW, SE, SW }

enum CollisionSource {
	## Mede a base do sprite (as duas arestas de baixo da silhueta) e usa esse
	## losango. É o padrão: a colisão acompanha o desenho.
	SPRITE_BASE,
	## Usa o losango cheio do footprint. Bom para móveis retangulares que
	## realmente ocupam a célula inteira (armário encostado na parede).
	FOOTPRINT,
	## Não mexe no polígono: o que estiver desenhado na cena é o que vale.
	MANUAL,
}

@export_category("Identidade")
@export var id: StringName = &"novo_movel"
@export var display_name: String = "Móvel"

@export_category("Arte")
## Uma textura por orientação, na ordem NE, NW, SE, SW.
@export var orientation_textures: Array[Texture2D] = []

@export_category("Grade")
## Quantas células o móvel ocupa: X segue o eixo (+1, 0) da grade, Y o eixo
## (0, +1). A célula PINTADA é a da frente; o footprint cresce para trás.
##
## Comece sempre em (1, 1). Só aumente quando a arte não couber — o gizmo do
## editor avisa quando a base transborda.
@export var footprint_cells: Vector2i = Vector2i.ONE
## Orientações "de lado" (NW e SW) giram o footprint: 1×2 vira 2×1.
@export var swap_footprint_on_side_orientations: bool = true
## Precisa bater com o tile_size do TileSet da estrutura.
@export var tile_size: Vector2i = Vector2i(128, 64)

@export_category("Colisão")
@export var collision_source: CollisionSource = CollisionSource.SPRITE_BASE
## Encolhe o polígono para dentro. Sem folga, uma célula vizinha encostada na
## borda pode ser lida como bloqueada.
@export_range(0.0, 32.0, 1.0) var collision_inset: float = 4.0
## Desligue para um móvel que o personagem atravessa (tapete, luminária de teto).
@export var blocks_movement: bool = true

@export_category("Interação")
## Sobra em volta do footprint onde o personagem consegue interagir.
@export_range(0.0, 4.0, 0.05) var interaction_margin_cells: float = 0.5
@export var interaction_prompt: String = ""


## Footprint já considerando a orientação.
func footprint_for(orientation: int) -> Vector2i:
	var swapped := swap_footprint_on_side_orientations and (orientation % 2 == 1)
	return Vector2i(footprint_cells.y, footprint_cells.x) if swapped else footprint_cells


func texture_for(orientation: int) -> Texture2D:
	if orientation < 0 or orientation >= orientation_textures.size():
		return null
	return orientation_textures[orientation]

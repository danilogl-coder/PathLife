## Definição de um bioma. Criar um bioma novo = criar um `.tres` deste tipo.
##
## Nenhuma linha de código precisa mudar: o [BiomeResolver] pontua todos os
## biomas da lista e escolhe o melhor.
class_name BiomeDefinition
extends Resource

@export var id: StringName = &"novo_bioma"
@export var display_name: String = "Novo bioma"

@export_group("Clima")
@export_range(0.0, 1.0) var temperature_min: float = 0.0
@export_range(0.0, 1.0) var temperature_max: float = 1.0
@export_range(0.0, 1.0) var humidity_min: float = 0.0
@export_range(0.0, 1.0) var humidity_max: float = 1.0
@export_range(0.0, 1.0) var continentalness_min: float = 0.0
@export_range(0.0, 1.0) var continentalness_max: float = 1.0
## Largura da faixa de transição fora do intervalo preferido.
@export_range(0.01, 0.5) var transition_width: float = 0.12
## Peso final: use para deixar um bioma mais raro ou mais dominante.
@export_range(0.0, 4.0) var weight: float = 1.0

@export_group("Altura")
@export var min_world_height: int = -999
@export var max_world_height: int = 999
## Deslocamento aplicado ao relevo dentro deste bioma (em níveis).
@export_range(-16.0, 16.0, 0.1) var height_bias: float = 0.0
## Multiplicador de amplitude do relevo dentro do bioma.
@export_range(0.0, 4.0, 0.05) var height_amplitude: float = 1.0

@export_group("Visual")
## Variantes de grama do bioma, da mais densa para a mais rala.
##
## O mundo sorteia entre elas usando um ruído de baixa frequência, então as
## variantes aparecem em MANCHAS contíguas — mato fechado aqui, grama rala ali —
## em vez de um chuvisco aleatório célula a célula. Vazio = usa
## [member ground_id].
@export var ground_variants: Array[GroundVariant] = []
## Chão usado quando não há variantes registradas.
@export var ground_id: StringName = &"campo_baixo"
## Bloco de TERRA usado nas paredes/colunas abaixo da grama.
##
## Cada bioma tem o seu, derivado da lateral do próprio tile de grama. Sem isso
## a grama parece flutuar quando há desnível de dois ou mais níveis.
@export var wall_id: StringName = &"campo_terra"
## Chão usado quando a célula fica submersa.
@export var underwater_ground_id: StringName = &"campo_terra"

@export_group("Conteúdo")
@export var decorations: Array[DecorationDefinition] = []
@export var structure_pool: Array[StructureDefinition] = []


## Escolhe a variante de chão para um valor de variação em 0..1.
##
## As variantes ocupam faixas proporcionais ao peso, na ordem em que estão no
## array. Como `variation` vem de um ruído suave, faixas vizinhas viram manchas
## vizinhas — e a ordem do array define quem faz fronteira com quem.
func pick_ground(variation: float) -> StringName:
	if ground_variants.is_empty():
		return ground_id
	var total := 0.0
	for variant in ground_variants:
		if variant != null:
			total += maxf(variant.weight, 0.0)
	if total <= 0.0:
		return ground_id
	var target := clampf(variation, 0.0, 0.999999) * total
	var walked := 0.0
	for variant in ground_variants:
		if variant == null:
			continue
		walked += maxf(variant.weight, 0.0)
		if target < walked:
			return variant.ground_id
	return ground_variants[ground_variants.size() - 1].ground_id

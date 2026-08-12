@tool
class_name SaiaRecurso
extends Resource
## Dados de UMA saia. Trocar de modelo de saia e' trocar este recurso.
##
## Separado de proposito: o SaiaMalha so' sabe montar malha, e o SaiaBalanco so'
## sabe balancar osso. Uma saia nova nao encosta em nenhum dos dois -- ela e'
## outro .tres apontando para outro JSON e outras texturas.

## JSON gerado por gerar_saia_malha.py. Traz, por corpo e direcao: poligono, uv,
## triangulos, pesos por osso, posicao dos ossos, z do painel e das texturas.
@export_file("*.json") var dados: String = ""

## Pasta onde estao as texturas, no formato que o JSON referencia.
@export_dir var pasta_texturas: String = ""

@export_group("Balanco")
## Frequencia propria, em Hz. Mais alto = pano mais duro e mais curto.
@export_range(0.5, 6.0) var rigidez: float = 2.4
## Abaixo de 1 a saia passa do ponto e volta -- e' esse excesso que le' como
## pano. Em 1,0 ela para onde o corpo parou, e le' como madeira.
@export_range(0.05, 1.0) var amortecimento: float = 0.34
## Graus de balanco por unidade de aceleracao horizontal do quadril.
@export_range(0.0, 0.2) var ganho: float = 0.055
## Teto rigido do balanco, em graus. Impede giro livre e acumulo de energia.
@export_range(0.0, 30.0) var limite: float = 12.0

@export_group("Barra")
## Segundo estagio: mais mole que o corpo da saia, porque e' ponta solta.
@export_range(0.3, 5.0) var rigidez_barra: float = 1.6
## Bem subamortecida: e' aqui que mora o atraso que faz a barra ler como pano.
@export_range(0.05, 1.0) var amortecimento_barra: float = 0.24
## Teto do atraso da barra em relacao ao corpo da saia, em graus.
@export_range(0.0, 20.0) var limite_barra: float = 7.0

## Abaixo desta velocidade de quadril (px/s) o balanco e' congelado. Sem isto,
## ruido de subpixel vira tremedeira com o personagem parado.
@export_range(0.0, 20.0) var limiar_parado: float = 1.5

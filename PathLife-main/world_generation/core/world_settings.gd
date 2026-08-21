## Configuração global do mundo procedural.
##
## É um [Resource]: crie um `.tres` em `res://data/world/` e ajuste tudo pelo
## Inspector. Nenhum sistema deve ler números mágicos direto do código.
class_name WorldSettings
extends Resource

@export_category("Semente")
## Semente mestre do mundo. 0 = sorteia uma semente ao iniciar.
@export var world_seed: int = 20260819

@export_category("Chunks")
@export_range(4, 64, 1) var chunk_size: int = 16
## Raio (em chunks) mantido carregado ao redor do jogador.
@export_range(0, 8, 1) var render_distance: int = 2
## Quantos chunks além do raio ficam vivos antes de descarregar (histerese).
@export_range(0, 4, 1) var unload_margin: int = 1
## Tamanho da região macro (em chunks) usada para planejar estruturas grandes.
@export_range(1, 32, 1) var generation_region_size_chunks: int = 4

@export_category("Projeção isométrica")
## Tamanho do losango da face superior do tile (deve bater com o TileSet).
@export var tile_size: Vector2i = Vector2i(128, 64)
## Altura em pixels de um nível de terreno (altura da lateral do bloco).
@export_range(1, 128, 1) var height_pixels: int = 26

@export_category("Limites de altura")
@export_range(-64, 0, 1) var min_height: int = -8
@export_range(0, 64, 1) var max_height: int = 14
## Altura da lâmina d'água. Células abaixo disso viram líquido.
##
## Deixe igual a [member min_height] para desligar a água (é o padrão do
## projeto, já que não há arte de água). Suba depois de catalogar um tile de
## água no [TileCatalog] e reativar o WaterPass.
@export_range(-64, 64, 1) var sea_level: int = -8

@export_category("Geração assíncrona")
## Quantos chunks podem ser gerados em paralelo. Também define quantas cópias
## dos recursos de geração são criadas (uma por thread, para evitar disputa).
@export_range(1, 16, 1) var max_parallel_generations: int = 4
## Quantos chunks no máximo são integrados na SceneTree por frame.
@export_range(1, 16, 1) var max_chunk_integrations_per_frame: int = 1
## Se falso, gera tudo na main thread (útil para depurar).
@export var use_worker_threads: bool = true

@export_category("Renderização")
## Profundidade máxima de parede desenhada abaixo de um bloco.
@export_range(1, 32, 1) var max_wall_depth: int = 6
## Id do tile desenhado na superfície da água (precisa existir no TileCatalog).
@export var water_ground_id: StringName = &"campo_terra"

@export_group("Leitura de altura")
## Sombreia os níveis diferentes do nível de referência. É o indicativo visual
## de "este bloco está acima/abaixo de mim" — sem ele, dois patamares vizinhos
## têm exatamente a mesma arte e o degrau some.
@export var height_shading_enabled: bool = true
## Quanto CADA nível ABAIXO da referência escurece.
@export_range(0.0, 0.4, 0.005) var height_shading_step_below: float = 0.30
## Quanto CADA nível ACIMA da referência é atenuado.
@export_range(0.0, 0.4, 0.005) var height_shading_step_above: float = 0.14
## Piso do multiplicador, para o fundo não virar preto.
@export_range(0.1, 1.0, 0.01) var height_shading_min: float = 0.40
## Quanto os níveis abaixo puxam para o azul (sombra fria). 0 = cinza puro.
@export_range(0.0, 1.0, 0.01) var height_shading_coolness: float = 0.5
## Nível neutro usado enquanto ninguém informa outro. Em jogo, o
## [HeightVisibilityManager] passa o nível do jogador.
@export var height_shading_reference: int = 0


## Cor de multiplicação da camada de um nível.
##
## O nível de referência (normalmente onde o jogador está) fica com a cor
## ORIGINAL, sem multiplicação nenhuma. Os de baixo escurecem e esfriam; os de
## cima recebem uma atenuação mais leve e levemente quente, para os dois lados
## serem distinguíveis à primeira vista.
func tint_for_level(level: int, reference_level: int = 2147483647) -> Color:
	if not height_shading_enabled:
		return Color.WHITE
	var reference := height_shading_reference
	if reference_level != 2147483647:
		reference = reference_level

	var delta := level - reference
	if delta == 0:
		return Color.WHITE

	if delta < 0:
		var factor := clampf(1.0 + float(delta) * height_shading_step_below, height_shading_min, 1.0)
		var cool := (1.0 - factor) * height_shading_coolness
		return Color(factor * (1.0 - cool * 0.45), factor * (1.0 - cool * 0.18), factor, 1.0)

	var above := clampf(1.0 - float(delta) * height_shading_step_above, height_shading_min, 1.0)
	var haze := (1.0 - above) * 0.5
	return Color(above + haze * 0.16, above + haze * 0.12, above + haze * 0.06, 1.0)


## Semente efetiva. Se [member world_seed] for 0, sorteia uma nova.
func resolved_seed() -> int:
	if world_seed != 0:
		return world_seed
	return int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF

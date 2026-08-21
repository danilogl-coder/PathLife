# Relatório — Mundo isométrico procedural do PathLife

Implementação do tutorial `tutorial_mundo_isometrico_procedural_godot_4_6.md`
adaptada ao projeto PathLife (Godot 4.6), respeitando as regras do projeto:
**tudo que é previsível vive em cenas `.tscn` e recursos `.tres`; código só cria
nó quando o conteúdo é realmente dinâmico (e mesmo aí, instanciando uma cena
reutilizável).**

---

## 1. O que foi entregue, em uma frase

Um mundo praticamente infinito, gerado em chunks fora da main thread, com altura
positiva e negativa, 12 biomas grandes com transição gradual, relevo
independente do bioma, estruturas que **o terreno se adapta a elas**, vegetação
data-driven, renderização por `TileMapLayer` com blocos empilhados, movimento em
grade `Vector3i` estilo Minecraft, pathfinding e save incremental — tudo
configurável pelo Inspector.

---

## 2. Arquitetura

```text
                       WorldSettings (.tres)
                               │
                         WorldSampler
              (clima + bioma + relevo, coordenada MUNDIAL)
                               │
     ┌───────────────┬─────────┴─────────┬───────────────┐
     ▼               ▼                   ▼               ▼
 ClimatePass     BiomePass          HeightPass     StructurePass
                                                    + TerrainAdapter
                               │
                        TerrainPass → WaterPass → DecorationPass
                               │
                          ChunkData  (DADOS)
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
   ChunkView            WorldData/Navigation     WorldSaveManager
   (TileMapLayer,       (MovementRules,          (semente + patches)
    cenas de árvore,     A*, WorldGridAgent)
    cenas de estrutura)
```

Regra que sustenta tudo: **o `TileMapLayer` nunca é a fonte da verdade.** Ele
desenha o que o `WorldData` diz. Trocar a arte do mundo inteiro é trocar um
`.tres` (o `TileCatalog`), sem tocar em geração, IA ou save.

---

## 3. Arquivos criados

### 3.1 Scripts — `res://world_generation/`

| Pasta | Arquivo | Papel |
|---|---|---|
| `core/` | `world_settings.gd` | **Resource** com toda a configuração global (chunk, raio, alturas, threads). |
| | `world_random.gd` | Sub-sementes determinísticas por sistema (`terrain`, `climate`, `structures`…). |
| | `iso_coordinate_system.gd` | **Único** lugar que conhece a projeção isométrica. |
| | `chunk_math.gd` | World ↔ Chunk ↔ Local ↔ Região (correto com negativos). |
| | `world_cell.gd` | A célula lógica (altura, bioma, relevo, caminhável, líquido…). |
| | `world_data.gd` | Camada de leitura do mundo carregado. Fonte da verdade do gameplay. |
| | `world_sampler.gd` | Clima+bioma+relevo em qualquer coordenada, independente de chunk. |
| | `generation_context.gd` | Contexto passado de passe em passe. |
| | `world_generation_pass.gd` | Interface (abstrata) de um passe da pipeline. |
| | `world_generator.gd` | Executa a pipeline; sabe se clonar para thread. |
| `climate/` | `climate_sample.gd`, `climate_generator.gd` | Temperatura, umidade, continentalidade, "weirdness". |
| | `biome_definition.gd` | **Resource** de bioma. |
| | `biome_resolver.gd` | Pontua todos os biomas e escolhe principal + secundário. Sem cadeia de `if`. |
| `terrain/` | `height_generator.gd` | Relevo por `FastNoiseLite` (continente + elevação + montanha + detalhe). |
| | `terrain_definition.gd`, `terrain_resolver.gd` | Relevo (plano/colina/montanha/penhasco) **independente** do bioma. |
| `passes/` | `01..07` | `ClimatePass`, `BiomePass`, `HeightPass`, `StructurePass`, `TerrainPass`, `WaterPass`, `DecorationPass`. |
| `structures/` | `structure_definition.gd` | **Resource** com footprint, spawn, biomas permitidos e modo de adaptação. |
| | `structure_placement.gd` | Estrutura já decidida (dado puro). |
| | `structure_planner.gd` | Planeja por **região** (4×4 chunks), nunca por chunk. |
| | `structure_root.gd` | Raiz `@tool` da cena da construção, com gizmo de footprint no editor. |
| | `structure_marker.gd` | `Marker2D` tipado: ENTRANCE, ROAD, NPC_SPAWN, DELIVERY, INTERACTION, CUSTOM. |
| | `terrain_adapter.gd` | Achata o footprint e mistura a borda (`smoothstep`) — nada de paredão artificial. |
| `decoration/` | `decoration_definition.gd`, `decoration_placement.gd` | Vegetação e objetos espalhados por dados. |
| `rendering/` | `tile_catalog.gd`, `ground_tile_entry.gd` | Traduz id lógico → tile do TileSet (superfície, face e bloco completo). |
| | `chunk_view.gd` | Visual de um chunk: camadas Ground (superfície) e Depth (faces) por nível. |
| | `height_visibility_manager.gd` | Esconde/esmaece níveis acima do jogador **sem alterar dados**. |
| `chunks/` | `chunk_data.gd` | Dados do chunk (não é Node → pode nascer em worker thread). |
| | `chunk_manager.gd` | Streaming: pede, gera em `WorkerThreadPool`, integra e descarrega. |
| `navigation/` | `movement_rules.gd` | **Regra única** de movimento (+1 sobe, −1 desce, +2 bloqueia, queda). |
| | `movement_context.gd` | Capacidades da entidade (nadar, escalar, degrau máximo). |
| | `world_navigation.gd` | A* sobre a grade lógica, sempre consultando `MovementRules`. |
| `agents/` | `world_grid_agent.gd` | Dá posição lógica `Vector3i` a qualquer `Node2D` e anima o passo. |
| | `world_object_anchor.gd` | Assenta um objeto **estático** (mobília, marco) na grade: o nó fica na célula, o filho recebe a altura. |
| `saving/` | `cell_patch.gd`, `world_save_manager.gd` | Save incremental: semente + diferenças + objetos removidos. |

### 3.2 Cenas

| Cena | O que é |
|---|---|
| `world_generation/rendering/height_layer.tscn` | `TileMapLayer` configurada (Y-Sort + filtro nearest). Instanciada por nível. |
| `world_generation/rendering/chunk_view.tscn` | `ChunkView` com `GroundLayers` / `DepthLayers` / `OverlayLayers` / `Structures` / `Decorations`. |
| `world_generation/agents/world_object_anchor.tscn` | Âncora reutilizável para pôr qualquer objeto autorado em cena em cima do relevo. |
| `scenes/world/procedural_world.tscn` | O mundo pronto para instanciar: `ChunkContainer` + `ChunkManager` + `HeightVisibility` + `SaveManager`. |
| `scenes/world/world_demo.tscn` | Laboratório autônomo (F6): mundo + ator em grade + HUD de debug. |
| `presentation/world/vegetation/arvore_*.tscn` | 6 árvores (álamo, baobá, ipê, palmeira, salgueiro, sequoia), animadas. |
| `presentation/world/structures/deck_madeira.tscn` | Estrutura de exemplo 4×4 com `StructureRoot` e 3 marcadores. |

### 3.3 Recursos gerados (`res://data/world/`) — 87 `.tres`

`world_settings`, `world_sampler`, `world_generator`, `climate_generator`,
`height_generator`, `biome_resolver`, `terrain_resolver`, `structure_planner`,
`player_movement_context`, 9 ruídos, **5 biomas** (um por pasta de bioma da
arte), **44 variantes de grama** (16 da sua arte + 28 de transição), 4 terrenos, 6 decorações, 1 estrutura,
7 passes, `tiles/ground_tileset` e `tiles/ground_catalog`.

Os biomas são `campo_claro`, `campo`, `floresta`, `campo_florido` e `savana` —
o espaço climático (temperatura × umidade) é repartido entre eles, cada um com
o seu bloco de terra em `wall_id` e a sua lista de variantes.

**Variantes em manchas.** Dentro de um bioma, a variante de grama de cada célula
é escolhida por um ruído próprio (`ground_variation`, manchas de ~26 células com
detalhe fino de ~7 para esfarelar as bordas). O resultado são áreas contíguas de
mato fechado, grama rala e rasteira em vez de um chuvisco célula a célula. A
ordem do array `ground_variants` define quem faz fronteira com quem: ele é
percorrido conforme o ruído sobe, então vale listar da mais densa para a mais
rala.

A água está **desligada** (`sea_level = min_height` e o passe de água com
`enabled = false`), porque não há arte de água. O sistema continua no lugar:
basta catalogar um tile de água e reativar.

Todos foram criados pela ferramenta `tools/build_world_resources.gd` e são
recursos normais: **a partir de agora, edite pelo Inspector**.

### 3.4 Arte

| Arquivo | Origem |
|---|---|
| `assets/world/tiles/ground_atlas.png` (384×5194) | Bloco completo: 3 colunas de animação × 49 linhas. |
| `assets/world/tiles/ground_top_atlas.png` (384×5194) | Só a superfície (usado pelas camadas Ground). |
| `assets/world/tiles/depth_face_atlas.png` (1152×5194) | Só as faces expostas: esquerda, direita e ambas, lado a lado. |
| `assets/world/tiles/ground_atlas.json` | Manifesto: linhas, quais animam, e a escala de variantes de cada bioma. |
| `assets/world/vegetation/arvore_*_atlas.png` (1024×1248) | Os 48 quadros de queda de folha de cada árvore, em grade 8×6. |
| `assets/world/vegetation/arvores_atlas.json` | Manifesto: textura, tamanho do quadro, grade e cadência. |
| `presentation/world/vegetation/arvore_*_frames.tres` | `SpriteFrames` de cada árvore, gerado do manifesto. |
| `assets/world/structures/piso_madeira.png` | `Tile Floor Wood Home/sala/sala_bloco.png`. |

**As 16 variantes de grama que você desenhou entram intactas e animadas
(3 frames cada)** — nenhum pixel delas foi tocado:

| Bioma (pasta) | Variantes |
|---|---|
| Campo Verde | `campo_alto`, `campo_mato_denso`, `campo_quase_ralo`, `campo_ralo`, `campo_baixo` |
| Campo Verde Claro | `claro_denso`, `claro` |
| Campo Florida | `florida`, `florida_rasteira`, `florida_baixa` |
| Floresta | `floresta`, `floresta_rasteira`, `musgo` |
| Savana | `savana`, `savana_rasteira`, `savana_baixa` |

**Entre elas entram 28 variantes de TRANSIÇÃO, também animadas** — ver 4.7. Cada
bioma vira uma escala contínua, do tile mais escuro/denso ao mais claro/ralo.

**As últimas 5 linhas são o bloco de TERRA de cada bioma, estático:** `campo_terra`,
`campo_claro_terra`, `campo_florido_terra`, `floresta_terra`, `savana_terra`.

Cada bloco de terra é derivado do tile de grama correspondente:

* a **lateral é cópia pixel a pixel** do tile original (só os tufos de grama que
  caíam sobre ela são substituídos), então a coluna encaixa perfeitamente
  embaixo da grama — era a falta disso que fazia a grama parecer flutuando em
  desníveis de dois ou mais níveis;
* a **face de cima** é pintada com a paleta de terra extraída da própria lateral
  daquele tile (5 cores, nada inventado), com ruído em blocos, dithering
  ordenado 4×4 e pedrinhas — pixel art de verdade, não textura redimensionada;
* **não animam**: só a arte que você forneceu anima.

Só existem tiles derivados da sua arte. Não há areia, pedra, neve nem água
inventadas — e nas transições nem cor nova existe: cada pixel é literalmente um
pixel de uma das duas artes vizinhas.

### 3.5 Ferramentas e testes

| Arquivo | Uso |
|---|---|
| `tools/gen_ground_atlas.py` | Monta os atlas de chão + o manifesto (escala de variantes por bioma). |
| `tools/gen_tree_atlases.py` | Monta os atlas de animação das árvores + o manifesto. |
| `tools/build_world_resources.gd` | Recria todos os `.tres` do zero, lendo os dois manifestos. |
| `tools/screenshot_runner.gd` | Roda N frames e salva um print (usado para validar visual). |
| `tests/world_generation_test.gd` | 96 verificações de lógica pura. |
| `tests/player_grid_integration_test.gd` | 32 verificações com `SceneTree` real. |
| `tests/terrain_depth_composition_test.gd` | Mede em pixels por que piso e faces ficam no mesmo Z. |
| `tests/character_walk_flicker_test.gd` | Mede a cintilação das pernas num passo, nos quatro sentidos. |
| `tests/world_roaming_visual_test.gd` | 512 passos pelo mundo + contact sheet de regressão visual. |
| `tests/world_depth_preview.gd` | Print da oclusão Ground/Depth com o personagem real. |

---

## 4. Decisões técnicas que valem registro

### 4.1 Geometria do tile
A sua arte de chão tem **128×106 px**: o losango de topo (128×64) começa em
`y = 16` e a saia de terra tem **26 px**. Por isso:

* `TileSet.tile_size = (128, 64)`, formato isométrico, layout *diamond down*;
* cada tile do atlas usa `texture_origin = (0, −5)` (sem isso o chão fica
  desalinhado da grade);
* `WorldSettings.height_pixels = 26` — igual à saia. Assim **um degrau de 1
  nível encaixa perfeitamente**, sem sobreposição nem fresta.

### 4.2 Ordenação de profundidade — um único espaço de Y-Sort

Na projeção isométrica, o que está mais perto da câmera é o que tem maior
`x + y`. A altura é só desempate. Então **a chave de ordenação é a posição PLANA
da célula**, nunca a posição visual (que já subiu com a altura).

O desenho de um bloco foi separado em duas classes, para não redesenhar o bloco
inteiro em terreno plano:

* **Ground** — só a superfície (o losango de cima), fonte 0 do `TileSet`,
  atlas `ground_top_atlas.png`;
* **Depth** — só as faces verticais expostas, fonte 1, atlas
  `depth_face_atlas.png`, com uma variação por lado (esquerda / direita /
  ambas). Uma face só é pintada quando o vizinho FRONTAL daquele lado é mais
  baixo;
* a fonte 2 guarda o **bloco completo** original, para ferramentas e cenas
  antigas continuarem funcionando.

**A regra inegociável** é que essa separação é só de conteúdo, nunca de
profundidade:

* todas as `TileMapLayer` — Ground e Depth — ficam em `position = 0`,
  `z_index = 0`, `y_sort_origin = 0` e `y_sort_enabled = true`;
* as raízes `GroundRoot`, `DepthSort` e as entidades também estão em `z 0` com
  Y-Sort ligado, então terreno, faces, vegetação, mobília e jogador disputam
  profundidade no MESMO espaço;
* o deslocamento vertical de cada nível vive no **`texture_origin`** de uma
  *alternative tile* por altura (`texture_origin.y = -5 + nível × 26`) — é
  aparência, não ordenação;
* dentro de uma célula a ordem é **superfície (pivô 0) → objeto (pivô 16, um
  quarto do tile) → parede frontal (pivô 31, quase meia altura)**, e a próxima
  diagonal chega em 32, cobrindo tudo isso. O quarto de tile do objeto não é
  chute — ver 4.11;
* árvores e estruturas nascem dentro de uma **âncora** (`prop_anchor.tscn`)
  posicionada no plano e recebem a altura como deslocamento local; entidades
  usam a mesma ideia via `WorldGridAgent` (grupo `grid_sort_anchor`); objetos
  autorados à mão usam `world_object_anchor.tscn`.

> **Bug do "tile recortado" — corrigido duas vezes.** O `GroundRoot` foi parar
> em `z_index = -1` enquanto o `DepthSort` ficava em `z_index = 0`. No Godot **o
> Z-Index é resolvido ANTES do Y-Sort**: com as duas classes em Z diferentes elas
> param de disputar profundidade entre si, e **toda face de terra passa a ser
> desenhada por cima de toda superfície de grama** — inclusive a da célula que
> está na frente dela. O resultado eram lascas de terra furando a grama, como se
> o tile tivesse sido recortado com tesoura.
>
> Na segunda vez veio acompanhado de uma classe `DepthCap`: a superfície de uma
> célula cujo vizinho de TRÁS fosse mais alto era movida para dentro de Depth,
> para conseguir recobrir a sobra daquela face. Era remendo do sintoma — com as
> duas classes no mesmo Z isso acontece sozinho, porque a face de trás fica meio
> tile atrás no Y-Sort. A classe foi removida.
>
> Das duas vezes a motivação declarada foi a mesma: proteger as pernas do
> personagem, que o piso estaria "engolindo". **Foi medido**, lendo as duas
> composições no MESMO quadro para a animação não poluir a conta: com o piso no
> Z comum o ator perde **320 px de 19 620 (1,6%)** — a grama da célula da frente
> encostando nos pés dele, que é profundidade correta, não defeito. Tirar o piso
> do Z comum devolve esses 320 px e, em troca, muda **11 192 px do terreno**.
> Trinta e cinco vezes mais estrago do que ganho. O teste
> `tests/terrain_depth_composition_test.gd` guarda essa conta.
>
> A cintilação que se tentava resolver com o Z tinha outra causa, no viés de
> ordenação do ator — ver 4.11.
>
> Por isso a normalização agora acontece **em código**, no
> `ProceduralWorld._normalize_sorting_space()`: se alguém der um Z próprio ao
> piso na cena, o jogo devolve para zero e emite um aviso, em vez de depender de
> alguém lembrar de conferir.

> **Tentativa mais antiga, também errada:** uma `TileMapLayer` por nível
> deslocada em `y = -nível × 26` com `z_index = nível`. Mesmo problema, em outra
> roupa: qualquer terreno mais alto era desenhado por cima do jogador, inclusive
> o que estava atrás dele.

### 4.2.1 Leitura de altura

Dois blocos vizinhos com um nível de diferença têm exatamente a mesma arte —
sem ajuda, o jogador não percebe o degrau. Foram adicionados:

* **sombreamento por altura relativo ao jogador**: o nível em que ele está fica
  com a **cor original**, sem multiplicação nenhuma; os de baixo escurecem e
  esfriam (**22% por nível**) e os de cima recebem uma atenuação mais leve e
  levemente quente (**14% por nível**). O passo é POR NÍVEL — um degradê
  absoluto sobre 20+ níveis daria menos de 3% e seria invisível. É esse
  contraste que faz um patamar inteiro ser lido como um patamar, e não como
  grama solta com riscos de terra. Configurável em `WorldSettings` →
  *Leitura de altura*;
* **sombra de contato** (`presentation/world/entity_shadow.tscn`) sob as
  entidades, para ancorar o personagem no chão. É uma elipse isométrica com
  contorno em xadrez na cor `(40, 34, 52)` — o mesmo estilo (e a mesma cor) das
  sombras que já existem sob as suas árvores, gerada por
  `tools/gen_entity_shadow.py`;
* o recorte correto do corpo pelo terreno da frente, que agora funciona e é o
  que comunica "estou um nível abaixo".

### 4.2.2 Patamares — por que o relevo é filtrado

Só metade dos degraus aparece em vista isométrica: você enxerga as faces que
apontam para +X e +Y (para a câmera), nunca as de trás. Um degrau de **uma
célula solta** no meio do campo, então, não vira penhasco — vira um risco de
terra de 26 px cercado de grama, exatamente o que dava a impressão de tile
recortado.

Por isso `WorldSampler.base_height()` passa o relevo por um **filtro de mediana**
(grupo *Patamares*, no Inspector):

| Propriedade | Padrão | O que faz |
|---|---|---|
| `plateau_filter_enabled` | ligado | Desligue para ver o ruído cru. |
| `plateau_filter_radius` | 2 | Vizinhança da mediana (2 = 5×5). |
| `plateau_filter_passes` | 2 | Passadas. 2 apaga também as línguas de duas células. |
| `height_cache_limit` | 65536 | Teto do cache de níveis por thread. |

Mediana é o filtro clássico para isso: apaga o que aparece em uma célula só e
**preserva bordas longas e retas**, então os penhascos continuam existindo — só
que contínuos. Continua sendo função **pura da coordenada mundial** (olha o
ruído da vizinhança, nunca o chunk), então não há costura entre chunks nem
diferença entre threads. Cada passada é memorizada; sem o cache a recursão
reamostraria a mesma célula centenas de vezes.

Custo medido: **29 ms por chunk 16×16** com o padrão (era 6 ms sem filtro), em
worker thread.

### 4.2.3 Objetos autorados à mão no editor

Um `Node2D` largado na cena é ordenado pela posição visual. Num mundo com
relevo isso está errado: quem decide a profundidade é a **célula**, e o objeto
em cima de um morro aparece 26 px acima por nível sem mudar de célula. Antes da
correção as camas de teste eram cobertas pela grama que deveria estar atrás
delas.

`WorldObjectAnchor` (`world_generation/agents/world_object_anchor.tscn`) resolve
isso do mesmo jeito que o jogador: **o nó fica na posição plana da célula e os
filhos recebem só o deslocamento de altura**. Basta pôr o objeto como filho da
âncora e arrastar a âncora no editor — com `derive_cell_from_position` ligado, a
célula é lida da própria posição. O `ProceduralWorld` chama `snap_world_objects()`
assim que o terreno existe e assenta tudo que estiver no grupo
`world_object_anchor`.

### 4.3 Paredes de desnível
Além do bloco de topo, o `ChunkView` empilha blocos de parede (`wall_id` do
bioma) do nível `h−1` até a altura do vizinho da frente mais baixo, limitado por
`WorldSettings.max_wall_depth`. Desníveis grandes viram penhascos sólidos em vez
de buracos.

### 4.4 Thread safety (armadilha do Godot 4.4+)
`Resource.duplicate(true)` **não copia mais sub-recursos externos** (os que têm
arquivo `.tres` próprio) nem objetos dentro de arrays. Isso faria todas as
"cópias" do gerador compartilharem os mesmos `FastNoiseLite` — disputa entre
threads e mundo errado.

Por isso existem `WorldGenerator.clone()`, `WorldGenerationPass.clone_pass()` e
`WorldSampler.clone_for_thread()`: a clonagem é explícita e copia exatamente o
que tem estado (os ruídos), compartilhando de propósito o que é somente leitura
(biomas, terrenos, cenas). Há teste automatizado cobrindo isso.

### 4.5 Estruturas nascem antes do terreno final
`StructurePass` roda **antes** de `TerrainPass`/`WaterPass`. O planejamento é por
região (4×4 chunks), então uma estrutura na borda aparece no plano dos dois
chunks vizinhos, mas só é **instanciada** pelo chunk que contém a origem do
footprint — nunca duplica. O `TerrainAdapter` achata o footprint e mistura a
borda com `smoothstep`.

### 4.6 O jogador virou grade `Vector3i`
`PlayerController` ganhou `@export var grid_agent: WorldGridAgent`. Com o agente
ligado (é o padrão em `player.tscn`), o movimento é célula a célula e passa
obrigatoriamente por `MovementRules`. Sem ele, o controlador cai no movimento
livre antigo — útil em cenas de teste sem mundo.

Toda a API pública anterior foi preservada (`locomotion_changed`,
`crouch_changed`, `sleep_changed`, `health_changed`, `set_controls_enabled`,
`enter_sleep`, `exit_sleep`, `damage`, `heal`…), então HUD, customização e o
sistema de cama continuam funcionando. O agente ainda consulta a física
(`test_move`) antes de andar, então camas e paredes `StaticBody2D` continuam
bloqueando o passo.

### 4.7 Variantes de transição — suavizando o contraste entre tiles

O bioma tinha só as artes originais, e o salto entre duas vizinhas era grande:
de `claro_denso` para `claro` a luminosidade pulava 9 pontos de uma célula para
a outra, e de `savana` para `savana_rasteira` o mato alto sumia de vez. O campo
lia como manchas coladas em vez de um terreno.

A ferramenta agora monta **uma escala por bioma**:

1. **Mede** cada arte: cor média da face de cima em Lab, quanto de terra
   aparece e quantos pixels de lâmina sobem acima do losango.
2. **Encadeia** as variantes minimizando o salto entre vizinhas. São no máximo
   5 por bioma, então dá para testar todas as ordens e escolher a melhor em vez
   de chutar. A cadeia sai do tile mais escuro para o mais claro.
3. **Preenche** cada par com transições, quantas o salto pedir
   (`distância / 4.5`, no máximo 4).

Uma transição em `t` é a mistura das duas artes vizinhas. **Nenhum pixel é
inventado nem interpolado**: cada pixel vem inteiro de uma das duas. Quem decide
de qual é um mapa por pixel, e o mapa muda de regime conforme a arte:

* **tapete** (grama baixa, musgo): mistura fina, em grãozinhos de 2 a 4 px. Duas
  texturas entrelaçadas leem opticamente como o tom do meio — é a técnica
  clássica de pixel art;
* **lâmina** (mato alto, savana): a máscara passa a variar ao longo de X, em
  faixas. Lâmina é vertical: serrilhada pixel a pixel vira chuvisco; escolhida
  em faixa, some ou aparece inteira;
* **acima do losango** a escolha é sempre por coluna, senão a ponta de uma
  lâmina ficaria solta no ar, sem a base.

Dois detalhes que decidiram a qualidade do resultado:

* **nada de Bayer puro.** Com a matriz ordenada sozinha, `t` perto de 0,5 vira
  um xadrez perfeito e o tile ganha efeito de tela de mosquiteiro. O grão fino é
  ruído, que aglomera os pixels em tufos irregulares; o Bayer entra com um
  quinto do peso, só para a distribuição não empoçar;
* **o histograma da máscara é achatado.** Ruído de valor interpolado não é
  uniforme — os valores se aglomeram perto de 0,5. Sem corrigir, `t = 0,2` e
  `t = 0,4` trocavam quase nada e `t = 0,6` trocava metade do tile de uma vez: a
  escala andava aos trancos. Trocando cada valor pela sua posição no ranking,
  `t` passa a significar exatamente "esta fração da área vem do segundo tile".

Os três quadros de animação usam a **mesma máscara**, então a lâmina que balança
continua sendo a mesma lâmina nos três — a transição anima igual à arte original.

**Peso no sorteio:** a transição é ponte, não variante nova. Ela recebe 30% do
menor peso do par, e as artes originais mantêm os pesos de design. O peso das
duas variantes de solo exposto (`campo_ralo`, `campo_quase_ralo`) foi reduzido:
a falha de terra que você desenhou no topo se repete a cada tile, então em
mancha grande ela chamava mais atenção que a grama.

### 4.8 Espelhamento do topo — o campo não é azulejo

Uma mancha de bioma usa a mesma arte em todas as suas células, então qualquer
detalhe do topo (uma falha de terra, uma pedra) se repetia numa grade perfeita.
Metade das células agora desenha o topo **espelhado na horizontal**, sorteado por
um hash estável da coordenada — recarregar o chunk não muda o desenho.

O espelho não custa nada no TileSet: o Godot aceita os bits de transformação
somados ao id da alternativa em `set_cell()`. E vale **só para o topo**: nas
faces o artista sombreou lado esquerdo e direito de formas diferentes, e trocá-los
inverteria a luz do penhasco.

### 4.9 O manifesto do atlas

`tools/gen_ground_atlas.py` agora grava
`assets/world/tiles/ground_atlas.json` junto com as imagens: quais linhas
existem, quais animam e a escala de variantes de cada bioma. O
`build_world_resources.gd` lê esse arquivo em vez de repetir a lista na mão.

Antes as duas listas viviam separadas: bastava acrescentar um tile na pasta de
arte para elas saírem de sincronia e o mundo desenhar o tile errado. Agora quem
gera a arte também descreve a arte, e acrescentar variantes virou "solte a pasta,
rode as duas ferramentas".

### 4.10 Árvores animadas

A pasta *arvores* traz, para cada espécie, **48 quadros de 128×208 com a queda
de folha** — e o GIF que veio junto define a cadência: 110 ms por quadro, ou
9,09 fps, num ciclo de 5,3 s.

* `tools/gen_tree_atlases.py` empilha os 48 quadros em **grade 8×6**
  (1024×1248). Em tira única a textura teria 6144 px de largura; em grade ela
  fica num formato amigável para qualquer GPU e ocupa ~80 KB em disco;
* `build_world_resources.gd` monta um `SpriteFrames` por árvore, com os quadros
  como `AtlasTexture` recortados de UMA textura — o Godot não carrega 48 imagens
  soltas por espécie, e trocar a arte é trocar um PNG;
* a cena da árvore virou `Node2D` + `AnimatedSprite2D`, com a mesma âncora de
  antes (`centered = false`, `offset = (-64, -198)`): o tronco continua no
  (0, 0) da célula, então nada mudou de lugar no mundo.

**Dessincronização.** Todas as instâncias de uma cena começam no quadro 0 — sem
tratar isso, a floresta inteira solta folha no mesmo instante e lê como um
objeto repetido. O script `VegetationAnimation` sorteia o quadro inicial (e uma
variação de ±12% na velocidade) a partir da **posição da decoração**, nunca do
relógio nem de `randi()`. Assim, quando o chunk é descarregado e volta, a árvore
reaparece no mesmo ponto da animação em vez de dar um salto. Há teste cobrindo
as duas coisas: 40 árvores vizinhas caem em mais de 10 quadros diferentes, e a
mesma célula cai sempre no mesmo quadro.

### 4.11 O viés do ator — por que é exatamente um quarto do tile

A chave de um tile de superfície é o **centro** do losango
(`y_sort_origin = 0`), não a borda da frente. O ator, por sua vez, é interpolado
linearmente entre duas células. Num passo de C para C+(1,0) ele percorre meia
altura de tile e cruza a fronteira das duas células exatamente no meio do
caminho. Igualando a chave dele à do tile de destino nesse instante:

```
centro_de_C + meia_altura * 0,5 + viés = centro_de_C + meia_altura
                                  viés = meia_altura / 2 = um quarto do tile
```

Com um viés menor a igualdade escorrega para o fim do passo. Com **0,5 px**
(tentado como "o ator deve ordenar pelos pés") ela cai em `t = 0,984`: o
personagem **atravessa o passo inteiro atrás da grama para a qual está andando**
e reaparece de uma vez no último quadro. Foi a cintilação das pernas relatada.

Medido, num passo plano, contando quantos pixels do ator sobrevivem à
composição em cada quadro:

| Viés | Pior quadro do passo | Maior salto entre quadros |
|---|---|---|
| 0,5 px | 2 492 px (~55% do rig) | 2 540 px (44%) |
| um quarto do tile | 4 505 px (~99% do rig) | 471 px (8%) |

E a mesma caminhada com o mundo escondido — só a animação — dá salto de 428 px.
Ou seja, com o viés certo **a ordenação não contribui em nada**: o que sobra é o
braço e a perna mudando a silhueta, como deve ser.

Duas travas cobrem isso: `tests/world_generation_test.gd` resolve o `t` da troca
nos quatro sentidos e exige que caia no meio do passo (roda headless, sem
driver), e `tests/character_walk_flicker_test.gd` mede os pixels quadro a
quadro com render de verdade, usando a caminhada sem mundo como linha de base.

---

## 5. Resultado dos testes

```
tests/world_generation_test.gd            →  96 passaram, 0 falharam
tests/player_grid_integration_test.gd     →  32 passaram, 0 falharam
tests/terrain_depth_composition_test.gd   →   3 passaram, 0 falharam
tests/character_walk_flicker_test.gd      →   8 passaram, 0 falharam
tests/world_roaming_visual_test.gd      →  512 passos, 31 camadas, sem divergência
```

Cobertura: coordenadas negativas, igualdade `IsoCoordinateSystem` ×
`TileMapLayer.map_to_local`, regras de degrau/queda/água, pontuação e alcance
dos 12 biomas, mistura do `TerrainAdapter`, determinismo por semente, ausência
de costura entre chunks, pipeline completa (relevo variado, biomas, relevos,
vegetação, água), estabilidade do planejamento por região, não-duplicação de
estruturas, terreno achatado sob o footprint, A* respeitando as regras, save
incremental, e — no teste de integração — carregamento/descarregamento de
chunks, sincronia entre views e dados, e o jogador andando de fato.

Além disso o mundo foi renderizado de verdade (OpenGL, 1600×900) em três
situações — campo com estruturas, terreno acidentado com neve e uma costa com
praia/savana/oceano — para conferir alinhamento, empilhamento e ordenação.

---

## 5.1 Medição com o personagem real

A perspectiva foi validada com o `character_visual.tscn` do projeto — o rig
cutout completo, com camisa, calça, sapato e cabelo — e não com um retângulo de
teste. O personagem foi renderizado isolado, com a origem no centro da tela, e
medido em pixels:

| Medida | Valor |
|---|---|
| Altura total | 81 px |
| Largura total | 28 px |
| Topo (cabeça) | −70 px da origem |
| **Base (sola do sapato)** | **+10 px da origem** |

Ou seja: **a origem do rig fica no tornozelo, e os pés passam 10 px dela.** Como
o mundo posiciona a entidade pelo centro da célula, o personagem fica com a sola
levemente à frente do centro do losango — o que lê bem em vista isométrica.

A consequência prática é a sombra: centrada na origem ela flutuaria na altura do
tornozelo. Por isso `entity_shadow.tscn` vem com `position = (0, 10)` — o
deslocamento medido. Se você preferir a sola exatamente no centro do losango,
suba o `VisualAnchor` do `player.tscn` em −10 px e zere a posição da sombra.

Os três casos foram conferidos em tela com o personagem real:

* terreno **mais alto atrás** → o corpo aparece inteiro, nada o corta;
* terreno **mais alto à frente** → as pernas são recortadas pela borda do
  degrau, que é o que comunica "estou um nível abaixo";
* **subindo um degrau** → a interpolação separa plano e altura, então o corpo
  sobe durante o passo em vez de saltar no fim, e a ordenação não pisca.

---

## 6. Limitações conhecidas / próximos passos

0. **A ordenação assume `max_height` menor que 16.** O viés de Y-Sort dos
   objetos é um quarto do tile (16 px) e precisa ser maior que o maior
   `y_sort_origin` de tile em uma célula. O padrão (`max_height = 14`) está
   dentro da folga, e há teste garantindo.
1. **Tiles de transição de bioma não estão ligados.** A pasta
   *Tile Transicao de Bioma* tem 4 conjuntos completos (12 peças cada). O dado
   necessário já existe em cada célula (`secondary_biome_id` e `biome_blend`);
   falta a camada de overlay no `ChunkView`. Está descrito no tutorial.
2. **Repetição da arte em manchas grandes.** Alguns tiles seus têm falhas de
   terra desenhadas no topo (`campo_ralo`, `campo_quase_ralo`, `florida`…).
   Quando uma mancha inteira usa a mesma variante, essas falhas se repetem numa
   grade perfeita. O `variation_cell_jitter` (padrão 0,14) já quebra a fronteira
   das manchas; subi-lo mistura variantes vizinhas célula a célula, ao custo de
   um campo mais "salpicado". Nenhuma arte foi alterada.
3. **`HeightVisibilityManager` vem desligado** (`enabled = false`): ligado, ele
   esconde montanhas acima do jogador. Ligue quando entrar em interiores/subsolo.
4. **Rios, estradas, cavernas e minérios** não foram implementados — a pipeline
   já tem o encaixe (basta um novo `WorldGenerationPass`).
5. A arte procedural dos 6 chãos novos é boa como base, mas não tem o carinho da
   sua pixel art. Substituir é trocar linhas do atlas.

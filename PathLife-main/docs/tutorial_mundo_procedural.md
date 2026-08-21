# Tutorial — Mexendo no mundo procedural do PathLife

Este documento é o "manual do operador". Ele responde três perguntas:
**como adicionar um bioma**, **como adicionar uma estrutura** e **como adicionar
uma mecânica nova** — sem tocar no núcleo.

> Regra de ouro do módulo: se você precisou editar um arquivo dentro de
> `world_generation/core/`, `chunks/` ou `rendering/` para adicionar
> **conteúdo**, provavelmente existe um caminho melhor. Conteúdo entra como
> `.tres` + `.tscn`. Comportamento novo entra como um passe novo.

---

## 0. Onde está cada coisa

```text
res://
├── assets/world/            arte (atlas de chão, árvores, piso de madeira)
├── data/world/              TODOS os .tres de configuração
│   ├── world_settings.tres      ← comece por aqui
│   ├── world_generator.tres     ← a pipeline (lista de passes)
│   ├── world_sampler.tres       ← clima + bioma + relevo
│   ├── biomes/  terrains/  decorations/  structures/  passes/  noise/
│   └── tiles/ground_tileset.tres + ground_catalog.tres
├── presentation/world/      cenas visuais (árvores, estruturas)
├── scenes/world/            procedural_world.tscn e world_demo.tscn
├── world_generation/        os scripts
└── tools/build_world_resources.gd   recria os .tres do zero
```

**Para ver o mundo agora:** abra `res://scenes/world/world_demo.tscn` e aperte
**F6**. WASD anda, Shift corre. O canto superior esquerdo mostra célula, altura,
bioma, relevo e quantos chunks estão carregados.

---

## 1. Os 8 botões que você vai mexer primeiro

Abra `res://data/world/world_settings.tres` no Inspector.

| Propriedade | O que muda |
|---|---|
| `world_seed` | A semente. `0` = mundo aleatório a cada partida. |
| `chunk_size` | Células por chunk (padrão 16). Maior = menos chunks, cada um mais caro. |
| `render_distance` | Raio de chunks carregados (padrão 2 → 5×5). |
| `height_pixels` | **Não mexa sem trocar a arte.** 26 px = altura da saia do bloco. |
| `min_height` / `max_height` | Amplitude vertical do mundo. |
| `sea_level` | Altura da lâmina d'água. |
| `max_parallel_generations` | Chunks gerados em paralelo. |
| `use_worker_threads` | Desligue para depurar a geração na main thread. |

Para relevo mais dramático ou mais manso, abra
`res://data/world/height_generator.tres` e mexa em:

* `contrast` (padrão 3.2) — o botão mais eficaz. Mais alto = montanhas e vales
  mais extremos;
* `continent_scale` / `elevation_scale` / `mountain_scale` — tamanho das formas;
* `continent_weight` / `elevation_weight` / `mountain_weight` / `detail_weight`;
* `mountain_sharpness` — quanto maior, picos mais raros e afiados.

E em `res://data/world/climate_generator.tres`:

* `biome_scale` (padrão 420) — **tamanho dos biomas** em células;
* `contrast` (padrão 2.3) — sem ele os climas ficam presos perto de 0.5 e
  deserto/neve/montanha nunca aparecem.

---

## 2. Adicionar um bioma novo

Exemplo: um bioma **"cerrado"**, quente e semiárido.

### Passo 1 — arte do chão (se for um chão novo)

O atlas `res://assets/world/tiles/ground_atlas.png` é uma grade de células
**128×106**: 3 colunas (os frames da animação) × N linhas (os tipos de chão).
Hoje são 21 linhas: **0–15 = as 16 variantes de grama que você forneceu**
(animadas, 3 frames) e **16–20 = o bloco de terra de cada bioma** (estático,
usado nas paredes).

O caminho mais fácil é usar o gerador, que já sabe fazer o par grama + terra:

1. coloque os 3 frames da grama nova em uma pasta;
2. em `tools/gen_ground_atlas.py`, acrescente a variante na lista `BIOMES` (o
   ÚLTIMO item de cada bioma é o que gera o bloco de terra dele);
3. rode `python3 gen_tiles.py` — ele redesenha o atlas com a grama animada e
   deriva o bloco de terra correspondente (lateral copiada do seu tile, face de
   cima pintada com a paleta de terra dele);
4. em `tools/build_world_resources.gd`, acrescente os dois ids em
   `GROUND_ROWS` (grama antes, terra depois) e ajuste `ANIMATED_ROWS`;
5. rode a ferramenta de recursos.

Prefere fazer na mão? Desenhe a linha nova no atlas, registre o tile em
`ground_tileset.tres` (**Animation Columns = 3** e **3 frames** só se for
animado; **Texture Origin = (0, −5 + nível × 26)** em cada alternativa de
altura) e adicione um `GroundTileEntry` em `ground_catalog.tres`.

Se o bioma reaproveitar um chão existente, pule este passo inteiro.

### Passo 2 — o `.tres` do bioma

`Botão direito em data/world/biomes/ → New Resource → BiomeDefinition`,
salve como `cerrado.tres` e preencha:

| Campo | Valor de exemplo | Observação |
|---|---|---|
| `id` | `cerrado` | Único. É por ele que tudo se refere ao bioma. |
| `temperature_min/max` | 0.62 / 0.88 | 0 = gelado, 1 = escaldante. |
| `humidity_min/max` | 0.18 / 0.42 | 0 = seco, 1 = encharcado. |
| `continentalness_min/max` | 0.34 / 1.0 | Abaixo de ~0.24 é oceano. |
| `transition_width` | 0.12 | Largura da mistura com os vizinhos. |
| `weight` | 1.0 | Suba para o bioma "ganhar" as disputas. |
| `ground_id` | `cerrado` | Precisa existir no `TileCatalog`. |
| `wall_id` | `cerrado_terra` | **Bloco de terra do próprio bioma.** É ele que aparece nos desníveis; sem um par correto a grama parece flutuar. |
| `underwater_ground_id` | `cerrado_terra` | Fundo quando submerso. |
| `height_bias` | 0.5 | Desloca o relevo em níveis. |
| `height_amplitude` | 0.9 | Multiplica a amplitude local. |
| `decorations` | `[baoba.tres, ipe.tres]` | Vegetação. |
| `structure_pool` | `[]` | Estruturas permitidas aqui. |

### Passo 3 — registrar

Abra `res://data/world/biome_resolver.tres` e arraste `cerrado.tres` para o
array `biomes`. **Pronto. Nenhuma linha de código.**

### Como o resolver escolhe

Cada bioma recebe uma nota:

```
nota = faixa(temperatura) × faixa(umidade) × faixa(continentalidade) × weight
```

`faixa()` vale 1.0 dentro do intervalo e cai suavemente até 0 ao longo de
`transition_width`. O bioma de maior nota vence; o segundo colocado é guardado
em `secondary_biome_id` com o peso em `biome_blend` — é isso que permite
transições graduais e que a vegetação rareie perto da fronteira
(`DecorationDefinition.max_biome_blend`).

### Conferindo

Rode `godot --headless --path . --script res://tests/world_generation_test.gd`.
O teste "biomas alcançáveis" varre o espaço climático inteiro e diz quantos
biomas realmente aparecem. Se o seu não aparecer, as faixas estão fora do
alcance do ruído — aumente `climate_generator.contrast` ou alargue o intervalo.

### Biomas que já existem

Um por pasta de bioma da arte: `campo_claro`, `campo`, `floresta`,
`campo_florido` e `savana`. Cada um aponta para o seu bloco de terra (`*_terra`)
em `wall_id` e tem a sua lista de variantes.

### Variantes de grama (o que dá vida ao bioma)

Um bioma não usa um tile só. `BiomeDefinition.ground_variants` é uma lista de
`GroundVariant` (`ground_id` + `weight`), e cada célula sorteia uma delas.

* o sorteio usa um ruído próprio — `WorldSampler.variation_noise` — então as
  variantes aparecem em **manchas contíguas**, não em chuvisco;
* `variation_scale` (padrão 26) controla o tamanho das manchas;
  `variation_detail_scale` e `variation_detail_weight` esfarelam as bordas;
* `weight` é a fatia de área de cada variante;
* **a ordem do array importa**: ele é percorrido conforme o ruído sobe, então
  variantes vizinhas na lista viram manchas vizinhas no mapa. A ferramenta já
  entrega o array na ordem certa — encadeado da mais escura/densa para a mais
  clara/rala — e com as **variantes de transição** entre cada par, para o campo
  não pular de um tom para outro. Ver 5.8.1.

Para acrescentar uma variante: solte a pasta com `frame_1/2/3.png` junto das
outras, acrescente a linha na tabela `BIOMES` de `tools/gen_ground_atlas.py` e
rode as ferramentas. As transições para as vizinhas saem sozinhas, e o
`build_world_resources.gd` lê tudo do manifesto — nada de editar lista na mão.

Os `.tres` das variantes ficam em `res://data/world/variants/`.

### Encostas com solo exposto

`TerrainDefinition` tem `expose_biome_wall`. Ligado, o relevo daquele tipo passa
a mostrar o **bloco de terra do próprio bioma** no lugar da grama — encostas de
terra batida sem precisar de tile novo. Vem desligado em `montanha.tres` e
`penhasco.tres`; ligue se quiser esse visual.

### Ligar a água

A água vem desligada porque não há arte de água. Para ligar: desenhe o tile,
catalogue-o, aponte `WorldSettings.water_ground_id` para ele, suba `sea_level`
e marque `enabled` no passe `06_water.tres`.

---

## 3. Adicionar uma estrutura (casa, loja, hospital…)

Estrutura = **uma cena normal do Godot** + **um `.tres` de regras**.

### Passo 1 — desenhe a cena

`res://presentation/world/structures/minha_casa.tscn`

```text
MinhaCasa            (Node2D, script structure_root.gd, Y-Sort ligado)
├── Piso             (Node2D, Y-Sort)
│   └── Sprite2D...  (ou uma TileMapLayer com o TileSet da casa)
├── Paredes
├── Mobilia
└── Marcadores
    ├── EntranceMarker   (Marker2D + structure_marker.gd, tipo ENTRANCE)
    ├── RoadMarker       (tipo ROAD)
    └── NPCSpawnMarker   (tipo NPC_SPAWN)
```

Use `res://presentation/world/structures/deck_madeira.tscn` como ponto de
partida — ele já tem a estrutura acima.

Dicas de posicionamento: a origem da cena é o **centro da face superior da
célula (0,0) do footprint**. A célula `(i, j)` fica em
`Vector2((i - j) * 64, (i + j) * 32)` relativa a essa origem.

No Inspector da raiz, ligue `draw_footprint_gizmo` e ajuste `footprint_preview`
para o tamanho em células: o editor desenha o losango do footprint para você
alinhar paredes e móveis.

### Passo 2 — o `.tres` de regras

`New Resource → StructureDefinition`, salve em `data/world/structures/`:

| Grupo | Campo | Para que serve |
|---|---|---|
| — | `scene` | A `.tscn` acima. |
| Footprint | `footprint` | Área em células (ex.: `Vector2i(6, 5)`). |
| | `adaptation_margin` | Quantas células ao redor o terreno mistura (5–8 fica natural). |
| Spawn | `spawn_chance` | Probabilidade por tentativa da região. |
| | `spawn_weight` | Peso na disputa contra outras estruturas do bioma. |
| | `minimum_spacing` | Distância mínima até outra estrutura, em células. |
| | `allowed_biomes` | Vazio = qualquer bioma. |
| | `allowed_terrains` | Vazio = qualquer relevo. Ex.: `[plano, colina]`. |
| | `min/max_world_height` | Faixa de altitude. |
| | `max_slope` | Desnível máximo tolerado no footprint antes de desistir do local. |
| | `allow_on_water` | Permite fundação abaixo do nível do mar. |
| Terreno | `adaptation_mode` | `FLATTEN`, `PLATEAU`, `EMBED`, `CARVE`, `WATER_EDGE` ou `NONE`. |
| | `preferred_foundation_offset` | Sobe/desce a fundação em níveis (ex.: `-1` para um porão). |
| | `footprint_blocks_movement` | Marque se a própria cena controla a passagem. |

### Passo 3 — registrar

Duas opções:

* arraste o `.tres` para `structure_pool` de um ou mais biomas; **ou**
* arraste para `global_pool` em `res://data/world/structure_planner.tres` (aí
  `allowed_biomes` decide onde pode nascer).

Ajuste `attempts_per_region` no planejador para densificar ou rarear as
construções. Uma região é `generation_region_size_chunks²` chunks (padrão 4×4).

### O que acontece por baixo

1. `StructurePlanner` sorteia posições **por região**, não por chunk — por isso
   duas chunks vizinhas nunca brigam pelo mesmo lugar.
2. A fundação é a **mediana** das alturas do footprint (um pico isolado não
   distorce), mais `preferred_foundation_offset`.
3. `TerrainAdapter` achata o footprint e mistura a borda com `smoothstep`.
4. Só o chunk que contém a origem do footprint instancia a cena — uma casa pode
   atravessar 4 chunks sem duplicar.
5. Células do footprint ficam com `terrain_locked = true`: água, vegetação e
   relevo não mexem mais nelas.

### Usando os marcadores depois

```gdscript
var root := chunk_view.add_structure(placement) as StructureRoot
for marker in root.markers_of_type(StructureMarker.MarkerType.NPC_SPAWN):
    spawn_morador(marker.global_position)
```

---

## 4. Adicionar vegetação / objetos espalhados

1. Crie a cena (`Node2D` + `Sprite2D`, com `offset` deixando a base do objeto na
   origem — veja `arvore_ipe.tscn`: `centered = false`, `offset = (−64, −198)`).
2. `New Resource → DecorationDefinition`:
   * `density` — chance por célula. `0.05` já é uma mata razoável.
   * `minimum_spacing` — evita objetos colados.
   * `max_slope` — não nasce em encosta íngreme.
   * `allowed_terrains`, `min/max_world_height`, `allow_on_water`.
   * `max_biome_blend` — só nasce onde o bioma é dominante (rarefaz na fronteira).
   * `random_flip_h`, `min_scale`, `max_scale` — variedade visual.
   * `blocks_movement` — se marcado, a célula deixa de ser caminhável.
3. Arraste para o array `decorations` de um bioma.

---

## 5. Adicionar uma mecânica nova

### 5.1 Um passe novo na pipeline (rios, estradas, minério, ruínas…)

Este é o encaixe oficial. Exemplo — um passe que espalha veios de minério:

```gdscript
## res://world_generation/passes/ore_pass.gd
class_name OrePass
extends WorldGenerationPass

@export var sampler: WorldSampler
@export var ore_ground_id: StringName = &"pedra"
@export_range(0.0, 1.0, 0.001) var chance: float = 0.004


func rebind_shared(shared: Dictionary) -> void:
    sampler = WorldGenerationPass.shared_clone(shared, sampler)


func prepare(settings: WorldSettings, world_seed: int) -> void:
    if sampler != null:
        sampler.prepare(settings, world_seed)


func run(context: GenerationContext) -> void:
    var ore_seed := WorldRandom.sub_seed(context.world_seed, &"ore")
    for local in context.each_local():
        var cell := context.cell(local)
        if cell.terrain_locked or cell.height > 2:
            continue
        if WorldRandom.value_01(ore_seed, cell.world_xy) < chance:
            cell.ground_id = ore_ground_id
```

Depois:

1. `New Resource → OrePass`, salve em `data/world/passes/08_ore.tres`, ligue o
   `sampler`.
2. Abra `data/world/world_generator.tres` e arraste o novo `.tres` para a
   posição desejada do array `passes`.

**Ordem importa.** A pipeline atual é: clima → bioma → relevo → estruturas
(+adaptação) → classificação de relevo → água → decoração. Um rio deve entrar
depois do relevo e antes da água; uma estrada, depois das estruturas (para
ligar os `RoadMarker`).

Três regras inegociáveis dentro de um `run()`:

* **nunca** toque na `SceneTree` (roda em worker thread);
* **sempre** use coordenada mundial no ruído (`cell.world_xy`), nunca local —
  senão o padrão reinicia a cada chunk;
* **sempre** derive aleatoriedade de `WorldRandom` + semente do mundo, para o
  chunk ser reproduzível.

Cada passe tem `enabled` no Inspector: desligue para isolar um problema sem
remover nada.

### 5.2 Mudar as regras de movimento

Tudo mora em `world_generation/navigation/movement_rules.gd` e no
`MovementContext` (`data/world/player_movement_context.tres`).

| Campo | Efeito |
|---|---|
| `max_step_up` | Subida automática. `2` faria o jogador subir 2 níveis. |
| `max_step_down` | Descida automática. |
| `max_safe_fall` | Acima disso, o destino é bloqueado em vez de virar queda. |
| `can_swim` | Permite entrar em células líquidas (retorna `SWIM`). |
| `can_climb` | Reservado para escaladas. |

Crie contextos diferentes por tipo de entidade: `npc_idoso.tres` com
`max_step_up = 0`, `cavalo.tres` com `max_step_up = 2`, e assim por diante.
Player, NPC e A* leem o mesmo lugar — a regra nunca duplica.

### 5.3 Fazer um NPC andar

```gdscript
# NPC = Node2D com um WorldGridAgent filho
@onready var agent: WorldGridAgent = $WorldGridAgent

func ir_ate(destino: Vector2i) -> void:
    var nav := WorldNavigation.new(agent.world(), agent.movement_context)
    var caminho := nav.find_path(agent.cell(), destino)
    for ponto in caminho:
        var direcao := Vector2i(ponto.x, ponto.y) - agent.cell()
        if direcao == Vector2i.ZERO:
            continue
        agent.request_step(direcao)
        await agent.step_finished
```

Sinais úteis do agente: `step_started(de, para, transicao)`,
`step_finished(posicao)`, `height_changed(nivel)`, `step_blocked(direcao)`.

### 5.4 Reagir à queda, ao degrau, à água

```gdscript
agent.step_started.connect(func(de, para, transicao):
    match transicao:
        MovementRules.MovementTransition.FALL:
            player.damage((de.z - para.z) * 5)
        MovementRules.MovementTransition.STEP_UP:
            tocar_som_de_subida()
        MovementRules.MovementTransition.SWIM:
            entrar_no_modo_nado()
)
```

### 5.5 Alterar o mundo em tempo de jogo (cavar, construir, cortar árvore)

```gdscript
var patch := CellPatch.new()
patch.world_pos = Vector3i(x, y, 0)
patch.height_override = nova_altura
patch.ground_override = &"terra"
save_manager.patch_cell(patch)

# árvore cortada:
save_manager.remove_object(arvore.get_meta(&"object_id"))
```

O `WorldSaveManager` aplica os patches automaticamente sempre que o chunk é
regerado. O save guarda **semente + diferenças**, nunca o mundo inteiro.

### 5.6 Trocar a aparência do mundo inteiro

Edite `res://data/world/tiles/ground_catalog.tres`. Se você criar um TileSet
novo (outra escala, outro estilo), aponte `tile_set` e as `entries` para ele —
geração, IA, save e pathfinding não percebem a diferença.

---

## 5.7 Colocar uma entidade nova no mundo (NPC, animal, veículo)

A ordenação de profundidade exige uma estrutura de dois nós:

```text
MeuNpcAnchor   (Node2D, grupo "grid_sort_anchor", SEM Y-Sort)
└── MeuNpc     (CharacterBody2D / Node2D)
    ├── GroundShadow      (presentation/world/entity_shadow.tscn)
    ├── Visual
    └── WorldGridAgent
```

A âncora recebe a posição **plana** da célula (é a chave do Y-Sort) e o corpo
recebe só o deslocamento vertical da altura. Sem isso, uma entidade em cima de
um morro é ordenada como se estivesse mais ao fundo, e o terreno alto atrás dela
aparece desenhado por cima.

O `WorldGridAgent` acha a âncora sozinho se ela for o **pai direto** do corpo e
estiver no grupo `grid_sort_anchor`. Dá para apontar explicitamente em
`sort_anchor_path`. Sem âncora nenhuma o componente ainda funciona, mas a
ordenação fica aproximada.

### Alinhando a arte da entidade

O mundo coloca a origem da entidade no **centro da célula**. Se a arte tiver a
origem em outro ponto (o rig do jogador, por exemplo, tem a origem no tornozelo
e os pés 10 px abaixo dela), a sombra precisa compensar.

Como medir a sua arte: renderize o visual isolado com a origem no centro da tela
e leia o contorno em pixels. Do jogador saiu: altura 81 px, largura 28 px, topo
−70, **base +10**. Esse `+10` é exatamente o `position.y` de
`entity_shadow.tscn`.

Para uma entidade nova, ajuste na cena:

* `GroundShadow.position.y` = distância da origem até a sola;
* o tamanho da elipse em `tools/gen_entity_shadow.py` (hoje 34×18, um pouco mais
  larga que os 28 px do jogador).

Prefere a sola exatamente no centro do losango? Suba o nó visual em −10 px e
zere a posição da sombra.

---

## 5.8 Ajustar a leitura de altura

Em `res://data/world/world_settings.tres`, grupo **Leitura de altura**:

| Campo | Efeito |
|---|---|
| `height_shading_enabled` | Liga/desliga o sombreamento por nível. |
| `height_shading_step_below` | Quanto CADA nível abaixo escurece (padrão **0.22**). |
| `height_shading_step_above` | Quanto CADA nível acima é atenuado (padrão **0.14**). |
| `height_shading_min` | Piso do multiplicador, para o fundo não virar preto. |
| `height_shading_coolness` | Quanto a sombra de baixo puxa para o azul. |
| `height_shading_reference` | Nível neutro usado quando ninguém informa outro. |

O nível do jogador fica com a **cor original** (multiplicador 1.0, sem
alteração nenhuma). Só os outros níveis são sombreados.

Em jogo, o `HeightVisibilityManager` passa o **nível do jogador** como
referência (`relative_height_shading`), então o contraste está sempre onde
importa. Desligue essa opção se preferir sombreamento fixo por altitude.

O mesmo nó tem o corte de níveis acima do jogador (`enabled`), útil para
interiores e subsolo — vem desligado porque, ligado, ele apaga montanhas.

> Esse contraste não é enfeite: em vista isométrica só aparecem as faces que
> apontam para a câmera (+X e +Y). Um degrau que sobe para o fundo não tem face
> nenhuma para desenhar — quem conta que ele existe é o tom do patamar. Com o
> passo baixo demais, o mundo vira um tapete verde com riscos de terra soltos.

---

## 5.8.1 Ajustar a suavização entre variantes de um bioma

Cada bioma é uma **escala**: as artes que você desenhou, encadeadas da mais
escura/densa para a mais clara/rala, com variantes de transição preenchendo os
saltos. Quem monta isso é `tools/gen_ground_atlas.py`, no topo do arquivo:

| Constante | Efeito |
|---|---|
| `BLEND_TARGET_DISTANCE` (4.5) | Salto "aceitável" entre vizinhas. **Menor = mais transições = campo mais macio.** |
| `BLEND_MAX_PER_PAIR` (4) | Teto de transições por par, para o atlas não crescer sem fim. |
| `WEIGHT_BLEND_FACTOR` (0.30) | Quanto a transição aparece, como fração do menor peso do par. Suba para manchas de transição maiores. |

E na tabela `BIOMES`, o terceiro campo de cada variante é o **peso no sorteio** —
quanto daquela cara o bioma tem. As de solo exposto (`campo_ralo`,
`campo_quase_ralo`) estão baixas de propósito: a falha de terra desenhada no topo
se repete a cada tile e, em mancha grande, chama mais atenção que a grama.

Depois de mexer, rode as duas ferramentas na ordem:

```bash
python3 tools/gen_ground_atlas.py          # atlas + manifesto
godot --headless --path . --script res://tools/build_world_resources.gd
godot --headless --path . --import         # o Godot precisa reimportar o PNG
```

> A ferramenta grava `assets/world/tiles/ground_atlas.json`, e é dele que o
> `build_world_resources.gd` tira as linhas do atlas e as variantes de cada
> bioma. Você não precisa editar lista nenhuma na mão.

**Para acrescentar uma arte nova de grama**: ponha a pasta com `frame_1/2/3.png`
onde estão as outras, acrescente a linha em `BIOMES` (id, caminho, peso) e rode
os três comandos. As transições para as vizinhas saem sozinhas.

**Se o campo ficar com cara de azulejo**: o topo já é espelhado em metade das
células (`TileCatalog.mirror_variation`). Se você desligar isso, qualquer detalhe
desenhado no topo volta a se repetir numa grade perfeita.

---

## 5.9 Ajustar os patamares do relevo

Em `res://data/world/world_sampler.tres`, grupo **Patamares**:

| Campo | Efeito |
|---|---|
| `plateau_filter_enabled` | Liga o filtro de mediana da altura (padrão ligado). |
| `plateau_filter_radius` | Vizinhança da mediana (padrão 2 → 5×5). |
| `plateau_filter_passes` | Passadas (padrão 2). |
| `height_cache_limit` | Teto do cache de níveis por thread. |

**Por que existe:** o ruído bruto produz degraus de uma célula só, soltos no
meio do campo. Um degrau desses não vira penhasco — vira um risco de terra de
26 px cercado de grama, e é isso que dá a impressão de "tile recortado". A
mediana apaga pico e cova de uma célula e **preserva bordas longas**, então os
penhascos continuam existindo, só que contínuos.

Quer relevo mais quebrado e selvagem? Baixe para `radius = 1, passes = 1` ou
desligue. Quer platôs ainda maiores? Suba `passes` para 3 — cada passada custa
tempo de geração (medido: 6 ms/chunk sem filtro, 29 ms com o padrão).

Se preferir mexer no ruído em vez do filtro, `height_generator.tres` →
`detail_weight` e `detail_scale` são os que mais geram degrau curto.

---

## 5.10 Pôr um objeto autorado à mão em cima do relevo

Camas, placas, cercas — qualquer `Node2D` que você posiciona na mão. Se ele for
solto direto na cena, é ordenado pela **posição visual**, e num mundo com
relevo isso está errado: quem decide profundidade é a **célula**. O objeto
acaba coberto pela grama que deveria estar atrás dele.

1. Instancie `res://world_generation/agents/world_object_anchor.tscn` dentro de
   `World/DepthSort/Entities`.
2. Ponha o objeto como **filho** da âncora (posição local `(0, 0)`).
3. Arraste a âncora para onde quiser — é só isso.

| Propriedade da âncora | Para quê |
|---|---|
| `derive_cell_from_position` | Ligado (padrão): a célula sai da posição em que você largou a âncora. |
| `world_cell` | Célula exata, quando você desliga o item acima. |
| `follow_terrain` | Ligado (padrão): a altura vem do relevo gerado sob a célula. |
| `height_level` | Altura fixa, para plataformas e pontes. |

O `ProceduralWorld` chama `snap_world_objects()` assim que o terreno existe e
assenta tudo que estiver no grupo `world_object_anchor`. Se você criar o objeto
em tempo de jogo depois disso, chame `anchor.snap_to_world(world_data, settings)`
você mesmo.

---

## 5.11 Trocar ou animar a arte de uma árvore

As seis árvores usam os 48 quadros de queda de folha que vieram na pasta
*arvores*, a 9,09 fps (a cadência do GIF original).

Para **trocar a arte** de uma espécie: substitua os `frames/queda_01..48.png` na
pasta de origem e rode:

```bash
python3 tools/gen_tree_atlases.py
godot --headless --path . --script res://tools/build_world_resources.gd
godot --headless --path . --import
```

Para **acrescentar uma espécie**: crie a pasta com os quadros, some o id à lista
`TREES` em `tools/gen_tree_atlases.py`, copie uma cena `arvore_*.tscn` apontando
para o novo `SpriteFrames`, e registre a decoração como sempre (seção 4).

| Onde | O quê |
|---|---|
| `tools/gen_tree_atlases.py` → `FRAME_MILLISECONDS` | Cadência da animação (110 ms = 9,09 fps). |
| `tools/gen_tree_atlases.py` → `COLUMNS` | Colunas da grade do atlas. |
| `presentation/world/vegetation/arvore_*_frames.tres` | Velocidade e loop, editáveis no Inspector. |
| `VegetationAnimation.speed_jitter` (0.12) | Quanto a velocidade varia entre indivíduos. |

> **Se a floresta inteira soltar folha junta**, o `sprite` da cena não está
> ligado ao `VegetationAnimation` (é ele que sorteia o quadro inicial a partir
> da posição). Se a árvore "pular" quando o chunk recarrega, alguém trocou esse
> sorteio por `randi()`.

---

## 6. Ligar os tiles de transição de bioma (tarefa pendente)

Você tem 4 conjuntos prontos em *Isometric Tiles/Tile Transicao de Bioma*
(`campo_para_musgo`, `campo_para_savana`, `campo_para_terra`,
`savana_para_terra`), cada um com 12 peças (`ponta_*`, `aresta_*`, `uniao_*`).

O dado necessário **já existe**: cada célula guarda `secondary_biome_id` e
`biome_blend`. O caminho:

1. Monte um segundo atlas com as 12 peças de cada par e registre-as no
   `TileSet`.
2. Crie um `BiomeTransitionCatalog` (`.tres`) mapeando
   `(bioma_a, bioma_b, máscara_de_vizinhos) → tile`.
3. No `ChunkView`, adicione uma camada de overlay por nível (uma segunda
   `height_layer.tscn`) e, para cada célula com `biome_blend > limiar`, calcule
   a máscara dos 4 vizinhos e pinte a peça correspondente.

> **Não use `z_index` para pôr o overlay na frente do chão.** No Godot o
> Z-Index é resolvido ANTES do Y-Sort: a camada sairia do espaço de ordenação e
> passaria a ser desenhada por cima de tudo, inclusive do jogador — é
> exatamente o bug do "tile recortado". Mantenha `z_index = 0` e
> `y_sort_enabled = true`, e dê ao tile de overlay um `y_sort_origin` um pouco
> maior que o da superfície (que é 0) e menor que o das faces (31).

Nada disso exige mexer em geração, dados ou regras — é puramente renderização.

---

## 7. Checklist rápido de diagnóstico

| Sintoma | Causa provável |
|---|---|
| Mundo todo plano | `height_generator.contrast` muito baixo, ou o passe não recebeu `prepare` (o `sampler` está vazio no `.tres`?). |
| Um bioma nunca aparece | Faixas climáticas fora do alcance do ruído. Suba `climate_generator.contrast` ou alargue o intervalo. |
| Uma variante de grama nunca aparece | `weight` zerado, ou a variante não está catalogada no `ground_catalog.tres`. |
| Salto forte de tom entre duas manchas vizinhas | Faltam transições: baixe `BLEND_TARGET_DISTANCE` (ver 5.8.1) e regere o atlas. |
| Campo com cara de azulejo, detalhe repetindo em grade | `TileCatalog.mirror_variation` desligado. |
| Tile de transição com efeito de tela de mosquiteiro | Alguém trocou o grão fino da máscara por Bayer puro em `gen_ground_atlas.py`. |
| Atlas e TileSet fora de sincronia | Rodou `gen_ground_atlas.py` sem rodar `build_world_resources.gd` (e o `--import`) depois. |
| Variantes viram chuvisco em vez de manchas | `variation_scale` baixo demais, ou `variation_detail_weight` alto demais. |
| Chão desalinhado da grade | `texture_origin` da alternativa ≠ `(0, −5 + nível × 26)`, ou `tile_size` ≠ `(128, 64)`. |
| Terreno alto ATRÁS cobrindo o jogador | Alguma camada com `z_index` por altura, ou entidade sem âncora de ordenação. |
| **Lascas de terra furando a grama ("tile recortado")** | Alguma classe de camada saiu do `z_index = 0` ou perdeu o `y_sort_enabled`. No Godot o Z-Index é resolvido ANTES do Y-Sort: basta um Z diferente para aquela classe passar a ser desenhada sempre por cima. Rode `tests/terrain_depth_composition_test.gd`: ele mede e aponta. |
| **Pernas do personagem piscando ao andar** | `IsoCoordinateSystem.prop_sort_bias()` diferente de um quarto do tile. A chave do tile é o CENTRO do losango; com viés menor a troca de profundidade escorrega para o fim do passo e o ator anda atrás da grama de destino. Rode `tests/character_walk_flicker_test.gd`. |
| Vontade de dar um `z_index` próprio ao piso "para ele não engolir as pernas" | Já foi medido: com piso e faces no mesmo Z o personagem fica com **exatamente os mesmos** pixels visíveis. O que muda é o terreno, que se recorta. O `ProceduralWorld` devolve o Z para zero e avisa no console. |
| Riscos de terra soltos, sem penhasco contínuo | `plateau_filter_enabled` desligado (ver 5.9). |
| Mobília/objeto coberto pela grama de trás | Objeto solto na cena, sem `WorldObjectAnchor` (ver 5.10). |
| Mundo "de cabeça para baixo" | Sinal do `texture_origin` invertido. Ele é SUBTRAÍDO ao desenhar: para o bloco subir, o valor é positivo. |
| Não dá para ver quem está acima/abaixo | `height_shading_step` baixo demais, ou `relative_height_shading` desligado. |
| Fresta ou sobreposição entre níveis | `WorldSettings.height_pixels` ≠ altura da saia da sua arte (26 px). |
| Costura visível entre chunks | Algum passe usando coordenada local no ruído em vez de `cell.world_xy`. |
| Estrutura duplicada | Alguém instanciando fora do chunk que contém a origem do footprint. |
| Travamento ou mundo errado com threads | Recurso com estado compartilhado entre threads. Implemente `clone_for_thread()` nele. |
| Nada aparece na tela | `catalog` ou `chunk_view_scene` vazios no `ChunkManager`; ou o `focus` não foi ligado. |
| Árvores paradas | `SpriteFrames` sem loop, ou `autoplay` vazio na cena. |
| Floresta inteira soltando folha junta | `sprite` não ligado no `VegetationAnimation` (ver 5.11). |

---

## 8. Comandos úteis

```bash
# montar os atlas de arte (chão e árvores) + os manifestos
python3 tools/gen_ground_atlas.py
python3 tools/gen_tree_atlases.py

# recriar todos os .tres do mundo do zero
godot --headless --path . --script res://tools/build_world_resources.gd

# testes de lógica (96 verificações)
godot --headless --path . --script res://tests/world_generation_test.gd

# testes de integração com SceneTree (32 verificações)
godot --headless --path . --script res://tests/player_grid_integration_test.gd

# regressão visual: 512 passos pelo mundo + contact sheet (precisa de vídeo)
godot --path . --resolution 640x360 --script res://tests/world_roaming_visual_test.gd

# mede por que piso e faces ficam no mesmo Z (precisa de vídeo)
godot --path . --resolution 400x300 --script res://tests/terrain_depth_composition_test.gd

# mede a cintilação das pernas num passo (precisa de vídeo)
godot --path . --resolution 320x240 --script res://tests/character_walk_flicker_test.gd

# print da oclusão do personagem contra um penhasco
godot --path . --resolution 640x360 --script res://tests/world_depth_preview.gd
```

Rode os dois testes depois de qualquer mudança grande de configuração: eles
pegam mundo plano, bioma inalcançável, costura entre chunks, estrutura
duplicada e quebra de determinismo antes de você abrir o editor.

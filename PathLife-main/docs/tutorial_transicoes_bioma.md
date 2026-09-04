# Transições de bioma — a borda desenhada entre campo, floresta e savana

> **Estado: já aplicado no projeto.** As 48 peças estão no atlas, o catálogo e o
> renderer já as usam. Falta rodar os dois comandos da seção 8.

Até aqui, quando um bioma encostava no outro, a troca acontecia na fronteira de
uma célula: de um lado grama de campo, do outro musgo, com o losango inteiro
mudando de cor de uma vez. Este documento troca esse corte seco por peças
desenhadas à mão, em que o bioma vizinho invade a célula.

## 1. A arte

Quatro pares, 12 peças cada, em
`Isometric Tiles/Tiles Biomes/Tile Transicao de Bioma/`:

| Par | De | Para |
|---|---|---|
| `campo_para_musgo` | campo | floresta |
| `campo_para_savana` | campo | savana |
| `campo_para_terra` | campo | terra exposta |
| `savana_para_terra` | savana | terra exposta |

Cada peça é 128 × 106 px com 3 quadros de animação em
`spritesheets/<forma>_sheet.png` (384 × 106) — exatamente o formato das outras
artes de chão. Por isso elas entram no atlas sem nenhuma conversão: são linhas
como qualquer outra.

### A arte é direcional, e de um lado só

Cada peça mostra o bioma de **destino** invadindo a célula. Quem recebe o tile
misto é sempre a célula do bioma de **origem**; o vizinho continua puro.

Não existe `musgo_para_campo`, e isso não é uma falta: a borda é desenhada de um
lado só, e é assim que ela deve ser lida. Uma célula de floresta encostada no
campo não muda — quem muda é a célula de campo, que ganha musgo na metade
voltada para a floresta.

### Os 12 nomes, e o que cada um significa

O nome diz **onde fica o bioma de destino**. O losango isométrico tem quatro
lados (cada um compartilhado com um vizinho de grade) e quatro cantos (cada um
tocado por uma diagonal):

```text
                    ▲ trás
        tras_esq  ◤   ◥  tras_dir
     esq ◀                    ▶ dir
      frente_esq  ◣   ◢  frente_dir
                    ▼ frente
```

| Forma | Quando aparece | Quanto da célula vira o outro bioma |
|---|---|---|
| `aresta_<lado>` | um vizinho de lado é do outro bioma | metade |
| `uniao_<canto>` | os **dois** lados que se encontram naquele canto | três quartos |
| `ponta_<canto>` | nenhum lado, só a **diagonal** daquele canto | uma pontinha |

E a correspondência com a grade, que é a parte fácil de errar — ela segue a
mesma convenção que o `ChunkView` já usava para decidir qual lateral do bloco
desenhar (`+X` é a face da frente-direita, `+Y` a da frente-esquerda):

| Vizinho | Lado | Canto entre dois lados | Diagonal |
|---|---|---|---|
| `(-1, 0)` | `tras_esq` | `tras` = tras_esq + tras_dir | `(-1, -1)` |
| `(0, -1)` | `tras_dir` | `dir` = tras_dir + frente_dir | `(+1, -1)` |
| `(+1, 0)` | `frente_dir` | `frente` = frente_dir + frente_esq | `(+1, +1)` |
| `(0, +1)` | `frente_esq` | `esq` = frente_esq + tras_esq | `(-1, +1)` |

## 2. Os casos que a arte não cobre

Doze peças cobrem um lado, dois lados vizinhos e uma diagonal. Faltam três
configurações, e o catálogo cai na peça mais próxima em vez de devolver o corte
seco:

| Situação | O que é desenhado | O que sobra |
|---|---|---|
| dois lados **opostos** | a aresta do primeiro deles | o lado oposto fica no corte seco |
| três lados | a união do primeiro canto fechado | um lado fica no corte seco |
| quatro lados | a união do primeiro canto | nada — a célula estava cercada e some no meio dos vizinhos |

São casos raros: exigem que uma mancha de bioma tenha um istmo de uma célula ou
uma ilha de uma célula. Se algum dia incomodarem, a saída é arte nova
(`aresta_dupla`, `quase_cercado`), não código: basta acrescentar a forma na
lista e uma linha no `forma_por_lados`.

## 3. Onde cada peça entra no pipeline

O pipeline do mundo não mudou de forma; ganhou 48 linhas.

```text
tools/gen_ground_atlas.py
   └─ ground_atlas.png       97 linhas x 3 quadros   (eram 49)
      ground_top_atlas.png   superfícies
      depth_face_atlas.png   laterais
      ground_atlas.json      manifesto: quem é cada linha
            │
tools/build_world_resources.gd
   └─ ground_tileset.tres    TileSet com as 3 fontes
      ground_catalog.tres    id lógico -> tile   (+ marca de direcional)
      biome_transitions.tres grupos + pares com arte
            │
world_generation/rendering/chunk_view.gd
   └─ pergunta ao catálogo qual peça usar em cada célula
```

A ordem das linhas do atlas importa: tudo que anima precisa ocupar linhas
contíguas no começo (é o que `animated_rows` significa para o `TileSet`). Então
as transições entram **depois** das variantes de grama e **antes** dos blocos de
terra, que são estáticos. Ficou assim:

| Faixa | Conteúdo | Animado |
|---|---|---|
| 0–43 | variantes de grama dos 5 biomas, com as misturas geradas entre elas | sim |
| 44–91 | as 48 peças de transição | sim |
| 92–96 | os 5 blocos de terra | não |

## 4. Camada de dados

Dois recursos novos, em `world_generation/rendering/`.

### `BiomeTransitionRule` — uma fronteira com arte

```gdscript
@export var de_grupo: StringName = &"campo"
@export var para_grupo: StringName = &"floresta"
@export var prefixo: StringName = &"campo_para_musgo"
```

O id de cada peça é `<prefixo>_<forma>`, então
`campo_para_musgo_aresta_tras_esq` é uma linha do atlas e uma entrada do
`TileCatalog`.

### `BiomeTransitionCatalog` — quem usa qual arte

```gdscript
## Bioma -> grupo de transição.
@export var grupos: Dictionary[StringName, StringName] = {}
@export var rules: Array[BiomeTransitionRule] = []
## Desligue para voltar ao corte seco sem desfazer nada.
@export var enabled: bool = true
```

O **grupo** é o que faz a arte render mais do que os pares que ela nomeia. Campo,
campo claro e campo florido são todos do grupo `campo`, então
`campo_para_musgo` serve para as três fronteiras com a floresta. Quem não está
no mapa simplesmente não ganha transição — é assim que floresta ↔ savana
continua no corte seco enquanto não existir arte para ela.

Estado atual dos grupos (montados por `build_world_resources.gd`):

| Bioma | Grupo |
|---|---|
| `campo`, `campo_claro`, `campo_florido` | `campo` |
| `floresta` | `floresta` |
| `savana` | `savana` |

O método central é puro — recebe os grupos dos 8 vizinhos e devolve um id
lógico, sem conhecer célula, TileSet ou cena:

```gdscript
func resolve(
	grupo: StringName,
	lados: Array[StringName],
	diagonais: Array[StringName]
) -> StringName
```

Primeiro ele olha os **lados**: se dois vizinhos diferentes encostam na mesma
célula, ganha o que ocupa mais lados — é ele que domina a silhueta. Só quando
nenhum lado difere é que as diagonais entram, para a pontinha do canto não
ficar em degrau.

## 5. Camada de apresentação

Três mudanças pequenas, todas em cima do que já existia.

**`WorldData.biome_at()`** — o bioma de uma célula, com queda para o amostrador
global quando o chunk vizinho ainda não carregou. O amostrador é determinístico,
então a borda desenhada agora é a mesma que o chunk vizinho vai gerar quando
entrar. Sem isso, **toda fronteira de chunk viraria um corte seco**.

**`ChunkView._ground_visual_for()`** — reúne os 8 vizinhos e pergunta ao
catálogo. O resultado é **visual**: `cell.ground_id` continua sendo o dado, e é
ele que gameplay, IA, pathfinding e save enxergam. A peça de transição existe
só no `TileMapLayer`.

O mesmo id vai para a superfície e para a face do nível de cima, senão a lateral
do bloco mostraria grama pura embaixo de uma borda misturada.

**`GroundTileEntry.directional`** — as peças de transição nunca podem ser
espelhadas. O `TileCatalog` espelha metade das células para o campo não virar
azulejo; num `aresta_frente_dir`, o espelho trocaria esquerda por direita e
jogaria a borda para o lado errado da célula. A marca vem do manifesto
(`kind == "transicao_bioma"`) e o `ChunkView` a respeita:

```gdscript
var mirrored := not entry.directional and _mirrors_top(cell_coord)
```

### Custo

Cada célula consulta 8 vizinhos, e cada vizinho é consultado por até 8 células.
Um cache por `ChunkView` (`_group_cache`) desfaz essa repetição; sem ele, a
borda de um chunk chamaria o amostrador milhares de vezes por carregamento. Os
vizinhos internos ao chunk são busca em dicionário; só o anel externo cai no
amostrador — cerca de 70 chamadas por chunk.

## 6. Acrescentar um par novo

1. Coloque as 12 peças em
   `Tile Transicao de Bioma/<novo_par>/spritesheets/<forma>_sheet.png`.
2. Acrescente uma linha em `TRANSICOES`, em `tools/gen_ground_atlas.py`:

```python
TRANSICOES = [
    ('campo_para_musgo',  'campo',  'floresta'),
    ('campo_para_savana', 'campo',  'savana'),
    ('campo_para_terra',  'campo',  'terra'),
    ('savana_para_terra', 'savana', 'terra'),
    ('floresta_para_savana', 'floresta', 'savana'),   # <- novo
]
```

3. Se o par usa um grupo que ainda não existe, acrescente os biomas dele em
   `TRANSITION_GROUPS`, em `tools/build_world_resources.gd`.
4. Rode os comandos da seção 8.

Nenhuma linha de renderer muda. As peças viram linhas do atlas, entradas do
catálogo e regras do `BiomeTransitionCatalog` sozinhas.

## 7. Desligar

Abra `data/world/tiles/biome_transitions.tres` e desmarque `enabled`. O mundo
volta ao corte seco na hora, sem desfazer nada — a arte continua no atlas e o
catálogo continua montado.

## 8. Rodar

As duas transições **para terra** já estão no atlas e no catálogo, mas não
aparecem: elas precisam de uma célula de terra exposta ao lado, e hoje o mundo
não tem nenhuma (`expose_biome_wall` desligado nos terrenos, água desligada).
Ficam prontas para o dia em que existir.

```powershell
cd C:\Users\danil\Desktop\PathLife\PathLife-main
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/build_world_resources.gd
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
```

> **Atenção**: `build_world_resources.gd` recria **todos** os `.tres` de
> `data/world/`. Se você ajustou ruído, bioma ou passe pelo Inspector desde a
> última vez que o rodou, esses ajustes se perdem. Se estiver em dúvida, copie
> `data/world/` antes.

Depois:

```powershell
& '...Godot...exe' --headless --path . --script res://tests/biome_transition_test.gd
& '...Godot...exe' --headless --path . --script res://tests/world_generation_test.gd
```

O primeiro deve imprimir `BIOME_TRANSITION_OK`. Ele confere as 12 formas uma a
uma, os três casos sem arte, os 4 pares e as 48 peças no catálogo, e que todas
estão marcadas como direcionais.

## 9. Erros que vão acontecer

**"A borda aparece do lado errado da célula."**
Espelhamento. Confira que `entry.directional` está `true` para as peças de
transição — quem preenche isso é `_directional_rows()` lendo
`kind == "transicao_bioma"` do manifesto.

**"A fronteira funciona no meio do chunk e some na borda dele."**
`WorldData.biome_at()` não está caindo no amostrador. Confira que o `WorldData`
recebeu o `sampler` (`ChunkManager` passa os dois juntos).

**"Não aparece transição nenhuma."**
Em ordem: `biome_transitions.tres` existe? `enabled` está marcado? Os biomas da
fronteira estão em `grupos`? Existe uma regra para aquele par, **na direção
certa** (campo → floresta, não floresta → campo)?

**"O tile de transição some e volta a grama pura."**
`catalog.has(tile)` falhou — a peça não está no `TileCatalog`. Isso quer dizer
que o atlas foi regerado sem as transições ou que `build_world_resources.gd` não
rodou depois.

**"O mundo inteiro ficou com o tile errado."**
As linhas do atlas saíram de ordem. `animated_rows` precisa cobrir exatamente as
linhas animadas, e elas precisam ser as primeiras. Se você acrescentou uma
transição depois dos blocos de terra, é isso.

## 10. Checklist

- [ ] `ground_atlas.json` tem 97 linhas, 92 animadas e a seção `transicoes`.
- [ ] `biome_transitions.tres` existe com 4 regras e 5 biomas em `grupos`.
- [ ] As 48 peças aparecem no `TileCatalog` e estão marcadas como direcionais.
- [ ] Campo encostando em floresta mostra musgo invadindo a célula de campo.
- [ ] Campo encostando em savana mostra o mesmo, com a grama de savana.
- [ ] A célula de floresta/savana continua pura — a borda é de um lado só.
- [ ] Andar de um bioma ao outro não mostra costura na fronteira de chunk.
- [ ] `biome_transition_test.gd` imprime `BIOME_TRANSITION_OK`.
- [ ] `world_generation_test.gd` continua passando.

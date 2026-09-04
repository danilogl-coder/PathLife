# Sistema modular de visão do PathLife

Este documento descreve o sistema de percepção atualmente integrado ao mundo
procedural do PathLife. A implementação foi inspirada na separação usada por
jogos isométricos de sobrevivência: o campo de visão é uma regra lógica da
grade, enquanto fog, telhado e paredes são apenas apresentações desse
resultado.

O contrato de gameplay entregue é:

- o jogador enxerga um cone frontal e uma pequena área periférica em 360°;
- paredes, portas fechadas e janelas fechadas bloqueiam line-of-sight nos dois
  sentidos;
- uma janela aberta revela até cinco células depois da abertura;
- uma porta aberta revela até oito células depois da abertura;
- um raio atravessa no máximo um portal com o perfil padrão;
- dentro de uma estrutura selada, o exterior fica totalmente oculto, inclusive
  se já tiver sido explorado;
- ao abrir uma janela ou porta, a visão pode atravessar o portal tanto de fora
  para dentro quanto de dentro para fora;
- percepção, iluminação, física e IA permanecem sistemas independentes.

O recurso ativo por padrão está em:

```text
res://data/vision/default_vision_profile.tres
```

---

## 1. Arquitetura

O sistema é dividido em três camadas e uma integração de runtime:

| Camada | Responsabilidade | Arquivos principais |
| --- | --- | --- |
| Domínio | Estados, perfil, LOS, memória e coordenação | `gameplay/vision/` |
| Topologia | Extrair e indexar pisos, bordas, portais e zonas | `world_generation/visibility/` |
| Apresentação | Fog, máscara, telhado, paredes e entidades | `presentation/world/visibility/` |
| Integração | Player, streaming, estrutura e save | `player_controller.gd`, `chunk_manager.gd`, `structure_root.gd`, `world_save_manager.gd` |

Fluxo completo:

```text
TileMapLayer Piso + TileMapLayer Paredes
                    │
                    ▼
        StructureVisionBaker
                    │  StructureVisionSnapshot
                    ▼
        VisionTopologyRegistry ◄──── streaming de chunks
                    │
player/portal ──► VisionSystem ──► VisionSolver
                    │                  │
                    │                  └─ VisionResult
                    ▼
          VisibilityPresenter
             ├─ fog global RGB
             ├─ máscara local de telhado
             ├─ cutaway automático de paredes
             └─ visibilidade de entidades dinâmicas
```

### Princípio de dependência

`VisionSolver` é puro: não acessa `SceneTree`, `TileMapLayer`, colisão, câmera,
shader ou save. Ele recebe somente coordenadas, um `VisionProfile`, um
`VisionTopologyRegistry` e a memória relevante. Isso permite testar as regras
em headless e adicionar renderizações diferentes sem alterar o gameplay.

`StructureVisionBaker` também não usa colisão ou arte para decidir LOS. Ele lê
somente os dados semânticos das camadas autoradas.

---

## 2. Estados de visão

Toda posição lógica usa `Vector3i`; `z` representa o nível. Os estados ficam em
`VisionState`:

```gdscript
UNKNOWN = 0
REMEMBERED = 1
FORCED_HIDDEN = 2
VISIBLE = 3
```

A prioridade de composição é:

```text
VISIBLE > FORCED_HIDDEN > REMEMBERED > UNKNOWN
```

- `UNKNOWN`: nunca observado; recebe o fog mais escuro.
- `REMEMBERED`: cenário já observado, mas fora do campo de visão atual.
- `FORCED_HIDDEN`: informação que deve ser ocultada por uma estrutura selada.
  Esse estado não apaga a memória; apenas a sobrepõe enquanto o bloqueio existe.
- `VISIBLE`: percepção atual. Sempre vence qualquer outro estado.

`VisionResult` expõe, além de `states`, os índices `visible_cells`,
`remembered_cells`, `forced_hidden_cells`, `explored_cells`,
`visible_interior_by_structure`, `traversed_portal_ids`,
`observer_placement_id`, `observer_zone_id` e `observer_zone_cells`. Esses
índices alimentam o recorte local de telhado e limitam a arte automática das
paredes ao cômodo atual.

---

## 3. Como o cálculo funciona

### Cone e periferia

O solver enumera as células dentro de `maximum_range_cells`. Uma célula entra
como candidata quando está no cone definido por `front_cone_degrees` ou dentro
do raio periférico `peripheral_range_cells`. A célula do observador é sempre
visível.

A orientação é um vetor lógico cardinal da grade isométrica:

```text
ne = ( 0, -1)
nw = (-1,  0)
se = ( 1,  0)
sw = ( 0,  1)
```

### Line-of-sight por bordas

Cada raio usa um percurso supercover entre a origem e o alvo. O solver testa
as bordas cruzadas, e não a colisão física da cena. Em um cruzamento exato de
canto, os quatro segmentos incidentes ao vértice (dois de saída e dois de
entrada) são verificados; qualquer contribuição opaca bloqueia o raio. Isso
evita vazamento diagonal mesmo quando o L de paredes foi autorado pelo lado da
célula-alvo.

Bordas sobrepostas são conservadoras: se uma estrutura contribui com um portal
e outra com uma parede opaca ou portal que não transmite na mesma posição, a
contribuição mais restritiva vence tanto no raycast quanto no grafo de zonas.

### Portais

Um portal fechado encerra o raio. Um portal aberto permite continuar até sua
profundidade configurada e incrementa a quantidade de saltos do raio. O mesmo
algoritmo vale nos dois sentidos da borda, portanto abrir uma janela permite
olhar para dentro da casa a partir do exterior e olhar para fora a partir do
interior.

Com o perfil padrão:

```text
janela aberta: 5 células depois da abertura
porta aberta:   8 células depois da abertura
saltos:         1 portal por raio
```

Duas janelas alinhadas não revelam através da construção inteira porque o
segundo portal ultrapassa `maximum_portal_hops`.

### Estruturas seladas

O baker separa o piso em zonas conexas, e cada portal conecta as duas zonas
adjacentes ou uma zona ao exterior. Quando o jogador está numa zona interna,
o registro percorre esse grafo usando apenas portais que transmitem visão.

Se não existir caminho até o exterior e
`sealed_structure_blocks_memory = true`, o solver:

1. mantém somente os candidatos internos da estrutura;
2. transforma memória exterior relevante em `FORCED_HIDDEN`;
3. marca a faixa externa adjacente como `FORCED_HIDDEN`, impedindo que a
   suavização visual atravesse a parede.

Abrir uma porta ou janela que conecte a zona ao exterior remove essa condição
no próximo cálculo. A visibilidade ainda respeita cone, paredes, profundidade e
limite de portais.

### Cache e custo

Offsets do cone, passos supercover, mapas de bordas relativos e partições de
estrutura selada são cacheados. O registro possui índice por vizinhança de
célula e buckets espaciais de 16 × 16. A memória entregue ao solver é limitada
aos chunks que cruzam o raio atual; o histórico completo não é copiado a cada
invalidação.

Não faça varreduras de `TileMapLayer` em `_process()`. Mudanças de topologia
devem gerar um novo snapshot ou atualizar um portal e então invalidar o
`VisionSystem`.

---

## 4. Configurando `VisionProfile`

Duplique `default_vision_profile.tres` para criar presets de dificuldade ou
acessibilidade. `VisionSystem` e `VisibilityPresenter` devem apontar para a
mesma instância do recurso.

| Propriedade | Padrão | Efeito |
| --- | ---: | --- |
| `enabled` | `true` | Liga cálculo e apresentação de visão. |
| `maximum_range_cells` | `18` | Raio máximo lógico. |
| `front_cone_degrees` | `155.0` | Abertura total do cone frontal. Use `360` para visão circular. |
| `peripheral_range_cells` | `2` | Raio próximo visível em 360°. |
| `window_reveal_depth_cells` | `5` | Alcance restante permitido depois de uma janela. |
| `door_reveal_depth_cells` | `8` | Alcance restante permitido depois de uma porta. |
| `maximum_portal_hops` | `1` | Número máximo de portais diferentes atravessados pelo mesmo raio. |
| `closed_window_transmission` | `0.0` | Campo reservado para evolução; o contrato atual mantém toda janela fechada opaca. |
| `open_window_transmission` | `1.0` | Gate atual: `0` bloqueia janela aberta; qualquer valor maior que zero transmite. Ainda não há atenuação gradual. |
| `sealed_structure_blocks_memory` | `true` | Oculta memória exterior quando a zona interna não alcança o exterior. |
| `mask_resolution_scale` | `0.5` | Escala do `SubViewport` da máscara global. |
| `visual_reveal_height_px` | `192` | Extrusão vertical da célula no fog e amostragem de sprites/telhado altos. |
| `edge_softness_px` | `3.0` | Suavidade visual da borda do fog. Não altera LOS. |
| `transition_seconds` | `0.15` | Fade entre resultados da máscara global. |
| `unknown_opacity` | `1.0` | Opacidade do fog nunca explorado. |
| `remembered_opacity` | `0.82` | Opacidade sobre cenário memorizado. |
| `forced_hidden_opacity` | `1.0` | Opacidade de ocultação estrutural forçada. |
| `roof_revealed_alpha` | `0.0` | Alpha do telhado sobre células internas atualmente visíveis. |
| `look_mouse_deadzone_px` | `24.0` | Distância mínima do cursor ao jogador no modo de olhar. |
| `look_stick_deadzone` | `0.35` | Zona morta do analógico direito. |

`sanitize()` limita valores inválidos antes do uso. Para ajustes em runtime,
altere o recurso e chame `vision_system.apply_profile_changes()`. O coordenador
sanitiza os valores, reaplica as deadzones, publica `profile_changed` para os
presenters e agrupa um novo cálculo. Ferramentas que emitem `Resource.changed`
também disparam esse fluxo automaticamente.

---

## 5. Authoring de estruturas

### Camadas semânticas

O baker reconhece `TileMapLayer` com estes nomes exatos:

```text
Piso
Paredes
```

`Piso` define as células pertencentes à estrutura. `Paredes` define bordas e
portais. Uma casa fechada normalmente usa ambas. Cercas e divisórias podem ter
somente `Paredes`: continuam bloqueando LOS, mas não criam zonas internas. A
camada `ParedesSemColisao` é deliberadamente ignorada pela visão. `Telhado` é
necessário somente para o recorte visual local.

Props que reutilizam `StructureRoot`, mas não possuem `Piso` nem `Paredes` como
`TileMapLayer` semântico (por exemplo, um deck feito apenas de sprites), não
contribuem para a topologia. Eles permanecem exterior comum e não recebem uma
máscara de telhado desnecessária.

O baker não restringe paredes ao `footprint` da definição procedural. Pinte
todas as bordas necessárias mesmo quando a arte ultrapassar o retângulo base.

### Dados semânticos do piso

Em `Piso`, o custom data `categoria` deve ser `piso` (uma categoria vazia ainda
é aceita por compatibilidade). O custom data `ambiente` pode nomear o cômodo,
mas não define a conectividade. O flood fill das bordas é a fonte de verdade.

Se vários nomes de `ambiente` caírem na mesma zona, o nome majoritário é usado
apenas como rótulo; empates são resolvidos deterministicamente.

### Paredes como bordas

Em `Paredes`, use `categoria = parede` e uma destas peças em `peca`:

| `peca` | Borda lógica |
| --- | --- |
| `ne` | célula ↔ célula + `(0, -1)` |
| `nw` | célula ↔ célula + `(-1, 0)` |
| `se` | célula ↔ célula + `(1, 0)` |
| `sw` | célula ↔ célula + `(0, 1)` |
| `quina_n` ou `canto` | `ne` + `nw` |
| `quina_e` | `ne` + `se` |
| `quina_s` | `se` + `sw` |
| `quina_w` | `nw` + `sw` |

O par de células é canonicalizado, portanto pintar a mesma borda pelo sentido
oposto não cria dois bloqueios. Uma peça desconhecida gera warning e é
ignorada.

### Portas e janelas

Use `categoria = porta` ou `categoria = janela`. A orientação deve estar em
`direcao` como `ne`, `nw`, `se` ou `sw`; o baker também tenta extraí-la de
`peca` como fallback.

Estados reconhecidos:

```text
estado_porta:  fechada | aberta | vao | anim00..anim08
estado_janela: fechada | aberta | vao
```

Regras importantes:

- `montante_*` é arte estrutural e não cria portal;
- estado `vao` ou uma peça terminada em `_vao` cria portal permanentemente
  aberto;
- vãos permanentes não são gravados no save;
- porta em animação passa a transmitir a partir de `anim05`;
- durante fechamento, a porta bloqueia ao entrar em `anim04`;
- janela só transmite ao alcançar o tile final aberto;
- janela deixa de transmitir no início da animação de fechamento;
- cada transição lógica emite um único `vision_portal_changed`;
- uma parede opaca e um portal na mesma borda resultam em parede opaca e um
  warning único por estrutura no coordenador.

O ID persistente é determinístico e usa o tipo normalizado em inglês:

```text
placement_id|local_x,local_y|direction|door
placement_id|local_x,local_y|direction|window
```

Nunca use `instance_id` como identidade persistente.

### Zonas internas e externas

O flood fill percorre pisos vizinhos apenas quando não existe borda entre eles.
Portas e janelas continuam separando zonas mesmo abertas; a conexão mutável é
representada pelo grafo de portais.

Uma zona é externa se alguma célula de piso alcançar um vizinho sem piso por
uma lateral sem borda. Assim decks, pátios e estruturas abertas permanecem
exteriores. Para um cômodo ser interno, seu contorno precisa estar fechado por
paredes ou portais autorados corretamente.

Checklist para uma nova casa:

1. pinte todas as células em `Piso`;
2. feche o contorno em `Paredes`, incluindo quinas;
3. confira `categoria`, `peca`, `direcao`, estado e `ambiente` no TileSet;
4. use montantes somente como arte, nunca como abertura;
5. execute o teste do baker ou crie um teste de contrato próprio;
6. verifique `snapshot.warnings` antes de ajustar shaders.

Exemplo de inspeção:

```gdscript
var snapshot := structure.vision_snapshot()
print(snapshot.floor_cells.size())
print(snapshot.edges.size())
print(snapshot.opaque_edge_count())
print(snapshot.portal_count(&"door"))
print(snapshot.portal_count(&"window"))
print(snapshot.warnings)
```

---

## 6. Controle de olhar

`PlayerController` centraliza toda troca de direção em
`_set_facing_direction()` e publica:

```gdscript
signal facing_changed(direction: StringName, logical_vector: Vector2i)
```

As ações registradas em `project.godot` são:

```text
look_mode        botão direito do mouse
look_left/right  eixo horizontal do analógico direito
look_up/down     eixo vertical do analógico direito
```

Enquanto o botão direito está pressionado, o vetor em pixels entre jogador e
cursor é comparado por produto escalar com as quatro direções isométricas. O
analógico direito usa a mesma conversão. Mouse tem precedência quando ambos
estão ativos.

Ao soltar o botão ou o analógico, a última direção permanece. Um movimento
posterior atualiza a orientação novamente. Código futuro de combate ou outra
ação que gire o personagem também deve passar por `_set_facing_direction()`
para manter animação, HUD e visão sincronizados.

---

## 7. Integração e APIs de runtime

### `VisionSystem`

API pública:

```gdscript
func configure(player: Node, chunk_manager: Node, save_manager: Node = null) -> void
func bind_player(player: Node) -> void
func bind_chunk_manager(chunk_manager: Node) -> void
func register_structure(snapshot: StructureVisionSnapshot) -> void
func unregister_structure(placement_id: int) -> void
func set_portal_open(portal_id: StringName, is_open: bool) -> void
func invalidate(reason: StringName = &"manual") -> void
func force_update() -> VisionResult
func apply_profile_changes() -> void
func import_memory(cells: Variant) -> void
func export_memory() -> Dictionary
func export_packed_memory() -> Dictionary
func clear_memory() -> void

signal visibility_changed(result: VisionResult)
signal profile_changed(updated_profile: VisionProfile)
```

Use `invalidate()` no gameplay normal. Invalidações no mesmo frame são
agrupadas e produzem um único solve. `force_update()` é apropriado para testes
e para liberar o primeiro resultado visual imediatamente.

O sistema já invalida em:

- mudança de direção;
- início e fim de passo;
- mudança de nível;
- abertura ou fechamento de portal;
- integração ou unload de estrutura;
- importação ou limpeza da memória.

Para presets alterados em runtime, modifique a instância compartilhada de
`VisionProfile` e finalize com `apply_profile_changes()`. Isso atualiza input,
solver, fog e todos os controladores locais sem recriar materiais ou texturas.

No início do passo, a posição-alvo é usada como origem lógica. Isso mantém o
resultado coerente durante a interpolação visual do jogador.

Para uma parede destrutível futura, faça o rebake e registre novamente o
snapshot com o mesmo `placement_id`:

```gdscript
vision_system.register_structure(structure.vision_snapshot())
vision_system.invalidate(&"wall_changed")
```

`register_structure()` já invalida; a segunda chamada é útil apenas se outras
contribuições externas também mudaram no mesmo fluxo.

### `StructureRoot`

Contrato usado pela visão:

```gdscript
signal vision_portal_changed(portal_id: StringName, is_open: bool)

func vision_snapshot() -> StructureVisionSnapshot
func vision_portals() -> Array[Dictionary]
func vision_portal_id(layer: TileMapLayer, cell: Vector2i, kind := &"") -> StringName
func set_vision_portal_open(portal_id: StringName, is_open: bool) -> bool
func set_vision_controlled(enabled: bool) -> void
func set_automatic_wall_rows(rows: Dictionary) -> void
```

`set_vision_portal_open()` restaura um estado sem animação antes do bake. Para
uma interação jogável, continue usando `toggle_door()` ou `toggle_window()`;
essas rotinas emitem o evento no quadro lógico correto.

### Streaming

`ChunkManager` publica:

```gdscript
signal structure_integrated(
    owner_chunk: Vector2i,
    placement: StructurePlacement,
    structure: StructureRoot
)

signal structure_will_unload(owner_chunk: Vector2i, placement_id: int)
```

O sinal de unload é emitido antes de `queue_free()`. Assim o registro remove
bordas e portais, e a apresentação libera controlador, material e textura sem
callbacks para nós inválidos.

Em `ProceduralWorld`, o player, streaming e save são configurados antes da
geração síncrona dos chunks. Estados persistidos são aplicados antes do
snapshot, e `force_update()` publica a primeira máscara ao fim da montagem.

---

## 8. Fog, telhado, paredes e entidades

### Máscara global

`VisibilityMaskRenderer` desenha num `SubViewport` RGBA de baixa resolução:

```text
R = visível agora
G = memória
B = ocultação forçada
```

Cada célula vira um losango com extrusão vertical para cobrir personagens,
paredes e sprites altos. O renderer usa o mesmo `IsoCoordinateSystem` do mundo
e deriva `tile_size` e `height_pixels` de `WorldSettings`; também sincroniza
tamanho do viewport, canvas transform, transform do mundo e zoom da câmera.
Polígonos fora do viewport são descartados antes da triangulação, inclusive
durante teleportes para coordenadas muito grandes. Enquanto há transição ou
movimento relevante, redesenha; estático, o `SubViewport` usa atualização
única. Transformação, meia célula e extrusão são calculadas uma vez por redraw,
e células totalmente fora da máscara são descartadas antes de enviar geometria
ao canvas.

`visibility_composite.gdshader` aplica a prioridade dos estados e suaviza só a
fronteira visual. O canal azul impede sangramento de suavização através de uma
estrutura selada. A interface principal está no `CanvasLayer` 20 e o
`VisionOverlay` no 10.

### Telhado por estrutura

Cada estrutura com telhado recebe um `RoofRevealController` e uma textura R8
própria, dimensionada pelo `used_rect` de `Piso`. O mesmo controlador pode ser
instalado numa estrutura apenas com `Paredes` para dirigir o modo `AUTO`, sem
criar textura de telhado. O shader converte pixels locais do telhado de volta
em células do piso e reduz o alpha somente onde há célula interna `VISIBLE`
para aquele `placement_id`.

Memória não recorta telhado. Casas que se sobrepõem na tela não compartilham
máscara. Se `Piso`, `Telhado`, TileSet ou máscara forem inválidos, o controlador
falha fechado: mantém o telhado opaco e emite warning.

Ao ativar visão, `StructureRoot.set_vision_controlled(true)` desliga o antigo
comportamento de esconder o telhado inteiro. Ao desativar visão, o material e o
detector legado são restaurados.

### Paredes em `AUTO`

`WallVisibilityManager` preserva os modos numéricos:

```text
FULL        = 0
TRANSPARENT = 1
CUTAWAY     = 2
AUTO        = 3
```

`AUTO` é o padrão. O atlas usa linha 0 para arte baixa, 1 para cheia e 2 para
fantasma. As bordas que correspondem a `se` e `sw` vistas a partir do cômodo
atual usam arte baixa, mesmo quando o tile foi autorado pelo lado oposto como
`nw` ou `ne`; paredes de outros cômodos continuam cheias. Um portal efetivamente
atravessado por um raio bem-sucedido usa arte fantasma. Os três modos manuais
continuam disponíveis como debug/acessibilidade e prevalecem sobre o resultado
automático.

### Entidades dinâmicas

Adicione `VisionVisibilityTarget` como filho de um NPC, item ou outro visual.
Configure `target_path` quando o `CanvasItem` não for o pai e
`logical_position_source_path` quando outro nó fornecer `world_position()`.

Também é possível registrar uma célula explicitamente:

```gdscript
$VisionVisibilityTarget.set_logical_position(Vector3i(x, y, level))
```

O componente desenha a entidade apenas em `VISIBLE`. `REMEMBERED` nunca mostra
entidades dinâmicas. Somente `CanvasItem.visible` é alterado; IA, física, áudio
e simulação continuam ativos. O alvo se registra no presenter ao entrar na
árvore, recebe o último resultado mesmo quando nasce depois do solve e reavalia
automaticamente ao trocar de célula. Se a posição lógica estiver mal
configurada, o componente falha aberto e registra warning para não apagar a
entidade de forma silenciosa. Limpar o presenter ou remover o último resultado
restaura imediatamente a visibilidade autoral do alvo.

---

## 9. Persistência

`WorldSaveManager` grava JSON versão 2. Além da semente, patches e objetos
removidos, o payload contém:

```json
{
  "version": 2,
  "portal_states": {
    "123|4,2|ne|window": true
  },
  "seen_chunks": {
    "-1:0:0": "...Base64..."
  }
}
```

`portal_states` armazena o estado mutável pelo ID estável. Vãos permanentes não
são escritos pelo fluxo de visão.

Quando `WorldSettings.world_seed` é `0`, o `ChunkManager` grava no save a seed
aleatória efetivamente resolvida antes de gerar chunks. Assim IDs de placement,
portais e memória continuam apontando para o mesmo mundo no próximo boot.

`seen_chunks` usa a chave `chunk_x:chunk_y:nivel`. Cada célula local ocupa um
bit em `y * chunk_size + x`; o `PackedByteArray` é convertido para Base64 no
JSON. O codec usa a matemática de chunk do mundo e suporta coordenadas
negativas.

Ordem de restauração de uma estrutura:

1. o streaming instancia `StructureRoot`;
2. `VisionSystem` lê os descritores de portal;
3. estados persistidos são aplicados sem animação;
4. a estrutura produz o snapshot já atualizado;
5. o snapshot entra no registro;
6. o primeiro `VisionResult` atualiza fog, telhado e entidades.

Saves versão 1 não possuem `portal_states` nem `seen_chunks`. A leitura usa
valores vazios para campos ausentes, preservando semente, patches e objetos
removidos sem migração destrutiva.

Use as APIs do coordenador para ferramentas de debug ou migração:

```gdscript
var cells: Dictionary = vision_system.export_memory()
var packed: Dictionary = vision_system.export_packed_memory()
vision_system.import_memory(cells) # aceita células ou chunks compactados
vision_system.clear_memory()
```

---

## 10. Pontos de extensão

### Árvores, móveis e paredes destrutíveis

Modele bloqueadores estáticos como contribuições de borda e mantenha um ID de
proprietário que permita removê-las. Evite consultar colisão dentro do solver.
Uma evolução natural é generalizar `VisionTopologyRegistry` de
`placement_id` para `contributor_id`, preservando a regra “qualquer opaco
vence”. Após adicionar, remover ou alterar a contribuição, invalide com um
motivo específico.

Móveis altos que apenas ocultam entidades podem usar `VisionVisibilityTarget`.
Móveis que bloqueiam LOS precisam contribuir para a topologia.

### Clima, fumaça e transparência parcial

Hoje a transmissão de portal é binária. Para neblina, fumaça ou vidro com
atenuação, adicione intensidade ao resultado do traçado em vez de colocar a
regra no shader. O presenter pode então renderizar outro canal, mas o solver
deve continuar sendo a fonte da percepção.

### Iluminação

Não transforme a máscara de visão em luz. Um sistema de iluminação futuro pode
combinar intensidade luminosa com `VISIBLE`, porém luz não deve revelar uma
célula bloqueada por LOS nem alterar memória.

### Mais andares

As APIs já usam `Vector3i` e a memória é separada por nível. Para escadas,
buracos e visão vertical, acrescente portais verticais e regras explícitas de
conexão; não projete dois níveis diferentes no mesmo registro 2D sem validar
`z`.

### Novos presenters

`VisionResultView` aceita `VisionResult` ou `Dictionary`, o que facilita HUD de
debug, minimapa, editor de topologia e capturas automatizadas. Esses consumers
devem ouvir `visibility_changed` e nunca recalcular LOS por conta própria.

---

## 11. Testes headless

Execute os comandos a partir da raiz do projeto. Se `godot` não estiver no
`PATH`, substitua pela localização do executável console da sua instalação.

Testes principais:

```powershell
godot --headless --path . --script res://tests/player_look_test.gd
godot --headless --path . --script res://tests/structure_vision_baker_test.gd
godot --headless --path . --script res://tests/structure_vision_portal_test.gd
godot --headless --path . --script res://tests/vision_solver_test.gd
godot --headless --path . --script res://tests/vision_system_test.gd
godot --headless --path . --script res://tests/vision_save_test.gd
godot --headless --path . --script res://tests/vision_streaming_signal_test.gd
godot --headless --path . --script res://tests/vision_result_view_test.gd
godot --headless --path . --script res://tests/vision_presentation_test.gd
godot --headless --path . --script res://tests/vision_main_integration_test.gd
```

Suites puras menores, úteis durante mudanças localizadas:

```powershell
godot --headless --path . --script res://gameplay/vision/tests/vision_solver_test.gd
godot --headless --path . --script res://world_generation/visibility/tests/structure_vision_baker_test.gd
```

Regressões relacionadas a estruturas e interação:

```powershell
godot --headless --path . --script res://tests/door_integration_test.gd
godot --headless --path . --script res://tests/window_integration_test.gd
godot --headless --path . --script res://tests/wall_visibility_test.gd
godot --headless --path . --script res://tests/structure_tilemap_test.gd
godot --headless --path . --script res://tests/world_generation_test.gd
godot --headless --path . --script res://tests/player_grid_integration_test.gd
```

Para rodar a suíte principal em PowerShell e parar no primeiro erro:

```powershell
$tests = @(
    "player_look_test.gd",
    "structure_vision_baker_test.gd",
    "structure_vision_portal_test.gd",
    "vision_solver_test.gd",
    "vision_system_test.gd",
    "vision_save_test.gd",
    "vision_streaming_signal_test.gd",
    "vision_result_view_test.gd",
    "vision_presentation_test.gd",
    "vision_main_integration_test.gd"
)

foreach ($test in $tests) {
    & godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Smoke test da cena principal:

```powershell
godot --headless --path . --quit-after 15
```

Prévia automatizada da visão por uma janela (precisa de driver gráfico para ler
os pixels do viewport):

```powershell
godot --path . --script res://tests/vision_visual_preview.gd -- --size=1280x720 --output=user://vision_preview_720p.png
godot --path . --script res://tests/vision_visual_preview.gd -- --size=1920x1080 --output=user://vision_preview_1080p.png
godot --path . --script res://tests/vision_visual_preview.gd -- --size=3840x2160 --output=user://vision_preview_4k.png
```

O contrato da casa de referência deve continuar produzindo 56 células de piso,
45 bordas, 35 bordas opacas, quatro portas, seis janelas e quatro zonas internas
com tamanhos `9`, `15`, `16` e `16`.

---

## 12. Diagnóstico rápido

- Exterior aparece dentro de uma casa fechada: confira contorno, quinas,
  `direcao` dos portais e warnings do snapshot.
- Janela aberta não revela: confirme estado final `aberta`, ID estável idêntico
  entre baker e `StructureRoot`, cone apontando para a abertura e
  `open_window_transmission > 0`.
- Visão atravessa duas aberturas: confira `maximum_portal_hops` e se montantes
  não foram autorados como portais.
- Fog desloca com zoom: confirme que `VisibilityPresenter.configure()` recebeu
  o viewport e o `world_root` que contém o mundo renderizado.
- Uma casa recorta o telhado da outra: cada estrutura deve possuir seu próprio
  `VisionRoofReveal`; nunca compartilhe a textura R8 local.
- Entidade desaparece para sempre: o alvo deve fornecer `world_position()` ou
  receber `set_logical_position()`; desabilitar o componente restaura a
  visibilidade anterior.
- Save não restaura portal: não troque `placement_id`, célula local, direção ou
  tipo sem uma migração dos IDs persistidos.

Com essa separação, novas mecânicas entram como fontes de topologia, regras do
solver ou presenters independentes, sem transformar o sistema de visão em um
bloco acoplado à arte, iluminação ou simulação.

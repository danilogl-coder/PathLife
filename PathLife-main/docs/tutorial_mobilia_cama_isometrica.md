# Tutorial: primeira mobília isométrica — cama

Este tutorial adiciona a cama como a primeira mobília de teste do PathLife. A
estrutura já deixa preparados colisão, interação, quatro orientações e pontos
de referência para futuramente colocar o personagem deitado.

O objetivo desta etapa é:

- importar os quatro PNGs corretamente;
- manter a cama proporcional ao personagem;
- criar uma cena reutilizável e configurável pelo editor;
- fazer o `Y Sort` funcionar;
- impedir que o jogador atravesse a cama;
- preparar marcadores de colchão, travesseiro e saída;
- permitir deitar com `E` e levantar automaticamente ao tentar andar.

## 1. Medidas verificadas

Os quatro arquivos possuem canvas de `192 × 160 px`.

| Arquivo | Área realmente visível |
|---|---:|
| `cama_r0.png` | `144 × 101 px` |
| `cama_r1.png` | `144 × 101 px` |
| `cama_r2.png` | `144 × 82 px` |
| `cama_r3.png` | `144 × 82 px` |

O personagem atual mede aproximadamente `82 px` do pé até o topo da cabeça. A
cama possui cerca de `144 px` no seu eixo visual maior. Isso produz uma razão
aproximada de `1,76`, coerente com uma cama vista em perspectiva isométrica.

Use a cama em escala nativa:

```text
Scale = (1, 1)
```

Não diminua para `0.5` nem aumente para `2`. Isso deixaria a cama incompatível
com o personagem e com as futuras animações de dormir.

## 2. Arquitetura adotada

A mobília será dividida em apresentação e gameplay:

```text
res://
├── assets/
│   └── furniture/
│       └── bedroom/
│           └── bed/
│               ├── cama_r0.png
│               ├── cama_r1.png
│               ├── cama_r2.png
│               └── cama_r3.png
├── presentation/
│   └── furniture/
│       └── bed/
│           └── bed_visual.tscn
└── gameplay/
    └── furniture/
        └── bed/
            ├── bed.gd
            ├── bed_base.tscn
            ├── bed_r0.tscn
            ├── bed_r1.tscn
            ├── bed_r2.tscn
            └── bed_r3.tscn
```

Responsabilidades:

- `bed_visual.tscn`: imagens e camadas visuais;
- `bed_base.tscn`: colisão, área de interação e marcadores;
- `bed_r0` até `bed_r3`: configurações específicas de cada orientação;
- `bed.gd`: somente dados e API pública do móvel;
- cena principal: apenas instancia a cama no mundo.

## 3. Copie os PNGs para dentro do projeto

O Godot só importa corretamente arquivos que estejam dentro de `res://`.

1. No Windows Explorer, abra:

```text
C:\Users\danil\Desktop\personagem_pecas\moveis\quarto
```

2. Copie:

```text
cama_r0.png
cama_r1.png
cama_r2.png
cama_r3.png
```

3. Dentro do projeto, crie:

```text
res://assets/furniture/bedroom/bed/
```

4. Cole os quatro arquivos nessa pasta.
5. Volte ao Godot e aguarde a importação.

Não use os caminhos absolutos da Área de Trabalho diretamente em uma cena. Um
projeto exportado não consegue carregar esses caminhos.

## 4. Configure a importação para pixel art

Para cada PNG:

1. Selecione o arquivo no painel **FileSystem**.
2. Abra a aba **Import**.
3. Configure:

```text
Compress > Mode: Lossless
Mipmaps > Generate: Off
Process > Fix Alpha Border: On
```

4. Clique em **Reimport**.

O filtro `Nearest` será configurado na cena visual, garantindo pixels nítidos.

## 5. Crie a cena visual da cama

1. Crie uma nova cena com raiz `Node2D`.
2. Nomeie a raiz `BedVisual`.
3. Salve como:

```text
res://presentation/furniture/bed/bed_visual.tscn
```

4. Configure a raiz:

```text
Texture Filter = Nearest
Position = (0, 0)
Scale = (1, 1)
```

5. Adicione estes filhos:

```text
BedVisual (Node2D)
├── BedBack (Sprite2D)
├── OccupantLayer (Node2D)
└── BedFront (Sprite2D)
```

### BedBack

Configure:

```text
Texture = cama_r0.png
Centered = On
Position = (0, -80)
Z Index = 0
```

Por que `Position Y = -80`?

O PNG possui `160 px` de altura. Com o sprite centralizado, seu centro original
fica a `80 px` do fundo. Deslocar o sprite para `Y = -80` coloca o centro
inferior do canvas exatamente na origem `(0, 0)` da mobília.

Essa origem será o ponto usado pelo `Y Sort`.

### OccupantLayer

Configure:

```text
Position = (0, 0)
Z Index = 1
```

Esse nó ficará vazio por enquanto. Ele representa a camada onde o personagem
deitado deverá aparecer futuramente.

### BedFront

Configure:

```text
Texture = vazio
Position = (0, -80)
Z Index = 2
Visible = Off
```

O PNG atual é uma imagem única. No futuro, para a coberta ou peseira aparecer
na frente do personagem, será necessário um segundo PNG contendo somente a
parte frontal da cama. Esse arquivo será colocado em `BedFront`.

Não duplique o PNG inteiro em `BedFront`, pois isso esconderia o personagem.

## 6. Por que a cama precisa de camadas

Com uma única imagem só existem duas possibilidades:

```text
Cama inteira atrás do personagem
```

ou:

```text
Cama inteira na frente do personagem
```

Para dormir de forma convincente serão necessárias três camadas:

```text
BedBack
   ↓
Personagem deitado
   ↓
BedFront / coberta / peseira
```

Nesta primeira etapa, `BedBack` exibirá a cama inteira. Isso é suficiente para
testar tamanho, posição, colisão e ordenação. `BedFront` é um ponto de extensão
preparado para o futuro.

## 7. Crie o script mínimo da cama

Crie:

```text
res://gameplay/furniture/bed/bed.gd
```

Use:

```gdscript
class_name BedFurniture
extends StaticBody2D

@export_category("Identity")
@export var furniture_id: StringName = &"bed_basic"
@export var display_name: String = "Cama"

@export_category("Sleep")
@export_enum("ne", "nw", "se", "sw") var sleep_direction: String = "ne"
@export var sleep_center: Marker2D
@export var pillow_anchor: Marker2D
@export var exit_anchor: Marker2D


func get_sleep_position() -> Vector2:
    return sleep_center.global_position


func get_pillow_position() -> Vector2:
    return pillow_anchor.global_position


func get_exit_position() -> Vector2:
    return exit_anchor.global_position


func get_sleep_direction() -> StringName:
    return StringName(sleep_direction)
```

Esse script não lê teclado, não controla o jogador e não abre interface. Ele
apenas descreve a cama e oferece pontos de referência. A futura regra de dormir
deverá ficar em um sistema de interação separado.

## 8. Crie a cena de gameplay da cama

1. Crie uma cena com raiz `StaticBody2D`.
2. Nomeie a raiz `Bed`.
3. Anexe `bed.gd`.
4. Salve como:

```text
res://gameplay/furniture/bed/bed_base.tscn
```

5. Monte esta árvore:

```text
Bed (StaticBody2D)
├── Visual (instância de bed_visual.tscn)
├── SolidCollision (CollisionPolygon2D)
├── InteractionArea (Area2D)
│   └── InteractionShape (CollisionPolygon2D)
├── SleepCenter (Marker2D)
├── PillowAnchor (Marker2D)
└── ExitAnchor (Marker2D)
```

6. Selecione a raiz e atribua pelo Inspector:

```text
Sleep Center = SleepCenter
Pillow Anchor = PillowAnchor
Exit Anchor = ExitAnchor
```

Não procure esses nós com caminhos enormes no script. As propriedades exportadas
deixam as referências visíveis e configuráveis no Inspector.

## 9. Configure as camadas de física

Na raiz `Bed`:

```text
Collision Layer = World / Furniture
Collision Mask = Player
```

Em `InteractionArea`:

```text
Collision Layer = Interactable
Collision Mask = Player
Monitoring = On
Monitorable = On
```

Se o projeto ainda não possui nomes de camada:

1. Abra **Project > Project Settings > Layer Names > 2D Physics**.
2. Nomeie, por exemplo:

```text
Layer 1 = World
Layer 2 = Player
Layer 3 = Interactable
Layer 4 = Furniture
```

Depois confira também a camada e máscara do `Player` para garantir que ele
detecta `World` e `Furniture`.

## 10. Desenhe a colisão r0

Selecione `SolidCollision` e desenhe um polígono somente sobre a área que a
cama ocupa no chão. Não contorne a cabeceira vertical nem o espaço transparente
do PNG.

Como ponto inicial para `r0`, use coordenadas locais próximas de:

```text
(-68, -40)
(-12, -72)
(69, -28)
(14, 0)
```

No Inspector, a propriedade `Polygon` ficará semelhante a:

```text
PackedVector2Array(
    -68, -40,
    -12, -72,
     69, -28,
     14,   0
)
```

Esses pontos são uma base de teste. Use o editor 2D para ajustar o polígono
visualmente ao chão da cama.

Não use um `RectangleShape2D` horizontal. A cama está em perspectiva
isométrica e sua área no chão é um paralelogramo.

## 11. Configure a área de interação

O `InteractionShape` deve ser um pouco maior que a colisão sólida, permitindo
interagir sem entrar dentro da cama.

Para `r0`, comece com:

```text
(-82, -42)
(-16, -86)
(84, -32)
(20, 14)
```

A área de interação não impede movimento. Ela apenas detectará que o jogador
está próximo quando o sistema de interação for implementado.

## 12. Posicione os marcadores r0

Com a origem da cama no centro inferior do canvas, use como base:

```text
SleepCenter  = (0, -55)
PillowAnchor = (35, -68)
ExitAnchor   = (0, 18)
```

Interpretação:

- `SleepCenter`: centro aproximado do colchão;
- `PillowAnchor`: lado da cabeceira onde ficará a cabeça;
- `ExitAnchor`: ponto de reserva para uma futura saída alternativa; atualmente o
  personagem retorna ao local exato em que pressionou `E`.

Para `r0`, configure:

```text
Sleep Direction = ne
```

O projeto já possui a animação `sleep_ne`, portanto esse valor poderá ser usado
diretamente no futuro.

## 13. Crie as quatro orientações como cenas herdadas

Não duplique toda a lógica manualmente.

1. Abra `bed_base.tscn`.
2. Use **Scene > New Inherited Scene**.
3. Escolha `bed_base.tscn` como base.
4. Salve como `bed_r0.tscn`.
5. Repita para `r1`, `r2` e `r3`.

Cada cena herdada alterará apenas:

- textura de `BedBack`;
- polígono de colisão;
- polígono de interação;
- posição dos marcadores;
- `Sleep Direction`.

### Tabela inicial de orientações

| Cena | Textura | Sleep Direction | PillowAnchor | SleepCenter |
|---|---|---|---:|---:|
| `bed_r0` | `cama_r0.png` | `ne` | `(35, -68)` | `(0, -55)` |
| `bed_r1` | `cama_r1.png` | `nw` | `(-35, -68)` | `(0, -55)` |
| `bed_r2` | `cama_r2.png` | `sw` | `(-35, -42)` | `(0, -55)` |
| `bed_r3` | `cama_r3.png` | `se` | `(35, -42)` | `(0, -55)` |

As coordenadas do travesseiro são pontos iniciais. Quando a animação de dormir
for integrada, ajuste alguns pixels observando onde a cabeça realmente termina.

### Colisão por eixo

`r0` e `r2` compartilham o mesmo eixo no chão. `r1` e `r3` usam o eixo
espelhado. Para `r1/r3`, comece espelhando horizontalmente os pontos de
`r0/r2`:

```text
(-69, -28)
(12, -72)
(68, -40)
(-14, 0)
```

Depois ajuste visualmente no editor.

## 14. Instancie a cama na cena principal

A cena principal atual possui:

```text
Main
└── World
    └── Entities (Y Sort Enabled)
        └── Player
```

Faça assim:

1. Abra `res://scenes/main/main.tscn`.
2. Selecione `World/Entities`.
3. Arraste `bed_r0.tscn` para dentro de `Entities`.
4. Nomeie a instância `TestBed`.
5. Comece com uma posição livre, por exemplo:

```text
Position = (470, 180)
```

6. Confirme que `Entities > Y Sort Enabled` continua ligado.

A cama deve ser irmã do `Player`, não filha dele.

## 15. Como a ordenação visual deve se comportar

A origem da cama fica no centro inferior do canvas. A raiz `Bed` e a raiz
`Player` usam `Z Index = 0` e são irmãs dentro de `World/Entities`, que possui
`Y Sort Enabled = On`.

O visual do Player fica dentro de um `CanvasGroup`. Isso mantém as camadas
internas de corpo, braços, roupas e cabelo como uma única unidade perante o
mundo. Assim:

- Player com os pés em `Y` menor que a origem da cama aparece atrás dela;
- Player com os pés em `Y` maior aparece na frente dela;
- a colisão continua independente da ordem de desenho;
- `Z Index` não representa altura física.

Não coloque a raiz da cama em `Z = 20`: isso faria a cama aparecer sempre na
frente e eliminaria a profundidade isométrica.

Cada orientação também possui `TopOcclusionArea/TopOcclusionShape`. Essa forma
é uma faixa fina que acompanha apenas as bordas superiores da cama. Quando o
Player encosta nessa faixa, o componente muda temporariamente `Visual` de
`Z = 0` para o valor `Occluding Z Index` configurado no Inspector. Quando o
Player se afasta, `Visual` volta para `Z = 0`.

Para ajustar o momento exato da troca, abra `bed_r0`, `bed_r1`, `bed_r2` ou
`bed_r3`, selecione `TopOcclusionShape` e mova seus seis pontos no editor 2D.
Não use `SolidCollision` para ajustar essa perspectiva: ela continua responsável
apenas por bloquear movimento.

## 16. Teste a proporção

1. Execute `main.tscn` com `F6`.
2. Ande ao redor da cama.
3. Compare a altura do personagem com o comprimento do colchão.
4. O personagem deve aparentar caber deitado com uma pequena sobra na cabeça e
   nos pés.

Não compare a altura em pé diretamente com a altura vertical do PNG. Em uma
imagem isométrica, o comprimento da cama é projetado diagonalmente e parece
menor na vertical da tela.

Se a cama parecer levemente grande ou pequena, ajuste somente o nó `Visual` e
os polígonos juntos. Use uma faixa conservadora:

```text
Scale mínimo recomendado = 0.90
Scale padrão = 1.00
Scale máximo recomendado = 1.10
```

Não use valores diferentes em X e Y.

## 17. Teste a colisão

Confirme:

- o personagem não atravessa o colchão;
- ele consegue chegar perto das duas laterais;
- a colisão não bloqueia uma área transparente enorme;
- ele consegue alcançar a área de interação;
- `ExitAnchor` está fora da colisão sólida.

Para visualizar formas durante o teste:

```text
Debug > Visible Collision Shapes
```

## 18. Ação de dormir implementada

O Player possui uma instância de `bed_sleep_interactor.tscn`. Seu filho
`BedDetector` detecta a `InteractionArea` da cama sem alterar a colisão sólida.

O fluxo atual é:

```text
Player entra na InteractionArea
    ↓
Pressiona E (ação interact)
    ↓
BedSleepInteractor escolhe a cama mais próxima
    ↓
Suspende temporariamente layer e mask do corpo
    ↓
Move o Player para SleepCenter
    ↓
Aplica o encaixe visual definido pela orientação da cama
    ↓
Reproduz sleep_ne, sleep_nw, sleep_sw ou sleep_se com as texturas correspondentes
```

Ao levantar:

```text
Player pressiona qualquer direção de movimento
    ↓
Restaura a posição global em que o Player pressionou E
    ↓
Restaura layer, mask e Z originais
    ↓
Encerra sleep e já permite caminhar
```

Responsabilidades:

- `BedFurniture` fornece direção, marcadores e o encaixe visual do sono;
- `BedSleepInteractor` cuida da interação, salva a posição de entrada e a restaura ao levantar;
- `PlayerController` mantém o estado de sono;
- `CharacterVisual` apresenta a animação correta.

### Cada cama usa as texturas da sua própria direção

O sistema não gira mais um único conjunto de sprites `ne`. Cada cama informa
sua direção real ao `CharacterVisual`; por isso `CharacterRig`, roupas e cabelo
carregam os arquivos da pasta correta antes de iniciar a animação. As quatro
animações `sleep_*` também possuem uma trilha explícita de rotação do osso raiz
`quadril`, deixando o esqueleto horizontal sem girar nem espelhar o
`VisualAnchor` inteiro:

| Cama | Lado esquerdo | Lado direito | Sleep Visual Offset | Rotation Degrees |
|---|---|---|---:|---:|
| `bed_r0` | `se` | `ne` | `(15, 15)` | `-33` |
| `bed_r1` | `nw` | `sw` | `(-28, 30)` | `30` |
| `bed_r2` | direção fixa `sw` | direção fixa `sw` | `(0, 40)` | `-9` |
| `bed_r3` | direção fixa `se` | direção fixa `se` | `(0, 40)` | `10` |

Esses campos aparecem na raiz `Bed`, na categoria **Apresentação do sono** do
Inspector. O deslocamento de 40 pixels compensa o centro real do rig no
`CharacterVisual`. Ao levantar, o interator restaura a transformação original.
Não altere `SolidCollision` nem `InteractionShape` para corrigir o encaixe
visual: essas formas pertencem à física e à interação.

Os sinais públicos do interator são:

```gdscript
signal bed_became_available(bed: BedFurniture)
signal bed_became_unavailable(bed: BedFurniture)
signal sleep_started(bed: BedFurniture)
signal sleep_ended(bed: BedFurniture)
```

### Direção conforme o lado de interação — somente R0 e R1

`bed_r0.tscn` e `bed_r1.tscn` possuem dois marcadores herdados da cena base:

```text
Bed
├── SleepSideLeft
└── SleepSideRight
```

Quando o Player aperta `E`, o interator guarda a posição exata em que a
interação aconteceu. A cama compara essa posição com os dois marcadores e usa
a direção pertencente ao marcador mais próximo. Portanto, não importa se a
cama foi movida dentro do mapa: os marcadores se movem junto com ela.

Configuração aplicada na raiz `Bed`:

| Propriedade | R0 | R1 | R2/R3 |
|---|---|---|---|
| `Use Interaction Side Direction` | On | On | Off |
| `Sleep Left Direction` | `se` | `nw` | não usada |
| `Sleep Right Direction` | `ne` | `sw` | não usada |

Para ajustar qual região conta como lado esquerdo ou direito:

1. Abra `bed_r0.tscn` ou `bed_r1.tscn`.
2. Selecione `SleepSideLeft` e use a ferramenta **Mover** para deixá-lo no
   centro aproximado do lado esquerdo onde o Player pode apertar `E`.
3. Selecione `SleepSideRight` e coloque-o no centro aproximado do lado direito.
4. Execute a cena e teste `E` nos dois lados.

Esses marcadores escolhem apenas a orientação da animação. Eles não movem o
personagem sobre o colchão. Para preservar o encaixe já ajustado, não altere
`Sleep Visual Offset`, `Sleep Visual Rotation Degrees`, `SleepCenter` ou
`PillowAnchor` ao regular os lados.

Em R2 e R3, `Use Interaction Side Direction` permanece desligado. Essas camas
continuam usando respectivamente `sleep_sw` e `sleep_se`, independentemente do
lado pelo qual o Player se aproxima.

## 19. Camadas frontais de sono implementadas

Cada orientação possui um overlay transparente de `192 × 160`, do mesmo
tamanho e alinhamento da textura da cama:

```text
lencol_r0.png
lencol_r1.png
lencol_r2.png
lencol_r3.png
```

Esses arquivos ficam no `Sprite2D` `Visual/BedFront`. O nó começa com
`Visible = Off` e usa `Z Index = 3`, acima do Player dormindo em `Z = 2`.
Quando `BedSleepInteractor` ocupa a cama, `BedFurniture` emite
`occupancy_changed(true)` e `BedVisual` mostra o lençol. Ao levantar, o mesmo
fluxo envia `false` e o lençol desaparece.

Não coloque essa regra no `PlayerController`: o Player informa apenas que está
dormindo, a cama mantém o estado de ocupação e a camada de apresentação decide
qual sprite mostrar.

R2 e R3 também possuem uma camada `Visual/SleepingHeadboard`, usando
`cabeceira_r2.png` e `cabeceira_r3.png`. Ela compartilha a mesma posição e
offset dos sprites da cama, começa escondida e acompanha o mesmo estado de
ocupação. A ordem atual é:

```text
Player dormindo       = Z 2
BedFront (lençol)     = Z 20
SleepingHeadboard     = Z 21
```

Assim a cabeceira/peseira frontal permanece acima do lençol. R0 e R1 possuem o
nó opcional sem textura, portanto ele continua invisível. Para mudar esse
índice, abra `bed_visual.tscn`, selecione `SleepingHeadboard` e altere
`Ordering > Z Index`, mantendo-o maior que o valor de `BedFront`.

## 20. Checklist final

- [ ] Os quatro PNGs estão dentro de `res://assets/furniture/bedroom/bed`.
- [ ] Importação usa Lossless, sem mipmaps.
- [ ] `BedVisual` usa filtro Nearest.
- [ ] O sprite está em `(0, -80)`.
- [ ] Escala está inicialmente em `(1, 1)`.
- [ ] A raiz física é `StaticBody2D`.
- [ ] A colisão acompanha somente o chão da cama.
- [ ] Existe uma `Area2D` de interação maior que a colisão.
- [ ] Existem `SleepCenter`, `PillowAnchor` e `ExitAnchor`.
- [ ] `ExitAnchor` está fora da colisão.
- [ ] As quatro orientações são cenas herdadas.
- [ ] Cada orientação usa sua própria animação e textura `sleep_ne/nw/sw/se`.
- [ ] R0 usa `sleep_se` pela esquerda e `sleep_ne` pela direita.
- [ ] R1 usa `sleep_nw` pela esquerda e `sleep_sw` pela direita.
- [ ] R2 e R3 continuam com direção fixa.
- [ ] Cada orientação usa seu próprio `lencol_r0/r1/r2/r3.png`.
- [ ] O lençol aparece somente enquanto a cama está ocupada.
- [ ] `BedFront` permanece acima do Player dormindo.
- [ ] R2 e R3 mostram `SleepingHeadboard` acima do lençol durante o sono.
- [ ] A cabeceira frontal desaparece quando o personagem levanta.
- [ ] A ação `interact` está vinculada à tecla `E`.
- [ ] `E` próximo da cama inicia a pose deitada e alinha a cabeça à cabeceira.
- [ ] Qualquer direção de movimento retira o Player da cama.
- [ ] Ao levantar, o Player reaparece exatamente na posição em que interagiu.
- [ ] Ao levantar, colisão, Z e transformação visual originais são restaurados.
- [ ] A cama foi colocada como filha de `World/Entities`.
- [ ] O jogador passa atrás e na frente corretamente.
- [ ] O jogador não atravessa a cama.
- [ ] O Debugger não apresenta erros.

Ao concluir este checklist, a cama estará pronta como primeira mobília
interativa de teste.

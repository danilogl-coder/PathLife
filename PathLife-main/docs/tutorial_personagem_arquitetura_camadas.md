# Personagem Skeleton2D no Godot 4.6 — tutorial com arquitetura em camadas

Este é o guia definitivo para montar o personagem recortado de `character/` sem transformar `Player.gd` em um monstro que movimenta, anima, troca textura e altera HUD ao mesmo tempo.

O resultado terá cinco responsabilidades separadas:

1. **Dados:** configurações reutilizáveis em `Resource`.
2. **Gameplay:** entrada, velocidade, colisão, vida e estado lógico.
3. **Apresentação:** Skeleton2D, sprites, direção visual e animações.
4. **Interface:** HUD responsivo, sem controlar o jogador diretamente.
5. **Composição:** a cena principal conecta os sinais entre as camadas.

No Godot, “backend” e “frontend” não são exatamente os mesmos conceitos de uma aplicação web. Neste tutorial:

- **backend do jogo** significa dados e regras de gameplay;
- **frontend do jogo** significa visual do personagem e HUD;
- **Main** é a ponte controlada entre os dois.

## 1. Regra fundamental da arquitetura

Cada camada só sabe o mínimo necessário:

```text
teclado → PlayerController → sinais → CharacterVisual
                              └────→ HUD
```

- `PlayerController` não conhece `Sprite2D`, `Bone2D`, `AnimationPlayer`, labels ou barras.
- `CharacterVisual` não lê teclado, não movimenta colisão e não altera vida.
- `HUD` não acessa propriedades internas do jogador para mudá-las.
- `Main` recebe referências pelo Inspector e conecta sinais.
- Todos os elementos previsíveis existem em `.tscn`; nenhum label, osso ou sprite estático é criado por código.

## 2. Estrutura de pastas definitiva

Crie esta organização dentro de `res://`:

```text
res://
├── assets/
│   └── characters/
│       └── cutout/
│           ├── masc/
│           │   ├── rig.json
│           │   ├── ne/
│           │   ├── nw/
│           │   ├── se/
│           │   └── sw/
│           └── fem/
│               ├── rig.json
│               ├── ne/
│               ├── nw/
│               ├── se/
│               └── sw/
├── data/
│   └── player/
│       ├── player_config.gd
│       └── default_player_config.tres
├── gameplay/
│   └── player/
│       ├── player.tscn
│       └── player_controller.gd
├── presentation/
│   └── characters/
│       └── cutout/
│           ├── character_visual.tscn
│           ├── character_visual.gd
│           └── character_rig.gd
├── interface/
│   └── hud/
│       ├── hud.tscn
│       └── hud.gd
└── scenes/
    └── main/
        ├── main.tscn
        └── main.gd
```

Não coloque o HUD dentro de `Player`. HUD pertence à interface e deve continuar na tela quando o personagem se movimentar.

## 3. Importe os assets

Copie as pastas originais:

```text
C:\Users\danil\Desktop\Isometric Tiles\character\masc
C:\Users\danil\Desktop\Isometric Tiles\character\fem
```

para:

```text
C:\Users\danil\Desktop\PathLife\path-life\assets\characters\cutout
```

O pacote contém 120 PNGs: 2 corpos × 4 direções × 15 peças.

No Godot:

1. Selecione todos os PNGs no painel **FileSystem**.
2. Na aba **Import**, desligue **Filter**.
3. Desligue **Mipmaps > Generate**.
4. Use compressão `Lossless`.
5. Clique em **Reimport**.

Isso evita que a pixel art fique borrada ou perca o contorno de um pixel.

## 4. Crie a camada de dados

### 4.1 Crie PlayerConfig

Crie `res://data/player/player_config.gd`:

```gdscript
class_name PlayerConfig
extends Resource

@export_category("Movement")
@export_range(10.0, 500.0, 1.0) var movement_speed: float = 100.0
@export_range(1.0, 3.0, 0.05) var run_speed_multiplier: float = 1.65
@export_range(0.1, 1.0, 0.05) var isometric_vertical_ratio: float = 0.5

@export_category("Vitals")
@export_range(1, 1000, 1) var maximum_health: int = 100
```

Esse `Resource` contém configuração permanente. Ele não contém a vida atual, porque vida atual é estado temporário da partida.

### 4.2 Crie o recurso configurável

1. No painel FileSystem, clique com o botão direito em `res://data/player/`.
2. Escolha **New > Resource**.
3. Procure `PlayerConfig`.
4. Salve como `default_player_config.tres`.
5. Configure pelo Inspector:

   - Movement Speed: `100`;
   - Maximum Health: `100`.

Assim um designer pode ajustar velocidade e vida sem editar código.

## 5. Crie a camada de gameplay

### 5.1 Cena Player

Crie `res://gameplay/player/player.tscn` com esta árvore:

```text
Player (CharacterBody2D)
├── CollisionShape2D
└── VisualAnchor (Node2D)
    └── CharacterVisual (instância de character_visual.tscn; será adicionada depois)
```

Por enquanto crie apenas:

1. Raiz `CharacterBody2D` chamada `Player`.
2. Filho `CollisionShape2D`.
3. Filho `Node2D` chamado `VisualAnchor`.

No `CollisionShape2D`:

- Shape: `CapsuleShape2D`;
- Radius: `5`;
- Height: `10`;
- Position: `(0, -5)`.

O ponto `(0, 0)` do Player representa os pés no chão. A colisão fica pequena e próxima aos pés para não prender braços e cabeça nas paredes.

### 5.2 PlayerController

Crie `res://gameplay/player/player_controller.gd`:

```gdscript
class_name PlayerController
extends CharacterBody2D

signal locomotion_changed(direction: StringName, is_moving: bool)
signal health_changed(current_health: int, maximum_health: int)

@export_category("Configuration")
@export var config: PlayerConfig

var _current_health: int = 1
var _facing_direction: StringName = &"se"
var _was_moving: bool = false


func _ready() -> void:
    if config == null:
        push_error("Player precisa de um PlayerConfig no Inspector.")
        set_physics_process(false)
        return

    _current_health = config.maximum_health


func _physics_process(_delta: float) -> void:
    var raw_input := Input.get_vector(
        "move_left",
        "move_right",
        "move_up",
        "move_down"
    )
    var grid_input := _restrict_to_four_directions(raw_input)
    var isometric_input := _to_isometric(grid_input)

    var is_moving := grid_input != Vector2.ZERO
    var previous_direction := _facing_direction
    if is_moving:
        _facing_direction = _direction_from_grid_input(grid_input)

    velocity = isometric_input * config.movement_speed
    move_and_slide()

    if is_moving != _was_moving or _facing_direction != previous_direction:
        locomotion_changed.emit(_facing_direction, is_moving)

    _was_moving = is_moving


func damage(amount: int) -> void:
    if amount <= 0:
        return
    _current_health = maxi(_current_health - amount, 0)
    health_changed.emit(_current_health, config.maximum_health)


func heal(amount: int) -> void:
    if amount <= 0:
        return
    _current_health = mini(_current_health + amount, config.maximum_health)
    health_changed.emit(_current_health, config.maximum_health)


func get_current_health() -> int:
    return _current_health


func get_maximum_health() -> int:
    return config.maximum_health if config != null else 1


func get_facing_direction() -> StringName:
    return _facing_direction


func _restrict_to_four_directions(input_vector: Vector2) -> Vector2:
    if input_vector == Vector2.ZERO:
        return Vector2.ZERO
    if absf(input_vector.x) > absf(input_vector.y):
        return Vector2(signf(input_vector.x), 0.0)
    return Vector2(0.0, signf(input_vector.y))


func _to_isometric(grid_input: Vector2) -> Vector2:
    if grid_input == Vector2.ZERO:
        return Vector2.ZERO
    return Vector2(
        grid_input.x - grid_input.y,
        (grid_input.x + grid_input.y) * config.isometric_vertical_ratio
    ).normalized()


func _direction_from_grid_input(grid_input: Vector2) -> StringName:
    if grid_input.y < 0.0:
        return &"ne"
    if grid_input.y > 0.0:
        return &"sw"
    if grid_input.x < 0.0:
        return &"nw"
    return &"se"
```

Anexe ao nó raiz `Player`. No Inspector, arraste `default_player_config.tres` para a propriedade **Config**.

Observe o que não existe nesse script:

- nenhum caminho para `Skeleton2D`;
- nenhuma textura;
- nenhum `AnimationPlayer`;
- nenhum label ou barra de vida;
- nenhuma montagem visual.

Ele é exclusivamente gameplay.

### 5.3 Configure Input Map

Abra **Project > Project Settings > Input Map** e crie:

```text
move_left   → A e seta esquerda
move_right  → D e seta direita
move_up     → W e seta para cima
move_down   → S e seta para baixo
move_run    → Shift
```

Quando `move_run` estiver pressionado junto de uma direção, o Player usa `run_speed_multiplier` e a apresentação toca `run_ne`, `run_nw`, `run_se` ou `run_sw`. Ao soltar Shift ainda em movimento, volta para `walk_*`; ao soltar a direção, toca `idle_*` preservando o último ângulo.

`Input.get_vector` normaliza as diagonais, impedindo que andar diagonalmente seja mais rápido.

## 6. Crie a camada visual do personagem

### 6.1 Cena CharacterVisual

Crie `res://presentation/characters/cutout/character_visual.tscn`:

```text
CharacterVisual (Node2D)
├── Skeleton2D
│   └── quadril (Bone2D)
│       ├── Sprite (Sprite2D)
│       ├── torso (Bone2D)
│       │   ├── Sprite (Sprite2D)
│       │   ├── cabeca (Bone2D)
│       │   │   ├── Sprite (Sprite2D)
│       │   │   └── ponta_cabeca (Marker2D)
│       │   ├── braco_sup_e (Bone2D)
│       │   │   ├── Sprite (Sprite2D)
│       │   │   └── braco_inf_e (Bone2D)
│       │   │       ├── Sprite (Sprite2D)
│       │   │       └── mao_e (Bone2D)
│       │   │           ├── Sprite (Sprite2D)
│       │   │           └── ponta_mao_e (Marker2D)
│       │   └── braco_sup_d (Bone2D)
│       │       ├── Sprite (Sprite2D)
│       │       └── braco_inf_d (Bone2D)
│       │           ├── Sprite (Sprite2D)
│       │           └── mao_d (Bone2D)
│       │               ├── Sprite (Sprite2D)
│       │               └── ponta_mao_d (Marker2D)
│       ├── coxa_e (Bone2D)
│       │   ├── Sprite (Sprite2D)
│       │   └── perna_e (Bone2D)
│       │       ├── Sprite (Sprite2D)
│       │       └── pe_e (Bone2D)
│       │           ├── Sprite (Sprite2D)
│       │           └── ponta_pe_e (Marker2D)
│       └── coxa_d (Bone2D)
│           ├── Sprite (Sprite2D)
│           └── perna_d (Bone2D)
│               ├── Sprite (Sprite2D)
│               └── pe_d (Bone2D)
│                   ├── Sprite (Sprite2D)
│                   └── ponta_pe_d (Marker2D)
└── AnimationPlayer
```

Todos os nomes precisam ser exatamente iguais. Para cada `Sprite2D`:

- Position: `(0, 0)`;
- Rotation: `0`;
- Scale: `(1, 1)`;
- Centered: ligado;
- Texture Filter: `Nearest`.

Não mova os sprites manualmente. O `offset_sprite` do JSON coloca a junta no pivô correto.

### 6.2 CharacterRig: infraestrutura visual do JSON

Crie `res://presentation/characters/cutout/character_rig.gd`:

```gdscript
class_name CharacterRig
extends Skeleton2D

@export_enum("masc", "fem") var body_type: String = "masc"
@export_enum("se", "sw", "ne", "nw") var initial_direction: String = "se"
@export_dir var assets_root: String = "res://assets/characters/cutout"

var _rig_data: Dictionary = {}
var _pieces: Dictionary = {}
var _current_direction: StringName = &""


func _ready() -> void:
    _cache_piece_nodes()
    _load_body_data()
    set_direction(initial_direction)


func set_direction(direction: StringName) -> void:
    if direction == _current_direction or _rig_data.is_empty():
        return

    var directions: Dictionary = _rig_data["direcoes"]
    var direction_key := String(direction)
    if not directions.has(direction_key):
        push_error("Direção inexistente no rig: %s" % direction_key)
        return

    var direction_data: Dictionary = directions[direction_key]
    var pieces_data: Dictionary = direction_data["pecas"]

    for piece_name: String in pieces_data:
        if not _pieces.has(piece_name):
            push_error("Bone2D ausente na cena: %s" % piece_name)
            continue

        var nodes: Dictionary = _pieces[piece_name]
        var bone: Bone2D = nodes["bone"]
        var sprite: Sprite2D = nodes["sprite"]
        var piece: Dictionary = pieces_data[piece_name]

        bone.position = _parse_vector2(piece["posicao"])
        bone.z_index = int(piece["z_index"])
        sprite.offset = _parse_vector2(piece["offset_sprite"])
        sprite.texture = load("%s/%s" % [assets_root, piece["arquivo"]]) as Texture2D

    _apply_markers(direction_data["pontas"])
    _current_direction = direction


func set_body(new_body: String) -> void:
    if new_body != "masc" and new_body != "fem":
        push_error("Corpo inválido: %s" % new_body)
        return
    if new_body == body_type:
        return

    var direction_to_preserve := _current_direction
    body_type = new_body
    _current_direction = &""
    _load_body_data()
    set_direction(direction_to_preserve if direction_to_preserve != &"" else StringName(initial_direction))


func _cache_piece_nodes() -> void:
    _pieces.clear()
    _collect_bones(self)


func _collect_bones(node: Node) -> void:
    for child: Node in node.get_children():
        if child is Bone2D:
            var bone := child as Bone2D
            bone.z_as_relative = false
            var sprite := bone.get_node_or_null("Sprite") as Sprite2D
            if sprite != null:
                _pieces[String(bone.name)] = {
                    "bone": bone,
                    "sprite": sprite,
                }
        _collect_bones(child)


func _load_body_data() -> void:
    var json_path := "%s/%s/rig.json" % [assets_root, body_type]
    if not FileAccess.file_exists(json_path):
        push_error("rig.json não encontrado: %s" % json_path)
        return

    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
    if not parsed is Dictionary:
        push_error("JSON inválido: %s" % json_path)
        return

    _rig_data = parsed as Dictionary


func _apply_markers(markers_data: Dictionary) -> void:
    for marker_name: String in markers_data:
        var marker := find_child(marker_name, true, false) as Marker2D
        if marker != null:
            marker.position = _parse_vector2(markers_data[marker_name]["posicao"])


func _parse_vector2(value: String) -> Vector2:
    var parts := value.split(" ", false)
    if parts.size() != 2:
        push_error("Vector2 inválido no rig.json: %s" % value)
        return Vector2.ZERO
    return Vector2(float(parts[0]), float(parts[1]))
```

Anexe esse script ao `Skeleton2D`. As propriedades de corpo, direção inicial e pasta dos assets aparecerão no Inspector.

### 6.3 CharacterVisual: API pública da apresentação

Crie `res://presentation/characters/cutout/character_visual.gd`:

```gdscript
class_name CharacterVisual
extends Node2D

@onready var rig: CharacterRig = $Skeleton2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _current_animation: StringName = &""


func present_locomotion(direction: StringName, is_moving: bool) -> void:
    rig.set_direction(direction)
    _play_animation(&"walk" if is_moving else &"idle")


func present_body(body_type: String) -> void:
    rig.set_body(body_type)


func _play_animation(animation_name: StringName) -> void:
    if animation_name == _current_animation:
        return
    animation_player.play(animation_name)
    _current_animation = animation_name
```

Anexe ao nó raiz `CharacterVisual`.

Esse script é uma fachada visual: outros sistemas dizem “apresente locomoção”, mas não precisam saber que existem 15 ossos, 120 texturas ou um JSON.

## 7. Crie as animações visualmente

No `AnimationPlayer` de `character_visual.tscn`, crie:

### idle

- Nome: `idle`;
- Duração: `1.0`;
- Loop: ligado.

Pode começar sem tracks. A pose do JSON ficará parada.

### walk

- Nome: `walk`;
- Duração: `0.60`;
- Loop: ligado.

Anime apenas apresentação. Nunca anime `Player.position`, `CollisionShape2D` ou `velocity`.

Adicione tracks de `rotation` para:

```text
quadril/torso
quadril/torso/braco_sup_e
quadril/torso/braco_sup_d
quadril/coxa_e
quadril/coxa_d
quadril/coxa_e/perna_e
quadril/coxa_d/perna_d
```

Anime também `CharacterVisual.position:y` para a oscilação de um pixel.

| Tempo | torso | braço E | braço D | coxa E | coxa D | perna E | perna D | Visual Y |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.00 | -2° | +12° | -12° | -16° | +16° | +10° | -6° | 0 |
| 0.15 | 0° | 0° | 0° | 0° | 0° | 0° | 0° | -1 |
| 0.30 | +2° | -12° | +12° | +16° | -16° | -6° | +10° | 0 |
| 0.45 | 0° | 0° | 0° | 0° | 0° | 0° | 0° | -1 |
| 0.60 | -2° | +12° | -12° | -16° | +16° | +10° | -6° | 0 |

Use o ícone de chave ao lado de **Rotation Degrees** no Inspector. O quadro `0.60` precisa ser idêntico ao `0.00`.

Não anime `Bone2D.position`: essas posições mudam por direção e são aplicadas pelo rig.json.

## 8. Instancie o visual no Player

1. Abra `player.tscn`.
2. Selecione `VisualAnchor`.
3. Arraste `character_visual.tscn` do FileSystem para `VisualAnchor`.
4. Marque a instância `CharacterVisual` como **Unique Name in Owner** usando o menu de contexto e a opção correspondente.
5. Salve.

A cena Player agora compõe gameplay e apresentação sem misturar os scripts:

```text
Player [player_controller.gd]
├── CollisionShape2D
└── VisualAnchor
    └── CharacterVisual [character_visual.gd]
        ├── Skeleton2D [character_rig.gd]
        └── AnimationPlayer
```

O fato de as cenas estarem instanciadas juntas não mistura responsabilidades. A separação está nas APIs e nos scripts.

## 9. Crie o HUD como cena independente

Crie `res://interface/hud/hud.tscn` com raiz `Control` chamada `HUD`.

Use esta árvore:

```text
HUD (Control)
└── SafeMargin (MarginContainer)
    └── StatusPanel (PanelContainer)
        └── PanelMargin (MarginContainer)
            └── Content (VBoxContainer)
                ├── TitleLabel (Label)
                ├── HealthLabel (Label)
                ├── HealthBar (ProgressBar)
                └── MovementLabel (Label)
```

### Layout responsivo

1. Selecione `HUD` e use **Layout > Full Rect**.
2. Em `HUD`, use Mouse > Filter = `Ignore`, para não bloquear cliques do jogo.
3. Selecione `SafeMargin` e use **Layout > Full Rect**.
4. Em Theme Overrides > Constants do `SafeMargin`, use margens de `24`.
5. No `StatusPanel`, use tamanho mínimo aproximado `(260, 0)`.
6. No `PanelMargin`, use margens internas de `12`.
7. No `Content`, use separação de `8`.
8. Configure os textos:

   - TitleLabel: `PERSONAGEM`;
   - HealthLabel: `Vida: 100 / 100`;
   - MovementLabel: `Parado — SE`.

9. Em `HealthBar`:

   - Min Value: `0`;
   - Max Value: `100`;
   - Value: `100`;
   - Show Percentage: ligado.

Marque `HealthLabel`, `HealthBar` e `MovementLabel` como **Unique Name in Owner**.

Nenhum desses controles deve ser criado em `hud.gd`. A árvore visual pertence ao `.tscn`.

### Script do HUD

Crie `res://interface/hud/hud.gd`:

```gdscript
class_name PlayerHUD
extends Control

@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var movement_label: Label = %MovementLabel


func present_health(current_health: int, maximum_health: int) -> void:
    health_bar.max_value = maximum_health
    health_bar.value = current_health
    health_label.text = "Vida: %d / %d" % [current_health, maximum_health]


func present_locomotion(direction: StringName, is_moving: bool) -> void:
    var state_text := "Andando" if is_moving else "Parado"
    movement_label.text = "%s — %s" % [state_text, String(direction).to_upper()]
```

Anexe ao nó raiz `HUD`.

O HUD só sabe apresentar valores. Ele não cura, causa dano, muda velocidade nem decide se o personagem pode andar.

## 10. Crie a cena principal como Composition Root

Crie `res://scenes/main/main.tscn`:

```text
Main (Node)
├── World (Node2D)
│   ├── Ground (visual temporário ou TileMapLayer)
│   └── Player (instância de player.tscn)
│       └── Camera2D
└── Interface (CanvasLayer)
    └── HUD (instância de hud.tscn)
```

### Passos

1. Crie `Main` como `Node`.
2. Adicione `World` como `Node2D`.
3. Instancie `player.tscn` dentro de `World`.
4. Posicione Player em `(320, 180)`.
5. Adicione `Camera2D` ao Player e ligue **Enabled**.
6. Adicione `Interface` como `CanvasLayer`, irmão de `World`.
7. Instancie `hud.tscn` dentro de `Interface`.
8. Marque Player, CharacterVisual e HUD como nomes únicos no proprietário quando estiverem disponíveis na cena editável.

O `CanvasLayer` impede que o HUD viaje junto com a câmera.

### Main.gd: somente conexões

Crie `res://scenes/main/main.gd`:

```gdscript
class_name MainScene
extends Node

@export_category("Scene References")
@export var player: PlayerController
@export var character_visual: CharacterVisual
@export var hud: PlayerHUD


func _ready() -> void:
    if not _references_are_valid():
        return

    player.locomotion_changed.connect(character_visual.present_locomotion)
    player.locomotion_changed.connect(hud.present_locomotion)
    player.health_changed.connect(hud.present_health)

    character_visual.present_locomotion(player.get_facing_direction(), false)
    hud.present_locomotion(player.get_facing_direction(), false)
    hud.present_health(player.get_current_health(), player.get_maximum_health())


func _references_are_valid() -> bool:
    if player == null:
        push_error("Main: referência Player não configurada no Inspector.")
        return false
    if character_visual == null:
        push_error("Main: referência CharacterVisual não configurada no Inspector.")
        return false
    if hud == null:
        push_error("Main: referência HUD não configurada no Inspector.")
        return false
    return true
```

Anexe ao `Main`.

No Inspector do Main:

1. Arraste o nó `Player` da árvore para a propriedade **Player**.
2. Arraste `CharacterVisual` para **Character Visual**.
3. Arraste `HUD` para **Hud**.

Isso é melhor que usar caminhos longos como `$World/Player/VisualAnchor/...`. As dependências ficam visíveis e substituíveis pelo Inspector.

O Main não possui regras do jogador e não modifica ossos. Ele apenas liga saídas a entradas:

```text
Player.locomotion_changed
├── CharacterVisual.present_locomotion
└── HUD.present_locomotion

Player.health_changed
└── HUD.present_health
```

## 11. Por que os sinais mantêm a separação

Quando o Player anda, ele emite:

```gdscript
locomotion_changed.emit(direction, is_moving)
```

O Player não sabe quem escuta. Você pode remover o HUD, substituir todo o visual ou adicionar som de passos sem tocar no controlador.

O CharacterVisual recebe os mesmos dados e decide:

- quais texturas usar;
- quais `z_index` aplicar;
- qual animação tocar.

O HUD recebe os dados e decide somente qual texto mostrar.

Essa direção de dependências evita ciclos e acoplamento:

```text
Dados ← Gameplay → sinais → Apresentação
                         → Interface
```

## 12. Configure ordenação isométrica

1. No `World`, crie um `Node2D` chamado `Entities` se houver vários personagens.
2. Ligue **Y Sort Enabled** nele.
3. Coloque Player e NPCs como filhos de Entities.
4. Mantenha a origem de cada personagem nos pés.

Os `z_index` internos dos membros vêm do `rig.json` e mudam por direção. Não zere esses valores; eles determinam qual braço ou perna fica na frente.

Em todos os `Bone2D`, deixe **Ordering > Z As Relative** desligado. A tabela do `rig.json` usa valores absolutos de `0` a `14`. Se essa opção ficar ligada, o Godot soma o Z do osso ao Z dos pais e um braço configurado para ficar atrás do torso pode terminar renderizado na frente.

O Y Sort do mundo e o z-index das peças resolvem problemas diferentes:

- Y Sort: personagem inteiro contra móveis, paredes baixas e outros personagens;
- z-index do rig: braço contra torso, coxa contra quadril e assim por diante.

## 13. Adicione uma colisão de teste

Dentro de `World`:

1. Adicione `StaticBody2D` chamado `TestWall`.
2. Adicione `CollisionShape2D` filho.
3. Use `RectangleShape2D` com Size `(120, 20)`.
4. Adicione algum visual atrás ou use um tile para enxergar a parede.

O jogador deve parar na parede enquanto o HUD continua fixo na tela e a animação continua pertencendo apenas ao visual.

## 14. Teste na ordem correta

### Teste A — visual isolado

Abra `character_visual.tscn` e pressione `F6`.

Esperado:

- corpo montado;
- nenhuma peça faltando;
- direção inicial `se`;
- nenhum erro vermelho.

### Teste B — Player isolado

Abra `player.tscn` e pressione `F6`.

Esperado:

- colisão existe;
- nenhuma mensagem de PlayerConfig ausente;
- não é obrigatório o HUD aparecer.

O movimento visual ainda depende das conexões feitas pelo Main. Isso é intencional: Player isolado testa gameplay, não a aplicação inteira.

### Teste C — HUD isolado

Abra `hud.tscn` e pressione `F6`.

Esperado:

- painel no canto superior esquerdo;
- margens corretas;
- barra e textos visíveis;
- redimensionar a janela não destrói o layout.

### Teste D — integração

Abra `main.tscn` e pressione `F6`.

Esperado:

- WASD e setas movimentam;
- personagem vira para as quatro diagonais;
- `walk` toca em movimento;
- `idle` toca parado;
- HUD alterna entre Andando e Parado;
- HUD fica fixo quando a câmera move;
- colisão impede atravessar a parede.

Depois pressione `F5` e defina `main.tscn` como cena principal.

## 15. Teste vida sem misturar o HUD

Para um teste temporário, adicione ao final de `_physics_process` de `PlayerController`:

```gdscript
if Input.is_action_just_pressed("ui_accept"):
    damage(10)
```

Pressionar espaço deverá reduzir a vida e atualizar o HUD através do sinal. Depois do teste, remova esse trecho; entrada de dano real deve vir de inimigos, perigos ou outro sistema de gameplay.

O ponto importante é: o Player emite `health_changed`; ele nunca escreve em `HealthBar.value`.

## 16. Onde adicionar funcionalidades futuras

Use esta tabela para não bagunçar a arquitetura:

| Funcionalidade | Lugar correto |
|---|---|
| velocidade, colisão e regras de movimento | `PlayerController` ou componente de gameplay |
| vida máxima e velocidade padrão | `PlayerConfig.tres` |
| vida atual | estado de gameplay do Player |
| trocar PNG por direção | `CharacterRig` |
| tocar idle/walk | `CharacterVisual` |
| cabelo, roupa e acessórios visuais | apresentação do personagem |
| barra de vida e textos | `HUD` |
| salvar jogo | sistema próprio, possivelmente Autoload se realmente global |
| conectar Player ao HUD | `Main` ou outra composition root |
| inventário visual | cena própria dentro de `interface/` |
| dados de itens | `Resource` dentro de `data/` |

## 17. Erros arquiteturais que você não deve cometer

### Não faça no PlayerController

```gdscript
$HUD/HealthBar.value = health
$Visual/Skeleton2D/torso.rotation = 0.2
$Visual/AnimationPlayer.play("walk")
```

Isso transforma gameplay em controlador de interface e apresentação.

### Não faça no HUD

```gdscript
player.health -= 10
player.velocity = Vector2.ZERO
```

O HUD apresenta e emite intenções de botões; regras continuam no gameplay.

### Não crie o HUD inteiro por código

Não use `Label.new()`, `ProgressBar.new()` e coordenadas fixas para elementos permanentes. Eles devem existir em `hud.tscn`, organizados por Containers.

### Não use Autoload como depósito de nós

Não crie um `Global.gd` contendo referências para Player, HUD, câmera e mapa. O Main já possui as dependências da cena e conecta os sinais explicitamente.

### Não coloque regra no CharacterVisual

O visual pode decidir como mostrar `is_moving`, mas não pode decidir se o jogador tem stamina suficiente para andar. Essa é uma regra de gameplay.

## 18. Checklist de arquitetura e funcionamento

- [ ] Assets estão em `res://assets/characters/cutout`.
- [ ] `PlayerConfig` é um Resource editável no Inspector.
- [ ] `PlayerController` não referencia HUD, sprites, esqueleto ou animações.
- [ ] `CharacterVisual` não lê teclado nem movimenta CharacterBody2D.
- [ ] `CharacterRig` só cuida de dados visuais do rig.
- [ ] HUD é uma cena independente sob `CanvasLayer`.
- [ ] HUD usa Containers e âncoras, não coordenadas fixas.
- [ ] HUD não altera vida nem movimento diretamente.
- [ ] Main recebe referências pelo Inspector.
- [ ] Main conecta sinais e não contém regras de gameplay.
- [ ] Todos os 15 Bone2D e Sprite2D existem em `character_visual.tscn`.
- [ ] A colisão permanece no Player e não acompanha o balanço visual.
- [ ] `walk` anima apenas propriedades visuais.
- [ ] As quatro direções usam posição, offset e z-index do JSON.
- [ ] Corpo masculino e feminino compartilham o esqueleto.
- [ ] O Debugger não mostra erros vermelhos.

## 19. Árvore final completa

```text
Main [main.gd: composição]
├── World
│   ├── Ground
│   ├── TestWall
│   └── Player [player_controller.gd: gameplay]
│       ├── CollisionShape2D
│       ├── Camera2D
│       └── VisualAnchor
│           └── CharacterVisual [character_visual.gd: apresentação]
│               ├── Skeleton2D [character_rig.gd: infraestrutura visual]
│               │   └── 15 Bone2D com seus Sprite2D
│               └── AnimationPlayer
└── Interface [CanvasLayer]
    └── HUD [hud.gd: interface]
        └── SafeMargin
            └── StatusPanel
                └── PanelMargin
                    └── Content
                        ├── TitleLabel
                        ├── HealthLabel
                        ├── HealthBar
                        └── MovementLabel
```

Essa divisão permite trocar o HUD, trocar o personagem visual, criar NPCs com o mesmo rig ou testar o gameplay sem carregar a interface. Cada cena continua visível, configurável e reutilizável no editor do Godot.

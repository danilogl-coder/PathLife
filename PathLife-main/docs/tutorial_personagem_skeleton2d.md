# Tutorial completo: personagem recortado com Skeleton2D no Godot 4.6

> **Versão arquitetural:** este primeiro guia ensina o funcionamento básico do rig. Para a implementação definitiva, com gameplay, visual e HUD separados por cenas, scripts e sinais, use [tutorial_personagem_arquitetura_camadas.md](./tutorial_personagem_arquitetura_camadas.md). O segundo guia substitui a arquitetura simplificada usada aqui.

Este guia começa do absoluto zero e usa exatamente o pacote localizado originalmente em:

```text
C:\Users\danil\Desktop\Isometric Tiles\character
```

O resultado final será um personagem que:

- aparece montado corretamente a partir das 15 peças;
- usa `CharacterBody2D`, `Skeleton2D`, `Bone2D` e `Sprite2D`;
- olha para `ne`, `nw`, `se` e `sw`;
- anda com teclado;
- colide com o cenário;
- toca uma animação de caminhada feita no `AnimationPlayer`;
- pode trocar entre corpo masculino e feminino sem remontar o esqueleto.

> Não pule etapas. Teste sempre no ponto indicado antes de continuar.

## 1. O que existe no pacote

Há dois corpos:

```text
character/
├── masc/
└── fem/
```

Cada corpo tem quatro direções:

- `se`: sudeste, para baixo e para a direita;
- `sw`: sudoeste, para baixo e para a esquerda;
- `ne`: nordeste, para cima e para a direita;
- `nw`: noroeste, para cima e para a esquerda.

Cada direção contém as mesmas 15 peças:

```text
quadril
torso
cabeca
braco_sup_e
braco_inf_e
mao_e
braco_sup_d
braco_inf_d
mao_d
coxa_e
perna_e
pe_e
coxa_d
perna_d
pe_d
```

`_e` significa o lado esquerdo do personagem e `_d` o lado direito do personagem. Não significa esquerda e direita da tela.

Cada corpo também possui um `rig.json`. Ele já informa:

- `posicao`: onde a junta fica em relação à junta pai;
- `offset_sprite`: onde a imagem fica em relação à junta;
- `z_index`: se a peça deve ser desenhada atrás ou na frente;
- `arquivo`: qual PNG usar;
- `pontas`: posição final de cabeça, mãos e pés.

O ponto `(0, 0)` da cena do personagem será o ponto dos pés no chão. O quadril fica aproximadamente 38 pixels acima dele. Isso é importante para colisão, navegação e ordenação isométrica.

## 2. Copie os arquivos para dentro do projeto

O Godot só importa normalmente arquivos que estão dentro da pasta do projeto, isto é, dentro de `res://`.

1. Feche o Godot se o projeto estiver aberto.
2. No Explorador de Arquivos, abra:

   ```text
   C:\Users\danil\Desktop\PathLife\path-life\assets\characters
   ```

3. Crie uma pasta chamada `cutout`.
4. Copie para ela as pastas `masc` e `fem` inteiras, incluindo os dois `rig.json`.

O resultado precisa ser:

```text
path-life/
└── assets/
    └── characters/
        └── cutout/
            ├── masc/
            │   ├── rig.json
            │   ├── ne/
            │   ├── nw/
            │   ├── se/
            │   └── sw/
            └── fem/
                ├── rig.json
                ├── ne/
                ├── nw/
                ├── se/
                └── sw/
```

Abra o projeto `C:\Users\danil\Desktop\PathLife\path-life\project.godot` no Godot 4.6 e espere a importação terminar.

## 3. Configure a importação dos PNGs

Esses PNGs são pixel art pequena. Filtro linear deixará tudo borrado.

1. No painel **FileSystem**, clique na pasta `assets/characters/cutout`.
2. Na caixa de busca do painel, procure por `*.png` se necessário.
3. Selecione todos os PNGs das pastas `masc` e `fem`.
4. Abra a aba **Import**, normalmente no canto superior esquerdo.
5. Configure:

   - **Filter**: desligado;
   - **Mipmaps > Generate**: desligado;
   - **Compress > Mode**: `Lossless`.

6. Clique em **Reimport**.

Alternativa global: em **Project > Project Settings > General > Rendering > Textures**, use filtro padrão `Nearest`. Mesmo assim, manter a importação sem mipmaps continua recomendável.

## 4. Crie as pastas do sistema

No painel **FileSystem**, clique com o botão direito e crie:

```text
res://characters/player/
├── player.tscn
├── player.gd
└── character_rig.gd
```

Os scripts serão criados depois. Não coloque o sistema inteiro em um script só:

- `player.gd`: entrada, movimento, direção e escolha da animação;
- `character_rig.gd`: leitura do `rig.json`, texturas, pivôs e profundidade;
- `player.tscn`: estrutura visual, colisão, esqueleto e animações.

## 5. Crie a cena Player

1. Clique em **Scene > New Scene**.
2. Clique em **Other Node**.
3. Procure `CharacterBody2D`.
4. Crie e renomeie para `Player`.
5. Salve como:

   ```text
   res://characters/player/player.tscn
   ```

6. Com `Player` selecionado, clique no botão de adicionar filho e crie `CollisionShape2D`.
7. No Inspector do `CollisionShape2D`, em **Shape**, escolha **New CapsuleShape2D**.
8. Clique no recurso `CapsuleShape2D` e use, inicialmente:

   - Radius: `5`
   - Height: `10`

9. Coloque o `CollisionShape2D` em `Position = (0, -5)`.

A colisão deve ficar apenas perto dos pés. Não envolva a cabeça e os braços; isso faria o personagem prender em todas as paredes.

10. Adicione um `Node2D` chamado `Visual` como filho de `Player`.
11. Adicione um `Skeleton2D` chamado `Skeleton2D` como filho de `Visual`.
12. Adicione um `AnimationPlayer` chamado `AnimationPlayer` como filho de `Visual`.

Neste ponto:

```text
Player (CharacterBody2D)
├── CollisionShape2D
└── Visual (Node2D)
    ├── Skeleton2D
    └── AnimationPlayer
```

## 6. Entenda a diferença entre os nós

- `CharacterBody2D` move o personagem inteiro e resolve colisões.
- `Visual` permite animar uma pequena subida e descida sem mexer na colisão.
- `Skeleton2D` reúne os ossos.
- Cada `Bone2D` é uma junta. Sua `position` vem de `posicao` no JSON.
- Cada osso terá um `Sprite2D` filho. O `offset` do sprite vem de `offset_sprite` no JSON.
- `AnimationPlayer` guarda os movimentos da caminhada.

Não use `Polygon2D` nem pintura de pesos neste personagem. Isso seria necessário para dobrar uma imagem como borracha. Aqui cada membro já é uma peça rígida separada; basta que cada `Sprite2D` acompanhe seu `Bone2D`.

## 7. Monte a árvore de ossos

Todos os nós abaixo de `Skeleton2D`, exceto os `Sprite2D` e `Marker2D`, devem ser do tipo `Bone2D`.

Crie exatamente esta árvore:

```text
Player
├── CollisionShape2D
└── Visual
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

### Como criar sem enlouquecer

1. Crie `quadril` como `Bone2D` filho de `Skeleton2D`.
2. Crie um `Sprite2D` filho de `quadril` e chame-o `Sprite`.
3. Selecione `quadril` de novo e crie `torso` como filho.
4. Crie o `Sprite` de `torso`.
5. Continue um ramo de cada vez.
6. Se colocar algo no pai errado, arraste o nó na árvore para o pai correto e confirme **Reparent**.

O nome precisa ser idêntico ao JSON, inclusive `_`, sem acento e com letras minúsculas.

### Propriedades de cada Sprite2D

Em todos os 15 `Sprite2D`:

- `Position = (0, 0)`;
- `Rotation = 0`;
- `Scale = (1, 1)`;
- `Centered = On`;
- `Texture Filter = Nearest`.

Não tente corrigir visualmente o pivô arrastando o sprite. O script aplicará o `offset_sprite` exato.

## 8. Crie o controlador do rig

Crie `res://characters/player/character_rig.gd` e cole:

```gdscript
class_name CharacterRig
extends Skeleton2D

@export_enum("masc", "fem") var body_type: String = "masc"
@export_enum("se", "sw", "ne", "nw") var initial_direction: String = "se"
@export_dir var assets_root: String = "res://assets/characters/cutout"

var _rig_data: Dictionary = {}
var _pieces: Dictionary = {}
var _current_direction: String = ""


func _ready() -> void:
    _cache_piece_nodes()
    _load_body_data()
    set_direction(initial_direction)


func _cache_piece_nodes() -> void:
    _pieces.clear()
    _collect_bones(self)


func _collect_bones(node: Node) -> void:
    for child: Node in node.get_children():
        if child is Bone2D:
            var bone := child as Bone2D
            var sprite := bone.get_node_or_null("Sprite") as Sprite2D
            if sprite != null:
                _pieces[bone.name] = {
                    "bone": bone,
                    "sprite": sprite,
                }
        _collect_bones(child)


func _load_body_data() -> void:
    var json_path := "%s/%s/rig.json" % [assets_root, body_type]
    if not FileAccess.file_exists(json_path):
        push_error("rig.json não encontrado: %s" % json_path)
        return

    var json_text := FileAccess.get_file_as_string(json_path)
    var parsed: Variant = JSON.parse_string(json_text)
    if not parsed is Dictionary:
        push_error("JSON inválido: %s" % json_path)
        return

    _rig_data = parsed as Dictionary


func set_direction(direction: String) -> void:
    if direction == _current_direction:
        return
    if _rig_data.is_empty():
        return
    if not _rig_data["direcoes"].has(direction):
        push_error("Direção inexistente no rig: %s" % direction)
        return

    var direction_data: Dictionary = _rig_data["direcoes"][direction]
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

    body_type = new_body
    _current_direction = ""
    _load_body_data()
    set_direction(initial_direction)


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

### Ligue o script ao nó correto

1. Selecione `Skeleton2D`.
2. Clique no ícone de anexar script.
3. Escolha `res://characters/player/character_rig.gd`.
4. No Inspector, confirme:

   - Body Type: `masc`;
   - Initial Direction: `se`;
   - Assets Root: `res://assets/characters/cutout`.

Salve a cena.

## 9. Primeiro teste visual

1. Clique no ícone de executar cena atual ou pressione `F6`.
2. Se o Godot pedir uma cena principal, escolha executar apenas a cena atual.

Ainda não há câmera nem fundo, mas o personagem deve aparecer perto do canto superior esquerdo. Se não aparecer:

1. Abra **Debugger > Errors**.
2. Confira se há `rig.json não encontrado`.
3. Confira se todos os 15 `Bone2D` têm exatamente os nomes do JSON.
4. Confira se cada `Bone2D` possui um filho chamado exatamente `Sprite`.

Se aparecer desmontado, quase sempre uma peça foi colocada sob o pai errado. Compare a árvore com a seção 7.

## 10. Crie as ações do teclado

1. Abra **Project > Project Settings**.
2. Vá até **Input Map**.
3. Crie estas quatro ações:

   ```text
   move_left
   move_right
   move_up
   move_down
   ```

4. Em `move_left`, adicione as teclas `A` e seta esquerda.
5. Em `move_right`, adicione `D` e seta direita.
6. Em `move_up`, adicione `W` e seta para cima.
7. Em `move_down`, adicione `S` e seta para baixo.
8. Feche Project Settings.

## 11. Crie o script de movimento

Crie `res://characters/player/player.gd` e cole:

```gdscript
class_name PlayerCharacter
extends CharacterBody2D

@export_category("Movement")
@export_range(10.0, 500.0, 1.0) var movement_speed: float = 100.0

@onready var rig: CharacterRig = $Visual/Skeleton2D
@onready var animation_player: AnimationPlayer = $Visual/AnimationPlayer

var _facing_direction: String = "se"
var _current_animation: StringName = &""


func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector(
        "move_left",
        "move_right",
        "move_up",
        "move_down"
    )

    velocity = input_vector * movement_speed

    if input_vector != Vector2.ZERO:
        _facing_direction = _direction_from_input(input_vector)
        rig.set_direction(_facing_direction)
        _play_animation(&"walk")
    else:
        _play_animation(&"idle")

    move_and_slide()


func _direction_from_input(input_vector: Vector2) -> String:
    if input_vector.y >= 0.0:
        return "se" if input_vector.x >= 0.0 else "sw"
    return "ne" if input_vector.x >= 0.0 else "nw"


func _play_animation(animation_name: StringName) -> void:
    if animation_name == _current_animation:
        return
    animation_player.play(animation_name)
    _current_animation = animation_name
```

Anexe esse script ao nó raiz `Player`.

### O que o código faz

- `Input.get_vector` lê as quatro ações e normaliza a diagonal. Sem isso, andar na diagonal seria mais rápido.
- `velocity` recebe direção vezes velocidade.
- `_direction_from_input` escolhe um dos quatro conjuntos de PNGs.
- `rig.set_direction` só troca os dados quando a direção realmente muda.
- `move_and_slide` move e resolve colisões.
- `_play_animation` evita reiniciar a animação a cada frame.

## 12. Crie a animação idle

1. Selecione `AnimationPlayer`.
2. O painel **Animation** aparecerá na parte inferior.
3. Clique em **Animation > New**.
4. Dê o nome `idle`.
5. Ative o botão de repetição/loop.
6. Defina a duração como `1.0` segundo.

Para um primeiro `idle`, não é obrigatório criar track alguma. A pose carregada do JSON ficará parada. Depois você pode animar respiração com rotação muito pequena do torso.

## 13. Crie a animação walk

1. No `AnimationPlayer`, clique em **Animation > New**.
2. Nomeie `walk`.
3. Ative loop.
4. Defina duração `0.60` segundo.
5. Use atualização contínua para tracks de rotação.

### Antes de inserir chaves

Nunca anime `position` dos ossos neste rig. As posições mudam quando o personagem vira, e vêm do JSON. Anime principalmente `rotation`.

Para dar subida e descida ao corpo inteiro, anime `Visual.position`, não `Player.position` nem `CollisionShape2D.position`.

### Tracks recomendadas

Adicione tracks de propriedade para:

```text
Skeleton2D/quadril/torso:rotation
Skeleton2D/quadril/torso/braco_sup_e:rotation
Skeleton2D/quadril/torso/braco_sup_d:rotation
Skeleton2D/quadril/coxa_e:rotation
Skeleton2D/quadril/coxa_d:rotation
Skeleton2D/quadril/coxa_e/perna_e:rotation
Skeleton2D/quadril/coxa_d/perna_d:rotation
Visual:position
```

O caminho exibido no editor pode começar por `Skeleton2D/...` ou por `Visual/...`, dependendo do nó raiz usado pelo `AnimationPlayer`. A forma mais segura é usar o ícone de chave no Inspector da propriedade, em vez de digitar o caminho.

### Método mais seguro para inserir cada chave

1. Mova a cabeça de reprodução para o tempo desejado.
2. Selecione o `Bone2D` na árvore.
3. No Inspector, abra **Transform**.
4. Digite o valor de **Rotation Degrees**.
5. Clique no pequeno ícone de chave à direita da propriedade.
6. Confirme a criação da track se o Godot perguntar.

### Tabela da caminhada

Use estes valores como primeira animação funcional. Eles são uma base; depois ajuste visualmente.

| Tempo | torso | braço sup. E | braço sup. D | coxa E | coxa D | perna E | perna D | Visual Y |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.00 | -2° | +12° | -12° | -16° | +16° | +10° | -6° | 0 |
| 0.15 | 0° | 0° | 0° | 0° | 0° | 0° | 0° | -1 |
| 0.30 | +2° | -12° | +12° | +16° | -16° | -6° | +10° | 0 |
| 0.45 | 0° | 0° | 0° | 0° | 0° | 0° | 0° | -1 |
| 0.60 | -2° | +12° | -12° | -16° | +16° | +10° | -6° | 0 |

Em `Visual.position`, use `X = 0` em todas as chaves e somente altere Y.

O frame de `0.60` precisa ser igual ao de `0.00`, senão haverá um tranco no loop.

### Se a caminhada parecer invertida em algumas direções

Isso é normal em um recorte isométrico. Faça assim depois que a primeira versão funcionar:

1. Duplique `walk` e chame a cópia `walk_left`.
2. Inverta os sinais das rotações de braços e pernas.
3. No script, escolha `walk_left` para `sw` e `nw`, e `walk` para `se` e `ne`.

Primeiro faça a versão única funcionar. Não complique antes do primeiro teste.

## 14. Teste em uma cena de mundo

1. Crie uma nova cena `Node2D` chamada `TestWorld`.
2. Salve como `res://test_world.tscn`.
3. Arraste `res://characters/player/player.tscn` para dentro dela.
4. Coloque o Player aproximadamente em `(320, 180)`.
5. Adicione um `Camera2D` como filho do Player.
6. No Inspector da câmera, deixe **Enabled** ligado.
7. Adicione ao mundo um `ColorRect` grande ou um `Sprite2D` de chão apenas para enxergar movimento. Se usar `ColorRect`, coloque-o atrás do Player com `z_index` menor.
8. Pressione `F6` para executar a cena.
9. Teste WASD e setas.

Para definir como cena principal:

1. Pressione `F6` e confirme que a cena funciona.
2. Pressione `F5`.
3. Quando o Godot perguntar, selecione **Select Current**.

## 15. Adicione uma parede para testar colisão

1. Em `TestWorld`, adicione `StaticBody2D` chamado `Wall`.
2. Adicione um `CollisionShape2D` filho.
3. Use `RectangleShape2D` com tamanho visível, por exemplo `(100, 20)`.
4. Opcionalmente adicione um `Polygon2D` ou `ColorRect` para enxergar a parede.
5. Execute e tente atravessá-la.

Se o personagem parar na parede, o `CharacterBody2D` está funcional.

## 16. Troque o corpo masculino pelo feminino

Como os dois corpos usam as mesmas juntas, não duplique o esqueleto.

Para escolher antes de executar:

1. Abra `player.tscn`.
2. Selecione `Skeleton2D`.
3. No Inspector, altere **Body Type** de `masc` para `fem`.
4. Execute.

Para trocar durante o jogo, algum sistema pode chamar:

```gdscript
rig.set_body("fem")
```

ou:

```gdscript
rig.set_body("masc")
```

## 17. Ordenação isométrica

O `z_index` das peças internas já vem do JSON e não deve ser substituído por um único valor. Ele muda conforme a direção para manter o braço e a perna corretos na frente.

Para ordenar personagens e objetos no mapa:

1. Coloque todos sob um `Node2D` de mundo com **Y Sort Enabled** ligado.
2. O ponto de origem do Player já é o pé, então a ordenação por Y será coerente.
3. Não mude a origem para o centro do torso.

Se estiver posicionando pelo canto de um tile isométrico de 128 × 64, o pacote informa:

```text
posição do personagem = (tile_x + 64 - pivo_x, tile_y + 32 - pivo_y)
```

Na cena construída neste tutorial o ponto do pé já é `(0, 0)`, então normalmente você posicionará o `Player` diretamente no ponto central do chão e não precisará subtrair o pivô do canvas original.

## 18. Erros comuns e solução

### O personagem fica todo borrado

- Desligue `Filter` na importação.
- Use `Texture Filter = Nearest` no `Visual` ou nos sprites.
- Desligue mipmaps.

### Braço gira em torno do centro da imagem

- O `Sprite2D.offset` não foi aplicado.
- Confira se o filho se chama `Sprite`.
- Confira o painel **Debugger > Errors**.
- Não mova o Sprite manualmente para compensar.

### Uma peça não aparece

- O nome do `Bone2D` pode estar errado.
- O PNG pode não ter sido copiado.
- O filho pode não se chamar `Sprite`.
- O caminho `Assets Root` pode estar errado.

### O corpo desmonta quando vira

- A hierarquia está errada.
- Compare cada pai com a árvore da seção 7.
- `posicao` é local ao pai, não global.

### Braço errado fica na frente

- Não fixe todos os `z_index` em zero.
- O script precisa aplicar `piece["z_index"]` ao `Bone2D`.

### O personagem não anda

- Confira as quatro ações no Input Map.
- Confira se `player.gd` está anexado ao nó `Player`.
- Confira se o Debugger mostra ação inexistente ou nó não encontrado.

### A animação reinicia e parece parada

- Não chame `play("walk")` incondicionalmente todo frame.
- O método `_play_animation` do tutorial evita isso.

### A colisão mexe junto com a animação

- A track de balanço foi criada no nó errado.
- Anime `Visual.position`, nunca `Player.position`.

### Há avisos de comprimento nos ossos terminais

Eles não impedem o personagem recortado de funcionar. Os `Marker2D` mostram as pontas. Se quiser limpar o aviso visual de um `Bone2D` terminal, desligue cálculo automático de comprimento e defina manualmente `Length` e `Bone Angle` no Inspector. Isso só altera o gizmo do osso, não o pivô do Sprite.

## 19. Checklist final

Só considere concluído quando todos os itens abaixo estiverem verdadeiros:

- [ ] Os 120 PNGs estão dentro de `res://assets/characters/cutout`.
- [ ] Os dois `rig.json` estão dentro do projeto.
- [ ] Todos os PNGs usam filtro Nearest, sem mipmaps e compressão sem perda.
- [ ] A raiz é `CharacterBody2D`.
- [ ] Existe um `CollisionShape2D` pequeno nos pés.
- [ ] Existe um `Visual` separado da colisão.
- [ ] Existe um `Skeleton2D` com 15 `Bone2D`.
- [ ] Cada `Bone2D` possui um `Sprite2D` chamado `Sprite`.
- [ ] A hierarquia de pais está correta.
- [ ] O personagem aparece montado em `se`.
- [ ] Virar para as quatro diagonais troca as texturas e a profundidade.
- [ ] WASD e setas movem na mesma velocidade inclusive na diagonal.
- [ ] A animação `walk` tem loop e não dá tranco entre 0.60 e 0.00.
- [ ] Parado toca `idle`; em movimento toca `walk`.
- [ ] O Player não atravessa um `StaticBody2D`.
- [ ] Trocar `Body Type` conserva o mesmo esqueleto.
- [ ] O Debugger não mostra erros vermelhos.

## 20. Estrutura final esperada

```text
res://
├── assets/
│   └── characters/
│       └── cutout/
│           ├── masc/
│           └── fem/
├── characters/
│   └── player/
│       ├── player.tscn
│       ├── player.gd
│       └── character_rig.gd
└── test_world.tscn
```

Na cena, a estrutura visual, os pivôs, a colisão e as animações continuam selecionáveis e configuráveis pelo editor. O código só executa as partes realmente dinâmicas: leitura dos dados, troca de corpo/direção, entrada e movimento.

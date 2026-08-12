# Sistema de personalização de personagem e roupas — Godot 4.6

Este tutorial parte do projeto atual do PathLife e não manda reconstruir o personagem. O `Player`, o `CharacterVisual`, o `Skeleton2D`, as quatro direções e as animações `idle`, `walk` e `run` continuam sendo usados.

O resultado será um menu próprio no qual será possível:

- escolher corpo masculino ou feminino;
- colocar e remover camisa;
- colocar e remover jaqueta;
- escolher calça;
- escolher sapato ou chinelo;
- escolher óculos comum ou escuro;
- escolher boné ou chapéu;
- conferir o resultado nas quatro direções;
- ver o personagem animado no preview;
- confirmar ou cancelar sem alterar o personagem por acidente.

> Importante: este documento é o tutorial de implementação. Apenas criar este arquivo não instala o sistema automaticamente. Execute as etapas na ordem.

## 1. O que já existe no projeto

A arquitetura atual é:

```text
Main
├── World
│   └── Entities
│       └── Player [PlayerController]
│           ├── CollisionShape2D
│           ├── Camera2D
│           └── VisualAnchor
│               └── CharacterVisual
│                   ├── Skeleton2D [CharacterRig]
│                   └── AnimationPlayer
└── Interface [CanvasLayer]
    └── HUD
```

As responsabilidades atuais estão corretas:

- `PlayerController` cuida de entrada, movimento, colisão e vida.
- `CharacterVisual` escolhe a animação visual.
- `CharacterRig` troca corpo, direção, texturas, offsets e profundidade.
- `AnimationPlayer` anima os `Bone2D`.
- `HUD` mostra informações.
- `Main` conecta sistemas independentes.

Não coloque lógica de roupas dentro de `PlayerController`. Roupa é aparência, não movimento.

## 2. Resultado da análise da pasta roupas

A origem analisada foi:

```text
C:\Users\danil\Desktop\PathLife\archive\roupas
```

Ela contém:

- `184` PNGs válidos no total: 168 das roupas rígidas e 16 da saia deformável;
- `roupas.json` com caminhos, ossos e offsets;
- versões `masc` e `fem`;
- direções `ne`, `nw`, `se` e `sw`;
- transparência correta para pixel art;
- nomes de ossos compatíveis com o `Skeleton2D` atual.

Inventário real:

| Item | Quantidade de PNGs | Ossos utilizados | Situação |
|---|---:|---|---|
| Camisa | 24 | torso e braços superiores | completa |
| Jaqueta | 40 | torso, braços superiores e inferiores | completa |
| Calça | 40 | quadril, coxas e pernas | completa |
| Sapato | 16 | dois pés | completa |
| Chinelo | 16 | dois pés | completa |
| Boné | 8 | cabeça | completa |
| Chapéu | 8 | cabeça | completa |
| Óculos | 8 | cabeça | completa |
| Óculos escuros | 8 | cabeça | completa |
| Saia deformável | 16 | Polygon2D com pesos no quadril e coxas | completa |

### Por que a saia é diferente

O `roupas.json` antigo ainda descreve uma saia rígida de oito arquivos chamados `quadril.png`. Essa descrição ficou obsoleta e **não deve ser usada**.

A saia nova possui seu próprio pacote:

```text
saia/
├── masc/{ne,nw,se,sw}/
│   ├── frente.png
│   └── tras.png
├── fem/{ne,nw,se,sw}/
│   ├── frente.png
│   └── tras.png
├── saia_malha.json
├── saia_malha.gd
├── saia_balanco.gd
├── saia_recurso.gd
├── saia_deformavel.tscn
└── saia_rosa.tres
```

Ela não é um `Sprite2D` preso rigidamente ao quadril. Ela usa:

- dois `Polygon2D`, um atrás e outro na frente das pernas;
- 261 vértices e 448 triângulos por gênero e direção;
- pesos das duas coxas;
- sete ossos exclusivos da saia;
- movimento secundário com mola amortecida;
- troca de malha, textura e profundidade nas quatro direções.

As 16 texturas foram verificadas:

| Corpo | Tamanho | Direções | Camadas |
|---|---:|---|---|
| Masculino | 25 × 29 px | NE, NW, SE, SW | frente e trás |
| Feminino | 27 × 29 px | NE, NW, SE, SW | frente e trás |

Todas são RGBA, possuem transparência binária e estão referenciadas corretamente pelo `saia_malha.json`.

## 3. Como uma roupa acompanhará a animação

Uma camisa não será uma imagem inteira flutuando por cima do personagem. Ela é formada por três imagens:

```text
camisa
├── torso.png
├── braco_sup_e.png
└── braco_sup_d.png
```

Cada imagem será colocada no mesmo osso da parte corporal correspondente:

```text
torso (Bone2D)
├── Sprite                         ← torso do corpo
├── Clothing_camisa_torso          ← camisa, ordem 1
└── Clothing_jaqueta_torso         ← jaqueta, ordem 2
```

Quando o osso gira, todos os seus filhos giram juntos. Portanto:

```text
AnimationPlayer gira Bone2D
            ↓
corpo acompanha
            ↓
camisa acompanha
            ↓
jaqueta acompanha
```

Não são necessárias versões novas de `idle`, `walk` ou `run` para cada roupa.

Regras obrigatórias para camisa, jaqueta, calça, calçados e acessórios rígidos:

1. A roupa é filha do `Bone2D`, não filha do sprite corporal.
2. A roupa é adicionada depois do sprite corporal.
3. A roupa usa `position = (0, 0)`.
4. A roupa usa o `offset_sprite` do `roupas.json`.
5. A roupa não altera `Bone2D.position`.
6. A roupa não altera o `z_index` do osso.
7. Camadas no mesmo osso seguem o campo `ordem` do JSON.

A saia é a exceção consciente:

```text
AnimationPlayer gira quadril e coxas
            ↓
pesos deformam os dois Polygon2D
            ↓
SaiaBalanco movimenta apenas os sete ossos exclusivos do tecido
```

Ela não exige novas animações e não escreve nos ossos animados do corpo. Dessa forma, `AnimationPlayer` e balanço procedural não disputam a mesma propriedade.

## 4. Slots de personalização

O JSON não possui slots. O sistema acrescentará seis:

| Slot interno | Texto no menu | Opções |
|---|---|---|
| `top` | Camisa | Nenhuma, Camisa |
| `outerwear` | Jaqueta | Nenhuma, Jaqueta |
| `bottom` | Parte inferior | Nenhuma, Calça, Saia |
| `footwear` | Calçado | Nenhum, Sapato, Chinelo |
| `eyewear` | Óculos | Nenhum, Óculos, Óculos escuros |
| `headwear` | Cabeça | Nenhum, Boné, Chapéu |

Camisa e jaqueta podem coexistir. A camisa tem ordem `1` e a jaqueta tem ordem `2`.

Itens do mesmo slot não coexistem. Por exemplo, selecionar saia substitui calça, e selecionar chinelo substitui sapato.

## 5. Arquitetura final

```text
dados permanentes
├── ClothingItem (.tres)
├── ClothingCatalog (.tres + roupas.json + saia_malha.json)
├── SaiaRecurso (.tres)
└── CharacterAppearance (.tres)
          ↓
estado oficial do Player
└── CharacterAppearanceState
          ↓ appearance_changed
apresentação
└── CharacterVisual
    ├── CharacterRig
    ├── WardrobePresenter
    ├── SaiaDeformavel
    └── AnimationPlayer

HUD ── customization_requested ──→ Main
Main ── snapshot ──→ CharacterCustomizationMenu
Menu ── appearance_confirmed ──→ Main
Main ── apply ──→ CharacterAppearanceState
```

O menu nunca mexe diretamente nos ossos do Player real. Ele modifica uma cópia temporária e usa outro `CharacterVisual` como preview.

## 6. Estrutura de pastas

Ao terminar, o projeto terá:

```text
res://
├── assets/characters/cutout/
│   ├── masc/
│   ├── fem/
│   └── clothing/
│       ├── roupas.json
│       ├── bone/
│       ├── calca/
│       ├── camisa/
│       ├── chapeu/
│       ├── chinelo/
│       ├── jaqueta/
│       ├── oculos/
│       ├── oculos_escuro/
│       ├── sapato/
│       ├── saia/
│       │   ├── masc/
│       │   └── fem/
│       └── saia_malha.json
├── data/character_customization/
│   ├── character_appearance.gd
│   ├── clothing_item.gd
│   ├── clothing_catalog.gd
│   ├── default_character_appearance.tres
│   ├── default_clothing_catalog.tres
│   ├── items/
│   └── skirt/
│       ├── saia_recurso.gd
│       └── default_skirt.tres
├── gameplay/player/
│   ├── character_appearance_state.gd
│   ├── player_controller.gd
│   └── player.tscn
├── presentation/characters/cutout/
│   ├── clothing_piece.tscn
│   ├── wardrobe_presenter.gd
│   ├── character_rig.gd
│   ├── character_visual.gd
│   ├── character_visual.tscn
│   └── skirt/
│       ├── saia_malha.gd
│       ├── saia_balanco.gd
│       └── saia_deformavel.tscn
└── interface/character_customization/
    ├── customization_slot_row.gd
    ├── customization_slot_row.tscn
    ├── character_customization_menu.gd
    └── character_customization_menu.tscn
```

## 7. Copie os assets para dentro do projeto

O Godot exporta arquivos de `res://`. Ele não deve carregar roupas diretamente de `archive`.

1. Feche o jogo em execução.
2. No Explorador do Windows, abra:

   ```text
   C:\Users\danil\Desktop\PathLife\archive\roupas
   ```

3. Copie `roupas.json` e estas nove pastas de roupas rígidas:

   ```text
   bone, calca, camisa, chapeu, chinelo, jaqueta,
   oculos, oculos_escuro, sapato
   ```

4. Da pasta `saia`, copie apenas `masc` e `fem` para uma nova pasta chamada `saia` no destino.
5. Copie `saia/saia_malha.json` diretamente para a raiz da pasta `clothing`.
6. O resultado deve ser colado em:

   ```text
   C:\Users\danil\Desktop\PathLife\PathLife-main\assets\characters\cutout\clothing
   ```

7. Volte ao Godot e espere a importação terminar.
8. Selecione os PNGs no FileSystem.
9. Na aba Import, use:

   ```text
   Mipmaps > Generate: Off
   Compress > Mode: Lossless
   ```

10. Clique em Reimport.
11. Abra `character_visual.tscn`, selecione `CharacterVisual` e confirme:

   ```text
   Texture > Filter = Nearest
   ```

No Godot 4.6, o filtro 2D é configurado no `CanvasItem`, não pela antiga opção `Filter: Off` do importador. O `ClothingPiece` herdará `Nearest` do `CharacterVisual`.

Resultado esperado: `184` PNGs dentro de `res://assets/characters/cutout/clothing` e dois JSONs nestes caminhos:

```text
res://assets/characters/cutout/clothing/roupas.json
res://assets/characters/cutout/clothing/saia/saia_malha.json
```

### 7.1 Organize os scripts da saia

Não copie `saia_deformavel.tscn` e `saia_rosa.tres` cegamente: os dois arquivos originais apontam para `res://saia/`, mas este projeto usa uma arquitetura organizada. Vamos reutilizar os scripts e remontar as referências pelo Inspector.

1. Crie:

   ```text
   res://data/character_customization/skirt/
   res://presentation/characters/cutout/skirt/
   ```

2. Copie:

   ```text
   archive/roupas/saia/saia_recurso.gd
   → res://data/character_customization/skirt/saia_recurso.gd

   archive/roupas/saia/saia_malha.gd
   → res://presentation/characters/cutout/skirt/saia_malha.gd

   archive/roupas/saia/saia_balanco.gd
   → res://presentation/characters/cutout/skirt/saia_balanco.gd
   ```

3. Espere o Godot reconhecer as classes `SaiaRecurso`, `SaiaMalha` e `SaiaBalanco`.

### 7.2 Crie o Resource da saia

1. Clique com o botão direito em `res://data/character_customization/skirt/`.
2. Escolha **New > Resource**.
3. Procure `SaiaRecurso`.
4. Salve como `default_skirt.tres`.
5. Configure no Inspector:

   ```text
   Dados:
   res://assets/characters/cutout/clothing/saia/saia_malha.json

   Pasta Texturas:
   res://assets/characters/cutout/clothing

   Rigidez: 2.4
   Amortecimento: 0.34
   Ganho: 0.055
   Limite: 12.0
   Rigidez Barra: 1.6
   Amortecimento Barra: 0.24
   Limite Barra: 7.0
   Limiar Parado: 1.5
   ```

`Pasta Texturas` termina em `clothing`, e não em `clothing/saia`, porque o JSON já contém caminhos começando por `saia/`.

### 7.3 Monte a cena deformável

Crie uma cena com esta árvore:

```text
SaiaDeformavel (Node2D) [saia_malha.gd]
├── SaiaTras (Polygon2D)
├── SaiaFrente (Polygon2D)
└── SaiaBalanco (Node) [saia_balanco.gd]
```

Passo a passo:

1. Crie uma cena **Other Node > Node2D**.
2. Nomeie a raiz `SaiaDeformavel`.
3. Anexe `saia_malha.gd` à raiz.
4. Crie dois filhos `Polygon2D`, chamados `SaiaTras` e `SaiaFrente`.
5. Nos dois Polygon2D use:

   ```text
   Texture > Filter = Nearest
   Antialiased = Off
   ```

6. Crie um filho `Node` chamado `SaiaBalanco`.
7. Anexe `saia_balanco.gd` ao `SaiaBalanco`.
8. No Inspector do `SaiaBalanco`, arraste a raiz `SaiaDeformavel` para a propriedade `Malha`.
9. No Inspector da raiz configure:

   ```text
   Recurso = default_skirt.tres
   Painel Tras = SaiaTras
   Painel Frente = SaiaFrente
   ```

10. Deixe `Visible = Off`; o guarda-roupa ligará a saia somente quando ela estiver equipada.
11. Salve como:

   ```text
   res://presentation/characters/cutout/skirt/saia_deformavel.tscn
   ```

As referências `Esqueleto`, `Osso Quadril`, `Osso Coxa Esq` e `Osso Coxa Dir` serão preenchidas depois, quando essa cena estiver dentro de `CharacterVisual`.

### 7.4 Acrescente a API de equipar e remover

Abra a cópia de `saia_malha.gd`. Depois de `signal reconfigurada`, adicione:

```gdscript
@onready var balanco: SaiaBalanco = $SaiaBalanco
```

Antes das funções privadas, adicione:

```gdscript
func equipar(corpo: StringName, direcao: StringName) -> void:
    show()
    configurar(corpo, direcao)
    if balanco != null:
        balanco.repousar()


func remover() -> void:
    if balanco != null:
        balanco.repousar()
    hide()
```

Isso garante que equipar, remover ou trocar de roupa não reutilize velocidade e aceleração antigas da mola.

## 8. Crie ClothingItem

Crie a pasta:

```text
res://data/character_customization/
```

Crie `clothing_item.gd`:

```gdscript
class_name ClothingItem
extends Resource

@export_category("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var source_key: StringName = &""

@export_category("Equipment")
@export_enum("top", "outerwear", "bottom", "footwear", "eyewear", "headwear")
var slot: String = "top"
@export_enum("bone_sprites", "deformable_skirt")
var visual_type: String = "bone_sprites"

@export_category("Menu")
@export var icon: Texture2D
```

Significado:

- `id`: identificador interno salvo no personagem.
- `display_name`: texto apresentado ao jogador.
- `source_key`: chave dentro do `roupas.json`.
- `slot`: local lógico ocupado.
- `visual_type`: `bone_sprites` para roupas normais; `deformable_skirt` somente para a saia.
- `icon`: miniatura futura. Pode ficar vazio porque ainda não existem ícones.

A ordem visual não é duplicada no `.tres`: ela continuará vindo do campo `ordem` do próprio `roupas.json`.

## 9. Crie os dez recursos de roupa

Crie:

```text
res://data/character_customization/items/
```

Para cada item:

1. Clique com o botão direito na pasta `items`.
2. Escolha **New > Resource**.
3. Procure `ClothingItem`.
4. Clique em Create.
5. Salve com o nome indicado.
6. Preencha o Inspector conforme a tabela.

| Arquivo | ID | Display Name | Source Key | Slot | Visual Type | Ordem |
|---|---|---|---|---|---|---:|
| `camisa.tres` | `camisa` | Camisa | `camisa` | `top` | `bone_sprites` | 1 |
| `jaqueta.tres` | `jaqueta` | Jaqueta | `jaqueta` | `outerwear` | `bone_sprites` | 2 |
| `calca.tres` | `calca` | Calça | `calca` | `bottom` | `bone_sprites` | 1 |
| `saia.tres` | `saia` | Saia | `saia` | `bottom` | `deformable_skirt` | 1 |
| `sapato.tres` | `sapato` | Sapato | `sapato` | `footwear` | `bone_sprites` | 1 |
| `chinelo.tres` | `chinelo` | Chinelo | `chinelo` | `footwear` | `bone_sprites` | 1 |
| `bone.tres` | `bone` | Boné | `bone` | `headwear` | `bone_sprites` | 3 |
| `chapeu.tres` | `chapeu` | Chapéu | `chapeu` | `headwear` | `bone_sprites` | 3 |
| `oculos.tres` | `oculos` | Óculos | `oculos` | `eyewear` | `bone_sprites` | 2 |
| `oculos_escuro.tres` | `oculos_escuro` | Óculos escuros | `oculos_escuro` | `eyewear` | `bone_sprites` | 2 |

A última coluna serve apenas para conferência. Não há propriedade para digitá-la no Resource. A ordem da saia pode continuar sendo lida da entrada antiga do `roupas.json`; seus caminhos antigos de textura, porém, não serão utilizados.

## 10. Crie ClothingCatalog

Crie `clothing_catalog.gd`:

```gdscript
class_name ClothingCatalog
extends Resource

const DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"se", &"sw"]

@export_file("*.json") var metadata_path: String = ""
@export_dir var textures_root: String = ""
@export var deformable_skirt: SaiaRecurso
@export var items: Array[ClothingItem] = []

var _clothes_data: Dictionary = {}
var _skirt_data: Dictionary = {}


func get_item(item_id: StringName) -> ClothingItem:
    for item: ClothingItem in items:
        if item != null and item.id == item_id:
            return item
    return null


func get_items_for_slot(slot_name: StringName) -> Array[ClothingItem]:
    var result: Array[ClothingItem] = []
    for item: ClothingItem in items:
        if item != null and StringName(item.slot) == slot_name:
            result.append(item)
    return result


func is_item_in_slot(item_id: StringName, slot_name: StringName) -> bool:
    var item := get_item(item_id)
    return item != null and StringName(item.slot) == slot_name


func get_piece_data(
    item_id: StringName,
    body_type: String,
    direction: StringName
) -> Dictionary:
    if not _ensure_loaded():
        return {}

    var item := get_item(item_id)
    if item == null:
        push_error("Roupa não cadastrada: %s" % item_id)
        return {}
    if item.visual_type != "bone_sprites":
        push_error("get_piece_data só aceita roupa rígida: %s" % item_id)
        return {}

    var source_id := String(item.source_key)
    if not _clothes_data.has(source_id):
        push_error("Roupa ausente no JSON: %s" % source_id)
        return {}

    var item_data: Dictionary = _clothes_data[source_id]
    var bodies: Dictionary = item_data.get("corpos", {})
    if not bodies.has(body_type):
        push_error("Corpo %s ausente na roupa %s" % [body_type, item_id])
        return {}

    var directions: Dictionary = bodies[body_type]
    var direction_key := String(direction)
    if not directions.has(direction_key):
        push_error("Direção %s ausente na roupa %s" % [direction_key, item_id])
        return {}

    return directions[direction_key] as Dictionary


func load_piece_texture(relative_path: String) -> Texture2D:
    var full_path := "%s/%s" % [textures_root, relative_path]
    if not ResourceLoader.exists(full_path):
        push_error("PNG de roupa não encontrado: %s" % full_path)
        return null
    return load(full_path) as Texture2D


func get_layer_order(item_id: StringName) -> int:
    if not _ensure_loaded():
        return 0
    var item := get_item(item_id)
    if item == null:
        return 0
    if item.visual_type == "deformable_skirt":
        return 1
    var source_id := String(item.source_key)
    if not _clothes_data.has(source_id):
        return 0
    var item_data: Dictionary = _clothes_data[source_id]
    return int(item_data.get("ordem", 0))


func is_item_complete(item_id: StringName, body_type: String) -> bool:
    if not _ensure_loaded():
        return false

    var item := get_item(item_id)
    if item == null:
        return false
    if item.visual_type == "deformable_skirt":
        return _is_deformable_skirt_complete(body_type)
    var source_id := String(item.source_key)
    if not _clothes_data.has(source_id):
        return false

    var item_data: Dictionary = _clothes_data[source_id]
    var expected_bones_value: Variant = item_data.get("ossos", [])
    if not expected_bones_value is Array:
        return false
    var expected_bones := expected_bones_value as Array

    for direction: StringName in DIRECTIONS:
        var pieces := get_piece_data(item_id, body_type, direction)
        if pieces.size() != expected_bones.size():
            return false

        for bone_value: Variant in expected_bones:
            var piece_name := String(bone_value)
            if not pieces.has(piece_name):
                return false
            var piece: Dictionary = pieces[piece_name]
            if not piece.has("arquivo") or not piece.has("offset_sprite") or not piece.has("tamanho"):
                return false

            var offset_value: Variant = piece["offset_sprite"]
            if not offset_value is Array or (offset_value as Array).size() != 2:
                return false

            var full_path := "%s/%s" % [textures_root, String(piece["arquivo"])]
            if not ResourceLoader.exists(full_path):
                return false

            var texture := load(full_path) as Texture2D
            var size_value: Variant = piece["tamanho"]
            if texture == null or not size_value is Array or (size_value as Array).size() != 2:
                return false
            var declared_size := Vector2(
                float((size_value as Array)[0]),
                float((size_value as Array)[1])
            )
            if texture.get_size() != declared_size:
                return false
    return true


func _is_deformable_skirt_complete(body_type: String) -> bool:
    if deformable_skirt == null:
        return false
    if not FileAccess.file_exists(deformable_skirt.dados):
        return false

    if _skirt_data.is_empty():
        var parsed: Variant = JSON.parse_string(
            FileAccess.get_file_as_string(deformable_skirt.dados)
        )
        if not parsed is Dictionary:
            return false
        _skirt_data = parsed as Dictionary

    var bodies: Dictionary = _skirt_data.get("corpos", {})
    if not bodies.has(body_type):
        return false
    var directions: Dictionary = bodies[body_type]

    for direction: StringName in DIRECTIONS:
        var direction_key := String(direction)
        if not directions.has(direction_key):
            return false
        var entry: Dictionary = directions[direction_key]
        for texture_key: String in ["textura_frente", "textura_tras"]:
            if not entry.has(texture_key):
                return false
            var texture_path := deformable_skirt.pasta_texturas.path_join(
                String(entry[texture_key])
            )
            if not ResourceLoader.exists(texture_path):
                return false
        if (entry.get("poligono", []) as Array).is_empty():
            return false
        if (entry.get("triangulos", []) as Array).is_empty():
            return false
        var weights: Dictionary = entry.get("pesos", {})
        if not weights.has("coxa_e") or not weights.has("coxa_d"):
            return false
    return true


func _ensure_loaded() -> bool:
    if not _clothes_data.is_empty():
        return true
    if metadata_path.is_empty() or not FileAccess.file_exists(metadata_path):
        push_error("roupas.json não encontrado: %s" % metadata_path)
        return false

    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
    if not parsed is Dictionary:
        push_error("JSON de roupas inválido: %s" % metadata_path)
        return false

    var root := parsed as Dictionary
    if not root.has("roupas") or not root["roupas"] is Dictionary:
        push_error("Campo 'roupas' ausente no JSON")
        return false

    _clothes_data = root["roupas"] as Dictionary
    return true
```

### Crie o catálogo `.tres`

1. Clique com o botão direito em `res://data/character_customization/`.
2. Escolha **New > Resource**.
3. Procure `ClothingCatalog`.
4. Salve como `default_clothing_catalog.tres`.
5. Configure:

   ```text
   Metadata Path:
   res://assets/characters/cutout/clothing/roupas.json

   Textures Root:
   res://assets/characters/cutout/clothing

   Deformable Skirt:
   default_skirt.tres
   ```

6. Em `Items`, defina o tamanho do array como `10`.
7. Arraste os dez recursos `.tres`, incluindo `saia.tres`, para o array.

## 11. Crie CharacterAppearance

Crie `character_appearance.gd`:

```gdscript
class_name CharacterAppearance
extends Resource

const SLOTS: Array[StringName] = [
    &"top",
    &"outerwear",
    &"bottom",
    &"footwear",
    &"eyewear",
    &"headwear",
]

@export_category("Body")
@export_enum("masc", "fem") var body_type: String = "masc"

@export_category("Equipped clothing")
@export var top: StringName = &""
@export var outerwear: StringName = &""
@export var bottom: StringName = &""
@export var footwear: StringName = &""
@export var eyewear: StringName = &""
@export var headwear: StringName = &""


func set_body_type(new_body_type: String) -> void:
    if new_body_type != "masc" and new_body_type != "fem":
        push_error("Gênero/corpo inválido: %s" % new_body_type)
        return
    body_type = new_body_type
    emit_changed()


func get_item(slot_name: StringName) -> StringName:
    match slot_name:
        &"top":
            return top
        &"outerwear":
            return outerwear
        &"bottom":
            return bottom
        &"footwear":
            return footwear
        &"eyewear":
            return eyewear
        &"headwear":
            return headwear
    push_error("Slot desconhecido: %s" % slot_name)
    return &""


func set_item(slot_name: StringName, item_id: StringName) -> void:
    match slot_name:
        &"top":
            top = item_id
        &"outerwear":
            outerwear = item_id
        &"bottom":
            bottom = item_id
        &"footwear":
            footwear = item_id
        &"eyewear":
            eyewear = item_id
        &"headwear":
            headwear = item_id
        _:
            push_error("Slot desconhecido: %s" % slot_name)
            return
    emit_changed()


func get_equipped_items() -> Array[StringName]:
    var result: Array[StringName] = []
    for slot_name: StringName in SLOTS:
        var item_id := get_item(slot_name)
        if item_id != &"":
            result.append(item_id)
    return result


func snapshot() -> CharacterAppearance:
    return duplicate(true) as CharacterAppearance
```

### Crie a aparência padrão

1. Crie um Resource `CharacterAppearance`.
2. Salve como `default_character_appearance.tres`.
3. Configure inicialmente:

   ```text
   Body Type: masc
   Top: camisa
   Outerwear: vazio
   Bottom: calca
   Footwear: sapato
   Eyewear: vazio
   Headwear: vazio
   ```

## 12. Crie o estado oficial da aparência

Crie `res://gameplay/player/character_appearance_state.gd`:

```gdscript
class_name CharacterAppearanceState
extends Node

signal appearance_changed(appearance: CharacterAppearance)

@export_category("Configuration")
@export var default_appearance: CharacterAppearance
@export var catalog: ClothingCatalog

var _current: CharacterAppearance


func _ready() -> void:
    if default_appearance == null:
        push_error("AppearanceState precisa de Default Appearance")
        return
    if catalog == null:
        push_error("AppearanceState precisa de Clothing Catalog")
        return

    _current = default_appearance.snapshot()
    call_deferred("_publish_current")


func get_snapshot() -> CharacterAppearance:
    if _current == null:
        push_error("AppearanceState ainda não possui aparência atual")
        return CharacterAppearance.new()
    return _current.snapshot()


func apply_appearance(candidate: CharacterAppearance) -> void:
    if candidate == null:
        push_error("Tentativa de aplicar aparência nula")
        return

    var validated := candidate.snapshot()
    if validated.body_type != "masc" and validated.body_type != "fem":
        validated.body_type = "masc"

    for slot_name: StringName in CharacterAppearance.SLOTS:
        var item_id := validated.get_item(slot_name)
        if item_id == &"":
            continue
        if not catalog.is_item_in_slot(item_id, slot_name):
            push_warning("Item %s removido do slot inválido %s" % [item_id, slot_name])
            validated.set_item(slot_name, &"")
            continue
        if not catalog.is_item_complete(item_id, validated.body_type):
            push_warning("Item incompleto removido: %s" % item_id)
            validated.set_item(slot_name, &"")

    _current = validated
    _publish_current()


func _publish_current() -> void:
    if _current != null:
        appearance_changed.emit(_current.snapshot())
```

Por que duplicar?

Um `.tres` é compartilhado. Se o menu alterar diretamente `default_character_appearance.tres`, cancelar não funcionará e o arquivo poderá ficar modificado. `snapshot()` cria uma cópia segura.

## 13. Adicione AppearanceState ao Player

Abra `res://gameplay/player/player.tscn`.

1. Selecione o nó `Player`.
2. Adicione um filho `Node`.
3. Nomeie exatamente `AppearanceState`.
4. Anexe `character_appearance_state.gd`.
5. No Inspector do `AppearanceState`, configure:

   ```text
   Default Appearance = default_character_appearance.tres
   Catalog = default_clothing_catalog.tres
   ```

A árvore ficará:

```text
Player
├── AppearanceState
├── CollisionShape2D
└── VisualAnchor
    └── CharacterVisual
```

Ainda não conecte o sinal; primeiro criaremos `present_appearance`.

## 14. Exponha os ossos com segurança

Abra `character_rig.gd` e adicione antes das funções privadas:

```gdscript
func get_piece_bone(piece_name: StringName) -> Bone2D:
    var key := String(piece_name)
    if not _pieces.has(key):
        return null
    var nodes: Dictionary = _pieces[key]
    return nodes["bone"] as Bone2D


func get_current_direction() -> StringName:
    return _current_direction
```

O renderizador de roupas não deve acessar `_pieces` diretamente porque `_pieces` é detalhe interno do rig.

## 15. Crie a cena reutilizável ClothingPiece

1. Crie uma nova cena com raiz `Sprite2D`.
2. Nomeie a raiz `ClothingPiece`.
3. Configure:

   ```text
   Position: (0, 0)
   Rotation: 0
   Scale: (1, 1)
   Centered: On
   Z Index: 0
   Z As Relative: On
   Texture > Filter: Parent Node
   ```

4. Não coloque textura fixa.
5. Salve como:

   ```text
   res://presentation/characters/cutout/clothing_piece.tscn
   ```

A quantidade de pedaços das roupas rígidas depende do equipamento. Por isso o `WardrobePresenter` pode instanciar essa cena dinamicamente. A saia é uma cena complexa previsível e permanece instanciada no `CharacterVisual`, apenas alternando visibilidade e configuração.

## 16. Crie WardrobePresenter

Crie `wardrobe_presenter.gd`:

```gdscript
class_name WardrobePresenter
extends Node

@export_category("References")
@export var catalog: ClothingCatalog
@export var clothing_piece_scene: PackedScene
@export var rig: CharacterRig
@export var skirt: SaiaMalha

var _spawned_pieces: Array[Sprite2D] = []
var _last_signature: String = ""


func present(appearance: CharacterAppearance, direction: StringName) -> void:
    if (
        appearance == null
        or catalog == null
        or rig == null
        or clothing_piece_scene == null
        or skirt == null
    ):
        push_error("WardrobePresenter está sem referência obrigatória")
        return

    var signature := _make_signature(appearance, direction)
    if signature == _last_signature:
        return

    _clear_spawned_pieces()

    var equipped := appearance.get_equipped_items()
    equipped.sort_custom(_sort_items_by_layer)

    for item_id: StringName in equipped:
        _spawn_item(item_id, appearance.body_type, direction)

    _last_signature = signature


func invalidate() -> void:
    _last_signature = ""


func _spawn_item(item_id: StringName, body_type: String, direction: StringName) -> void:
    var item := catalog.get_item(item_id)
    if item == null:
        push_error("Roupa sem ClothingItem: %s" % item_id)
        return

    if item.visual_type == "deformable_skirt":
        skirt.equipar(StringName(body_type), direction)
        return

    var pieces := catalog.get_piece_data(item_id, body_type, direction)
    for piece_name: String in pieces:
        var bone := rig.get_piece_bone(StringName(piece_name))
        if bone == null:
            push_error("Osso da roupa não encontrado: %s" % piece_name)
            continue

        var piece_data: Dictionary = pieces[piece_name]
        var sprite := clothing_piece_scene.instantiate() as Sprite2D
        sprite.name = "Clothing_%s_%s" % [item_id, piece_name]
        sprite.position = Vector2.ZERO
        sprite.rotation = 0.0
        sprite.scale = Vector2.ONE
        sprite.z_index = 0
        sprite.z_as_relative = true
        sprite.offset = _parse_vector2(piece_data["offset_sprite"])
        sprite.texture = catalog.load_piece_texture(String(piece_data["arquivo"]))

        bone.add_child(sprite)
        _spawned_pieces.append(sprite)


func _clear_spawned_pieces() -> void:
    skirt.remover()
    for sprite: Sprite2D in _spawned_pieces:
        if not is_instance_valid(sprite):
            continue
        var parent := sprite.get_parent()
        if parent != null:
            parent.remove_child(sprite)
        sprite.queue_free()
    _spawned_pieces.clear()


func _sort_items_by_layer(a: StringName, b: StringName) -> bool:
    return catalog.get_layer_order(a) < catalog.get_layer_order(b)


func _make_signature(appearance: CharacterAppearance, direction: StringName) -> String:
    return "%s|%s|%s|%s|%s|%s|%s|%s" % [
        appearance.body_type,
        direction,
        appearance.top,
        appearance.outerwear,
        appearance.bottom,
        appearance.footwear,
        appearance.eyewear,
        appearance.headwear,
    ]


func _parse_vector2(value: Variant) -> Vector2:
    if value is Array:
        var coordinates := value as Array
        if coordinates.size() == 2:
            return Vector2(float(coordinates[0]), float(coordinates[1]))
    push_error("offset_sprite inválido: %s" % value)
    return Vector2.ZERO
```

Não use o campo `ordem` como `z_index` do Sprite. O esqueleto já usa `z_index` para perspectiva. O presenter lê `ordem` do JSON e cria as roupas da menor para a maior; no mesmo osso, o irmão criado depois aparece por cima.

## 17. Adicione WardrobePresenter ao CharacterVisual

Abra `character_visual.tscn`.

1. Selecione `CharacterVisual`.
2. Instancie `res://presentation/characters/cutout/skirt/saia_deformavel.tscn` como filha direta de `CharacterVisual`, fora do `Skeleton2D`.
3. Selecione a instância `SaiaDeformavel` e configure:

   ```text
   Recurso = default_skirt.tres
   Esqueleto = ../Skeleton2D
   Osso Quadril = ../Skeleton2D/quadril
   Osso Coxa Esq = ../Skeleton2D/quadril/coxa_e
   Osso Coxa Dir = ../Skeleton2D/quadril/coxa_d
   ```

4. Selecione `CharacterVisual` novamente e adicione um filho `Node`.
5. Nomeie `WardrobePresenter`.
6. Anexe `wardrobe_presenter.gd`.
7. Configure no Inspector:

   ```text
   Catalog = default_clothing_catalog.tres
   Clothing Piece Scene = clothing_piece.tscn
   Rig = ../Skeleton2D
   Skirt = ../SaiaDeformavel
   ```

A árvore ficará:

```text
CharacterVisual
├── Skeleton2D
├── SaiaDeformavel
│   ├── SaiaTras
│   ├── SaiaFrente
│   └── SaiaBalanco
├── WardrobePresenter
└── AnimationPlayer
```

Em execução, `SaiaMalha` cria sete `Bone2D` sob `quadril`. Isso é intencional: a posição de repouso deles muda conforme a direção. Os dois `Polygon2D` permanecem visíveis e configuráveis na cena, cumprindo a arquitetura visual do projeto.

## 18. Faça CharacterVisual apresentar aparência

Em `character_visual.gd`, adicione:

```gdscript
@onready var wardrobe_presenter: WardrobePresenter = $WardrobePresenter

var _appearance: CharacterAppearance = CharacterAppearance.new()
```

No final de `_ready()`, antes ou depois de iniciar o idle, aplique:

```gdscript
wardrobe_presenter.present(_appearance, _direction)
```

Adicione esta API pública:

```gdscript
func present_appearance(appearance: CharacterAppearance) -> void:
    if appearance == null:
        return

    _appearance = appearance.snapshot()
    rig.set_body(_appearance.body_type)
    wardrobe_presenter.invalidate()
    wardrobe_presenter.present(_appearance, _direction)
    _current_animation = &""
    _refresh_locomotion_animation()
```

Atualize `present_locomotion()` para também sincronizar a roupa depois da direção:

```gdscript
func present_locomotion(
    direction: StringName,
    is_moving: bool,
    is_running: bool = false
) -> void:
    _direction = direction
    _is_moving = is_moving
    _is_running = is_moving and is_running
    rig.set_direction(direction)
    wardrobe_presenter.present(_appearance, direction)
    _refresh_locomotion_animation()
```

Mantenha `present_body()` por compatibilidade, mas faça-o usar a aparência:

```gdscript
func present_body(body_type: String) -> void:
    var updated := _appearance.snapshot()
    updated.set_body_type(body_type)
    present_appearance(updated)
```

## 19. Conecte AppearanceState ao visual do Player

Abra `player.tscn`.

1. Selecione `AppearanceState`.
2. Abra a aba **Node > Signals**.
3. Dê duplo clique em `appearance_changed`.
4. Escolha o nó `VisualAnchor/CharacterVisual`.
5. Escolha o método existente `present_appearance`.
6. Confirme.

Fluxo resultante:

```text
AppearanceState.appearance_changed
└── CharacterVisual.present_appearance
```

## 20. Crie uma linha reutilizável de opção

Crie `customization_slot_row.gd`:

```gdscript
class_name CustomizationSlotRow
extends HBoxContainer

signal selection_changed(slot: StringName, item_id: StringName)

@export_enum("top", "outerwear", "bottom", "footwear", "eyewear", "headwear")
var slot: String = "top"
@export var label_text: String = "Roupa"

@onready var slot_label: Label = %SlotLabel
@onready var selector: OptionButton = %Selector


func _ready() -> void:
    slot_label.text = label_text


func setup(
    catalog: ClothingCatalog,
    body_type: String,
    selected_item: StringName
) -> void:
    selector.clear()
    selector.add_item("Nenhum")
    selector.set_item_metadata(0, &"")

    var selected_index := 0
    for item: ClothingItem in catalog.get_items_for_slot(StringName(slot)):
        if not catalog.is_item_complete(item.id, body_type):
            continue
        selector.add_item(item.display_name)
        var index := selector.item_count - 1
        selector.set_item_metadata(index, item.id)
        if item.id == selected_item:
            selected_index = index

    selector.select(selected_index)


func _on_selector_item_selected(index: int) -> void:
    var metadata: Variant = selector.get_item_metadata(index)
    selection_changed.emit(StringName(slot), StringName(String(metadata)))
```

Crie `customization_slot_row.tscn`:

```text
CustomizationSlotRow (HBoxContainer)
├── SlotLabel (Label) [Unique Name]
└── Selector (OptionButton) [Unique Name]
```

Selecione a raiz `CustomizationSlotRow`, clique em **Attach Script** e escolha o arquivo `customization_slot_row.gd` que acabou de criar.

Configure:

- `CustomizationSlotRow`: Size Flags Horizontal = Fill + Expand.
- `SlotLabel`: Custom Minimum Size X = `150`.
- `Selector`: Size Flags Horizontal = Fill + Expand.

Conecte, pela aba Node, `Selector.item_selected` ao método `_on_selector_item_selected` da raiz.

## 21. Monte o menu de personalização

Crie `character_customization_menu.tscn` com raiz `Control`.

Use esta árvore:

```text
CharacterCustomizationMenu (Control)
├── DimBackground (ColorRect)
└── SafeMargin (MarginContainer)
    └── Center (CenterContainer)
        └── MainPanel (PanelContainer)
            └── PanelMargin (MarginContainer)
                └── MainColumn (VBoxContainer)
                    ├── TitleLabel (Label)
                    ├── PreviewPanel (PanelContainer)
                    │   └── PreviewCenter (CenterContainer)
                    │       └── PreviewContainer (SubViewportContainer)
                    │           └── PreviewViewport (SubViewport)
                    │               └── PreviewRoot (Node2D)
                    │                   ├── CharacterVisual (instância)
                    │                   └── Camera2D
                    ├── DirectionRow (HBoxContainer)
                    │   ├── DirectionLabel (Label)
                    │   ├── NEButton (Button)
                    │   ├── NWButton (Button)
                    │   ├── SEButton (Button)
                    │   └── SWButton (Button)
                    ├── OptionsScroll (ScrollContainer)
                    │   └── OptionsColumn (VBoxContainer)
                    │       ├── GenderRow (HBoxContainer)
                    │       │   ├── GenderLabel (Label)
                    │       │   ├── MascButton (Button)
                    │       │   └── FemButton (Button)
                    │       ├── TopRow (instância de CustomizationSlotRow)
                    │       ├── OuterwearRow (instância)
                    │       ├── BottomRow (instância)
                    │       ├── FootwearRow (instância)
                    │       ├── EyewearRow (instância)
                    │       └── HeadwearRow (instância)
                    └── ActionRow (HBoxContainer)
                        ├── CancelButton (Button)
                        └── ConfirmButton (Button)
```

### Layout da raiz

1. Selecione `CharacterCustomizationMenu`.
2. Use **Layout > Full Rect**.
3. Desmarque Visible, porque o menu começa fechado.
4. Em Mouse > Filter, use `Stop`.

### Fundo

1. Selecione `DimBackground`.
2. Use **Layout > Full Rect**.
3. Use uma cor como `Color(0, 0, 0, 0.70)`.

### Margens e painel

1. `SafeMargin`: Full Rect.
2. Margens: `16` nos quatro lados.
3. `MainPanel`: Custom Minimum Size `(320, 0)` e Size Flags Vertical = Fill + Expand.
4. `PanelMargin`: margens internas `20`.
5. `MainColumn`: Separation `12`.
6. `TitleLabel`: texto `PERSONALIZAR PERSONAGEM`, alinhamento central.
7. `OptionsScroll`: Size Flags Vertical = Fill + Expand e Custom Minimum Size Y aproximadamente `180`.

Não fixe a altura do painel em `620`: com as margens isso pode ultrapassar telas baixas. O `OptionsScroll` existe justamente para permitir rolagem.

### Preview

1. `PreviewPanel`: Custom Minimum Size Y = `240`.
2. `PreviewContainer`: Custom Minimum Size `(256, 256)`.
3. `PreviewContainer`: Stretch = Off.
4. `PreviewViewport`: Size `(256, 256)`.
5. `PreviewViewport`: Transparent Bg = On.
6. Instancie `character_visual.tscn` em `PreviewRoot`.
7. Coloque o `CharacterVisual` em `(0, 0)`.
8. Ative `Camera2D` e use Position aproximadamente `(0, -38)`.

Não procure uma propriedade `Own World 2D`: ela não existe no `SubViewport` do Godot 4.6. Cada viewport já possui seu contexto 2D. A propriedade semelhante disponível no Inspector é relacionada ao mundo 3D e não é necessária aqui.

Se o personagem parecer pequeno, ajuste `Camera2D.zoom`; não altere a escala do Skeleton usado pelo Player.

### Linhas de slot

Configure as seis instâncias:

| Nó | Slot | Label Text |
|---|---|---|
| TopRow | `top` | Camisa |
| OuterwearRow | `outerwear` | Jaqueta |
| BottomRow | `bottom` | Parte inferior |
| FootwearRow | `footwear` | Calçado |
| EyewearRow | `eyewear` | Óculos |
| HeadwearRow | `headwear` | Cabeça |

Marque como **Unique Name in Owner**:

```text
CharacterVisual do preview
MascButton
FemButton
NEButton
NWButton
SEButton
SWButton
TopRow
OuterwearRow
BottomRow
FootwearRow
EyewearRow
HeadwearRow
```

Nos botões `MascButton` e `FemButton`:

1. Ative **Toggle Mode**.
2. Crie um `ButtonGroup` no Inspector.
3. Coloque os dois no mesmo `ButtonGroup`.
4. Deixe **Allow Unpress** desligado.

Repita o processo com `NEButton`, `NWButton`, `SEButton` e `SWButton`, usando outro `ButtonGroup`. Marque inicialmente `SEButton` como pressionado.

Configure os textos para não terminar com botões vazios:

| Nó | Text |
|---|---|
| GenderLabel | Gênero |
| MascButton | Masculino |
| FemButton | Feminino |
| DirectionLabel | Direção |
| NEButton | NE |
| NWButton | NW |
| SEButton | SE |
| SWButton | SW |
| CancelButton | Cancelar |
| ConfirmButton | Confirmar |

## 22. Script do menu

Crie `character_customization_menu.gd`:

```gdscript
class_name CharacterCustomizationMenu
extends Control

signal appearance_confirmed(appearance: CharacterAppearance)
signal customization_cancelled
signal menu_opened
signal menu_closed

@export_category("Configuration")
@export var catalog: ClothingCatalog

@onready var preview: CharacterVisual = %CharacterVisual
@onready var masc_button: Button = %MascButton
@onready var fem_button: Button = %FemButton
@onready var ne_button: Button = %NEButton
@onready var nw_button: Button = %NWButton
@onready var se_button: Button = %SEButton
@onready var sw_button: Button = %SWButton

@onready var rows: Array[CustomizationSlotRow] = [
    %TopRow as CustomizationSlotRow,
    %OuterwearRow as CustomizationSlotRow,
    %BottomRow as CustomizationSlotRow,
    %FootwearRow as CustomizationSlotRow,
    %EyewearRow as CustomizationSlotRow,
    %HeadwearRow as CustomizationSlotRow,
]

var _working: CharacterAppearance
var _preview_direction: StringName = &"se"


func _ready() -> void:
    hide()


func open(source: CharacterAppearance) -> void:
    if source == null or catalog == null:
        push_error("Menu recebeu aparência ou catálogo nulo")
        return

    _working = source.snapshot()
    _preview_direction = &"se"
    se_button.button_pressed = true
    _refresh_everything()
    show()
    menu_opened.emit()


func _refresh_everything() -> void:
    masc_button.button_pressed = _working.body_type == "masc"
    fem_button.button_pressed = _working.body_type == "fem"

    for row: CustomizationSlotRow in rows:
        row.setup(
            catalog,
            _working.body_type,
            _working.get_item(StringName(row.slot))
        )

    preview.present_appearance(_working)
    preview.present_locomotion(_preview_direction, false, false)


func _refresh_preview() -> void:
    preview.present_appearance(_working)
    preview.present_locomotion(_preview_direction, false, false)


func _on_slot_selection_changed(slot: StringName, item_id: StringName) -> void:
    _working.set_item(slot, item_id)
    _refresh_preview()


func _on_masc_button_pressed() -> void:
    _working.set_body_type("masc")
    _refresh_everything()


func _on_fem_button_pressed() -> void:
    _working.set_body_type("fem")
    _refresh_everything()


func _on_ne_button_pressed() -> void:
    _set_preview_direction(&"ne")


func _on_nw_button_pressed() -> void:
    _set_preview_direction(&"nw")


func _on_se_button_pressed() -> void:
    _set_preview_direction(&"se")


func _on_sw_button_pressed() -> void:
    _set_preview_direction(&"sw")


func _set_preview_direction(direction: StringName) -> void:
    _preview_direction = direction
    ne_button.button_pressed = direction == &"ne"
    nw_button.button_pressed = direction == &"nw"
    se_button.button_pressed = direction == &"se"
    sw_button.button_pressed = direction == &"sw"
    preview.present_locomotion(direction, false, false)


func _on_confirm_button_pressed() -> void:
    appearance_confirmed.emit(_working.snapshot())
    _close()


func _on_cancel_button_pressed() -> void:
    customization_cancelled.emit()
    _close()


func _close() -> void:
    hide()
    menu_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        customization_cancelled.emit()
        _close()
        get_viewport().set_input_as_handled()
```

Selecione a raiz `CharacterCustomizationMenu`, clique em **Attach Script** e escolha `character_customization_menu.gd`.

No Inspector da raiz do menu:

```text
Catalog = default_clothing_catalog.tres
```

## 23. Conecte os sinais internos do menu

Use a aba **Node > Signals**. Não digite caminhos de nós manualmente.

Conecte:

```text
MascButton.pressed       → _on_masc_button_pressed
FemButton.pressed        → _on_fem_button_pressed
NEButton.pressed          → _on_ne_button_pressed
NWButton.pressed          → _on_nw_button_pressed
SEButton.pressed          → _on_se_button_pressed
SWButton.pressed          → _on_sw_button_pressed
ConfirmButton.pressed     → _on_confirm_button_pressed
CancelButton.pressed      → _on_cancel_button_pressed
```

Em cada linha de roupa, conecte `selection_changed` ao método:

```text
_on_slot_selection_changed
```

Todos enviam os mesmos dois argumentos: `slot` e `item_id`.

## 24. Adicione o botão ao HUD

Abra `hud.tscn`.

Dentro de:

```text
HUD/SafeMargin/HUDColumn/StatusPanel/PanelMargin/Content
```

adicione:

```text
CustomizeButton (Button)
```

Configure:

```text
Text = PERSONALIZAR
Size Flags Horizontal = Fill + Expand
```

Em `hud.gd`, adicione:

```gdscript
signal customization_requested


func _on_customize_button_pressed() -> void:
    customization_requested.emit()
```

Conecte `CustomizeButton.pressed` a `_on_customize_button_pressed`.

O HUD apenas pede a abertura. Ele não procura o menu e não altera o jogador.

## 25. Bloqueie o movimento enquanto o menu estiver aberto

Em `player_controller.gd`, adicione:

```gdscript
var _controls_enabled: bool = true
```

Adicione a API:

```gdscript
func set_controls_enabled(enabled: bool) -> void:
    if _controls_enabled == enabled:
        return

    _controls_enabled = enabled
    if not enabled:
        velocity = Vector2.ZERO
        if _was_moving or _was_running:
            locomotion_changed.emit(_facing_direction, false, false)
        _was_moving = false
        _was_running = false
```

No começo de `_physics_process`, depois de validar a configuração, coloque:

```gdscript
if not _controls_enabled:
    velocity = Vector2.ZERO
    return
```

O PlayerController não sabe que existe um menu. Ele só conhece “controles habilitados” ou “desabilitados”.

## 26. Instancie o menu no Main

Abra `main.tscn`.

1. Selecione `Interface`.
2. Instancie `character_customization_menu.tscn`.
3. Deixe-o depois do HUD, para aparecer por cima.

Resultado:

```text
Main
├── World
│   └── Entities
│       └── Player
│           ├── AppearanceState
│           ├── CollisionShape2D
│           ├── Camera2D
│           └── VisualAnchor
│               └── CharacterVisual
│                   ├── Skeleton2D
│                   ├── SaiaDeformavel
│                   ├── WardrobePresenter
│                   └── AnimationPlayer
└── Interface
    ├── HUD
    └── CharacterCustomizationMenu
```

## 27. Faça o Main conectar tudo

Em `main.gd`, acrescente referências exportadas:

```gdscript
@export var appearance_state: CharacterAppearanceState
@export var customization_menu: CharacterCustomizationMenu
```

Em `_ready()`, depois das conexões atuais:

```gdscript
hud.customization_requested.connect(_on_customization_requested)
customization_menu.appearance_confirmed.connect(_on_appearance_confirmed)
customization_menu.menu_opened.connect(_on_customization_menu_opened)
customization_menu.menu_closed.connect(_on_customization_menu_closed)
```

Adicione:

```gdscript
func _on_customization_requested() -> void:
    customization_menu.open(appearance_state.get_snapshot())


func _on_appearance_confirmed(appearance: CharacterAppearance) -> void:
    appearance_state.apply_appearance(appearance)


func _on_customization_menu_opened() -> void:
    player.set_controls_enabled(false)


func _on_customization_menu_closed() -> void:
    player.set_controls_enabled(true)
```

O bloqueio acontece somente depois que `open()` realmente conseguiu abrir o menu. Assim, uma referência ausente no menu não deixa o Player permanentemente travado.

Atualize `_references_are_valid()` para também verificar:

```gdscript
if appearance_state == null:
    push_error("Main: referência AppearanceState não configurada.")
    return false
if customization_menu == null:
    push_error("Main: referência CharacterCustomizationMenu não configurada.")
    return false
```

Na raiz `Main`, arraste pelo Inspector:

```text
Appearance State = World/Entities/Player/AppearanceState
Customization Menu = Interface/CharacterCustomizationMenu
```

## 28. Primeiro teste em partes

Não teste tudo ao mesmo tempo. Siga esta ordem.

### Teste A — catálogo

1. Execute o projeto.
2. Abra o menu. Isso valida os dez itens masculinos ao preencher as listas.
3. Troque para feminino. Isso valida novamente os dez itens para o outro corpo.
4. Abra Debugger > Errors.
5. Não deve aparecer `roupas.json não encontrado`.
6. Não deve aparecer `PNG de roupa não encontrado`.

Se aparecer, confira `Metadata Path` e `Textures Root` no catálogo.

### Teste B — roupa padrão no Player

Ao iniciar, o personagem deve usar:

```text
camisa + calça + sapato
```

Ande e corra. As roupas devem acompanhar braços e pernas.

### Teste C — menu

1. Clique em PERSONALIZAR.
2. O Player deve parar.
3. O menu deve aparecer por cima do HUD.
4. O preview deve mostrar outro personagem.

### Teste D — gênero

1. Selecione feminino.
2. Corpo e roupas devem mudar no preview.
3. Volte para masculino.
4. As opções equipadas devem permanecer.

### Teste E — quatro ângulos

Clique:

```text
NE → NW → SE → SW
```

Confira especialmente:

- braço da frente;
- manga da jaqueta;
- perna da frente;
- óculos e chapéu;
- alinhamento de sapato e chinelo.
- `SaiaTras` atrás das pernas e `SaiaFrente` à frente;
- tecido acompanhando as coxas sem virar uma placa rígida.

O preview foi intencionalmente configurado em `idle`, para facilitar a inspeção. `walk` e `run` são testados no Player real depois de confirmar a aparência.

### Teste F — confirmar

1. Escolha roupas.
2. Clique Confirmar.
3. O menu deve fechar.
4. O Player real deve assumir a aparência.
5. O movimento deve voltar.

### Teste G — cancelar

1. Abra novamente.
2. Troque todas as opções.
3. Clique Cancelar ou pressione Esc.
4. O Player real deve continuar com a aparência anterior.

## 29. Matriz mínima de validação

Para cada caso de roupa listado abaixo, teste:

```text
2 gêneros
× 4 direções
× 3 estados (idle, walk, run)
```

Casos importantes:

```text
nenhuma roupa
cada roupa individualmente
camisa + jaqueta
óculos + boné
óculos escuros + chapéu
calça + sapato
calça + chinelo
saia + sapato
saia + chinelo
todas as camadas simultaneamente
```

Contagem esperada no `Remote Scene Tree`:

| Caso | Quantidade de nós `Clothing_*` |
|---|---:|
| Tudo removido | 0 |
| Camisa | 3 |
| Jaqueta | 5 |
| Calça | 5 |
| Saia | 0 `Clothing_*`, 2 Polygon2D e 7 ossos próprios |
| Sapato ou chinelo | 2 |
| Cada tipo de óculos | 1 |
| Cada boné ou chapéu | 1 |
| Camisa + jaqueta | 8 |
| Conjunto máximo | 17 |

Com saia no conjunto máximo, serão `12` nós `Clothing_*`, mais os dois painéis `SaiaFrente/SaiaTras` e os sete ossos próprios da saia.

Também confirme:

- selecionar `Nenhum` realmente remove a roupa;
- trocar sapato por chinelo não deixa o sapato antigo;
- trocar óculos comum por escuro não duplica acessórios;
- alternar gênero e direção repetidamente não aumenta a contagem de nós;
- abrir, cancelar e confirmar várias vezes não duplica sprites;
- em zoom 2× ou 4×, a pixel art continua nítida com `Nearest`;
- mangas da frente e de trás continuam corretas durante caminhada e corrida.
- trocar `calça → saia → Nenhum → calça` não deixa nenhuma camada antiga;
- a saia repousa sem tremor no idle;
- ao correr, parar, virar ou trocar gênero, o balanço reinicia sem dar um salto;
- `SaiaTras` continua atrás das duas pernas e `SaiaFrente` continua na frente nas quatro direções;
- no `Remote Scene Tree`, equipar/remover repetidamente não cria mais que sete ossos próprios da saia.

## 30. Erros comuns

### A roupa aparece, mas não acompanha o braço

Ela foi colocada no lugar errado.

Errado:

```text
CharacterVisual
└── ClothingSprite
```

Certo:

```text
braco_sup_e (Bone2D)
├── Sprite
└── Clothing_camisa_braco_sup_e
```

### A roupa está deslocada

Você ignorou `offset_sprite` ou somou o offset do corpo. Use somente o offset específico da roupa.

### Jaqueta aparece atrás da camisa

Confira:

```text
camisa ordem = 1 no roupas.json
jaqueta ordem = 2 no roupas.json
```

O presenter precisa ordenar antes de instanciar.

### Óculos ficam sobre o chapéu de modo estranho

Confira:

```text
óculos ordem 2
chapéu/boné ordem 3
```

Não use `z_index` da roupa para resolver isso.

### Roupa desaparece quando vira

`present_locomotion()` não chamou:

```gdscript
wardrobe_presenter.present(_appearance, direction)
```

### Trocar gênero mantém roupa masculina

O presenter não foi invalidado ou não recebeu `appearance.body_type`.

### A saia não aparece

Confira separadamente:

- `saia.tres`: Visual Type = `deformable_skirt`;
- `default_clothing_catalog.tres`: Deformable Skirt = `default_skirt.tres`;
- `default_skirt.tres`: caminhos de dados e texturas;
- `SaiaDeformavel`: referências ao Skeleton2D, quadril e duas coxas;
- `WardrobePresenter`: propriedade Skirt apontando para `SaiaDeformavel`;
- `saia_malha.json` e os 16 PNGs dentro de `res://`.

Não tente consertar criando `quadril.png`: esse era o formato rígido antigo e não pertence à saia nova.

### Cancelar altera o Player mesmo assim

O menu recebeu o Resource oficial sem duplicar. Use `snapshot()` ao abrir, confirmar e publicar.

### O Player continua andando atrás do menu

Confira `player.set_controls_enabled(false)` ao abrir e `true` ao confirmar/cancelar.

### Preview aparece vazio

Confira:

- `SubViewport.size = 256 × 256`;
- `Transparent Bg = On`;
- `Camera2D.enabled = On`;
- posição da câmera aproximadamente `(0, -38)`;
- `CharacterVisual` instanciado dentro de `PreviewRoot`.

### As opções do OptionButton estão vazias

Confira:

- catálogo atribuído ao menu;
- dez ClothingItems dentro do catálogo;
- Slot correto em cada `.tres`;
- assets copiados para `res://`.

## 31. Como adicionar uma roupa nova depois

Para uma segunda camisa, não sobrescreva `camisa`.

Use uma estrutura como:

```text
camisa_azul/
├── masc/ne/...
├── masc/nw/...
├── masc/se/...
├── masc/sw/...
├── fem/ne/...
├── fem/nw/...
├── fem/se/...
└── fem/sw/...
```

Depois:

1. Adicione `camisa_azul` ao JSON.
2. Crie `camisa_azul.tres` como ClothingItem.
3. Use Slot `top`.
4. No JSON, use `ordem: 1`.
5. Adicione o recurso ao array do catálogo.
6. Teste dois gêneros e quatro direções.

O menu se preencherá pelo catálogo, sem criar um botão especial por código.

## 32. Salvamento opcional

Primeiro faça todo o sistema funcionar. Depois salve apenas IDs simples:

```text
body_type=masc
top=camisa
outerwear=jaqueta
bottom=calca
footwear=sapato
eyewear=oculos
headwear=bone
```

Não salve texturas, nós nem o Resource inteiro. Salve strings e reconstrua `CharacterAppearance` ao carregar.

## 33. Prepare a exportação do jogo

No editor, tudo pode funcionar e ainda faltar arquivo no `.exe`: `roupas.json` e os caminhos dos PNGs são descobertos dinamicamente, portanto não aparecem como dependências estáticas de uma cena.

Antes de exportar:

1. Abra **Project > Export**.
2. Selecione ou crie o preset da plataforma.
3. Abra a seção **Resources**.
4. Em **Export Mode**, escolha **Export All Resources in the Project**.
5. Em **Filters to export non-resource files/folders**, coloque:

   ```text
   *.json
   ```

Isso inclui `roupas.json`, `saia_malha.json` e também protege os `rig.json` masculino e feminino já usados pelo personagem.

Depois de gerar o executável, teste novamente abrir o menu, trocar gênero, vestir cada categoria e andar nas quatro direções.

## 34. Checklist final

- [ ] Os 184 PNGs estão dentro de `res://`.
- [ ] `roupas.json` está dentro de `res://`.
- [ ] `saia_malha.json` está dentro de `res://`.
- [ ] Existem dez `ClothingItem.tres`, incluindo `saia.tres`.
- [ ] Existe um `ClothingCatalog.tres` com os dez itens.
- [ ] O catálogo aponta para `default_skirt.tres`.
- [ ] CharacterVisual possui a instância `SaiaDeformavel` fora do Skeleton2D.
- [ ] A saia cria sete ossos próprios e dois Polygon2D sem erros.
- [ ] `SaiaTras` fica atrás e `SaiaFrente` fica à frente das pernas nas quatro direções.
- [ ] A saia acompanha walk/run e volta ao repouso sem tremor no idle.
- [ ] Trocar calça, saia e Nenhum não deixa camadas antigas.
- [ ] Existe `default_character_appearance.tres`.
- [ ] O Player possui `AppearanceState`.
- [ ] `AppearanceState.appearance_changed` está conectado ao CharacterVisual.
- [ ] `CharacterRig` expõe `get_piece_bone()`.
- [ ] Existe `clothing_piece.tscn`.
- [ ] CharacterVisual possui `WardrobePresenter`.
- [ ] Roupas atualizam quando a direção muda.
- [ ] Roupas atualizam quando o gênero muda.
- [ ] Camisa fica abaixo da jaqueta.
- [ ] Óculos ficam abaixo de boné/chapéu.
- [ ] O menu usa um CharacterVisual separado no preview.
- [ ] Confirmar altera o Player real.
- [ ] Cancelar preserva o Player real.
- [ ] O Player para enquanto o menu está aberto.
- [ ] Idle, walk e run continuam funcionando.
- [ ] Não existem erros vermelhos no Debugger.

Quando todos os itens estiverem marcados, o sistema estará separado em dados, estado, apresentação, interface e composição, sem transformar `PlayerController`, `CharacterRig` ou o menu em um script responsável por tudo.

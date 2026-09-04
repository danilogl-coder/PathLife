# Idades do personagem — bebê, criança, adolescente, adulto e idoso

> **Estado: já aplicado no projeto.** Todos os arquivos das seções 4 a 12
> existem em `res://` e as edições nos scripts e cenas existentes já foram
> feitas. O que falta é abrir o projeto no editor (para o Godot importar os
> `.tres` novos) e rodar o teste da seção 12. Este documento continua sendo a
> explicação de *por que* cada peça é assim — e o guia para quando você quiser
> mexer nos números, acrescentar uma sexta idade ou dar arte dedicada ao bebê.

Este tutorial adiciona uma segunda dimensão ao personagem. Hoje ele tem **corpo**
(`masc` / `fem`); ao final terá **corpo × idade**, com cinco fases da vida que
mudam proporção, postura, ritmo de animação, velocidade e colisão — e que podem
avançar sozinhas durante a partida.

A regra de sempre continua valendo: nada de `if idade == "bebe"` espalhado pelo
código. Uma idade nova é um `.tres` novo, ajustável no Inspector, e nada mais.

## 1. O que o projeto já tem — e por que isso decide o desenho

Antes de escolher a abordagem, três fatos do rig atual. Eles não são detalhes:
são exatamente o que torna esse sistema barato.

### 1.1 O rig é recortado, com sprites pendurados nos ossos

`presentation/characters/cutout/character_visual.tscn` tem um `Skeleton2D` com 15
`Bone2D`, cada um com um `Sprite2D` filho. `CharacterRig` (`character_rig.gd`) lê
`assets/characters/cutout/<corpo>/rig.json` e, a cada troca de direção, reescreve
`bone.position`, `bone.z_index`, `sprite.offset` e `sprite.texture`.

```text
Skeleton2D
└── quadril            (0.26, -37.87)
    ├── torso          (0.15,  -2.85)
    │   ├── cabeca     (0.00, -16.07)   ← HairRig e chapéu são filhos daqui
    │   ├── braco_sup_e … braco_inf_e … mao_e
    │   └── braco_sup_d … braco_inf_d … mao_d
    ├── coxa_e … perna_e … pe_e
    └── coxa_d … perna_d … pe_d
```

### 1.2 As animações só escrevem `rotation`

Conferi as duas bibliotecas: 40 animações cada (10 ações × 4 direções). Em
**todas** elas, as únicas propriedades animadas são:

| Propriedade animada | Onde |
|---|---|
| `rotation` | nos 15 `Bone2D` |
| `position:y` | só no nó raiz `CharacterVisual` |
| `position:x` | só no nó raiz, e só em `walk`, `run` e `pick` da biblioteca `fem` |

Isso dá três conclusões que o resto do tutorial usa o tempo todo:

- **`Bone2D.position` e `Bone2D.scale` estão livres.** Nada os reescreve a cada
  quadro. É aí que a idade mora: comprimento de perna, tamanho de cabeça e
  largura de corpo mudam sem tocar em uma única animação.
- **`rotation` é território da animação.** Uma coluna curvada de idoso não pode
  ser uma rotação estática no osso — o `AnimationPlayer` a apaga no quadro
  seguinte. Ela precisa ser somada *depois* da animação, todo quadro, do mesmo
  jeito que o `HairPhysicsController` já faz com `process_priority = 100`.
- **A `position` do nó raiz também é território da animação.** Por isso a
  compensação de altura do pé (seção 5.1) vai no `Skeleton2D`, e nunca no
  `CharacterVisual`.

> Detalhe: a animação `RESET`, que mora dentro de `character_visual.tscn` e não
> nas bibliotecas, tem sim um track de `quadril:position`. Ela só é aplicada pelo
> editor (ao salvar a cena com `reset_on_save`), nunca em jogo — e a proporção é
> reescrita na primeira troca de direção ou idade. Não é problema; é bom saber
> antes de estranhar o quadril voltando ao lugar dentro do editor.

### 1.3 Roupa, cabelo, chapéu e saia herdam escala de graça

Isso é o ponto que economiza mais trabalho, e vale conferir no código:

- `WardrobePresenter._spawn_item()` faz `bone.add_child(sprite)` — cada peça de
  roupa é **filha do osso**.
- `HairRig` é filho do osso `cabeca` na própria cena.
- `SaiaMalha._montar()` faz `painel.reparent(osso_quadril, false)` — os dois
  `Polygon2D` da saia também viram filhos do quadril (e `pg.skeleton` fica vazio,
  então não há skinning para quebrar).

**Consequência:** escalar um osso escala tudo que está pendurado nele. Encolher a
perna encolhe a calça e o sapato junto. Aumentar a cabeça aumenta o cabelo e o
chapéu junto. Zero código extra em roupa, cabelo ou saia.

## 2. A decisão: proporção primeiro, arte dedicada depois

Três caminhos possíveis, com o custo honesto de cada um:

| Caminho | Custo | Resultado |
|---|---|---|
| Conjunto de arte por idade | 5 idades × 2 corpos × 4 direções × 15 peças = **600 PNGs**, mais roupas e cabelos por idade | Fidelidade máxima |
| Só proporção procedural | **0 PNG** | Convence de criança para cima; bebê fica adulto encolhido |
| **Híbrido (este tutorial)** | 0 PNG agora, arte opcional depois, uma idade por vez | Roda hoje e cresce sem refatoração |

No híbrido, o `AgeProfile` tem um campo `pasta_arte`. Se existir
`assets/characters/cutout/bebe_masc/rig.json`, o rig usa essa arte; se não
existir, usa `masc/` com as proporções aplicadas. Trocar proporção por arte de
verdade vira colocar a pasta no lugar — sem mexer em uma linha de código.

### Proporções alvo

O adulto do projeto tem 78 px e ~4,3 cabeças de altura (estilizado, não
realista). As outras idades foram derivadas dessa referência, mantendo a mesma
estilização:

| Idade | Altura resultante | % do adulto | ≈ metros | Cabeças |
|---|---|---|---|---|
| Bebê | 36 px | 46% | 0,83 m | 2,6 |
| Criança | 55 px | 71% | 1,27 m | 3,5 |
| Adolescente | 74 px | 95% | 1,70 m | 4,2 |
| Adulto | 78 px | 100% | 1,80 m | 4,3 |
| Idoso | 73 px | 93% | 1,67 m | 4,1 |

Esses números saem sozinhos dos valores da seção 4.3. Estão aqui para você ter
como conferir se errou um decimal no Inspector.

## 3. Estrutura de arquivos nova

```text
res://
├── data/character_customization/age/
│   ├── age_profile.gd
│   ├── age_catalog.gd
│   ├── default_age_catalog.tres
│   └── profiles/
│       ├── bebe.tres
│       ├── crianca.tres
│       ├── adolescente.tres
│       ├── adulto.tres
│       └── idoso.tres
├── presentation/characters/cutout/age/
│   └── character_age_presenter.gd
├── gameplay/
│   ├── player/character_age_body.gd
│   └── life/
│       ├── life_stage_clock.gd
│       └── life_stage_clock.tscn
├── interface/character_customization/
│   ├── age_selection_row.gd
│   └── age_selection_row.tscn
├── tests/character_age_test.gd
└── assets/characters/cutout/
    ├── masc/  fem/                 (o que já existe)
    └── bebe_masc/ bebe_fem/ …      (opcional, seção 10)
```

E arquivos existentes que recebem edições pontuais:

```text
character_appearance.gd      + campo age
character_appearance_state.gd + validação e set_age
character_rig.gd             + proporção e arte por idade
character_visual.gd          + presenter e biblioteca de animação
character_visual.tscn        + nó CharacterAgePresenter
player.tscn                  + nó AgeBody e duas conexões
player_controller.gd         + multiplicador de velocidade
character_customization_menu.gd/.tscn + linha de idade
main.tscn                    + LifeStageClock (opcional)
```

## 4. Camada de dados

### 4.1 `AgeProfile`

`res://data/character_customization/age/age_profile.gd`

```gdscript
class_name AgeProfile
extends Resource
## UMA fase da vida. É só dado: não existe em lugar nenhum do projeto um
## "if idade == bebe". Uma idade nova é um .tres novo, sem uma linha de código.

@export_category("Identidade")
@export var id: StringName = &"adulto"
@export var display_name: String = "Adulto"
## Posição na linha do tempo. O LifeStageClock avança por este número.
@export_range(0, 16, 1) var ordem: int = 3

@export_category("Arte")
## Prefixo da pasta em assets/characters/cutout. Vazio = usa a arte do corpo.
## Com "bebe", o rig procura "bebe_masc/rig.json" e cai em "masc/rig.json"
## quando a pasta não existe. É isto que deixa você trocar proporção por arte
## de verdade, uma idade de cada vez, sem tocar em código.
@export var pasta_arte: StringName = &""
## Biblioteca do AnimationPlayer a usar. Vazio = a do corpo (masc/fem).
@export var biblioteca_animacao: StringName = &""

@export_group("Escala")
## Escala uniforme do rig inteiro. 1.0 = o adulto de hoje.
@export_range(0.2, 1.4, 0.01) var escala_global: float = 1.0

@export_group("Proporções")
## Multiplica o osso da cabeça — e leva cabelo e chapéu junto, porque eles são
## filhos dele. É este número que faz um bebê parecer bebê.
@export_range(0.5, 2.5, 0.01) var escala_cabeca: float = 1.0
@export_range(0.4, 1.6, 0.01) var fator_tronco: float = 1.0
@export_range(0.4, 1.6, 0.01) var fator_pernas: float = 1.0
@export_range(0.4, 1.6, 0.01) var fator_bracos: float = 1.0
## Única escala não uniforme do sistema. Ver a nota de cisalhamento na seção 5.1.
@export_range(0.6, 1.6, 0.01) var fator_largura: float = 1.0

@export_group("Postura")
## Somado à rotação DEPOIS da animação, em radianos. Positivo curva para a
## frente. 0.14 ≈ 8°, que já lê como idoso sem virar caricatura.
@export_range(-0.6, 0.6, 0.005) var curvatura_tronco: float = 0.0
@export_range(-0.6, 0.6, 0.005) var curvatura_cabeca: float = 0.0

@export_group("Animação")
## speed_scale do AnimationPlayer. Criança anda miudinho e rápido; idoso, devagar.
@export_range(0.3, 2.0, 0.01) var velocidade_animacao: float = 1.0

@export_group("Gameplay")
@export_range(0.2, 1.6, 0.01) var multiplicador_velocidade: float = 1.0
@export_range(2.0, 16.0, 0.5) var raio_colisao: float = 5.0
@export_range(4.0, 40.0, 0.5) var altura_colisao: float = 10.0
@export var pode_correr: bool = true
@export var pode_agachar: bool = true
```

Sim, gameplay e apresentação convivem no mesmo recurso. É dado de configuração,
não regra — do mesmo jeito que `PlayerConfig` junta `Movement` e `Vitals`. Quem
lê cada grupo é uma camada diferente, e nenhuma delas escreve no recurso.

### 4.2 `AgeCatalog`

`res://data/character_customization/age/age_catalog.gd`

```gdscript
class_name AgeCatalog
extends Resource

@export var profiles: Array[AgeProfile] = []
@export var default_id: StringName = &"adulto"

var _by_id: Dictionary = {}


func get_profile(age_id: StringName) -> AgeProfile:
	_ensure_index()
	return _by_id.get(age_id) as AgeProfile


func normalize_id(age_id: StringName) -> StringName:
	return age_id if get_profile(age_id) != null else default_id


func get_sorted_profiles() -> Array[AgeProfile]:
	var result: Array[AgeProfile] = []
	for profile: AgeProfile in profiles:
		if profile != null and profile.id != &"":
			result.append(profile)
	result.sort_custom(func(a: AgeProfile, b: AgeProfile) -> bool: return a.ordem < b.ordem)
	return result


## Próxima fase da vida. Na última, devolve ela mesma — quem decide o que
## acontece no fim da linha é o gameplay, não o catálogo.
func next_id(age_id: StringName) -> StringName:
	var sorted_profiles := get_sorted_profiles()
	for index: int in sorted_profiles.size():
		if sorted_profiles[index].id != age_id:
			continue
		var next_index := index + 1
		return sorted_profiles[next_index].id if next_index < sorted_profiles.size() else age_id
	return normalize_id(age_id)


func is_last(age_id: StringName) -> bool:
	return next_id(age_id) == age_id


func _ensure_index() -> void:
	if _by_id.size() == profiles.size():
		return
	_by_id.clear()
	for profile: AgeProfile in profiles:
		if profile != null and profile.id != &"":
			_by_id[profile.id] = profile
```

Mesmo formato do `HairCatalog`, de propósito: quem já leu um lê o outro.

### 4.3 Os cinco `.tres`

No editor: **FileSystem → botão direito na pasta `profiles/` → New Resource →
AgeProfile**. Um arquivo por idade, preenchido no Inspector com a tabela abaixo.

| Campo | bebe | crianca | adolescente | adulto | idoso |
|---|---|---|---|---|---|
| `id` | `bebe` | `crianca` | `adolescente` | `adulto` | `idoso` |
| `display_name` | Bebê | Criança | Adolescente | Adulto | Idoso |
| `ordem` | 0 | 1 | 2 | 3 | 4 |
| `pasta_arte` | `bebe` | *(vazio)* | *(vazio)* | *(vazio)* | *(vazio)* |
| `escala_global` | 0.44 | 0.70 | 0.93 | 1.00 | 0.96 |
| `escala_cabeca` | 1.75 | 1.25 | 1.06 | 1.00 | 1.02 |
| `fator_tronco` | 1.05 | 1.00 | 0.97 | 1.00 | 0.94 |
| `fator_pernas` | 0.72 | 0.90 | 1.02 | 1.00 | 0.95 |
| `fator_bracos` | 0.78 | 0.92 | 1.00 | 1.00 | 0.99 |
| `fator_largura` | 1.18 | 1.02 | 0.93 | 1.00 | 1.03 |
| `curvatura_tronco` | 0.04 | 0.0 | 0.0 | 0.0 | 0.14 |
| `curvatura_cabeca` | -0.02 | 0.0 | 0.0 | 0.0 | -0.09 |
| `velocidade_animacao` | 1.15 | 1.10 | 1.02 | 1.00 | 0.82 |
| `multiplicador_velocidade` | 0.45 | 0.80 | 1.00 | 1.00 | 0.72 |
| `raio_colisao` | 3.0 | 4.0 | 4.5 | 5.0 | 5.0 |
| `altura_colisao` | 5.0 | 8.0 | 9.0 | 10.0 | 10.0 |
| `pode_correr` | ✗ | ✓ | ✓ | ✓ | ✗ |
| `pode_agachar` | ✗ | ✓ | ✓ | ✓ | ✓ |

Leitura rápida da tabela: bebê tem cabeça enorme, membros curtos e corpo largo;
adolescente é alto e estreito; idoso é levemente mais baixo, curvado e lento. O
adulto é a referência — todos os valores 1.0, então ele continua idêntico ao que
está no jogo hoje.

Depois: **New Resource → AgeCatalog** em `default_age_catalog.tres`, arraste os
cinco perfis para `profiles` e deixe `default_id = adulto`.

### 4.4 A idade entra na aparência

`data/character_customization/character_appearance.gd` — dois trechos novos:

```gdscript
@export_enum("masc", "fem") var body_type: String = "masc"
@export var age: StringName = &"adulto"          # ← NOVO
@export var top: StringName = &""
```

```gdscript
func set_age(new_age: StringName) -> void:       # ← NOVO
	if new_age == age:
		return
	age = new_age
	emit_changed()
```

E em `default_character_appearance.tres`, acrescente a linha `age = &"adulto"`
(ou abra no Inspector e escolha; o campo aparece sozinho).

## 5. Camada de apresentação

### 5.1 `CharacterRig` aprende proporção e arte por idade

Quatro edições em `presentation/characters/cutout/character_rig.gd`.

**(a) Constantes e campos novos**, logo abaixo de `extends Skeleton2D`:

```gdscript
## Raízes de cadeia. Escalar a RAIZ é o que faz roupa, mão, pé, sapato e cabelo
## acompanharem sem uma linha a mais: todos eles são filhos.
const OSSO_TRONCO: StringName = &"torso"
const OSSO_CABECA: StringName = &"cabeca"
const OSSOS_BRACO: Array[StringName] = [&"braco_sup_e", &"braco_sup_d"]
const OSSOS_PERNA: Array[StringName] = [&"coxa_e", &"coxa_d"]

## Y do dedo do pé no espaço do Skeleton2D com o rig em escala 1. Sem ele, o
## personagem encolhido flutua: a escala puxa o pé para perto da origem.
## Como medir: selecione ponta_pe_e no editor, na pose de repouso, e leia o Y
## dele relativo ao Skeleton2D.
@export_range(-32.0, 32.0, 0.01) var apoio_pes_y: float = 3.34

var _age: AgeProfile
var _rig_base_position := Vector2.ZERO
var _quadril_base := Vector2.ZERO
var _perna_escalavel: float = 0.0
var _medidas_prontas: bool = false
```

E a primeira linha de `_ready()`, para a compensação do pé não depender de o
`Skeleton2D` estar exatamente em (0, 0) na cena:

```gdscript
func _ready() -> void:
	_rig_base_position = position          # ← NOVO
	_cache_piece_nodes()
	_load_body_data()
	set_direction(initial_direction)
```

**(b) A resolução da pasta de arte.** Troque `_load_body_data()` e acrescente
`_resolve_art_key()`:

```gdscript
func _load_body_data() -> void:
	var art_key := _resolve_art_key(_age)
	var json_path := "%s/%s/rig.json" % [assets_root, art_key]
	if not FileAccess.file_exists(json_path):
		push_error("rig.json não encontrado: %s" % json_path)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error("JSON inválido: %s" % json_path)
		return

	_rig_data = parsed as Dictionary


## "bebe" + "masc" -> "bebe_masc" SE a pasta existir; senão "masc". É o fallback
## que deixa uma idade nascer só com proporção e ganhar arte dedicada depois.
func _resolve_art_key(profile: AgeProfile) -> String:
	if profile != null and profile.pasta_arte != &"":
		var candidate := "%s_%s" % [String(profile.pasta_arte), body_type]
		if FileAccess.file_exists("%s/%s/rig.json" % [assets_root, candidate]):
			return candidate
	return body_type


func get_art_key() -> String:
	return _resolve_art_key(_age)
```

**(c) Dois métodos públicos de idade:**

```gdscript
## Troca de idade. Recarrega a arte só quando a pasta muda; o resto é escala.
func set_age_profile(profile: AgeProfile) -> void:
	var art_changed := _resolve_art_key(profile) != _resolve_art_key(_age)
	_age = profile
	if not art_changed:
		apply_age_shape()
		return
	var direction_to_preserve := _current_direction
	_current_direction = &""
	_load_body_data()
	set_direction(
		direction_to_preserve if direction_to_preserve != &"" else StringName(initial_direction)
	)


## Só as escalas — sem tocar em JSON nem em textura. Barato o bastante para
## rodar todo quadro durante a transição de idade.
func set_age_shape(profile: AgeProfile) -> void:
	_age = profile
	apply_age_shape()


func apply_age_shape() -> void:
	var escala := 1.0
	var largura := 1.0
	var tronco := 1.0
	var pernas := 1.0
	var bracos := 1.0
	var cabeca := 1.0
	if _age != null:
		escala = _age.escala_global
		largura = _age.fator_largura
		tronco = maxf(_age.fator_tronco, 0.01)
		pernas = _age.fator_pernas
		bracos = _age.fator_bracos
		cabeca = _age.escala_cabeca

	# A largura é a única escala não uniforme, e por isso mora na RAIZ: aqui
	# nenhum osso girado a herdou ainda de um pai já rotacionado.
	scale = Vector2(escala * largura, escala)
	# Escalar aproxima o pé da origem. Isto devolve o contato com o chão.
	position.y = _rig_base_position.y + apoio_pes_y * (1.0 - escala)

	_escalar_osso(OSSO_TRONCO, tronco)
	# cabeça e ombros são FILHOS do tronco: dividir cancela a herança e deixa
	# cada fator significar exatamente o que o nome diz.
	_escalar_osso(OSSO_CABECA, cabeca / tronco)
	for bone_name: StringName in OSSOS_BRACO:
		_escalar_osso(bone_name, bracos / tronco)
	for bone_name: StringName in OSSOS_PERNA:
		_escalar_osso(bone_name, pernas)

	var quadril := get_piece_bone(&"quadril")
	if quadril != null and _medidas_prontas:
		# Encurtar a perna sem descer o quadril deixa o personagem no ar. O
		# quadril compensa exatamente o que a cadeia da perna perdeu.
		quadril.position = Vector2(
			_quadril_base.x,
			_quadril_base.y + _perna_escalavel * (1.0 - pernas)
		)


func _escalar_osso(bone_name: StringName, factor: float) -> void:
	var bone := get_piece_bone(bone_name)
	if bone != null:
		bone.scale = Vector2(factor, factor)
```

**(d) `set_direction()` guarda as medidas e aplica a forma.** No final do
método, antes de `_apply_core_layering()`:

```gdscript
	_quadril_base = _parse_vector2(pieces_data["quadril"]["posicao"])
	# A parte da perna que a escala do osso coxa realmente encolhe: joelho,
	# tornozelo e ponta do pé. O offset quadril->coxa não entra, porque é filho
	# do quadril e não da coxa.
	_perna_escalavel = (
		_parse_vector2(pieces_data["perna_e"]["posicao"]).y
		+ _parse_vector2(pieces_data["pe_e"]["posicao"]).y
		+ _parse_vector2(direction_data["pontas"]["ponta_pe_e"]["posicao"]).y
	)
	_medidas_prontas = true
	apply_age_shape()
	_apply_core_layering()
	_apply_markers(direction_data["pontas"])
	_current_direction = direction
```

> **Sobre `fator_largura` e cisalhamento.** Uma escala não uniforme em um pai
> deforma filhos rotacionados — é geometria, não bug do Godot. Por isso ela fica
> no `Skeleton2D`, onde o efeito é mínimo, e nunca em um osso do meio da cadeia.
> Na faixa 0,93–1,18 da tabela é imperceptível. Se algum dia incomodar, ponha
> `fator_largura = 1.0` e resolva com arte dedicada.

### 5.2 `CharacterAgePresenter`

`res://presentation/characters/cutout/age/character_age_presenter.gd`

```gdscript
class_name CharacterAgePresenter
extends Node
## Traduz uma idade (StringName) em proporção, postura e ritmo de animação.
## Não decide nada: quem escolhe a idade é o estado, quem guarda os números é o
## .tres do catálogo. Este nó só aplica.

signal profile_changed(profile: AgeProfile)

@export var catalog: AgeCatalog
@export var rig: CharacterRig
@export var animation_player: AnimationPlayer
## 0 = troca seca. Acima disso, o personagem CRESCE até a idade nova. Só vale
## entre idades que compartilham a mesma arte (ver seção 9).
@export_range(0.0, 8.0, 0.1) var transicao_segundos: float = 0.0

var _profile: AgeProfile
var _anterior: AgeProfile
var _mistura := AgeProfile.new()
var _postura_alvo := Vector2.ZERO
var _postura_aplicada := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	# Depois do AnimationPlayer. A rotação deste quadro só existe depois que a
	# animação escreveu nela — mesmo motivo do HairPhysicsController.
	process_priority = 100


func present(age_id: StringName) -> void:
	if catalog == null or rig == null:
		push_error("CharacterAgePresenter está sem catálogo ou rig")
		return
	var profile := catalog.get_profile(catalog.normalize_id(age_id))
	if profile == null or profile == _profile:
		return
	_anterior = _profile
	_profile = profile
	if animation_player != null:
		animation_player.speed_scale = profile.velocidade_animacao

	var pode_interpolar := (
		_anterior != null
		and transicao_segundos > 0.0
		and _anterior.pasta_arte == profile.pasta_arte
	)
	if pode_interpolar:
		_iniciar_transicao()
	else:
		_parar_transicao()
		_postura_alvo = Vector2(profile.curvatura_tronco, profile.curvatura_cabeca)
		rig.set_age_profile(profile)
	profile_changed.emit(profile)


func get_profile() -> AgeProfile:
	return _profile


## Biblioteca de animação da idade, com fallback para a do corpo. É isso que
## deixa uma idade nova funcionar ANTES de existir animação própria para ela.
func animation_library(body_type: String) -> String:
	if _profile != null and _profile.biblioteca_animacao != &"":
		return String(_profile.biblioteca_animacao)
	return body_type


func _process(_delta: float) -> void:
	if rig == null:
		return
	# Nada a fazer se não há postura nem resíduo de postura para desfazer.
	if _postura_alvo.is_equal_approx(Vector2.ZERO) and _postura_aplicada.is_equal_approx(Vector2.ZERO):
		return
	var tronco := rig.get_piece_bone(&"torso")
	var cabeca := rig.get_piece_bone(&"cabeca")
	if tronco == null or cabeca == null:
		return
	# Com animação tocando, o valor lido já é o do quadro (a animação apagou o
	# nosso offset). Sem animação tocando, ele ainda carrega o offset anterior.
	# Descontar antes de somar deixa a conta idempotente nos dois casos.
	if animation_player == null or not animation_player.is_playing():
		tronco.rotation -= _postura_aplicada.x
		cabeca.rotation -= _postura_aplicada.y
	tronco.rotation += _postura_alvo.x
	cabeca.rotation += _postura_alvo.y
	_postura_aplicada = _postura_alvo


func _iniciar_transicao() -> void:
	_parar_transicao()
	_tween = create_tween()
	_tween.tween_method(_aplicar_peso, 0.0, 1.0, transicao_segundos)
	# No fim, o rig volta a apontar para o recurso de verdade em vez da mistura.
	_tween.finished.connect(func() -> void: rig.set_age_profile(_profile))


func _parar_transicao() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _aplicar_peso(peso: float) -> void:
	rig.set_age_shape(_mistura_em(peso))


func _mistura_em(peso: float) -> AgeProfile:
	_mistura.id = _profile.id
	_mistura.pasta_arte = _profile.pasta_arte
	_mistura.biblioteca_animacao = _profile.biblioteca_animacao
	_mistura.escala_global = lerpf(_anterior.escala_global, _profile.escala_global, peso)
	_mistura.escala_cabeca = lerpf(_anterior.escala_cabeca, _profile.escala_cabeca, peso)
	_mistura.fator_tronco = lerpf(_anterior.fator_tronco, _profile.fator_tronco, peso)
	_mistura.fator_pernas = lerpf(_anterior.fator_pernas, _profile.fator_pernas, peso)
	_mistura.fator_bracos = lerpf(_anterior.fator_bracos, _profile.fator_bracos, peso)
	_mistura.fator_largura = lerpf(_anterior.fator_largura, _profile.fator_largura, peso)
	_postura_alvo = Vector2(
		lerpf(_anterior.curvatura_tronco, _profile.curvatura_tronco, peso),
		lerpf(_anterior.curvatura_cabeca, _profile.curvatura_cabeca, peso)
	)
	return _mistura
```

### 5.3 `CharacterVisual` liga o presenter

Três edições em `presentation/characters/cutout/character_visual.gd`.

**(a) Referência**, junto das outras:

```gdscript
@onready var age_presenter: CharacterAgePresenter = $CharacterAgePresenter
```

**(b) `present_appearance()`** — a idade tem que ser aplicada **antes** da
direção, porque `set_direction()` reescreve as posições dos ossos:

```gdscript
func present_appearance(appearance: CharacterAppearance) -> void:
	if appearance == null:
		return
	_appearance = appearance.snapshot()
	rig.set_body(_appearance.body_type)
	age_presenter.present(_appearance.age)   # ← NOVO, antes de set_direction
	rig.set_direction(_direction)
	rig.present_skin_color(_appearance.skin_color)
	wardrobe.invalidate()
	wardrobe.present(_appearance, _direction)
	hair.invalidate()
	hair.present(_appearance.hair_front, _appearance.hair_back, _direction, _appearance.hair_color)
	_current_animation = &""
	_refresh_locomotion_animation()
```

**(c) Nome da animação, com fallback.** Troque `_make_animation_name()` e a
verificação dentro de `_play_action()`:

```gdscript
func _make_animation_name(action: StringName) -> StringName:
	return StringName(
		"%s/%s_%s" % [
			age_presenter.animation_library(rig.body_type), String(action), String(_direction)
		]
	)


func _fallback_animation_name(action: StringName) -> StringName:
	return StringName("%s/%s_%s" % [rig.body_type, String(action), String(_direction)])
```

E dentro de `_play_action()`, no lugar do `push_error` seco:

```gdscript
	if not animation_player.has_animation(animation_name):
		var fallback := _fallback_animation_name(action)
		if not animation_player.has_animation(fallback):
			push_error("Animação não encontrada: %s" % animation_name)
			return
		animation_name = fallback
```

Sem isso, criar uma biblioteca de animação para uma idade só (`bebe_masc`, por
exemplo) faria as outras direções e ações inexistentes despejarem erro no
console.

### 5.4 A cena `character_visual.tscn` — onde clicar

1. Selecione o nó raiz `CharacterVisual` → **Add Child Node → Node** → renomeie
   para **`CharacterAgePresenter`**.
2. Arraste `character_age_presenter.gd` para o campo **Script** dele.
3. No Inspector do nó novo:
   - `Catalog` → `default_age_catalog.tres`
   - `Rig` → aponte para `Skeleton2D` (o campo aceita NodePath; use o seletor)
   - `Animation Player` → aponte para `AnimationPlayer`
   - `Transicao Segundos` → `0` por enquanto (a transição entra na seção 9)
4. Arraste o nó para ficar **acima** do `AnimationPlayer` na árvore. Não é
   obrigatório — `process_priority` já garante a ordem — mas deixa a cena
   legível na mesma ordem em que as coisas acontecem.

Árvore resultante:

```text
CharacterVisual
├── Skeleton2D               (CharacterRig)
├── SaiaDeformavel
├── WardrobePresenter
├── CharacterColorPresenter
├── CharacterAgePresenter    ← NOVO
└── AnimationPlayer
```

## 6. Camada de estado

`gameplay/player/character_appearance_state.gd` — o estado é quem impede uma
idade inválida de chegar na apresentação, igual já faz com roupa, cabelo e cor.

```gdscript
@export var color_catalog: CharacterColorCatalog
@export var age_catalog: AgeCatalog                 # ← NOVO
```

Dentro de `_ready()`, na verificação de configuração:

```gdscript
	if default_appearance == null or catalog == null or hair_catalog == null \
			or color_catalog == null or age_catalog == null:
		push_error("AppearanceState está sem configuração")
		return
```

Dentro de `apply_appearance()`, junto das outras normalizações:

```gdscript
	validated.age = age_catalog.normalize_id(validated.age)     # ← NOVO
```

E o método que o relógio da vida vai chamar:

```gdscript
## Envelhecer é só mudar um campo da aparência. Tudo o mais já está ligado.
func set_age(age_id: StringName) -> void:
	if _current == null:
		return
	var updated := _current.snapshot()
	updated.age = age_id
	apply_appearance(updated)
```

Na cena `player.tscn`, selecione `AppearanceState` e preencha o novo campo
`Age Catalog` com `default_age_catalog.tres`.

> **Não esqueça dos testes existentes.** `character_color_integration_test.gd` e
> `hair_integration_test.gd` montam um `CharacterAppearanceState` na mão. Sem
> `state.age_catalog = load(...)`, o `_ready()` aborta na verificação e o
> primeiro `apply_appearance()` estoura em cima de um catálogo nulo. Os dois já
> foram corrigidos.

## 7. Camada de gameplay

### 7.1 `CharacterAgeBody`

`res://gameplay/player/character_age_body.gd`

```gdscript
class_name CharacterAgeBody
extends Node
## O corpo físico da idade: colisão e sombra. Não lê teclado, não anima, não
## conhece Sprite2D do rig. Recebe a aparência por sinal e reemite o que o
## controlador precisa saber.

signal age_body_changed(profile: AgeProfile)

@export var catalog: AgeCatalog
@export var collision_shape: CollisionShape2D
## Opcional: a sombra encolhe junto com o personagem.
@export var shadow: Node2D

var _profile: AgeProfile


func _ready() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	# Sem duplicar, todos os personagens que usam esta cena compartilham a MESMA
	# CapsuleShape2D — envelhecer um encolheria a colisão de todos.
	collision_shape.shape = collision_shape.shape.duplicate()


## Conecte aqui o sinal appearance_changed do AppearanceState.
func present_appearance(appearance: CharacterAppearance) -> void:
	if appearance == null or catalog == null:
		return
	var profile := catalog.get_profile(catalog.normalize_id(appearance.age))
	if profile == null or profile == _profile:
		return
	_profile = profile
	_aplicar_colisao(profile)
	if shadow != null:
		shadow.scale = Vector2.ONE * profile.escala_global
	age_body_changed.emit(profile)


func get_profile() -> AgeProfile:
	return _profile


func _aplicar_colisao(profile: AgeProfile) -> void:
	if collision_shape == null:
		return
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule == null:
		return
	capsule.radius = profile.raio_colisao
	capsule.height = maxf(profile.altura_colisao, profile.raio_colisao * 2.0)
	# A cápsula cresce para cima a partir dos pés, que ficam na origem do Player.
	collision_shape.position.y = -capsule.height * 0.5
```

Na cena `player.tscn`:

1. Selecione `Player` → **Add Child Node → Node** → renomeie para **`AgeBody`**.
2. Script: `character_age_body.gd`.
3. Inspector: `Catalog` → `default_age_catalog.tres`; `Collision Shape` →
   `CollisionShape2D`.
4. Aba **Node → Signals**:
   - `AppearanceState.appearance_changed` → `AgeBody.present_appearance`
   - `AgeBody.age_body_changed` → `Player.present_age_body`

### 7.2 `PlayerController` recebe o multiplicador

`gameplay/player/player_controller.gd`:

```gdscript
var _age_speed_multiplier: float = 1.0
var _age_can_run: bool = true
var _age_can_crouch: bool = true


## Ligado ao sinal age_body_changed. O controlador não conhece idade nenhuma:
## ele recebe três números e obedece.
func present_age_body(profile: AgeProfile) -> void:
	if profile == null:
		return
	_age_speed_multiplier = profile.multiplicador_velocidade
	_age_can_run = profile.pode_correr
	_age_can_crouch = profile.pode_agachar
	if _is_crouching and not _age_can_crouch:
		_is_crouching = false
		crouch_changed.emit(false)
```

Em `_physics_process()`, três linhas mudam:

```gdscript
	var wants_to_crouch := Input.is_action_pressed("crouch") and _age_can_crouch
```

```gdscript
	var wants_to_run := (
		has_movement_input
		and not _is_crouching
		and _age_can_run
		and Input.is_action_pressed("move_run")
	)
```

```gdscript
	velocity = isometric_input * config.movement_speed * speed_multiplier * _age_speed_multiplier
```

E em `_process_grid_movement()`, no modo em grade:

```gdscript
		grid_agent.request_step(
			Vector2i(roundi(grid_input.x), roundi(grid_input.y)),
			speed_scale * _age_speed_multiplier
		)
```

(o `wants_to_run` desse método recebe o mesmo `and _age_can_run`).

### 7.3 Câmera e sombra

- **Sombra:** se o `Player` tiver uma instância de `entity_shadow.tscn`, ligue-a
  no campo `Shadow` do `AgeBody` e ela encolhe sozinha.
- **Câmera:** o `Camera2D` é filho do `Player`, na origem dos pés. Um bebê de 36
  px com a câmera na mesma altura deixa muito chão na tela. Se quiser corrigir,
  crie um `Marker2D` chamado `CameraPivot` no `Player`, ponha a câmera nele e
  acrescente ao `CharacterAgeBody`:

```gdscript
@export var camera_pivot: Node2D
@export_range(0.0, 1.0, 0.01) var camera_na_altura: float = 0.45
```

```gdscript
	if camera_pivot != null:
		camera_pivot.position.y = -profile.altura_colisao * 2.0 * camera_na_altura
```

- **SubViewport:** o `CharacterViewport` tem 192×192 px com o pé em (96, 144). O
  adulto ocupa 78 px acima disso e nenhuma idade aqui cresce além dele, então
  não há estouro. Se você criar uma idade com `escala_global > 1.0` **ou**
  `escala_cabeca` muito alta com cabelo longo, aumente o `size` do SubViewport e
  o `texture_foot` do `CharacterViewportComposite` na mesma proporção.

## 8. Interface: escolher a idade no menu

### 8.1 `AgeSelectionRow`

`res://interface/character_customization/age_selection_row.gd`

```gdscript
class_name AgeSelectionRow
extends HBoxContainer

signal selection_changed(age_id: StringName)

@export var label_text: String = "Idade"

@onready var slot_label: Label = %SlotLabel
@onready var selector: OptionButton = %Selector


func _ready() -> void:
	slot_label.text = label_text


func setup(catalog: AgeCatalog, selected_age: StringName) -> void:
	selector.clear()
	var selected_index := 0
	for profile: AgeProfile in catalog.get_sorted_profiles():
		selector.add_item(profile.display_name)
		var index := selector.item_count - 1
		selector.set_item_metadata(index, profile.id)
		if profile.id == selected_age:
			selected_index = index
	selector.select(selected_index)


func _on_selector_item_selected(index: int) -> void:
	selection_changed.emit(StringName(selector.get_item_metadata(index)))
```

A cena `age_selection_row.tscn` é a mesma estrutura de `hair_selection_row.tscn`
— o jeito mais rápido é abrir aquela, **Scene → Save Scene As** com o nome novo,
trocar o script e o `label_text`, e conferir que `SlotLabel` e `Selector` têm
`unique_name_in_owner` ligado (o `%` do script depende disso).

```text
AgeSelectionRow (HBoxContainer, custom_minimum_size.y = 34)
├── SlotLabel  (Label, custom_minimum_size.x = 150)
└── Selector   (OptionButton, size_flags_horizontal = Fill|Expand)
```

Conecte `Selector.item_selected` → `_on_selector_item_selected`.

### 8.2 Menu

`character_customization_menu.gd`:

```gdscript
@export var age_catalog: AgeCatalog                                  # ← NOVO
@onready var age_row: AgeSelectionRow = %AgeRow                      # ← NOVO
```

Em `open()`, some `age_catalog == null` à verificação. Em `_refresh_everything()`,
antes do `_refresh_preview()`:

```gdscript
	age_row.setup(age_catalog, _working.age)
```

E o handler:

```gdscript
func _on_age_selection_changed(age_id: StringName) -> void:
	_working.set_age(age_id)
	_refresh_everything()
```

Na cena `character_customization_menu.tscn`: instancie `age_selection_row.tscn`
dentro de `OptionsScroll/Options`, **logo abaixo de `GenderRow`** (idade e corpo
são a mesma família de escolha), marque `unique_name_in_owner`, renomeie para
`AgeRow` e conecte `selection_changed` → `_on_age_selection_changed`. No nó raiz
do menu, preencha `Age Catalog`.

O preview do menu é um `CharacterVisual` completo, então ele já mostra a idade
funcionando — inclusive as roupas encolhendo junto.

### 8.3 Randomizador (opcional)

Se quiser que o botão de sortear também sorteie a idade,
`character_appearance_randomizer.gd`:

```gdscript
@export var idades_sorteaveis: Array[StringName] = []
```

```gdscript
	if not idades_sorteaveis.is_empty():
		result.age = idades_sorteaveis[rng.randi_range(0, idades_sorteaveis.size() - 1)]
```

Deixe o array vazio para o sorteio preservar a idade atual — que é o
comportamento certo enquanto você está testando roupas.

## 9. Envelhecer durante a partida

### 9.1 `LifeStageClock`

`res://gameplay/life/life_stage_clock.gd`

```gdscript
class_name LifeStageClock
extends Node
## O tempo da vida. Só conta e anuncia — não sabe o que uma idade faz, não
## conhece rig, colisão nem menu.

signal stage_changed(age_id: StringName)
signal life_ended(age_id: StringName)

@export var catalog: AgeCatalog
@export var idade_inicial: StringName = &"adulto"
@export_range(5.0, 3600.0, 1.0) var segundos_por_estagio: float = 120.0
## Desligado, o relógio existe mas não avança sozinho: chame advance() de um
## aniversário, de um item ou de um botão de debug. Vem desligado de propósito,
## para o jogo continuar exatamente como estava até você querer envelhecer.
@export var iniciar_automaticamente: bool = false
@export var timer: Timer

var _current: StringName = &""


func _ready() -> void:
	if catalog == null or timer == null:
		push_error("LifeStageClock precisa de catálogo e Timer no Inspector.")
		return
	_current = catalog.normalize_id(idade_inicial)
	timer.wait_time = segundos_por_estagio
	timer.one_shot = false
	if iniciar_automaticamente:
		timer.start()
	# call_deferred: o AppearanceState também publica no _ready, e quem chega
	# depois vence. A idade inicial tem que ser a última palavra.
	_publicar.call_deferred()


func get_age() -> StringName:
	return _current


## Avança uma fase. Serve para o Timer, para um item, para um evento de história
## ou para um botão de debug — o gatilho não muda nada aqui.
func advance() -> void:
	if catalog.is_last(_current):
		life_ended.emit(_current)
		timer.stop()
		return
	_current = catalog.next_id(_current)
	_publicar()


func set_age(age_id: StringName) -> void:
	var normalized := catalog.normalize_id(age_id)
	if normalized == _current:
		return
	_current = normalized
	_publicar()


func _on_timer_timeout() -> void:
	advance()


func _publicar() -> void:
	stage_changed.emit(_current)
```

`life_stage_clock.tscn`:

```text
LifeStageClock (Node, script life_stage_clock.gd)
└── Timer       (Timer)
```

No Inspector do nó raiz: `Catalog` → `default_age_catalog.tres`, `Timer` →
o nó `Timer`. Conecte `Timer.timeout` → `_on_timer_timeout`.

O `Timer` existe **na cena**, não é criado por código — é um nó previsível, e
você vai querer mexer no `wait_time` pelo editor enquanto ajusta o ritmo.

### 9.2 Ligar na `main.tscn`

1. Instancie `life_stage_clock.tscn` em `Main` (junto de `World` e `Interface`;
   se você criar um nó `Systems`, melhor ainda).
2. `Main.gd` ganha a referência e a conexão:

```gdscript
@export var life_clock: LifeStageClock
```

```gdscript
	if life_clock != null:
		life_clock.stage_changed.connect(appearance_state.set_age)
```

Pronto: o relógio anuncia, o estado valida e publica, e a apresentação e o corpo
físico reagem ao mesmo sinal que já existia. Nenhuma camada nova precisou
conhecer outra.

### 9.3 Crescer suavemente

Ponha `Transicao Segundos = 1.5` no `CharacterAgePresenter` e a mudança de idade
vira um crescimento contínuo em vez de um estalo.

Duas honestidades sobre isso:

- A interpolação só acontece entre idades que usam a **mesma arte**. Não existe
  como interpolar entre dois conjuntos de PNG diferentes com uma escala; quando
  `pasta_arte` muda, a troca é seca por definição.
- Por isso, num jogo de vida, a troca de fase costuma acontecer **atrás de algo**:
  dormir, uma tela de aniversário, um fade. O projeto já tem o sistema de dormir
  na cama — é o gancho natural para o aniversário.

## 10. Quando a proporção não basta: arte dedicada

O bebê é o caso em que a proporção sozinha não convence. Um adulto encolhido com
cabeça grande ainda tem ombro largo, pescoço definido e proporção de mão de
adulto. As outras quatro idades passam bem com o corpo base.

### 10.1 Como acrescentar um conjunto de arte

1. Crie `assets/characters/cutout/bebe_masc/` com as quatro subpastas
   `se/ sw/ ne/ nw/` e as 15 peças de sempre (`quadril.png`, `torso.png`,
   `cabeca.png`, `braco_sup_e.png`, …).
2. Copie `masc/rig.json` para `bebe_masc/rig.json` e ajuste:
   - `"tipo": "bebe_masc"`;
   - todos os `"arquivo"` passam a apontar para `bebe_masc/<dir>/<peca>.png`;
   - `posicao`, `offset_sprite` e `z_index` de cada peça, medidos na arte nova;
   - `altura_px` para conferência.
3. Em `bebe.tres`, `pasta_arte` já é `bebe` — o rig acha a pasta sozinho e para
   de usar o fallback.
4. Zere ou amanse as proporções desse perfil (`escala_cabeca` perto de 1.0,
   `fator_pernas` perto de 1.0): a arte nova já tem a proporção desenhada, e
   multiplicar de novo dobra o efeito.
5. `escala_global` continua útil, para casar o tamanho do bebê com o tile.

O rig não precisa de nenhuma mudança. `_resolve_art_key()` já procura a pasta e
cai no corpo base quando ela não existe. Você pode fazer `bebe_masc` hoje e
`bebe_fem` no mês que vem — cada corpo cai no fallback independentemente.

### 10.2 O que mais precisa de arte por idade

| Sistema | Precisa de arte nova? |
|---|---|
| Corpo | Só se `pasta_arte` estiver preenchida |
| Roupas | Não — os PNGs de adulto escalam com o osso |
| Cabelo | Não — o `HairRig` é filho da cabeça |
| Saia | Não — os painéis são reparentados ao quadril |
| Sombra | Não — `AgeBody` escala a existente |

Roupa de adulto encolhida em um bebê funciona surpreendentemente bem porque ela
acompanha o mesmo osso. O que fica estranho é **estilo**, não escala: bebê de
jaqueta social. Isso se resolve no catálogo (um campo `idades_permitidas` no
`ClothingItem` e um filtro em `get_items_for_slot`), não no rig.

## 11. Animações por idade

Três níveis, do mais barato ao mais caro:

1. **`velocidade_animacao`** (já implementado). Um idoso com `0.82` e uma criança
   com `1.10` já leem como idades diferentes andando. É um número no `.tres`.
2. **Postura** (já implementado). `curvatura_tronco` de 0.14 rad no idoso muda a
   silhueta em toda animação, sem tocar em nenhuma delas.
3. **Biblioteca própria.** Quando quiser um andar realmente diferente (bebê
   engatinhando, por exemplo):
   - duplique `animacoes_masc.tres` como `animacoes_bebe_masc.tres`;
   - no `AnimationPlayer` de `character_visual.tscn`, **Animation → Manage
     Animations → Add Library**, nome `bebe_masc`, apontando para o `.tres` novo;
   - em `bebe.tres`, `biblioteca_animacao = bebe_masc`.

   Você só precisa regravar as animações que quer diferentes: o fallback da
   seção 5.3 usa a do corpo para tudo que faltar naquela biblioteca.

Um aviso sobre engatinhar: o rig tem os ossos certos para isso (é uma pose de
quatro apoios com rotações), mas o `z_index` das peças vem do `rig.json` por
direção, e uma pose horizontal quer outra ordem de profundidade. É trabalho de
`rig.json` dedicado, não de animação — mais um motivo para o bebê ganhar pasta
própria quando chegar a hora.

## 12. Teste

`res://tests/character_age_test.gd`

```gdscript
extends SceneTree


func _init() -> void:
	var catalog := load("res://data/character_customization/age/default_age_catalog.tres") as AgeCatalog
	assert(catalog != null)
	var sorted_profiles := catalog.get_sorted_profiles()
	assert(sorted_profiles.size() == 5, "Esperava 5 idades")

	var expected: Array[StringName] = [&"bebe", &"crianca", &"adolescente", &"adulto", &"idoso"]
	for index: int in expected.size():
		assert(sorted_profiles[index].id == expected[index], "Ordem errada em %d" % index)

	assert(catalog.normalize_id(&"inexistente") == &"adulto")
	assert(catalog.next_id(&"bebe") == &"crianca")
	assert(catalog.next_id(&"idoso") == &"idoso")
	assert(catalog.is_last(&"idoso"))

	_run.call_deferred()


func _run() -> void:
	var catalog := load("res://data/character_customization/age/default_age_catalog.tres") as AgeCatalog
	var appearance := load("res://data/character_customization/default_character_appearance.tres") as CharacterAppearance
	var visual := (load("res://presentation/characters/cutout/character_visual.tscn") as PackedScene).instantiate() as CharacterVisual
	root.add_child(visual)
	await process_frame

	var alturas: Dictionary = {}
	var chaos: Dictionary = {}
	for profile: AgeProfile in catalog.get_sorted_profiles():
		var aged := appearance.snapshot()
		aged.age = profile.id
		visual.present_appearance(aged)
		visual.present_locomotion(&"se", false, false)
		await process_frame

		var pe := visual.rig.find_child("ponta_pe_e", true, false) as Marker2D
		var cabeca := visual.rig.find_child("ponta_cabeca", true, false) as Marker2D
		assert(pe != null and cabeca != null)
		# to_local do CharacterVisual já embute a escala e a posição do rig.
		var chao: float = visual.to_local(pe.global_position).y
		var topo: float = visual.to_local(cabeca.global_position).y
		alturas[profile.id] = absf(chao - topo)
		chaos[profile.id] = chao

	# O pé fica onde estava: encolher não pode fazer o personagem flutuar. A
	# folga de 2.5 px cobre a pose de idle, que não deixa os dois pés retos.
	for age_id: StringName in chaos:
		var desvio: float = absf(float(chaos[age_id]) - float(chaos[&"adulto"]))
		assert(desvio < 2.5, "Pé fora do chão em %s: %.2f px" % [age_id, desvio])

	# Crescimento monotônico até o adulto.
	assert(alturas[&"bebe"] < alturas[&"crianca"])
	assert(alturas[&"crianca"] < alturas[&"adolescente"])
	assert(alturas[&"adolescente"] < alturas[&"adulto"])
	assert(alturas[&"idoso"] < alturas[&"adulto"])
	# O bebê fica entre 40% e 55% do adulto.
	var razao: float = alturas[&"bebe"] / alturas[&"adulto"]
	assert(razao > 0.40 and razao < 0.55, "Bebê com %.0f%% do adulto" % (razao * 100.0)) 

	print("CHARACTER_AGE_OK ", alturas)
	quit()
```

Rodar (mesmo comando dos outros testes do projeto). Na primeira vez, importe
antes — há `.tres` e `.gd` novos que o Godot ainda não indexou:

```powershell
cd C:\Users\danil\Desktop\PathLife\PathLife-main
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/character_age_test.gd
```

Saída esperada: uma linha começando com `CHARACTER_AGE_OK`, com as cinco alturas
e a razão do bebê perto de `0.46`. Vale rodar também os dois testes que foram
tocados:

```powershell
& '...Godot...exe' --headless --path . --script res://tests/character_color_integration_test.gd
& '...Godot...exe' --headless --path . --script res://tests/hair_integration_test.gd
```

**Teste visual**, que vale mais que qualquer assert aqui: abra
`character_visual.tscn`, rode a cena (F6), e no Inspector do
`CharacterAgePresenter` chame `present("bebe")`, `present("idoso")`… pela aba
**Debugger → Evaluate**. Ou, mais prático: abra o menu de customização no jogo e
troque de idade com a roupa e o cabelo equipados. É aí que os erros de proporção
aparecem.

## 13. Ordem de execução

Faça nesta ordem e cada passo é testável sozinho:

1. `age_profile.gd` + `age_catalog.gd` + os seis `.tres` (seção 4).
2. Campo `age` em `CharacterAppearance` (4.4).
3. Edições no `CharacterRig` (5.1). **Teste:** o jogo continua idêntico — com
   `_age == null` todos os fatores valem 1.0.
4. `CharacterAgePresenter` + nó na cena (5.2, 5.4).
5. `CharacterVisual` (5.3). **Teste:** troque `age` no
   `default_character_appearance.tres` para `crianca` e rode. O personagem
   encolhe, com roupa e cabelo.
6. `AppearanceState` (seção 6).
7. `AgeBody` + `PlayerController` (7.1, 7.2). **Teste:** o bebê anda devagar e
   não corre.
8. Linha de idade no menu (seção 8). **Teste:** trocar no menu muda na hora.
9. `LifeStageClock` (seção 9), com `segundos_por_estagio = 10` para ver as cinco
   fases em menos de um minuto.
10. `tests/character_age_test.gd` (seção 12).

## 14. Erros que vão acontecer

**"A idade some quando eu ando."**
`set_direction()` reescreve `bone.position` a cada troca de direção. Se você
esqueceu de chamar `apply_age_shape()` dentro dele (item (d) da seção 5.1), a
proporção volta ao adulto no primeiro passo para o lado.

**"A curvatura do idoso não aparece."**
`rotation` é escrito pelo `AnimationPlayer` todo quadro. Se você pôs a curvatura
em `_ready()` ou direto no `.tscn`, ela dura um quadro. Tem que ser no `_process`
com `process_priority = 100` (seção 5.2).

**"O idoso vai entortando até deitar."**
É o `+=` acumulando com a animação parada. O desconto de `_postura_aplicada`
existe exatamente para isso — confira que ele não sumiu.

**"O bebê flutua / afunda no chão."**
`apoio_pes_y` está errado. Selecione `ponta_pe_e` no editor com o rig em repouso
e leia o Y dele relativo ao `Skeleton2D`. O valor padrão (3.34) vale para a arte
atual; arte nova pede medida nova.

**"A calça não encolheu junto."**
A roupa acompanha porque é filha do osso. Se não acompanhou, ou você escalou o
`Sprite2D` do corpo em vez do `Bone2D`, ou escalou um osso que não é raiz de
cadeia. Escale `coxa_e` / `coxa_d`, nunca `perna_e`.

**"Animação não encontrada: bebe_masc/walk_se."**
Falta o fallback do item (c) da seção 5.3, ou `biblioteca_animacao` aponta para
uma biblioteca que não foi adicionada no `AnimationPlayer`.

**"Todos os NPCs mudaram de idade junto."**
`CapsuleShape2D` compartilhada. O `duplicate()` no `_ready()` do `AgeBody` existe
para isso — é o mesmo cuidado que o projeto já toma com `ShaderMaterial`.

**"O braço fica torto quando o personagem anda."**
`fator_largura` fora da faixa. É a única escala não uniforme; acima de ~1,25 o
cisalhamento nos ossos girados começa a aparecer. Volte para perto de 1.0.

## 15. Checklist

- [ ] Os cinco `.tres` existem e o `adulto` tem todos os fatores em 1.0.
- [ ] Com `age = adulto`, o jogo está **pixel a pixel** igual ao de antes.
- [ ] Trocar de direção não perde a proporção.
- [ ] Roupa, sapato, cabelo, chapéu e saia acompanham as cinco idades.
- [ ] O pé encosta no chão em todas as idades (teste automatizado cobre).
- [ ] O idoso curva o tronco e continua curvado depois de parar de andar.
- [ ] A colisão do bebê é menor que a do adulto, e são objetos distintos.
- [ ] O bebê não corre e não agacha.
- [ ] O menu lista as cinco idades e o preview reage na hora.
- [ ] `LifeStageClock` avança bebê → criança → … → idoso e para no idoso.
- [ ] `character_age_test.gd` passa.
- [ ] Nenhum `if idade ==` em lugar nenhum do código.

## 16. Árvore final

```text
Main
├── World
│   └── DepthSort/Entities/PlayerAnchor
│       └── Player                        (CharacterBody2D)
│           ├── WorldGridAgent
│           ├── AppearanceState           + age_catalog
│           ├── AgeBody                   ← NOVO (colisão + sombra)
│           ├── CollisionShape2D
│           ├── VisualAnchor
│           │   └── CharacterViewport/CharacterStage
│           │       └── CharacterVisual
│           │           ├── Skeleton2D    (CharacterRig + proporção)
│           │           ├── SaiaDeformavel
│           │           ├── WardrobePresenter
│           │           ├── CharacterColorPresenter
│           │           ├── CharacterAgePresenter   ← NOVO
│           │           └── AnimationPlayer
│           ├── BedSleepInteractor
│           └── Camera2D
├── LifeStageClock                        ← NOVO
│   └── Timer
└── Interface
    ├── HUD
    └── CharacterCustomizationMenu        + AgeRow
```

Fluxo de sinais, do gatilho ao pixel:

```text
LifeStageClock.stage_changed
        ↓
AppearanceState.set_age → valida → appearance_changed
        ├────────────→ CharacterVisual.present_appearance → AgePresenter → CharacterRig
        └────────────→ AgeBody.present_appearance → colisão
                              └→ age_body_changed → PlayerController (velocidade)
```

Nenhuma seta sobe de volta. É o mesmo desenho do tutorial de arquitetura em
camadas, com uma dimensão a mais.

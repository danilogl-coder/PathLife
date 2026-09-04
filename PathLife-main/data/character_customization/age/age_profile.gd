class_name AgeProfile
extends Resource
## UMA fase da vida. É só dado: não existe em lugar nenhum do projeto um
## "if idade == bebe". Uma idade nova é um .tres novo, sem uma linha de código.
##
## POR QUE PROPORÇÃO E NÃO UM CONJUNTO DE ARTE POR IDADE
## As animações do rig só escrevem `rotation` nos ossos (conferido nas duas
## bibliotecas). Isso deixa `Bone2D.position` e `Bone2D.scale` livres, e é aí
## que a idade mora: escalando a RAIZ de cada cadeia, roupa, mão, pé, sapato e
## cabelo acompanham sozinhos, porque todos são filhos daquele osso. Cinco
## idades saem sem um PNG novo. Quando a proporção não bastar (o bebê é o caso),
## `pasta_arte` liga um conjunto dedicado sem tocar em código.

@export_category("Identidade")
@export var id: StringName = &"adulto"
@export var display_name: String = "Adulto"
## Posição na linha do tempo. O LifeStageClock avança por este número.
@export_range(0, 16, 1) var ordem: int = 3

@export_category("Arte")
## Prefixo da pasta em assets/characters/cutout. Vazio = usa a arte do corpo.
## Com "bebe", o rig procura "bebe_masc/rig.json" e cai em "masc/rig.json"
## quando a pasta não existe. É isto que deixa você trocar proporção por arte
## de verdade, uma idade de cada vez.
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
## Única escala não uniforme do sistema, e por isso ela mora na raiz do
## Skeleton2D. Acima de ~1.25 o cisalhamento nos ossos girados aparece.
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

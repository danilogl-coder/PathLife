@tool
class_name HairPhysicsProfile
extends Resource
## Como UMA cadeia de cabelo reage. Nao sabe qual penteado esta usando ela.
##
## Um bob curto e um cabelo ate' a cintura nao podem balancar igual, e a
## diferenca entre os dois mora inteira aqui -- nenhum script pergunta o nome do
## penteado. Trocar a fisica de um cabelo e' apontar para outro .tres.
##
## AS UNIDADES SAO TODAS FISICAS, NAO "0 A 1"
## 'frequencia' e' Hz de verdade e 'amortecimento' e' razao de amortecimento de
## verdade (1,0 = critico). Numero adimensional de 0 a 1 obriga a decorar o que
## cada um faz; assim da' para raciocinar: 1,2 Hz e 0,25 e' um pendulo lento que
## passa do ponto, e e' exatamente isso que cabelo comprido faz.

@export var ativo: bool = true

@export_group("Mola")
## Frequencia propria do PRIMEIRO osso, em Hz. Curto = alto (responde rapido e
## quase nao sai do lugar); comprido = baixo (chega atrasado e passa do ponto).
@export_range(0.2, 8.0, 0.05) var frequencia: float = 2.2
## Razao de amortecimento. 1,0 = critico: para no alvo sem passar. Abaixo de 1 e'
## que existe o "ultrapassa e volta" -- e' esse excesso que le' como peso.
## Cabelo que toca por tres segundos depois de parar le' como gelatina, nao como
## cabelo. Medido: com 0,26 a ponta so' cai abaixo do passo de arredondamento
## (1,5 graus, o limiar do que chega a aparecer) 3,2s depois da parada.
@export_range(0.05, 1.5, 0.01) var amortecimento: float = 0.36
## Cada osso e' mais mole que o anterior. A ponta de uma cadeia com este valor em
## 0,8 tem frequencia 0,8^(n-1) da raiz. E' o que faz o atraso se ACUMULAR ao
## longo da mecha em vez de todos os ossos chegarem juntos.
@export_range(0.4, 1.0, 0.01) var maciez_por_osso: float = 0.78

@export_group("Resposta ao movimento")
## Graus de balanco por unidade de ACELERACAO horizontal de tela. E' o termo
## principal: acelerar para a direita joga a ponta para a esquerda.
@export_range(0.0, 0.5, 0.001) var ganho_aceleracao: float = 0.070
## Graus por unidade de VELOCIDADE horizontal. Pequeno de proposito: velocidade
## sozinha faz o cabelo ficar torto o tempo todo enquanto anda, que e' o erro
## classico. Serve so' para dar um vies enquanto o personagem esta em curso.
@export_range(0.0, 0.3, 0.001) var ganho_velocidade: float = 0.012
## Quanto o osso persegue a VERTICAL DE TELA em vez de acompanhar o osso pai.
## Em 1,0 o cabelo obedece a' gravidade: o personagem se abaixa, a cabeca gira, e
## a mecha continua caindo em vez de sair na horizontal. Em 0,0 ela e' filha
## rigida do pai. Raiz costuma querer pouco; ponta costuma querer muito.
@export_range(0.0, 1.0, 0.01) var influencia_gravidade: float = 0.65

@export_group("Limites")
## Teto de rotacao do osso mais solto da cadeia, em graus. Os de cima recebem
## menos, pela curva de amplitude. Existe para a mola nunca poder atravessar a
## cabeca nem girar a mecha de ponta-cabeca, aconteca o que acontecer com o dt.
@export_range(0.0, 60.0, 0.5) var limite_graus: float = 12.0
## Teto do ANGULO ENTRE um osso e o anterior. Impede o cotovelo: com so' o teto
## absoluto, dois ossos podem chegar aos extremos opostos e a mecha dobra.
@export_range(0.0, 40.0, 0.5) var limite_entre_ossos: float = 8.0
## RAIZ NAO BALANCA. A amplitude de cada osso e' (i/(n-1))^expoente: com 1,6 o
## primeiro osso solto pega ~19% e a ponta 100%. Aumentar deixa a raiz ainda mais
## presa. E' o que impede o "cabelo inteiro balancando como uma placa".
@export_range(0.5, 4.0, 0.1) var expoente_amplitude: float = 1.6
## Se preenchida, substitui o expoente. X = posicao na cadeia (0 raiz, 1 ponta),
## Y = fracao da amplitude. Para quem quer desenhar a curva no Inspector.
@export var curva_amplitude: Curve

@export_group("Idle")
## Amplitude do balanco parado, em graus. Fica na casa do meio grau de proposito:
## idle tem que impedir que o cabelo pareca congelado, nao chamar atencao.
@export_range(0.0, 3.0, 0.05) var idle_graus: float = 0.35
## Duas senoides de frequencias incomensuraveis, para nao fechar ciclo visivel.
@export_range(0.0, 2.0, 0.01) var idle_hz: float = 0.23

@export_group("Estabilidade")
## Abaixo desta velocidade de ancora (px/s) a aceleracao e' tratada como zero.
## Sem isso, ruido de subpixel com o personagem parado vira tremedeira.
@export_range(0.0, 40.0, 0.1) var limiar_parado: float = 1.5
## Salto de posicao maior que isto num quadro e' teleporte, nao movimento: a
## fisica reseta em vez de interpretar como aceleracao gigante.
@export_range(8.0, 4096.0, 1.0) var distancia_teleporte: float = 64.0
## PIXEL ART: a rotacao final e' arredondada para multiplos disto, em graus. Com
## 0 o sprite reamostra a cada quadro e os pixels "andam" sozinhos; com 1,5 ele
## so' troca de pose em degraus, que e' o que pixel art rotacionada faz. A fisica
## continua em float por dentro -- o arredondamento e' so' na apresentacao.
@export_range(0.0, 15.0, 0.25) var passo_angulo_graus: float = 1.5
## Arredonda a posicao de tela de cada peca para pixel inteiro na apresentacao.
@export var arredondar_posicao: bool = true

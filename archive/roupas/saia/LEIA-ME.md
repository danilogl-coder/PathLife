# Saia deformável — Polygon2D + Skeleton2D

Refeita do zero. A anterior era sprite **rígido** recortado em pedaços que
giravam; pedaço rígido não dobra, só muda de ângulo. Esta é uma **malha** cujos
vértices são arrastados por pesos de osso, então o pano muda de **forma**.

---

## Antes de mais nada: o que eu não pude fazer

Você pediu para inspecionar a árvore de nós, o `Skeleton2D`, o sistema de troca
de roupas, o controle de direção e as configurações de importação. **A pasta a
que tenho acesso é só a de assets** — não há `project.godot`, `.tscn`, `.import`
nem os scripts do personagem.

Então não integrei nada à sua cena, porque isso exigiria inventar nomes de nós,
que é exatamente o que você proibiu. O que está aqui é autocontido e a
integração é um passo manual seu, documentado abaixo.

Pela mesma razão **não gerei arquivos `.import`**: eles carregam um hash e um
UID do projeto, e um `.import` fabricado quebraria a importação em vez de
ajudar. A configuração de filtro está resolvida de outro jeito, também abaixo.

---

## Arquivos

| arquivo | o que é |
|---|---|
| `saia_malha.json` | malha, UV, triângulos, pesos, ossos e z — por corpo e direção |
| `masc/` `fem/` `<dir>/frente.png` `tras.png` | 16 texturas |
| `saia_recurso.gd` | `Resource` com os dados e o ajuste do pano |
| `saia_malha.gd` | monta a malha, os pesos e a ordem visual |
| `saia_balanco.gd` | movimento secundário |
| `saia_deformavel.tscn` | os nós prontos, para instanciar |
| `saia_rosa.tres` | exemplo de recurso |

---

## Estrutura

```
Skeleton2D
└── Quadril (Bone2D)
    ├── CoxaE / CoxaD          (já existem)
    └── SaiaRaiz (Bone2D)      ← criado em execução
        ├── SaiaEsq  └── BarraEsq
        ├── SaiaCen  └── BarraCen
        └── SaiaDir  └── BarraDir

SaiaDeformavel (Node2D, saia_malha.gd)
├── SaiaTras    (Polygon2D)   z = min(z das pernas) − 1
├── SaiaFrente  (Polygon2D)   z = max(z das pernas) + 1
└── SaiaBalanco (Node, saia_balanco.gd)
```

**Os dois Polygon2D vivem na cena** e são editáveis no Inspector. **Os sete
Bone2D são criados por código**, e não por preguiça: a posição de repouso de cada
um muda por **direção**, porque a silhueta da saia muda. Isso não pode viver
estático na cena.

---

## A malha sai da própria silhueta

Não desenhei o polígono à mão. Para cada linha de pixel da silhueta renderizada,
o gerador acha o primeiro e o último pixel cheio e distribui 9 colunas entre
eles. **261 vértices, 448 triângulos, 29 linhas** por corpo/direção.

Isso dá três coisas de graça:

- a borda esquerda e a direita seguem o contorno com erro de subpixel;
- topo e barra caem nas linhas extremas reais, então a curva do cone em
  isométrico é respeitada sem caso especial;
- **a mesma função serve para qualquer saia futura** — é só trocar a textura.

A UV é a posição do vértice na própria textura. **Em repouso o Polygon2D desenha
exatamente o sprite: verificado, 0 px de diferença.** Adotar malha não mexeu na
pixel art.

Duas armadilhas de subpixel que custaram esses 0 px: a linha de vértices tem que
ficar no **centro** da linha de pixels, não na borda de cima — senão a lateral
interpolada corta a quina da escada; e a primeira e a última linha vão para a
borda externa, senão a última fileira de pixels fica de fora do polígono.

A diagonal dos quads **alterna** (`(r+c)%2`). Com a diagonal sempre no mesmo
sentido, a textura dobra em zigue-zague quando a malha estica.

---

## Frente e trás são o mesmo polígono, duas texturas

A perna fica **dentro** do cone da saia. Então o que resolve a ordem visual é um
painel na frente da perna e outro atrás, os dois com a silhueta inteira:

```
SaiaTras  →  pernas  →  SaiaFrente
```

Em repouso o da frente cobre o de trás e não se vê diferença. Quando a malha
deforma, o de trás aparece na fresta — e ele é a **face interna do tecido**
(mesma geometria, rampa mais escura). Nenhuma colisão envolvida.

Os dois z vêm do `rig.json`, por direção, calculados dos z das próprias pernas.
Não há um segundo sistema de direção: `configurar(corpo, direcao)` é chamada do
mesmo lugar de onde o resto do rig já troca.

---

## Os pesos

| região | quem manda |
|---|---|
| cintura | `SaiaRaiz` ~1,0 |
| meio | `SaiaEsq/Cen/Dir`, repartidos por três funções-tenda em 0,14 / 0,50 / 0,86 |
| barra | `BarraEsq/Cen/Dir` |
| coluna da coxa, da cintura até a barra | a coxa, **com teto de 0,52** |

O teto existe para a saia não virar duas pernas de pano. Comecei em 0,22 e a
varredura mostrou que era conservador demais. O valor de agora saiu da medição,
não de chute — e a influência ficou **concentrada na coluna da perna** (tenda
lateral mais estreita e mais forte). Espalhada, ela puxava o centro junto, e era
aí que a saia ameaçava rachar.

O resto é normalizado tirando proporcionalmente dos ossos da saia. Verificado:
**a soma dos pesos desvia de 1,0 no máximo 0,0002** (arredondamento de 4 casas).
Se não somasse 1, o vértice encolheria para a origem do `Skeleton2D` e a saia
teria um bico preso no chão.

**Peso sozinho não bastou.** A coxa viaja muito mais do que 52% de um vértice
consegue acompanhar. Por isso o `SaiaBalanco` tem um **canal da perna**: o osso
da saia sobre aquela coluna gira junto com a coxa, então o painel inteiro
acompanha. A rotação da coxa é local ao quadril, o mesmo pai da raiz da saia —
mesmo referencial de tela, e não existe tabela por direção.

E **peso arrasta pano, mas não cria pano onde não há**: a barra ganhou 1,2 px de
folga de cada lado (16,6 → 18,4 no gabarito), que é o espaço físico que um
joelho levantado precisa.

---

## Movimento secundário

Mola amortecida procedural nos seis ossos da saia. Nada de `RigidBody2D` nem
cadeia de colisões.

**Pêndulo de tela, sem tabela por direção.** A saia pendura para baixo na tela e
a gravidade projeta para baixo na tela. O que balança o pano é a componente
**horizontal** da aceleração do quadril, medida na tela — a conta já acontece no
espaço certo, então trocar de direção não muda nada aqui.

**Segundo estágio.** A barra persegue o corpo da saia com mola mais mole (1,6 Hz
contra 2,4) e menos amortecida (0,24 contra 0,34): chega depois e passa do
ponto. É esse atraso que faz a barra ler como tecido.

Os requisitos, um a um:

- **Não gira livremente / não acumula energia** — teto aplicado *depois* da
  integração, e o estado da barra é reescrito com o valor limitado (`_bar = _ang
  + atraso`), então o excesso não fica guardado.
- **Não depende da taxa de quadros** — integração semi-implícita com `delta`, e
  os filtros usam `1 - exp(-delta * k)`.
- **Não treme parada** — abaixo de `limiar_parado` (1,5 px/s de velocidade do
  quadril) o alvo é exatamente zero, então a mola converge para o repouso em vez
  de perseguir ruído de subpixel.
- **Reinicia certo** — `repousar()` é chamado automaticamente em toda
  reconfiguração (troca de direção ou de corpo), via o sinal `reconfigurada`.
  Chame também ao equipar, remover e teleportar.
- **Não disputa osso com o `AnimationPlayer`** — os seis ossos são criados pelo
  `SaiaMalha` e não existem em nenhuma `AnimationLibrary`. E o nó roda com
  `process_priority = 100`, então lê o quadril depois que a animação escreveu a
  pose do quadro.
- **Desempenho** — referências em cache no `_ready` e no sinal, nada de
  `get_node` por quadro, nenhum objeto temporário no laço, e `_process` retorna
  imediatamente se a saia não está visível na árvore.

---

## Parâmetros no Inspector (no `SaiaRecurso`)

| campo | padrão | efeito |
|---|---:|---|
| `rigidez` | 2,4 Hz | frequência própria do corpo da saia |
| `amortecimento` | 0,34 | **abaixo de 1 ela passa do ponto e volta** |
| `ganho` | 0,055 | graus por unidade de aceleração |
| `limite` | 12° | teto do balanço |
| `rigidez_barra` | 1,6 Hz | ponta solta é mais mole |
| `amortecimento_barra` | 0,24 | **é aqui que mora o atraso da barra** |
| `limite_barra` | 7° | teto do atraso |
| `limiar_parado` | 1,5 px/s | abaixo disso, congela — é o antitremor |

Saia justa: `ganho` 0,03 e `limite` 7. Saia rodada: 0,08 e 16. Tecido pesado:
`amortecimento` 0,6 com `rigidez` 1,5.

---

## Integrar no seu projeto

1. Copie esta pasta para `res://saia/` (ou ajuste os caminhos no `.tres` e no
   `.tscn`).
2. Instancie `saia_deformavel.tscn` como filha do nó do personagem — **fora** do
   `Skeleton2D`.
3. No Inspector do nó raiz preencha: `recurso`, `esqueleto` (o `Skeleton2D`),
   `osso_quadril`, `osso_coxa_esq`, `osso_coxa_dir`.
4. No `saia_rosa.tres`, aponte `dados` para `saia_malha.json` e
   `pasta_texturas` para a pasta que contém `masc/` e `fem/`.
5. Onde o seu rig já troca de direção, acrescente uma linha:

```gdscript
saia.configurar(corpo_atual, direcao)   # ex.: &"fem", &"se"
```

6. Ao equipar: `saia.visible = true` e `saia.configurar(...)`.
   Ao remover: `saia.visible = false` — o `_process` do balanço já sai fora
   sozinho quando o painel não está visível na árvore.

### Filtro Nearest

Em vez de `.import` por arquivo, resolva no projeto inteiro, que é o certo para
pixel art:

**Project Settings → Rendering → Textures → Canvas Textures → Default Texture
Filter = Nearest**

Os dois `Polygon2D` já vêm com `texture_filter = 1` (Nearest) explícito no
`.tscn`, então eles ficam nítidos mesmo se o padrão do projeto for outro. Deixe
também mipmaps e repeat desligados nas texturas da saia.

---

## Uma saia nova

Trocar de modelo de saia **não encosta em nenhum script**:

1. No `corpo_lib.py`, mude a função `_f_saia` (ou faça outra) e a rampa de cor.
2. Rode `gerar_saia_malha.py` — ele monta malha, pesos e texturas sozinho a
   partir da silhueta nova.
3. Duplique `saia_rosa.tres`, aponte para o JSON novo e ajuste o pano.
4. Troque o `recurso` no Inspector.

O `SaiaMalha` só sabe montar malha e o `SaiaBalanco` só sabe balançar osso.
Nenhum dos dois conhece uma saia específica.

---

## A varredura: onde a perna saía da saia

`verificar_saia.py` roda as 7 animações × 4 direções × 2 corpos, quadro a
quadro, com a mesma física e o mesmo LBS da prévia, e conta pixel de perna
aparecendo onde não devia.

### A primeira definição de defeito estava errada

Comecei contando como falha todo pixel de perna acima da barra. Deu **244 px** no
pior quadro — e, olhando o quadro marcado em vermelho, a "falha" era a perna
**chutada para fora** da saia, ao lado dela. Perna fora da saia não está
atravessando pano nenhum.

A definição certa é de **vão**: um pixel de perna é falha quando, na mesma
coluna, existe pano **acima e abaixo** dele e ele não está no pano. Ou seja, o
tecido se abriu e a perna apareceu pelo meio.

### O que sobrou

| | antes | depois |
|---|---:|---:|
| pior quadro (fem) | 244 px | **8 px** |
| `sit` | 252 px | 2 px |
| `run` | 210 px | 8 px |
| `walk` | 53 px | 1 px |
| pior quadro (masc) | — | 5 px |

Três mudanças, nessa ordem de impacto: o **canal da perna** nos ossos da saia, o
**teto da coxa** de 0,22 para 0,52 concentrado na coluna da perna, e **1,2 px de
folga** na barra.

Os 8 px que sobram são lascas de **1 px na própria borda da silhueta**, nos dois
quadros mais rápidos da corrida: a perna passa rente ao pano e sobra uma coluna
de pele entre o contorno dela e o da saia. Não é tecido abrindo — é a resolução.
Fechar isso exigiria engordar o polígono, o que quebraria os 0 px de diferença
em repouso. Preferi manter a nitidez.

## Como validei

| checagem | resultado |
|---|---|
| soma dos pesos por vértice | desvio máximo de 1,0: **0,0002** |
| malha em repouso vs sprite original | **0 px** de diferença |
| perna aparecendo em vão do tecido | **8 px** no pior quadro (era 244) |
| deformação nas 7 animações × 4 direções | prévias em `animacoes/previa/saia_*.gif` |
| roupas anteriores | `gerar_roupas.py` roda sem a saia: **9 peças, 208 PNGs, 0 px** em remontagem, vão e giro |
| animações existentes | intocadas — a saia não usa nenhum osso do corpo como alvo de escrita |

As prévias rodam **o mesmo JSON de pesos** e reproduzem *linear blend skinning*
(`Σ wᵢ · Mᵢ · Rᵢ⁻¹ · v`), que é a conta que o `Polygon2D` faz. Se a prévia usasse
uma deformação própria, estaria provando outra coisa.

### O que não consegui validar, e é honesto dizer

Sem o projeto, **não rodei nada dentro do Godot**. Os itens da sua lista que
dependem de execução — pausar e retomar, recarregar a cena, vários personagens
ao mesmo tempo, trocar de direção enquanto se move — estão *implementados* com
esse cuidado (reset por sinal, sem estado global, `delta` em tudo), mas não
testados em jogo. Me dê acesso ao projeto e eu fecho essa parte.

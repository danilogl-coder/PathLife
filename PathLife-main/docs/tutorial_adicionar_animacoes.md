# Tutorial: criar e editar animações do personagem

Este guia usa a estrutura que já existe no projeto PathLife. Ele não cria outro
esqueleto e não coloca animação no `Player`: toda animação visual continua no
`CharacterVisual`, separada da movimentação e da colisão.

## 1. Como o projeto organiza as animações

A cena visual é:

```text
res://presentation/characters/cutout/character_visual.tscn
```

Sua parte importante é:

```text
CharacterVisual (Node2D)
├── Skeleton2D
│   └── quadril (Bone2D)
│       ├── torso
│       │   ├── cabeca
│       │   ├── braco_sup_e → braco_inf_e → mao_e
│       │   └── braco_sup_d → braco_inf_d → mao_d
│       ├── coxa_e → perna_e → pe_e
│       └── coxa_d → perna_d → pe_d
├── SaiaDeformavel
├── WardrobePresenter
├── CharacterColorPresenter
└── AnimationPlayer
```

O `AnimationPlayer` possui duas bibliotecas externas:

| Biblioteca | Arquivo | Corpo |
|---|---|---|
| `masc` | `animation/animacoes_masc.tres` | masculino |
| `fem` | `animation/animacoes_fem.tres` | feminino |

Já existem 28 animações em cada biblioteca: `idle`, `walk`, `run`, `pick`,
`sit`, `sleep` e `wave`, cada uma nas quatro direções.

O nome completo visto pelo `AnimationPlayer` tem este formato:

```text
biblioteca/ação_direção
```

Exemplos:

```text
masc/walk_se
masc/wave_nw
fem/sit_ne
fem/sleep_sw
```

As direções do projeto são:

| Sufixo | Sentido no controle | Direção vista no mundo |
|---|---|---|
| `ne` | W / cima | nordeste |
| `nw` | A / esquerda | noroeste |
| `se` | D / direita | sudeste |
| `sw` | S / baixo | sudoeste |

Portanto, uma ação nova chamada `dance` precisa idealmente de oito animações:

```text
masc/dance_ne  masc/dance_nw  masc/dance_se  masc/dance_sw
fem/dance_ne   fem/dance_nw   fem/dance_se   fem/dance_sw
```

Para aprender, comece somente com `masc/dance_se`. Depois que ela estiver boa,
faça as outras sete.

## 2. Abra o lugar correto no Godot

1. No painel **FileSystem**, abra a pasta
   `presentation/characters/cutout`.
2. Dê duplo clique em `character_visual.tscn`.
3. Na árvore da cena, selecione o nó `AnimationPlayer`.
4. O painel **Animation** aparecerá na parte inferior do editor.
5. No seletor de animação desse painel, escolha `masc/wave_se`.

Se você não enxergar o painel inferior, clique em **Animation** na barra de
painéis inferiores. Ele só fica utilizável quando o `AnimationPlayer` está
selecionado.

Agora pressione o triângulo de reprodução do próprio painel **Animation**. O
personagem deve acenar no editor. Isso prova que você abriu o nó certo.

## 3. Entenda o painel Animation

O painel inferior funciona como uma linha do tempo:

```text
0.00 s                 0.60 s                 1.20 s
  │----------------------│----------------------│
  chave                 chave                  chave
```

- A linha vertical é o cursor do tempo.
- Cada linha é uma propriedade animada, por exemplo a rotação do braço.
- Cada losango é um **keyframe**, ou quadro-chave.
- O Godot calcula os valores intermediários entre dois keyframes.
- O campo de duração define quantos segundos a animação possui.
- O botão de loop define se ela recomeça ao chegar ao final.
- O passo da linha do tempo não é a duração. Ele apenas controla o encaixe do
  cursor e das chaves.

O personagem é pixel art, mas a animação não é um `AnimatedSprite2D` trocando
imagens. São os `Bone2D` que giram, levando seus sprites e roupas junto.

## 4. Crie uma animação sem começar do zero

O método mais seguro é duplicar uma animação que já possui todas as tracks.

1. Selecione `AnimationPlayer`.
2. No painel inferior, abra o menu **Animation**.
3. Entre em **Manage Animations…**.
4. Selecione a biblioteca `masc` à esquerda.
5. Selecione `wave_se` na lista de animações.
6. Use **Duplicate** — o ícone normalmente mostra duas folhas.
7. Nomeie a cópia exatamente `dance_se`, sem escrever `masc/` no nome interno.
8. Feche a janela de gerenciamento.
9. No seletor do painel inferior, confirme que aparece `masc/dance_se`.
10. Pressione `Ctrl+S`.

Se a sua disposição do editor mostrar o comando **Duplicate** diretamente no
menu **Animation**, ele faz a mesma coisa. Confirme apenas que a cópia ficou
dentro da biblioteca `masc`, e não em uma biblioteca vazia chamada `global`.

Duplicar é melhor que criar vazio porque a cópia já contém tracks válidas para
todos os ossos. Você pode apagar as chaves indesejadas sem precisar digitar
caminhos de nós manualmente.

## 5. Defina duração e loop

Com `masc/dance_se` selecionada:

1. Defina a duração, por exemplo `1.20` segundo.
2. Ative **Loop** se a dança deve repetir continuamente.
3. Desative **Loop** se for uma ação que acontece uma vez, como atacar, pegar
   um objeto ou cair.
4. Para um loop suave, a pose no último instante deve ser igual à pose de
   `0.00`. Caso contrário haverá um salto quando a animação recomeçar.

Sugestões iniciais:

| Tipo | Duração aproximada | Loop |
|---|---:|---|
| respiração / idle | 1.2–2.0 s | ligado |
| caminhada | 0.5–0.8 s | ligado |
| corrida | 0.35–0.55 s | ligado |
| acenar | 0.8–1.4 s | depende do uso |
| ataque / pegar | 0.3–0.9 s | desligado |
| dança | 1.0–3.0 s | ligado |

## 6. Como mover uma parte do corpo

Não mova o `Sprite2D` chamado `Sprite`. Se você mover o sprite, apenas separará
a imagem do pivô. Selecione e anime o `Bone2D` que é pai desse sprite.

Exemplo: levantar o braço esquerdo.

1. No painel **Animation**, escolha `masc/dance_se`.
2. Coloque o cursor em `0.00` segundo.
3. Na árvore, selecione
   `Skeleton2D/quadril/torso/braco_sup_e`.
4. No Inspector, abra **Transform**.
5. Localize **Rotation** ou **Rotation Degrees**.
6. Ajuste a rotação. Você pode digitar um valor ou girar o osso pela alça do
   editor 2D.
7. Clique no pequeno ícone de chave à direita de **Rotation**.
8. Se o Godot perguntar se deve criar a track, confirme.
9. Mova o cursor para `0.30` segundo.
10. Altere a rotação novamente e clique na chave.
11. Mova o cursor para `0.60` e crie outra pose.
12. Pressione o triângulo do painel para assistir ao resultado.

Para dobrar o cotovelo, selecione `braco_inf_e`. Para girar a mão, selecione
`mao_e`. A mesma lógica vale para as pernas.

## 7. Qual osso controla cada parte

| Parte visual | Bone2D que deve ser animado |
|---|---|
| corpo inteiro / base | `quadril` |
| peito e tudo acima dele | `torso` |
| cabeça e cabelos | `cabeca` |
| braço esquerdo superior | `braco_sup_e` |
| antebraço esquerdo | `braco_inf_e` |
| mão esquerda | `mao_e` |
| braço direito superior | `braco_sup_d` |
| antebraço direito | `braco_inf_d` |
| mão direita | `mao_d` |
| coxa esquerda | `coxa_e` |
| canela esquerda | `perna_e` |
| pé esquerdo | `pe_e` |
| coxa direita | `coxa_d` |
| canela direita | `perna_d` |
| pé direito | `pe_d` |

Os ossos formam uma hierarquia. Girar `braco_sup_e` também leva consigo
`braco_inf_e` e `mao_e`. Girar somente `mao_e` não move o antebraço.

## 8. O que pode e o que não pode ser animado

Neste projeto, anime principalmente:

- `Bone2D.rotation`;
- `CharacterVisual.position:y`, somente para um balanço vertical discreto;
- `scale`, apenas quando houver uma intenção visual específica.

Não anime normalmente:

- a `position` dos ossos;
- os `Sprite2D.offset`;
- as texturas dos sprites;
- `z_index` para corrigir perspectiva;
- `Player.position`;
- `CollisionShape2D.position`.

As posições, texturas e ordens de profundidade dos ossos mudam conforme a
direção e são aplicadas pelo `CharacterRig`. Uma track de posição pode disputar
com o rig e desmontar o personagem ao virar. A ordem isométrica também já é
responsabilidade do rig, não da animação.

A saia e o cabelo possuem controladores físicos próprios. Anime os ossos
normais do corpo; não crie tracks diretamente para os segmentos físicos deles.

## 9. Criando poses com Auto Key

O painel possui um modo de chave automática, geralmente representado por uma
chave vermelha. Ele cria ou atualiza keyframes quando uma propriedade já
animada é alterada.

Para começar, deixe **Auto Key desligado** e use o botão de chave do Inspector.
Isso evita gravar acidentalmente posição, escala ou outra propriedade errada.

Quando você já entender as tracks:

1. Ative Auto Key.
2. Posicione o cursor no tempo desejado.
3. Gire os ossos da pose.
4. Confira quais losangos foram criados.
5. Desative Auto Key ao terminar.

## 10. Apagar ou corrigir um keyframe

- Para mover uma chave no tempo, arraste o losango horizontalmente.
- Para alterar seu valor, coloque o cursor exatamente sobre ela, selecione o
  osso, mude a rotação e grave a chave novamente.
- Para apagar, selecione o losango e pressione `Delete`.
- Para copiar uma pose, selecione as chaves, pressione `Ctrl+C`, coloque o
  cursor em outro tempo e pressione `Ctrl+V`.
- Use `Ctrl+Z` imediatamente se uma peça saltar para um lugar estranho.

Não apague a track `RESET` do projeto nem crie uma animação chamada `RESET`
sem saber exatamente qual propriedade ela precisa restaurar.

## 11. Faça as quatro direções

Depois de terminar `masc/dance_se`:

1. Duplique para `dance_ne`, `dance_nw` e `dance_sw` dentro de `masc`.
2. Selecione cada direção no painel.
3. Ajuste as rotações porque o braço que fica na frente muda conforme a
   perspectiva.
4. Use como referência `wave_ne`, `wave_nw`, `wave_se` e `wave_sw`. Elas mostram
   como os braços foram adaptados em cada direção.
5. Repita as quatro animações na biblioteca `fem`.

Não copie o arquivo `.tres` masculino por cima do feminino. Os dois corpos
podem precisar de poses ligeiramente diferentes e já possuem bibliotecas
separadas para isso.

## 12. Reproduza a animação no próprio editor

Este é o teste mais rápido e não exige código:

1. Abra `character_visual.tscn`.
2. Selecione `AnimationPlayer`.
3. Escolha `masc/dance_se`.
4. Volte o cursor para `0.00`.
5. Clique no triângulo **Play selected animation** do painel inferior.
6. Clique no quadrado de parada para interromper.
7. Arraste o cursor lentamente para inspecionar cada pose.

Se o personagem permanecer numa pose depois de você parar a prévia, escolha
uma animação `idle_se`, leve o cursor a `0.00` ou use o botão de reset da prévia.
Isso é apenas o estado visual do editor, não uma alteração permanente, desde
que você não grave novas chaves.

## 13. Teste a seleção automática de gênero e direção

O método público já existente é:

```gdscript
character_visual.play_action(&"dance")
```

Você fornece somente `dance`. O `CharacterVisual` monta o nome completo usando
o corpo e a direção atuais:

```gdscript
"%s/%s_%s" % [rig.body_type, action, direction]
```

Assim, um corpo feminino olhando para noroeste tentará tocar:

```text
fem/dance_nw
```

Para um teste temporário, você pode chamar o método a partir de um script de
teste que tenha uma referência tipada ao `CharacterVisual`:

```gdscript
@onready var character_visual: CharacterVisual = $VisualAnchor/CharacterVisual

func _ready() -> void:
    character_visual.play_action(&"dance")
```

Remova essa chamada depois do teste. Não a deixe permanentemente em `_ready()`
se a ação não deve acontecer sempre que a cena abrir.

## 14. Como ligar uma ação a uma tecla sem misturar arquitetura

O projeto separa responsabilidades:

```text
Input → PlayerController → sinal → CharacterVisual → AnimationPlayer
```

O `PlayerController` detecta a tecla, mas não conhece nomes completos como
`masc/dance_se`. O `CharacterVisual` escolhe a biblioteca e a direção.

Para integrar definitivamente uma ação, o caminho correto é:

1. Criar uma ação como `action_dance` em **Project > Project Settings > Input
   Map**.
2. Declarar no `PlayerController` um sinal, por exemplo:

```gdscript
signal action_requested(action: StringName)
```

3. Ao detectar `Input.is_action_just_pressed("action_dance")`, emitir:

```gdscript
action_requested.emit(&"dance")
```

4. Na cena `player.tscn`, conectar esse sinal ao método público
   `CharacterVisual.play_action`.

Não coloque leitura de teclado dentro de `character_visual.gd`. Esse script é
apresentação e também é reutilizado no preview do menu, onde não deve responder
ao teclado do mundo.

### Atenção para ações de uma única execução

Atualmente `idle`, `walk` e `run` são estados de locomoção. `play_action()` toca
uma ação visual, mas a arquitetura ainda não bloqueia a locomoção nem restaura
automaticamente o idle ao terminar uma ação avulsa.

Para um teste visual isso não é problema. Para implementar ataque, coleta ou
dança como mecânica completa, também será necessário:

- decidir se o jogador pode andar durante a ação;
- impedir `walk` ou `run` de substituir a ação antes da hora;
- ouvir o sinal `animation_finished` do `AnimationPlayer`;
- restaurar `idle`, `walk` ou `run` ao final;
- emitir eventos de gameplay pelo controlador, sem colocá-los na animação.

## 15. Erros comuns

### “Animação não encontrada: masc/dance_nw”

Você criou somente `dance_se` e virou o personagem para outra direção. Crie as
quatro direções com o mesmo prefixo.

### A animação funciona no masculino e falha no feminino

Faltam as quatro cópias na biblioteca `fem`.

### O braço gira pelo meio da imagem

Você provavelmente moveu o `Sprite2D` ou alterou seu offset. Desfaça e anime o
`Bone2D` pai pela propriedade `rotation`.

### O personagem desmonta ao virar

Alguma track está animando `Bone2D.position`. Remova essa track e deixe apenas
a rotação.

### A animação dá um tranco no loop

O último quadro não combina com o primeiro. Copie as chaves do tempo `0.00` e
cole exatamente no final da animação.

### A animação para no último quadro

Isso é normal para uma animação sem loop. O `AnimationPlayer` conserva a última
pose até outra animação ser tocada. Na integração final, restaure a locomoção
ao receber `animation_finished`.

### A animação é imediatamente substituída por walk ou idle

O sinal de locomoção pediu outra animação. Ações de gameplay precisam de um
estado temporário que bloqueie a troca até a ação terminar.

### Roupa ou cabelo parecem atrasados no editor

Teste também executando a cena. Roupas acompanham os mesmos ossos, enquanto
cabelo e saia possuem atualização física própria durante a execução.

## 16. Checklist antes de considerar a animação pronta

- [ ] O nome interno é `ação_direção`, sem espaços e em minúsculas.
- [ ] A animação está na biblioteca correta, `masc` ou `fem`.
- [ ] Existem as quatro direções.
- [ ] Existem versões masculina e feminina, se ambos os corpos usarão a ação.
- [ ] Apenas propriedades intencionais possuem tracks.
- [ ] Nenhuma track move a colisão ou o `Player`.
- [ ] Nenhuma track disputa posição, textura ou `z_index` com o rig.
- [ ] A duração está correta.
- [ ] O loop está ligado somente quando necessário.
- [ ] Primeiro e último quadro combinam quando há loop.
- [ ] A prévia funciona no painel Animation.
- [ ] `play_action(&"nome")` encontra a combinação atual.
- [ ] O jogo abre sem erros ou avisos no Debugger.

## 17. Arquivos envolvidos

Ao editar visualmente pelo Godot, as mudanças serão gravadas principalmente em:

```text
res://presentation/characters/cutout/animation/animacoes_masc.tres
res://presentation/characters/cutout/animation/animacoes_fem.tres
```

O nó que usa essas bibliotecas está em:

```text
res://presentation/characters/cutout/character_visual.tscn
```

E a escolha automática de corpo, ação e direção está em:

```text
res://presentation/characters/cutout/character_visual.gd
```

Faça uma animação por vez, salve, reproduza no painel e só depois duplique para
as outras direções. Isso torna muito mais fácil descobrir qual chave causou um
movimento errado.

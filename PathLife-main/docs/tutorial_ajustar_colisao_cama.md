# Tutorial: ajustar a colisão da cama inteira

Este tutorial explica como editar visualmente as colisões das quatro camas no
Godot 4.6. Ele considera a arquitetura que já existe no PathLife.

## 1. Entenda as duas colisões da cama

A árvore atual é:

```text
Bed (StaticBody2D)
├── Visual
│   └── BedBack (Sprite2D)
├── SolidCollision (CollisionPolygon2D)
├── InteractionArea (Area2D)
│   └── InteractionShape (CollisionPolygon2D)
├── SleepCenter
├── PillowAnchor
└── ExitAnchor
```

Os dois polígonos têm funções diferentes:

| Nó | Função |
|---|---|
| `SolidCollision` | Bloqueia fisicamente o Player. É este que você deve ajustar. |
| `InteractionShape` | Detecta quando o Player está perto. Não bloqueia movimento. |

Não tente aumentar `InteractionShape` para impedir que o personagem atravesse
a cama. A área continuará sendo apenas um sensor.

## 2. Como as quatro orientações estão organizadas

As cenas ficam em:

```text
res://gameplay/furniture/bed/
├── bed_base.tscn
├── bed_r0.tscn
├── bed_r1.tscn
├── bed_r2.tscn
└── bed_r3.tscn
```

`bed_base.tscn` contém a colisão original. As outras cenas são herdadas.

No estado atual:

- `r0` usa diretamente a colisão de `bed_base`;
- `r2` também usa a colisão de `bed_base`;
- `r1` possui uma colisão sobrescrita;
- `r3` possui uma colisão sobrescrita.

Isso era suficiente enquanto a colisão representava apenas o chão. Para
contornar a cama inteira, `r0`, `r1`, `r2` e `r3` precisam terminar com
polígonos próprios, porque as cabeceiras não ocupam a mesma altura na imagem.

## 3. Qual cena abrir primeiro

Para ajustar a cama usada no mapa atual:

1. No painel **FileSystem**, abra:

```text
res://gameplay/furniture/bed/bed_base.tscn
```

2. Não comece por `bed.tscn`. Ela é somente uma entrada conveniente que
   instancia a orientação `r0`.
3. Na árvore da cena, selecione:

```text
Bed/SolidCollision
```

4. Mantenha o editor na visualização **2D**.

O sprite e o polígono devem aparecer juntos na tela.

## 4. Como editar os pontos visualmente

Ao selecionar `SolidCollision`, o Godot mostra o contorno e os pontos do
`CollisionPolygon2D`.

### Mover um ponto

1. Ative a ferramenta de edição de pontos na barra superior do editor 2D.
2. Passe o mouse sobre um ponto do polígono.
3. Arraste o ponto até a borda externa da cama.
4. Solte o botão do mouse.

Observe as coordenadas `X` e `Y` enquanto move o ponto. Como o sprite foi
posicionado com o fundo na origem da mobília, quase todos os valores `Y` da
cama são negativos.

### Adicionar um ponto

1. Na barra do editor 2D, escolha a ferramenta cujo tooltip indica adicionar
   ou inserir pontos.
2. Clique sobre um segmento do contorno.
3. Arraste o novo ponto até a parte da imagem que faltava cobrir.

Os nomes exatos dos botões podem mudar com o idioma do editor. Passe o mouse
sobre os ícones para ver os tooltips **Editar pontos**, **Inserir ponto** e
**Excluir ponto**.

### Remover um ponto

1. Selecione a ferramenta de excluir pontos.
2. Clique no ponto indesejado.
3. Confira se o polígono não ficou cruzado ou aberto.

Não use dezenas de pontos para acompanhar cada pixel. Para essa cama, de oito
a treze pontos são suficientes.

## 5. Formato recomendado para cobrir a cama inteira

Os pontos abaixo foram medidos usando os pixels opacos dos quatro PNGs. Eles
formam um contorno convexo que cobre a imagem inteira, incluindo cabeceira,
peseira, colchão e sombra.

### Orientação r0

Edite `SolidCollision` dentro de `bed_base.tscn` e use como referência:

```text
(-72, -25)
(-67, -38)
(-60, -46)
( 18,-101)
( 64, -78)
( 66, -76)
( 71, -40)
( 70, -39)
( -6,  -1)
(-26,  -1)
(-70, -23)
```

No Inspector, a propriedade completa pode ser preenchida como:

```text
PackedVector2Array(
    -72, -25,
    -67, -38,
    -60, -46,
     18, -101,
     64, -78,
     66, -76,
     71, -40,
     70, -39,
     -6, -1,
    -26, -1,
    -70, -23
)
```

Salve com `Ctrl + S`.

### Orientação r1

1. Abra `bed_r1.tscn`.
2. Selecione o `SolidCollision` herdado.
3. Edite a propriedade `Polygon` desta cena.
4. Use:

```text
(-72, -40)
(-67, -76)
(-65, -78)
(-19,-101)
(-15, -99)
( 58, -47)
( 59, -46)
( 66, -38)
( 71, -25)
( 69, -23)
( 25,  -1)
(  5,  -1)
(-71, -39)
```

Salve a cena.

### Orientação r2

`r2` ainda herda a colisão de `bed_base`. Você precisa criar uma sobrescrita
local:

1. Abra `bed_r2.tscn`.
2. Selecione `SolidCollision` na árvore.
3. Expanda `Polygon` no Inspector.
4. Altere pelo menos um ponto. Ao salvar, o Godot registra a propriedade como
   uma sobrescrita da cena herdada.
5. Ajuste o contorno usando:

```text
(-72, -25)
(-67, -58)
(-66, -59)
(-62, -61)
( 11, -82)
( 14, -82)
( 18, -81)
( 64, -58)
( 66, -56)
( 71, -40)
( 70, -39)
( -6,  -1)
(-26,  -1)
(-70, -23)
```

Salve a cena. Depois disso, alterações futuras no polígono de `bed_base` não
devem substituir o polígono específico de `r2`.

### Orientação r3

Abra `bed_r3.tscn`, selecione `SolidCollision` e use:

```text
(-72, -40)
(-67, -56)
(-65, -58)
(-19, -81)
(-15, -82)
(-12, -82)
( 61, -61)
( 65, -59)
( 66, -58)
( 71, -25)
( 69, -23)
( 25,  -1)
(  5,  -1)
(-71, -39)
```

Salve a cena.

## 6. Como colar coordenadas pelo Inspector

O método visual é o melhor para pequenos ajustes. Para substituir todos os
pontos rapidamente:

1. Selecione `SolidCollision`.
2. No Inspector, encontre `Polygon`.
3. Expanda o `PackedVector2Array`.
4. Ajuste o tamanho do array para a quantidade desejada.
5. Preencha cada `Vector2` na ordem indicada.

Não troque a ordem dos pontos aleatoriamente. Eles devem percorrer a borda da
cama em sequência. Uma ordem errada cria linhas cruzadas e uma colisão
inválida.

## 7. Como enxergar somente a colisão sólida

Durante a edição, `InteractionShape` pode atrapalhar porque seu polígono é
maior.

Para ocultá-lo temporariamente:

1. Selecione `InteractionArea/InteractionShape`.
2. No Inspector, marque `Disabled = On`.
3. Ajuste `SolidCollision`.
4. Quando terminar, volte `Disabled = Off`.

Não esqueça de reativá-lo. Ele será necessário para a futura ação de dormir.

Você também pode ocultar o nó pelo ícone de olho na árvore. Ocultar no editor
é mais seguro porque não muda o funcionamento do jogo.

## 8. Como testar no jogo

A cama de teste já está em:

```text
Main/World/Entities/TestBed
Position = (470, 180)
```

Para testar:

1. Abra `res://scenes/main/main.tscn`.
2. No menu superior, ative:

```text
Debug > Visible Collision Shapes
```

3. Execute o projeto com `F6` ou `F5`.
4. Ande contra cada lado da cama usando `W`, `A`, `S` e `D`.
5. Tente chegar à cabeceira e à peseira.
6. Confirme que o Player para na linha do polígono.

As formas de colisão aparecerão coloridas durante a execução. Isso não aparece
na versão exportada do jogo; é apenas uma ferramenta de depuração.

## 9. Se a colisão não funcionar

Confira a raiz `Bed`:

```text
Collision Layer = Furniture (camada 4)
Collision Mask  = Player (camada 2)
```

Confira o `Player`:

```text
Collision Layer = Player (camada 2)
Collision Mask  = World + Furniture
```

No projeto atual, os valores internos equivalentes são:

```text
Bed collision_layer  = 8
Bed collision_mask   = 2
Player collision_layer = 2
Player collision_mask  = 9
```

Também confira:

- `SolidCollision > Disabled` precisa estar desligado;
- o polígono precisa ter pelo menos três pontos;
- as linhas não podem se cruzar;
- o nó precisa continuar filho do `StaticBody2D`;
- não coloque a colisão como filha de `BedBack`.

## 10. Diferença entre contorno completo e colisão de chão

Uma colisão acompanhando a cama inteira bloqueia inclusive a parte alta da
cabeceira. É exatamente o comportamento solicitado, mas tem uma consequência:
o personagem não conseguirá caminhar visualmente atrás da cabeceira, mesmo
quando seus pés ainda estiverem longe da base do móvel.

Para uma perspectiva isométrica mais natural, normalmente a colisão física
cobre somente a área da cama no chão. O sprite pode continuar grande e passar
visualmente na frente ou atrás do personagem por meio do `Y Sort`.

Se a colisão completa parecer “invisível demais” durante o teste, reduza apenas
os pontos superiores, aproximando-os da base da cabeceira. Não altere a escala
do Sprite2D para tentar corrigir colisão.

A raiz `Bed` usa `Z Index = 0`, assim como o Player. Ambos são ordenados pela
posição `Y` dentro de `World/Entities`. Essa propriedade afeta somente o desenho:
ela não aumenta, reduz, desloca nem desativa a colisão.

## 11. Como desfazer uma sobrescrita herdada

Se você estragar a colisão de `r1`, `r2` ou `r3`:

1. Selecione `SolidCollision`.
2. Encontre `Polygon` no Inspector.
3. Clique no ícone de reverter propriedade ao lado do campo.

A cena voltará a usar o polígono de `bed_base`.

Use `Ctrl + Z` antes de fechar a cena se quiser desfazer apenas o último ponto
movido.

## 12. Checklist

- [ ] Você editou `SolidCollision`, não `InteractionShape`.
- [ ] A colisão cobre toda a cama na orientação atual.
- [ ] As linhas do polígono não se cruzam.
- [ ] `r0`, `r1`, `r2` e `r3` foram conferidas separadamente.
- [ ] `InteractionShape` voltou a ficar habilitada.
- [ ] A escala da cama continua em `(1, 1)`.
- [ ] As camadas `Player` e `Furniture` continuam marcadas corretamente.
- [ ] O teste foi feito com **Visible Collision Shapes** ativado.
- [ ] O Player não atravessa cabeceira, colchão, lateral ou peseira.
- [ ] O painel **Debugger** não apresenta erro.

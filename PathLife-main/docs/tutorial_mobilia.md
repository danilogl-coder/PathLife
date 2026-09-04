# Mobília: como um móvel entra no jogo

Este documento descreve a mecânica de mobília do PathLife e o passo a passo para
adicionar um móvel novo.

## 1. Como o personagem anda (o que dita a regra)

Antes de falar de móvel, o que importa do movimento:

- o mundo é uma grade isométrica de **128 × 64 px** por célula
  (`IsoCoordinateSystem`);
- o personagem anda **de célula em célula**: `WorldGridAgent.request_step()`
  avalia o passo em dois lugares — logicamente pelas `MovementRules` (altura,
  água, célula caminhável) e **fisicamente** com `test_move`, varrendo o corpo
  do Player do centro da célula atual até o centro da célula de destino;
- o corpo do Player é uma cápsula minúscula (raio 1,25 px). Ou seja: **quem
  decide se o passo acontece é o polígono de colisão do móvel**;
- paredes já funcionam assim (a colisão vem do TileSet). Mobília entra na mesma
  regra, na camada de física `8`, que a máscara do Player já lê.

A consequência prática: um polígono maior que o desenho tranca o cômodo sem
motivo visível, e um polígono menor deixa o personagem andar por dentro do
móvel. Por isso a colisão não é desenhada no olho — ela é **medida da arte**.

## 2. A mecânica

Três peças:

```text
data/furniture/furniture_definition.gd     # o móvel como DADO (.tres)
gameplay/furniture/furniture_piece.gd      # a cena-base, com o cálculo
gameplay/furniture/furniture_piece.tscn    # Visual + colisão + área de interação
```

E o que a cena-base faz sozinha, ao montar:

1. lê a textura da orientação escolhida;
2. **mede a base do sprite**: a silhueta de um objeto isométrico termina embaixo
   em duas arestas de inclinação ±1/2. Ajustando as duas retas pela mediana das
   colunas e cruzando-as, saem os quatro cantos do losango que encosta no chão —
   sem contar a parte alta do desenho, que não ocupa chão nenhum;
3. **encaixa a arte no centro do footprint** declarado;
4. gera a colisão a partir dessa base, com uma folga (`collision_inset`) para a
   célula vizinha nunca ser lida como bloqueada;
5. gera a área de interação (footprint + margem);
6. desenha no editor o footprint (verde), a base medida (laranja) e as células
   ocupadas, e avisa quando a arte transborda o footprint.

### A célula pintada é a da FRENTE

O footprint cresce **para trás** a partir da célula pintada. Isso não é gosto: a
âncora de Y-Sort do móvel é a célula pintada e o piso das células da frente é
desenhado depois. Com a arte crescendo para trás, nenhum tile de chão passa por
cima do móvel e quem está à frente aparece na frente.

### Ocupar pouco espaço é uma regra, não um acaso

O móvel bloqueia **exatamente** as células do footprint. A cama, por exemplo, é
`1 × 2`: num quarto de 3 × 3 células ela usa duas e deixa sete livres, e o
personagem passa colado nos quatro lados. O teste
`tests/furniture_piece_test.gd` falha se qualquer célula vizinha for bloqueada.

## 3. Adicionar um móvel novo

1. **Arte.** Um PNG por orientação (NE, NW, SE, SW), mesmo canvas, objeto
   apoiado no chão. Guarde em `assets/furniture/<cômodo>/<móvel>/`.
2. **Definição.** Crie `data/furniture/pieces/<móvel>.tres` com script
   `FurnitureDefinition`:
   - `orientation_textures`: as quatro texturas, nessa ordem;
   - `footprint_cells`: comece em `(1, 1)`. Se o gizmo acusar transbordo,
     aumente para `(1, 2)` / `(2, 2)`;
   - `collision_source`: `SPRITE_BASE` (padrão) mede a arte; `FOOTPRINT` usa o
     losango cheio da célula; `MANUAL` respeita o polígono desenhado à mão;
   - `blocks_movement`: desligue para tapete, luminária, quadro.
3. **Cenas de orientação.** Quatro cenas herdadas de `furniture_piece.tscn` em
   `gameplay/furniture/pieces/`, cada uma com `definition` e `orientation`
   (0 = NE, 1 = NW, 2 = SE, 3 = SW). Abra cada uma: o editor monta tudo e você
   confere o gizmo. Salve — os valores ficam assados na cena e o jogo não paga
   nada em runtime.
4. **TileSet.** Some as quatro cenas em `FURNITURE_SCENES`
   (`tools/build_structure_tileset.gd`) e rode o gerador, ou registre à mão na
   fonte `Mobilia` (source 40) do `casa_madeira_tileset.tres`.
5. **Pintar.** Na cena da casa, selecione a camada `Mobilia` e pinte a célula da
   frente do móvel. Em jogo a `StructureRoot` promove o tile para uma âncora
   própria de Y-Sort, com a compensação de fundação já resolvida.

## 4. Quando a arte não couber

Móvel muito comprido (sofá de 3 células, mesa de jantar) volta a esbarrar no
limite do Y-Sort: um objeto é ordenado por um ponto só. Para esses casos existem
dois componentes prontos em `gameplay/furniture/depth/`:

- `FurnitureTopOccluder`: o ator passa por trás da borda de cima e o móvel
  precisa cobri-lo;
- `FurnitureFrontOccluder`: o ator está à frente mas seria ordenado atrás; a
  faixa empurra a chave de Y-Sort dele meia célula
  (`WorldGridAgent.set_extra_sort_bias`).

Com o footprint bem declarado a cama não precisa de nenhum dos dois.

## 5. Próximos passos naturais

- **Interação.** A `InteractionArea` já nasce dimensionada. Falta o verbo:
  apertar `E` perto do móvel e disparar a ação (dormir, sentar, cozinhar). O
  personagem ainda tem `enter_sleep()` / `exit_sleep()` e a animação de dormir.
- **Célula lógica ocupada.** Hoje o bloqueio é físico, como o das paredes. Para
  NPCs andarem sozinhos pela casa, vale marcar `WorldCell.walkable = false` nas
  células do footprint, e o A* de `WorldNavigation` passa a desviar dos móveis.
- **Modo construir.** Com a definição sendo dado, um catálogo em jogo e uma
  prévia verde/vermelha na célula sob o cursor é o passo seguinte para o jogador
  mobiliar a própria casa.

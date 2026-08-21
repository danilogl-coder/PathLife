# Tutorial: ajustar o sombreamento dos níveis do terreno

O mundo usa cor para indicar se um patamar está acima ou abaixo do personagem.
Esse efeito não está pintado nos PNGs: ele é aplicado em tempo de execução por
meio do `modulate` dos `TileMapLayer`s.

Existem dois sistemas diferentes:

1. **Sombreamento relativo:** escurece ou muda a tonalidade de níveis diferentes
   daquele em que o personagem está.
2. **Visibilidade por altura:** deixa níveis superiores transparentes ou os
   esconde completamente.

Na configuração padrão, o primeiro está ligado e o segundo está desligado.

## Resposta rápida: onde modificar

Para mudar a intensidade e a cor do sombreamento, abra no Godot:

```text
data/world/world_settings.tres
```

No Inspector, procure o grupo:

```text
Leitura de altura
```

Os campos são:

```text
Height Shading Enabled
Height Shading Step Below
Height Shading Step Above
Height Shading Min
Height Shading Coolness
Height Shading Reference
```

Os valores padrão atuais vêm de:

```text
world_generation/core/world_settings.gd
```

```gdscript
height_shading_enabled = true
height_shading_step_below = 0.22
height_shading_step_above = 0.14
height_shading_min = 0.40
height_shading_coolness = 0.5
height_shading_reference = 0
```

## O que cada campo faz

### Height Shading Enabled

Liga ou desliga todo o sombreamento relativo.

```text
On  = níveis diferentes recebem tonalidades diferentes
Off = todos os níveis preservam as cores originais dos tiles
```

Para remover completamente o efeito sem alterar mais nada:

```text
Height Shading Enabled = Off
```

### Height Shading Step Below

Define quanto **cada nível abaixo do personagem** escurece.

Valor atual:

```text
0.22
```

Exemplo simplificado, antes do limite mínimo e da tonalidade fria:

```text
mesmo nível: 1.00
1 abaixo:    0.78
2 abaixo:    0.56
3 abaixo:    0.40  ← atingiu o mínimo atual
```

- Aumente para separar os patamares com mais força.
- Diminua para produzir uma transição mais suave.
- Use `0.0` para não escurecer níveis inferiores.

### Height Shading Step Above

Define quanto **cada nível acima do personagem** é atenuado.

Valor atual:

```text
0.14
```

Ele é separado do valor de baixo porque níveis inferiores normalmente precisam
de uma sombra mais forte, enquanto níveis superiores precisam continuar
legíveis.

- Aumente para destacar bastante as elevações.
- Diminua para deixar montanhas mais próximas da cor original.
- Use `0.0` para não alterar os níveis superiores.

### Height Shading Min

É o limite de escurecimento. Nenhum nível continuará ficando mais escuro depois
de atingir esse valor.

Valor atual:

```text
0.40
```

Exemplos:

```text
0.25 = regiões distantes podem ficar bem escuras
0.50 = contraste médio
0.75 = todos os níveis permanecem claros
1.00 = impede qualquer escurecimento
```

Evite valores muito baixos: árvores, paredes e detalhes de solo podem perder a
leitura visual.

### Height Shading Coolness

Controla quanto a sombra dos níveis inferiores puxa para azul.

Valor atual:

```text
0.5
```

```text
0.0 = sombra neutra/cinza
0.3 = sombra levemente fria
0.5 = configuração atual
1.0 = sombra azulada forte
```

Esse campo não altera a altura nem a transparência. Ele apenas modifica a
proporção de vermelho, verde e azul do sombreamento.

### Height Shading Reference

É o nível considerado neutro quando nenhum sistema informa outra referência.

Em jogo, normalmente esse número é substituído automaticamente pelo nível do
personagem. Por isso, alterar apenas esse campo pode não produzir diferença
durante a partida.

Ele é mais útil em previews, ferramentas e cenas sem personagem.

## Configurações prontas

### Sombreamento suave

```text
Height Shading Enabled    = On
Height Shading Step Below = 0.08
Height Shading Step Above = 0.05
Height Shading Min        = 0.72
Height Shading Coolness   = 0.25
```

Boa opção se o mundo estiver parecendo dividido em faixas muito escuras.

### Sombreamento médio

```text
Height Shading Enabled    = On
Height Shading Step Below = 0.14
Height Shading Step Above = 0.08
Height Shading Min        = 0.55
Height Shading Coolness   = 0.40
```

Mantém a altura legível sem alterar demais as cores da arte.

### Sombreamento forte atual

```text
Height Shading Enabled    = On
Height Shading Step Below = 0.22
Height Shading Step Above = 0.14
Height Shading Min        = 0.40
Height Shading Coolness   = 0.50
```

### Somente patamares inferiores escuros

```text
Height Shading Step Below = 0.14
Height Shading Step Above = 0.00
Height Shading Min        = 0.55
Height Shading Coolness   = 0.35
```

### Sem nenhuma mudança de cor

```text
Height Shading Enabled = Off
```

## Como editar pelo Inspector

1. Abra o projeto no Godot.
2. No painel `FileSystem`, abra `data/world/world_settings.tres`.
3. No Inspector, expanda `Leitura de altura`.
4. Comece alterando apenas `Height Shading Step Below` e
   `Height Shading Step Above`.
5. Execute o jogo e caminhe entre níveis.
6. Ajuste `Height Shading Min` se níveis distantes ficarem escuros demais.
7. Ajuste `Height Shading Coolness` por último, pois ele muda a cor da arte.
8. Salve o recurso.

Uma boa sequência de teste é começar pelo preset médio e mudar os valores em
passos pequenos de `0.02`.

## Transparência e ocultação de níveis superiores

Este é um sistema separado. Para configurá-lo, abra:

```text
scenes/world/procedural_world.tscn
```

Selecione o nó:

```text
ProceduralWorld
└── Systems
    └── HeightVisibility
```

As propriedades desse nó vêm de:

```text
world_generation/rendering/height_visibility_manager.gd
```

### Enabled

Liga o fade e a ocultação dos níveis acima.

```text
Off = todos os níveis permanecem visíveis; só o sombreamento atua
On  = níveis superiores podem ficar transparentes ou desaparecer
```

O padrão é `Off` porque ligar esse recurso no mundo aberto pode fazer partes de
montanhas desaparecerem. Ele é mais útil em interiores e áreas subterrâneas.

### Relative Height Shading

Quando ligado, usa o nível atual do personagem como referência do sombreamento.

```text
On  = o nível do personagem sempre mantém a cor original
Off = usa Height Shading Reference de WorldSettings
```

O padrão recomendado para o mundo aberto é `On`.

### Fade Above Levels

Quantidade de níveis acima do personagem que ainda aparecem transparentes antes
de desaparecer.

Com:

```text
Enabled = On
Fade Above Levels = 1
```

o comportamento é:

```text
nível do jogador: visível
1 nível acima:    transparente
2+ níveis acima:  escondido
```

### Faded Alpha

Transparência aplicada aos níveis classificados como `FADED`.

```text
0.15 = quase invisível
0.35 = padrão atual
0.60 = ainda bem visível
1.00 = opaco
```

### Underground

Quando ligado, todo nível acima do personagem é escondido imediatamente, sem a
faixa intermediária de fade.

Use somente quando a área realmente representar interior, caverna ou subsolo.

## Como os dois sistemas trabalham juntos

O `HeightVisibilityManager` escolhe visibilidade e transparência. Depois,
`ChunkView` multiplica esse resultado pela cor calculada em `WorldSettings`:

```text
cor final = sombreamento do nível × transparência/visibilidade
```

Por isso:

- desligar `HeightVisibility.Enabled` não desliga necessariamente o
  sombreamento;
- desligar `Height Shading Enabled` não desliga necessariamente o fade;
- para remover os dois efeitos, desligue ambos.

## Alteração permanente pelo código

Os valores padrão ficam em:

```text
world_generation/core/world_settings.gd
```

Por exemplo:

```gdscript
@export var height_shading_enabled: bool = true
@export_range(0.0, 0.4, 0.005) var height_shading_step_below: float = 0.14
@export_range(0.0, 0.4, 0.005) var height_shading_step_above: float = 0.08
@export_range(0.1, 1.0, 0.01) var height_shading_min: float = 0.55
@export_range(0.0, 1.0, 0.01) var height_shading_coolness: float = 0.4
```

Editar `world_settings.tres` pelo Inspector é preferível para ajustes do jogo.
Editar o script muda os padrões usados por recursos novos ou reconstruídos.

**Atenção:** `tools/build_world_resources.gd` recria
`data/world/world_settings.tres`. Se executar essa ferramenta depois de ajustar
o recurso pelo Inspector, revise o diff para confirmar que os valores não foram
substituídos pelos padrões do script.

## Não altere estas propriedades para controlar a sombra

### Height Pixels

```text
WorldSettings > Projeção isométrica > Height Pixels
```

Esse valor muda a distância vertical física/visual entre níveis e o encaixe das
faces. Ele não é intensidade de sombra. Alterá-lo só para clarear tiles quebra a
geometria do terreno.

### Modulate dos TileMapLayers

Não ajuste manualmente o `modulate` dos layers gerados. `ChunkView._apply_tint()`
recalcula esse valor quando o personagem troca de altura e sobrescreverá a
mudança.

### Peso na tabela BIOMES

Os pesos de `tools/gen_ground_atlas.py` controlam a frequência das variantes de
grama, não o sombreamento.

## Testar depois da alteração

Execute primeiro os testes do mundo:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/world_generation_test.gd
```

Depois percorra o mundo visualmente:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --resolution 800x600 --script res://tests/world_roaming_visual_test.gd
```

Confira:

- o nível do personagem permanece com a cor original;
- um nível abaixo não fica preto;
- níveis superiores continuam legíveis;
- topo e lateral do mesmo patamar recebem a mesma tonalidade;
- trocar de nível atualiza a referência sem piscar;
- nenhuma montanha desaparece quando `HeightVisibility.Enabled` está desligado.

## Erros comuns

| Sintoma | Causa provável |
|---|---|
| Tudo ficou claro | `Height Shading Enabled` foi desligado ou os dois Steps estão em `0`. |
| Tudo abaixo ficou quase preto | `Step Below` alto e `Shading Min` baixo. |
| As sombras ficaram azuis demais | `Height Shading Coolness` alto. |
| Montanhas desaparecem | `HeightVisibility.Enabled` ou `Underground` foi ligado. |
| Alterei `Height Shading Reference`, mas nada mudou | `Relative Height Shading` usa o nível do jogador no lugar dele. |
| Alterei o `modulate`, mas voltou sozinho | `ChunkView` recalcula a cor ao atualizar a altura. |
| O relevo perdeu o encaixe | `Height Pixels` foi alterado por engano. |

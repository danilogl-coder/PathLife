# Tutorial: modificar a animação dos tiles do mundo

Este tutorial trata dos tiles de terreno do mundo procedural: grama, transições
de bioma e faces dos desníveis.

## Resposta rápida

A configuração que controla a animação está em:

```text
tools/build_world_resources.gd
```

Procure por estas chamadas:

```gdscript
source.set_tile_animation_columns(coords, 3)
source.set_tile_animation_frames_count(coords, 3)
source.set_tile_animation_speed(coords, 1.4)

for frame in 3:
    source.set_tile_animation_frame_duration(coords, frame, 1.0)
```

O mesmo bloco aparece para três fontes do TileSet:

1. `source`: superfície do terreno (`Ground`);
2. `face_source`: laterais dos desníveis (`Depth`);
3. `underlay_source`: fonte completa mantida para compatibilidade.

Mantenha velocidade, quantidade de quadros e durações iguais nas três fontes.
Caso contrário, o topo e a lateral do mesmo tile podem mudar de quadro em
momentos diferentes.

## O que cada número significa

### Quantidade de quadros

```gdscript
set_tile_animation_frames_count(coords, 3)
```

O projeto foi construído para três imagens:

```text
frame_1.png
frame_2.png
frame_3.png
```

### Velocidade global da animação

```gdscript
set_tile_animation_speed(coords, 1.4)
```

- Um número maior deixa a animação mais rápida.
- Um número menor deixa a animação mais lenta.
- `1.0` usa as durações sem multiplicador.

Exemplos:

```gdscript
# Mais lenta
source.set_tile_animation_speed(coords, 0.7)

# Velocidade normal
source.set_tile_animation_speed(coords, 1.0)

# Mais rápida
source.set_tile_animation_speed(coords, 2.0)
```

Com três quadros de duração `1.0` e velocidade `1.4`, o ciclo completo dura
aproximadamente:

```text
(1.0 + 1.0 + 1.0) / 1.4 = 2,14 segundos
```

### Duração individual de cada quadro

```gdscript
set_tile_animation_frame_duration(coords, frame, 1.0)
```

O último argumento é o peso de duração daquele quadro. Para deixar o primeiro
quadro mais tempo parado:

```gdscript
source.set_tile_animation_frame_duration(coords, 0, 2.0)
source.set_tile_animation_frame_duration(coords, 1, 1.0)
source.set_tile_animation_frame_duration(coords, 2, 1.0)
```

Não confunda essa duração com segundos absolutos: o valor final ainda é
dividido por `animation_speed`.

## Onde trocar os desenhos dos quadros

As pastas de origem estão declaradas na tabela `BIOMES`, perto do começo de:

```text
tools/gen_ground_atlas.py
```

Exemplo:

```python
('campo_alto', SRC_ALT + 'Tile Bioma Campo Verde/Campo/frames/', 0.90)
```

Dentro da pasta indicada devem existir:

```text
frame_1.png
frame_2.png
frame_3.png
```

Cada imagem deve continuar com `128 × 106` pixels e fundo transparente. Não
altere o tamanho ou a posição do losango entre os quadros; caso contrário, o
tile vai parecer pular e as faces dos desníveis podem perder o encaixe.

O terceiro valor da linha (`0.90` no exemplo) **não é velocidade**. Ele é o peso
da variante no sorteio procedural: quanto aquele tipo de grama aparece no mapa.

## Fluxo recomendado para trocar a arte

1. Faça uma cópia dos três quadros originais.
2. Edite `frame_1.png`, `frame_2.png` e `frame_3.png`.
3. Preserve tamanho, transparência e alinhamento.
4. Na raiz `PathLife-main`, gere novamente atlas e manifesto:

```powershell
python tools/gen_ground_atlas.py
```

5. Reimporte as imagens no Godot:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
```

Se você alterou apenas os PNGs, não precisa reconstruir todos os recursos do
mundo. O `gen_ground_atlas.py` atualiza estes arquivos:

```text
assets/world/tiles/ground_atlas.png
assets/world/tiles/ground_top_atlas.png
assets/world/tiles/depth_face_atlas.png
assets/world/tiles/ground_atlas.json
```

## Fluxo recomendado para trocar velocidade ou duração

Para uma mudança permanente, altere as configurações nas três fontes de
`tools/build_world_resources.gd`. Depois execute:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/build_world_resources.gd
```

**Atenção:** essa ferramenta recria os recursos do mundo em `data/world/`.
Revise o diff depois de executá-la caso tenha configurações ajustadas à mão no
Inspector.

Em seguida, faça a importação:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --import
```

## Alteração rápida pelo Inspector

Também é possível editar o recurso gerado diretamente:

```text
data/world/tiles/ground_tileset.tres
```

No Godot:

1. Abra `ground_tileset.tres` no FileSystem.
2. Abra a fonte `GroundSurfaceAtlas` no editor de TileSet.
3. Selecione o tile desejado.
4. Abra a seção de animação.
5. Ajuste `Speed`, duração dos quadros ou reprodução.
6. Repita o mesmo ajuste na variante correspondente de `DepthFaceAtlas`.
7. Salve o recurso.

Essa edição é boa para experimentar, mas será sobrescrita quando
`build_world_resources.gd` for executado novamente. Quando gostar do resultado,
copie os números para o script gerador.

## Como deixar os tiles mais naturais

Para vento suave em grama, comece com:

```text
Speed: 0.8 a 1.2
Frame 1: 1.4
Frame 2: 0.8
Frame 3: 1.0
```

Para vento mais forte:

```text
Speed: 1.6 a 2.2
Duração de todos os quadros: 1.0
```

Evite diferenças muito grandes entre os quadros. Em um mapa com muitos tiles,
um deslocamento brusco de vários pixels vira uma tremulação na tela inteira.

## Testar depois da alteração

Execute os testes de recursos e a caminhada visual:

```powershell
& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/world_generation_test.gd

& 'C:\Users\danil\Desktop\Godot\4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --resolution 800x600 --script res://tests/world_roaming_visual_test.gd
```

O primeiro confere atlas, frames e TileSet. O segundo percorre o mundo e salva:

```text
C:\Users\danil\AppData\Roaming\Godot\app_userdata\PathLife\world_roaming_contact_sheet.png
```

Inspecione principalmente:

- se topo e lateral mudam de quadro juntos;
- se o losango não pula verticalmente;
- se não aparece linha transparente nas bordas;
- se a animação não fica rápida demais quando ocupa a tela inteira.

## Erros comuns

| Sintoma | Causa provável |
|---|---|
| Alterei `0.90` na tabela `BIOMES` e nada ficou mais rápido | Esse número é peso de aparecimento, não velocidade. |
| Mudei o `.tres`, mas minha alteração sumiu | `build_world_resources.gd` recriou o recurso. |
| O topo anima, mas a parede fica parada ou dessincronizada | As três fontes não receberam a mesma configuração. |
| O tile pula | Os três PNGs não possuem o mesmo alinhamento. |
| O terceiro quadro mostra outro tile | O atlas foi regenerado, mas o Godot ainda não reimportou os PNGs. |
| A animação fica parecendo uma TV piscando | Os quadros diferem demais ou a velocidade está alta para um padrão repetido no mapa inteiro. |

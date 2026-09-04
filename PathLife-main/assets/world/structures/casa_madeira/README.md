# Kit TileMap da casa de madeira

Este pacote foi organizado para desenhar estruturas diretamente com
`TileMapLayer` no Godot 4.6.

## Comece por aqui

Abra esta cena no editor:

```text
res://presentation/world/structures/casa_madeira_tilemap.tscn
```

Ela contém o desenho 7×8 que está sendo editado e três camadas:

- `Piso`: pinte o chão; colisão desligada.
- `Paredes`: pinte paredes sólidas; colisão automática ligada.
- `ParedesSemColisao`: fantasmas, prévias e peças que não bloqueiam.

As três camadas compartilham:

```text
res://data/world/structures/casa_madeira_tileset.tres
```

Selecione uma camada e use o painel **TileMap** na parte inferior do editor. O
TileSet é isométrico (`128×64`), usa filtro `Nearest` e já possui as origens de
textura corretas.

## Geração procedural

A cena de trabalho atual usa uma área pintada 7×8 e já está registrada no mapa:

```text
res://data/world/structures/casa_madeira.tres
res://data/world/biomes/campo.tres
```

Ela está temporariamente em modo de teste (`spawn_chance = 1.0`,
`spawn_weight = 16.0`, `minimum_spacing = 8`) para ser encontrada com
facilidade. Depois do teste, reduza a chance/peso e aumente o espaçamento.

O registro também existe em `tools/build_world_resources.gd`, portanto o
recriador mantém a casa e sua entrada na pool de `campo`.

## Pastas de produção

- `pisos/<ambiente>/`: pisos de `banheiro`, `cozinha`, `lazer` e `sala`.
- `paredes/<ambiente>/`: paredes dos mesmos quatro ambientes.

## Pisos

- `*_bloco.png` (`128x76`): piso com espessura lateral visível.
- `*_topo.png` (`128x64`): somente a superfície plana.

## Paredes

Cada ambiente possui 27 peças de `128x158`, incluindo paredes nas direções
isométricas, cantos, quinas e os estados `baixa`, `cheia` e `fantasma`.

Os aliases `parede_ne.png` e `parede_nw.png` foram preservados. Eles são cópias
visuais das respectivas peças `ne_cheia` e `nw_cheia`.

No TileSet, os aliases duplicados foram omitidos da paleta. O gerador combina
as faces `NE` e `NW` para completar o canto baixo e fantasma; assim, cada
ambiente possui uma fonte nomeada com 27 peças únicas:

```text
Paredes_Banheiro
Paredes_Cozinha
Paredes_Lazer
Paredes_Sala
```

Em cada fonte, as colunas são `NE`, `NW`, `SE`, `SW`, `quina N`, `quina E`,
`quina S`, `quina W` e `canto`. As linhas são `baixa`, `cheia` e `fantasma`;
todas as colunas possuem os três estados.

## Visualização durante o jogo

O botão `Paredes` no HUD (ou a tecla `V`) alterna globalmente entre paredes
inteiras, transparentes e cortadas. Toda cena baseada em `StructureRoot` se
registra automaticamente, inclusive estruturas criadas proceduralmente depois
da troca. A colisão permanece ativa nos três modos.

Os PNGs `fantasma` originais são preservados como arte-fonte, mas o atlas de
runtime gera essa linha a partir da parede cheia com alpha uniforme de 50%.
Isso mantém a mesma cobertura visual sem o xadrez de 1 pixel que cintila quando
a câmera se move. As fontes de parede usam `use_texture_padding = false` para
contornar o problema conhecido de transparência em `TileMapLayer`.

Todas as peças disponíveis em `Paredes` já carregam polígonos de colisão na
camada física `World`. Pintar ou apagar uma parede também adiciona ou remove a
colisão correspondente.

## Configuração recomendada no Godot

- Filtro de textura: `Nearest`.
- Compressão: sem perda (`Lossless`).
- Mipmaps: desativados.
- Não recorte as margens transparentes: elas mantêm o alinhamento entre as peças.

Essas configurações já estão aplicadas aos atlas e à cena-base.

## Regeneração do kit

O gerador reproduz os atlas e o TileSet a partir dos PNGs originais:

```text
res://tools/build_structure_tileset.gd
```

O modo normal de recursos preserva `casa_madeira_tilemap.tscn`, para não apagar
o que você pintou. A cena só é recriada quando o modo explícito
`--resources-force-scene` é usado.

## Referências

A pasta `_referencias/` contém pranchas, ampliações e exemplos de montagem. Ela
possui um arquivo `.gdignore`, então essas imagens não são importadas pelo Godot.

O arquivo antigo `assets/world/structures/piso_madeira.png` não foi alterado. Ele
é idêntico ao novo `pisos/sala/sala_bloco.png` e pode continuar sendo usado pelas
cenas existentes.

As pastas de origem não incluíam licença ou informação de autoria. Antes de
redistribuir os tiles fora deste projeto, confirme os direitos de uso do pacote.

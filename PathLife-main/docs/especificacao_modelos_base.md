# Personagens em camadas — Padrão v2 (extraído da referência)

> v2 substitui o padrão chibi anterior (arquivado em `PathLife/archive/chibi_v1/`).
> O novo padrão foi extraído por engenharia reversa da folha de referência de
> 8 direções fornecida pelo diretor de arte do projeto.

## Padrão técnico

| Item | Valor |
|---|---|
| Canvas por frame | **48 × 80 px** |
| Personagem adulto | ~70 px de altura (~4 cabeças, semi-realista) |
| Pivô | centro-base: **(24, 80)** |
| Contato com o chão | pés em **y = 77** (verificado nos 8 frames) |
| Sheet | **384 × 80** — 8 frames na ordem **S, SE, E, NE, N, NW, W, SW** |
| Direções | **8** (cada uma desenhada, sem espelhamento automático) |
| Cabeça (banda) | 18 px do topo do cabelo ao queixo |

### Consequência importante de escala

Personagem de 70 px pede grade maior que a recomendada na fase chibi:

| Item | Valor novo |
|---|---|
| Tile lógico | **64 × 32 px** |
| Altura de andar | **96 px** (parede 64 × 128) |
| Viewport base | **640 × 360**, stretch `canvas_items`, aspect `expand`, escala inteira |

Custo honesto: móveis, pisos e paredes nessa escala têm ~2× mais pixels que no
padrão 32 × 16. É o preço da fidelidade da referência — orçar tempo de arte de
acordo.

## Paleta-chave (rampa verde) — inalterada

| Papel | RGB | Hex |
|---|---|---|
| Luz | 140, 230, 110 | `#8CE66E` |
| Base | 90, 190, 70 | `#5ABE46` |
| Sombra | 55, 140, 55 | `#378C37` |
| Escuro/contorno | 30, 85, 40 | `#1E5528` |

O shader `res://shaders/skin_palette_swap.gdshader` continua o mesmo: troca os
4 verdes por qualquer rampa. **Corpo e cabelo** usam verde-chave; roupas da v1
usam cores fixas (recolorização de roupas = pintar a peça com os 4 verdes).

## Arquivos e slots

```text
res://assets/characters/
├── base/body_male_adult.png        manequim verde: careca, sem rosto, anatomia da referência
├── hair/hair_m_adult_01.png        verde-chave (recolorível). Pupila e sobrancelha ficam AQUI
│                                   e recolorem junto com o cabelo (estilização proposital)
├── eyes/eyes_m_adult_01.png        branco + íris (cores fixas). Vazio na direção N (de costas)
└── outfits/
    ├── top_m_adult_01.png          regata (cores fixas)
    ├── bottom_m_adult_01.png       calça jeans (cores fixas)
    └── shoes_m_adult_01.png        tênis, inclui solado escuro (cores fixas)
```

Convenção: `<slot>_<m|f|u>_<idade>_<id>.png`, sempre 384 × 80, mesma ordem de
direções, mesmo pivô. Compor as camadas = personagem completo (validado: a
recomposição reproduz a referência pixel a pixel, exceto o rosto que agora é
modular).

## Ordem de desenho (Sprite2D filhos, de trás para frente)

```text
0 sombra no chão
1 corpo (shader pele)
2 roupa inferior
3 tênis
4 roupa superior
5 olhos
6 cabelo (shader cabelo)
7 chapéu/acessório
8 efeitos
```

Nota: nesta referência o cabelo cobre a testa, então olhos ficam ABAIXO do
cabelo na ordem. Chapéus cobrem o cabelo.

## Configuração na Godot 4.6

1. Project Settings → Rendering → Textures → Default Texture Filter = **Nearest**.
2. Cena `character_visual.tscn`: `Node2D` raiz + um `Sprite2D` por camada.
3. Cada `Sprite2D`: `Hframes = 8`, `Frame` = índice da direção
   (0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW), `Centered` ligado,
   `Offset = (0, -40)` → origem do nó no pé (pivô 24,80) para o Y-sort.
4. ShaderMaterial no corpo (rampa de pele) e no cabelo (rampa de cabelo).
   Em tempo de execução: `sprite.material = sprite.material.duplicate()` por
   instância, senão todos os NPCs mudam de cor juntos.

## Pipeline "devorador de referência"

`PathLife/tools/devour_reference.py` transforma uma folha de 8 PNGs nomeados
(south.png, south-east.png, ...) em: manequim verde + camadas separadas e
alinhadas. Para cada novo conjunto de referência (feminino, criança, idoso,
novas roupas/cabelos), basta colocar os 8 PNGs e rodar o script — ele
normaliza pivô, classifica materiais por paleta e emite os sheets no padrão.

Limitações conhecidas (retocar no Aseprite se incomodar):
- O crânio do manequim usa a silhueta do cabelo → cabeça ligeiramente maior
  que o crânio real. Invisível com qualquer cabelo equipado.
- A classificação depende da paleta exata da referência; referência nova com
  cores diferentes exige atualizar as tabelas SKIN/SHIRT/PANTS no script.

## Próximos passos (nesta ordem)

1. Referências feminina, criança e idosa NESTE mesmo estilo (8 direções cada)
   → passar pelo pipeline. Sem referência, os corpos teriam que ser desenhados
   à mão no padrão.
2. Animação de caminhada (4–6 frames × 8 direções) — o custo dobra com 8
   direções; reservar tempo.
3. Mais cabelos/roupas como camadas independentes.

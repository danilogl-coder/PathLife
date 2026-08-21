"""Monta os atlas de chão do mundo procedural.

Regras:
  * os 6 tiles de grama são EXATAMENTE os fornecidos, com os 3 frames de
    animação preservados;
  * para cada grama é derivado um bloco de TERRA correspondente, usado nas
    paredes/colunas abaixo da grama. A lateral é copiada pixel a pixel do tile
    original (então casa perfeitamente) e a face de cima é reconstruída a partir
    da paleta de terra daquele mesmo tile;
  * os blocos de terra são ESTÁTICOS (1 frame). Só a arte fornecida anima;
  * entre duas variantes VIZINHAS de um bioma são geradas variantes
    INTERMEDIÁRIAS, para o campo não pular de um tom para outro. Elas não
    inventam pixel nenhum: cada pixel vem de uma das duas artes originais,
    escolhido por dithering ordenado (tapete) ou por faixa (mato alto);
  * a saída gera uma cópia TOP para Ground e uma FACE para Depth. O atlas
    original completo permanece no TileSet apenas para compatibilidade com
    recursos antigos; o renderer atual não precisa de underlay por chunk;
  * um manifesto JSON acompanha os atlas, para o `build_world_resources.gd`
    montar TileSet e biomas sem nenhuma lista repetida na mão.
"""
from PIL import Image
import numpy as np
import itertools
import json
import math
import random
import zlib

# Ajuste para a pasta onde estão os tiles originais.
import os
SRC = os.environ.get('PATHLIFE_TILES_SRC', '../../Isometric Tiles/Tiles Biomes/')
SRC_ALT = SRC
W, H = 128, 106
DIAMOND_TOP = 16                        # y do topo do losango da face superior
DIAMOND_H = 64
CY = DIAMOND_TOP + DIAMOND_H / 2.0      # 48.0
SKIRT = 26                              # altura da lateral (= height_pixels)

# --- suavização de contraste entre variantes -------------------------------
# Distância perceptual "alvo" entre duas variantes vizinhas na escala do bioma.
# Quanto menor, mais degraus intermediários (transição mais macia).
BLEND_TARGET_DISTANCE = 4.5
# Teto de intermediárias por par, para o atlas não explodir.
BLEND_MAX_PER_PAIR = 4
# A transição é uma PONTE, não uma variante nova: ela precisa aparecer o
# suficiente para o olho não ver o degrau, e pouco o suficiente para o bioma
# continuar tendo a cara das artes originais. Fração do menor peso do par.
WEIGHT_BLEND_FACTOR = 0.30

# Cada bioma tem VÁRIAS variantes de grama na pasta original — é o que dá vida
# ao terreno. Todas entram no atlas; o mundo sorteia entre elas em manchas.
# O último item de cada bioma é o usado para derivar o bloco de terra.
# Cada bioma tem VÁRIAS variantes de grama na pasta original — é o que dá vida
# ao terreno. Todas entram no atlas; o mundo sorteia entre elas em manchas.
# O último item de cada bioma é o usado para derivar o bloco de terra.
#
# O terceiro campo é o PESO no sorteio. É design, não medida: define quanto de
# cada cara o bioma tem. As variantes de solo exposto (`ralo`, `quase_ralo`)
# ficam baixas de propósito — a falha de terra que o artista desenhou no topo se
# repete a cada tile, então em mancha grande ela vira quadriculado.
BIOMES = [
    ('campo', [
        ('campo_alto',       SRC_ALT + 'Tile Bioma Campo Verde/Campo/frames/', 0.90),
        ('campo_mato_denso', SRC_ALT + 'Tile Bioma Campo Verde/Campo Mato Denso/frames/', 0.60),
        ('campo_quase_ralo', SRC_ALT + 'Tile Bioma Campo Verde/Campo quase ralo/', 0.40),
        ('campo_ralo',       SRC_ALT + 'Tile Bioma Campo Verde/Campo Ralo/frames/', 0.25),
        ('campo_baixo',      SRC + 'Tile Bioma Campo Verde/r01_campo_baixo/frames/', 2.00),
    ]),
    ('campo_claro', [
        ('claro_denso', SRC + 'Tile Bioma Campo Verde Claro/r02_denso_baixo/frames/', 0.80),
        ('claro',       SRC + 'Tile Bioma Campo Verde Claro/r03_clara/frames/', 1.50),
    ]),
    ('campo_florido', [
        ('florida',          SRC_ALT + 'Tile Bioma Campo Florida/florida/', 0.60),
        ('florida_rasteira', SRC_ALT + 'Tile Bioma Campo Florida/florida_rasteira/', 0.70),
        ('florida_baixa',    SRC + 'Tile Bioma Campo Florida/r06_florida_baixa/frames/', 1.50),
    ]),
    ('floresta', [
        ('floresta',           SRC_ALT + 'Tile Bioma Floresta/floresta/frames/', 0.70),
        ('floresta_rasteira',  SRC_ALT + 'Tile Bioma Floresta/floresta_rasteira/', 0.70),
        ('musgo',              SRC + 'Tile Bioma Floresta/r05_musgo/frames/', 1.50),
    ]),
    ('savana', [
        ('savana',           SRC_ALT + 'Tile Bioma Savana/Savana/frames/', 0.70),
        ('savana_rasteira',  SRC_ALT + 'Tile Bioma Savana/Savana rasteira/', 0.70),
        ('savana_baixa',     SRC + 'Tile Bioma Savana/r04_savana_baixa/frames/', 1.50),
    ]),
]


def load_frames(folder):
    return [Image.open(folder + 'frame_%d.png' % i).convert('RGBA') for i in (1, 2, 3)]


def diamond_edges(x):
    """(y_topo, y_base) da face superior na coluna x."""
    t = abs(x + 0.5 - 64.0) / 64.0
    half = (DIAMOND_H / 2.0) * (1.0 - t)
    return CY - half, CY + half


# ------------------------------------------------------------------ ruído
def _vnoise(gx, gy, seed):
    h = (int(gx) * 374761393 + int(gy) * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def smooth_noise(fx, fy, cell, seed):
    gx, gy = fx / cell, fy / cell
    x0, y0 = math.floor(gx), math.floor(gy)
    tx, ty = gx - x0, gy - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    v00 = _vnoise(x0, y0, seed);     v10 = _vnoise(x0 + 1, y0, seed)
    v01 = _vnoise(x0, y0 + 1, seed); v11 = _vnoise(x0 + 1, y0 + 1, seed)
    return (v00 * (1 - tx) + v10 * tx) * (1 - ty) + (v01 * (1 - tx) + v11 * tx) * ty


def ramp(colors, t):
    n = len(colors) - 1
    p = max(0.0, min(0.999999, t)) * n
    i = int(p)
    f = p - i
    a, b = colors[i], colors[i + 1]
    return tuple(int(round(a[c] + (b[c] - a[c]) * f)) for c in range(3))


# ---------------------------------------------------- paleta de terra do tile
def skirt_palette(image, steps=5):
    """Paleta de terra extraída da LATERAL do próprio tile.

    São literalmente as cores que o artista usou. Nada de média nem gradiente:
    o bloco de terra é pintado só com elas.
    """
    px = np.array(image)
    samples = []
    for x in range(W):
        _, yb = diamond_edges(x)
        for y in range(int(math.ceil(yb)) + 3, int(yb) + SKIRT - 1):
            if 0 <= y < H and px[y, x, 3] > 200 and not _is_foliage(px[y, x]):
                samples.append(px[y, x, :3].astype(float))
    samples = np.array(samples)
    luma = samples @ np.array([0.299, 0.587, 0.114])
    samples = samples[np.argsort(luma)]
    stops = np.linspace(0.10, 0.97, steps)
    palette = []
    for stop in stops:
        color = samples[int(stop * (len(samples) - 1))]
        palette.append(tuple(int(round(v)) for v in color))
    return palette


def skirt_colors(image, limit=16):
    """Cores DE FATO usadas na lateral do tile, da mais comum para a mais rara.

    Serve para travar qualquer pixel novo em um tom que já existe na arte —
    nada de cor inventada e nada de meio-tom borrado.
    """
    px = np.array(image)
    counts = {}
    for x in range(W):
        _, yb = diamond_edges(x)
        for y in range(int(math.ceil(yb)), H):
            if px[y, x, 3] < 200:
                continue
            if _is_foliage(px[y, x]):
                continue
            key = (int(px[y, x, 0]), int(px[y, x, 1]), int(px[y, x, 2]))
            counts[key] = counts.get(key, 0) + 1
    ordered = sorted(counts.items(), key=lambda kv: -kv[1])
    return [color for color, _count in ordered[:limit]]


def snap(color, palette):
    """Cor mais próxima dentro da paleta da arte original."""
    best = palette[0]
    best_distance = None
    for candidate in palette:
        dr = color[0] - candidate[0]
        dg = color[1] - candidate[1]
        db = color[2] - candidate[2]
        distance = dr * dr + dg * dg + db * db
        if best_distance is None or distance < best_distance:
            best_distance = distance
            best = candidate
    return best


def brighten(color, gain, lift):
    return tuple(min(255, max(0, int(round(c * gain + lift)))) for c in color)


# Dithering ordenado 4x4 (Bayer). É o que dá a "textura de pixel art" em vez de
# um degradê liso de imagem redimensionada.
BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def quantize(palette, t, x, y):
    """Escolhe uma cor DA PALETA, com dithering ordenado entre vizinhas."""
    t = max(0.0, min(1.0, t))
    f = t * (len(palette) - 1)
    index = int(math.floor(f))
    frac = f - index
    if frac > (BAYER4[y & 3][x & 3] + 0.5) / 16.0:
        index += 1
    return palette[max(0, min(len(palette) - 1, index))]


def _is_foliage(pixel):
    """Verdadeiro para pixels de vegetação.

    Usa MATIZ, não só "é verde": a grama da savana puxa para o ocre e a sombra
    sob a grama puxa para o verde-azulado. Terra e pedra ficam de fora porque a
    terra tem matiz alaranjada (< 45°) e a pedra é dessaturada.
    """
    r, g, b = float(pixel[0]), float(pixel[1]), float(pixel[2])
    mx, mn = max(r, g, b), min(r, g, b)
    if mx <= 0.0:
        return False
    delta = mx - mn
    if delta / mx < 0.18:
        return False
    if mx == r:
        hue = 60.0 * (((g - b) / delta) % 6.0)
    elif mx == g:
        hue = 60.0 * (((b - r) / delta) + 2.0)
    else:
        hue = 60.0 * (((r - g) / delta) + 4.0)
    return 45.0 <= hue <= 200.0


def make_dirt_block(name, source_frame):
    """Bloco de terra que combina com o tile de grama informado.

    A lateral é copiada pixel a pixel do original — é isso que faz a coluna de
    terra encaixar embaixo da grama sem a grama parecer flutuando.
    """
    src = np.array(source_frame)
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = out.load()
    palette = skirt_palette(source_frame)
    # A face de cima recebe mais luz que a lateral, mas continua usando as
    # mesmas cores da arte, só deslocadas — nada de tons inventados.
    top_palette = [brighten(c, 1.30, 12) for c in palette]
    # `hash(str)` do Python recebe um salt aleatório por processo. Usá-lo aqui
    # fazia o atlas mudar a cada execução da ferramenta mesmo sem alterar
    # entrada alguma. CRC32 é estável em todas as máquinas/processos.
    stable_seed = zlib.crc32(name.encode('utf-8')) & 0xFFFFFFFF
    rnd = random.Random(stable_seed)
    seed = stable_seed & 0xFFFF

    # --- face superior: ruído em blocos + dithering ordenado
    for x in range(W):
        yt, yb = diamond_edges(x)
        for y in range(int(math.floor(yt)), int(math.ceil(yb))):
            if y < 0 or y >= H:
                continue
            u = (x + 0.5 - 64.0) / 64.0
            v = (y + 0.5 - CY) / 32.0
            # Coordenadas "de superfície": desfaz a projeção para a textura não
            # sair esticada na diagonal.
            sx = u * 64.0 + v * 64.0
            sy = v * 64.0 - u * 64.0
            # Grão fino domina, para a face de cima ter a mesma densidade de
            # pixel da lateral do artista (e não manchas grandes e lisas).
            n = (0.26 * smooth_noise(sx, sy, 11.0, seed)
                 + 0.30 * smooth_noise(sx, sy, 4.0, seed + 31)
                 + 0.28 * smooth_noise(sx, sy, 1.8, seed + 77)
                 + 0.16 * smooth_noise(sx, sy, 1.0, seed + 131))
            t = 0.12 + 0.76 * n
            t += 0.10 * (-v) - 0.04 * u          # luz vinda do topo-esquerdo
            c = quantize(top_palette, t, x, y)
            px[x, y] = (c[0], c[1], c[2], 255)

    # --- pedrinhas, no mesmo espírito das que existem na lateral da arte
    pebble_dark = palette[1]
    pebble_light = brighten(palette[-1], 1.05, 10)
    for _ in range(rnd.randint(5, 8)):
        sxp = rnd.uniform(-0.62, 0.62)
        syp = rnd.uniform(-0.62, 0.62)
        cx = int(64 + (sxp - syp) * 44.0)
        cy = int(CY + (sxp + syp) * 22.0)
        shape = rnd.choice([
            [(0, 0), (1, 0)],
            [(0, 0), (1, 0), (0, 1)],
            [(0, 0)],
        ])
        for dx, dy in shape:
            gx, gy = cx + dx, cy + dy
            if not (0 <= gx < W):
                continue
            top_y, bottom_y = diamond_edges(gx)
            if top_y <= gy < bottom_y:
                px[gx, gy] = (pebble_dark[0], pebble_dark[1], pebble_dark[2], 255)
        top_y, bottom_y = diamond_edges(cx) if 0 <= cx < W else (0.0, -1.0)
        if 0 <= cx < W and top_y <= cy - 1 < bottom_y:
            px[cx, cy - 1] = (pebble_light[0], pebble_light[1], pebble_light[2], 255)

    max_fringe = 14
    art_colors = skirt_colors(source_frame)
    for x in range(W):
        _, yb = diamond_edges(x)
        start = int(math.ceil(yb))
        bottom = H - 1
        while bottom > start and src[bottom, x, 3] == 0:
            bottom -= 1

        # Até onde a grama do tile original invade a lateral.
        fringe_end = start - 1
        for y in range(start, min(start + max_fringe, H)):
            if src[y, x, 3] == 0:
                continue
            if _is_foliage(src[y, x]):
                fringe_end = y
        # As duas primeiras linhas entram sempre: na arte original são a sombra
        # sob a grama e, num bloco de terra puro, virariam um risco solto.
        fringe_end = max(fringe_end, start + 1)

        for y in range(start, H):
            if src[y, x, 3] == 0:
                continue
            if y > fringe_end:
                # Terra original: cópia pixel a pixel.
                px[x, y] = tuple(int(v) for v in src[y, x])
                continue

            # Faixa que era grama: em vez de esticar um pixel (o que vira
            # borrão), a textura de terra logo abaixo é ESPELHADA para cima.
            # Assim o granulado e o dithering do artista continuam, e a cor é
            # travada na paleta da própria arte.
            depth = fringe_end - y + 1
            mirror_y = fringe_end + depth
            span = bottom - fringe_end
            if span > 0:
                # Vai e volta, para não repetir um padrão óbvio nem estourar.
                offset = (depth - 1) % (2 * span)
                if offset >= span:
                    offset = 2 * span - offset - 1
                mirror_y = fringe_end + 1 + offset
            mirror_y = max(start, min(bottom, mirror_y))
            sample = src[mirror_y, x]
            if _is_foliage(sample) or sample[3] == 0:
                sample = src[min(bottom, fringe_end + 1), x]
            # O topo da lateral pega mais luz que o pé: um leve degrau de
            # brilho devolve o volume do bloco.
            gain = 1.0 + 0.030 * float(depth)
            lit = tuple(min(255, int(round(float(sample[c]) * gain))) for c in range(3))
            c = snap(lit, art_colors)
            px[x, y] = (c[0], c[1], c[2], 255)

    # --- contorno do topo com a cor mais escura DA PALETA (sem multiplicação,
    #     senão aparece um tom que não existe na arte)
    edge = brighten(palette[0], 1.05, 0)
    for x in range(W):
        yt, yb = diamond_edges(x)
        for y in (int(math.floor(yt)), int(math.ceil(yb)) - 1):
            if 0 <= y < H and px[x, y][3]:
                px[x, y] = (edge[0], edge[1], edge[2], 255)
    return out


# ------------------------------------------- variantes intermediárias
# O bioma vira uma ESCALA: as variantes são encadeadas da mais escura/densa
# para a mais clara/rala, e entre cada par vizinho entram tiles de transição.
# Nenhum pixel novo é inventado — cada pixel vem de uma das duas artes.

BAYER8 = np.array([
    [0, 32, 8, 40, 2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
], dtype=float) / 64.0


def _srgb_to_lab(rgb):
    def linear(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = [linear(v) for v in rgb]
    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505
    def pivot(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
    fx, fy, fz = pivot(x / 0.95047), pivot(y), pivot(z / 1.08883)
    return np.array([116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)])


def blade_pixels(frame):
    """Pixels de lâmina acima do losango.

    Mede o quanto o tile é feito de LÂMINAS verticais (que não podem ser
    serrilhadas) em vez de um tapete de textura (que aceita dithering fino).
    """
    px = np.array(frame)
    total = 0
    for x in range(W):
        yt, _yb = diamond_edges(x)
        total += int((px[:int(math.floor(yt)), x, 3] > 0).sum())
    return total


def describe(frame):
    """Cor média da face de cima, cobertura de folha e quantidade de lâmina."""
    px = np.array(frame).astype(float)
    samples = []
    foliage = 0
    total = 0
    for x in range(W):
        yt, yb = diamond_edges(x)
        for y in range(int(math.floor(yt)), int(math.ceil(yb))):
            if 0 <= y < H and px[y, x, 3] > 200:
                samples.append(px[y, x, :3])
                total += 1
                if _is_foliage(px[y, x]):
                    foliage += 1
    mean = np.array(samples).mean(axis=0)
    return {
        'lab': _srgb_to_lab(mean),
        'foliage': 100.0 * foliage / max(1, total),
        'blades': blade_pixels(frame),
    }


def perceptual_distance(a, b):
    """Distância "de olho": cor + quanto de terra aparece + altura do mato."""
    color = float(np.linalg.norm(a['lab'] - b['lab']))
    return color + 0.30 * abs(a['foliage'] - b['foliage']) + 0.010 * abs(a['blades'] - b['blades'])


def order_chain(ids, described):
    """Encadeia as variantes do bioma minimizando o salto entre vizinhas.

    São no máximo 5 variantes por bioma, então dá para testar todas as ordens e
    escolher a melhor em vez de chutar. A cadeia sai do tile mais ESCURO para o
    mais CLARO: assim o ruído que sorteia a variante caminha pela escala em vez
    de pular de um extremo ao outro.
    """
    best_order = None
    best_total = None
    for order in itertools.permutations(ids):
        total = sum(
            perceptual_distance(described[order[i]], described[order[i + 1]])
            for i in range(len(order) - 1)
        )
        if best_total is None or total < best_total:
            best_total = total
            best_order = order
    if described[best_order[0]]['lab'][0] > described[best_order[-1]]['lab'][0]:
        best_order = tuple(reversed(best_order))
    return list(best_order)


def build_selector(seed, structure):
    """Mapa 0..1 por pixel; comparado com `t`, decide de qual tile o pixel vem.

    A mistura muda de regime conforme a arte, porque duas coisas diferentes
    pedem tratamentos diferentes:

      * TAPETE (grama baixa, musgo): mistura FINA, em grãozinhos de 2 a 4 px.
        Duas texturas entrelaçadas leem opticamente como o tom do meio — é a
        técnica clássica de pixel art;
      * LÂMINA (mato alto, savana): a máscara passa a variar sobretudo ao longo
        de X, em faixas. Lâmina é vertical: serrilhada pixel a pixel ela vira
        chuvisco; escolhida em faixa, some ou aparece inteira.

    Acima do losango só existe lâmina, então lá a escolha é sempre por coluna —
    caso contrário a ponta de uma lâmina ficaria solta no ar, sem a base.

    [b]Por que o grão fino é ruído e não só Bayer[/b]: com a matriz ordenada
    pura, `t` perto de 0,5 vira um xadrez perfeito e o tile ganha aquele efeito
    de tela de mosquiteiro. Um ruído fino aglomera os pixels em tufos
    irregulares — que é como um pixel artist mistura duas gramas. O Bayer entra
    só com um quinto do peso, para a distribuição não empoçar.
    """
    weight_column = 0.20 + 0.55 * structure
    weight_surface = 0.20
    weight_fine = max(0.0, 1.0 - weight_column - weight_surface)
    selector = np.zeros((H, W), dtype=float)
    for x in range(W):
        yt, _yb = diamond_edges(x)
        u = (x + 0.5 - 64.0) / 64.0
        v_top = (yt - CY) / 32.0
        cx = u * 64.0 + v_top * 64.0
        cy = v_top * 64.0 - u * 64.0
        column = (0.62 * smooth_noise(cx, cy, 15.0, seed)
                  + 0.38 * smooth_noise(cx, cy, 5.0, seed + 7))
        for y in range(H):
            dither = BAYER8[y & 7][x & 7]
            if y < yt:
                selector[y, x] = 0.88 * column + 0.12 * dither
                continue
            v = (y + 0.5 - CY) / 32.0
            sx = u * 64.0 + v * 64.0
            sy = v * 64.0 - u * 64.0
            surface = (0.62 * smooth_noise(sx, sy, 16.0, seed)
                       + 0.38 * smooth_noise(sx, sy, 5.0, seed + 7))
            grain = (0.70 * smooth_noise(sx, sy, 2.3, seed + 41)
                     + 0.30 * smooth_noise(sx, sy, 1.2, seed + 91))
            selector[y, x] = (
                weight_column * column
                + weight_surface * surface
                + weight_fine * (0.78 * grain + 0.22 * dither)
            )
    return _equalize(selector)


def _equalize(selector):
    """Achata o histograma do seletor, por região.

    Ruído de valor interpolado NÃO é uniforme: os valores se aglomeram perto de
    0,5. Sem corrigir isso, `t = 0,2` e `t = 0,4` trocam quase nada e `t = 0,6`
    troca metade do tile de uma vez — a escala do bioma anda aos trancos.
    Trocando cada valor pela sua POSIÇÃO no ranking, `t` passa a significar
    exatamente "esta fração da área vem do segundo tile", e os degraus ficam do
    mesmo tamanho.

    O ranking é feito separado para as LÂMINAS (acima do losango) e para a
    SUPERFÍCIE, senão uma região comeria a cota da outra.
    """
    blades = np.zeros((H, W), dtype=bool)
    for x in range(W):
        yt, _yb = diamond_edges(x)
        blades[:max(0, int(math.floor(yt))), x] = True
    out = np.zeros_like(selector)
    for region in (blades, ~blades):
        values = selector[region]
        order = np.argsort(values, kind='stable')
        ranks = np.empty(values.size, dtype=float)
        ranks[order] = (np.arange(values.size) + 0.5) / float(values.size)
        out[region] = ranks
    return out


def blend_frames(frames_a, frames_b, t, selector):
    """Mistura quadro a quadro, com a MESMA máscara nos três.

    Usar a mesma máscara é o que mantém a animação coerente: a lâmina que balança
    continua sendo a mesma lâmina nos três quadros.
    """
    take_b = selector < t
    out = []
    for frame_a, frame_b in zip(frames_a, frames_b):
        a = np.array(frame_a)
        b = np.array(frame_b)
        out.append(Image.fromarray(
            np.where(take_b[:, :, None], b, a).astype(np.uint8), 'RGBA'
        ))
    return out


def intermediate_count(distance):
    steps = int(round(distance / BLEND_TARGET_DISTANCE))
    return max(0, min(BLEND_MAX_PER_PAIR, steps - 1))


# ---------------------------------------------------------------- montagem
rows = []          # (id, frames, animado)
manifest_rows = []
manifest_biomes = []

for biome_id, variants in BIOMES:
    loaded = {vid: load_frames(folder) for vid, folder, _w in variants}
    weights = {vid: weight for vid, _folder, weight in variants}
    described = {vid: describe(frames[0]) for vid, frames in loaded.items()}
    chain = order_chain([vid for vid, _f, _w in variants], described)

    scale = []     # (id, frames, animado, peso, origem)
    for index, vid in enumerate(chain):
        scale.append((vid, loaded[vid], True, weights[vid], 'arte'))
        if index + 1 >= len(chain):
            break
        next_id = chain[index + 1]
        distance = perceptual_distance(described[vid], described[next_id])
        count = intermediate_count(distance)
        if count == 0:
            continue
        structure = min(
            1.0,
            (described[vid]['blades'] + described[next_id]['blades']) / 2.0 / 800.0
        )
        selector = build_selector(
            zlib.crc32((vid + '>' + next_id).encode('utf-8')) & 0xFFFF, structure
        )
        bridge_weight = WEIGHT_BLEND_FACTOR * min(weights[vid], weights[next_id])
        for step in range(count):
            t = float(step + 1) / float(count + 1)
            blend_id = '%s_para_%s' % (vid, next_id)
            if count > 1:
                blend_id += '_%d' % (step + 1)
            scale.append((
                blend_id,
                blend_frames(loaded[vid], loaded[next_id], t, selector),
                True,
                bridge_weight,
                'transicao',
            ))
        print('  %-20s -> %-20s  d=%5.1f  estrutura=%.2f  +%d' % (
            vid, next_id, distance, structure, count))

    variant_entries = []
    for vid, frames, animated, weight, kind in scale:
        manifest_rows.append({
            'id': vid, 'row': len(rows), 'animated': animated,
            'biome': biome_id, 'kind': kind,
        })
        variant_entries.append({'id': vid, 'weight': weight, 'kind': kind})
        rows.append((vid, frames, animated))
    manifest_biomes.append({
        'id': biome_id,
        'wall': biome_id + '_terra',
        'variants': variant_entries,
    })

ANIMATED_ROWS = len(rows)

for biome_id, variants in BIOMES:
    # O bloco de terra sai da última variante DA PASTA (a "baixa"), que é a de
    # grama mais curta e portanto a de lateral mais limpa. Continua vindo da
    # arte original: nenhuma intermediária participa disso.
    base_id, folder, _weight = variants[-1]
    base = Image.open(folder + 'frame_1.png').convert('RGBA')
    dirt_id = biome_id + '_terra'
    manifest_rows.append({
        'id': dirt_id, 'row': len(rows), 'animated': False,
        'biome': biome_id, 'kind': 'terra',
    })
    rows.append((dirt_id, [make_dirt_block(biome_id, base)], False))

atlas = Image.new('RGBA', (W * 3, H * len(rows)), (0, 0, 0, 0))
for r, (name, frames, _animated) in enumerate(rows):
    for c, frame in enumerate(frames):
        atlas.paste(frame, (c * W, r * H))
out_path = 'assets/world/tiles/ground_atlas.png'
atlas.save(out_path)


def split_top_and_faces(source_atlas, row_count):
    """Separa cada bloco em superfície e laterais expostas.

    O atlas de faces guarda os três recortes LADO A LADO (esquerda, direita,
    ambas), cada um com seus 3 quadros de animação. Empilhá-los em linhas faria
    a textura passar de 13 000 px de altura com o número de variantes atual —
    perto do teto de muitas GPUs. Em colunas, ela fica na mesma altura do atlas
    de superfície.
    """
    top_atlas = Image.new('RGBA', source_atlas.size, (0, 0, 0, 0))
    face_atlas = Image.new('RGBA', (W * 9, H * row_count), (0, 0, 0, 0))

    for row in range(row_count):
        for frame in range(3):
            box = (frame * W, row * H, (frame + 1) * W, (row + 1) * H)
            block = source_atlas.crop(box)
            block_px = np.array(block)
            top_px = np.zeros_like(block_px)
            left_px = np.zeros_like(block_px)
            right_px = np.zeros_like(block_px)

            for x in range(W):
                _yt, yb = diamond_edges(x)
                boundary = int(math.ceil(yb))
                # Duplica a linha de contorno: o topo fica atrás da face, então
                # a sobreposição elimina frestas sem alterar a oclusão.
                top_px[:min(H, boundary + 1), x] = block_px[:min(H, boundary + 1), x]
                if boundary < H:
                    # Uma fatia visual representa exatamente um Z-Level.
                    # Recortar pela altura lógica faz fatias consecutivas se
                    # encontrarem sem sobreposição nem buracos.
                    face_bottom = min(H, boundary + SKIRT)
                    if x < W // 2:
                        left_px[boundary:face_bottom, x] = block_px[boundary:face_bottom, x]
                    else:
                        right_px[boundary:face_bottom, x] = block_px[boundary:face_bottom, x]

            top_frame = Image.fromarray(top_px, 'RGBA')
            left_frame = Image.fromarray(left_px, 'RGBA')
            right_frame = Image.fromarray(right_px, 'RGBA')
            both_frame = Image.alpha_composite(left_frame, right_frame)

            top_atlas.paste(top_frame, (frame * W, row * H))
            for face_kind, face_frame in enumerate((left_frame, right_frame, both_frame)):
                face_atlas.paste(face_frame, ((face_kind * 3 + frame) * W, row * H))

    top_atlas.save('assets/world/tiles/ground_top_atlas.png')
    face_atlas.save('assets/world/tiles/depth_face_atlas.png')
    return top_atlas, face_atlas


top_atlas, face_atlas = split_top_and_faces(atlas, len(rows))

manifest = {
    'tile': {'width': W, 'height': H, 'skirt': SKIRT, 'frames': 3,
             'diamond_top': DIAMOND_TOP, 'diamond_height': DIAMOND_H},
    'atlas': {
        'ground': 'res://assets/world/tiles/ground_atlas.png',
        'top': 'res://assets/world/tiles/ground_top_atlas.png',
        'face': 'res://assets/world/tiles/depth_face_atlas.png',
        'face_kind_stride': 3,
    },
    'animated_rows': ANIMATED_ROWS,
    'rows': manifest_rows,
    'biomes': manifest_biomes,
}
with open('assets/world/tiles/ground_atlas.json', 'w', encoding='utf-8') as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=1)

print('atlas', atlas.size, '->', out_path)
print('top atlas', top_atlas.size, '-> assets/world/tiles/ground_top_atlas.png')
print('face atlas', face_atlas.size, '-> assets/world/tiles/depth_face_atlas.png')
print('manifesto  -> assets/world/tiles/ground_atlas.json')
print('linhas: %d (%d animadas, %d de terra)' % (
    len(rows), ANIMATED_ROWS, len(rows) - ANIMATED_ROWS))
for entry in manifest_rows:
    print('    %-28s linha %2d  %s  %s' % (
        entry['id'], entry['row'], entry['biome'], entry['kind']))

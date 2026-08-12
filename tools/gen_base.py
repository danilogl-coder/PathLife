# -*- coding: utf-8 -*-
"""
Gerador dos modelos-base (mannequins verdes) do PathLife.
Canvas por frame: 32x48. Pivo: centro-base (16, 48). Pes tocam y=46.
Sheet: 4 frames na horizontal, ordem: SE, SO, NE, NO (128x48).
Paleta-chave (rampa verde para chroma-swap):
  HL (140,230,110)  luz
  BA (90,190,70)    base
  SH (55,140,55)    sombra
  OL (30,85,40)     contorno/escuro
"""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 32, 48
HL = (140, 230, 110, 255)
BA = (90, 190, 70, 255)
SH = (55, 140, 55, 255)
OL = (30, 85, 40, 255)
TR = (0, 0, 0, 0)

CX = 16.0  # centro horizontal (entre colunas 15 e 16) -> espelhamento perfeito


# ---------- primitivas ----------

def ellipse(cx, cy, rx, ry):
    pts = []
    for y in range(H):
        for x in range(W):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                pts.append((x, y))
    return pts


def rect(x0, y0, x1, y1):
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def trapezoid(cx, y0, y1, w_top, w_bot):
    pts = []
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, (y1 - y0))
        w = w_top + (w_bot - w_top) * t
        x0 = int(round(cx - w / 2))
        x1 = int(round(cx + w / 2)) - 1
        pts += [(x, y) for x in range(x0, x1 + 1)]
    return pts


# ---------- render ----------

def render(parts):
    """parts: lista de (pixels, style). style: 'auto' | 'shade' | 'dark' | 'light'
    Desenha na ordem; sombreia por parte; contorno so na silhueta externa."""
    img = [[TR] * W for _ in range(H)]
    union = set()
    for pix, style in parts:
        if style == 'auto':
            union |= set(pix)

    for pix, style in parts:
        pix = list(pix)
        if not pix:
            continue
        xs = [p[0] for p in pix]
        ys = [p[1] for p in pix]
        minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
        for (x, y) in pix:
            if not (0 <= x < W and 0 <= y < H):
                continue
            # overlays (shade/dark/light) so pintam DENTRO da silhueta
            if style in ('shade', 'dark', 'light'):
                if (x, y) not in union:
                    continue
                img[y][x] = {'shade': SH, 'dark': OL, 'light': HL}[style]
                continue
            rx = (x - minx) / max(1, maxx - minx)
            ry = (y - miny) / max(1, maxy - miny)
            score = rx * 0.35 + ry * 0.75
            if score < 0.26:
                c = HL
            elif score > 0.86:
                c = SH
            else:
                c = BA
            img[y][x] = c

    # contorno externo (apenas silhueta)
    for (x, y) in union:
        if not (0 <= x < W and 0 <= y < H):
            continue
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= W or ny >= H or (nx, ny) not in union:
                img[y][x] = OL
                break
    return img


def to_image(img):
    im = Image.new('RGBA', (W, H), TR)
    px = im.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = img[y][x]
    return im


def mirror(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


# ---------- corpos ----------

def adult(sex='m', elder=False, front=True):
    parts = []
    h = 3 if elder else 0          # idoso: 3px mais baixo (curvado)
    fwd = 1 if elder else 0        # idoso: cabeca 1px a frente

    if sex == 'm':
        # tronco: ombros 10 -> cintura 8 (bracos ficam FORA do tronco)
        sh_w = 8 if elder else 10
        parts.append((trapezoid(CX, 27 + h, 37, sh_w, 8), 'auto'))
        arm_l, arm_r = (10, 20) if elder else (9, 21)
        seam_l, seam_r = arm_l + 2, arm_r - 1
    else:
        sh_w = 8
        parts.append((trapezoid(CX, 27 + h, 37, sh_w, 7), 'auto'))       # tronco unico
        parts.append((trapezoid(CX, 33 + h, 37, 7, 10), 'auto'))         # quadril
        arm_l, arm_r = 10, 20
        seam_l, seam_r = 12, 19

    # ombros: 1 linha cheia ligando bracos ao tronco
    parts.append((rect(arm_l, 27 + h, arm_r + 1, 28 + h), 'auto'))

    # bracos (2px, encostados no tronco)
    parts.append((rect(arm_l, 28 + h, arm_l + 1, 36), 'auto'))
    parts.append((rect(arm_r, 28 + h, arm_r + 1, 36), 'auto'))

    # pernas
    parts.append((rect(11, 38, 14, 44), 'auto'))
    parts.append((rect(17, 38, 20, 44), 'auto'))

    # pes
    parts.append((rect(10, 45, 14, 46), 'auto'))
    parts.append((rect(17, 45, 21, 46), 'auto'))

    # corcunda do idoso (atras do pescoco)
    if elder:
        parts.append((ellipse(CX, 27.0 + h - 1, 4.5, 2.0), 'auto'))

    # cabeca por cima
    parts.append((ellipse(CX + fwd, 20.5 + h, 6.0, 5.5), 'auto'))

    # ---- detalhes ----
    if front:
        parts.append((rect(14 + fwd, 26 + h, 17 + fwd, 26 + h), 'shade'))  # sombra do queixo
    else:
        parts.append((rect(13, 36, 18, 36), 'shade'))                      # base das costas
    # costura braco/tronco (linha de sombra curta, so na altura do ombro)
    seam_end = 33 + h if sex == 'f' else 36
    parts.append(([(seam_l, y) for y in range(29 + h, seam_end)], 'shade'))
    parts.append(([(seam_r, y) for y in range(29 + h, seam_end)], 'shade'))
    # maos: pontinha clara
    parts.append((rect(arm_l, 35, arm_l + 1, 35), 'light'))
    parts.append((rect(arm_r, 35, arm_r + 1, 35), 'light'))
    return parts


def child(sex='m', front=True):
    parts = []
    if sex == 'm':
        parts.append((trapezoid(CX, 35, 41, 7, 6), 'auto'))
    else:
        parts.append((trapezoid(CX, 35, 38, 7, 5), 'auto'))
        parts.append((trapezoid(CX, 38, 41, 5, 7), 'auto'))
    arm_l, arm_r = 11, 19
    seam_l, seam_r = 13, 18

    parts.append((rect(arm_l, 35, arm_r + 1, 36), 'auto'))   # ombros
    parts.append((rect(arm_l, 36, arm_l + 1, 41), 'auto'))
    parts.append((rect(arm_r, 36, arm_r + 1, 41), 'auto'))

    parts.append((rect(12, 42, 14, 44), 'auto'))
    parts.append((rect(17, 42, 19, 44), 'auto'))
    parts.append((rect(11, 45, 14, 46), 'auto'))
    parts.append((rect(17, 45, 20, 46), 'auto'))

    parts.append((ellipse(CX, 30.5, 5.0, 4.5), 'auto'))
    if front:
        parts.append((rect(14, 35, 17, 35), 'shade'))
    parts.append(([(seam_l, y) for y in range(37, 41)], 'shade'))
    parts.append(([(seam_r, y) for y in range(37, 41)], 'shade'))
    return parts


def baby(front=True):
    # bebe sentado: cabecao, corpo redondo, perninhas abertas para os lados
    parts = []
    parts.append((ellipse(CX, 44.0, 5.0, 3.2), 'auto'))          # corpo
    parts.append((rect(8, 45, 11, 46), 'auto'))                  # perna esq (aberta)
    parts.append((rect(20, 45, 23, 46), 'auto'))                 # perna dir (aberta)
    parts.append((rect(9, 42, 10, 44), 'auto'))                  # braco esq
    parts.append((rect(21, 42, 22, 44), 'auto'))                 # braco dir
    parts.append((ellipse(CX, 37.0, 5.2, 4.5), 'auto'))          # cabecao
    if front:
        parts.append((rect(14, 41, 17, 41), 'shade'))
    # pezinhos claros
    parts.append((rect(8, 45, 8, 46), 'light'))
    parts.append((rect(23, 45, 23, 46), 'light'))
    return parts


# ---------- montagem ----------

def make_sheet(front_parts, back_parts):
    """Retorna sheet 128x48: SE, SO, NE, NO"""
    se = to_image(render(front_parts))
    so = mirror(se)
    ne = to_image(render(back_parts))
    no = mirror(ne)
    sheet = Image.new('RGBA', (W * 4, H), TR)
    for i, f in enumerate((se, so, ne, no)):
        sheet.paste(f, (i * W, 0))
    return sheet


MODELS = {
    'body_male_adult':    lambda front: adult('m', False, front),
    'body_female_adult':  lambda front: adult('f', False, front),
    'body_male_elder':    lambda front: adult('m', True, front),
    'body_female_elder':  lambda front: adult('f', True, front),
    'body_male_child':    lambda front: child('m', front),
    'body_female_child':  lambda front: child('f', front),
    'body_baby':          lambda front: baby(front),
}


def build_all(outdir):
    os.makedirs(outdir, exist_ok=True)
    sheets = {}
    for name, fn in MODELS.items():
        sheet = make_sheet(fn(True), fn(False))
        sheet.save(os.path.join(outdir, name + '.png'))
        sheets[name] = sheet
    return sheets


# ---------- recoloracao (validacao da tecnica) ----------

RAMPS = {
    'verde (original)': [HL, BA, SH, OL],
    'pele clara':   [(255, 221, 190, 255), (235, 189, 151, 255), (191, 141, 106, 255), (120, 80, 60, 255)],
    'pele media':   [(222, 171, 121, 255), (191, 140, 96, 255), (140, 96, 61, 255), (85, 55, 35, 255)],
    'pele escura':  [(151, 101, 71, 255), (116, 76, 51, 255), (81, 51, 36, 255), (45, 28, 20, 255)],
    'fantasia':     [(150, 200, 255, 255), (100, 160, 230, 255), (60, 110, 180, 255), (30, 60, 110, 255)],
}

KEYS = [HL, BA, SH, OL]


def recolor(im, ramp):
    im = im.copy()
    px = im.load()
    mapping = {KEYS[i]: ramp[i] for i in range(4)}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c in mapping:
                px[x, y] = mapping[c]
    return im


def preview(sheets, path, scale=5):
    pad = 8
    label_h = 14
    cols = Image.new('RGBA', (10, 10))
    font = ImageFont.load_default()

    row_imgs = []
    for name, sheet in sheets.items():
        big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
        row = Image.new('RGBA', (big.width + pad * 2, big.height + label_h + pad), (40, 42, 50, 255))
        row.paste(big, (pad, label_h), big)
        d = ImageDraw.Draw(row)
        d.text((pad, 1), name + '.png   [SE | SO | NE | NO]', fill=(230, 230, 230, 255), font=font)
        row_imgs.append(row)

    # linha de recoloracao: adulto M frame SE em todas as rampas
    se = sheets['body_male_adult'].crop((0, 0, W, H))
    swatches = []
    for rname, ramp in RAMPS.items():
        r = recolor(se, ramp).resize((W * scale, H * scale), Image.NEAREST)
        sw = Image.new('RGBA', (r.width + pad, r.height + label_h), (40, 42, 50, 255))
        sw.paste(r, (pad // 2, label_h), r)
        d = ImageDraw.Draw(sw)
        d.text((2, 1), rname, fill=(230, 230, 230, 255), font=font)
        swatches.append(sw)
    swrow = Image.new('RGBA', (sum(s.width for s in swatches) + pad, max(s.height for s in swatches) + pad),
                      (40, 42, 50, 255))
    xoff = pad // 2
    for s in swatches:
        swrow.paste(s, (xoff, pad // 2), s)
        xoff += s.width

    total_w = max(max(r.width for r in row_imgs), swrow.width)
    total_h = sum(r.height for r in row_imgs) + swrow.height + pad
    canvas = Image.new('RGBA', (total_w, total_h), (40, 42, 50, 255))
    yoff = 0
    for r in row_imgs:
        canvas.paste(r, (0, yoff), r)
        yoff += r.height
    canvas.paste(swrow, (0, yoff + pad), swrow)
    canvas.save(path)


if __name__ == '__main__':
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'base_sprites')
    sheets = build_all(out)
    preview(sheets, os.path.join(out, 'preview.png'))
    print('OK:', list(sheets.keys()))

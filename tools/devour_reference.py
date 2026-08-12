# -*- coding: utf-8 -*-
"""
"Devora" a referencia de 8 direcoes e produz o sistema de camadas do PathLife:
  - body_male_adult.png : manequim verde (anatomia da referencia, careca, sem rosto)
  - hair_m_adult_01.png : cabelo em verde-chave (recoloravel)
  - top_m_adult_01.png / bottom_m_adult_01.png / shoes_m_adult_01.png : cores originais
Frame padrao: 48x80, pivo centro-base (24,80), pes em y=77.
Sheet: 8 frames na ordem S, SE, E, NE, N, NW, W, SW  (384x80).
"""
from PIL import Image, ImageDraw, ImageFont
from collections import deque
import os

SRC = '/sessions/ecstatic-laughing-rubin/mnt/uploads'
OUT = '/sessions/ecstatic-laughing-rubin/mnt/outputs/base_v2'
os.makedirs(OUT, exist_ok=True)

FW, FH = 48, 80
FOOT_Y = 77
CXF = 24
ORDER = ['south', 'south-east', 'east', 'north-east', 'north', 'north-west', 'west', 'south-west']

# rampa verde-chave
HL = (140, 230, 110, 255)
BA = (90, 190, 70, 255)
SH = (55, 140, 55, 255)
OL = (30, 85, 40, 255)
TR = (0, 0, 0, 0)

# paleta da referencia -> (categoria, indice_na_rampa 0..3)
SKIN = {(239, 192, 158): 0, (206, 156, 126): 1, (171, 124, 96): 2, (138, 100, 79): 3, (14, 7, 4): 3}
SHIRT = {(247, 243, 238): 1, (178, 171, 169): 2, (129, 128, 134): 3}
PANTS = {(133, 177, 215): 1, (80, 126, 167): 2, (61, 95, 131): 2, (0, 41, 81): 3}
DARKS = {(5, 3, 3), (7, 8, 10), (14, 12, 10), (17, 16, 18), (27, 23, 31)}
GRAYS = {(50, 51, 59), (56, 55, 64)}  # brilho do cabelo / olhos

GREEN_IDX = [HL, BA, SH, OL]
HEAD_BAND = 18   # altura da cabeca (topo do cabelo ate o queixo) na referencia


def load_frames():
    frames = []
    for name in ORDER:
        im = Image.open(os.path.join(SRC, name + '.png')).convert('RGBA')
        px = im.load()
        pts = {}
        for y in range(im.height):
            for x in range(im.width):
                c = px[x, y]
                if c[3] > 10 and not (c[0] > 240 and c[1] > 240 and c[2] > 240 and c[3] < 255 and False):
                    pts[(x, y)] = (c[0], c[1], c[2])
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        # normaliza: pes em FOOT_Y, centro do bbox em CXF
        dx = CXF - (min(xs) + max(xs)) // 2 - min(xs) + min(xs)
        dx = CXF - ((min(xs) + max(xs)) // 2)
        dy = FOOT_Y - max(ys)
        norm = {}
        for (x, y), c in pts.items():
            nx, ny = x + dx, y + dy
            if 0 <= nx < FW and 0 <= ny < FH:
                norm[(nx, ny)] = c
        frames.append(norm)
    return frames


def classify(pts):
    """Retorna dicts por categoria + regiao do couro cabeludo (banda + escuros conectados)."""
    top_y = min(y for (_, y) in pts)
    band_max = top_y + HEAD_BAND
    cat = {}
    for (x, y), c in pts.items():
        in_band = y <= band_max
        if in_band and (c == (61, 95, 131) or c in SHIRT or
                        (c[0] > 240 and c[1] > 240 and c[2] > 235)):
            cat[(x, y)] = ('face', 1)          # olhos/sobrancelha viram camada propria
        elif c in SKIN:
            cat[(x, y)] = ('skin', SKIN[c])
        elif c in PANTS:
            cat[(x, y)] = ('pants', PANTS[c])
        elif c in SHIRT or (c[0] > 240 and c[1] > 240 and c[2] > 235):
            if y >= 68:
                cat[(x, y)] = ('shoes', SHIRT.get(c, 1))
            else:
                cat[(x, y)] = ('shirt', SHIRT.get(c, 1))
        elif (c in DARKS or c in GRAYS) and y >= 68:
            cat[(x, y)] = ('shoes_dark', 3)    # sola escura: corpo OL + camada tenis
        elif c in DARKS or c in GRAYS:
            cat[(x, y)] = ('dark', 3)
        else:
            # cor desconhecida: escala por luminancia
            l = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
            idx = 0 if l > 200 else 1 if l > 140 else 2 if l > 60 else 3
            cat[(x, y)] = ('other', idx)

    # couro cabeludo: tudo na banda da cabeca + escuros conectados a ela (nuca)
    scalp = set(p for p in pts if p[1] <= band_max)
    queue = deque(p for p in scalp if cat[p][0] == 'dark')
    seen = set(queue)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            p = (nx, ny)
            # limita a extensao da nuca para o flood nao vazar pelos contornos do corpo
            if p in pts and p not in seen and ny <= band_max + 5 \
                    and cat.get(p, ('', 0))[0] == 'dark':
                seen.add(p)
                queue.append(p)
    scalp |= seen
    hair = set(p for p in scalp if cat[p][0] == 'dark')
    return cat, scalp, hair, top_y


def head_shading(scalp):
    xs = [p[0] for p in scalp]
    ys = [p[1] for p in scalp]
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    rx = max(1.0, (max(xs) - min(xs)) / 2)
    ry = max(1.0, (max(ys) - min(ys)) / 2)
    out = {}
    for (x, y) in scalp:
        nx = (x - cx) / rx
        ny = (y - cy) / ry
        t = nx * 0.45 + ny * 0.75
        out[(x, y)] = HL if t < -0.35 else (BA if t < 0.45 else SH)
    return out


def build(frames):
    body_f, hair_f, top_f, bot_f, shoe_f, eye_f = [], [], [], [], [], []
    for pts in frames:
        cat, scalp, hair, top_y = classify(pts)
        body = {}
        hair_l, top_l, bot_l, shoe_l, eye_l = {}, {}, {}, {}, {}

        shading = head_shading(scalp)
        for p, c in pts.items():
            k, idx = cat[p]
            if p in scalp:
                body[p] = shading[p]           # cabeca careca, sem rosto
            elif k in ('dark', 'shoes_dark'):
                body[p] = OL                   # contornos internos (entre pernas, braco/tronco)
            else:
                body[p] = GREEN_IDX[min(3, idx)]
            # camadas
            if p in hair:
                # cabelo em verde-chave: tons por luminancia original
                l = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                hair_l[p] = HL if l > 45 else (BA if l > 20 else (SH if l > 8 else OL))
            elif k == 'face':
                eye_l[p] = c + (255,)
            elif k == 'shirt':
                top_l[p] = c + (255,)
            elif k == 'pants':
                bot_l[p] = c + (255,)
            elif k in ('shoes', 'shoes_dark'):
                shoe_l[p] = c + (255,)

        # contorno externo do manequim
        allp = set(body)
        for (x, y) in list(allp):
            for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if (nx, ny) not in allp:
                    body[(x, y)] = OL
                    break
        body_f.append(body)
        hair_f.append(hair_l)
        top_f.append(top_l)
        bot_f.append(bot_l)
        shoe_f.append(shoe_l)
        eye_f.append(eye_l)
    return body_f, hair_f, top_f, bot_f, shoe_f, eye_f


def to_sheet(frame_dicts):
    sheet = Image.new('RGBA', (FW * 8, FH), TR)
    px = sheet.load()
    for i, fd in enumerate(frame_dicts):
        for (x, y), c in fd.items():
            px[i * FW + x, y] = c if len(c) == 4 else c + (255,)
    return sheet


def recolor(im, ramp):
    im = im.copy()
    px = im.load()
    m = {HL: ramp[0], BA: ramp[1], SH: ramp[2], OL: ramp[3]}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c in m:
                px[x, y] = m[c]
    return im


SKIN_RAMP = [(255, 221, 190, 255), (235, 189, 151, 255), (191, 141, 106, 255), (120, 80, 60, 255)]
DARKSKIN_RAMP = [(151, 101, 71, 255), (116, 76, 51, 255), (81, 51, 36, 255), (45, 28, 20, 255)]
BLACKHAIR_RAMP = [(70, 70, 85, 255), (40, 38, 50, 255), (22, 20, 28, 255), (8, 7, 10, 255)]
BLONDE_RAMP = [(250, 225, 150, 255), (225, 185, 105, 255), (175, 130, 70, 255), (110, 75, 40, 255)]


def compose(*sheets):
    base = Image.new('RGBA', sheets[0].size, TR)
    for s in sheets:
        base = Image.alpha_composite(base, s)
    return base


if __name__ == '__main__':
    frames = load_frames()
    body_f, hair_f, top_f, bot_f, shoe_f, eye_f = build(frames)

    body = to_sheet(body_f)
    hair = to_sheet(hair_f)
    top = to_sheet(top_f)
    bottom = to_sheet(bot_f)
    shoes = to_sheet(shoe_f)
    eyes = to_sheet(eye_f)

    body.save(os.path.join(OUT, 'body_male_adult.png'))
    hair.save(os.path.join(OUT, 'hair_m_adult_01.png'))
    top.save(os.path.join(OUT, 'top_m_adult_01.png'))
    bottom.save(os.path.join(OUT, 'bottom_m_adult_01.png'))
    shoes.save(os.path.join(OUT, 'shoes_m_adult_01.png'))
    eyes.save(os.path.join(OUT, 'eyes_m_adult_01.png'))

    # preview: original | manequim | pele clara | recomposto (pele+cabelo preto+roupas) | recomposto moreno+loiro
    orig = Image.new('RGBA', (FW * 8, FH), TR)
    px = orig.load()
    for i, fd in enumerate(frames):
        for (x, y), c in fd.items():
            px[i * FW + x, y] = c + (255,)

    recomp1 = compose(recolor(body, SKIN_RAMP), top, bottom, shoes, eyes, recolor(hair, BLACKHAIR_RAMP))
    recomp2 = compose(recolor(body, DARKSKIN_RAMP), top, bottom, shoes, eyes, recolor(hair, BLONDE_RAMP))

    rows = [('referencia original', orig),
            ('body_male_adult (manequim verde)', body),
            ('manequim + rampa de pele', recolor(body, SKIN_RAMP)),
            ('camada de cabelo (verde-chave) + olhos', compose(hair, eyes)),
            ('recomposto: pele clara + cabelo preto + roupas', recomp1),
            ('recomposto: pele escura + cabelo loiro + roupas', recomp2)]

    scale = 4
    pad, label_h = 8, 14
    font = ImageFont.load_default()
    row_imgs = []
    for name, sheet in rows:
        big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
        row = Image.new('RGBA', (big.width + pad * 2, big.height + label_h + pad), (40, 42, 50, 255))
        row.paste(big, (pad, label_h), big)
        ImageDraw.Draw(row).text((pad, 1), name, fill=(230, 230, 230, 255), font=font)
        row_imgs.append(row)
    canvas = Image.new('RGBA', (max(r.width for r in row_imgs), sum(r.height for r in row_imgs)), (40, 42, 50, 255))
    yoff = 0
    for r in row_imgs:
        canvas.paste(r, (0, yoff), r)
        yoff += r.height
    canvas.save(os.path.join(OUT, 'preview_v2.png'))
    print('OK')

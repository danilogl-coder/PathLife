"""Gera a sombra de chão das entidades no mesmo estilo das sombras das árvores.

A arte do projeto usa uma elipse isométrica com contorno em xadrez (dithering)
na cor (40, 34, 52). Este script reproduz esse estilo no tamanho de um
personagem, para a sombra não destoar da vegetação.
"""
from PIL import Image

W, H = 34, 18           # elipse isométrica 2:1, um pouco mais larga que o corpo
CORE = 0.52             # fração interna preenchida sólida
SHADOW = (40, 34, 52)

img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
px = img.load()
cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
rx, ry = W / 2.0, H / 2.0

for y in range(H):
    for x in range(W):
        u = (x - cx) / rx
        v = (y - cy) / ry
        d = u * u + v * v
        if d > 1.0:
            continue
        if d <= CORE:
            px[x, y] = (SHADOW[0], SHADOW[1], SHADOW[2], 255)
        elif (x + y) % 2 == 0:          # xadrez, igual à sombra das árvores
            px[x, y] = (SHADOW[0], SHADOW[1], SHADOW[2], 255)

out = 'assets/world/entity_shadow.png'
img.save(out)
print('sombra', img.size, '->', out)

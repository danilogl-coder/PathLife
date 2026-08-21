"""Monta os atlas de animação das árvores.

A pasta `Isometric Tiles/arvores/<arvore>/frames/` traz 48 quadros de 128x208
com a queda de folhas. Empilhar os 48 em uma tira só daria uma textura de
6144 px de largura; em GRADE (8 colunas x 6 linhas) ela fica em 1024x1248, um
formato muito mais amigável para qualquer GPU.

A ferramenta grava também um manifesto JSON, para o `build_world_resources.gd`
montar os `SpriteFrames` sem nenhuma lista repetida na mão.

Uso (a partir da raiz do projeto):
    python3 tools/gen_tree_atlases.py
"""
from PIL import Image
import json
import os

SRC = os.environ.get('PATHLIFE_TREES_SRC', '../../Isometric Tiles/arvores/')
OUT = 'assets/world/vegetation/'

TREES = ['alamo', 'baoba', 'ipe', 'palmeira', 'salgueiro', 'sequoia']
FRAME_COUNT = 48
COLUMNS = 8
## 110 ms por quadro é a cadência do GIF que veio junto da arte.
FRAME_MILLISECONDS = 110
## Nome da animação. É "queda" porque é isso que a arte faz: folha caindo.
ANIMATION = 'queda'


def load_frames(tree):
    frames = []
    for index in range(1, FRAME_COUNT + 1):
        path = '%s%s/frames/queda_%02d.png' % (SRC, tree, index)
        frames.append(Image.open(path).convert('RGBA'))
    return frames


def build(tree):
    frames = load_frames(tree)
    width, height = frames[0].size
    rows = (FRAME_COUNT + COLUMNS - 1) // COLUMNS
    atlas = Image.new('RGBA', (COLUMNS * width, rows * height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        if frame.size != (width, height):
            raise SystemExit('%s: quadro %d tem tamanho diferente' % (tree, index + 1))
        atlas.paste(frame, ((index % COLUMNS) * width, (index // COLUMNS) * height))
    path = '%sarvore_%s_atlas.png' % (OUT, tree)
    atlas.save(path)
    return {
        'id': tree,
        'texture': 'res://%sarvore_%s_atlas.png' % (OUT, tree),
        'frame_size': [width, height],
        'columns': COLUMNS,
        'rows': rows,
        'frames': FRAME_COUNT,
    }, atlas.size


os.makedirs(OUT, exist_ok=True)
entries = []
for tree_id in TREES:
    entry, size = build(tree_id)
    entries.append(entry)
    print('  %-10s %s  %d quadros' % (tree_id, size, FRAME_COUNT))

manifest = {
    'animation': ANIMATION,
    'frame_milliseconds': FRAME_MILLISECONDS,
    'fps': round(1000.0 / FRAME_MILLISECONDS, 3),
    'trees': entries,
}
with open(OUT + 'arvores_atlas.json', 'w', encoding='utf-8') as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=1)
print('manifesto -> %sarvores_atlas.json  (%s, %.2f fps)' % (
    OUT, ANIMATION, manifest['fps']))

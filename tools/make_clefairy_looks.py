# Builds assets/clefairy/badassbill.png: a Clefairy walking sheet in the 9-frame column Facets' partner looks use (32x32 frames:
# down, up and left standing, then each one's two steps), with the
# sprite's feet on row 29 like HeartGold's.
# python3 tools/make_clefairy_looks.py <badassbill sheet> assets/clefairy -Elvie
import sys
from PIL import Image, ImageOps

def clear_bg(im, bg):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    seen, stack = set(), [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][:3] != bg:
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im

def placed(cell, feet=29, lift=0):
    box = cell.getbbox()
    out = Image.new("RGBA", (32, 32))
    if not box:
        return out
    part = cell.crop(box)
    x = 16 - (part.width + 1) // 2
    y = feet + 1 - part.height - lift
    out.alpha_composite(part, (x, y))
    return out

def column(frames):
    out = Image.new("RGBA", (32, 32 * len(frames)))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (0, 32 * i))
    return out

bill_src, dest = sys.argv[1], sys.argv[2]

# Badassbill: a 4x4 grid of 17x17 cells on white (side, side again, down,
# up), each row stand, step, stand, step. Its side rows face right, so
# they're mirrored for the left-facing frames the engine wants -Elvie
b = Image.open(bill_src).convert("RGBA")
def cell(i, j):
    return placed(clear_bg(b.crop((17 * i, 17 * j, 17 * i + 17, 17 * j + 16)), (255, 255, 255)))
def side(i):
    return ImageOps.mirror(cell(i, 0))
column([cell(0, 2), cell(0, 3), side(0),
        cell(1, 2), cell(3, 2), cell(1, 3), cell(3, 3), side(1), side(3)]).save(dest + "/badassbill.png")

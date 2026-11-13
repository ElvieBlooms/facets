# Builds assets/clefairy/rahtak.png and badassbill.png: Clefairy walking
# sheets in the 9-frame column Facets' partner looks use (32x32 frames:
# down, up and left standing, then each one's two steps), with the
# sprite's feet on row 29 like HeartGold's.
# python3 tools/make_clefairy_looks.py <rahtak sheet> <badassbill sheet> assets/clefairy -Elvie
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

rahtak_src, bill_src, dest = sys.argv[1], sys.argv[2], sys.argv[3]

# Rahtak: six 32x32 frames on a flat green: down, down step, up, up step,
# left, left step. The second step is the first mirrored (down and up), or
# the standing frame lifted a pixel (left) -Elvie
r = Image.open(rahtak_src).convert("RGBA")
bg = r.getpixel((0, 0))[:3]
r = clear_bg(r, bg)
f = [placed(r.crop((32 * i, 0, 32 * i + 32, 32))) for i in range(6)]
ds, us, ls = f[1], f[3], f[5]
column([f[0], f[2], f[4], ds, ImageOps.mirror(ds), us, ImageOps.mirror(us), ls,
        placed(r.crop((128, 0, 160, 32)), lift=1)]).save(dest + "/rahtak.png")

# Badassbill: a 4x4 grid of 17x17 cells on white (left, left again, down,
# up), each row stand, step, stand, step -Elvie
b = Image.open(bill_src).convert("RGBA")
def cell(i, j):
    return placed(clear_bg(b.crop((17 * i, 17 * j, 17 * i + 17, 17 * j + 16)), (255, 255, 255)))
column([cell(0, 2), cell(0, 3), cell(0, 0),
        cell(1, 2), cell(3, 2), cell(1, 3), cell(3, 3), cell(1, 0), cell(3, 0)]).save(dest + "/badassbill.png")

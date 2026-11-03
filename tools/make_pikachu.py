#!/usr/bin/env python3
"""Yellow's Pikachu looks, from the artists' DeviantArt sheets.

Turns each overworld sheet into a Facets sheet: nine 32x32 frames, top to
bottom, in Gen 3's order (stand down, up, left, then two steps each), the
Pikachu centred with its feet on row 30 and each step a pixel up, unless
the sheet draws its own bob. Writes assets/pikachu/<key>.png;
assets/pikachu/meta.json keeps the labels and credits. -Elvie

Sheets are found by their DeviantArt file names (any extension), in the
folder given. They come at 1x or 2x, on see-through or a flat colour, and
in two layouts:
  rpgmaker: rows down, left, right, up; four frames each (stand, step,
            stand, step)
  follower: rows up, down, left[, right]; two frames each (stand, step)

    python3 tools/make_pikachu.py <folder with the sheets> [facets folder]
"""
import glob
import os
import sys
from math import gcd

from PIL import Image

LOOKS = [
    ("hat", "pikachu_hat_by_vitorluiscolnago_dldja39", "rpgmaker"),
    ("belle", "cosplay_pikachu_bella_form_overworld_sprite_sheet_by_piphybuilder88_d9kehd8", "follower"),
    # the rockstar and libre files hold each other's costume (Rock Star's
    # red and black jacket, Libre's orange suit), so they're crossed here -Elvie
    ("rock_star", "cosplay_pikachu_libre_form_overworld_sprite_sheet_by_piphybuilder88_d9kehrf", "follower"),
    ("phd", "cosplay_pikachu_p_h_d_form_overworld_sprite_sheet_by_piphybuilder88_d9kehwz", "follower"),
    ("pop_star", "cosplay_pikachu_popstar_form_overworld_sprites_by_piphybuilder88_d9kei19", "follower"),
    ("libre", "cosplay_pikachu_rockstar_form_overworld_sprites_by_piphybuilder88_d9kei63", "follower"),
    ("cosplay", "cosplay_pikachu_overworld_sprites_by_piphybuilder88_d9k2ofj", "follower"),
]

# (row, column) for Gen 3's nine frames: stand down, up, left, then
# down step, down step, up step, up step, left step, left step -Elvie
FRAMES = {
    "rpgmaker": [(0, 0), (3, 0), (1, 0), (0, 1), (0, 3), (3, 1), (3, 3), (1, 1), (1, 3)],
    "follower": [(1, 0), (0, 0), (2, 0), (1, 1), (1, 1), (0, 1), (0, 1), (2, 1), (2, 1)],
}
FEET = 30


def pixel_scale(im):
    """1 or 2: the size of the art's pixels, from horizontal runs."""
    px, (w, h), g = im.load(), im.size, 0
    for y in range(0, h, 3):
        run = 1
        for x in range(1, w):
            if px[x, y] == px[x - 1, y]:
                run += 1
            else:
                g, run = gcd(g, run), 1
    return 2 if g and g % 2 == 0 else 1


def load(path):
    """The sheet at 1x, its flat background (if any) see-through."""
    im = Image.open(path).convert("RGBA")
    if pixel_scale(im) == 2:
        im = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    bg = im.getpixel((0, 0))
    if bg[3] > 0:
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                if px[x, y] == bg:
                    px[x, y] = (0, 0, 0, 0)
    return im


def sprites(im):
    """Each sprite's box, in rows top to bottom, each row left to right."""
    w, h = im.size
    px, seen, boxes = im.load(), set(), []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 or (x, y) in seen:
                continue
            stack, box = [(x, y)], [x, y, x, y]
            seen.add((x, y))
            while stack:
                a, b = stack.pop()
                box = [min(box[0], a), min(box[1], b), max(box[2], a), max(box[3], b)]
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        c, d = a + dx, b + dy
                        if 0 <= c < w and 0 <= d < h and (c, d) not in seen and px[c, d][3] > 0:
                            seen.add((c, d))
                            stack.append((c, d))
            if (box[2] - box[0] + 1) * (box[3] - box[1] + 1) >= 20:
                boxes.append(box)
    boxes.sort(key=lambda b: ((b[1] + b[3]) / 2, b[0]))
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        if rows and abs(rows[-1][0] - cy) < 8:
            rows[-1][1].append(b)
        else:
            rows.append([cy, [b]])
    return [sorted(r[1]) for r in rows]


def convert(path, layout):
    im = load(path)
    rows = sprites(im)
    out = Image.new("RGBA", (32, 32 * 9), (0, 0, 0, 0))
    for i, (r, c) in enumerate(FRAMES[layout]):
        b = rows[r][c]
        art = im.crop((b[0], b[1], b[2] + 1, b[3] + 1))
        if art.width > 32 or art.height > FEET + 1:
            raise SystemExit(f"{path}: frame {r},{c} is {art.size}, too big for 32x32")
        # the row's own feet line, so a sheet's walking bob stays; a sheet
        # with none drawn gets one: each step a pixel up, as the
        # follower's walk bounces -Elvie
        bottoms = [box[3] for box in rows[r]]
        drop = max(bottoms) - b[3]
        if len(set(bottoms)) == 1 and i >= 3:
            drop += 1
        out.alpha_composite(art, ((32 - art.width) // 2, i * 32 + FEET + 1 - drop - art.height))
    return out


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    src = sys.argv[1]
    facets = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..")
    dest = os.path.join(facets, "assets", "pikachu")
    os.makedirs(dest, exist_ok=True)
    done = 0
    for key, name, layout in LOOKS:
        found = glob.glob(os.path.join(src, name + ".*"))
        if not found:
            print(f"missing: {name}")
            continue
        convert(found[0], layout).save(os.path.join(dest, key + ".png"), optimize=True)
        done += 1
    print(f"{done} of {len(LOOKS)} looks")


if __name__ == "__main__":
    main()

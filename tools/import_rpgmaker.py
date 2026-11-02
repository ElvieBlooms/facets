#!/usr/bin/env python3
"""An RPG Maker or Gen 3 overworld sheet as a Facets sheet, for the Game Boy games.

RPG Maker sheets are four rows (down, left, right, up) of four frames
(stand, step, stand, step), at 1x or 2x, on see-through or a flat colour.
A Gen 3 strip (nine frames side by side, already in Gen 3's order) works
too.
The Facets sheet is nine 32x32 frames, top to bottom, in Gen 3's order
(stand down, up, left, then two steps each). Each cell keeps its place in
the grid, so a sheet's own walking bob stays, and the standing frames'
feet go on row 30. -Elvie

    python3 tools/import_rpgmaker.py <sheet.png> <NAME> <out folder>

writes <out folder>/<NAME>.png, NAME being the Game Boy sprite's
(JESSIE for SPRITE_JESSIE).
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_pikachu import load  # noqa: E402  (1x, flat background see-through)

# (row, column) for Gen 3's nine frames -Elvie
FRAMES = [(0, 0), (3, 0), (1, 0), (0, 1), (0, 3), (3, 1), (3, 3), (1, 1), (1, 3)]
FEET = 30


def strip(im):
    """Nine frames side by side -> stacked, centred, bottoms kept."""
    fw = im.width // 9
    out = Image.new("RGBA", (32, 32 * 9), (0, 0, 0, 0))
    for i in range(9):
        cell = im.crop((i * fw, 0, i * fw + fw, im.height))
        if cell.height > 32:
            cell = cell.crop((0, cell.height - 32, fw, cell.height))
        out.alpha_composite(cell, ((32 - fw) // 2, i * 32 + 32 - cell.height))
    return out


def convert(path):
    im = load(path)
    if im.width == 9 * (im.width // 9) and im.width // 9 <= 32 and im.width >= 2 * im.height:
        return strip(im)
    cw, ch = im.width // 4, im.height // 4
    if cw > 32:
        raise SystemExit(f"{path}: cells are {cw} wide, more than 32")
    # the standing frames' feet line, across the sheet -Elvie
    feet = max(im.crop((0, r * ch, cw, r * ch + ch)).getbbox()[3] for r in range(4))
    out = Image.new("RGBA", (32, 32 * 9), (0, 0, 0, 0))
    for i, (r, c) in enumerate(FRAMES):
        cell = im.crop((c * cw, r * ch, c * cw + cw, r * ch + ch))
        top = FEET + 1 - feet
        if top < 0:
            cell = cell.crop((0, -top, cw, ch))
            top = 0
        out.alpha_composite(cell, ((32 - cw) // 2, i * 32 + top))
    return out


def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    path, name, dest = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(dest, exist_ok=True)
    convert(path).save(os.path.join(dest, name + ".png"), optimize=True)
    print(f"{name}.png")


if __name__ == "__main__":
    main()

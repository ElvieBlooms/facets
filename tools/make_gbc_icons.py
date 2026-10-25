#!/usr/bin/env python3
"""Cuts GBC-style party icons from a sheet into the GBC Pokémon set
(assets/mons/gbcish/icons/NNN.png, shared by GBC-ISH and GBC ANIM). Pokémon without one (the egg, and any
the sheets miss) still get Crystal's own from the player's install.

  python3 make_gbc_icons.py <recipe.json> <sheet.png or .gif> <mod folder>

Each icon is two 16x16 frames, one above the other (16x32), like
Crystal's. A recipe's "frames" says where the second frame is: "rows"
(the row under the first) or "gif" (the same cell in the GIF's second
frame). The background joined to a cell's edge becomes see-through;
background inside the outline becomes "inside" (white). Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image


def clear_outside(cell, white, inside=None):
    w, h = cell.size
    px = cell.load()
    outside, stack = set(), [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or px[x, y][:3] != white:
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if (x, y) not in outside:
                c = px[x, y][:3]
                o[x, y] = (inside if inside and c == white else c) + (255,)
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    recipe = json.load(open(sys.argv[1]))
    source = Image.open(sys.argv[2])
    pages = []
    for i in range(getattr(source, "n_frames", 1)):
        source.seek(i)
        pages.append(source.convert("RGBA"))
    by_gif = recipe.get("frames", "rows") == "gif"
    if by_gif and len(pages) < 2:
        sys.exit("the recipe wants the GIF's second frame, but the sheet has only one")
    out_dir = os.path.join(sys.argv[3], "assets", "mons", recipe["set"], "icons")
    os.makedirs(out_dir, exist_ok=True)
    g = recipe["grid"]
    white = tuple(recipe.get("background", [255, 255, 255]))
    inside = tuple(recipe["inside"]) if recipe.get("inside") else None
    near = {tuple(k): tuple(v) for k, v in recipe.get("same_as", [])}
    size, pitch, cols = g["size"], g.get("pitch"), g["columns"]
    written = 0
    for run in recipe["runs"]:
        for i in range(run["count"]):
            row, col = divmod(i, cols)
            icon = Image.new("RGBA", (size, size * 2), (0, 0, 0, 0))
            for f in range(2):
                x = g["x0"] + col * g.get("pitch_x", pitch)
                if by_gif:
                    # both frames in the same cell, one per GIF frame -Elvie
                    y = g["y0"] + row * g.get("pitch_y", pitch)
                    cell = pages[f].crop((x, y, x + size, y + size))
                else:
                    # frame 1 on the run's row, frame 2 on the row under it -Elvie
                    y = g["y0"] + (row * 2 + f) * g.get("pitch_y", pitch)
                    cell = pages[0].crop((x, y, x + size, y + size))
                if near:
                    cell.putdata([near.get(p[:3], p[:3]) + (p[3],) for p in cell.getdata()])
                icon.paste(clear_outside(cell, white, inside), (0, f * size))
            icon.save(os.path.join(out_dir, "%03d.png" % (run["national"] + i)))
            written += 1
    print("wrote %d icons to %s" % (written, out_dir))


if __name__ == "__main__":
    main()

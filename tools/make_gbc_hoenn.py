#!/usr/bin/env python3
"""Cuts GBC-style Pokémon sprites from a compilation sheet into the GBC
Pokémon set (assets/mons/gbc/front|back/NNN.png), for what the Game Boy
games never had: Hoenn, Castform's and Deoxys's forms, Unown ! and ?.

  python3 make_gbc_hoenn.py <recipe.json> <sheet.png> <mod folder>

Cells are white inside; the white joined to a cell's edge becomes
see-through, white inside the outline stays. Each sprite goes at the
bottom-centre of a 64x64 picture (Facets stands it on the game's
ground line anyway). Sprites the player's own Crystal has (Kanto, Johto,
Unown A-Z) still come from there. Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image


def clear_outside(cell, bg):
    w, h = cell.size
    px = cell.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    outside = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or px[x, y][:3] not in bg:
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for y in range(h):
        for x in range(w):
            if (x, y) not in outside:
                o[x, y] = px[x, y][:3] + (255,)
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    recipe, sheet, mod_dir = sys.argv[1:]
    r = json.load(open(recipe, encoding="utf-8"))
    g = r["grid"]
    im = Image.open(sheet).convert("RGB")

    def cut(panel, index):
        row, col = divmod(index, 12)
        x = g["x0"] + panel * g["panel"] + col * g["pitch"]
        y = g["y0"] + row * g["pitch"]
        # Big sprites spill over the white onto the cell's coloured frame,
        # so the frame is cut too and its colour counts as outside. -Elvie
        m = g["frame"]
        crop = im.crop((x - m, y - m, x + g["size"] + m, y + g["size"] + m))
        return clear_outside(crop, {(255, 255, 255), crop.getpixel((0, 0))[:3]}), m

    jobs = []
    for run in r["runs"]:
        for i in range(run["count"]):
            jobs.append((run["panel"], run["cell"] + 2 * i, f"{run['national'] + i:03d}"))
    for c in r["cells"]:
        jobs.append((c["panel"], c["cell"], c["name"]))
    set_dir = os.path.join(mod_dir, "assets", "mons", r["set"])
    written = 0
    for panel, index, name in jobs:
        for kind, k in (("front", 0), ("back", 1)):
            sprite, m = cut(panel, index + k)
            box = sprite.getbbox()
            if not box:
                sys.exit(f"{name} {kind}: empty cell (panel {panel}, cell {index + k}); check the grid")
            sprite = sprite.crop(box)
            if sprite.width > 64 or sprite.height > 64:
                sys.exit(f"{name} {kind}: {sprite.width}x{sprite.height} won't fit 64x64")
            # centred, feet on the bottom row -Elvie
            pic = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            pic.alpha_composite(sprite, ((64 - sprite.width) // 2, 64 - sprite.height))
            os.makedirs(os.path.join(set_dir, kind), exist_ok=True)
            pic.save(os.path.join(set_dir, kind, name + ".png"))
            written += 1
    meta_path = os.path.join(set_dir, "meta.json")
    meta = json.load(open(meta_path, encoding="utf-8"))
    if r["credit"] not in meta.get("credit", []):
        meta.setdefault("credit", []).append(r["credit"])
    json.dump(meta, open(meta_path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    open(meta_path, "a").write("\n")
    print(f"wrote {written} pictures to {set_dir}")


if __name__ == "__main__":
    main()

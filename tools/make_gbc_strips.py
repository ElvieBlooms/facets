#!/usr/bin/env python3
"""Builds GBC strips (assets/npcs/gbc/strips/) from Game Boy-style
Essentials charsets, and adds them to the GBC set's gb.json. A strip is
what Game Boy games store: 16x16 frames stacked, stand down, up, left, then
walk down, up, left, in the sheet's own colours. GBC draws strips the same
way as the sprites it reads from the player's install, at 1x or 2x.

  python3 make_gbc_strips.py <recipe.json> <pack folder> <mod folder>

The recipe (recipes/gbc_strips.json) lists the strips and which NPC each
one stands in for. Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import npc_convert as C

# Crystal's daytime NPC palettes, colours 1-3 (same as gb.lua). -Elvie
PALETTES = {
    "PAL_OW_RED": [(255, 156, 82), (255, 58, 8), (0, 0, 0)],
    "PAL_OW_BLUE": [(255, 156, 82), (82, 74, 255), (0, 0, 0)],
    "PAL_OW_GREEN": [(255, 156, 82), (58, 189, 25), (0, 0, 0)],
    "PAL_OW_BROWN": [(255, 156, 82), (123, 82, 25), (0, 0, 0)],
    "PAL_OW_PINK": [(255, 156, 82), (247, 82, 49), (0, 0, 0)],
}
# Charset cells (row, column) for each strip frame. Rows: down, left, right, up. -Elvie
CELLS = [(0, 0), (3, 0), (1, 0), (0, 1), (3, 1), (1, 1)]


def luminance(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def strip(path, recolor=None, sit=0):
    im = C.clear_background(Image.open(path))
    k = C.lossless_scale(im)
    if k > 1:
        im = im.resize((im.width // k, im.height // k), Image.NEAREST)
    cw, ch = im.width // 4, im.height // 4
    if cw != 16:
        C.fail(f"{path}: cells are {cw} wide after shrinking; a Game Boy sprite is 16")
    frames = CELLS[:3] if sit else CELLS
    # The sprite's 16 rows end at the sheet's lowest drawn row: the pack
    # draws at the top of its 16x20 cells. -Elvie
    cells = [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r, c in frames]
    boxes = [b for b in (x.getbbox() for x in cells) if b]
    if len(boxes) < len(cells):
        C.fail(f"{path}: an empty frame")
    bottom = max(16, max(b[3] for b in boxes))
    out = Image.new("RGBA", (16, 16 * len(frames)), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sprite = cell.crop((0, bottom - 16, 16, bottom))
        if bottom > 16 and cell.crop((0, 0, 16, bottom - 16)).getbbox():
            C.fail(f"{path}: frame {i} is taller than 16")
        if sit:
            body = sprite.crop((0, 0, 16, 16 - sit))   # legs off, set down on the ground
            sprite = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            sprite.alpha_composite(body, (0, sit))
        out.alpha_composite(sprite, (0, i * 16))
    if recolor:
        pal = PALETTES[recolor]
        colours = sorted({p[:3] for p in C.pixels(out) if p[3]}, key=luminance)
        # darkest is colour 3 (black), then 2, then 1 (skin) -Elvie
        target = {col: pal[2 - min(i, 2)] for i, col in enumerate(colours)} if len(colours) <= 3 else None
        if target is None:
            C.fail(f"{path}: {len(colours)} colours; a recolour needs 3 or fewer")
        out.putdata([target[p[:3]] + (255,) if p[3] else p for p in C.pixels(out)])
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    recipe_path, pack, mod_dir = sys.argv[1:]
    recipe = json.load(open(recipe_path))
    set_dir = os.path.join(mod_dir, "assets", "npcs", "gbc")
    strips_dir = os.path.join(set_dir, "strips")
    os.makedirs(strips_dir, exist_ok=True)
    for name, e in recipe["strips"].items():
        f = e["file"] + ("" if e.get("variant", "-") == "-" else "_" + e["variant"]) + ".png"
        strip(os.path.join(pack, f), e.get("recolor"), int(e.get("sit", 0))).save(os.path.join(strips_dir, name + ".png"))
    gbjson = os.path.join(set_dir, "gb.json")
    m = json.load(open(gbjson))
    added = 0
    for fam in ("frlg", "rse"):
        for npc, name in (recipe.get(fam) or {}).items():
            if npc in m[fam] and "strip" not in m[fam][npc]:
                continue          # a sprite from the player's games wins
            m[fam][npc] = {"strip": name}
            added += 1
    json.dump(m, open(gbjson, "w"), indent=2)
    print(f"wrote {len(recipe['strips'])} strips to {strips_dir}; {added} NPCs use them")


if __name__ == "__main__":
    main()

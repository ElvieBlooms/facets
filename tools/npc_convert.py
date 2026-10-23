#!/usr/bin/env python3
"""Facets converter: Pokemon Essentials charsets (4x4: rows down, left,
right, up; columns stand, step, stand, step) to Facets sheets (frames
stacked in pret's ANIM_STD order). Run it on your own copy of a sprite
pack; the art never goes in the mod's repo or release. -Elvie

one     Convert one charset into a set folder:
          python3 npc_convert.py one 123.png <mod folder> --set hgss --family frlg --name NURSE
        --extra bow.png adds a hand-drawn frame 9 (the nurse's bow, or an
        FR/LG trainer's VS Seeker hand raise), the same size as one frame.
        --cells picks the cell for each frame when a sheet isn't laid out
        the usual way (some packs draw a bow into the charset).

recipe  Convert a whole pack from a recipe (see recipes/example.json):
          python3 npc_convert.py recipe hgss.json <pack folder> <mod folder>

Upscaled packs (each pixel drawn as 2x2) are shrunk back first, only when
that loses nothing. The feet are moved to the second-to-last row, where
the game's own NPCs stand. Needs Pillow (python3 -m pip install --user pillow).
"""
import argparse, json, os, sys
from PIL import Image

# (row, column) of the charset for each ANIM_STD frame. Rows: 0 down,
# 1 left, 2 right, 3 up. The right row isn't used: the game mirrors left.
# -Elvie
ORDER = [(0, 0), (3, 0), (1, 0),   # stand down, up, left
         (0, 1), (0, 3),           # walk down
         (3, 1), (3, 3),           # walk up
         (1, 1), (1, 3)]           # walk left
FRAME = 32  # Facets frame size for DS-style art


def fail(msg):
    raise SystemExit("npc_convert: " + msg)


def pixels(im):
    # Pillow 12 renamed getdata; use whichever this Pillow has. -Elvie
    f = getattr(im, "get_flattened_data", None)
    return f() if f else im.getdata()


def clear_background(im):
    """Charsets without transparency use a flat backdrop: the top-left
    pixel's colour, made clear wherever it appears. -Elvie"""
    im = im.convert("RGBA")
    if any(p[3] < 255 for p in pixels(im)):
        return im
    key = im.getpixel((0, 0))[:3]
    im.putdata([(0, 0, 0, 0) if p[:3] == key else p for p in pixels(im)])
    return im


def lossless_scale(im):
    """The biggest factor (4, 3 or 2) by which every block of pixels is one
    colour, so shrinking by it loses nothing; 1 if none. -Elvie"""
    w, h = im.size
    px = im.load()
    for k in (4, 3, 2):
        if w % (4 * k) or h % (4 * k):
            continue
        if all(px[x, y] == px[x - x % k, y - y % k] for y in range(h) for x in range(w)):
            return k
    return 1


def lowest_row(im):
    bbox = im.getbbox()
    return None if bbox is None else bbox[3] - 1


def convert(path, extra=None, order=None):
    """order: (row, column) for each frame, instead of ORDER, for a sheet
    laid out its own way; a 10th entry is frame 9 taken from the sheet
    (a bow drawn into the charset). -Elvie"""
    order = [tuple(rc) for rc in order] if order else ORDER
    if len(order) not in (9, 10) or any(len(rc) != 2 or not all(0 <= v < 4 for v in rc) for rc in order):
        fail(f"{path}: cells must list 9 or 10 [row, column] pairs, each 0-3")
    if extra and len(order) == 10:
        fail(f"{path}: frame 9 given twice (a 10th cell and --extra)")
    im = clear_background(Image.open(path))
    w, h = im.size
    if w % 4 or h % 4:
        fail(f"{path} is {w}x{h}; a 4x4 charset divides into 4 columns and 4 rows")
    k = lossless_scale(im)
    if k > 1:
        im = im.resize((w // k, h // k), Image.NEAREST)
    cw, ch = im.size[0] // 4, im.size[1] // 4
    if cw > FRAME or ch > FRAME:
        fail(f"{path}: frames are {cw}x{ch} after shrinking by {k}; Facets takes up to {FRAME}x{FRAME}")
    cells = [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r, c in order]
    if extra:
        e = clear_background(Image.open(extra))
        if e.size != (cw, ch) and e.size != (FRAME, FRAME):
            fail(f"{extra} is {e.size[0]}x{e.size[1]}; frame 9 should be {cw}x{ch}")
        cells.append(e)

    # Same feet row for every frame, taken from standing facing down. -Elvie
    low = lowest_row(cells[0])
    if low is None:
        fail(f"{path}: the standing-down frame is empty")
    out = Image.new("RGBA", (FRAME, FRAME * len(cells)), (0, 0, 0, 0))
    clipped = False
    for i, cell in enumerate(cells):
        dx = (FRAME - cell.size[0]) // 2
        # A hand-drawn frame 9 lines up by its own feet. -Elvie
        own = lowest_row(cell) if i >= 9 else low
        dy = (FRAME - 2) - (own if own is not None else low)
        bbox = cell.getbbox()
        if bbox and (bbox[1] + dy < 0 or bbox[3] + dy > FRAME):
            clipped = True
        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        frame.alpha_composite(cell, (dx, dy)) if dy >= 0 else frame.alpha_composite(cell.crop((0, -dy, cell.size[0], cell.size[1])), (dx, 0))
        out.alpha_composite(frame, (0, i * FRAME))
    if clipped:
        print(f"warning: {path}: some pixels fell outside the frame after lining up the feet")
    return out, k


def write(out, mod_dir, set_key, family, name):
    d = os.path.join(mod_dir, "assets", "npcs", set_key, "gen3", family)
    os.makedirs(d, exist_ok=True)
    dest = os.path.join(d, name.upper() + ".png")
    out.save(dest)
    return dest


def ensure_meta(mod_dir, set_key, label=None, credit=None):
    path = os.path.join(mod_dir, "assets", "npcs", set_key, "meta.json")
    meta = {}
    if os.path.exists(path):
        with open(path) as f:
            meta = json.load(f)
    meta.setdefault("label", label or set_key.upper())
    if credit:
        meta["credit"] = credit
    meta.setdefault("credit", [])
    with open(path, "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")


def find_in_pack(pack, ref):
    for cand in (ref, ref + ".png"):
        p = os.path.join(pack, cand)
        if os.path.isfile(p):
            return p
    fail(f"{ref} not found in {pack}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    one = sub.add_parser("one")
    one.add_argument("charset")
    one.add_argument("mod_dir")
    one.add_argument("--set", required=True, dest="set_key")
    one.add_argument("--family", required=True, choices=["frlg", "rse"])
    one.add_argument("--name", required=True, help="the game's sprite name, e.g. NURSE")
    one.add_argument("--extra", help="frame 9 (bow or hand raise)")
    one.add_argument("--cells", help="row,column per frame for a sheet laid out its own way, e.g. \"0,2 3,0 1,0 0,1 0,3 3,1 3,2 1,1 1,3 0,0\"")
    rec = sub.add_parser("recipe")
    rec.add_argument("recipe")
    rec.add_argument("pack")
    rec.add_argument("mod_dir")
    a = ap.parse_args()

    if a.cmd == "one":
        cells = [[int(v) for v in rc.split(",")] for rc in a.cells.split()] if a.cells else None
        out, k = convert(a.charset, a.extra, cells)
        dest = write(out, a.mod_dir, a.set_key, a.family, a.name)
        ensure_meta(a.mod_dir, a.set_key)
        print(f"{dest} ({out.size[1] // FRAME} frames, shrunk by {k})")
        return

    with open(a.recipe) as f:
        recipe = json.load(f)
    set_key = recipe.get("set") or fail("the recipe needs a \"set\" folder name")
    count = 0
    for family in ("frlg", "rse"):
        for name, ref in (recipe.get(family) or {}).items():
            if isinstance(ref, dict):
                src, extra, cells = ref.get("file"), ref.get("extra"), ref.get("cells")
            else:
                src, extra, cells = ref, None, None
            out, _ = convert(find_in_pack(a.pack, str(src)),
                             extra and find_in_pack(a.pack, str(extra)), cells)
            write(out, a.mod_dir, set_key, family, name)
            count += 1
    ensure_meta(a.mod_dir, set_key, recipe.get("label"), recipe.get("credit"))
    print(f"wrote {count} sheets to assets/npcs/{set_key}/")


if __name__ == "__main__":
    main()

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
        --lie-down makes a lying-down sprite (FR/LG's OLD_MAN_LYING_DOWN)
        from a standing charset: the standing frame turned on its side.
        --sit-down [ROWS] makes a sitting sprite (FR/LG's SITTING_BOY): the
        standing frames with ROWS of legs taken off, set on the ground.
        --down-only is for sheets with only the facing-down row drawn:
        every facing uses it (they look at the camera when they turn).

recipe  Convert a whole pack from a recipe (see recipes/example.json):
          python3 npc_convert.py recipe hgss.json <pack folder> <mod folder>

Upscaled packs (each pixel drawn as 2x2) are shrunk back first, only when
that loses nothing; a 2x sheet drawn a pixel off the even grid is found
and shrunk too, and one with a few touched-up pixels needs --lossy. The
feet are moved to the second-to-last row, where the game's own NPCs stand. Needs Pillow (python3 -m pip install --user pillow).
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


def shrink_2x(im, lossy=False):
    """For sheets that are 2x but not on the even grid: drawn a pixel off
    (some packs are), or with a few touched-up pixels. Tries the four
    grid offsets and keeps the one with the fewest mixed blocks. Mixed
    blocks take their most common colour, only when lossy is on.
    Returns (image, offset, mixed) or None. -Elvie"""
    w, h = im.size
    if w % 8 or h % 8:
        return None
    best = None
    for ox in (0, 1):
        for oy in (0, 1):
            # shift onto the grid; the pixel row/column that falls off the
            # edge is checked to be clear first
            shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            shifted.alpha_composite(im.crop((ox, oy, w, h)), (0, 0))
            lost = im.crop((0, 0, ox, h)).getbbox() if ox else None
            lost = lost or (im.crop((0, 0, w, oy)).getbbox() if oy else None)
            if lost:
                continue
            px = shifted.load()
            out = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
            opx = out.load()
            mixed = 0
            for y in range(0, h, 2):
                for x in range(0, w, 2):
                    block = [px[x, y], px[x + 1, y], px[x, y + 1], px[x + 1, y + 1]]
                    block = [(0, 0, 0, 0) if b[3] == 0 else b for b in block]
                    if block.count(block[0]) != 4:
                        mixed += 1
                        block.sort(key=block.count, reverse=True)
                    opx[x // 2, y // 2] = block[0]
            if best is None or mixed < best[2]:
                best = (out, (ox, oy), mixed)
    if best is None:
        return None
    if best[2] and not lossy:
        return ("mixed", best[1], best[2])
    return best


def lowest_row(im):
    bbox = im.getbbox()
    return None if bbox is None else bbox[3] - 1


def lie_down(out):
    """For sprites lying on the ground (FR/LG's old man in Viridian): the
    standing-down frame turned a quarter clockwise, head to the right, on
    the feet row, the same in all 9 frames like the game's own. -Elvie"""
    first = out.crop((0, 0, FRAME, FRAME))
    bbox = first.getbbox()
    if not bbox:
        fail("lie_down: the standing-down frame is empty")
    body = first.crop(bbox).transpose(Image.ROTATE_270)
    if body.size[0] > FRAME or body.size[1] > FRAME:
        fail(f"lie_down: lying down he's {body.size[0]}x{body.size[1]}, bigger than {FRAME}x{FRAME}")
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.alpha_composite(body, ((FRAME - body.size[0]) // 2, (FRAME - 1) - body.size[1]))
    lying = Image.new("RGBA", (FRAME, FRAME * 9), (0, 0, 0, 0))
    for i in range(9):
        lying.alpha_composite(frame, (0, i * FRAME))
    return lying


def sit_down(out, legs=2):
    """For sprites sitting on the floor (FR/LG's SITTING_BOY): each
    standing frame with the bottom `legs` rows of the body taken off and
    the rest set down on the feet row. Walking frames use the standing
    one of the same facing, since a sitting NPC only turns. -Elvie"""
    lying = Image.new("RGBA", (FRAME, FRAME * 9), (0, 0, 0, 0))
    stand = {0: 0, 1: 1, 2: 2, 3: 0, 4: 0, 5: 1, 6: 1, 7: 2, 8: 2}
    for i in range(9):
        f = out.crop((0, stand[i] * FRAME, FRAME, stand[i] * FRAME + FRAME))
        bbox = f.getbbox()
        if not bbox:
            continue
        top = f.crop((0, 0, FRAME, bbox[3] - legs))
        lying.alpha_composite(top, (0, i * FRAME + legs))
    return lying


# For sheets with only the facing-down row drawn: every facing uses it. -Elvie
DOWN_ONLY = [(0, 0), (0, 0), (0, 0), (0, 1), (0, 3), (0, 1), (0, 3), (0, 1), (0, 3)]
POSES = ["standing down", "standing up", "standing left", "walking down", "walking down",
         "walking up", "walking up", "walking left", "walking left", "frame 9"]


def convert(path, extra=None, order=None, lossy=False, down_only=False):
    """order: (row, column) for each frame, instead of ORDER, for a sheet
    laid out its own way; a 10th entry is frame 9 taken from the sheet
    (a bow drawn into the charset). down_only: the sheet only has its
    facing-down row, so every frame comes from it. -Elvie"""
    if down_only and order:
        fail(f"{path}: give cells or down_only, not both")
    order = [tuple(rc) for rc in order] if order else (DOWN_ONLY if down_only else ORDER)
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
    elif w // 4 > FRAME or h // 4 > FRAME:
        shrunk = shrink_2x(im, lossy)
        if shrunk and shrunk[0] == "mixed":
            fail(f"{path}: looks 2x (grid offset {shrunk[1]}) but {shrunk[2]} blocks of 2x2 pixels "
                 "aren't one colour; --lossy (or \"lossy\": true in a recipe) shrinks it anyway, "
                 "each block taking its most common colour")
        if shrunk:
            im, offset, mixed = shrunk
            k = 2
            if offset != (0, 0) or mixed:
                print(f"note: {path}: shrunk from grid offset {offset}"
                      + (f", {mixed} mixed blocks settled by their most common colour" if mixed else ""))
    cw, ch = im.size[0] // 4, im.size[1] // 4
    if cw > FRAME or ch > FRAME:
        fail(f"{path}: frames are {cw}x{ch} after shrinking by {k}; Facets takes up to {FRAME}x{FRAME}")
    cells = [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r, c in order]
    for i, cell in enumerate(cells):
        if not cell.getbbox():
            r, c = order[i]
            fail(f"{path}: frame {i} ({POSES[i]}, row {r} column {c} of the sheet) is empty"
                 + ("; if only the facing-down row is drawn, --down-only (\"down_only\": true in a recipe) uses it for every facing"
                    if r else ""))
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

    # How far a group of frames can move without losing a pixel: some
    # sheets step lower when walking than when standing, so their feet go
    # as near row 30 as fits. -Elvie
    def fit(dy, group):
        boxes = [c.getbbox() for c in group if c.getbbox()]
        lo = max([-b[1] for b in boxes] or [dy])
        hi = min([FRAME - b[3] for b in boxes] or [dy])
        return max(lo, min(hi, dy)) if lo <= hi else dy
    shared = fit((FRAME - 2) - low, cells[:9])
    if shared != (FRAME - 2) - low:
        print(f"note: {path}: feet put on row {low + shared} instead of {FRAME - 2}, so no frame loses pixels")
    clipped = False
    for i, cell in enumerate(cells):
        dx = (FRAME - cell.size[0]) // 2
        # A hand-drawn frame 9 lines up by its own feet. -Elvie
        if i >= 9:
            own = lowest_row(cell)
            dy = fit((FRAME - 2) - (own if own is not None else low), [cell])
        else:
            dy = shared
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
    one.add_argument("--lie-down", action="store_true", help="a lying-down sprite from the standing-down frame, turned on its side")
    one.add_argument("--sit-down", type=int, nargs="?", const=2, metavar="ROWS", help="a sitting sprite from the standing frames: ROWS of legs taken off (default 2)")
    one.add_argument("--down-only", action="store_true", help="the sheet only has its facing-down row; use it for every facing")
    one.add_argument("--lossy", action="store_true", help="shrink a near-2x sheet even if some 2x2 blocks are mixed")
    one.add_argument("--cells", help="row,column per frame for a sheet laid out its own way, e.g. \"0,2 3,0 1,0 0,1 0,3 3,1 3,2 1,1 1,3 0,0\"")
    rec = sub.add_parser("recipe")
    rec.add_argument("recipe")
    rec.add_argument("pack")
    rec.add_argument("mod_dir")
    a = ap.parse_args()

    if a.cmd == "one":
        cells = [[int(v) for v in rc.split(",")] for rc in a.cells.split()] if a.cells else None
        out, k = convert(a.charset, a.extra, cells, a.lossy, a.down_only)
        if a.lie_down:
            out = lie_down(out)
        if a.sit_down:
            out = sit_down(out, a.sit_down)
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
                src, extra, cells, lossy = ref.get("file"), ref.get("extra"), ref.get("cells"), ref.get("lossy")
            else:
                src, extra, cells, lossy = ref, None, None, False
            out, _ = convert(find_in_pack(a.pack, str(src)),
                             extra and find_in_pack(a.pack, str(extra)), cells, bool(lossy),
                             isinstance(ref, dict) and bool(ref.get("down_only")))
            if isinstance(ref, dict) and ref.get("lie_down"):
                out = lie_down(out)
            if isinstance(ref, dict) and ref.get("sit_down"):
                out = sit_down(out, int(ref["sit_down"]))
            write(out, a.mod_dir, set_key, family, name)
            count += 1
    ensure_meta(a.mod_dir, set_key, recipe.get("label"), recipe.get("credit"))
    print(f"wrote {count} sheets to assets/npcs/{set_key}/")


if __name__ == "__main__":
    main()

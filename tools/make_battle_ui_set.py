#!/usr/bin/env python3
"""Builds a Facets battle UI set (assets/battleui/<set>/) from a patch
that ips_extract.py pulled apart: the healthboxes, the HP and EXP bar
sheet and the battle text box, laid out exactly as the engine's own
importer lays out FireRed's (src/import/gba/battle_chrome_extract.lua),
so the engine draws them with its own code.

  python3 make_battle_ui_set.py <extracted/<patch> folder> <mod folder> <set> <LABEL> "<credit>"
      [--tilemap <textbox_map.bin>]

A piece whose picture the patch changed is baked to PNG. A piece whose
palette alone changed (HP bar recolours, plain text boxes) is written as
that palette, and Facets recolours the game's own picture with it while
you play. The palettes are kept either way: the game's text and fills on
the boxes take their colours from them. The battle text box's picture needs FireRed's own text box
map: pret's graphics/battle_interface/textbox.bin, fetched from GitHub
the first time (or given with --tilemap). Needs Pillow. -Elvie
"""
import json, os, sys, urllib.request
from PIL import Image

# FireRed's own palettes (pret's graphics/battle_interface), as GBA
# colours: what a palette-only patch's colours replace -Elvie
VANILLA = {
    "healthbox": [0, 8456, 28671, 23387, 15096, 16975, 12714, 228, 8519, 927, 19071, 32552, 31744, 992, 31, 32333],
    "healthbar": [0, 7399, 32767, 24378, 17936, 11529, 11690, 11103, 8927, 11707, 22510, 17227, 8095, 1721, 7551, 9493],
    "textbox": [0, 32767, 31, 19850, 24109, 32767, 14701, 27450, 15656, 6341, 31775, 29564, 31775, 3571, 9913, 13637],
}

TILEMAP_URL = "https://raw.githubusercontent.com/pret/pokefirered/master/graphics/battle_interface/textbox.bin"


def colours(raw, count=16):
    out = []
    for i in range(count):
        c = int.from_bytes(raw[i * 2:i * 2 + 2], "little") if i * 2 + 2 <= len(raw) else 0
        out.append(c & 0x7FFF)
    return out


def rgb(c):
    return tuple(round((c >> s & 31) * 255 / 31) for s in (0, 5, 10))


def tile_pixels(gfx, ti):
    base = ti * 32
    px = []
    for row in range(8):
        r = []
        for bx in range(4):
            b = gfx[base + row * 4 + bx] if base + row * 4 + bx < len(gfx) else 0
            r += [b & 15, b >> 4]
        px.append(r)
    return px


def blit(gfx, pal, start, tw, th, img, dx, dy):
    """GBA OAM: tw x th tiles, row-major from tile start. -Elvie"""
    count = len(gfx) // 32
    px = img.load()
    for ty in range(th):
        for tx in range(tw):
            ti = start + ty * tw + tx
            if ti >= count:
                continue
            for y, row in enumerate(tile_pixels(gfx, ti)):
                for x, v in enumerate(row):
                    if v:
                        px[dx + tx * 8 + x, dy + ty * 8 + y] = rgb(pal[v]) + (255,)


def box(gfx, pal, tall):
    """Player and Safari: two 64x64 halves; enemy and doubles: 64x32. -Elvie"""
    if tall:
        img = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
        blit(gfx, pal, 0, 8, 8, img, 0, 0)
        blit(gfx, pal, 64, 8, 8, img, 64, 0)
    else:
        img = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
        blit(gfx, pal, 0, 8, 4, img, 0, 0)
        blit(gfx, pal, 32, 8, 4, img, 64, 0)
    return img


def sheet(gfx, pal, w=320, h=24):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    blit(gfx, pal, 0, w // 8, h // 8, img, 0, 0)
    return img


# FireRed's battle windows on the text box map (pokefirered/src/battle_bg.c):
# left, top, width, height in tiles. The game clears the message ones to
# the box's colour 15 before printing, so the picture under them never
# shows. -Elvie
MESSAGE_WINDOWS = [(1, 15, 28, 4), (1, 35, 14, 4)]
# The menu windows are cleared to the window palette's white, and the
# tiles in the second bank are the player's own window frame, loaded over
# them (LoadBattleMenuWindowGfx): neither is the patch's, so both are left
# clear and Facets draws the game's own under the set's. -Elvie
MENU_WINDOWS = [(17, 35, 12, 4), (2, 55, 8, 2), (11, 55, 8, 2), (2, 57, 8, 2), (11, 57, 8, 2),
                (21, 55, 3, 2), (21, 57, 8, 2), (24, 55, 5, 2)]


def keep_runs(tmap, tw=32, th=64):
    """The tiles where the game's own text box shows instead, as runs
    [x, y, width] in tiles. -Elvie"""
    keep = set()
    for ty in range(th):
        for tx in range(tw):
            i = (ty * tw + tx) * 2
            e = int.from_bytes(tmap[i:i + 2], "little") if i + 2 <= len(tmap) else 0
            if e >> 12 & 15:
                keep.add((tx, ty))
    for l, t, w, h in MENU_WINDOWS:
        keep |= {(x, y) for x in range(l, l + w) for y in range(t, t + h)}
    runs = []
    for ty in range(th):
        tx = 0
        while tx < tw:
            if (tx, ty) in keep:
                start = tx
                while tx < tw and (tx, ty) in keep:
                    tx += 1
                runs.append([start, ty, tx - start])
            else:
                tx += 1
    return runs


def tilemap_image(gfx, pal_raw, tmap, tw=32, th=64):
    bank = colours(pal_raw[:32])
    img = Image.new("RGBA", (tw * 8, th * 8), (0, 0, 0, 0))
    px = img.load()
    count = len(gfx) // 32
    for ty in range(th):
        for tx in range(tw):
            i = (ty * tw + tx) * 2
            e = int.from_bytes(tmap[i:i + 2], "little") if i + 2 <= len(tmap) else 0
            t, hf, vf, p = e & 0x3FF, e >> 10 & 1, e >> 11 & 1, e >> 12 & 15
            if p != 0:
                continue
            if t >= count:
                t = 0
            for y, row in enumerate(tile_pixels(gfx, t)):
                for x, v in enumerate(row):
                    if v:
                        px[tx * 8 + (7 - x if hf else x), ty * 8 + (7 - y if vf else y)] = rgb(bank[v]) + (255,)
    for rects, c in ((MESSAGE_WINDOWS, rgb(bank[15]) + (255,)), (MENU_WINDOWS, (0, 0, 0, 0))):
        for l, t, w, h in rects:
            for y in range(t * 8, (t + h) * 8):
                for x in range(l * 8, (l + w) * 8):
                    px[x, y] = c
    return img


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) < 5:
        sys.exit(__doc__)
    src, mod, key, label, credit = args[:5]
    tilemap_path = None
    if "--tilemap" in sys.argv:
        tilemap_path = sys.argv[sys.argv.index("--tilemap") + 1]
        args = [a for a in args if a != tilemap_path]

    def piece(name):
        for kind in ("battle_ui", "graphics", "windows_fonts", "other"):
            p = os.path.join(src, kind, name + ".bin")
            if os.path.exists(p):
                return open(p, "rb").read()
        return None

    out_dir = os.path.join(mod, "assets", "battleui", key)
    os.makedirs(out_dir, exist_ok=True)
    hb_pal_raw, bar_pal_raw = piece("gBattleInterface_Healthbox_Pal"), piece("gBattleInterface_Healthbar_Pal")
    meta = {"label": label, "credit": [credit], "images": {}, "palettes": {}}
    if hb_pal_raw:
        meta["palettes"]["healthbox"] = {"from": VANILLA["healthbox"], "to": colours(hb_pal_raw)}
    if bar_pal_raw:
        meta["palettes"]["healthbar"] = {"from": VANILLA["healthbar"], "to": colours(bar_pal_raw)}

    def need_pal(name):
        raw = {"healthbox": hb_pal_raw, "healthbar": bar_pal_raw}[name]
        if raw is None:
            sys.exit("%s changes a picture but not its palette; give the set the game's own "
                     "palette by hand, or leave the picture out" % src)
        return colours(raw)

    for name, sym, tall in (("healthbox_player", "gHealthboxSinglesPlayerGfx", True),
                            ("healthbox_enemy", "gHealthboxSinglesOpponentGfx", False),
                            ("healthbox_safari", "gHealthboxSafariGfx", True),
                            ("healthbox_doubles_player", "gHealthboxDoublesPlayerGfx", False),
                            ("healthbox_doubles_opponent", "gHealthboxDoublesOpponentGfx", False)):
        gfx = piece(sym)
        if gfx:
            box(gfx, need_pal("healthbox"), tall).save(os.path.join(out_dir, name + ".png"))
            meta["images"][name] = name + ".png"
    el = piece("gBattleInterface_Gfx")
    if el:
        sheet(el, need_pal("healthbar")).save(os.path.join(out_dir, "elements.png"))
        sheet(el, need_pal("healthbox")).save(os.path.join(out_dir, "elements_exp.png"))
        meta["images"]["elements"], meta["images"]["elements_exp"] = "elements.png", "elements_exp.png"
    tb_gfx, tb_pal = piece("gBattleInterface_Textbox_Gfx"), piece("gBattleInterface_Textbox_Pal")
    if tb_pal:
        # the message box's colours: the first bank -Elvie
        meta["palettes"]["textbox"] = {"from": VANILLA["textbox"], "to": colours(tb_pal[:32])}
    if tb_gfx:
        if not tilemap_path:
            tilemap_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textbox_map.bin")
            if not os.path.exists(tilemap_path):
                print("fetching FireRed's text box map once: " + TILEMAP_URL)
                with urllib.request.urlopen(TILEMAP_URL) as r, open(tilemap_path, "wb") as f:
                    f.write(r.read())
        if not tb_pal:
            sys.exit("%s changes the text box picture but not its palette" % src)
        tmap = open(tilemap_path, "rb").read()
        tilemap_image(tb_gfx, tb_pal, tmap).save(os.path.join(out_dir, "textbox.png"))
        meta["images"]["textbox"] = "textbox.png"
        meta["textboxKeep"] = keep_runs(tmap)
    with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("%s: %s%s -> %s" % (label, ", ".join(sorted(meta["images"])) or "no pictures",
                              (" + palettes " + ", ".join(sorted(meta["palettes"]))) if meta["palettes"] else "", out_dir))


if __name__ == "__main__":
    main()

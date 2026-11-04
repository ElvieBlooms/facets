"""A tileset patch's own art as plain files: what an extracted FireRed patch
(ips_extract.py's output) puts in, as tile sheets, palettes, 16x16 block
atlases, map layouts and previews. Any tile that is FireRed's own, and any
block or cell needing one, is left out and marked.

  python3 tileset_package.py <extracted/patch> <pokefirered layouts.json>
      <out folder> <your FireRed import: .../firered/data/generated/gba>

layouts.json is pret's pokefirered data/layouts/layouts.json. The FireRed
import is only read, to know FireRed's own tiles and maps."""
import json, os, struct, sys
from PIL import Image, ImageDraw

EXT, LAYOUTS, OUT, FR = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fr_tiles as frtiles
FR_TILES = frtiles.load(os.path.join(FR, "map_tree", "tilesets"))
FR_LAYOUTS = os.path.join(FR, "native", "layouts")
TS, MS = os.path.join(EXT, "tilesets"), os.path.join(EXT, "maps_scripts")
os.makedirs(OUT, exist_ok=True)
for d in ("tiles", "blocks", "maps", "previews"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)

def short(sym):  # gTileset_General -> General
    return sym.split("_", 1)[1]

def read(name):
    p = os.path.join(TS, name + ".bin")
    return open(p, "rb").read() if os.path.exists(p) else None

def palettes(name):
    b = read("gTilesetPalettes_" + name)
    if not b: return None
    out = []
    for i in range(16):
        pal = []
        for c in struct.unpack("<16H", b[i * 32:i * 32 + 32]):
            pal.append(((c & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31, ((c >> 10) & 31) * 255 // 31))
        out.append(pal)
    return out

def tiles(name):
    b = read("gTilesetTiles_" + name)
    if not b: return None
    out = []
    for t in range(len(b) // 32):
        raw = b[t * 32:t * 32 + 32]
        if raw in FR_TILES and not frtiles.plain(raw):
            out.append(None)  # FireRed's own tile: left out
            continue
        px = []
        for y in range(8):
            row = b[t * 32 + y * 4:t * 32 + y * 4 + 4]
            for byte in row:
                px += [byte & 15, byte >> 4]
        out.append(px)
    return out

def metatiles(name):
    b = read("gMetatiles_" + name)
    if not b: return None
    n = len(b) // 16
    return [struct.unpack("<8H", b[i * 16:i * 16 + 16]) for i in range(n)]

def attributes(name):
    b = read("gMetatileAttributes_" + name)
    if not b: return None
    return list(struct.unpack("<%dI" % (len(b) // 4), b))

PRIMARY_TILES = 640
PRIMARY_PALS = 7
layouts = [l for l in json.load(open(LAYOUTS))["layouts"]
           if l.get("primary_tileset", "NULL") != "NULL" and l.get("secondary_tileset", "NULL") != "NULL"]
by_name = {l["name"]: l for l in layouts if "name" in l}
cache = {}
def tileset(sym):
    if sym not in cache:
        n = short(sym)
        cache[sym] = {"name": n, "tiles": tiles(n), "pals": palettes(n), "metas": metatiles(n), "attrs": attributes(n)}
    return cache[sym]

def draw_block(entries, prim, sec):
    """A 16x16 RGBA block, or None when any of it is FireRed's own"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for layer in range(2):
        for q in range(4):
            e = entries[layer * 4 + q]
            t, hf, vf, p = e & 0x3FF, (e >> 10) & 1, (e >> 11) & 1, e >> 12
            if t < PRIMARY_TILES:
                tl = prim["tiles"]
            else:
                tl = sec["tiles"] if sec else None
                t -= PRIMARY_TILES
            pal = (prim["pals"] if p < PRIMARY_PALS else (sec["pals"] if sec else None))
            if tl is None or pal is None or t >= len(tl):
                return None
            tile, colours = tl[t], pal[p]
            if tile is None:
                return None
            ox, oy = (q % 2) * 8, (q // 2) * 8
            for y in range(8):
                for x in range(8):
                    c = tile[(7 - y if vf else y) * 8 + (7 - x if hf else x)]
                    if c == 0 and layer == 1: continue
                    if c == 0:
                        px[ox + x, oy + y] = prim["pals"][0][0] + (255,) if px[ox + x, oy + y][3] == 0 else px[ox + x, oy + y]
                        continue
                    px[ox + x, oy + y] = colours[c] + (255,)
    return img

# tiles, as the patch has them, in its first palette -Elvie
for f in sorted(os.listdir(TS)):
    if not (f.startswith("gTilesetTiles_") and f.endswith(".bin")): continue
    n = f[len("gTilesetTiles_"):-4]
    tl, pals = tiles(n), palettes(n)
    if not tl or all(t is None for t in tl): continue
    if not pals: pals = [[(i * 17,) * 3 for i in range(16)]] * 16
    pal = pals[0] if n in ("General", "Building") else pals[7]
    img = Image.new("RGBA", (128, (len(tl) + 15) // 16 * 8), (0, 0, 0, 0))
    for i, t in enumerate(tl):
        if t is None: continue
        for y in range(8):
            for x in range(8):
                img.putpixel(((i % 16) * 8 + x, (i // 16) * 8 + y), pal[t[y * 8 + x]])
    img.save(os.path.join(OUT, "tiles", n + ".png"))
    json.dump({"palettes": [["#%02x%02x%02x" % c for c in p] for p in pals]},
              open(os.path.join(OUT, "tiles", n + "_palettes.json"), "w"), indent=1)

block_imgs, report = {}, []
def block(prim_sym, sec_sym, bid):
    key = (prim_sym, sec_sym, bid)
    if key in block_imgs: return block_imgs[key]
    prim, sec = tileset(prim_sym), tileset(sec_sym)
    metas = prim["metas"] if bid < 640 else sec["metas"]
    i = bid if bid < 640 else bid - 640
    img = None
    if metas and i < len(metas) and prim["tiles"] and prim["pals"]:
        img = draw_block(metas[i], prim, sec if (sec["tiles"] or sec["pals"]) else None)
    block_imgs[key] = img
    return img

# blocks: one atlas per tileset the patch edited, 8 blocks across -Elvie
for sym in sorted({l["primary_tileset"] for l in layouts} | {l["secondary_tileset"] for l in layouts}):
    ts = tileset(sym)
    if not ts["metas"]: continue
    primary = ts["name"] in ("General", "Building")
    pairs = sorted({l["primary_tileset"] for l in layouts if l["secondary_tileset"] == sym}) if not primary else [sym]
    prim_sym = pairs[0] if pairs else "gTileset_General"
    n = len(ts["metas"])
    atlas = Image.new("RGBA", (8 * 16, (n + 7) // 8 * 16), (0, 0, 0, 0))
    info = []
    for i in range(n):
        bid = i if primary else 640 + i
        img = block(prim_sym, None if primary else sym, bid) if not primary else (
            draw_block(ts["metas"][i], ts, None))
        if img: atlas.paste(img, ((i % 8) * 16, (i // 8) * 16))
        info.append({"block": bid, "included": img is not None,
                     "behavior": (ts["attrs"][i] if ts["attrs"] and i < len(ts["attrs"]) else None)})
    atlas.save(os.path.join(OUT, "blocks", ts["name"] + ".png"))
    json.dump({"tileset": ts["name"], "primary": primary, "drawn_with": short(prim_sym),
               "blocks": info}, open(os.path.join(OUT, "blocks", ts["name"] + ".json"), "w"), indent=1)

# maps: the patch's own layouts, block by block -Elvie
hatch = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(hatch)
for k in range(-16, 16, 4): d.line([(k, 16), (k + 16, 0)], fill=(255, 0, 160, 255))
for f in sorted(os.listdir(MS)):
    if not f.endswith("_Blockdata.bin"): continue
    name = f[:-len("_Blockdata.bin")]
    lay = by_name.get(name)
    if not lay: continue
    w, h = lay["width"], lay["height"]
    if w * h == 0: continue
    b = open(os.path.join(MS, f), "rb").read()
    if len(b) < w * h * 2: continue
    cells = struct.unpack("<%dH" % (w * h), b[:w * h * 2])
    # a map the patch leaves as FireRed's is left out -Elvie
    fr_path = os.path.join(FR_LAYOUTS, lay["id"].replace("LAYOUT_", "FR_") + ".mid")
    if os.path.exists(fr_path):
        fb = open(fr_path, "rb").read()
        if fb[:4] == b"SVML" and len(fb) >= 24 + w * h * 4:
            ids = struct.unpack("<%dH" % (w * h * 2), fb[24:24 + w * h * 4])[0::2]
            if list(ids) == [v & 0x3FF for v in cells]:
                continue
    border = None
    bp = os.path.join(MS, name + "_Border.bin")
    if os.path.exists(bp):
        bb = open(bp, "rb").read(); border = [v & 0x3FF for v in struct.unpack("<%dH" % (len(bb) // 2), bb)]
    prim, sec = lay["primary_tileset"], lay["secondary_tileset"]
    img = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
    have = 0
    for i, v in enumerate(cells):
        bimg = block(prim, sec, v & 0x3FF)
        x, y = (i % w) * 16, (i // w) * 16
        if bimg: img.paste(bimg, (x, y)); have += 1
        else: img.paste(hatch, (x, y))
    if have == 0: continue
    img.save(os.path.join(OUT, "previews", name.replace("_Layout", "") + ".png"))
    json.dump({"layout": lay["id"], "name": name, "width": w, "height": h,
               "primary_tileset": short(prim), "secondary_tileset": short(sec),
               "blocks": [v & 0x3FF for v in cells],
               "collision": [(v >> 10) & 3 for v in cells],
               "elevation": [v >> 12 for v in cells],
               "border": border, "cells_from_the_patch": have},
              open(os.path.join(OUT, "maps", name.replace("_Layout", "") + ".json"), "w"))
    report.append((name.replace("_Layout", ""), w * h, have, short(prim), short(sec)))

with open(os.path.join(OUT, "coverage.md"), "w") as fp:
    fp.write("| Map | Cells | Drawn from the patch | Tilesets |\n|---|---|---|---|\n")
    for n, t, hv, p, s in sorted(report, key=lambda r: (-r[2] / max(1, r[1]), r[0])):
        fp.write(f"| {n} | {t} | {hv} ({100 * hv // max(1, t)}%) | {p} + {s} |\n")
full = sum(1 for r in report if r[1] == r[2])
print(len(report), "maps;", full, "drawn entirely from the patch")

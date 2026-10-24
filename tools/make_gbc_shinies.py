#!/usr/bin/env python3
"""Gives the GBC set's Hoenn sprites (from E-SY's sheet, which has no
shinies) shiny colours, worked out from pictures that come in a normal and
a shiny version with the same pixels:

  python3 make_gbc_shinies.py gen3 <gen1recomp install folder> <mod folder>
  python3 make_gbc_shinies.py ds <DS-style resource folder> <mod folder>

gen3 uses the games' own Gen 3 pictures (FireRed's, LeafGreen's and
Emerald's for the Deoxys forms), so each GBC shiny matches the shiny you'd
see in the game; that's how the shipped ones were made. ds uses a DS-style
resource's normal and shiny frames instead.

For each colour of a GBC sprite (white and black stay), the normal
picture's colours of about the same hue vote, by how many pixels they
cover, on what it becomes. Writes assets/mons/gbc/front_shiny and
back_shiny. Needs Pillow. -Elvie
"""
import collections, colorsys, math, os, sys
from PIL import Image

def load_internal(mod_dir):
    import json
    r = json.load(open(os.path.join(mod_dir, "tools", "recipes", "ds_mons.json"), encoding="utf-8"))
    return {v: int(k) for k, v in r["internal"].items()}  # national -> internal


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def shiny_colour(c, pairs):
    """pairs: Counter of (normal, shiny) pixel colours. Every normal colour
    of about c's hue (or, for a grey, about its brightness) votes, by how
    many pixels it covers, for how hue, saturation and brightness change;
    the result is applied to c. -Elvie"""
    hc, sc, vc = colorsys.rgb_to_hsv(*[x / 255 for x in c])
    grey = sc < 0.15
    vx = vy = 0.0; sat_r = val_r = wsum = 0.0; to_hue = [0.0, 0.0, 0.0]
    for (n, t), k in pairs.items():
        if not (20 <= lum(n) <= 235):
            continue
        hn, sn, vn = colorsys.rgb_to_hsv(*[x / 255 for x in n])
        ht, st, vt = colorsys.rgb_to_hsv(*[x / 255 for x in t])
        if grey:
            if sn >= 0.15 or abs(vn - vc) > 0.25:
                continue
        else:
            d = abs(hn - hc); d = min(d, 1 - d)
            if sn < 0.15 or d > 0.15:
                continue
        shift = (ht - hn) * 2 * math.pi
        vx += math.cos(shift) * k; vy += math.sin(shift) * k
        to_hue[0] += math.cos(ht * 2 * math.pi) * k * st; to_hue[1] += math.sin(ht * 2 * math.pi) * k * st
        to_hue[2] += st * k
        sat_r += (st / max(sn, 0.05) if not grey else 1.0) * k
        val_r += vt / max(vn, 0.05) * k
        wsum += k
    if wsum == 0:
        return c
    # c takes the hue its matches turn into (a grey stays grey unless they
    # turn coloured), and their change in saturation and brightness -Elvie
    if to_hue[2] / wsum >= 0.15:
        h = (math.atan2(to_hue[1], to_hue[0]) / (2 * math.pi)) % 1.0
        sat = min(1.0, (sc if not grey else to_hue[2] / wsum) * (sat_r / wsum if not grey else 1.0))
    else:
        h, sat = hc, min(sc, to_hue[2] / wsum)
    val = min(1.0, vc * val_r / wsum)
    return tuple(round(x * 255) for x in colorsys.hsv_to_rgb(h, sat, val))


def gen3_pair(install, game, kind, pic):
    import zlib
    base = os.path.join(install, game, "data", "generated", "gba", "pokemon")
    def load(k):
        p = os.path.join(base, k, pic + ".rgba")
        if not os.path.exists(p):
            return None
        return Image.frombytes("RGBA", (64, 64), zlib.decompress(open(p, "rb").read()))
    a, b = load(kind), load(kind + "_shiny")
    if a is None or b is None:
        return None
    return collections.Counter((p[:3], q[:3]) for p, q in zip(a.getdata(), b.getdata()) if p[3])


def ds_pair(folder, kind, internal_id):
    p = os.path.join(folder, "GenIII", f"{internal_id}.png")
    if not os.path.exists(p):
        return None
    sheet = Image.open(p).convert("RGB")
    col = 0 if kind == "front" else 2
    bg = sheet.getpixel((col * 64, 0))
    normal = sheet.crop((col * 64, 0, col * 64 + 64, 64))
    shiny = sheet.crop((col * 64 + 64, 0, col * 64 + 128, 64))
    return collections.Counter((p, q) for p, q in zip(normal.getdata(), shiny.getdata()) if p != bg)


# GBC form files -> (game, Gen 3 picture name) -Elvie
FORMS = {"351_sunny": ("firered", "385_1"), "351_rainy": ("firered", "385_2"), "351_snowy": ("firered", "385_3"),
         "386_attack": ("firered", "410_handled"), "386_defense": ("leafgreen", "410_handled"),
         "386_speed": ("emerald", "410_handled")}


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("gen3", "ds"):
        sys.exit(__doc__)
    source, where, mod_dir = sys.argv[1:]
    internal = load_internal(mod_dir)
    base = os.path.join(mod_dir, "assets", "mons", "gbc")
    jobs = [(f"{nat:03d}", ("firered", str(internal[nat]))) for nat in range(252, 387)]
    if source == "gen3":
        jobs += list(FORMS.items())
    written = 0
    for kind in ("front", "back"):
        os.makedirs(os.path.join(base, kind + "_shiny"), exist_ok=True)
        for name, (game, pic) in jobs:
            gpath = os.path.join(base, kind, name + ".png")
            if not os.path.exists(gpath):
                continue
            pairs = gen3_pair(where, game, kind, pic) if source == "gen3" else ds_pair(where, kind, pic)
            if not pairs:
                continue
            g = Image.open(gpath).convert("RGBA")
            colours = {p[:3] for p in g.getdata() if p[3]}
            change = {c: (c if lum(c) > 235 or lum(c) < 20 else shiny_colour(c, pairs)) for c in colours}
            g.putdata([change[p[:3]] + (p[3],) if p[3] else p for p in g.getdata()])
            g.save(os.path.join(base, kind + "_shiny", name + ".png"))
            written += 1
    print(f"wrote {written} shiny pictures")


if __name__ == "__main__":
    main()

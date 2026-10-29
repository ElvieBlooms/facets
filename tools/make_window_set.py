#!/usr/bin/env python3
"""Builds a Facets window set (assets/windows/<set>/) from a pack's own
images: Gen 3 window frames (24x24, 3x3 tiles), dialogue boxes (18
tiles) and signpost boxes (19 tiles), as PNG or BMP in any tile
arrangement, read left to right, top to bottom.

  python3 make_window_set.py <recipe.json> <mod folder> <pack folder>

Palette colour 0 becomes see-through, as on the GBA; a dialogue or sign
box's colour 1 is its inside (Gen 3 fills a window with colour 1). The
recipe names each style and the files it uses; see
recipes/windows_tito.json. Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image

LAYOUT = {"frame": (9, 3), "dialogue": (18, 6), "sign": (19, 5)}


def load(path):
    im = Image.open(path)
    pal = None
    if im.mode == "P":
        p = im.getpalette()
        pal = [tuple(p[i * 3:i * 3 + 3]) for i in range(len(p) // 3)]
        idx = im.load()
        rgba = im.convert("RGBA")
        px = rgba.load()
        for y in range(im.height):
            for x in range(im.width):
                if idx[x, y] == 0:
                    px[x, y] = (0, 0, 0, 0)
        return rgba, pal
    return im.convert("RGBA"), pal


def retile(img, count, across):
    """count 8x8 tiles, read in order, laid out across tiles wide. -Elvie"""
    src_across = img.width // 8
    rows = (count + across - 1) // across
    out = Image.new("RGBA", (across * 8, rows * 8), (0, 0, 0, 0))
    for t in range(count):
        sx, sy = (t % src_across) * 8, (t // src_across) * 8
        out.paste(img.crop((sx, sy, sx + 8, sy + 8)), ((t % across) * 8, (t // across) * 8))
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    recipe = json.load(open(sys.argv[1], encoding="utf-8"))
    mod, pack = sys.argv[2], sys.argv[3]
    out_dir = os.path.join(mod, "assets", "windows", recipe["set"])
    os.makedirs(out_dir, exist_ok=True)
    styles = []
    for st in recipe["styles"]:
        entry = {"name": st["name"]}
        for kind in ("frame", "dialogue", "sign"):
            src = st.get(kind)
            if not src:
                continue
            img, pal = load(os.path.join(pack, src))
            count, across = LAYOUT[kind]
            name = st.get(kind + "As") or ("%s_%s.png" % (kind, st["name"].lower().replace(" ", "_")))
            retile(img, count, across).save(os.path.join(out_dir, name))
            entry[kind] = name
            if kind != "frame" and pal:
                entry["fill" if kind == "dialogue" else "signFill"] = list(pal[1])
        styles.append(entry)
    meta = {"label": recipe["label"], "credit": recipe["credit"], "styles": styles}
    with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("%s: %d styles -> %s" % (recipe["label"], len(styles), out_dir))


if __name__ == "__main__":
    main()

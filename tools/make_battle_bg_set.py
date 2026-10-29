#!/usr/bin/env python3
"""Builds a Facets battle background set (assets/battlebg/<set>/) from a
pack's own pictures: each scene cropped to the 240x112 the battle shows
above the text box, and a map from the games' background names (grass,
cave, gym, the Elite Four's...) to scenes.

  python3 make_battle_bg_set.py <recipe.json> <mod folder> <pack folder>

See recipes/battlebg_scenery.json. Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    recipe = json.load(open(sys.argv[1], encoding="utf-8"))
    mod, pack = sys.argv[2], sys.argv[3]
    out_dir = os.path.join(mod, "assets", "battlebg", recipe["set"])
    os.makedirs(out_dir, exist_ok=True)
    scenes = {}
    for name, src in recipe["scenes"].items():
        img = Image.open(os.path.join(pack, src)).convert("RGB")
        x, y, w, h = recipe.get("crop", [0, 0, 240, 112])
        img.crop((x, y, x + w, y + h)).save(os.path.join(out_dir, name + ".png"))
        scenes[name] = name + ".png"
    meta = {"label": recipe["label"], "credit": recipe["credit"], "scenes": scenes,
            "keys": recipe["keys"], "default": recipe.get("default", next(iter(scenes)))}
    with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("%s: %d scenes -> %s" % (recipe["label"], len(scenes), out_dir))


if __name__ == "__main__":
    main()

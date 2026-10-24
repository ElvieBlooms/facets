#!/usr/bin/env python3
"""Turns a 64x64 Pokémon sprite resource into a Facets Pokémon set
(assets/mons/<set>/front|back[_shiny]/NNN.png, by national number).

  python3 mon_convert.py <recipe.json> <pack folder> <mod folder>

The recipe (recipes/ds_mons.json) says which folders hold which numbering,
any extra files (forms), and the set's label and credit. Sheets are
256 wide: front, shiny front, back, shiny back, 64x64 each, on a solid
background (each frame's top-left pixel's colour), which becomes see-through. Only
the first row is used. Facets stands each picture on the game's own
ground line when it draws it, so where the art sits in its frame doesn't
matter. Needs Pillow. -Elvie
"""
import json, os, re, sys
from PIL import Image

KINDS = ["front", "front_shiny", "back", "back_shiny"]


def clear(frame, bg):
    out = frame.convert("RGBA")
    out.putdata([(0, 0, 0, 0) if p[:3] == bg else p[:3] + (255,) for p in out.getdata()])
    return out


def frames(path, single=None):
    """single: "front" or "back" for a lone 64x64 picture -Elvie"""
    im = Image.open(path).convert("RGBA")
    bg = im.getpixel((0, 0))[:3]
    if single:
        if im.size != (64, 64):
            sys.exit(f"{path}: a single picture should be 64x64, not {im.size[0]}x{im.size[1]}")
        return {single: clear(im, bg)}
    if im.width != 256 or im.height not in (64, 128):
        sys.exit(f"{path}: expected a 256x64 sheet, not {im.width}x{im.height}")
    out = {}
    for i, kind in enumerate(KINDS):
        # each frame's own corner: shiny frames often sit on another colour -Elvie
        cell = im.crop((i * 64, 0, i * 64 + 64, 64))
        f = clear(cell, cell.getpixel((0, 0))[:3])
        if f.getbbox():
            out[kind] = f
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    recipe_path, pack, mod_dir = sys.argv[1:]
    r = json.load(open(recipe_path, encoding="utf-8"))
    set_dir = os.path.join(mod_dir, "assets", "mons", r["set"])
    internal = {int(k): v for k, v in r.get("internal", {}).items()}
    skip_front = set(r.get("skip_front", []))
    jobs = []
    for folder, numbering in r["folders"].items():
        for f in sorted(os.listdir(os.path.join(pack, folder))):
            m = re.fullmatch(r"(\d+)\.png", f, re.I)
            if not m:
                continue
            n = int(m.group(1))
            nat = internal.get(n) if numbering == "internal" else n
            if nat is None or not 1 <= nat <= 386:
                continue
            jobs.append((os.path.join(pack, folder, f), nat, "", None))
    for rel, e in r.get("extras", {}).items():
        if "national" in e:
            single = e.get("kind") or ("front" if e.get("front_only") else None)
            jobs.append((os.path.join(pack, rel), e["national"], "_" + e["variant"], single))
    written, have = 0, set()
    for path, nat, variant, single in jobs:
        for kind, img in frames(path, single).items():
            if kind == "front" and nat in skip_front and not variant:
                continue
            d = os.path.join(set_dir, kind)
            os.makedirs(d, exist_ok=True)
            img.save(os.path.join(d, f"{nat:03d}{variant}.png"))
            written += 1
            if kind == "front" and not variant:
                have.add(nat)
    meta = {"label": r["label"], "credit": r["credit"]}
    json.dump(meta, open(os.path.join(set_dir, "meta.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    missing = [n for n in range(1, 387) if n not in have]
    print(f"wrote {written} pictures to {set_dir}")
    if missing:
        print("no front picture for:", " ".join(map(str, missing)))


if __name__ == "__main__":
    main()

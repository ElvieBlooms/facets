#!/usr/bin/env python3
"""Turns DS-style trainer sprites (80x80 art, often saved doubled at
160x160) into a Facets trainer set: assets/trainers/<set>/<NAME>.png,
64x64, by the Gen 3 picture's name (YOUNGSTER, LEADER_BROCK...).

  python3 make_trainer_set.py <recipe.json> <mod folder> name=<folder> [name=<folder> ...]

Each name=<folder> is one of the recipe's sources (kyle=..., gela=...).
The recipe lists, for each Gen 3 picture, the sources to try in order
and the file in each (.png or .webp). A list of files instead of one
stands them side by side, for pairs drawn apart (Tate and Liza). Gen 3's trainer frame is 64x64, so art taller or
wider than that is shrunk to fit (nearest neighbour, whole pixels kept
crisp); Facets stands each picture on the game's own ground line when it
draws it. Needs Pillow. -Elvie
"""
import json, os, sys
from PIL import Image

SIZE = 64


EXTS = (".png", ".webp")


def find(folder, stem):
    """stem.png or stem.webp anywhere under folder, any case -Elvie"""
    want = [stem.lower() + e for e in EXTS]
    for root, _, files in os.walk(folder):
        for f in files:
            if f.lower() in want:
                return os.path.join(root, f)
    return None


def side_by_side(paths, overlap=6):
    """a pair drawn apart, stood together on one ground line -Elvie"""
    ims = []
    for path in paths:
        im = Image.open(path).convert("RGBA")
        box = im.getchannel("A").getbbox()
        if box:
            ims.append(im.crop(box))
    if not ims:
        return None
    w = sum(i.width for i in ims) - overlap * (len(ims) - 1)
    h = max(i.height for i in ims)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for i in reversed(range(len(ims))):  # the first stands in front -Elvie
        x = sum(j.width - overlap for j in ims[:i])
        out.alpha_composite(ims[i], (x, h - ims[i].height))
    return out


def to_set(path, doubled):
    im = path if isinstance(path, Image.Image) else Image.open(path).convert("RGBA")
    if doubled == "auto":
        # doubled art: every pixel a 2x2 block -Elvie
        px = im.load()
        w, h = im.size
        doubled = w % 2 == 0 and h % 2 == 0 and all(
            px[x, y] == px[x + 1, y] == px[x, y + 1] == px[x + 1, y + 1]
            for y in range(0, h, 2) for x in range(0, w, 2))
    if doubled:
        im = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    box = im.getchannel("A").getbbox()
    if not box:
        return None
    art = im.crop(box)
    scale = min(SIZE / art.width, SIZE / art.height, 1)
    if scale < 1:
        art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.NEAREST)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(art, ((SIZE - art.width) // 2, SIZE - art.height))
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    recipe = json.load(open(sys.argv[1], encoding="utf-8"))
    mod = sys.argv[2]
    folders = {}
    for arg in sys.argv[3:]:
        name, _, folder = arg.partition("=")
        if not folder or not os.path.isdir(folder):
            sys.exit(f"{arg}: give each source as name=<folder>")
        folders[name] = folder
    out_dir = os.path.join(mod, "assets", "trainers", recipe["set"])
    os.makedirs(out_dir, exist_ok=True)
    made, missing, used = 0, [], {}
    for pic, tries in sorted(recipe["trainers"].items()):
        done = False
        for source, stem in tries:
            if source not in folders:
                continue
            if isinstance(stem, list):
                paths = [find(folders[source], one) for one in stem]
                if not all(paths):
                    continue
                path = side_by_side(paths)
            else:
                path = find(folders[source], stem)
            if not path:
                continue
            im = to_set(path, recipe.get("doubled", "auto"))
            if im is None:
                continue
            im.save(os.path.join(out_dir, pic + ".png"))
            used[source] = used.get(source, 0) + 1
            made += 1
            done = True
            break
        if not done:
            missing.append(pic)
    meta = {"label": recipe["label"], "credit": recipe["credit"]}
    with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"{recipe['label']}: {made} pictures ({', '.join(f'{k} {v}' for k, v in sorted(used.items()))}) -> {out_dir}")
    if missing:
        print("not found:", " ".join(missing))


if __name__ == "__main__":
    main()

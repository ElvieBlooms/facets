#!/usr/bin/env python3
"""Builds the GBC ANIM Pokémon set from Nuuk's Crystal-style sprites
(Crystal_GFX_files.zip: one pokecrystal folder per Pokémon, each zipped).

  python3 make_gbc_anim.py <recipe.json> <Crystal_GFX_files.zip> <mod folder>

For each Pokémon in the recipe it writes, under assets/mons/<set>/:
  front/NNN.png, front_shiny/NNN.png   the first picture, 64x64
  back/NNN.png,  back_shiny/NNN.png    the back, 64x64
  anim/NNN.png,  anim_shiny/NNN.png    every picture, stacked (base first),
                                       at the sprite's own size
  anim/NNN.json                        the animation scripts (play, idle)
Fronts and backs sit at the bottom centre of their 64x64 picture, as
Crystal's would in a 64x64 frame; Facets lines the animation frames up
with the front the same way. The white joined to a picture's edge becomes see-through; white inside the
outline stays. Shinies swap the two middle colours for shiny.pal's. The
scripts are anim.asm and anim_idle.asm as numbers, the way Crystal's own
are stored: [frame, duration], [254, count] (setrepeat), [253, index]
(dorepeat). Needs Pillow. -Elvie
"""
import io, json, os, sys, zipfile
from PIL import Image

SETREPEAT, DOREPEAT, END = 254, 253, 255


def lum(c):
    return c[0] * 299 + c[1] * 587 + c[2] * 114


def clear_outside(pic):
    """RGBA copy with the white touching the edge made see-through. -Elvie"""
    pic = pic.convert("RGBA")
    w, h = pic.size
    px = pic.load()
    seen, stack = set(), [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        r, g, b, a = px[x, y]
        if a and (r, g, b) != (255, 255, 255):
            continue
        seen.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for x, y in seen:
        px[x, y] = (0, 0, 0, 0)
    return pic


def pad64(pic):
    """pic at the bottom centre of a see-through 64x64 picture. -Elvie"""
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    out.paste(pic, ((64 - pic.width) // 2, 64 - pic.height))
    return out


def shades(img):
    """The picture's colours lightest first: white, light, dark, black. -Elvie"""
    cols = sorted({p[:3] for p in img.convert("RGBA").getdata() if p[3]}, key=lum, reverse=True)
    return cols


def shiny_of(img, normal, pal):
    """img with its light and dark colours swapped for the shiny pair. -Elvie"""
    if len(normal) < 4 or len(pal) < 2:
        return img.copy()
    swap = {normal[1]: pal[0], normal[2]: pal[1]}
    out = img.copy()
    out.putdata([(swap.get(p[:3], p[:3]) + (p[3],)) if p[3] else p for p in img.getdata()])
    return out


def read_pal(text):
    out = []
    for line in text.splitlines():
        parts = line.replace(",", " ").split()
        if parts and parts[0].upper() == "RGB" and len(parts) >= 4:
            out.append(tuple((int(v) * 255 + 15) // 31 for v in parts[1:4]))
    return out


def read_script(text):
    rows = []
    for line in text.splitlines():
        line = line.split(";")[0].replace(",", " ").split()
        if not line:
            continue
        op, args = line[0].lower(), [int(a) for a in line[1:]]
        if op == "frame":
            rows.append([args[0], args[1]])
        elif op == "setrepeat":
            rows.append([SETREPEAT, args[0]])
        elif op == "dorepeat":
            rows.append([DOREPEAT, args[0]])
        elif op == "endanim":
            rows.append([END, 0])
        else:
            raise ValueError("unknown command " + op)
    return rows


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    recipe = json.load(open(sys.argv[1]))
    outer = zipfile.ZipFile(sys.argv[2])
    base = os.path.join(sys.argv[3], "assets", "mons", recipe["set"])
    for d in ("front", "front_shiny", "back", "back_shiny", "anim", "anim_shiny"):
        os.makedirs(os.path.join(base, d), exist_ok=True)
    inner_names = {os.path.basename(n): n for n in outer.namelist()}
    written = 0
    for stem, nat in sorted(recipe["pokemon"].items(), key=lambda kv: kv[1]):
        inner = zipfile.ZipFile(io.BytesIO(outer.read(inner_names[stem + ".zip"])))
        files = {os.path.basename(n): n for n in inner.namelist() if not n.endswith("/")}
        read = lambda n: inner.read(files[n])
        sheet = Image.open(io.BytesIO(read("front.png"))).convert("RGBA")
        back = Image.open(io.BytesIO(read("back.png"))).convert("RGBA")
        pal = read_pal(read("shiny.pal").decode("latin1"))
        size = sheet.width
        count = sheet.height // size
        normal = shades(sheet)
        back_normal = shades(back)
        # each picture cleared on its own, then stacked again -Elvie
        pics = [clear_outside(sheet.crop((0, i * size, size, (i + 1) * size))) for i in range(count)]
        stacked = Image.new("RGBA", (size, size * count), (0, 0, 0, 0))
        for i, p in enumerate(pics):
            stacked.paste(p, (0, i * size))
        back_clear = clear_outside(back)
        name = "%03d.png" % nat
        pad64(pics[0]).save(os.path.join(base, "front", name))
        pad64(shiny_of(pics[0], normal, pal)).save(os.path.join(base, "front_shiny", name))
        pad64(back_clear).save(os.path.join(base, "back", name))
        pad64(shiny_of(back_clear, back_normal, pal)).save(os.path.join(base, "back_shiny", name))
        stacked.save(os.path.join(base, "anim", name))
        shiny_of(stacked, normal, pal).save(os.path.join(base, "anim_shiny", name))
        script = {"tiles": size // 8, "play": read_script(read("anim.asm").decode("latin1"))}
        if "anim_idle.asm" in files:
            script["idle"] = read_script(read("anim_idle.asm").decode("latin1"))
        with open(os.path.join(base, "anim", "%03d.json" % nat), "w") as f:
            json.dump(script, f, separators=(",", ":"))
        written += 1
    print("wrote %d Pokémon to %s" % (written, base))


if __name__ == "__main__":
    main()

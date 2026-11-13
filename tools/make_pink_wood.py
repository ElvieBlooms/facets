# Builds assets/windows/pinkwood/: Tito Seich / Sage's WOODY text box
# (assets/windows/tito/dialogue_woody.png), recoloured in PINK's colours.
# python3 tools/make_pink_wood.py assets/windows/tito/dialogue_woody.png assets/windows/pinkwood -Elvie
import sys, json
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
base = Image.open(src).convert("RGBA")
LIGHT, MID, SHADOW, OUTLINE = (248,200,120), (232,184,104), (200,144,72), (72,80,80)
STYLES = [
  ("ROSE",    (255,236,246), (246,213,238), (222,156,205), (112,44,92)),
  ("MAGENTA", (252,228,244), (238,190,224), (197,74,164),  (88,28,74)),
  ("SKY",     (236,247,255), (204,230,248), (106,180,222), (38,72,104)),
  ("BERRY",   (255,236,232), (248,204,200), (205,82,82),   (98,34,40)),
  ("PEACH",   (255,246,238), (250,226,210), (232,172,148), (108,66,58)),
]
meta = {"label": "PINK WOOD",
        "credit": ["Text boxes recoloured by ElvieBlooms to match PINK, after Tito Seich / Sage's Woody, used with credit"],
        "styles": []}
for name, light, mid, shadow, outline in STYLES:
    m = {LIGHT: light, MID: mid, SHADOW: shadow, OUTLINE: outline}
    im = base.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in m:
                px[x, y] = m[(r, g, b)] + (a,)
    f = "dialogue_%s.png" % name.lower()
    im.save(out + "/" + f)
    meta["styles"].append({"name": name, "dialogue": f, "fill": list(light)})
json.dump(meta, open(out + "/meta.json", "w"), indent=2, ensure_ascii=False)

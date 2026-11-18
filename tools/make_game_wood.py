# GAME WOOD: Tito Seich / Sage's Woody text box and frame, recoloured in
# each game's own colour, as PINK WOOD and PAPER WOOD are. Only the games
# whose colours stand apart are made; the rest are here to compare
# (--preview draws them all side by side).
# python3 tools/make_game_wood.py assets/windows [--preview out.png] -Elvie
import json, os, sys
from PIL import Image, ImageDraw
SRC = sys.argv[1]
OUT = os.path.join(SRC, "gamewood")
woody = Image.open(os.path.join(SRC, "tito", "dialogue_woody.png")).convert("RGBA")
paperMap = os.path.join(SRC, "tito", "dialogue_woody.paper.png")
LIGHT, MID, SHADOW, OUTLINE = (248, 200, 120), (232, 184, 104), (200, 144, 72), (72, 80, 80)
# name: light (the inside), mid (the panel), shadow (the trim), outline -Elvie
GAMES = [
  ("RED",       (255, 226, 220), (246, 190, 180), (220, 72, 56),   (104, 28, 24)),
  ("BLUE",      (226, 236, 255), (192, 210, 248), (64, 104, 208),  (28, 40, 100)),
  ("YELLOW",    (255, 248, 200), (250, 232, 140), (232, 184, 24),  (110, 84, 16)),
  ("GOLD",      (250, 236, 192), (234, 206, 120), (184, 136, 24),  (88, 64, 16)),
  ("SILVER",    (236, 240, 246), (208, 214, 226), (136, 148, 168), (52, 60, 76)),
  ("CRYSTAL",   (224, 248, 252), (184, 232, 244), (56, 176, 208),  (20, 72, 96)),
  ("RUBY",      (255, 224, 232), (244, 184, 200), (192, 32, 72),   (92, 16, 36)),
  ("SAPPHIRE",  (220, 232, 255), (180, 204, 248), (40, 72, 184),   (20, 30, 90)),
  ("EMERALD",   (220, 248, 232), (176, 232, 200), (32, 160, 96),   (16, 72, 44)),
  ("FIRERED",   (255, 232, 212), (250, 200, 168), (232, 96, 40),   (110, 40, 20)),
  ("LEAFGREEN", (236, 250, 212), (208, 238, 168), (104, 176, 40),  (44, 80, 20)),
]
MADE = ["RED", "BLUE", "YELLOW", "GOLD", "SILVER", "CRYSTAL", "EMERALD", "LEAFGREEN"]

def recolour(light, mid, shadow, outline):
  m = {LIGHT: light, MID: mid, SHADOW: shadow, OUTLINE: outline}
  out = woody.copy(); px = out.load()
  for y in range(out.height):
    for x in range(out.width):
      r, g, b, a = px[x, y]
      if a and (r, g, b) in m: px[x, y] = m[(r, g, b)] + (a,)
  return out

# A window frame from the text box (as make_paper_wood.py makes PAPER
# WOOD's): its top edge's run of lines (outline,
# panel, inside) on all four sides, its rounded corner kept, as a 24x24
# nine-slice -Elvie
def frameOf(dlg):
  T = 8
  def tile(i, vf=0):
    c = dlg.crop(((i % 6) * T, (i // 6) * T, (i % 6) * T + T, (i // 6) * T + T))
    return c.transpose(Image.FLIP_TOP_BOTTOM) if vf else c
  top = tile(2)       # a stretch of the top edge
  corner0 = tile(0)   # the top left corner, rounded
  edge = [top.getpixel((4, y)) for y in range(T)]
  corner = Image.new("RGBA", (T, T))
  for y in range(T):
    for x in range(T):
      a, b = min(x, y), max(x, y)
      # (the rounding, from the box's own corner; past it the edge's run) -Elvie
      corner.putpixel((x, y), corner0.getpixel((min(x, y), min(x, y))) if a < 3 and b < 3 else edge[a])
  side = Image.new("RGBA", (T, T))
  for y in range(T):
    for x in range(T): side.putpixel((x, y), edge[x])
  f = Image.new("RGBA", (3 * T, 3 * T))
  f.paste(corner, (0, 0)); f.paste(corner.transpose(Image.FLIP_LEFT_RIGHT), (2 * T, 0))
  f.paste(corner.transpose(Image.FLIP_TOP_BOTTOM), (0, 2 * T)); f.paste(corner.transpose(Image.ROTATE_180), (2 * T, 2 * T))
  f.paste(top, (T, 0)); f.paste(top.transpose(Image.FLIP_TOP_BOTTOM), (T, 2 * T))
  f.paste(side, (0, T)); f.paste(side.transpose(Image.FLIP_LEFT_RIGHT), (2 * T, T))
  fill = edge[T - 1]
  for y in range(T, 2 * T):
    for x in range(T, 2 * T): f.putpixel((x, y), fill)
  return f
# a box w x h tiles, from a frame's nine-slice, for the preview -Elvie
def box(dlg, w, h):
  T = 8
  f = frameOf(dlg)
  def tile(c, r): return f.crop((c * T, r * T, c * T + T, r * T + T))
  out = Image.new("RGBA", (w * T, h * T))
  for y in range(h):
    for x in range(w):
      c = 0 if x == 0 else (2 if x == w - 1 else 1)
      r = 0 if y == 0 else (2 if y == h - 1 else 1)
      out.paste(tile(c, r), (x * T, y * T))
  return out

if "--preview" in sys.argv:
  path = sys.argv[sys.argv.index("--preview") + 1]
  from PIL import ImageFont
  W, H, S = 20, 6, 3
  cols = 3
  rows = (len(GAMES) + 1 + cols - 1) // cols
  sheet = Image.new("RGB", (cols * (W * 8 + 8) * S + 8 * S, rows * (H * 8 + 18) * S + 8 * S), (40, 40, 44))
  d = ImageDraw.Draw(sheet)
  items = [("WOODY (Tito's own)", woody)] + [(n + ("" if n in MADE else "  (not made)"), recolour(*c)) for n, *c in GAMES]
  for i, (name, dlg) in enumerate(items):
    x0 = 8 * S + (i % cols) * (W * 8 + 8) * S
    y0 = 8 * S + (i // cols) * (H * 8 + 18) * S
    b = box(dlg, W, H).resize((W * 8 * S, H * 8 * S), Image.NEAREST)
    sheet.paste(b, (x0, y0 + 12 * S), b)
    d.text((x0, y0), name, fill=(240, 240, 240))
  sheet = sheet.resize((sheet.width, sheet.height))
  sheet.save(path)
  print("preview", path)
  sys.exit(0)

import shutil
os.makedirs(OUT, exist_ok=True)
styles = []
for name, light, mid, shadow, outline in GAMES:
  if name not in MADE: continue
  out = recolour(light, mid, shadow, outline)
  file = "dialogue_" + name.lower() + ".png"
  out.save(os.path.join(OUT, file))
  shutil.copyfile(paperMap, os.path.join(OUT, "dialogue_" + name.lower() + ".paper.png"))
  frame = "frame_" + name.lower() + ".png"
  frameOf(out).save(os.path.join(OUT, frame))
  styles.append({"name": name + " WOOD", "frame": frame, "dialogue": file, "fill": list(light)})
json.dump({"label": "GAME WOOD", "short": True,
  "credit": ["Text boxes and frames recoloured by ElvieBlooms in each game's colour, after Tito Seich / Sage's Woody, used with credit"],
  "styles": styles}, open(os.path.join(OUT, "meta.json"), "w"), indent=2)
print(len(styles))

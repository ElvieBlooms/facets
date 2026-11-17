# PAPER WOOD: Tito Seich / Sage's Woody text box recoloured, as PINK WOOD
# was, in each of PAPER's colours, light and dark -Elvie
import colorsys, json, os, sys
from PIL import Image
SRC = sys.argv[1]; OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SRC, "paperwood")
woody = Image.open(os.path.join(SRC, "tito", "dialogue_woody.png")).convert("RGBA")
FILL, PANEL, LINE, ACCENT = (248, 200, 120), (232, 184, 104), (72, 80, 80), (200, 144, 72)
PAPERS = [("CREAM", (248, 240, 216)), ("LEMON", (248, 244, 204)), ("PEACH", (250, 228, 210)),
  ("ROSE", (248, 224, 230)), ("LILAC", (234, 226, 248)), ("SKY", (218, 234, 250)),
  ("MINT", (222, 246, 228)), ("GREY", (214, 214, 214)),
  ("DARK", (34, 36, 46)), ("COCOA", (52, 38, 30)), ("OLIVE", (44, 44, 22)), ("RUST", (64, 34, 24)),
  ("WINE", (64, 22, 36)), ("PLUM", (46, 30, 62)), ("NAVY", (22, 32, 64)), ("FOREST", (22, 48, 34))]
def hls(c): return colorsys.rgb_to_hls(*[v / 255 for v in c])
def rgb(h, l, s): return tuple(round(v * 255) for v in colorsys.hls_to_rgb(h, max(0, min(1, l)), max(0, min(1, s))))
# A window frame from the text box: its top edge's run of lines (outline,
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
os.makedirs(OUT, exist_ok=True)
styles = []
for name, p in PAPERS:
  h, l, s = hls(p)
  sat = 0 if max(p) - min(p) < 6 else 1
  if l > 0.5:
    panel = rgb(h, l - 0.06, min(1, s + 0.15) * sat)
    accent = rgb(h, 0.72, 0.5 * sat)
    line = rgb(h, 0.30, 0.42 * sat)
  else:
    panel = rgb(h, l + 0.05, s * sat)
    accent = rgb(h, 0.42, 0.35 * sat)
    line = rgb(h, 0.74, 0.35 * sat)
  m = {FILL: p, PANEL: panel, LINE: line, ACCENT: accent}
  out = woody.copy(); px = out.load()
  for y in range(out.height):
    for x in range(out.width):
      r, g, b, a = px[x, y]
      if a and (r, g, b) in m: px[x, y] = m[(r, g, b)] + (a,)
  file = "dialogue_" + name.lower() + ".png"
  out.save(os.path.join(OUT, file))
  frame = "frame_" + name.lower() + ".png"
  frameOf(out).save(os.path.join(OUT, frame))
  styles.append({"name": name, "frame": frame, "dialogue": file, "fill": list(p)})
json.dump({"label": "PAPER WOOD", "short": True,
  "credit": ["Text boxes and frames recoloured by ElvieBlooms in PAPER's colours, after Tito Seich / Sage's Woody, used with credit"],
  "styles": styles}, open(os.path.join(OUT, "meta.json"), "w"), indent=2)
print(len(styles))

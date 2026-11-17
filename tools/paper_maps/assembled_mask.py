# The paper masks, on assembled windows: each frame as a 6x4 tile box and
# each text box / sign as Gen 3 lays it (8 tiles wide here, 6 high), from
# windows_paper_mask.png's pieces. Every tile placement is recorded, so an
# edited sheet maps back to each art file's tiles (a pixel is paper if any
# placement of that tile marks it) -Elvie
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
WORK, OUT = sys.argv[1], sys.argv[2]
T = 8
mp = json.load(open(os.path.join(WORK, "windows_sheet.json")))
masks = Image.open(os.path.join(OUT, "windows_paper_mask.png")).convert("RGBA")
MAG = (255, 0, 255, 255)
def piece(e): return masks.crop((e["x"], e["y"], e["x"] + e["w"], e["y"] + e["h"]))
def frameLayout(tw=6, th=4):
  R, out = tw - 1, []
  out += [(0, 0, 0, False), (2, R, 0, False), (6, 0, th - 1, False), (8, R, th - 1, False)]
  for i in range(1, tw - 1): out += [(1, i, 0, False), (7, i, th - 1, False)]
  for j in range(1, th - 1): out += [(3, 0, j, False), (5, R, j, False)]
  return out, (1, 1, tw - 2, th - 2), (tw, th)
def textLayout(W=4, H=4):
  L, Top, out = 2, 1, []
  for y, f in ((Top - 1, False), (Top + H, True)):
    out += [(0, L - 2, y, f), (1, L - 1, y, f)] + [(2, L + i, y, f) for i in range(W)] + [(3, L + W, y, f), (4, L + W + 1, y, f)]
  rows = [(5, 6, 8, 9, False), (10, 11, 12, 13, False), (10, 11, 12, 13, True), (5, 6, 8, 9, True)]
  for r, c in enumerate(rows):
    y = Top + r
    out += [(c[0], L - 2, y, c[4]), (c[1], L - 1, y, c[4]), (c[2], L + W, y, c[4]), (c[3], L + W + 1, y, c[4])]
  return out, (L, Top, W, H), (W + 4, H + 2)
font = ImageFont.load_default()
d0 = ImageDraw.Draw(Image.new("RGB", (1, 1)))
PAD, GAP, LBL = 8, 10, 12
groups, cur = [], None
for e in mp:
  folder = e["file"].split("/")[0]
  if folder != cur: groups.append((folder, [])); cur = folder
  groups[-1][1].append(e)
titles = {"libertytwins": "LIBERTY (LibertyTwins)", "pink": "PINK", "pinkwood": "PINK WOOD", "tito": "TITO"}
placed, boxes, y, W = [], [], PAD, 0
for folder, es in groups:
  placed.append(("title", titles.get(folder, folder), PAD, y)); y += LBL + 4
  x, rowh = PAD, 0
  for e in es:
    name = e["file"].split("/")[1][:-4]
    lay, inner, (tw, th) = frameLayout() if name.startswith("frame") else textLayout()
    w = max(tw * T, int(d0.textlength(name, font=font)))
    if x + w > 480: x, y, rowh = PAD, y + rowh + GAP, 0
    placed.append(("box", name, x, y, e, lay, inner, (tw, th)))
    rowh = max(rowh, LBL + th * T); x += w + GAP; W = max(W, x)
  y += rowh + GAP * 2
H = y
sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dr = ImageDraw.Draw(sheet)
record = []
for p in placed:
  if p[0] == "title":
    dr.text((p[2], p[3]), p[1], fill=(255, 200, 80, 255), font=font); continue
  _, name, x, y, e, lay, inner, (tw, th) = p
  dr.text((x, y), name, fill=(230, 230, 240, 255), font=font)
  ox, oy = x, y + LBL
  src = piece(e); cols = src.width // T
  # the inside, always paper (not mapped back)
  ix, iy, iw, ih = inner
  dr.rectangle([ox + ix * T, oy + iy * T, ox + (ix + iw) * T - 1, oy + (iy + ih) * T - 1], fill=MAG)
  for (i, cx, cy, flip) in lay:
    cell = src.crop(((i % cols) * T, (i // cols) * T, (i % cols) * T + T, (i // cols) * T + T))
    if flip: cell = cell.transpose(Image.FLIP_TOP_BOTTOM)
    sheet.alpha_composite(cell, (ox + cx * T, oy + cy * T))
    record.append({"file": e["file"], "cell": i, "cols": cols, "x": ox + cx * T, "y": oy + cy * T, "flip": flip})
sheet.save(os.path.join(OUT, "windows_paper_mask_assembled.png"))
json.dump(record, open(os.path.join(WORK, "windows_paper_mask_assembled.json"), "w"))
big = sheet.resize((W * 4, H * 4), Image.NEAREST)
bg = Image.new("RGBA", big.size, (60, 60, 68, 255)); bg.alpha_composite(big)
bg.save(os.path.join(OUT, "windows_paper_mask_assembled_preview.png"))
print(W, H, len(record))

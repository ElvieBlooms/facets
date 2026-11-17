# Edited assembled mask sheet -> one <art>.paper.png per art file: white
# where any placement of a tile is magenta, see-through elsewhere -Elvie
import json, os, sys
from PIL import Image
SHEET, REC, SRC = sys.argv[1], sys.argv[2], sys.argv[3]
sheet = Image.open(SHEET).convert("RGBA")
rec = json.load(open(REC))
T = 8
masks, counts = {}, {}
for r in rec:
  f = r["file"]
  if f not in masks:
    art = Image.open(os.path.join(SRC, f))
    masks[f] = Image.new("RGBA", art.size, (0, 0, 0, 0)); counts[f] = 0
  tile = sheet.crop((r["x"], r["y"], r["x"] + T, r["y"] + T))
  if r["flip"]: tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
  cx, cy = (r["cell"] % r["cols"]) * T, (r["cell"] // r["cols"]) * T
  for y in range(T):
    for x in range(T):
      p = tile.getpixel((x, y))
      if p[0] >= 250 and p[1] <= 5 and p[2] >= 250 and p[3] >= 250:
        if masks[f].getpixel((cx + x, cy + y))[3] == 0: counts[f] += 1
        masks[f].putpixel((cx + x, cy + y), (255, 255, 255, 255))
for f, m in masks.items():
  out = os.path.join(SRC, f[:-4] + ".paper.png")
  m.save(out)
  print(f, counts[f])

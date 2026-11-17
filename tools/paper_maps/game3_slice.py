# An edited GBA frames mask sheet -> a paper map per game art file (white
# where any placement of a tile is magenta), for every game that file's
# art is in: <out>/<game>/<file>.paper.png. Maps only: no art -Elvie
#
#   python3 game3_slice.py <edited sheet> <gba_frames_paper_mask_assembled.json> <out dir>
import json, os, sys
from PIL import Image
SHEET, REC, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
sheet = Image.open(SHEET).convert("RGBA")
T = 8
masks = {}
for r in json.load(open(REC)):
  key = (tuple(r["games"]), r["file"])
  if key not in masks: masks[key] = Image.new("RGBA", (r["w"], r["h"]), (0, 0, 0, 0))
  tile = sheet.crop((r["x"], r["y"], r["x"] + T, r["y"] + T))
  if r["flip"]: tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
  if r.get("hflip"): tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
  cx, cy = (r["cell"] % r["cols"]) * T, (r["cell"] // r["cols"]) * T
  for y in range(T):
    for x in range(T):
      p = tile.getpixel((x, y))
      if p[0] >= 250 and p[1] <= 5 and p[2] >= 250 and p[3] >= 250 and cx + x < r["w"] and cy + y < r["h"]:
        masks[key].putpixel((cx + x, cy + y), (255, 255, 255, 255))
for (games, f), m in masks.items():
  for g in games:
    os.makedirs(os.path.join(OUT, g), exist_ok=True)
    m.save(os.path.join(OUT, g, f[:-5] + ".paper.png"))
print(len(masks), "maps")

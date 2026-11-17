# The paper mask sheet: windows_sheet.png's layout, each piece with the
# pixels that take the paper's colour painted magenta (255, 0, 255), as
# Facets guesses them now (filter.darkArt's rule) -Elvie
import json, os, sys
from PIL import Image
SRC, WORK, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
mp = json.load(open(os.path.join(WORK, "windows_sheet.json")))
sheet = Image.open(os.path.join(WORK, "windows_sheet.png")).convert("RGBA")
def fills(folder):
  meta = json.load(open(os.path.join(SRC, folder, "meta.json")))
  out = {}
  for st in meta.get("styles", []):
    for k, fk in (("frame", "fill"), ("dialogue", "fill"), ("sign", "signFill")):
      if isinstance(st.get(k), str):
        out[st[k]] = tuple(c / 255 for c in (st.get(fk) or st.get("fill") or (248, 248, 248)))
  return out
def kind(px, x, y, w, h):
  if x < 0 or y < 0 or x >= w or y >= h: return "none"
  r, g, b, a = [c / 255 for c in px[x, y]]
  if a < 0.5: return "none"
  hi, lo = max(r, g, b), min(r, g, b)
  l = 0.299 * r + 0.587 * g + 0.114 * b
  if l > 0.8 and hi - lo < 0.07: return "white"
  if l < 0.2 and hi - lo < 0.12: return "black"
  return "colour"
total = 0
for e in mp:
  folder, name = e["file"].split("/")
  also = fills(folder).get(name) if not name.startswith("frame") else None
  im = Image.open(os.path.join(SRC, folder, name)).convert("RGBA")
  px, w, h = im.load(), im.width, im.height
  def inside(x, y):
    k = kind(px, x, y, w, h)
    if k == "white": return True
    if k == "colour" and also:
      r, g, b, a = [c / 255 for c in px[x, y]]
      return abs(r - also[0]) + abs(g - also[1]) + abs(b - also[2]) < 0.06
    return False
  for y in range(h):
    for x in range(w):
      if inside(x, y):
        beside = any(kind(px, x + dx, y + dy, w, h) == "colour" and not inside(x + dx, y + dy)
                     for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dy)
        if not beside:
          sheet.putpixel((e["x"] + x, e["y"] + y), (255, 0, 255, 255)); total += 1
sheet.save(os.path.join(OUT, "windows_paper_mask.png"))
big = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
bg = Image.new("RGBA", big.size, (60, 60, 68, 255)); bg.alpha_composite(big)
bg.save(os.path.join(OUT, "windows_paper_mask_preview.png"))
print(total)

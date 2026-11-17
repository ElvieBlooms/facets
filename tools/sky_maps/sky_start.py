# First sky maps for SCENERY's outdoor scenes, worked out from their
# colours: the sky reached from the top edge through sky blue (and clouds,
# where a scene has them), down to a line per scene. Maps only, white
# where the sky is: <scene>.sky.png beside each scene. Paint them by hand
# after (sky_sheet.py / sky_slice.py) -Elvie
#
#   python3 sky_start.py <assets/battlebg/scenery>
import colorsys, os, sys
from collections import deque
from PIL import Image
DIR = sys.argv[1]
# scene: (lowest row the sky reaches, clouds count as sky)
SCENES = { "grass": (80, True), "route": (60, True), "beach": (12, True), "sea": (46, True),
  "lake": (34, True), "mountain": (80, True), "snow": (27, False), "snow_mountain": (60, False),
  "desert": (60, True) }
def skyish(p, clouds):
  r, g, b = [v / 255 for v in p[:3]]
  h, l, s = colorsys.rgb_to_hls(r, g, b)
  if clouds and l > 0.78 and s < 0.6 and b >= r - 0.02: return True
  return 165 <= h * 360 <= 250 and s > 0.2 and l > 0.35 and b > r
for name, (lim, clouds) in SCENES.items():
  im = Image.open(os.path.join(DIR, name + ".png")).convert("RGB")
  w, h = im.size
  px = im.load()
  out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
  seen = set()
  q = deque((x, 0) for x in range(w) if skyish(px[x, 0], clouds))
  seen.update(q)
  while q:
    x, y = q.popleft()
    out.putpixel((x, y), (255, 255, 255, 255))
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
      if 0 <= nx < w and 0 <= ny < min(h, lim) and (nx, ny) not in seen and skyish(px[nx, ny], clouds):
        seen.add((nx, ny))
        q.append((nx, ny))
  out.save(os.path.join(DIR, name + ".sky.png"))
print(len(SCENES), "maps")

# A painted sky sheet (sky_sheet.py) -> a sky map per scene: white where
# the sheet is magenta, <scene>.sky.png. A scene with no magenta has no
# map (no sky: its colours follow the hour as a whole) -Elvie
#
#   python3 sky_slice.py <sheet.png> <assets/battlebg/scenery>
import os, sys
from PIL import Image
SHEET, DIR = sys.argv[1], sys.argv[2]
SCENES = ["grass", "route", "town", "forest", "beach", "sea", "lake", "mountain", "snow", "snow_mountain", "desert"]
W, H, GAP = 240, 112, 4
sheet = Image.open(SHEET).convert("RGBA")
for i, name in enumerate(SCENES):
  out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  n = 0
  for y in range(H):
    for x in range(W):
      p = sheet.getpixel((x, i * (H + GAP) + y))
      if p[0] >= 250 and p[1] <= 5 and p[2] >= 250:
        out.putpixel((x, y), (255, 255, 255, 255)); n += 1
  path = os.path.join(DIR, name + ".sky.png")
  if n: out.save(path)
  elif os.path.exists(path): os.remove(path)
  print(name, n)

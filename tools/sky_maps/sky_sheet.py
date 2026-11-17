# SCENERY's outdoor scenes in a column, each with its sky map painted on
# in magenta (#FF00FF), to paint over by hand: magenta is sky. blank
# leaves the maps off -Elvie
#
#   python3 sky_sheet.py <assets/battlebg/scenery> <sheet.png> [blank]
import os, sys
from PIL import Image
DIR, OUT = sys.argv[1], sys.argv[2]
BLANK = len(sys.argv) > 3 and sys.argv[3] == "blank"
SCENES = ["grass", "route", "town", "forest", "beach", "sea", "lake", "mountain", "snow", "snow_mountain", "desert"]
W, H, GAP = 240, 112, 4
sheet = Image.new("RGBA", (W, len(SCENES) * (H + GAP) - GAP), (0, 0, 0, 255))
for i, name in enumerate(SCENES):
  im = Image.open(os.path.join(DIR, name + ".png")).convert("RGBA")
  sky = os.path.join(DIR, name + ".sky.png")
  if not BLANK and os.path.exists(sky):
    m = Image.open(sky).convert("RGBA")
    for y in range(H):
      for x in range(W):
        if m.getpixel((x, y))[3] > 127: im.putpixel((x, y), (255, 0, 255, 255))
  sheet.paste(im, (0, i * (H + GAP)))
sheet.save(OUT)

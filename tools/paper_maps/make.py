import json, os, sys
from PIL import Image, ImageDraw, ImageFont
SRC = sys.argv[1]; OUT = sys.argv[2]
font = ImageFont.load_default()
sets = [
  ("LIBERTY (LibertyTwins)", "libertytwins",
   [f"frame_{i}" for i in range(1, 11)] + ["dialogue", "sign"]),
  ("PINK", "pink",
   [f"{k}_{c}" for k in ("frame", "dialogue", "sign") for c in ("berry", "blush", "border", "pastel", "sky")]),
  ("PINK WOOD", "pinkwood", [f"dialogue_{c}" for c in ("berry", "magenta", "peach", "rose", "sky")]),
  ("TITO", "tito", [f"dialogue_{c}" for c in ("checkered", "cool_red", "emerald", "hoenn", "orange", "red", "silver", "sky_blue", "square_red", "woody")]),
]
PAD, GAP, LBL = 8, 8, 12
d0 = ImageDraw.Draw(Image.new("RGB", (1, 1)))
def tw(t): return int(d0.textlength(t, font=font))
layout, y, W = [], PAD, 0
for title, folder, names in sets:
  layout.append(("title", title, PAD, y)); y += LBL + 4
  x, rowh = PAD, 0
  for n in names:
    im = Image.open(os.path.join(SRC, folder, n + ".png")).convert("RGBA")
    w = max(im.width, tw(n))
    if x + w > 560:
      x, y = PAD, y + rowh + GAP; rowh = 0
    layout.append(("piece", f"{folder}/{n}.png", x, y, n, im))
    rowh = max(rowh, LBL + im.height)
    x += w + GAP
    W = max(W, x)
  y += rowh + GAP * 2
H = y
for scale, name, bg in ((1, "windows_sheet.png", (0, 0, 0, 0)), (4, "windows_sheet_preview.png", None)):
  sheet = Image.new("RGBA", (W * scale, H * scale), bg or (0, 0, 0, 0))
  if bg is None:
    # a checker behind, for looking only
    ck = Image.new("RGBA", sheet.size, (60, 60, 68, 255)); dc = ImageDraw.Draw(ck)
    for yy in range(0, sheet.height, 16):
      for xx in range(0, sheet.width, 16):
        if (xx // 16 + yy // 16) % 2: dc.rectangle([xx, yy, xx + 15, yy + 15], fill=(80, 80, 90, 255))
    sheet = ck
  dr = ImageDraw.Draw(sheet)
  mp = []
  for e in layout:
    if e[0] == "title":
      dr.text((e[2] * scale, e[3] * scale), e[1], fill=(255, 200, 80, 255), font=font if scale == 1 else ImageFont.load_default(size=40) if hasattr(ImageFont, "truetype") else font)
    else:
      _, path, x, yy, n, im = e
      dr.text((x * scale, yy * scale), n, fill=(230, 230, 240, 255), font=font if scale == 1 else ImageFont.load_default(size=36))
      px, py = x, yy + LBL
      sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (px * scale, py * scale))
      mp.append({"file": path, "x": px, "y": py, "w": im.width, "h": im.height})
  sheet.save(os.path.join(OUT, name))
json.dump(mp, open(os.path.join(OUT, "windows_sheet.json"), "w"), indent=1)
print(W, H, len(mp))

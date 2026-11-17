# The GBA games' own window frames, read from your own imported games (the
# install's data/generated/gba/chrome), assembled as each game lays them
# out, for painting paper masks on, as the Facets window sets were. The
# sheet is for painting only: it holds the games' art, so it's never
# committed or shipped. Each tile placement is recorded, so an edited
# sheet maps back to each art file's tiles -Elvie
#
#   python3 game3_sheet.py <install> <out dir>
import hashlib, json, os, sys, zlib
from PIL import Image, ImageDraw, ImageFont
INST, OUT = sys.argv[1], sys.argv[2]
T = 8
MAG = (255, 0, 255, 255)
font = ImageFont.load_default()
d0 = ImageDraw.Draw(Image.new("RGB", (1, 1)))

def load(game, name, w, h):
  p = os.path.join(INST, game, "data/generated/gba/chrome", name)
  if not os.path.exists(p): return None
  raw = open(p, "rb").read()
  try: raw = zlib.decompress(raw)
  except zlib.error: pass
  if len(raw) != w * h * 4: return None
  return Image.frombytes("RGBA", (w, h), raw)

# layouts: (tile, x, y, vflip, hflip) in tiles, the inside (x, y, w, h)
# and the whole size -Elvie
def frame():  # a user or std frame round a 4x2 inside
  tw, th, R = 6, 4, 5
  out = [(0, 0, 0, 0, 0), (2, R, 0, 0, 0), (6, 0, th - 1, 0, 0), (8, R, th - 1, 0, 0)]
  for i in range(1, tw - 1): out += [(1, i, 0, 0, 0), (7, i, th - 1, 0, 0)]
  for j in range(1, th - 1): out += [(3, 0, j, 0, 0), (5, R, j, 0, 0)]
  return out, (1, 1, 4, 2), (tw, th)
def frlgText(W=4, H=4):  # FR/LG's text box and sign (chrome.lua dialogueFrame)
  L, Top, out = 2, 1, []
  for y, f in ((Top - 1, 0), (Top + H, 1)):
    out += [(0, L - 2, y, f, 0), (1, L - 1, y, f, 0)] + [(2, L + i, y, f, 0) for i in range(W)]
    out += [(3, L + W, y, f, 0), (4, L + W + 1, y, f, 0)]
  rows = [(5, 6, 8, 9, 0), (10, 11, 12, 13, 0), (10, 11, 12, 13, 1), (5, 6, 8, 9, 1)]
  for r, c in enumerate(rows):
    y = Top + r
    out += [(c[0], L - 2, y, c[4], 0), (c[1], L - 1, y, c[4], 0), (c[2], L + W, y, c[4], 0), (c[3], L + W + 1, y, c[4], 0)]
  return out, (L, Top, W, H), (W + 4, H + 2)
def emeraldText(W=4, H=4):  # Emerald's message box (chrome.lua drawMessageBox)
  L, Top, out = 2, 1, []
  for y, f in ((Top - 1, 0), (Top + H, 1)):
    out += [(1, L - 2, y, f, 0), (3, L - 1, y, f, 0)] + [(4, L + i, y, f, 0) for i in range(W - 1)]
    out += [(5, L + W - 1, y, f, 0), (6, L + W, y, f, 0)]
  for j in range(H): out += [(7, L - 2, Top + j, 0, 0), (9, L - 1, Top + j, 0, 0), (10, L + W, Top + j, 0, 0)]
  return out, (L, Top, W, H), (W + 3, H + 2)
def rsText():  # Ruby and Sapphire's (pokeruby/src/text_window.c:92), narrowed
  rows = [[1, 3, 4, 4, 5, 6, 9], [11, 9, 9, 9, 9, 0x040B, 9], [7, 9, 9, 9, 9, 10, 9],
          [0x080B, 9, 9, 9, 9, 0x0C0B, 9], [0x0801, 0x0803, 0x0804, 0x0804, 0x0805, 0x0806, 9]]
  xs = [0, 1, 2, 3, 4, 28, 29]
  out = []
  for y in range(6):
    for i, x in enumerate(xs):
      row = y - 4 + 3 if y >= 4 else (2 if y > 1 else y)
      col = x - 28 + 4 if x >= 28 else (3 if x > 2 else x)
      e = rows[row][col] if col < len(rows[row]) else 9
      out.append((e % 1024, i, y, (e // 2048) % 2, (e // 1024) % 2))
  return out, (1, 1, 5, 4), (len(xs), 6)

items = []  # (group, name, file, image, cols, layout)
seen = {}
def add(group, name, game, file, w, h, cols, lay):
  im = load(game, file, w, h)
  if im is None: return
  key = hashlib.md5(im.tobytes()).hexdigest()
  if key in seen:
    seen[key][1].append(game); return
  entry = [group, [game], name, file, im, cols, lay]
  seen[key] = (entry, entry[1]); items.append(entry)
for g in ("firered", "leafgreen"):
  add("FIRERED / LEAFGREEN", "text box", g, "menu_message_rgba.rgba", 48, 24, 6, frlgText)
  add("FIRERED / LEAFGREEN", "sign", g, "signpost_rgba.rgba", 40, 32, 5, frlgText)
  add("FIRERED / LEAFGREEN", "std", g, "std_rgba.rgba", 24, 24, 3, frame)
  for n in range(10): add("FIRERED / LEAFGREEN", f"frame {n + 1}", g, f"user_frame_{n}.rgba", 24, 24, 3, frame)
add("EMERALD", "text box", "emerald", "message_box.rgba", 56, 16, 7, emeraldText)
for n in range(20): add("EMERALD", f"frame {n + 1}", "emerald", f"user_frame_{n}.rgba", 24, 24, 3, frame)
for g in ("ruby", "sapphire"):
  add("RUBY / SAPPHIRE", "text box", g, "message_box.rgba", 56, 16, 7, rsText)
  for n in range(20): add("RUBY / SAPPHIRE", f"frame {n + 1}", g, f"user_frame_{n}.rgba", 24, 24, 3, frame)

PAD, GAP, LBL, MAXW = 8, 10, 12, 520
placed, y, W, cur = [], PAD, 0, None
x, rowh = PAD, 0
for it in items:
  group = it[0]
  if group != cur:
    if cur is not None: y += rowh + GAP * 2
    placed.append(("title", group, PAD, y)); y += LBL + 4
    x, rowh, cur = PAD, 0, group
  lay, inner, (tw, th) = it[6]()
  w = max(tw * T, int(d0.textlength(it[2], font=font)))
  if x + w > MAXW: x, y, rowh = PAD, y + rowh + GAP, 0
  placed.append(("box", it, x, y, lay, inner, (tw, th)))
  rowh = max(rowh, LBL + th * T); x += w + GAP; W = max(W, x)
H = y + rowh + PAD

# the auto guess: the art's white, not beside a colour of its own, as the
# window sets' was -Elvie
def kind(im, x, y):
  if x < 0 or y < 0 or x >= im.width or y >= im.height: return "none"
  r, g, b, a = im.getpixel((x, y))
  if a < 128: return "none"
  hi, lo = max(r, g, b), min(r, g, b)
  l = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if l > 0.8 and hi - lo < 18: return "white"
  if l < 0.2 and hi - lo < 30: return "black"
  return "colour"
def guessed(im):
  out = im.copy()
  for yy in range(im.height):
    for xx in range(im.width):
      if kind(im, xx, yy) == "white" and not any(kind(im, xx + dx, yy + dy) == "colour"
          for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
        out.putpixel((xx, yy), MAG)
  return out

art = Image.new("RGBA", (W, H), (0, 0, 0, 0))
mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
record = []
for sheet, guess in ((art, False), (mask, True)):
  dr = ImageDraw.Draw(sheet)
  for p in placed:
    if p[0] == "title":
      dr.text((p[2], p[3]), p[1], fill=(255, 200, 80, 255), font=font); continue
    _, it, x, y, lay, inner, (tw, th) = p
    games = "+".join(it[1])
    dr.text((x, y), it[2], fill=(230, 230, 240, 255), font=font)
    ox, oy = x, y + LBL
    src = guessed(it[4]) if guess else it[4]
    cols = it[5]
    for (i, cx, cy, vf, hf) in lay:
      sx, sy = (i % cols) * T, (i // cols) * T
      cell = src.crop((sx, sy, sx + T, sy + T))
      if vf: cell = cell.transpose(Image.FLIP_TOP_BOTTOM)
      if hf: cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
      sheet.alpha_composite(cell, (ox + cx * T, oy + cy * T))
      if guess:
        record.append({"games": it[1], "file": it[3], "w": it[4].width, "h": it[4].height, "cell": i, "cols": cols,
                       "x": ox + cx * T, "y": oy + cy * T, "flip": vf, "hflip": hf})
    # the inside, always paper (over any fill tiles the game lays there)
    # -Elvie
    if guess:
      ix, iy, iw, ih = inner
      dr.rectangle([ox + ix * T, oy + iy * T, ox + (ix + iw) * T - 1, oy + (iy + ih) * T - 1], fill=MAG)
art.save(os.path.join(OUT, "gba_frames_sheet.png"))
mask.save(os.path.join(OUT, "gba_frames_paper_mask_assembled.png"))
json.dump(record, open(os.path.join(OUT, "gba_frames_paper_mask_assembled.json"), "w"))
for name, im in (("gba_frames_sheet_preview.png", art), ("gba_frames_paper_mask_preview.png", mask)):
  big = im.resize((W * 4, H * 4), Image.NEAREST)
  bg = Image.new("RGBA", big.size, (60, 60, 68, 255)); bg.alpha_composite(big); bg.save(os.path.join(OUT, name))
print(W, H, len(items), len(record))
for it in items: print(it[0], it[2], "+".join(it[1]))

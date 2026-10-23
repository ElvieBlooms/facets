#!/usr/bin/env python3
"""Facets test set: numbered placeholder sheets for checking frame order,
sizes and fallbacks in game. Each frame shows its number and which way it
faces (an arrow). Original art, safe to ship.

  python3 make_test_set.py <mod folder>

Writes assets/npcs/test_frames/ with meta.json and these sheets, chosen to
cover each rule (FR/LG and R/S/E):
  NURSE       32x32, 10 frames: walking, and the bow on frame 9 (B)
  YOUNGSTER   32x32, 9 frames: the VS Seeker hand raise falls back to standing
  LITTLE_BOY  32x32 over the game's 16x16
  BROCK       16x32, 9 frames: the game's own size (FR/LG)
  BUG_CATCHER 16x32, 10 frames: the game's own size with the hand raise (FR/LG)
  ROXANNE     16x32, 9 frames: the game's own size (R/S/E)
  RICH_BOY    R/S/E only: Ruby's BOY_4 finds it through the alias table
Needs Pillow (python3 -m pip install --user pillow). -Elvie
"""
import json, os, sys
from PIL import Image

# 3x5 digits and a B for the bow/raise frame
GLYPHS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    "B": ["110", "101", "110", "101", "110"],
}
INK = (24, 24, 32, 255)
SKIN = (248, 208, 168, 255)
DIR_COLOR = {"down": (64, 120, 232, 255), "up": (56, 168, 88, 255),
             "left": (232, 136, 40, 255), "extra": (216, 64, 200, 255)}
# pret ANIM_STD: facing and step for each frame; frame 9 is the bow or hand raise
FRAMES = [("down", 0), ("up", 0), ("left", 0), ("down", 1), ("down", 2),
          ("up", 1), ("up", 2), ("left", 1), ("left", 2), ("extra", 0)]


def rect(im, x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(im.height, y1)):
        for x in range(max(0, x0), min(im.width, x1)):
            im.putpixel((x, y), c)


def text(im, s, x, y, scale):
    for ch in s:
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    rect(im, x + gx * scale, y + gy * scale, x + (gx + 1) * scale, y + (gy + 1) * scale, INK)
        x += 4 * scale


def frame(w, h, index):
    """One frame: a head, a body in the facing's colour, two feet (one lifted
    when stepping), the frame number on the body and an arrow for the facing.
    The feet's lowest row is h - 2, like the game's own NPCs. -Elvie"""
    facing, step = FRAMES[index]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s = 2 if w >= 32 else 1                       # scale for small art
    bw = min(w - 2, 12 * s)                       # body width
    bx = (w - bw) // 2
    feet = h - 2                                  # lowest opaque row
    foot_h = 2 * s
    body_bot = feet + 1 - foot_h
    body_top = max(h // 2 - 2 * s, body_bot - 10 * s)
    head = min(8 * s, body_top)
    hx = (w - head) // 2
    rect(im, hx, body_top - head, hx + head, body_top, SKIN)
    rect(im, bx, body_top, bx + bw, body_bot, DIR_COLOR[facing])
    # feet: left and right; step 1 lifts the left, step 2 the right
    fw = max(2, bw // 3)
    for side, lifted in ((0, step == 1), (1, step == 2)):
        fx = bx + 1 if side == 0 else bx + bw - 1 - fw
        lift = s if lifted else 0
        rect(im, fx, body_bot - lift, fx + fw, feet + 1 - lift, INK)
    # arrow on the head for the facing
    cx, cy = w // 2, body_top - head // 2
    if facing == "down":
        rect(im, cx - s, cy, cx + s, cy + 2 * s, INK)
    elif facing == "up":
        rect(im, cx - s, cy - 2 * s, cx + s, cy, INK)
    elif facing == "left":
        rect(im, hx, cy - s, hx + 2 * s, cy + s, INK)
    label = "B" if facing == "extra" else str(index)
    if s == 2 or label != "B":
        text(im, label, bx + (bw - 3 * s) // 2, body_top + s, s if bh_ok(body_bot - body_top, s) else 1)
    return im


def bh_ok(body_h, s):
    return body_h >= 6 * s


def sheet(w, h, n):
    out = Image.new("RGBA", (w, h * n), (0, 0, 0, 0))
    for i in range(n):
        out.alpha_composite(frame(w, h, i), (0, i * h))
    return out


SHEETS = {
    "frlg": {"NURSE": (32, 32, 10), "YOUNGSTER": (32, 32, 9), "LITTLE_BOY": (32, 32, 9),
             "BROCK": (16, 32, 9), "BUG_CATCHER": (16, 32, 10)},
    "rse": {"NURSE": (32, 32, 10), "YOUNGSTER": (32, 32, 9), "LITTLE_BOY": (32, 32, 9),
            "ROXANNE": (16, 32, 9), "RICH_BOY": (32, 32, 9)},
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = os.path.join(sys.argv[1], "assets", "npcs", "test_frames")
    for family, sheets in SHEETS.items():
        d = os.path.join(root, "gen3", family)
        os.makedirs(d, exist_ok=True)
        for name, (w, h, n) in sheets.items():
            sheet(w, h, n).save(os.path.join(d, name + ".png"))
    with open(os.path.join(root, "meta.json"), "w") as f:
        json.dump({"label": "TEST FRAMES", "credit": ["Test frames by Elvie"], "test": True}, f, indent=2)
        f.write("\n")
    print("wrote", root)


if __name__ == "__main__":
    main()

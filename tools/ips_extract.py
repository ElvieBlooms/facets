#!/usr/bin/env python3
"""Pulls everything an IPS patch changes out of FireRed, sorted by kind,
using your own FireRed 1.0 ROM. Nothing is patched on disk: each patch
is applied to a copy in memory.

  python3 ips_extract.py <FireRed 1.0 ROM> <mod folder> <patch.ips | folder | .zip> [...]
      [--out <folder>] [--sym <pokefirered.sym>]

A folder or .zip is searched for .ips files (zips inside folders too).
For each patch, every changed piece of the ROM is named with pret's
FireRed symbols (pokefirered.sym: downloaded from GitHub the first
time and kept beside this tool, or given with --sym) and sorted:
audio, tilesets, battle backgrounds, battle UI, battle animations,
Pokemon, trainers, overworld, windows and fonts, items, menus, maps
and scripts, text, code, and new data nothing points at. A piece the
patch moved elsewhere is followed through the pointers to it. Each
lands in <out>/<patch>/<kind>/ as its bytes (unpacked if LZ77), with
a PNG for graphics (coloured by its palette when one goes with it by
name, else grey), a palette swatch for palettes, and a WAV for sound
samples; songs stay as their raw sequence data. <out>/<patch>/
report.md lists it all. --out is <mod folder>/extracted by default.

The option-menu frames, dialogue box and signpost box also become a
Facets window set (assets/windows/x_<patch>/) when a patch changes them.

The art and sound are the patch authors'. If they took them from
another game (many DS-style patches do), they're that game's: keep
them on your own machine. Facets' .gitignore keeps extracted/ and
assets/windows/ out unless a set is listed there. Needs Pillow. -Elvie
"""
import hashlib, io, json, os, re, struct, sys, urllib.request, wave, zipfile
from PIL import Image

FIRERED_10_SHA1 = "41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"
GBA = 0x08000000

# pokefirered: the text window art, as the engine's importer reads it
# (src/import/gba/text_chrome_extract.lua) -Elvie
USER_FRAMES_TABLE = 0x471E8C   # 10 x { tiles*, palette* } -Elvie
USER_FRAME_COUNT = 10
DIALOGUE = (0x41F1C8, 18, 6, 0x471DEC)   # tiles, count, tiles across, palette -Elvie
SIGN = (0x470B0C, 19, 5, 0x471E0C)


# --------------------------------------------------
# IPS and LZ77
# --------------------------------------------------

def apply_ips(rom, patch):
    """rom: bytearray, patched in place. -Elvie"""
    if patch[:5] != b"PATCH":
        raise ValueError("not an IPS patch")
    i = 5
    while i + 3 <= len(patch):
        if patch[i:i + 3] == b"EOF":
            i += 3
            if i + 3 <= len(patch):  # truncation extension -Elvie
                del rom[int.from_bytes(patch[i:i + 3], "big"):]
            break
        off = int.from_bytes(patch[i:i + 3], "big")
        size = int.from_bytes(patch[i + 3:i + 5], "big")
        i += 5
        if size:
            data = patch[i:i + size]
            i += size
        else:  # run of one byte -Elvie
            run = int.from_bytes(patch[i:i + 2], "big")
            data = bytes([patch[i + 2]]) * run
            i += 3
        end = off + len(data)
        if end > len(rom):
            rom.extend(b"\xff" * (end - len(rom)))
        rom[off:end] = data
    return rom


def lz77(rom, off):
    """GBA LZ77 (type 0x10), or None. -Elvie"""
    if off + 4 > len(rom) or rom[off] != 0x10:
        return None
    size = int.from_bytes(rom[off + 1:off + 4], "little")
    if size <= 0 or size > 0x40000:
        return None
    out, i = bytearray(), off + 4
    try:
        while len(out) < size:
            flags = rom[i]
            i += 1
            for bit in range(8):
                if len(out) >= size:
                    break
                if flags & (0x80 >> bit):
                    b1, b2 = rom[i], rom[i + 1]
                    i += 2
                    n = (b1 >> 4) + 3
                    disp = ((b1 & 0xF) << 8 | b2) + 1
                    if disp > len(out):
                        return None
                    for _ in range(n):
                        out.append(out[-disp])
                else:
                    out.append(rom[i])
                    i += 1
    except IndexError:
        return None
    return bytes(out[:size])


def u32(rom, off):
    return int.from_bytes(rom[off:off + 4], "little") if off + 4 <= len(rom) else 0


def refs_to(rom, target):
    """Every 4-aligned word in the ROM pointing at target. -Elvie"""
    want = (GBA + target).to_bytes(4, "little")
    out, start = [], 0
    while True:
        i = rom.find(want, start)
        if i < 0:
            return out
        if i % 4 == 0:
            out.append(i)
        start = i + 1


def moved(vanilla, patched, target, refs=None):
    """Where the patched ROM's pointers to target now lead. -Elvie"""
    refs = refs if refs is not None else refs_to(vanilla, target)
    votes = {}
    for r in refs:
        p = u32(patched, r)
        if GBA <= p < GBA + len(patched):
            votes[p - GBA] = votes.get(p - GBA, 0) + 1
    if not votes:
        return target
    # a changed pointer wins over the unchanged ones -Elvie
    changed = {k: v for k, v in votes.items() if k != target}
    pool = changed or votes
    return max(pool, key=pool.get)


def tile_bytes(rom, off, count):
    """count 4bpp tiles at off, raw or LZ77. -Elvie"""
    unpacked = lz77(rom, off)
    if unpacked is not None and len(unpacked) >= count * 32:
        return unpacked[:count * 32]
    return bytes(rom[off:off + count * 32])


def palette(rom, off):
    """16 colours; colour 0 is see-through. -Elvie"""
    unpacked = lz77(rom, off)
    raw = unpacked if unpacked is not None and len(unpacked) >= 32 else rom[off:off + 32]
    out = []
    for i in range(16):
        c = int.from_bytes(raw[i * 2:i * 2 + 2], "little")
        out.append(tuple(round((c >> s & 31) * 255 / 31) for s in (0, 5, 10)))
    return out


def tiles_image(data, count, across, pal):
    rows = (count + across - 1) // across
    img = Image.new("RGBA", (across * 8, rows * 8), (0, 0, 0, 0))
    px = img.load()
    for t in range(count):
        tx, ty = t % across, t // across
        for y in range(8):
            for b in range(4):
                byte = data[t * 32 + y * 4 + b] if t * 32 + y * 4 + b < len(data) else 0
                for k, v in enumerate((byte & 15, byte >> 4)):
                    if v:
                        r, g, bl = pal[v]
                        px[tx * 8 + b * 2 + k, ty * 8 + y] = (r, g, bl, 255)
    return img


# --------------------------------------------------
# One patch
# --------------------------------------------------

class Art:
    def __init__(self, vanilla):
        self.vanilla = vanilla
        self.refs = {}

    def r(self, target):
        if target not in self.refs:
            self.refs[target] = refs_to(self.vanilla, target)
        return self.refs[target]

    def piece(self, rom, tiles_off, count, across, pal_off):
        t = moved(self.vanilla, rom, tiles_off, self.r(tiles_off))
        p = moved(self.vanilla, rom, pal_off, self.r(pal_off))
        data, pal = tile_bytes(rom, t, count), palette(rom, p)
        return data, pal

    def frames(self, rom):
        table = moved(self.vanilla, rom, USER_FRAMES_TABLE, self.r(USER_FRAMES_TABLE))
        out = []
        for n in range(USER_FRAME_COUNT):
            t, p = u32(rom, table + n * 8) - GBA, u32(rom, table + n * 8 + 4) - GBA
            if not (0 <= t < len(rom) and 0 <= p < len(rom)):
                out.append(None)
                continue
            out.append((tile_bytes(rom, t, 9), palette(rom, p)))
        return out


def fill_colour(pal):
    """Gen 3 fills a window with colour 1. -Elvie"""
    return list(pal[1])


def extract(art, vanilla_rom, patched):
    """The pieces this patch changed: { name: (image, palette) }. -Elvie"""
    out = {}
    vf, pf = art.frames(vanilla_rom), art.frames(patched)
    for n in range(USER_FRAME_COUNT):
        if pf[n] and pf[n] != vf[n]:
            data, pal = pf[n]
            out["frame_%d" % (n + 1)] = (tiles_image(data, 9, 3, pal), pal)
    for name, (off, count, across, pal_off) in (("dialogue", DIALOGUE), ("sign", SIGN)):
        before = art.piece(vanilla_rom, off, count, across, pal_off)
        after = art.piece(patched, off, count, across, pal_off)
        if after != before:
            out[name] = (tiles_image(after[0], count, across, after[1]), after[1])
    return out


def credits_beside(files):
    """Credit lines from a #CREDITS.txt, or a README's 'credit' lines. -Elvie"""
    lines = []
    for name, text in files:
        base = os.path.basename(name).lower()
        if "credit" in base:
            lines += [l.strip() for l in text.splitlines() if l.strip()][:6]
        elif "readme" in base:
            lines += [l.strip() for l in text.splitlines() if re.search(r"credit", l, re.I)][:3]
    return lines


def slug(name):
    s = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    return s[:40] or "patch"


def write_set(mod, name, pieces, credit, source):
    key = "x_" + slug(name)
    out_dir = os.path.join(mod, "assets", "windows", key)
    os.makedirs(out_dir, exist_ok=True)
    styles = []
    frames = sorted((k for k in pieces if k.startswith("frame_")), key=lambda k: int(k.split("_")[1]))
    for k, (img, _) in pieces.items():
        img.save(os.path.join(out_dir, k + ".png"))
    common = {}
    if "dialogue" in pieces:
        common["dialogue"] = "dialogue.png"
        common["fill"] = fill_colour(pieces["dialogue"][1])
    if "sign" in pieces:
        common["sign"] = "sign.png"
        common["signFill"] = fill_colour(pieces["sign"][1])
    if frames:
        for k in frames:
            st = {"name": k.split("_")[1], "frame": k + ".png"}
            st.update(common)
            styles.append(st)
    else:
        st = {"name": "1"}
        st.update(common)
        styles.append(st)
    meta = {"label": name.upper()[:12], "credit": credit or ["From " + source],
            "from": source, "styles": styles}
    with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return key, len(styles)


# --------------------------------------------------
# Everything else: pret's symbols, sorted by kind
# --------------------------------------------------

SYM_URL = "https://raw.githubusercontent.com/pret/pokefirered/symbols/pokefirered.sym"

# the first segment of a map's own symbols (FiveIsland_ResortGorgeous_...) -Elvie
MAP_WORDS = r"(City|Town|Island|Islands|Route\d+|Forest|Cave|Tunnel|Tower|Mansion|Plateau|Road|Co|Gym|Mart|Center|Lab|House|Hideout|Path|Cape|Valley|Ruins|Chamber|Ship|Mountain|Moon|Woods|Den|Rock|Pass|Gate|Park|Zone|Lake|Lagoon|Grotto|Room|Corner|Isle|Rock|Rocks|Tree|Water|Bay|Hill|Point|Reef|Spot|Fields|Peak)_"

KINDS = [
    ("audio", r"^(mus_|se_|ph_|voicegroup|DirectSoundWaveData|ProgrammableWaveData|Cry_|gSongTable|gCryTable|gMPlay|keysplit|gCgb)"),
    ("tilesets", r"^(gTileset|sTileset|gMetatile|sMetatile|MetatileBehavior)"),
    ("battle_backgrounds", r"^(sBattleTerrain|gBattleTerrain|gBattleBgTemplates)"),
    ("battle_anims", r"^(gBattleAnim|sBattleAnim|gFile_graphics_battle_anims|gBattleAnimSprite|gBattleAnimBg|Move_|General_|Special_|Status_|AnimTask_|gAnimTask|sAnimTask)"),
    ("battle_scripts", r"^(BattleScript_|gBattleScripts|gBattleScriptsFor)"),
    ("battle_ui", r"^(gBattleInterface|gHealthbox|sTextbox_|gBattleTextbox|sBattleTextbox|gBattle|sBattle)"),
    ("pokemon", r"^(gMon|sMon|gPokemon|sPokemon|sPicTable_)|LevelUpLearnset|PokedexText|Evolution|BaseStats|EggMoves|TMHMLearnset"),
    ("trainers", r"^(gTrainer|sTrainer)"),
    ("overworld", r"^(gObjectEvent|sObjectEvent|gFieldEffect|sFieldEffect|FldEff)"),
    ("windows_fonts", r"^(gTextWindow|gUserFrames|sUserFrame|gMenuMessageWindow|gSignpost|gStdFrame|gFont|sFont|sTextWindow|gStandardMenuPalette|sDownArrow|sDoubleArrow|sDarkDownArrow|gFireRedMenuElements|sKeypadIcon|gKeypadIcon)"),
    ("items", r"^(gItemIcon|gItem|sItemIcon|DecorGfx_|DecorDesc_)"),
    ("menus", r"^(gFile_graphics|sBag|gBag|sParty|gParty|sSummary|gSummary|sPokedex|gPokedex|sDex|gDex|sStartMenu|sOption|gTitle|sTitle|sMainMenu|sNaming|gNaming|sPSS|gPSS|sWallpaper|gWallpaper|sShop|gShop|sTMCase|gTMCase|sBerryPouch|gBerryPouch|sMenu|gMenu|sHelp|gHelp|sWindowTemplate|gWindowTemplate|sBgTemplate|sTownMap|gTownMap|sRegionMap|gRegionMap|sTrainerCard|gTrainerCard)"),
    ("text", r"^(gText_|sText_|gString|sString|gExpandedPlaceholder|sEasyChat|gEasyChat|sEasy|gMoveNames|gSpeciesNames|gAbilityNames|gTypeNames|gMoveDescription|sMapsecName|gMapsecName|gCreditsString|gFameChecker|sBerryDescription)|_Text_|Text$|Texts$"),
    ("maps_scripts", r"(LandMons|WaterMons|FishingMons|RockSmashMons|^gMapGroup|^gMapHeader|^sMapsec|EventScript|MapScripts|Movement_|_OnTransition|_OnFrame|_OnWarp|_OnLoad|_OnResume|_OnReturn|Map_|_Layout|_MapHeader|_MapEvents|_ObjectEvents|_Warps|_CoordEvents|_BgEvents|^gStdScripts|^Std_|^Common_|^EventScript_|^Route\d+)|^[A-Z][A-Za-z]*" + MAP_WORDS),
    ("menus2", r"^(sMultichoice|gMultichoice)"),
    ("sprite_tables", r"^(sAnim|gAnim|sAffine|gAffine|sOam|gOam|sSpriteTemplate|gSpriteTemplate|sSpriteAnim|.*SpriteTemplate$|.*AffineAnim)"),
    # pictures and palettes nothing above claimed -Elvie
    ("graphics", r"(Gfx|Tiles|Tilemap|Pic|Icon|Image|Sheet|Pal|Palette|Palettes)(_|$|\d)|_(Gfx|Tiles|Tilemap|Pal)"),
    ("code", r"^([A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)*_?|_[A-Za-z][A-Za-z0-9_]*|[a-z][a-z0-9]*(_[A-Za-z0-9]+)+_?|sub_[0-9A-Fa-f]+|nullsub_.*|\.gcc2_compiled\.?|\.text|start_vector|intr_main|loop|jump_intr|intr_return)$"),
]


def kind_of(name):
    for kind, pat in KINDS:
        if re.search(pat, name):
            return "menus" if kind == "menus2" else kind
    return "other"


def load_symbols(path=None):
    """[(start, end, name, sized)] for ROM symbols, sorted; an unsized one
    (audio and script labels) runs to the next symbol. -Elvie"""
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pokefirered.sym")
    path = path or here
    if not os.path.exists(path):
        print("fetching pret's FireRed symbols once: " + SYM_URL)
        with urllib.request.urlopen(SYM_URL) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.split()
        if len(parts) < 4:
            continue
        try:
            addr, size = int(parts[0], 16), int(parts[2], 16)
        except ValueError:
            continue
        if GBA <= addr < GBA + 0x2000000:
            rows.append((addr - GBA, size, parts[3]))
    rows.sort()
    out = []
    for i, (a, size, name) in enumerate(rows):
        nxt = rows[i + 1][0] if i + 1 < len(rows) else a + max(size, 4)
        end = a + size if size else min(nxt, a + 0x10000)
        if end <= a:
            end = nxt if nxt > a else a + 4
        out.append((a, end, name, bool(size)))
    return out


class Symbols:
    def __init__(self, rows):
        import bisect
        self.rows = rows
        self.starts = [r[0] for r in rows]
        self.by_start = {}
        for r in rows:
            self.by_start.setdefault(r[0], r)
        self.by_name = {r[2]: r for r in rows}
        self.sized = {r[2]: r[3] for r in rows}
        self._bisect = bisect

    def at(self, off):
        """The symbol covering off, or None. -Elvie"""
        i = self._bisect.bisect_right(self.starts, off) - 1
        while i >= 0:
            a, e, n = self.rows[i][:3]
            if a <= off < e:
                return self.rows[i]
            if off - a > 0x10000:
                return None
            i -= 1
        return None

    def overlapping(self, start, end):
        i = max(0, self._bisect.bisect_right(self.starts, start) - 1)
        out = []
        while i < len(self.rows) and self.rows[i][0] < end:
            a, e, n = self.rows[i][:3]
            if e > start:
                out.append(self.rows[i][:3])
            i += 1
        return out


def changed_runs(vanilla, patched, records):
    """Byte ranges the patch really changed, merged across small gaps. -Elvie"""
    runs = []
    for off, length in records:
        i, end = off, off + length
        while i < end:
            if i >= len(vanilla) or vanilla[i] != patched[i]:
                j = i
                while j < end and (j >= len(vanilla) or vanilla[j] != patched[j]):
                    j += 1
                runs.append([i, j])
                i = j
            else:
                i += 1
    runs.sort()
    merged = []
    for a, b in runs:
        if merged and a - merged[-1][1] <= 16:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    return merged


def ips_records(patch):
    out, i = [], 5
    while i + 3 <= len(patch) and patch[i:i + 3] != b"EOF":
        off = int.from_bytes(patch[i:i + 3], "big")
        size = int.from_bytes(patch[i + 3:i + 5], "big")
        i += 5
        if size:
            out.append((off, size))
            i += size
        else:
            out.append((off, int.from_bytes(patch[i:i + 2], "big")))
            i += 3
    return out


def survey(vanilla, patched, records, syms):
    """{ name: { kind, how, start, end } } for everything changed. -Elvie"""
    runs = changed_runs(vanilla, patched, records)
    found, pointer_words = {}, set()
    # moved: a pointer to a symbol's start now points elsewhere -Elvie
    for a, b in runs:
        for w in range(a - a % 4, b, 4):
            v, p = u32(vanilla, w), u32(patched, w)
            if v == p or not (GBA <= v < GBA + len(vanilla)) or not (GBA <= p < GBA + len(patched)):
                continue
            target = syms.by_start.get(v - GBA)
            if not target:
                continue
            pointer_words.add(w)
            name = target[2]
            new = p - GBA
            end = new + (target[1] - target[0])
            if not target[3]:
                # no size known: only as far as the patch wrote -Elvie
                for ra, rb in runs:
                    if ra <= new < rb:
                        end = min(end, rb)
            found.setdefault(name, {"kind": kind_of(name), "how": "moved", "start": new, "end": end})
    # edited in place: changed bytes inside a symbol (pointer swaps aside) -Elvie
    claimed = [(v["start"], v["end"]) for v in found.values()]
    for a, b in runs:
        bytes_left = [i for i in range(a, b) if (i - i % 4) not in pointer_words]
        if not bytes_left:
            continue
        lo, hi = bytes_left[0], bytes_left[-1] + 1
        if any(ca <= lo and hi <= ce for ca, ce in claimed):
            continue
        hits = [r for r in syms.overlapping(lo, hi) if r[0] < len(vanilla)
                and any(r[0] <= i < r[1] for i in bytes_left)]
        fresh = lo >= len(vanilla) or all(vanilla[i] == 0xFF for i in range(lo, min(hi, len(vanilla))))
        if hits and not fresh:
            for sa, se, name in hits:
                found.setdefault(name, {"kind": kind_of(name), "how": "edited", "start": sa, "end": se})
        else:
            name = "new_%06X" % lo
            found.setdefault(name, {"kind": "new_data", "how": "new", "start": lo, "end": hi})
    return found


GFX = re.compile(r"(Tiles|Gfx|Pic|Icon|Glyphs|Image|Sheet)(_|$)")
PAL = re.compile(r"(Pal|Palette|Palettes)(_|$)")


def blob(rom, start, end):
    unpacked = lz77(rom, start)
    if unpacked is not None:
        return unpacked, True
    return bytes(rom[start:end]), False


def palette_for(name, syms, located):
    """A palette named like the picture, as (start, end) in the patched ROM. -Elvie"""
    tries = []
    for a, b in (("Tiles", "Palettes"), ("Tiles", "Palette"), ("FrontPic", "Palette"), ("BackPic", "Palette"),
                 ("Gfx", "Pal"), ("Gfx", "Palette"), ("Pic", "Pal"), ("Pic", "Palette"), ("Icon", "IconPalette")):
        if a in name:
            tries.append(name.replace(a, b, 1))
    for t in tries:
        if t in located:
            return located[t]
        if t in syms.by_name:
            r = syms.by_name[t]
            return (r[0], r[1])
    return None


def palettes_from(data):
    pals = []
    for k in range(0, min(len(data), 32 * 16) - 31, 32):
        pals.append([tuple(round((int.from_bytes(data[k + i * 2:k + i * 2 + 2], "little") >> s & 31) * 255 / 31)
                           for s in (0, 5, 10)) for i in range(16)])
    return pals


def tiles_png(data, pal, across):
    count = len(data) // 32
    if count == 0:
        return None
    grey = [(0, 0, 0)] + [(255 - i * 17,) * 3 for i in range(1, 16)]
    img = tiles_image(data, count, min(across, count), pal or grey)
    return img


def font_png(data):
    """Gen 3 glyphs: 2bpp 8x8 tiles, four a glyph (16x16, normal) or two
    (8x16, small); ink black, shadow grey. -Elvie"""
    per = 64 if len(data) >= 32768 else 32
    n = len(data) // per
    if n == 0:
        return None
    cols, gw = 32, 16 if per == 64 else 8
    img = Image.new("RGB", (cols * gw, ((n + cols - 1) // cols) * 16), (255, 255, 255))
    px = img.load()
    shade = {1: (0, 0, 0), 2: (170, 170, 170), 3: (90, 90, 90)}
    for g in range(n):
        ox, oy = (g % cols) * gw, (g // cols) * 16
        subs = ((0, 0), (8, 0), (0, 8), (8, 8)) if per == 64 else ((0, 0), (0, 8))
        for k, (sx, sy) in enumerate(subs):
            base = g * per + k * 16
            for y in range(8):
                for x in range(8):
                    byte = data[base + y * 2 + (1 - x // 4)] if base + y * 2 + 1 < len(data) else 0
                    v = byte >> ((3 - x % 4) * 2) & 3
                    if v:
                        px[ox + sx + x, oy + sy + y] = shade[v]
    return img


def swatch_png(data):
    pals = palettes_from(data)
    if not pals:
        return None
    img = Image.new("RGB", (16 * 8, len(pals) * 8))
    for r, pal in enumerate(pals):
        for c, col in enumerate(pal):
            img.paste(col, (c * 8, r * 8, c * 8 + 8, r * 8 + 8))
    return img


def sample_wav(data, path):
    """A DirectSound sample: 16-byte header, then signed 8-bit PCM. -Elvie"""
    if len(data) < 16:
        return False
    kind, _flags, pitch, _loop, size = struct.unpack("<HHIII", data[:16])
    if kind != 0 or size <= 0 or size + 16 > len(data) + 1:
        return False
    rate = max(4000, min(48000, pitch // 1024)) if pitch else 13379
    pcm = bytes((b + 128) & 0xFF for b in data[16:16 + size])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(rate)
        w.writeframes(pcm)
    return True


USED = set()


def export(out_root, patch_name, found, patched, syms, source=""):
    # same-named patches from different packs get their own folders -Elvie
    key = slug(patch_name)
    if key in USED and source:
        key = (key + "_" + slug(source.split(":")[0].rsplit(".", 1)[0]))[:60]
    base_key, n = key, 2
    while key in USED:
        key = "%s_%d" % (base_key, n)
        n += 1
    USED.add(key)
    base = os.path.join(out_root, key)
    located = {n: (v["start"], v["end"]) for n, v in found.items()}
    counts, lines = {}, []
    for name in sorted(found, key=lambda n: (found[n]["kind"], n)):
        v = found[name]
        kind = v["kind"]
        counts[kind] = counts.get(kind, 0) + 1
        files = []
        if kind != "code":
            d = os.path.join(base, kind)
            os.makedirs(d, exist_ok=True)
            data, packed = blob(patched, v["start"], v["end"])
            stem = os.path.join(d, re.sub(r"[^\w.-]", "_", name))
            with open(stem + ".bin", "wb") as f:
                f.write(data)
            files.append(os.path.basename(stem) + ".bin")
            img = None
            if re.search(r"Font.*Glyphs$", name):
                img = font_png(data)
            elif PAL.search(name) and not GFX.search(name):
                img = swatch_png(data)
            elif GFX.search(name) and "Tilemap" not in name:
                pal = None
                where = palette_for(name, syms, located)
                if where:
                    pals = palettes_from(blob(patched, *where)[0])
                    pal = pals[0] if pals else None
                across = 8 if re.search(r"(FrontPic|BackPic|TrainerFrontPic)", name) else 16
                img = tiles_png(data, pal, across)
            if img:
                img.save(stem + ".png")
                files.append(os.path.basename(stem) + ".png")
            if name.startswith("DirectSoundWaveData") and sample_wav(data, stem + ".wav"):
                files.append(os.path.basename(stem) + ".wav")
            size = "%d bytes%s" % (len(data), " unpacked" if packed else "")
        else:
            size = "%d bytes" % (v["end"] - v["start"])
        lines.append("| %s | %s | %s | 0x%06X | %s | %s |" % (
            kind, name, v["how"], v["start"], size, ", ".join(files)))
    os.makedirs(base, exist_ok=True)
    with open(os.path.join(base, "report.md"), "w", encoding="utf-8") as f:
        f.write("# %s\n\n" % patch_name)
        f.write(", ".join("%s %d" % (k, counts[k]) for k in sorted(counts)) + "\n\n")
        f.write("| kind | name | how | at | size | files |\n|---|---|---|---|---|---|\n")
        f.write("\n".join(lines) + "\n")
    return counts


# --------------------------------------------------
# Finding patches
# --------------------------------------------------

def patches_in(path):
    """(name, bytes, [(file, text)] beside it) for every .ips. -Elvie"""
    def from_zip(zbytes, where):
        try:
            z = zipfile.ZipFile(io.BytesIO(zbytes))
        except zipfile.BadZipFile:
            return
        names = [n for n in z.namelist() if not n.startswith("__MACOSX")]
        texts = {}
        for n in names:
            if n.lower().endswith(".txt"):
                try:
                    texts[n] = z.read(n).decode("utf-8", "replace")
                except Exception:
                    pass
        for n in names:
            low = n.lower()
            if low.endswith(".ips"):
                folder = os.path.dirname(n)
                beside = [(t, s) for t, s in texts.items() if os.path.dirname(t) == folder
                          or os.path.dirname(t) == os.path.dirname(folder)]
                yield os.path.splitext(os.path.basename(n))[0], z.read(n), beside, where + ":" + n
            elif low.endswith(".zip"):
                yield from from_zip(z.read(n), where + ":" + n)

    if os.path.isfile(path):
        if path.lower().endswith(".zip"):
            yield from from_zip(open(path, "rb").read(), os.path.basename(path))
        elif path.lower().endswith(".ips"):
            folder = os.path.dirname(path)
            beside = []
            for t in os.listdir(folder or "."):
                if t.lower().endswith(".txt"):
                    beside.append((t, open(os.path.join(folder, t), encoding="utf-8", errors="replace").read()))
            yield os.path.splitext(os.path.basename(path))[0], open(path, "rb").read(), beside, os.path.basename(path)
        return
    for root, _, files in os.walk(path):
        for f in sorted(files):
            if f.lower().endswith((".ips", ".zip")):
                yield from patches_in(os.path.join(root, f))


def option(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


def main():
    skip = set()
    for flag in ("--out", "--sym"):
        if flag in sys.argv:
            i = sys.argv.index(flag)
            skip.update({i, i + 1})
    args = [a for i, a in enumerate(sys.argv) if i > 0 and i not in skip and not a.startswith("--")]
    if len(args) < 3:
        sys.exit(__doc__)
    rom_path, mod = args[0], args[1]
    out_root = option("--out", os.path.join(mod, "extracted"))
    vanilla = bytearray(open(rom_path, "rb").read())
    sha = hashlib.sha1(vanilla).hexdigest()
    if sha != FIRERED_10_SHA1 and "--any-rom" not in sys.argv:
        sys.exit("That isn't FireRed 1.0 (BPRE, sha1 %s...). These patches are made for it, "
                 "and the art is found by its addresses." % FIRERED_10_SHA1[:8])
    syms = Symbols(load_symbols(option("--sym")))
    art = Art(vanilla)
    index, sets = [], 0
    for path in args[2:]:
        for name, patch, beside, source in patches_in(path):
            try:
                rom = apply_ips(bytearray(vanilla), patch)
            except Exception as e:
                print("skip %s: %s" % (source, e))
                continue
            found = survey(vanilla, rom, ips_records(patch), syms)
            if not found:
                print("%s: changes nothing" % source)
                continue
            counts = export(out_root, name, found, rom, syms, source)
            summary = ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts))
            index.append("| %s | %s | %s |" % (name, source, summary))
            line = "%s: %s" % (source, summary)
            pieces = extract(art, vanilla, rom)
            if pieces:
                key, n = write_set(mod, name, pieces, credits_beside(beside), source)
                sets += 1
                line += " (window set %s)" % key
            print(line)
    if index:
        os.makedirs(out_root, exist_ok=True)
        with open(os.path.join(out_root, "index.md"), "w", encoding="utf-8") as f:
            f.write("# Extracted patches\n\n| patch | from | changed |\n|---|---|---|\n")
            f.write("\n".join(index) + "\n")
    print("%d patch%s extracted to %s; %d window set%s." % (
        len(index), "" if len(index) == 1 else "es", out_root, sets, "" if sets == 1 else "s"))


if __name__ == "__main__":
    main()

"""A FireRed tileset patch's maps and tilesets, found the way the game finds them.

Follows the game's own pointers: gMapLayouts -> each map's header ->
its blocks, border and two tileset structs -> their tiles, palettes,
blocks and behaviours. Bytes come from, in order: what ips_extract saved
(exact patched bytes at a known address), the patch itself, and FireRed's
own values where they're known without a ROM (pret's layouts and
symbols, and free space). Anything still unknown is FireRed's own art and
is left out.

  python3 patch_layouts.py <extracted/patch> <patch .ips/.ups> <pokefirered.sym>
      <pret pokefirered checkout> <out>
  then: python3 tileset_package.py <out> <pret>/data/layouts/layouts.json ...

ips_extract.py names what it finds by FireRed's symbols, which goes wrong
when a patch resizes maps or points them at other tilesets. This reads
gMapGroups -> map headers -> layouts -> tileset structs instead, and
names each tileset by FireRed's struct at that address (slots.json).
The pret checkout needs data/layouts, data/maps and src/data/tilesets.
Set FRIMPORT to your FireRed import (.../firered/data/generated/gba) so
FireRed's palettes and blocks are known where the patch leaves them.
"""
import os, re, shutil, struct, sys, json

EXT, PATCH, SYM, PRET, OUT = sys.argv[1:6]
GBA = 0x08000000
SHIFT = 0

syms, by_addr = {}, {}
for line in open(SYM):
    q = line.split()
    if len(q) < 4: continue
    try: a, s = int(q[0], 16), int(q[2], 16)
    except ValueError: continue
    if GBA <= a < GBA + 0x1000000:
        syms[q[3]] = (a - GBA, s)
        by_addr.setdefault(a - GBA, []).append(q[3])

# --- the patch
p = open(PATCH, "rb").read()
xor, written, SRC, UPS = {}, {}, 0x1000000, p[:4] == b"UPS1"
if UPS:
    def var(i):
        v, s = 0, 1
        while True:
            x = p[i]; i += 1; v += (x & 0x7F) * s
            if x & 0x80: return v, i
            s <<= 7; v += s
    i = 4
    SRC, i = var(i); _, i = var(i)
    pos, end = 0, len(p) - 12
    while i < end:
        g, i = var(i); pos += g
        while i < end and p[i] != 0:
            xor[pos] = p[i]; pos += 1; i += 1
        i += 1; pos += 1
else:
    i = 5
    while i + 3 <= len(p) and p[i:i + 3] != b"EOF":
        off = int.from_bytes(p[i:i + 3], "big"); size = int.from_bytes(p[i + 3:i + 5], "big"); i += 5
        if size:
            for k in range(size): written[off + k] = p[i + k]
            i += size
        else:
            n = int.from_bytes(p[i:i + 2], "big")
            for k in range(n): written[off + k] = p[i + 2]
            i += 3

# --- what ips_extract saved: exact patched bytes from its start address
saved_raw, saved_unpacked = {}, {}
for line in open(os.path.join(EXT, "report.md"), encoding="utf-8"):
    c = [x.strip() for x in line.strip().strip("|").split("|")]
    if len(c) != 6 or not c[3].startswith("0x") or not c[5]: continue
    a = int(c[3], 16)
    f = os.path.join(EXT, c[0], c[5].split(", ")[0])
    if not f.endswith(".bin") or not os.path.exists(f): continue
    data = open(f, "rb").read()
    if "unpacked" in c[4]:
        saved_unpacked.setdefault(a, data)
    else:
        for k, x in enumerate(data): saved_raw.setdefault(a + k, x)

# --- FireRed's own bytes known without a ROM
FREE = [(0x72B860, 0xD00000), (0xEB0B20, 0x1000000)]
oracle = {}
def put(a, b):
    for k, x in enumerate(b): oracle.setdefault(a + k, x)
LAYOUTS = json.load(open(os.path.join(PRET, "data/layouts/layouts.json")))["layouts"]
def sym_addr(n):
    s = syms.get(n)
    return s[0] + GBA if s else None
table = syms["gMapLayouts"][0]
for i, l in enumerate(LAYOUTS):
    if "name" not in l:
        put(table + 4 * i, b"\0\0\0\0"); continue
    h = sym_addr(l["name"])
    if h is None: continue
    put(table + 4 * i, struct.pack("<I", h))
    parts = [sym_addr(l["name"] + "_Border"), sym_addr(l["name"] + "_Blockdata"),
             sym_addr(l["primary_tileset"]), sym_addr(l["secondary_tileset"])]
    if None not in parts:
        put(h - GBA, struct.pack("<ii4IBB", l["width"], l["height"], *parts,
                                 l.get("border_width", 2), l.get("border_height", 2)))
    for key, fp in (("_Blockdata", "blockdata_filepath"), ("_Border", "border_filepath")):
        a, f = syms.get(l["name"] + key), os.path.join(PRET, l.get(fp, ""))
        if a and os.path.isfile(f): put(a[0], open(f, "rb").read())
# map headers, the map groups, and each map's layout -Elvie
LAYOUT_INDEX = {l["id"]: i for i, l in enumerate(LAYOUTS) if "id" in l}
mg = json.load(open(os.path.join(PRET, "data/maps/map_groups.json")))
maps = {}
for d in os.listdir(os.path.join(PRET, "data/maps")):
    f = os.path.join(PRET, "data/maps", d, "map.json")
    if os.path.isfile(f):
        m = json.load(open(f)); maps[m["name"]] = m
GROUPS = []
for gi, g in enumerate(mg["group_order"]):
    put(syms["gMapGroups"][0] + 4 * gi, struct.pack("<I", sym_addr(g)))
    GROUPS.append(g)
    for mi, mn in enumerate(mg[g]):
        h = sym_addr(mn)
        if h is None: continue
        put(syms[g][0] + 4 * mi, struct.pack("<I", h))
        m = maps.get(mn)
        li = LAYOUT_INDEX.get(m["layout"]) if m else None
        if li is not None and sym_addr(LAYOUTS[li]["name"]):
            put(h - GBA, struct.pack("<I", sym_addr(LAYOUTS[li]["name"])))
            put(h - GBA + 18, struct.pack("<H", li + 1))
# tileset structs exactly as pret writes them (some share another
# tileset's tiles) -Elvie
hdr = open(os.path.join(PRET, "src/data/tilesets/headers.h")).read()
for m in re.finditer(r"const struct Tileset (gTileset_\w+) =\s*\{(.*?)\};", hdr, re.S):
    a = syms.get(m.group(1))
    if not a: continue
    f = dict(re.findall(r"\.(\w+)\s*=\s*([\w]+)", m.group(2)))
    def val(k):
        v = f.get(k, "NULL")
        if v in ("TRUE", "FALSE"): return 1 if v == "TRUE" else 0
        if v == "NULL": return 0
        return sym_addr(v) or (sym_addr(v.replace("_", "_", 1)) or None)
    vals = [val(k) for k in ("isCompressed", "isSecondary", "tiles", "palettes", "metatiles", "callback", "metatileAttributes")]
    if None in vals: continue
    put(a[0], struct.pack("<BBHIIIII", vals[0], vals[1], 0, vals[2], vals[3], vals[4], vals[5], vals[6]))

# FireRed's palettes, blocks and behaviours, from the player's own import
# (only read, to know which bytes the patch left alone) -Elvie
FRI = os.environ.get("FRIMPORT")
if FRI:
    tsd = os.path.join(FRI, "map_tree", "tilesets")
    for d in os.listdir(tsd):
        mj = os.path.join(tsd, d, "meta.json")
        if not os.path.exists(mj): continue
        meta = json.load(open(mj)); a = meta["ptr"] - GBA
        n = None
        for x in by_addr.get(a, []):
            if x.startswith("gTileset_"): n = x[len("gTileset_"):]
        if not n: continue
        put(a, bytes([1 if meta.get("compressed") else 0, 1 if meta.get("secondary") else 0]))
        for prefix, f in (("gTilesetPalettes_", "palettes.bin"), ("gMetatiles_", "metatiles.bin"),
                          ("gMetatileAttributes_", "attributes.bin")):
            s = syms.get(prefix + n)
            if s and os.path.exists(os.path.join(tsd, d, f)):
                put(s[0], open(os.path.join(tsd, d, f), "rb").read())

def vanilla(a):
    if a in oracle: return oracle[a]
    if a >= SRC: return 0
    if any(s <= a < e for s, e in FREE): return 0xFF
    return None

def rom(a):
    """A byte of the patched ROM, or None when it can't be known here"""
    if a in saved_raw: return saved_raw[a]
    if a in written: return written[a]
    v = vanilla(a)
    if v is None: return None
    return v ^ xor.get(a, 0) if UPS else v

def span(a, n):
    out = bytearray()
    for k in range(n):
        b = rom(a + k)
        if b is None: return None
        out.append(b)
    return bytes(out)

GUESSED = [0]
def span_lenient(a, n):
    """span(), but a few unknown bytes (under 1%) are taken from where the
    same data sits in FireRed, or 0 -Elvie"""
    out, miss = bytearray(), 0
    for k in range(n):
        b = rom(a + k)
        if b is None:
            miss += 1
            if miss > max(2, n // 100): return None
            v = vanilla(a + k - SHIFT) if SHIFT else None
            b = v if v is not None else 0
        out.append(b)
    GUESSED[0] += miss
    return bytes(out)

def u32(a):
    b = span(a, 4)
    return struct.unpack("<I", b)[0] if b else None

def ptr(v):
    return v - GBA if v and GBA <= v < GBA + 0x2000000 else None

def lz77(a):
    head = span(a, 4)
    if not head or head[0] != 0x10: return None
    size = head[1] | head[2] << 8 | head[3] << 16
    out, i = bytearray(), a + 4
    while len(out) < size:
        flags = rom(i); i += 1
        if flags is None: return None
        for bit in range(8):
            if len(out) >= size: break
            if flags & (0x80 >> bit):
                b = span(i, 2); i += 2
                if not b: return None
                n, d = (b[0] >> 4) + 3, ((b[0] & 15) << 8 | b[1]) + 1
                for _ in range(n): out.append(out[-d])
            else:
                b = rom(i); i += 1
                if b is None: return None
                out.append(b)
    return bytes(out[:size])

# --- maps
if os.path.exists(OUT): shutil.rmtree(OUT)
MS, TS = os.path.join(OUT, "maps_scripts"), os.path.join(OUT, "tilesets")
os.makedirs(MS); os.makedirs(TS)
need, uses, log = {}, {}, []
# where each layout really is: through the map headers, as the game finds
# it (a patch can move the layout table), else the layout table -Elvie
found_at = {}
for gi, g in enumerate(GROUPS):
    ga = ptr(u32(syms["gMapGroups"][0] + 4 * gi))
    if ga is None: continue
    for mi in range(len(mg[g])):
        ha = ptr(u32(ga + 4 * mi))
        if ha is None: continue
        lp, lid = u32(ha), span(ha + 18, 2)
        if lp is None or not lid: continue
        lid = struct.unpack("<H", lid)[0]
        if 1 <= lid <= len(LAYOUTS) and "name" in LAYOUTS[lid - 1]:
            found_at.setdefault(lid - 1, ptr(lp))
for i, l in enumerate(LAYOUTS):
    if "name" not in l: continue
    h = found_at.get(i)
    if h is None: h = ptr(u32(table + 4 * i))
    hb = span(h, 26) if h is not None else None
    if not hb:
        log.append("%s: header unknown" % l["name"]); continue
    w, hh, bp, mp, pp, sp = struct.unpack_from("<ii4I", hb)
    bw, bh = hb[24] or 2, hb[25] or 2
    if not (0 < w <= 1024 and 0 < hh <= 1024): continue
    blocks = span(ptr(mp), w * hh * 2) if ptr(mp) is not None else None
    border = span(ptr(bp), bw * bh * 2) if ptr(bp) is not None else None
    if not blocks:
        log.append("%s: blocks unknown" % l["name"]); continue
    name = l["name"]
    open(os.path.join(MS, name + ".bin"), "wb").write(hb + b"\0\0")
    open(os.path.join(MS, name + "_Blockdata.bin"), "wb").write(blocks)
    if border: open(os.path.join(MS, name + "_Border.bin"), "wb").write(border)
    for v in struct.unpack("<%dH" % (w * hh), blocks):
        m = v & 0x3FF
        key, idx = (pp, m) if m < 640 else (sp, m - 640)
        need[key] = max(need.get(key, 0), idx + 1)
    for t in (pp, sp): uses.setdefault(t, []).append(name.replace("_Layout", ""))

# --- tilesets, named by FireRed's struct at that address -Elvie
def slot(a):
    for n in by_addr.get(a - SHIFT, []):
        if n.startswith("gTileset_"): return n[len("gTileset_"):]
    return "At%06X" % a

slots = {}
for n, (a, _) in syms.items():
    if n.startswith("gTileset_"): slots["0x%06X" % (a + SHIFT + GBA)] = n
for sv in sorted(uses):
    a = ptr(sv)
    if a is None: continue
    n = slot(a)
    slots["0x%06X" % sv] = "gTileset_" + n
    st = span(a, 24)
    if not st:
        # flags and callback aren't known; the pointers are what matter -Elvie
        fields = [u32(a + o) for o in (4, 8, 12, 20)]
        if None in fields:
            log.append("%s: struct unknown" % n); continue
        st = struct.pack("<BBHIIIII", 0, 0, 0, fields[0], fields[1], fields[2], 0, fields[3])
    _, _, _, tp, palp, mp, _, ap = struct.unpack("<BBHIIIII", st)
    open(os.path.join(TS, "gTileset_%s.bin" % n), "wb").write(st)
    count = need.get(sv, 0)
    got = []
    if ptr(tp) is not None:
        t = saved_unpacked.get(ptr(tp)) or lz77(ptr(tp))
        if t is None and n.startswith("At"): t = span(ptr(tp), 0x4000)
        if t:
            open(os.path.join(TS, "gTilesetTiles_%s.bin" % n), "wb").write(t); got.append("tiles")
    for prefix, pv, size in (("gTilesetPalettes_", palp, 16 * 32), ("gMetatiles_", mp, count * 16),
                             ("gMetatileAttributes_", ap, count * 4)):
        if ptr(pv) is None or size == 0: continue
        b = span_lenient(ptr(pv), size)
        if b:
            open(os.path.join(TS, prefix + n + ".bin"), "wb").write(b); got.append(prefix.strip("_"))
    log.append("%s (0x%06X): %s; %d blocks; maps: %s" % (n, a, ", ".join(got) or "nothing known",
                                                         count, ", ".join(sorted(set(uses[sv])))))
json.dump(slots, open(os.path.join(TS, "slots.json"), "w"), indent=1)
shutil.copy(os.path.join(EXT, "report.md"), os.path.join(OUT, "report.md"))
open(os.path.join(OUT, "frompatch.md"), "w").write("\n".join(log) + "\n")
print("\n".join(x for x in log if "unknown" in x)[:3000])
print("guessed bytes", GUESSED[0]); print(len(os.listdir(MS)) // 3, "maps;", sum(1 for f in os.listdir(TS) if f.startswith("gTileset_")), "tilesets")

"""The set of every FireRed tile (4bpp, 32 bytes) and its flips, from the
player's own import. Used only to leave FireRed's own tiles out."""
import os
def flips(t):
    rows = [t[y * 4:y * 4 + 4] for y in range(8)]
    def hflip(r):
        return bytes(((b & 15) << 4) | (b >> 4) for b in reversed(r))
    h = b"".join(hflip(r) for r in rows)
    v = b"".join(reversed(rows))
    hv = b"".join(hflip(r) for r in reversed(rows))
    return (t, h, v, hv)
def load(root):
    s = set()
    for d in os.listdir(root):
        p = os.path.join(root, d, "tiles.4bpp")
        if not os.path.exists(p): continue
        b = open(p, "rb").read()
        for i in range(0, len(b) - 31, 32):
            for f in flips(b[i:i + 32]): s.add(f)
    return s
def plain(t):
    return len(set(((b & 15) for b in t)) | set((b >> 4 for b in t))) == 1

"""posdump.py: every figure in the running original's fight: number, name, cell and HP (DS:0x5F2A + 4i: flag, x, y;
the fight records DS:0x65B9; Combat Chat 3). Note: the figure numbering of the two tables can differ."""
import struct, trace as tr
p, img, psp, load = tr.where()
m = open(f"/proc/{p}/mem", "rb", 0)
base = img - load * 16
ds = base + psp * 16 + 0x100 + 0xC7C * 16
rd = lambda a, n: (m.seek(a), m.read(n))[1]
for i in range(1, 32):
    f0, x, y, b = rd(ds + 0x5F2A + 4 * i, 4)
    off, seg = struct.unpack("<HH", rd(ds + 0x65B9 + 4 * i, 4))
    if not seg: continue
    rec = base + seg * 16 + off
    name = rd(rec + 1, rd(rec, 1)[0]).decode("latin1")
    print("%2d %-15s %2d,%2d hp %d" % (i, name, x, y, rd(rec + 0x11B, 1)[0]))

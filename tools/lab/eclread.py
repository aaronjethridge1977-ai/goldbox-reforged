"""eclread.py <hex cell> [count]: ECL cells (words) in the running original (chat 29).
Cell N sits at the far pointer DS:0x49D2 + (2N + 0x6E00) & 0xFFFF (GAME.OVR 0x1FC04)."""
import sys, struct, seed as sd
p = sd.pid(); img = sd.find(p)
m = open(f"/proc/{p}/mem", "rb", 0)
m.seek(img - 0x110); psp = struct.unpack_from("<H", m.read(16), 1)[0]
base = img - (psp + 0x10) * 16; ds = (psp + 0x10 + 0xC7C) * 16
m.seek(base + ds + 0x49D2); off, seg = struct.unpack("<HH", m.read(4))
n0 = int(sys.argv[1], 16)
for n in range(n0, n0 + (int(sys.argv[2]) if len(sys.argv) > 2 else 1)):
    m.seek(base + seg * 16 + ((off + 2 * n + 0x6E00) & 0xFFFF))
    print("%04X %d" % (n, struct.unpack("<H", m.read(2))[0]))

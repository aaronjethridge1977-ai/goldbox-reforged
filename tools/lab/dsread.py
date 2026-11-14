"""dsread.py <hex addr> [count]: bytes at DS:addr in the running original."""
import sys, struct, seed as sd
p = sd.pid(); img = sd.find(p)
m = open(f"/proc/{p}/mem", "rb", 0)
m.seek(img - 0x110); psp = struct.unpack_from("<H", m.read(16), 1)[0]
base = img - (psp + 0x10) * 16; ds = (psp + 0x10 + 0xC7C) * 16
m.seek(base + ds + int(sys.argv[1], 16)); print(m.read(int(sys.argv[2]) if len(sys.argv) > 2 else 1).hex(" "))

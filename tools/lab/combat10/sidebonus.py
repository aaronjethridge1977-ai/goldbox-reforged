"""sidebonus.py: the running original's per-side to-hit bonuses ([DS:0x49D6]+0x6E0 monsters, +0x6E2 party; GAME.OVR
0x2BBF2) and the bytes round them."""
import struct, seed as sd
p = sd.pid(); img = sd.find(p)
m = open(f"/proc/{p}/mem", "rb", 0)
m.seek(img - 0x110); psp = struct.unpack_from("<H", m.read(16), 1)[0]
base = img - (psp + 0x10) * 16; ds = (psp + 0x10 + 0xC7C) * 16
m.seek(base + ds + 0x49D6); off, seg = struct.unpack("<HH", m.read(4))
m.seek(base + seg * 16 + off + 0x6D0); b = m.read(0x30)
print("[0x49D6] = %04x:%04x" % (seg, off))
print("+0x6D0:", b.hex(" "))
print("+0x6E0 (monsters) %d  +0x6E2 (party) %d" % (struct.unpack("b", b[0x10:0x11])[0], struct.unpack("b", b[0x12:0x13])[0]))

"""partyrec.py <name> ...: each named member's HP and status byte (record +0x11B, +0x10C)
from the running original's memory, found by the name (a Pascal string at the record's
start): PARTY <member number> <hp> <status>, as ours' partyhp key prints them (no names, so
the saved traces carry nothing from the game)."""
import sys, trace as tr
p, img, psp, load = tr.where()
m = open(f"/proc/{p}/mem", "rb", 0)
m.seek(img - load * 16); mem = m.read(0xA0000)          # guest linear 0 .. 640K
for k, name in enumerate(sys.argv[1:]):
    i = mem.find(bytes([len(name)]) + name.encode())
    print("PARTY %d %s" % (k + 1, "%d %d" % (mem[i + 0x11B], mem[i + 0x10C]) if i >= 0 else "?"))

"""fallen.py: the running original's fight: the fallen list (DS:0x66D6, 7 bytes: figure, x, y, covered ground; count
DS:0x6715), the figure table DS:0x5F2A and the ground (DS:0x6716 far pointer, y * 0x32 + x + 7) around the party
(Combat Chat 4: where a body lies; 0x1F is a body's ground). Run from the lab folder while a fight is on."""
import struct, sys
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import trace as tr
p, img, psp, load = tr.where()
m = open(f"/proc/{p}/mem", "rb", 0)
base = img - load * 16
ds = base + psp * 16 + 0x100 + 0xC7C * 16
rd = lambda a, n: (m.seek(a), m.read(n))[1]
n = rd(ds+0x6715,1)[0]; print("fallen", n)
for k in range(1, n+1):
    e = rd(ds+0x66D6+7*k, 7); off,seg = struct.unpack("<HH", e[:4]); rec=base+seg*16+off
    print(k, rd(rec+1, rd(rec,1)[0]).decode('latin1'), "x,y", e[4], e[5], "covered", hex(e[6]))
for i in range(1, 12):
    f0, x, y, b = rd(ds + 0x5F2A + 4 * i, 4); print("map fig", i, f0, x, y, b)
off,seg = struct.unpack("<HH", rd(ds+0x6716,4)); g = base+seg*16+off
for y in range(8,17):
    print(y, " ".join("%02x"%b for b in rd(g+y*0x32+20+7, 16)))

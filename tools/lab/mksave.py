"""Make a lab save for the original that jumps to another area on the first step.

  python3 mksave.py <base letter> <new letter (B-I)> <ecl file> <block> <x> <y> <facing N|E|S|W> [addr=val ...] [xp<n>=<experience>] [pp<n>=<platinum>] [strong]

The original's save holds the current area's script image from byte 0x1401 (base 0x9900).
This patches the script's "on move" entry (its first GOTO's target) to do what the game's
own boats and gates do: set the square (C04B/C04C/C04D) and the data set (6E12), then
NEW_ECL <block>. Load the save in the original and press Up once. addr=val writes a byte
of ECL memory 0x4900-0x4AFF in the save (hex address).
Character files CHRDAT<base>n are copied to CHRDAT<new>n.
"""
import glob, os, shutil, struct, sys
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "game")
base, new, n, b, x, y, f = sys.argv[1:8]
B, N = base.upper(), new.upper()
s = bytearray(open(os.path.join(G, "SAVGAM%s.DAT" % B), "rb").read())
on_move = struct.unpack_from("<H", s, 0x1401 + 2)[0]      # GOTO [addr] at 0x9900
o = 0x1401 + on_move - 0x9900
def wm(v, a):
    return bytes([0x09, 0x00, v, 0x01, a & 255, a >> 8])
patch = wm(int(x), 0xC04B) + wm(int(y), 0xC04C) + wm("NESW".index(f.upper()), 0xC04D) + wm(int(n), 0x6E12) + bytes([0x20, 0x00, int(b)])
s[o:o + len(patch)] = patch
strong = "strong" in sys.argv[8:]
xp = {}
pp = {}
for a in sys.argv[8:]:
    if a == "strong":
        continue
    if a.startswith("xp"):          # xp<n>=<experience> for character file n (1-6)
        k, v = a[2:].split("=")
        xp[int(k)] = int(v)
        continue
    if a.startswith("pp"):          # pp<n>=<platinum pieces> for character file n
        k, v = a[2:].split("=")
        pp[int(k)] = int(v)
        continue
    k, v = a.split("=")
    s[1 + 2 * (int(k, 16) - 0x4900)] = int(v, 0)
for k in range(8):
    p = 0x3209 + k * 41
    ln = s[p]
    if 0 < ln <= 12:
        s[p + 1:p + 1 + ln] = s[p + 1:p + 1 + ln].replace(b"CHRDAT" + B.encode(), b"CHRDAT" + N.encode())
for p in glob.glob(os.path.join(G, "CHRDAT%s?.*" % B)):
    shutil.copy(p, p.replace("CHRDAT" + B, "CHRDAT" + N))
if strong:   # lab only: 200 HP, AC -10, THAC0 1, so the walker survives late areas
    for p in glob.glob(os.path.join(G, "CHRDAT%s?.SAV" % N)):
        d = bytearray(open(p, "rb").read())
        d[0x32] = d[0x11B] = 200
        d[0xA9] = d[0x111] = 70
        d[0x2D] = d[0x110] = 59
        open(p, "wb").write(d)
for n_, v in xp.items():
    p_ = os.path.join(G, "CHRDAT%s%d.SAV" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    struct.pack_into("<I", d_, 0xAC, v)
    open(p_, "wb").write(d_)
for n_, v in pp.items():
    p_ = os.path.join(G, "CHRDAT%s%d.SAV" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    struct.pack_into("<H", d_, 0x88 + 4 * 2, v)
    open(p_, "wb").write(d_)
open(os.path.join(G, "SAVGAM%s.DAT" % N), "wb").write(s)
print("SAVGAM%s.DAT: first step goes to ECL%s block %s at %s,%s %s" % (N, n, b, x, y, f))

"""Lab (Combat Chat 1): after `mksave.py ... strong`, put each character's THAC0 bytes (0x2D, 0x110)
back to the base save's. The original ignores a file's THAC0 (it recomputes 0x2D from the class
tables before a fight: the strong save's THAC0 1 fought as THAC0 19-20 in DOSBox), ours uses it.
  python3 fixthac0.py <base letter> <new letter>"""
import os, sys
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "game")
b, n = sys.argv[1].upper(), sys.argv[2].upper()
for k in range(1, 7):
    src = os.path.join(G, "CHRDAT%s%d.SAV" % (b, k)); dst = os.path.join(G, "CHRDAT%s%d.SAV" % (n, k))
    if not os.path.exists(dst):
        continue
    s = open(src, "rb").read(); d = bytearray(open(dst, "rb").read())
    d[0x2D] = s[0x2D]; d[0x110] = s[0x110]
    open(dst, "wb").write(d)
    print(dst, d[0x2D], d[0x110])

"""missiles.py <video> <start> <end>: in a lab fight video, each frame's COMSPR sprite found on the 7x7 view
(the sprite id, flip and its top-left pixel within the view)."""
import sys, struct, subprocess
import os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dax import read_dax, EGA
from PIL import Image
d = read_dax(os.path.join(HERE, "game", "COMSPR.DAX"))
spr = {}
for k, b in d.items():
	h, w8 = struct.unpack_from("<HH", b, 0); w = w8 * 8
	px = {}
	for r in range(h):
		for c in range(w):
			v = b[17 + r * w8 * 4 + c // 2]; v = (v >> 4) if c % 2 == 0 else v & 15
			if v: px[(c, r)] = EGA[v]
	spr[k] = px
v, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-ss", str(t0), "-i", v, "-t", str(t1 - t0), "-vf", "scale=320:200:flags=neighbor,crop=168:168:8:8", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
n = 0
while True:
	b = p.stdout.read(168 * 168 * 3)
	if len(b) < 168 * 168 * 3: break
	im = Image.frombytes("RGB", (168, 168), b); P = im.load(); t = t0 + n / 30; n += 1
	best = []
	for k in sorted(spr):
		if k in (11, 139, 25, 153): continue
		px = spr[k]; pts = list(px.items())
		if len(pts) < 4: continue
		(c0, r0), col0 = pts[0]
		for y in range(-24, 168):
			for x in range(-24, 168):
				if not (0 <= x + c0 < 168 and 0 <= y + r0 < 168) or P[x + c0, y + r0] != col0: continue
				ok = all(0 <= x + c < 168 and 0 <= y + r < 168 and P[x + c, y + r] == col for (c, r), col in pts)
				if ok: best.append((k, x, y))
	print("%7.3f %s" % (t, " ".join("spr%d@%d,%d" % b for b in best)), flush=True)

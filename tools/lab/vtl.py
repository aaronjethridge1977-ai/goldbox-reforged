"""vtl.py <video> [start] [end]: timeline of a lab video (origvid.sh / oursvid.sh: the game area only, any 320x200 multiple).
Per frame: which regions changed (map, panel, row 24), with row 24's and the panel's text."""
import sys, subprocess, json, hashlib
import os
HERE = os.path.dirname(os.path.abspath(__file__))
from PIL import Image
FONT = json.load(open(os.path.join(HERE, "font.json")))
v = sys.argv[1]; t0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0; t1 = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-ss", str(t0), "-i", v, "-t", str(t1 - t0), "-vf", "scale=320:200:flags=neighbor", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
def text(im, row, c0=0, c1=40):
	out = ""
	for c in range(c0, c1):
		g = bytes(sum(1 << (7 - x) for x in range(8) if sum(im.getpixel((c*8+x, row*8+y))) > 60 and im.getpixel((c*8+x, row*8+y)) != (85, 85, 85)) for y in range(8)).hex()
		out += FONT.get(g, "?" if int(g, 16) else " ")
	return out.rstrip()
prev = {}; n = 0
while True:
	b = p.stdout.read(320*200*3)
	if len(b) < 320*200*3: break
	im = Image.frombytes("RGB", (320, 200), b); t = t0 + n / 30.0; n += 1
	reg = {"map": im.crop((8, 8, 176, 176)).tobytes(), "panel": im.crop((184, 8, 312, 184)).tobytes(), "row24": im.crop((0, 192, 320, 200)).tobytes()}
	ch = [k for k in reg if prev.get(k) != reg[k]]
	if ch:
		extra = ""
		if "row24" in ch: extra += " R24[" + text(im, 24).strip() + "]"
		if "panel" in ch: extra += " P[" + " / ".join(x for x in (text(im, r, 23, 39).strip("? ").strip() for r in range(1, 23)) if x) + "]"
		if "map" in ch:
			a = prev.get("map"); d = 0
			if a: d = sum(1 for i in range(0, len(a), 3) if a[i:i+3] != reg["map"][i:i+3])
			extra += " map(%d px)" % d
		print("%7.3f %s%s" % (t, ",".join(ch), extra))
	prev = reg

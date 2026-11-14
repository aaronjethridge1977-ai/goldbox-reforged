"""viewlog.py <secs>: logs the original's combat view while a fight runs: each change of the view's
top-left cell (bytes 2 and 3 of the battlefield record at DS:[0x6716]; GAME.OVR 0x30F0E sets them) and of the figures' cells (DS:0x5F2B, 4 bytes each: x, y, number, flag)."""
import sys, time, struct, seed as sd
p = sd.pid(); img = sd.find(p)
m = open(f"/proc/{p}/mem", "rb", 0)
m.seek(img - 0x110); psp = struct.unpack_from("<H", m.read(16), 1)[0]
base = img - (psp + 0x10) * 16; DS = base + (psp + 0x10 + 0xC7C) * 16
def rd(a, n):
	m.seek(DS + a); return m.read(n)
t0 = time.time(); last = None
while time.time() - t0 < float(sys.argv[1]):
	cells = rd(0x5F2B, 64); xr = rd(0x604B, 16); yr = rd(0x6093, 16)
	figs = []
	for i in range(16):
		x, y, k = cells[i*4:i*4+3]
		if k == 0: break
		figs.append((k, x, y))
	off, seg = struct.unpack("<HH", rd(0x6716, 4))
	m.seek(base + seg * 16 + off + 2); v = m.read(2)
	if figs:
		ox, oy = struct.unpack("bb", v)
		st = (ox, oy, tuple(figs))
		if st != last:
			moved = "" if last is None else " ".join("%d:%d,%d" % f for f, g in zip(figs, last[2]) if f != g)
			print("%7.3f view %d,%d%s" % (time.time() - t0, ox, oy, ("  moved " + moved) if moved else ""), flush=True)
			last = st
	time.sleep(0.004)

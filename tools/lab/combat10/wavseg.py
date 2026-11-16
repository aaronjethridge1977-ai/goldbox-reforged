#!/usr/bin/env python3
"""wavseg.py <wav> [row ...]: DOSBox's capture split into sounds (runs of signal separated by 50+ ms of silence), each one's
length and tone per driver tick (zero crossings in 1/236.7 s windows); with rows, each sound is matched against
sfx.py's rendering of those rows (the best row by mean tone difference over the shared ticks)."""
import os, struct, sys, wave
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx  # noqa: E402

w = wave.open(sys.argv[1])
ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
raw = w.readframes(n)
fmt = "<%dh" % (len(raw) // 2)
s = struct.unpack(fmt, raw)[::ch]
tick = rate / sfx.TICK_HZ
# a speaker square wave: the sign of the signal minus its local mean
segs, start, quiet = [], None, 0
for i in range(0, len(s), 64):
    blk = s[i:i + 64]
    loud = max(blk) - min(blk) > 2000
    if loud:
        if start is None:
            start = i
        quiet = 0
    elif start is not None:
        quiet += 64
        if quiet > rate * 0.05:
            segs.append((start, i - quiet + 64)); start = None
if start is not None:
    segs.append((start, len(s)))


def tones(a, b):
    """Tone per driver tick: rising crossings (hysteresis round the segment's middle), each interval's 1/period put in
    the tick window it ends in; a window with none is 0 (silence or a period longer than the window)."""
    blk = s[a:b]
    hi, lo = max(blk), min(blk)
    mid, hyst = (hi + lo) / 2, (hi - lo) / 4
    ups, state = [], blk[0] > mid
    for k, v in enumerate(blk):
        if not state and v > mid + hyst:
            state = True; ups.append(k)
        elif state and v < mid - hyst:
            state = False
    nt = int(len(blk) / tick)
    per = [[] for _ in range(nt + 1)]
    for k in range(1, len(ups)):
        per[min(int(ups[k] / tick), nt)].append(rate / (ups[k] - ups[k - 1]))
    return [round(sorted(p)[len(p) // 2]) if p else 0 for p in per[:nt]]


rows = [int(r) for r in sys.argv[2:]]
ref = {r: sfx.render(r)[1:] for r in rows}
for a, b in segs:
    tn = tones(a, b)
    line = "%7.2fs %5.2fs %3d ticks: %s" % (a / rate, (b - a) / rate, len(tn), " ".join(str(x) for x in tn[:16]))
    if rows:
        best = None
        for r, rs in ref.items():
            hz = [round(1193182 / v) if v else 0 for v in rs]
            k = min(len(hz), len(tn))
            if k == 0:
                continue
            d = sum(abs(hz[j] - tn[j]) for j in range(k)) / k + abs(len(hz) - len(tn)) * 5
            if best is None or d < best[0]:
                best = (d, r, len(hz))
        line += "  | best row %d (%d ticks), diff %.0f" % (best[1], best[2], best[0])
    print(line)

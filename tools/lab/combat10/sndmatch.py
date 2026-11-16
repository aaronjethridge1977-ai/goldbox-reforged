#!/usr/bin/env python3
"""sndmatch.py <capture.wav> [rows]: each sound in DOSBox's capture (runs of signal split by 50+ ms of silence) matched to
the sfx.py row it is: every row is rendered as a square wave and measured the same way (rising-crossing intervals,
hysteresis), and compared by length and the median tone of each quarter. Prints each sound, its best row and the
distance, then a count per row."""
import os, struct, sys, wave
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx  # noqa: E402


def load(path):
    w = wave.open(path)
    ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    if sw == 2:
        s = struct.unpack("<%dh" % (len(raw) // 2), raw)[::ch]
    else:
        s = [(b - 128) * 256 for b in raw[::ch]]
    return s, rate


def segments(s, rate):
    segs, start, quiet = [], None, 0
    for i in range(0, len(s), 64):
        blk = s[i:i + 64]
        if max(blk) - min(blk) > 2000:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 64
            if quiet > rate * 0.05:
                segs.append((start, i - quiet + 64)); start = None
    if start is not None:
        segs.append((start, len(s)))
    return segs


def signature(s, rate, a, b):
    """Length and the median tone of each quarter: rising edges are rises of over 3000 in 3 samples (DOSBox's
    speaker is a high-passed square wave: a spike at each edge)."""
    ups, last = [], -100
    for k in range(a + 3, b):
        if s[k] - s[k - 3] > 3000 and k - last > 8:
            ups.append(k)
        if s[k] - s[k - 3] > 3000:
            last = k
    q = [[] for _ in range(4)]
    for k in range(1, len(ups)):
        q[min(3, (ups[k] - a) * 4 // (b - a))].append(rate / (ups[k] - ups[k - 1]))
    med = [sorted(x)[len(x) // 2] if x else 0 for x in q]
    return (b - a) / rate, med


def row_wave(row, rate=48000):
    seq = sfx.render(row)
    per, acc, ph, out = rate / sfx.TICK_HZ, 0.0, 0.0, []
    for v in seq:
        acc += per; n = int(acc); acc -= n
        for _ in range(n):
            if v:
                ph = (ph + (1193182 / v) / rate) % 1.0
                out.append(8000 if ph < 0.5 else -8000)
            else:
                out.append(0)
    return out


def dist(x, y):
    d = abs(x[0] - y[0]) * 400            # seconds
    for f, g in zip(x[1], y[1]):
        d += abs(f - g) / max(f, g, 1) * 100
    return d


if __name__ == "__main__":
    s, rate = load(sys.argv[1])
    rows = [int(r) for r in sys.argv[2:]] or list(range(1, 20))
    refs = {}
    for r in rows:
        w = row_wave(r, rate)
        sg = segments(w, rate)
        if sg:
            refs[r] = signature(w, rate, sg[0][0], sg[-1][1])
    for r, v in refs.items():
        print("row %2d: %.3fs  %s" % (r, v[0], " ".join("%4.0f" % f for f in v[1])))
    count = {}
    for a, b in segments(s, rate):
        sig = signature(s, rate, a, b)
        best = min(refs, key=lambda r: dist(sig, refs[r]))
        count[best] = count.get(best, 0) + 1
        print("%7.2fs %.3fs %s | row %d dist %.0f" % (a / rate, sig[0], " ".join("%4.0f" % f for f in sig[1]), best,
                                                     dist(sig, refs[best])))
    print("per row:", dict(sorted(count.items())))

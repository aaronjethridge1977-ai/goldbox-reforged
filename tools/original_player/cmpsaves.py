"""Compares two of the original's saves byte for byte (the repeatability test: same save, seed and plan, two runs).

  cmpsaves.py <checkpoint dir A> <checkpoint dir B>

Each dir holds SAVGAM<x>.DAT and its CHRDAT<x>n files (player.py checkpoints). The save's ECL memory
(0x4900-0x52FF as words from byte 1) is reported by address; the rest by file offset; character files by name.
Prints IDENTICAL or one line per difference.
"""
import os, sys


def files(d):
    out = {}
    for f in os.listdir(d):
        u = f.upper()
        if u.startswith("SAVGAM"):
            out["SAVGAM"] = os.path.join(d, f)
        elif u.startswith("CHRDAT"):
            out["CHRDAT" + u[7:]] = os.path.join(d, f)    # slot letter dropped
    return out


def where(name, i):
    if name == "SAVGAM":
        if i == 0:
            return "data set"
        if 1 <= i < 0x1401:
            return "ECL %04X%s" % (0x4900 + (i - 1) // 2, " (high byte)" if (i - 1) % 2 else "")
        if 0x1401 <= i < 0x3201:
            return "script image %04X" % (0x9900 + i - 0x1401)
        return "offset %04X" % i
    return "offset %04X" % i


def compare(a, b):
    fa, fb = files(a), files(b)
    diffs = []
    for name in sorted(set(fa) | set(fb)):
        if name not in fa or name not in fb:
            diffs.append("%s only in %s" % (name, "A" if name in fa else "B"))
            continue
        x, y = open(fa[name], "rb").read(), open(fb[name], "rb").read()
        if name == "SAVGAM":     # the character file names inside differ only by slot letter
            x, y = bytearray(x), bytearray(y)
        if len(x) != len(y):
            diffs.append("%s: sizes %d and %d" % (name, len(x), len(y)))
        for i in range(min(len(x), len(y))):
            if x[i] != y[i]:
                if name == "SAVGAM" and 0x3209 <= i and chr(x[i]).isalpha() and chr(y[i]).isalpha():
                    continue      # a CHRDAT<slot> name
                diffs.append("%s %s: %d / %d" % (name, where(name, i), x[i], y[i]))
    return diffs


if __name__ == "__main__":
    d = compare(sys.argv[1], sys.argv[2])
    print("IDENTICAL" if not d else "\n".join(d[:200]) + "\n%d differences" % len(d))
    sys.exit(1 if d else 0)

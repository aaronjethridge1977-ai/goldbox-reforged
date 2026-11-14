"""Compares each combatant's sequence of cells in the original's trace and ours."""
import sys, re, collections
def moves(path, orig):
    m = collections.defaultdict(list)
    for l in open(path):
        if orig and l.startswith("POS "):
            for t in l[4:].split():
                k, xy = t.split(":"); m[int(k)].append(xy)
        if not orig:
            r = re.search(r"pos (\d+):(\S+)", l)
            if r and "Random" not in l: m[int(r[1])].append(r[2])
    return m
o, u = moves(sys.argv[1], True), moves(sys.argv[2], False)
for k in sorted(set(o) | set(u)):
    a = o.get(k, []); b = u.get(k, [])
    if k in o and a and a[0] == "": a = a[1:]
    print("%2d %s %s\n   orig %s\n   ours %s" % (k, "same" if a[-len(b):] == b or a == b else "DIFF", "", " ".join(a), " ".join(b)))

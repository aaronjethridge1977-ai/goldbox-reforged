"""Lines up the original's draws (trace.py run) and ours (tplog) and shows where they part."""
import re, sys
o = []; opos = {}; upos = {}
for l in open(sys.argv[1]):
    if l.startswith("POS "):
        opos.setdefault(len(o), []).append(l[4:].strip()); continue
    m = re.match(r"\s*(\d+)\s+\S+\s+(\S+)\s+n=(\d+)\s+->\s+(\d+)", l)
    if m: o.append((int(m[1]), m[2], int(m[3]), int(m[4])))
    elif "LOST" in l: o.append((None, "LOST", 0, 0))
u = []
for l in open(sys.argv[2]):
    if "pos " in l and "Random" not in l:
        upos.setdefault(len(u), []).append(l.split("pos ")[1].strip()); continue
    m = re.match(r"\s*#(\d+) (.*) Random\((\d+)\) = (\d+)", l)
    if m: u.append((int(m[1]), m[2], int(m[3]), int(m[4])))
print("original: %d draws (%d lost), ours: %d" % (len(o), sum(1 for x in o if x[1] == "LOST"), len(u)))
for i in range(max(len(o), len(u))):
    a = o[i] if i < len(o) else None; b = u[i] if i < len(u) else None
    # A draw right next to a lost stretch can carry the wrong size (the trace ring's race);
    # its size can't be trusted, so it isn't counted as a difference.
    edge = a is not None and b is not None and a[1] != "LOST" and a[2] != b[2] and (
        (i + 1 < len(o) and o[i + 1][1] == "LOST") or (i > 0 and o[i - 1][1] == "LOST"))
    if edge:
        print("  (draw %d next to lost ones: orig d%d=%d, ours %s d%d=%d; not counted)" % (i + 1, a[2], a[3], b[1], b[2], b[3]))
        continue
    if a is None or b is None or (a[1] != "LOST" and (a[2] != b[2] or a[3] != b[3])):
        print("first difference at draw %d:" % (i + 1))
        for j in range(max(0, i - 40), min(i + 8, max(len(o), len(u)))):
            a = o[j] if j < len(o) else ("", "", "", ""); b = u[j] if j < len(u) else ("", "", "", "")
            print("  %s%4d  orig %-24s d%-4s=%-4s | ours %-40s d%-4s=%s" % (">" if j == i else " ", j + 1, a[1], a[2], a[3], b[1], b[2], b[3]))
            if opos.get(j + 1) or upos.get(j + 1):
                print("         orig moves %-24s | ours moves %s" % (" ".join(opos.get(j + 1, [])), " ".join(upos.get(j + 1, []))))
        break
else:
    print("identical")

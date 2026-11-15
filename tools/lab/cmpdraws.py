"""Lines up the original's draws (trace.py run) and ours (tplog) and shows where they part;
then compares where every figure went, whether CONTINUE BATTLE was asked, and the party's HP
and status at the end. The last line is the verdict: MATCH, or what differs."""
import os, re, sys
# DRAWS_ONLY=1 (Combat Chat 7): the draws alone decide (a Player's trace logs figures 1-31 only
# and no end lines: 6:1's buccaneers run to figure 40).
DRAWS_ONLY = bool(os.environ.get("DRAWS_ONLY"))
o = []; opos = {}; upos = {}; omoves = {}; umoves = {}; ustart = []
oend = []; uend = []
for l in open(sys.argv[1]):
    if l.startswith("POS "):
        opos.setdefault(len(o), []).append(l[4:].strip())
        for t in l[4:].split():
            k, xy = t.split(":"); omoves.setdefault(int(k), []).append(xy)
        continue
    if l.startswith("PARTY ") or l.startswith("ASKED "):
        oend.append(l.strip()); continue
    m = re.match(r"\s*(\d+)\s+\S+\s+(\S+)\s+n=(\d+)\s+->\s+(\d+)", l)
    if m: o.append((int(m[1]), m[2], int(m[3]), int(m[4])))
    elif "LOST" in l: o.append((None, "LOST", 0, 0))
u = []
for l in open(sys.argv[2]):
    s = l.strip()
    if s.startswith("PARTY ") or s.startswith("ASKED "):
        uend.append(s); continue
    if s.startswith("cell "):
        ustart.append(s.rsplit(" ", 1)[1]); continue
    if "pos " in l and "Random" not in l:
        p = l.split("pos ")[1].strip()
        upos.setdefault(len(u), []).append(p)
        k, xy = p.split(":"); umoves.setdefault(int(k), []).append(xy)
        continue
    m = re.match(r"\s*#(\d+) (.*) Random\((\d+)\) = (\d+)", l)
    if m: u.append((int(m[1]), m[2], int(m[3]), int(m[4])))
lost = sum(1 for x in o if x[1] == "LOST")
print("original: %d draws (%d lost), ours: %d" % (len(o), lost, len(u)))
problems = []
if lost:
    problems.append("%d lost draws (unchecked)" % lost)
first = None
for i in range(max(len(o), len(u))):
    a = o[i] if i < len(o) else None; b = u[i] if i < len(u) else None
    # (old traces only) a draw right next to a lost stretch can carry the wrong size (the
    # old trace ring's race); its size can't be trusted, so it isn't counted as a difference.
    edge = lost and a is not None and b is not None and a[1] != "LOST" and a[2] != b[2] and (
        (i + 1 < len(o) and o[i + 1][1] == "LOST") or (i > 0 and o[i - 1][1] == "LOST"))
    if edge:
        print("  (draw %d next to lost ones: orig d%d=%d, ours %s d%d=%d; not counted)" % (i + 1, a[2], a[3], b[1], b[2], b[3]))
        continue
    if a is None or b is None or (a[1] != "LOST" and (a[2] != b[2] or a[3] != b[3])):
        first = i
        print("first difference at draw %d:" % (i + 1))
        for j in range(max(0, i - 40), min(i + 8, max(len(o), len(u)))):
            a = o[j] if j < len(o) else ("", "", "", ""); b = u[j] if j < len(u) else ("", "", "", "")
            print("  %s%4d  orig %-24s d%-4s=%-4s | ours %-40s d%-4s=%s" % (">" if j == i else " ", j + 1, a[1], a[2], a[3], b[1], b[2], b[3]))
            if opos.get(j + 1) or upos.get(j + 1):
                print("         orig moves %-24s | ours moves %s" % (" ".join(opos.get(j + 1, [])), " ".join(upos.get(j + 1, []))))
        problems.append("draws differ from %d of %d" % (i + 1, len(o)))
        break
else:
    print("draws: identical")
# Where everyone went. The original's cells are sampled as the trace polls (a step between two
# polls can be missed, and figures pass through odd cells while being placed), so its list must
# be a subsequence of ours, from ours' starting cell on, and end on the same cell.
if DRAWS_ONLY:
    print("positions and end: not compared (DRAWS_ONLY)")
if ustart and not DRAWS_ONLY:
    if first is not None:          # only the moves made before the draws part
        omoves = {}; umoves = {}
        for src, dst in ((opos, omoves), (upos, umoves)):
            for at in sorted(src):
                if at < first:
                    for t in src[at]:
                        k, _, xy = t.partition(":")
                        if k.isdigit(): dst.setdefault(int(k), []).append(xy)
    bad = []
    for k in range(len(ustart)):
        ours = [ustart[k]] + umoves.get(k, [])
        orig = omoves.get(k, [])
        if ustart[k] in orig:
            orig = orig[orig.index(ustart[k]):]
        # A diagonal step can be polled half done: the original writes x before y, so the trace
        # shows the cell (new x, old y) between the two (Combat Chat 1: the three "positions of 1
        # figure" verdicts were all this). Such a cell is left out when ours made that diagonal step.
        pairs = set(zip(ours, ours[1:]))
        xy = lambda c: tuple(int(v) for v in c.split(","))
        orig = [c for i, c in enumerate(orig) if not (0 < i < len(orig) - 1 and (orig[i - 1], orig[i + 1]) in pairs
                and xy(c) == (xy(orig[i + 1])[0], xy(orig[i - 1])[1]))]
        # A step that draws free attacks shows twice: the original moves the figure, puts it
        # back on its square while the blows land, then moves it again (Combat Chat 5: the
        # graveyard's turned spectre, 20,12 19,12 20,12 19,12 around two free attacks). The
        # repeat is left out when ours made that step.
        i = 0
        while i + 3 < len(orig):
            if orig[i] == orig[i + 2] and orig[i + 1] == orig[i + 3] and (orig[i], orig[i + 1]) in pairs:
                del orig[i + 2:i + 4]
            else:
                i += 1
        it = iter(ours)
        sub = all(c in it for c in orig)
        if not orig or not sub or orig[-1] != ours[-1]:
            bad.append("%d: orig %s | ours %s" % (k, " ".join(orig), " ".join(ours)))
    if bad:
        print("positions differ:"); [print("  " + b) for b in bad]
        problems.append("positions of %d figures" % len(bad))
    else:
        print("positions: every figure's cells agree (%d figures%s)" % (len(ustart), ", up to that draw" if first is not None else ""))
def _same_end(o, u):
    # A party record the original no longer holds ("PARTY n ?": the party was wiped and the
    # game left for its death screen, Combat Chat 2's 7:23 fight) matches ours' member at 0 HP.
    if len(o) != len(u):
        return False
    for a, b in zip(o, u):
        if a == b:
            continue
        if a.startswith("PARTY ") and a.endswith(" ?") and b.split()[:2] == a.split()[:2] and b.split()[2] == "0":
            continue
        return False
    return True
if (oend or uend) and not DRAWS_ONLY:
    uend = [x for x in uend if not (x.startswith("ASKED ") and not any(y.startswith("ASKED ") for y in oend) and any(y.endswith(" ?") for y in oend))]
    if _same_end(oend, uend):
        print("end: the same (%s)" % "; ".join(x.replace("PARTY ", "") for x in oend))
    else:
        print("end differs:\n  orig %s\n  ours %s" % (" | ".join(oend), " | ".join(uend)))
        problems.append("end of fight")
print("VERDICT: " + ("MATCH" if not problems else "; ".join(problems)))

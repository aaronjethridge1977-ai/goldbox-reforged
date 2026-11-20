#!/usr/bin/env python3
"""Player 34: OP_MAGICAT for a recording whose trace has no MAGIC lines (Combat Chat 34: the QUICK-caster family is
the replay's MAGIC timing). Fights in the trace start where a run of OVR:1efd6 draws (the monster colours) begins;
fights in the log are its "fight N ended" / "NOTE loss" lines, and an Alt-M before a fight's end belongs to it. Per
Alt-M fight, Player 24's rule (p24/magicat.py): the last spell weighing (OVR:0b16c) with no list before the first one
with a list, + 2. Run from the Player lab (reads logs/<run>.log and .trace.txt). Usage: magicat_all.py <run>"""
import re, sys
run = sys.argv[1]
rows = []
for line in open("logs/%s.trace.txt" % run, errors="replace"):
    m = re.match(r"\s*(\d+) \S+ OVR:(\w+)", line)
    if m:
        rows.append((int(m.group(1)), m.group(2)))
starts, prev = [], None
for d, a in rows:
    if a == "1efd6" and prev != "1efd6":
        starts.append(d)
    prev = a
fights, alt = [], False
for line in open("logs/%s.log" % run, errors="replace"):
    if " MAGIC alt+m " in line:
        alt = True
    if re.search(r"NOTE fight fight \d+ ended|NOTE loss the party was destroyed", line):
        fights.append(alt)
        alt = False
print("# %s: %d fights in the log, %d fight starts in the trace (%s); Alt-M in fights %s" % (
    run, len(fights), len(starts), ",".join(map(str, starts)), [i + 1 for i, a in enumerate(fights) if a]))
out = []
bounds = starts + [10 ** 9]
for i, a in enumerate(fights):
    if not a:
        continue
    if i >= len(starts):
        out.append("-")
        continue
    f = [r for r in rows if starts[i] <= r[0] < bounds[i + 1]]
    weigh = [(d, j + 1 < len(f) and f[j + 1][1] == "0b1cd") for j, (d, x) in enumerate(f) if x == "0b16c"]
    first = next((k for k, w in enumerate(weigh) if w[1]), None)
    if first is None:
        out.append("-")
    else:
        out.append(str(weigh[first - 1][0] + 2) if first else str(starts[i]))
print(",".join(out))

#!/usr/bin/env python3
"""Player 16: a run's trace cut to start where a from-checkpoint segment's draws start (cmpdraws.py lines the two up
from draw 1): finds ours' first draws (n, value) in the trace and writes the trace from there.
  slice.py <trace> <segment txt> <out trace>"""
import re, sys
tr, seg, out = sys.argv[1:4]
u = []
for l in open(seg):
    m = re.match(r"\s*#\d+ .*Random\((\d+)\) = (\d+)", l)
    if m:
        u.append((int(m[1]), int(m[2])))
    if len(u) >= 12:
        break
L = open(tr).read().split("\n")
D = [(i, int(m[1]), int(m[2])) for i, l in enumerate(L) for m in [re.match(r"\s*\d+\s+\S+\s+\S+\s+n=(\d+)\s+->\s+(\d+)", l)] if m]
for k in range(len(D) - len(u), -1, -1):      # the last place the 12 draws appear
    if [(n, v) for _, n, v in D[k:k + len(u)]] == u:
        open(out, "w").write("\n".join(L[D[k][0]:]))
        print("ours' first %d draws found at the trace's draw %d" % (len(u), k + 1))
        break
else:
    print("not found:", u)

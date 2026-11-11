"""Tour plan for an area: one square per event number, in nearest-next order by walking
distance from the start. python3 plan.py <geo> <block> <x,y>  -> prints "x,y x,y ..."."""
import sys, route as R
R.NE, R.SW, R.INFO, R.DOORS = R.load(int(sys.argv[1]), int(sys.argv[2]))
sx, sy = [int(v) for v in sys.argv[3].split(",")]
from collections import deque
def dist_from(s):
    d = {s: 0}; q = deque([s])
    while q:
        c = q.popleft()
        for k in range(4):
            if R.passable(c[0], c[1], k):
                n = (c[0] + R.DX[k], c[1] + R.DY[k])
                if n not in d:
                    d[n] = d[c] + 1; q.append(n)
    return d
reach = dist_from((sx, sy))
events = {}
for (x, y) in reach:
    e = R.event(x, y)
    if e:
        events.setdefault(e, []).append((x, y))
todo = set(events)
cur = (sx, sy); out = []
while todo:
    d = dist_from(cur)
    best = min(((d[s], e, s) for e in todo for s in events[e] if s in d), default=None)
    if best is None:
        break
    _, e, s = best
    todo.discard(e); out.append(s); cur = s
print(" ".join("%d,%d" % s for s in out))
unreached = sorted(set(R.event(x, y) for y in range(16) for x in range(16)) - set(events) - {0})
if unreached:
    print("unreachable events:", unreached, file=sys.stderr)

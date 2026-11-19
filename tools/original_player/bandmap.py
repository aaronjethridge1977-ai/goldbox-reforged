#!/usr/bin/env python3
"""Player 24: a wilderness band's passable squares from START.EXE's overland map (format as ours'
scripts/formats/overland_map.gd: 44x36 bytes, water / poisoned river stop the party), and a BFS route between two
band squares, printed as waypoints (each a straight run). Usage: bandmap.py <band 6|7|8> [x0,y0 x1,y1] [--river-ok]"""
import os, sys, collections
sys.path.insert(0, os.environ.get("OP_LAB", "/home/aaron/gbr/player_lab"))   # the lab's unexepack.py
from unexepack import unpack
W, H = 44, 36
img = unpack(open(os.path.join(os.environ.get("OP_GAME", "/home/aaron/gbr/player_lab/game"), "START.EXE"), "rb").read())
end = next(i for i in range(W * H, len(img) - 3) if img[i] == 0 and img[i+1] == 13 and img[i+2] == 26
           and img[i-1] == 0x4E and img[i-W] == 0x4E)
cells = img[end - W * H:end]
left = {6: 0, 7: 13, 8: 26}[int(sys.argv[1])]
def water(v): return v == 0x4E or 0x7E <= v <= 0x80 or 0x82 <= v <= 0x84 or 0xA8 <= v <= 0xAC or 0xAE <= v <= 0xB3 \
    or v == 0xBC or 0xDD <= v <= 0xDE or 0xE1 <= v <= 0xE9 or v == 0xF5
def river(v): return 0x66 <= v <= 0x6C or v == 0x72
rok = "--river-ok" in sys.argv
def ok(x, y):
    if not (0 <= x < 16 and 0 <= y < H): return False
    v = cells[y * W + left + x]
    return not water(v) and (rok or not river(v))
args = [a for a in sys.argv[2:] if not a.startswith("--")]
if not args:
    print("    " + "".join("%x" % (x % 16) for x in range(16)))
    for y in range(H):
        print("%3d " % y + "".join("." if ok(x, y) else ("r" if river(cells[y*W+left+x]) else "~") for x in range(16)))
    sys.exit()
a = tuple(int(v) for v in args[0].split(",")); b = tuple(int(v) for v in args[1].split(","))
prev = {a: None}; q = collections.deque([a])
while q:
    c = q.popleft()
    if c == b: break
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        n = (c[0] + dx, c[1] + dy)
        if n not in prev and ok(*n): prev[n] = c; q.append(n)
if b not in prev: print("no route"); sys.exit(1)
path = [b]
while prev[path[-1]]: path.append(prev[path[-1]])
path.reverse()
way = [p for i, p in enumerate(path[1:-1], 1) if (path[i-1][0] == p[0]) != (path[i+1][0] == p[0])] + [b]
print(len(path) - 1, "steps:", " ".join("%d,%d" % p for p in way))

"""Player 34: the party's levels at each recording's checkpoint (the original's save), for poolrad.md's route levels.
Run from the Player lab: python3 <this> <worktree>/tools/original_player/match/recordings.txt"""
import os, glob, sys
AB = ["C", "D", "F", "P", "R", "MU", "T", "M"]
REC = sys.argv[1]
for l in open(REC):
    l = l.split("#", 1)[0].split()
    if len(l) < 4:
        continue
    seg, run, start, cp = l[:4]
    d = os.path.join(".lab/player/saves", run, cp)
    out = []
    for f in sorted(glob.glob(os.path.join(d, "CHRDAT*.SAV"))):
        r = open(f, "rb").read()
        name = r[1:1 + r[0]].decode("latin1")
        lv = "/".join("%s%d" % (AB[i], r[0x96 + i]) for i in range(8) if r[0x96 + i])
        out.append("%s %s%s" % (name, lv, " -%d" % r[0x74] if r[0x74] else ""))
    print("%2s %-7s %-14s %s" % (seg, run, cp, ", ".join(out)))

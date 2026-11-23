#!/bin/bash
# p23a4.sh <out> [proj]: Player 23's p23a4 (the throne room's horde, from p2start/p23a3_s17door, seed 23230004) in ours on
# its own game copy game54a (slot F), QoL off (tmp/xdg53d), GBR_PLAYOUT=1, keys as segment.py's (logs/p23a4.segment_begin-end.txt).
cd /home/aaron/gbr/combat_lab || exit 1
G=godot/Godot_v4.7.2-stable_linux.x86_64
P=${2:-proj}
[ -d game54a ] || cp -r game53d game54a
python3 - <<'PY'
import os, shutil
g = "game54a"; d = "/home/aaron/gbr/player_lab/.lab/player/saves/p2start/p23a3_s17door"
for f in os.listdir(g):
    if f.upper() == "SAVGAMF.DAT" or f.upper().startswith("CHRDATF"): os.remove(os.path.join(g, f))
for f in os.listdir(d):
    u = f.upper(); dst = "SAVGAMF.DAT" if u.startswith("SAVGAM") else "CHRDATF" + u[7:]
    shutil.copy(os.path.join(d, f), os.path.join(g, dst))
p = os.path.join(g, "SAVGAMF.DAT"); s = bytearray(open(p, "rb").read())
for k in range(8):
    o = 0x3209 + k * 41
    if 0 < s[o] <= 12 and s[o + 1:o + 7] == b"CHRDAT": s[o + 7] = ord("F")
open(p, "wb").write(s)
PY
[ -d run54_a ] && find run54_a -delete
cp -r $P run54_a
rm -f tmp/qs54a.cfg; cp qs.cfg tmp/qs54a.cfg
K=$(head -1 logs/p23a4.segment_begin-end.txt | sed 's/^keys: //')
env GBR_PLAYOUT=1 XDG_DATA_HOME=$PWD/tmp/xdg53d timeout ${OT:-2400} $G --headless --path run54_a -- --game-path=$PWD/game54a --save=$PWD/tmp/qs54a.cfg "--keys=$K" > $1 2>&1
find run54_a -delete
grep "^ *#\|^ *pos \|^ *cell \|PARTY \|ASKED " $1 > ${1%.txt}_t.txt
DRAWS_ONLY=1 python3 cmpdraws.py logs/p23a4.trace.txt ${1%.txt}_t.txt | tail -3
echo P23DONE

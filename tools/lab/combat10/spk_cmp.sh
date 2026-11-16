#!/bin/bash
# spk_cmp.sh: ours' speaker driver (scripts/ui/speaker.gd in the lab's proj) against sfx.py, every row tick for tick.
cd /home/aaron/gbr/combat_lab
cp combat10/spk_test.gd proj/spk_test.gd
timeout 120 godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path proj --script res://spk_test.gd -- --game-path=$PWD/game 2>&1 | grep '^ROW\|NO DRIVER' > tmp/spk_ours.txt
python3 - <<'P'
import sys; sys.path.insert(0, "combat10"); import sfx
ours = {int(l.split()[1]): [int(x) for x in l.split()[2:]] for l in open("tmp/spk_ours.txt") if l.startswith("ROW")}
bad = 0
for r in range(21):
    ref = sfx.render(r)
    o = ours.get(r)
    if o != ref:
        bad += 1
        k = next((i for i in range(min(len(o or []), len(ref))) if o[i] != ref[i]), min(len(o or []), len(ref)))
        print("row %d differs at tick %d (ours %d ticks, sfx %d)" % (r, k, len(o or []), len(ref)))
print("SPEAKER %d/21 rows identical" % (21 - bad))
P

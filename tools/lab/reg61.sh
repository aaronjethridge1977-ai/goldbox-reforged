#!/bin/bash
# reg61.sh (Combat Chat 7): 6:1's run for the gate (the Player's p2e entry: c24f's party at 6:1 7,6 N after the
# boy's rescue, seed 2468ace1, Up x4, QUICK for all) in ours, compared draw for draw with the original's trace
# (traces/orig_61_gate.txt: Player 2's p2i trace cut at the fight's last draw, 7346; regress.sh copies it to
# tmp/cmp_orig.txt). DRAWS_ONLY: the Player's trace logs figures 1-31 only and no end lines.
# Needs the lab's combat6/g61 game folder with the Player's entry save as slot F (combat6/README.txt).
cd /home/aaron/gbr/combat_lab
[ -f combat6/g61/SAVGAMF.DAT ] || { echo "VERDICT: skipped (no combat6/g61 save F)"; exit 0; }
GTIME=${GTIME:-600} combat6/run61.sh > tmp/reg61_ours.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py tmp/cmp_orig.txt tmp/reg61_ours.txt

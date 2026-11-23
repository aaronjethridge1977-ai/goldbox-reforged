#!/bin/bash
# regtyr.sh <seed> (Combat Chat 8): Tyranthraxus alone (Player 5/6's c27a_5-7_dragon, keys Up Y Enter Enter A x6, QUICK
# for all) in ours from combat6/g61 slot B, compared draw for draw with the original's trace (traces/orig_B_tyr1.txt for
# 12345678, orig_B_tyr2.txt for 2468ace1: Player 6's p5_dragon1T/2T traces cut at Tyranthraxus's fall, 1273 and 1042
# draws; the original then plays the round out, ours ends the fight at once: the QoL decision of 2026-11-10).
# regress.sh copies the trace to tmp/cmp_orig.txt. DRAWS_ONLY: the Player's trace has no end lines.
cd /home/aaron/gbr/combat_lab
[ -f combat6/g61/SAVGAMB.DAT ] || { echo "VERDICT: skipped (no combat6/g61 save B)"; exit 0; }
# Combat Chat 54: waits before each key (main chat 117: a menu after a script's text waits for the text to type;
# the dragon's speech took the A's while still typing and ours never fought)
W8=wait,wait,wait,wait,wait,wait,wait,wait
GTIME=${GTIME:-500} bash combat6/oursg.sh "load=B,tpseed=$1,Up,$W8,Y,$W8,Enter,$W8,Enter,$W8,A,A,A,A,A,A,wait,wait,quickall,fightend,tplog" > tmp/regtyr_ours.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py tmp/cmp_orig.txt tmp/regtyr_ours.txt

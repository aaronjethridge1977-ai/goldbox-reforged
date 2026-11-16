#!/bin/bash
# regpatrol.sh (Combat Chat 8): Player 5's 5:4 patrol (c27a_5-4_alarm in combat6/g61 slot C, seed 12345678: rest E R H I R,
# interrupted at 13:41, Enter (ours' RUDELY INTERRUPTED pause), Enter, C, QUICK for all) in ours, compared draw for draw
# with the original's trace (traces/orig_C_patrol.txt = the Player lab's p3x_patrol1U trace, 2460 draws; regress.sh
# copies it to tmp/cmp_orig.txt). DRAWS_ONLY: the Player's trace has no end lines (the original asked CONTINUE BATTLE).
cd /home/aaron/gbr/combat_lab
[ -f combat6/g61/SAVGAMC.DAT ] || { echo "VERDICT: skipped (no combat6/g61 save C)"; exit 0; }
GTIME=${GTIME:-500} bash combat6/oursg.sh "load=C,tpseed=12345678,e,r,wait,wait,h,wait,wait,i,wait,wait,r,wait,wait,Enter,wait,wait,Enter,wait,wait,c,wait,wait,quickall,fightend,tplog" > tmp/regpatrol_ours.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py tmp/cmp_orig.txt tmp/regpatrol_ours.txt

#!/bin/bash
# pf.sh <slot> <seed> <original trace> [tag]: a Player fight from combat6/g61 slot <slot> in ours (keys Up, Enter, QUICK,
# the Player's p7/rerun1.sh SEGX keys), compared draw for draw with the original's trace (DRAWS_ONLY).
# Slots (combat10/README.txt): I = c33b_4-2_3-11 (GRISHNAK), K = c33b_2-20_0-14 (the troll/ogres), L = c34e_4-21_2-11 (Sokal Keep).
cd /home/aaron/gbr/combat_lab
SL=$1; S=$2; T=$3; TAG=${4:-$SL$S}
GTIME=${GTIME:-500} bash combat6/oursg.sh "load=$SL,tpseed=$S,Up,tplog,Enter,tplog,wait,wait,quickall,tplog,wait,wait,fightend,tplog" > tmp/pf_$TAG.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py $T tmp/pf_$TAG.txt

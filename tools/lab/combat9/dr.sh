#!/bin/bash
# dr.sh <seed> [trace]: Tyranthraxus alone from c32a's save (combat6/g61 slot H; Player 7's p7_dragon1T/2T) in ours.
cd /home/aaron/gbr/combat_lab
S=${1:-12345678}; T=${2:-combat9/p7/p7_dragon$([ $S = 12345678 ] && echo 1 || echo 2)T.trace.txt}
GTIME=${GTIME:-500} bash combat6/oursg.sh "load=H,tpseed=$S,Up,Y,Enter,Enter,A,A,A,A,A,A,wait,wait,quickall,fightend,tplog" > tmp/dr_$S.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py $T tmp/dr_$S.txt

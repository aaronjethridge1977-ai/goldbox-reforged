#!/bin/bash
# zh.sh <seed> [trace]: 4:10 9,1 (the spectres, c32a's save as combat6/g61 slot G; Player 7's p7_zh1T/2T) in ours, QUICK,
# compared draw for draw with the original's trace (default combat9/p7/p7_zh1T for 12345678, p7_zh2T for 2468ace1).
cd /home/aaron/gbr/combat_lab
S=${1:-12345678}; T=${2:-combat9/p7/p7_zh$([ $S = 12345678 ] && echo 1 || echo 2)T.trace.txt}
GTIME=${GTIME:-400} bash combat6/oursg.sh "load=G,tpseed=$S,Up,tplog,quickall,wait,wait,fightend,tplog" > tmp/zh_$S.txt 2>&1
DRAWS_ONLY=1 python3 cmpdraws.py $T tmp/zh_$S.txt

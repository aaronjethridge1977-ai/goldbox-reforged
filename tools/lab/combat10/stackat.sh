#!/bin/bash
# stackat.sh <save dir> <seed> <hold draw> <stack ovr offset> [keys...]: the original held before <hold draw>, its call
# chain (HOLDSTACK) printed, then DOSBox stopped. Also DSSNAP=1: the data segment to tmp/stackat_<seed>_<draw>.ds.
cd /home/aaron/gbr/combat_lab
SD=$1; S=$2; H=$3; ST=$4; shift 4; OUT=tmp/stackat_${S}_$H.txt; : > $OUT
(HOLDSTACK=$ST timeout 700 combat10/orighold.sh $SD $S $H $OUT "$@" > /dev/null 2>&1 &)
sleep 5; for k in $(seq 200); do grep -q 'HOLD at draw' $OUT 2>/dev/null && break; sleep 3; done; sleep 3
[ -n "$DSSNAP" ] && python3 dssnap.py tmp/stackat_${S}_$H.ds
grep 'HOLDSTACK\|HOLD at' $OUT | cut -c1-500
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1

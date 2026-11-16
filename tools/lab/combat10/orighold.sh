#!/bin/bash
# orighold.sh <save dir> <seed> <hold draw> [out] [keys...]: a Player save in the original as slot A (combat9/inst.sh),
# keys (default: up enter) then QUICK for all (presser), held before <hold draw> with every figure's effects and record
# bytes (HOLDREC, default c8,3a). <hold draw> 0: no hold, the whole fight's trace (TSECS seconds, default 600).
cd /home/aaron/gbr/combat_lab
SD=$1; SEED=$2; H=$3; OUT=${4:-tmp/orighold_${SEED}_$H.txt}; shift 4; KEYS=${*:-up wait=3 enter wait=6}
rm -f root/POOLRAD/CHRDATA[A][1-8].*; bash combat9/inst.sh $SD game A
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1
./orig.sh wait=15 enter wait=6 l wait=4 a wait=10 >/dev/null
python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
if [ "$H" = 0 ]; then
  (DISPLAY=:96 timeout ${TSECS:-600} python3 trace.py run ${TSECS:-600} > $OUT &)
else
  (HOLD=$H HOLDSTACK=${HOLDSTACK:-} HOLDITEMS=1 HOLDREC=${HOLDREC:-c8,3a} DISPLAY=:96 timeout 600 python3 trace.py run 580 > $OUT &)
fi
sleep 1
for k in $KEYS; do ./orig.sh $k >/dev/null; done
DISPLAY=:96 timeout ${TSECS:-300} python3 presser.py $(( ${TSECS:-300} - 20 )) noenter > ${OUT%.txt}_press.txt

#!/bin/bash
# patrolhold.sh <seed> <hold draw> [out]: Player 5/6's Tyranthraxus alone (c27a_5-7_dragon, combat8/saves/tyr as slot A)
# in the original, keys Up Y Enter Enter A x6, QUICK for all (presser), held before <hold draw> with every figure's
# record bytes (HOLDREC, default c8,3a: items, weapon, shield, arrows, quarrels, hands) and items.
# HOLD=0 (second argument 0): no hold, the whole fight's trace (TSECS seconds, default 600).
cd /home/aaron/gbr/combat_lab
SEED=${1:-12345678}; H=${2:-845}; OUT=${3:-tmp/patrolhold_${SEED}_$H.txt}
./savein.sh patrol
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1
./orig.sh wait=15 enter wait=6 l wait=4 a wait=10 >/dev/null
python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
if [ "$H" = 0 ]; then
  (DISPLAY=:96 timeout ${TSECS:-600} python3 trace.py run ${TSECS:-600} > $OUT &)
else
  (HOLD=$H HOLDSTACK=${HOLDSTACK:-} HOLDITEMS=1 HOLDREC=${HOLDREC:-c8,3a} DISPLAY=:96 timeout 600 python3 trace.py run 580 > $OUT &)
fi
sleep 1
for k in e wait=3 r wait=3 h wait=3 i wait=3 r wait=5 enter wait=4 c wait=6; do ./orig.sh $k >/dev/null; done
DISPLAY=:96 timeout ${TSECS:-300} python3 presser.py $(( ${TSECS:-300} - 20 )) noenter > ${OUT%.txt}_press.txt

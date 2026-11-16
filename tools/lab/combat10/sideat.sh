#!/bin/bash
# sideat.sh <save dir> <seed> <hold draw>: the original held there, sidebonus.py printed, DOSBox stopped.
cd /home/aaron/gbr/combat_lab
OUT=tmp/sideat_$2_$3.txt; : > $OUT
(timeout 700 combat10/orighold.sh $1 $2 $3 $OUT > /dev/null 2>&1 &)
sleep 5; for k in $(seq 200); do grep -q 'HOLD at draw' $OUT 2>/dev/null && break; sleep 3; done; sleep 3
PYTHONPATH=/home/aaron/gbr/combat_lab python3 combat10/sidebonus.py
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1

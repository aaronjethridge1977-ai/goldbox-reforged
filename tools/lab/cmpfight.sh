#!/bin/bash
# Runs the Slums orc fight (save E, 13,1 W) in the original and in ours from the same seed,
# everyone on QUICK, and prints the first draw where the two differ.
# Usage: cmpfight.sh [seed hex] [orig|ours|both]
cd "$(dirname "$0")"
SEED=${1:-12345678}; WHAT=${2:-both}
if [ $WHAT != ours ]; then
  pkill -f presser.py; pkill -f dosbox; sleep 1
  CONF=por_slow.conf ./orig.sh wait=15 enter wait=6 l wait=4 e wait=10 up wait=3 up wait=5 >/dev/null
  python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
  (DISPLAY=:98 timeout 400 python3 trace.py run 330 > /tmp/cmp_orig.txt &)
  sleep 1
  DISPLAY=:98 timeout 400 python3 presser.py 320
  sleep 2; pkill -f "trace.py run"
fi
if [ $WHAT != orig ]; then
  Q="quickall,$(printf "wait,%.0s" $(seq 80))"
  GTIME=300 ./ours.sh --save=$PWD/qs.cfg "--keys=load=E,up,up,tpseed=$SEED,enter,${Q}tplog" 2>&1 | grep "^ *#\|^ *pos \|^ *cell " > /tmp/cmp_ours.txt
fi
python3 cmpdraws.py /tmp/cmp_orig.txt /tmp/cmp_ours.txt

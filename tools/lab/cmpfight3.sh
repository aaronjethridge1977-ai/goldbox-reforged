#!/bin/bash
# cmpfight3.sh <save> <seed> "<keys before>" "<keys after>" [orig|ours|both] <seed2> "<keys after seed2>"
# As cmpfight2.sh, with a second seed set (and the trace started) after the first keys:
# the encounter comes from the first seed, the fight from the second.
# The original: load the save, press the keys before, set the seed, press the keys after,
# then everyone on QUICK (MAGIC=1: Alt-M too, so QUICK members cast). Ours: the same keys in
# --keys. Then cmpdraws.py.
cd "$(dirname "$0")"
L=$1; SEED=$2; PRE=$3; POST=$4; WHAT=${5:-both}; SEED2=$6; POST2=$7
if [ $WHAT != ours ]; then
  pkill -f presser.py; pkill -f dosbox; sleep 1
  CONF=por_slow.conf ./orig.sh wait=15 enter wait=6 l wait=4 ${L,,} wait=10 $(echo $PRE | tr ',' ' ' | sed 's/\([a-z0-9]*\)/\1 wait=3/g') >/dev/null
  python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
  for k in $(echo $POST | tr ',' ' '); do ./orig.sh $k wait=4 >/dev/null; done
  python3 seed.py set $SEED2 >/dev/null
  (DISPLAY=:98 timeout 500 python3 trace.py run 430 > /tmp/cmp_orig.txt &)
  sleep 1
  for k in $(echo $POST2 | tr "," " "); do ./orig.sh $k wait=4 >/dev/null; done
  DISPLAY=:98 timeout 450 python3 presser.py 420 noenter ${MAGIC:+magic}
  sleep 2; pkill -f "trace.py run"
fi
if [ $WHAT != orig ]; then
  Q="quickall,${MAGIC:+magic,}$(printf 'wait,%.0s' $(seq 100))"
  K="load=$L"; [ -n "$PRE" ] && K="$K,$PRE"; K="$K,tpseed=$SEED"; [ -n "$POST" ] && K="$K,$POST"; K="$K,tpseed=$SEED2,$POST2"
  GTIME=300 ./ours.sh --save=$PWD/qs.cfg "--keys=$K,${Q}tplog" 2>&1 | tee /tmp/cmp_ours_full.txt | grep "^ *#\|^ *pos \|^ *cell " > /tmp/cmp_ours.txt
fi
python3 cmpdraws.py /tmp/cmp_orig.txt /tmp/cmp_ours.txt

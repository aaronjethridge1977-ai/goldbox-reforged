#!/bin/bash
# cmpfight3.sh <save> <seed> "<keys before>" "<keys after>" [orig|ours|both] [<seed2> "<keys after seed2>"]
# The same fight in both games, compared draw by draw (cmpdraws.py): the original loads the
# save, presses the keys before, gets the seed, presses the keys after; with seed2 that is set
# next (the encounter comes from the first seed, the fight from the second) and its keys
# pressed. Then everyone on QUICK (MAGIC=1: Alt-M too, so QUICK members cast) until the fight
# is over; CONTINUE BATTLE is answered NO in both. At the end each side records the party's
# HP and status. Ours gets the same keys in --keys.
# Since 2026-11-14 the trace loses no draws, so the original runs at full speed (SLOW=1:
# por_slow.conf, 1500 cycles, as before) and ours with --fast: a fight takes about a minute.
# KW=<seconds>: the wait after each key before the seed (default 3; longer where texts print first).
# A wait=<s> token in the keys waits in the original only (ours leaves it out).
cd "$(dirname "$0")"
L=$1; SEED=$2; PRE=$3; POST=$4; WHAT=${5:-both}; SEED2=$6; POST2=$7
NAMES="THRENDER GRONE,BAKSHI,RHIANNON,BROTHER SEAN,DARKSTAR,PHINEAS"
if [ $WHAT != ours ]; then
  ./orig.sh stop
  CONF=$([ -n "$SLOW" ] && echo por_slow.conf || echo por.conf) ./orig.sh wait=15 enter wait=6 l wait=4 ${L,,} wait=10 $(echo $PRE | tr ',' ' ' | sed "s/\([a-z0-9]*\)/\1 wait=${KW:-3}/g") >/dev/null
  python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
  if [ -n "$SEED2" ]; then
    for k in $(echo $POST | tr ',' ' '); do ./orig.sh $k wait=4 >/dev/null; done
    python3 seed.py set $SEED2 >/dev/null
  fi
  S=${OSECS:-880}   # OSECS: how long the original may fight (seconds; long fights, Combat Chat 1)
  (DISPLAY=:98 timeout $((S + 20)) python3 trace.py run $S > /tmp/cmp_orig.txt & echo $! > /tmp/gbr_trace_98.pid)
  sleep 1
  KEYS2=$POST; [ -n "$SEED2" ] && KEYS2=$POST2
  for k in $(echo $KEYS2 | tr ',' ' '); do ./orig.sh $k wait=4 >/dev/null; done
  DISPLAY=:98 timeout $((S - 20)) python3 presser.py $((S - 30)) noenter ${MAGIC:+magic} > /tmp/cmp_orig_end.txt
  sleep 2; kill $(cat /tmp/gbr_trace_98.pid) 2>/dev/null; sleep 1
  cat /tmp/cmp_orig_end.txt >> /tmp/cmp_orig.txt
  (IFS=,; python3 partyrec.py $NAMES) >> /tmp/cmp_orig.txt
fi
if [ $WHAT != orig ]; then
  # wait=<s> tokens are for the original only (texts that print slowly there)
  PRE=$(echo "$PRE" | sed 's/wait=[0-9.]*,\?//g; s/,$//'); POST=$(echo "$POST" | sed 's/wait=[0-9.]*,\?//g; s/,$//')
  K="load=$L"; [ -n "$PRE" ] && K="$K,$PRE"; K="$K,tpseed=$SEED"; [ -n "$POST" ] && K="$K,$POST"
  [ -n "$SEED2" ] && K="$K,tpseed=$SEED2${POST2:+,$POST2}"
  W=$(printf "wait,%.0s" $(seq ${OWAITS:-6})); W=${W%,}   # OWAITS: more waits for long fights
  GTIME=${GTIME:-300} ./ours.sh --save=$PWD/qs.cfg --fast "--keys=$K,quickall,${MAGIC:+magic,}fightend,n,$W,tplog,partyhp" 2>&1 | tee /tmp/cmp_ours_full.txt | grep "^ *#\|^ *pos \|^ *cell \|PARTY \|ASKED " > /tmp/cmp_ours.txt
fi
python3 cmpdraws.py /tmp/cmp_orig.txt /tmp/cmp_ours.txt

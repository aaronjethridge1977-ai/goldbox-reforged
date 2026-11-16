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
# OURS_SEED=<n> (Combat Chat 7): ours' own generator seeded (--seed), for keys walked before the dice
# are seeded (a random encounter on the troll fixture's first step otherwise comes and goes run to run).
# A wait=<s> token in the keys waits in the original only (ours leaves it out).
cd "$(dirname "$0")"
L=$1; SEED=$2; PRE=$3; POST=$4; WHAT=${5:-both}; SEED2=$6; POST2=$7
NAMES="THRENDER GRONE,BAKSHI,RHIANNON,BROTHER SEAN,DARKSTAR,PHINEAS"
if [ $WHAT != ours ]; then
  /home/aaron/gbr/combat_lab/killmine.sh presser.py; /home/aaron/gbr/combat_lab/killmine.sh 'trace.py run'; /home/aaron/gbr/combat_lab/killmine.sh '[d]osbox -conf'; sleep 1
  CONF=$([ -n "$SLOW" ] && echo por_slow.conf || echo por.conf) ./orig.sh wait=15 enter wait=6 l wait=4 ${L,,} wait=10 $(echo $PRE | tr ',' ' ' | sed "s/\([a-z0-9]*\)/\1 wait=${KW:-3}/g") >/dev/null
  python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
  if [ -n "$SEED2" ]; then
    for k in $(echo $POST | tr ',' ' '); do ./orig.sh $k wait=4 >/dev/null; done
    python3 seed.py set $SEED2 >/dev/null
  fi
  S=${OSECS:-880}   # OSECS: how long the original may fight (seconds; long fights, Combat Chat 1)
  (DISPLAY=:96 timeout $((S + 20)) python3 trace.py run $S > /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt &)
  sleep 1
  KEYS2=$POST; [ -n "$SEED2" ] && KEYS2=$POST2
  for k in $(echo $KEYS2 | tr ',' ' '); do ./orig.sh $k wait=4 >/dev/null; done
  DISPLAY=:96 timeout $((S - 20)) python3 presser.py $((S - 30)) noenter ${MAGIC:+magic} > /home/aaron/gbr/combat_lab/tmp/cmp_orig_end.txt
  sleep 2; /home/aaron/gbr/combat_lab/killmine.sh 'trace.py run'; sleep 1
  cat /home/aaron/gbr/combat_lab/tmp/cmp_orig_end.txt >> /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt
  (IFS=,; python3 partyrec.py $NAMES) >> /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt
fi
if [ $WHAT != orig ]; then
  # wait=<s> tokens are for the original only (texts that print slowly there)
  PRE=$(echo "$PRE" | sed 's/wait=[0-9.]*,\?//g; s/,$//'); POST=$(echo "$POST" | sed 's/wait=[0-9.]*,\?//g; s/,$//')
  # OPOST (Combat Chat 8): ours' keys after the seed, when they must differ (an ours-only wait: 2:9's c pressed
  # before the fight opened in ours under load and the party's QUICK never reached it).
  [ -n "$OPOST" ] && POST=$OPOST
  K="load=$L"; [ -n "$PRE" ] && K="$K,$PRE"; K="$K,tpseed=$SEED"; [ -n "$POST" ] && K="$K,$POST"
  [ -n "$SEED2" ] && K="$K,tpseed=$SEED2${POST2:+,$POST2}"
  W=$(printf "wait,%.0s" $(seq ${OWAITS:-6})); W=${W%,}   # OWAITS: more waits for long fights
  GTIME=${GTIME:-300} ./ours.sh --save=$PWD/qs.cfg --fast ${OURS_SEED:+--seed=$OURS_SEED} "--keys=$K,quickall,${MAGIC:+magic,}fightend,n,$W,tplog,partyhp" 2>&1 | tee /home/aaron/gbr/combat_lab/tmp/cmp_ours_full.txt | grep "^ *#\|^ *pos \|^ *cell \|PARTY \|ASKED " > /home/aaron/gbr/combat_lab/tmp/cmp_ours.txt
fi
python3 cmpdraws.py /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt /home/aaron/gbr/combat_lab/tmp/cmp_ours.txt

#!/bin/bash
# stagefight.sh <save letter> <stage> <seed hex> "<keys after F>" [out file]
# A staged test fight in ours (side chat 5, for B1's flee and hurt rules): loads the lab save,
# opens the area's test fight (B), sets the monsters (stage=<id>x<n>;...), the original's dice
# from the seed, F, everyone on QUICK with magic, then the extra keys (smartquick, hp=<pct>,
# smartmonsters, order=...), plays to the end and prints one summary line:
# outcome (1 won, 2 lost, 3 ran away), rounds, flee messages, escapes, blows from behind,
# party members still standing / fled.
cd "$(dirname "$0")"
SAVE=$1 STAGE=$2 SEED=$3 EXTRA=$4 OUT=${5:-/tmp/stage_$$.txt}
K="load=$SAVE,b,stage=$STAGE,tpseed=$SEED,f,quickall,magic${EXTRA:+,$EXTRA},fightend,outcome"
GTIME=${GTIME:-400} ./ours.sh --save=$PWD/qs.cfg --fast "--keys=$K" > $OUT 2>&1
o=$(grep -o "OUTCOME [0-9]* ROUND [0-9]*" $OUT | tail -1)
fl=$(grep -c "FLEES IN PANIC" $OUT); got=$(grep -c "GOT AWAY" $OUT); blk=$(grep -c "ESCAPE IS BLOCKED" $OUT)
beh=$(grep "ATTACKS" $OUT | grep -c "(FROM BEHIND)")
up=$(grep "FIG 0 " $OUT | grep -c "DOWN false"); ran=$(grep "FIG 0 " $OUT | grep -c "FLED true")
echo "$SAVE $STAGE $SEED [$EXTRA]: ${o:-no outcome} | flees $fl, got away $got, blocked $blk, from behind $beh | party up $up, fled $ran"

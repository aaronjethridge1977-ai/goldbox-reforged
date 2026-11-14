#!/bin/bash
# Replays every saved original trace (tools/lab/traces/: the original's dice, cells, CONTINUE
# BATTLE and the party's HP at the end; no game data) in ours and prints each fight's verdict.
# regress.sh record: plays each fight in the original again first and saves its new trace
# (about a minute a fight). Needs the lab saves E and F (README, side chat 2) and H (side chat 3).
# Past the early game (side chat 5): save I = `python3 mksave.py E I 2 15 5 5 N` (Mendor's library); save C =
# `python3 mksave.py E C 8 13 9 9 E`, then every CHRDATC?.SAV's bytes 0x32 and 0x11B set to 40 (the kobold caves'
# net trap at 10,9 with 20 kobolds; the party at 40 HP so the fight runs long).
cd "$(dirname "$0")"
WHAT=ours; [ "$1" = record ] && WHAT=both
run() { # name magic script args...
  local n=$1 m=$2; shift 2
  [ $WHAT = ours ] && cp traces/$n.txt /tmp/cmp_orig.txt
  if [ "$m" = 1 ]; then export MAGIC=1; else unset MAGIC; fi
  timeout 900 "$@" > /tmp/reg_$n.txt 2>&1
  [ $WHAT = both ] && cp /tmp/cmp_orig.txt traces/$n.txt
  echo "$n: $(grep '^original:' /tmp/reg_$n.txt) $(grep '^VERDICT' /tmp/reg_$n.txt)"
}
run orig_F_magic 1 ./cmpfight2.sh F 10000012 "" up,c $WHAT
run orig_F_plain 0 ./cmpfight2.sh F 10000012 "" up,c $WHAT
run orig_E_magic 1 ./cmpfight2.sh E 12345678 up,up enter $WHAT
run orig_E_22 1 ./cmpfight2.sh E 22222222 up,up enter $WHAT
run orig_E_bad 0 ./cmpfight2.sh E 0badf00d up,up enter $WHAT
run orig_E_31415926 1 ./cmpfight2.sh E 31415926 up,up enter $WHAT
run orig_E_0000beef 0 ./cmpfight2.sh E 0000beef up,up enter $WHAT
run orig_E_5eed5eed 1 ./cmpfight2.sh E 5eed5eed up,up enter $WHAT
for s in 00000002 00000003 00000004 deadbeef cafef00d 12121212; do
  m=1; [ $s = 00000003 ] || [ $s = deadbeef ] && m=0
  run orig_F3_$s $m ./cmpfight3.sh F 10000012 "" up,c $WHAT $s ""
done
for s in 11111111 22222222 33333333 55555555 deadbeef 0badf00d; do   # QUICK Bakshi with two Magic Missiles
  run orig_H_$s 1 ./cmpfight2.sh H $s up,up enter $WHAT
done
# Past the early game (side chat 5): monster powers and casters, one fight each.
run orig_I_basilisk 1 env KW=8 ./cmpfight2.sh I 11111111 up,up enter,wait=8,c $WHAT
run orig_C_kobolds 1 env KW=8 ./cmpfight2.sh C 11111111 up up $WHAT   # open: differs at draw 4107 of 8905 (Thrender's fail count)

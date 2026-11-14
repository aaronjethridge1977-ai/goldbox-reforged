#!/bin/bash
# Replays every saved original trace (tools/lab/traces/: the original's dice, no game data;
# add the original side of new cmpfight runs there) in ours and prints where each differs.
cd "$(dirname "$0")"
run() { # name magic script args...
  local n=$1 m=$2; shift 2
  cp "$(dirname "$0")/traces/$n.txt" /tmp/cmp_orig.txt 2>/dev/null || cp traces/$n.txt /tmp/cmp_orig.txt
  if [ "$m" = 1 ]; then export MAGIC=1; else unset MAGIC; fi
  timeout 400 "$@" > /tmp/reg_$n.txt 2>&1
  echo "$n: $(sed -n 1,2p /tmp/reg_$n.txt | tr '\n' ' ')"
}
run orig_F_magic 1 ./cmpfight2.sh F 10000012 "" up,c ours
run orig_F_plain 0 ./cmpfight2.sh F 10000012 "" up,c ours
run orig_E_magic 1 ./cmpfight2.sh E 12345678 up,up enter ours
run orig_E_22 1 ./cmpfight2.sh E 22222222 up,up enter ours
run orig_E_bad 0 ./cmpfight2.sh E 0badf00d up,up enter ours
run orig_E_31415926 1 ./cmpfight2.sh E 31415926 up,up enter ours
run orig_E_0000beef 0 ./cmpfight2.sh E 0000beef up,up enter ours
run orig_E_5eed5eed 1 ./cmpfight2.sh E 5eed5eed up,up enter ours
for s in 00000002 00000003 00000004 deadbeef cafef00d 12121212; do
  m=1; [ $s = 00000003 ] || [ $s = deadbeef ] && m=0
  run orig_F3_$s $m ./cmpfight3.sh F 10000012 "" up,c ours $s ""
done

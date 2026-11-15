#!/bin/bash
# Replays every saved original trace (tools/lab/traces/: the original's dice, cells, CONTINUE
# BATTLE and the party's HP at the end; no game data) in ours and prints each fight's verdict.
# regress.sh record: plays each fight in the original again first and saves its new trace
# (about a minute a fight). Needs the lab saves E and F (README, side chat 2) and H (side chat 3).
# Past the early game (side chat 5): save I = `python3 mksave.py E I 2 15 5 5 N` (Mendor's library); save C =
# `python3 mksave.py E C 8 13 9 9 E`, then every CHRDATC?.SAV's bytes 0x32 and 0x11B set to 40 (the kobold caves'
# net trap at 10,9 with 20 kobolds; the party at 40 HP so the fight runs long).
# Differential checks' fights (Combat Chat 1, docs/diff-checks.md): save D = `python3 mksave.py J D 4 2 11 14 E 4A97=255 strong`
# then `python3 fixthac0.py J D` (the original ignores a file's THAC0; ours doesn't).
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
run orig_C_kobolds 1 env KW=8 ./cmpfight2.sh C 11111111 up up $WHAT   # matches to the end since Combat Chat 1
run orig_C_kobolds22 1 env KW=8 ./cmpfight2.sh C 22222222 up up $WHAT   # the net trap on a second seed (Combat Chat 1: checks the sort list fitted on the first)
run orig_D_ogrechief 1 env KW=4 ./cmpfight2.sh D 11111111 up up,enter,enter $WHAT   # check 3: 4:2 the ogre chief, 15863 draws (~10 min in the original)
# Check 10: 7:23 Yarash and 6 MUTANT LIZ-MEN (Combat Chat 2: Yarash's wand of paralyzation, 0xAFA4; the party is
# held one by one and slain, 3689 draws). Save G = `mksave.py J G 7 23 5 1 W strong`, `fixthac0.py J G`. Needs main's
# magic-armour movement fix (party_member.gd; until it lands the line is skipped).
if grep -q "armor.plus != 0" ../../scripts/game/party_member.gd 2>/dev/null || grep -q "armor.plus != 0" "${REPO:-/home/claude/goldbox-reforged}/scripts/game/party_member.gd" 2>/dev/null; then
  run orig_G_yarash 1 env KW=4 ./cmpfight2.sh G 11111111 up up,enter,c $WHAT   # check 10
else
  echo "orig_G_yarash: skipped (main's magic-armour movement fix not in party_member.gd yet)"
fi

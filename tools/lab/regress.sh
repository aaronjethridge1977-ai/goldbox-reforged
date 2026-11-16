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
  [ $WHAT = ours ] && cp traces/$n.txt /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt
  if [ "$m" = 1 ]; then export MAGIC=1; else unset MAGIC; fi
  timeout 900 "$@" > /home/aaron/gbr/combat_lab/tmp/reg_$n.txt 2>&1
  [ $WHAT = both ] && cp /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt traces/$n.txt
  echo "$n: $(grep '^original:' /home/aaron/gbr/combat_lab/tmp/reg_$n.txt) $(grep '^VERDICT' /home/aaron/gbr/combat_lab/tmp/reg_$n.txt)"
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
run orig_C_kobolds22 1 env KW=8 OURS_SEED=1 ./cmpfight2.sh C 22222222 up up $WHAT   # the net trap on a second seed (Combat Chat 1: checks the sort list fitted on the first)
run orig_D_ogrechief 1 env KW=4 ./cmpfight2.sh D 11111111 up up,enter,enter $WHAT   # check 3: 4:2 the ogre chief, 15863 draws (~10 min in the original)
# Differential checks 5 and 10's fights with main's start recipe (chat 23: each member's weapon +10, `strong`):
# save B = `mksave.py J B 5 7 3 7 S strong wplus1=10 ... wplus6=10` (5:7's guards, 9284 draws, the party wins);
# save G = `mksave.py J G 7 23 5 1 W strong wplus1=10 ... wplus6=10` (Yarash, 1323 draws, wins; his wand once).
# orig_G_yarash_held: the same fight from `mksave.py J G 7 23 5 1 W strong` (no +10): the wand holds the party one by
# one and the held are slain (3689 draws; Combat Chat 2's item-use check); that save is kept in the lab as
# combat2/saveG_held and swapped in for its run. All three need main's magic-armour movement fix (landed, chat 23).
run orig_B_guards 1 env KW=4 ./cmpfight2.sh B 11111111 up up,enter,enter,c $WHAT   # check 5
run orig_G_yarash_win 1 env KW=4 ./cmpfight2.sh G 11111111 up up,enter,c $WHAT   # check 10
if [ -d combat2/saveG_held ]; then
  mkdir -p /home/aaron/gbr/combat_lab/tmp/saveG_win && cp game/SAVGAMG.DAT game/CHRDATG* /home/aaron/gbr/combat_lab/tmp/saveG_win/ && cp combat2/saveG_held/* game/
  run orig_G_yarash_held 1 env KW=4 ./cmpfight2.sh G 11111111 up up,enter,c $WHAT
  cp /home/aaron/gbr/combat_lab/tmp/saveG_win/* game/
else
  echo "orig_G_yarash_held: skipped (no combat2/saveG_held in the lab)"
fi
# Combat Chat 4: check 5 goes on to Tyranthraxus (save B, the guards on 11111111, the vote seeded 22222222, A x6, QUICK);
# 1718 draws. The trace was recorded by the lab archive's combat4/tyr2.sh (the original's guards played QUICK first), so
# `record` skips it; its first POS line has Darkstar's and Tyranthraxus's start cells added from a HOLD dump (the trace
# logs only changes, and the guards' fight had left those bytes the same).
[ $WHAT = ours ] && run orig_B_tyranthraxus 1 env GTIME=900 ./cmpfight3.sh B 11111111 up up,enter,enter,c,quickall,magic,fightend,n,wait,wait,wait,enter,wait,wait,e,wait,wait,n,wait,wait,enter,wait,enter,wait $WHAT 22222222 a,wait,a,wait,a,wait,a,wait,a,wait,a,wait,wait
run orig_A_spectre 1 bash -c "./savein.sh spectre && KW=4 ./cmpfight2.sh A 11111111 '' up $WHAT"   # Combat Chat 5: 4:10's brass doors, two spectres (drain, turning, a turned spectre running), 3195 draws; the start save is lab-only (combat5/saves/spectre: the J party at levels 4-6, 200 HP, +1 weapons, saved by the original at 4:10's gate and moved to 10,1 W)
run orig_A_mu 1 bash -c "./savein.sh mu && KW=4 ./cmpfight2.sh A 11111111 '' up,wait=4,enter,wait=3,enter,wait=3,s $WHAT"   # Combat Chat 6: 4:10's LEVEL 6 MU ("THEN DIE YOU SCUM", 8,9; start combat6/saves/mu: the spectre's party, 0x4A42 = 3), 952 draws; he casts Magic Missile (his Fireball plan fails beside the party)
run orig_A_troll 1 bash -c "./savein.sh troll && KW=4 OURS_SEED=1 ./cmpfight2.sh A 11111111 up 'up,wait=6,enter' $WHAT"   # Combat Chat 7: 2:20 0,14's two ogres and four trolls (start combat5/saves/troll, 2:20 0,15 N, lab only; the event's random treasure first: main's chat 28), 2561 draws; OURS_SEED=1: ours' own generator seeded for the step before the dice (a random encounter there came and went run to run)
run orig_A_mu29 1 bash -c "./savein.sh mu29 && KW=4 OSECS=1700 OPOST=up,enter,wait,c ./cmpfight2.sh A 11111111 up 'up,wait=4,enter,wait=3,c' $WHAT"   # Combat Chat 7: 2:9 event 13 at 7,6, two LEVEL 6 MUs, two aides, six ettins (start combat6/saves/mu29, lab only), 6973 draws; recorded again with OSECS=1700 (the fight is long)
[ $WHAT = ours ] && run orig_61_gate 1 ./reg61.sh   # Combat Chat 7: 6:1's run for the gate (Player 2's p2e entry, seed 2468ace1, QUICK), 7346 draws to the fight's end; the start is the Player lab's save (combat6/g61 slot F); draws only (DRAWS_ONLY)
# Combat Chat 8: Tyranthraxus alone from Player 5/6's save (combat6/g61 slot B), seeds 12345678 and 2468ace1, to his fall.
[ $WHAT = ours ] && run orig_B_tyr1 1 ./regtyr.sh 12345678
[ $WHAT = ours ] && run orig_B_tyr2 1 ./regtyr.sh 2468ace1
[ $WHAT = ours ] && run orig_C_patrol 1 ./regpatrol.sh   # Combat Chat 8: Player 5's 5:4 patrol (LIRA's hands, the hill giants' DEX 0, Cause Blindness's touch), 2460 draws
# Combat Chat 9: c32a's saves (Player 7; combat6/g61 slots G and H, combat9/inst.sh): DIRTEN (0x84 = 0xFF, with the party)
# surrenders on his first turn (the morale routine 0x0BC97 on either side). 4:10 9,1's spectres and Tyranthraxus, two seeds each.
[ $WHAT = ours ] && run orig_G_zh1 1 ./combat9/zh.sh 12345678 tmp/cmp_orig.txt
[ $WHAT = ours ] && run orig_G_zh2 1 ./combat9/zh.sh 2468ace1 tmp/cmp_orig.txt
[ $WHAT = ours ] && run orig_H_tyr1 1 ./combat9/dr.sh 12345678 tmp/cmp_orig.txt
[ $WHAT = ours ] && run orig_H_tyr2 1 ./combat9/dr.sh 2468ace1 tmp/cmp_orig.txt   # the party falls in both games

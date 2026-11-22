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
F5="BAKSHI,RHIANNON,BROTHER SEAN,DARKSTAR,PHINEAS"   # Combat Chat 15: save F (lab_prev's) has five members, no Thrender
WHAT=ours; [ "$1" = record ] && WHAT=both
run() { # name magic script args...
  local n=$1 m=$2; shift 2
  [ $WHAT = ours ] && cp traces/$n.txt /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt
  if [ "$m" = 1 ]; then export MAGIC=1; else unset MAGIC; fi
  timeout 900 "$@" > /home/aaron/gbr/combat_lab/tmp/reg_$n.txt 2>&1
  [ $WHAT = both ] && cp /home/aaron/gbr/combat_lab/tmp/cmp_orig.txt traces/$n.txt
  echo "$n: $(grep '^original:' /home/aaron/gbr/combat_lab/tmp/reg_$n.txt) $(grep '^VERDICT' /home/aaron/gbr/combat_lab/tmp/reg_$n.txt)"
}
run orig_F_magic 1 env NAMES="$F5" ./cmpfight2.sh F 10000012 "" up,c $WHAT
run orig_F_plain 0 env NAMES="$F5" ./cmpfight2.sh F 10000012 "" up,c $WHAT
run orig_E_magic 1 ./cmpfight2.sh E 12345678 up,up enter $WHAT
run orig_E_22 1 ./cmpfight2.sh E 22222222 up,up enter $WHAT
run orig_E_bad 0 ./cmpfight2.sh E 0badf00d up,up enter $WHAT
run orig_E_31415926 1 ./cmpfight2.sh E 31415926 up,up enter $WHAT
run orig_E_0000beef 0 ./cmpfight2.sh E 0000beef up,up enter $WHAT
run orig_E_5eed5eed 1 ./cmpfight2.sh E 5eed5eed up,up enter $WHAT
for s in 00000002 00000003 00000004 deadbeef cafef00d 12121212; do
  m=1; [ $s = 00000003 ] || [ $s = deadbeef ] && m=0
  run orig_F3_$s $m env NAMES="$F5" ./cmpfight3.sh F 10000012 "" up,c $WHAT $s ""
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
# Combat Chat 33, the spell lab: one caster (BAKSHI) with 21 copies of one spell, everyone else's memory empty, game speed 0
# (fixtures combat33/saves/<name>, lab only: combat33/mkfix.py C|E <name> clear mem2=<id>x21 speed=0), MAGIC on, QUICK.
run orig_A_c33_hp_kob 1 bash -c "./combat33/fixin.sh hp_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_mhp_kob 1 bash -c "./combat33/fixin.sh mhp_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_mm_kob 1 bash -c "./combat33/fixin.sh mm_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_slow_kob 1 bash -c "./combat33/fixin.sh slow_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_bless_kob 1 bash -c "./combat33/fixin.sh bless_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_prayer_kob 1 bash -c "./combat33/fixin.sh prayer_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_haste_kob 1 bash -c "./combat33/fixin.sh haste_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_pfe_kob 1 bash -c "./combat33/fixin.sh pfe_kob && KW=8 OURS_SEED=1 ./cmpfight2.sh A 11111111 up up $WHAT"
run orig_A_c33_hp_orc 1 bash -c "./combat33/fixin.sh hp_orc && KW=8 ./cmpfight2.sh A 12345678 up,up enter $WHAT"
# Combat Chat 34: the spell lab's hand-cast fights (Combat Chat 33's handcast.py in the original), replayed in ours by the
# handcast= lab key (combat34/handreg.sh, draws only): Sleep x2 and Fireball on the net trap, Stinking Cloud x2 and Hold
# Person (three picks) on the Slums orcs. The fixtures are lab-only (combat33/saves, mkfix.py recipes in combat33/README).
run orig_A_c34_hand_sl22 0 env OURS_SEED=1 ./combat34/handreg.sh sl_kob1 22222222 up up 12 1
run orig_A_c34_hand_sl44 0 env OURS_SEED=1 ./combat34/handreg.sh sl_kob1 44444444 up up 12 1
run orig_A_c34_hand_sl1 0 env OURS_SEED=1 ./combat34/handreg.sh sl_kob1 22222222 up up 6 1
run orig_A_c34_hand_fb1 0 env OURS_SEED=1 ./combat34/handreg.sh fb_kob1 33333333 up up 10 1
run orig_A_c34_hand_sco1 0 ./combat34/handreg.sh sc_orc1 12345678 up,up enter 2 1
run orig_A_c34_hand_sco2 0 ./combat34/handreg.sh sc_orc1 22222222 up,up enter 2 1
run orig_A_c34_hand_hpo1 0 ./combat34/handreg.sh hp_orc1 12345678 up,up enter 1 3
# Combat Chat 34, the spell lab's second part (combat34/batch5.sh): 2:20's ogres and trolls (Hold Person, Sleep, Stinking
# Cloud), 4:10's spectres (the same), TURN on the net trap's kobolds (cleric 1) and on the spectres (cleric 5).
run orig_A_c34_hand_hptr1 0 env OURS_SEED=1 ./combat34/handreg.sh hp_troll 11111111 up up,enter 1 3
run orig_A_c34_hand_sltr1 0 env OURS_SEED=1 ./combat34/handreg.sh sl_troll 11111111 up up,enter 3 1
run orig_A_c34_hand_sctr1 0 env OURS_SEED=1 ./combat34/handreg.sh sc_troll 11111111 up up,enter 2 1
run orig_A_c34_hand_hpsp1 0 ./combat34/handreg.sh hp_spec 11111111 "" up 1 3
run orig_A_c34_hand_slsp1 0 ./combat34/handreg.sh sl_spec 11111111 "" up 3 1
run orig_A_c34_hand_scsp1 0 ./combat34/handreg.sh sc_spec 11111111 "" up 2 1
run orig_A_c34_hand_tukob1 0 env OURS_SEED=1 ./combat34/handreg.sh tu_kob 11111111 up up 1 1:1
run orig_A_c34_hand_tusp1 0 ./combat34/handreg.sh tu_spec 11111111 "" up 1 1:1
# Combat Chat 36: Lightning Bolt by hand (BAKSHI, MU 4, 21 bolts memorized) in the net trap: the bolt bounces off the
# walls (lb1: BAKSHI hit by his own); lb2 ends as the original only with the round played out (GBR_PLAYOUT=1).
run orig_A_c36_hand_lb1 0 env OURS_SEED=1 ./combat34/handreg.sh lb_kob1 33333333 up up 10 1
run orig_A_c36_hand_lb2 0 env GBR_PLAYOUT=1 OURS_SEED=1 ./combat34/handreg.sh lb_kob1 44444444 up up 3 1
run orig_A_c38_hand_disp 0 env HANDX=0:2:1 OURS_SEED=1 ./combat34/handreg.sh disp_kob 33333333 up up 0 1
run orig_A_c39_hand_jav 0 env HANDX=0:99:0:2:2 OURS_SEED=1 ./combat34/handreg.sh jav_kob 33333333 up up 1 1
# Combat Chat 41: MOVE off the field's edge (8:27's kobolds, ARN alone, fixture flee_k1): FLEE: YES, he gets away and the
# round plays out (the kobolds' turns) before THE PARTY HAS FLED; the original's keys replayed (handflee=@).
run orig_A_c41_flee 0 ./combat41/oursflee.sh flee_k1 31310016 - @/home/aaron/gbr/combat_lab/traces/orig_A_c41_flee_hand.txt
# Combat Chat 42, the spell matrix (combat42/mx.sh: the hand-cast fight in ours with the fxwatch key; the verdict
# needs the draws and every figure's status, HP and effects (type:minutes/power) in order, as the original's FXWATCH).
run orig_A_c42_mx_sl1 0 env ORIG=skip OURS_SEED=1 ./combat42/mx.sh sl_kob1 22222222 mx_sl1 up up 12 1
run orig_A_c42_mx_sco1 0 env ORIG=skip ./combat42/mx.sh sc_orc1 12345678 mx_sco1 up,up enter 2 1
run orig_A_c42_mx_sck1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh sc_kob1 11111111 mx_sck1 up up 12 1
run orig_A_c42_mx_hpo1 0 env ORIG=skip ./combat42/mx.sh hp_orc1 12345678 mx_hpo1 up,up enter 1 3
run orig_A_c42_mx_hpk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh hpk1 11111111 mx_hpk1 up up 1 3
run orig_A_c42_mx_mhpk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh mhpk1 11111111 mx_mhpk1 up up 1 3
run orig_A_c42_mx_fb1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh fb_kob1 33333333 mx_fb1 up up 10 1
run orig_A_c42_mx_lb1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh lb_kob1 33333333 mx_lb1 up up 10 1
run orig_A_c42_mx_mmk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh mmk1 11111111 mx_mmk1 up up 1 1
run orig_A_c43_mx_chk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh chk1 11111111 mx_chk1 up up 1 1
run orig_A_c43_mx_blk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh blk1 11111111 mx_blk1 up up 0 1
run orig_A_c43_mx_prk1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh prk1 11111111 mx_prk1 up up 0 1
run orig_A_c43_mx_mik1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh mik1 11111111 mx_mik1 up up 0 1
# Combat Chat 44: Haste (hak1): draws and effects, the mark at the cast (HOLD in a second original run: the same draws, one lost to the hold).
run orig_A_c44_mx_hak1 0 env ORIG=skip GBR_PLAYOUT=1 OURS_SEED=1 ./combat42/mx.sh hak1 11111111 mx_hak1 up up 0 1
# Combat Chat 43: main chat 97's throne room (s39door in slot G, seed 39600001, all QUICK; draws only: main's trace
# has no positions); the aligned sword's rating 0 (GAME.OVR 0xBF3E). Slot G is the Yarash save again after it.
run orig_G_c43_throne 0 bash -c "python3 combat43/putg.py combat43/saves/s39door G >/dev/null && DRAWS_ONLY=1 ./cmpfight3.sh G 39600001 '' right,up,enter $WHAT; python3 combat43/putg.py combat43/saves/slotG_yarash G >/dev/null"
# Combat Chat 44: main chat 98's (2), the throne room with MAGIC on (seed 39600002; the party on QUICK in the save:
# QUICKSET, MAGICAT=826, the first round's setup): the weapon choice's attack count (Haste mid-round) and the sweep
# cap cleared by an attack (two original runs agree). Slot G is the Yarash save again after it.
run orig_G_c44_throne_magic 0 bash -c "python3 combat43/putg.py combat43/saves/s39door G >/dev/null && QUICKSET=1 MAGICAT=826 DRAWS_ONLY=1 ./cmpfight3.sh G 39600002 '' right,up,enter $WHAT; python3 combat43/putg.py combat43/saves/slotG_yarash G >/dev/null"
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
# Combat Chat 10: the Player's c33b/c34e saves (combat6/g61 slots I, K, L via combat9/inst.sh; combat10/pf.sh, keys Up Enter, QUICK).
# 4:2 3,11 GRISHNAK (Hold Person's three aims, the targets last to first, resistances after the save; seed 12345678, cut at the
# fight's last draw 4836: the spoils follow), 2:20 0,14 the ogres and trolls (Protection from Evil and the to-hit; a troll up
# at the round's end), 4:21 2,11 the huge scorpion (poison from its second attack slot only, no d100 before the save).
[ $WHAT = ours ] && run orig_I_grishnak1 1 ./combat10/pf.sh I 12345678 tmp/cmp_orig.txt reg_I1
# Combat Chat 11: 4:2 seed 2468ace1 to the fight's last draw 3617 (melee attacks counted again: a third attacker strikes from behind).
[ $WHAT = ours ] && run orig_I_grishnak2 1 ./combat10/pf.sh I 2468ace1 tmp/cmp_orig.txt reg_I2
[ $WHAT = ours ] && run orig_K_ogres1 1 ./combat10/pf.sh K 12345678 tmp/cmp_orig.txt reg_K1
[ $WHAT = ours ] && run orig_K_ogres2 1 ./combat10/pf.sh K 2468ace1 tmp/cmp_orig.txt reg_K2
[ $WHAT = ours ] && run orig_L_scorp1 1 ./combat10/pf.sh L 13579bdf tmp/cmp_orig.txt reg_L1
[ $WHAT = ours ] && run orig_L_scorp2 1 ./combat10/pf.sh L 0badf00d tmp/cmp_orig.txt reg_L2
# Combat Chat 24: the nomads' kobold waves (Player 20's p20a3, 7:17 from s11c to s11k: walk to the camp at 0,0 W, rest,
# three waves; the original's trace cut at s11c). The approach cells 0x6DC0 / 0x6DC1 (SPRITE_START 0,2,0, then
# ENCOUNTER_MENU 0, [6DC0]): 36 of the 56 kobolds seated two squares ahead (ours seated 48 at distance 0).
# A segment replay (~13 min: ours plays it in real time, as the original's 738 s; needs the lab's p20a3 setup: logs/p20a3.*, .lab/player/saves/p20a3, its index lines).
if [ $WHAT = ours ]; then
  chmod u+w /home/aaron/gbr/combat_lab/logs/p20a3.segment_* 2>/dev/null
  OP_SEG_TIMEOUT=1200 combat18/seg.sh p20a3 s11c s11k   # Combat Chat 25: 600 s cut the third wave (the original takes 738 s)
  python3 cmpdraws.py traces/seg_p20a3_nomads.txt logs/p20a3.segment_s11c-s11k.txt > /home/aaron/gbr/combat_lab/tmp/reg_seg_p20a3.txt 2>&1
  combat16/restore_saves.sh > /dev/null 2>&1
  # Combat Chat 24's "stall" in the third wave was the old 600 s limit (Combat Chat 25: with 1200 s identical, all 37697);
  # a slower run cut by the limit: draws identical to ours' end past the second wave (26916) still count as a match.
  r=/home/aaron/gbr/combat_lab/tmp/reg_seg_p20a3.txt
  n=$(grep '^original:' $r | sed 's/.*ours: //'); fd=$(grep -o 'first difference at draw [0-9]*' $r | grep -o '[0-9]*$')
  if grep -q "^draws: identical" $r; then v=MATCH
  elif [ -n "$fd" ] && [ "$fd" = "$((n + 1))" ] && [ "$n" -gt 26916 ]; then v="MATCH (identical to ours' end, $n: cut by the time limit)"
  else v="DIFFERS: $(grep VERDICT $r)"; fi
  echo "seg_p20a3_nomads: $(grep '^original:' /home/aaron/gbr/combat_lab/tmp/reg_seg_p20a3.txt) VERDICT: $v"
fi

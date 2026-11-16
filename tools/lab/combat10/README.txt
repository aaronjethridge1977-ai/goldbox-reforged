Combat Chat 10 lab archive (over combat9_lab.tgz; unattended: the Lead's four faithfulness items, then sound).
Unpack over the lab after combat9_lab.tgz. Paths are the PC's (/home/aaron/gbr/combat_lab). No game data inside: the saves
named below are the Player lab's; install them as described.

Saves (combat9/inst.sh into combat6/g61):
  combat9/inst.sh ~/gbr/player_lab/.lab/player/saves/p2start/c33b_4-2_3-11 combat6/g61 I    (4:2 3,11 GRISHNAK)
  combat9/inst.sh ~/gbr/player_lab/.lab/player/saves/p2start/c33b_2-20_0-14 combat6/g61 K   (2:20 0,14 ogres, trolls)
  combat9/inst.sh ~/gbr/player_lab/.lab/player/saves/p2start/c34e_4-21_2-11 combat6/g61 L   (4:21 2,11 huge scorpion)

Fight tools (also in the repo's tools/lab/):
  combat10/pf.sh <slot> <seed> <trace> [tag]   a Player fight in ours from g61 <slot> (keys Up Enter, QUICK; the Player's
                 rerun1.sh SEGX keys), DRAWS_ONLY against the original's trace. regress.sh runs it for orig_I_grishnak1
                 (seed 12345678, the trace cut at the fight's last draw 4836: the spoils follow), orig_K_ogres1/2
                 (12345678 / 2468ace1), orig_L_scorp1/2 (13579bdf / 0badf00d): 45 fights.
  combat10/orighold.sh <save dir> <seed> <hold> [out] [keys]   the original from a Player save (slot A), held before a draw
                 (HOLDREC, HOLDITEMS); <hold> 0: no hold.
  combat10/stackat.sh <save dir> <seed> <hold> <ovr offset>    the same with HOLDSTACK (the held draw's call chain);
                 DSSNAP=1 also writes the data segment to tmp/stackat_<seed>_<hold>.ds.
  combat10/sideat.sh + sidebonus.py   the per-side to-hit bonuses ([DS:0x49D6]+0x6E0 / +0x6E2) at a hold.
  combat10/stopall.sh   presser, trace reader and DOSBox stopped. NOTE: killmine.sh's pattern must not be on your own
                 command line (an inline loop or heredoc holding 'trace.py run' killed the calling shell twice): use it
                 from a script file.
  combat10/p8, p9/   the Player's traces and cmpdraws for p8_pd1T/2T, p8_kt1T/2T, p9_sk3Tb, p9_sk4T.
  traces/orig_I_grishnak1.txt, orig_K_ogres1/2.txt, orig_L_scorp1/2.txt.

The rules found (GAME.OVR; the board's Rule changes, 2026-11-16):
  - The computer's spell aim 0x148BE: area code & 0xF: 0 self; 0xF one aim; 8-14 one aim (area); else (code & 3) + 1 aims.
    Each aim 0x14611 (computer path): up to 20 tries of 0x15FDF (forced new pick, d<list> at 0x160DB); a try is thrown
    away when the spell's effect (entry byte 10, DS:0x3204 + 16 id) is in DS:0x286C (51, 52, 53, 31) and the figure has
    one (START.EXE 0xBA:0x0B73), or for byte 15 (area) > 0 when the area round the figure holds a figure not of the
    enemy side (0x14740). A repeated figure counts once (0x14B3C). Spell table at DS:0x3200 + 16 id = entry byte 6.
  - Hold Person 0x28670: bonus -2/-3 (one target, cleric/MU), -1 (two); targets from the last; save 0x2BC4D, then record
    0x9F or 0x6C over 1 counts as saved; add-effect 0x2C540 dispatches category 9 (resistances, d100s) first, then
    "is Unaffected" if the pending effect was cleared or saved with byte 8 = 1.
  - 0x6B (elf) handler 0x115ED: d100 <= 90 clears a pending 0x35 (sleep) or 0x0B (charm) only.
  - Protection from Evil/Good (8, 9, 0x2D, 0x2E): handler 0xEFD2: -2 on DS:0x6822 and +2 on 0x6816 when the current
    figure's alignment (0xA0) is 2, 5 or 8 (9: good). Category 0xB runs at 0x13D89 (the attack, on the target) and 0x279CA
    (a touch spell) BEFORE 0x2BBA1 writes the d20 to 0x6822: no to-hit effect. Category 0xC runs in the save (0x2BC9A).
  - To-hit 0x2BBA1: d20 (0x2BBBF) into DS:0x6822 (20 -> 100), category 0xA on the attacker, 0x10 on the target, then hit
    if 0x6822 + attacker 0x110 + side bonus ([0x49D6]+0x6E2 party side, +0x6E0 monsters) >= the AC byte passed (target
    0x111 front, 0x112 rear; backstab 0x112 - 2 when 0x14D6F). 0x14319 raises the AC byte by 2 and 3 for range.
  - On a hit 0x13F3C dispatches category (attack slot + 1) on the attacker: 2 = 0x55-0x57, 0x44, 0x4F, 0x50, 0x4C, 0x49,
    0x4D; 3 = 0x40-0x46, 0x4F, 0x55-0x57. The attack loop counts slots down from the current one (0x13E74).
  - Monster poison 0x101A0: save (type 0, bonus per type), on a failure "is Poisoned", effect 0x37 through 0x2BD3C (no
    category 9), "is killed".
  - End of round 0xA087: 0x241A1 (effect clocks), each figure's category 0x13 and 0x2B9D1, dying counters, "Your Teammate
    is Dying", 0xBA:0x23DB (count), then CONTINUE BATTLE (0xA163).
  - Initiative is 0x1289F (d6 per figure with 0x10D set).

Open: 4:2 seed 2468ace1 draw 2507: GRISHNAK (0x110 = 47) hits DORN (0x111 = 62) with d20 9; side bonuses 0; no backstab
  (GRISHNAK 0x9C = 0); DORN not held; DS:0x6822 = 16 at the next draw (the damage d4). No handler that writes 0x6822 explains
  +7 (combat10 notes: every writer listed; handler 6 adds at most 3). Next: a breakpoint at 0x2BBA1 (DOSBox debugger build)
  or dump 0x6822 at a hold placed inside the to-hit (HOLD before 2506 shows the state before; 2507 after).

Sound (Lead's approved item, started):
  combat10/sfx.py list | wav <row> <out>   the original's sound driver (START.EXE unpacked, segment 0x8AE: code and data)
                 in Python on the game's data: every row's speaker output per tick. Header: the driver's layout.
  combat10/spk_test.gd + spk_cmp.sh   ours' port (scripts/ui/speaker.gd) against sfx.py: 21 of 21 rows identical.
  combat10/sndcap.sh <save dir> <seed> <secs> [keys]   the original with sound on (por_snd.conf: nosound = false,
                 SDL_AUDIODRIVER=dummy), DOSBox's wave capture (Ctrl+F6; keys.py now knows f6) into cap/; prints DS:0x5372
                 (1: PC speaker) and DS:0x5374 (10 in a fight).
  combat10/wavseg.py, sndmatch.py   the capture split into sounds; each matched to a row by length and quarter tones
                 (DOSBox records a high-passed square wave: edges are rises of 3000+ in 3 samples).
  cap/audio0001.wav (lab only, 14 MB, not archived): 60 s of the scorpion fight: the hit (row 6, cut at 0.107 s), the miss
                 (row 8: 298 Hz then 1200 Hz), row 9's low 72-98 Hz ticks (id 10, many: a move?).
  The game's ids (wrapper START.EXE 0x8BBC; DS:0x2612 = 0xFF stop, 0x2614 = 0 off, 0x2616 = 1 on, 0x2618-0x262C = 2-12):
    id 7 hit 0x13EF1, slays helpless 0x13C54, Bash (door menu) 0x17702; id 9 miss 0x13F6F (an attack with no hit);
    cast 0x27C38: id 11 spell 47, id 8 spell 51, id 2 the rest (0x27E08 clears DS:0x5374 first: plays out); Hold Person
    id 2 0x286FE; id 6 / 12 in 0x14EAB (0x1501A / 0x15060); id 10 at 0x3AD2, 0x4219, 0x13071 (0x12F0D), 0x16E0D, 0x171DF,
    0x17224 (0x17054, "Not Here"); id 11 0x3AE2; id 5 in 0x3154B (0x31564, 0x31748); START.EXE id 4 0x2C0D, id 3 0x2C18.
  Hooked in ours so far: hit, slays helpless, miss (melee and missiles). The rest: hear each in DOSBox first (sndcap.sh at
  the right moment), then hook.

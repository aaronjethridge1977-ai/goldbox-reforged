# Differential checks

One check = a lab save just before a story-critical event; both games play the same keys from it, then save;
`statediff.sh` compares the saves (script memory 0x4900-0x4AFF; each member's HP, max HP, experience, status,
coins and items). **MATCH** means identical after the ignore list below, where every entry has a reason.
Plan and decisions: ai-business-ideas `ideas/game-modernizer.md` (Methods 2 and 3, 2026-11-14).

## How to run one (main lane lab, chat 20)

- The start save: `mksave.py J <letter> <ecl> <block> <x> <y> <dir> [addr=val ...] [item<n>=<DAX>:<block>:<i>] [strong]`
  (from the shipped save J; never save over J, A or the other shipped files). Up once moves the party there.
- The original: `export DISPLAY=:99` first (WSL sets `:0`, and `pl.py` only defaults to `:99`), then
  `pl.py boot <letter>`, `pl.py do <keys> dump`. Save with ENCAMP, SAVE, F (the check's own slot).
- Ours: `ours.sh --save=<writable .cfg> --keys='load=<letter>,...,F2'` (keys replay only when that file exists;
  Godot's key names: `Up`, `Enter`, letters).
- Compare: `statediff.sh <our .cfg> F --ignore=4AFA,4AFB,4AFC,4AFD,4AFE,4AFF`.

**Ignore list**
- 0x4AFA-0x4AFF: the original writes them at save time from engine words (GAME.OVR 0x1FE9C / 0x1FEC2,
  research/pool-of-radiance-formats.md); no script of any data set reads or writes them. Chat 22: they are the
  three wall-set slots (the last LOAD_AREA_DECO's ids at 0x4AFA-0x4AFC, the slot numbers 1-3 after them), and the
  original reads them back when it loads a save; ours now writes them (and the data set at 0x5012) in its
  original-format saves, so a check whose start save ours made compares them too (check 6: 0 differences without
  the ignore list).

## The first five events

All five reach their event in both games from lab saves made as below (chat 20, checked in DOSBox and ours).

| # | event | start save | keys to the event | check |
|---|---|---|---|---|
| 1 | 3:8 the clerk's reward (Podol Plaza cleared) | `mksave.py J G 3 8 4 5 E 4AE7=254` | Up, Up, Enter x2 (ours Enter x3) to the treasure; SHARE, EXIT; Enter x5 | **MATCH** (chat 20) |
| 2 | 6:19 the silver bottle | `mksave.py J B 6 25 10 10 N 4A87=1 49C3=10 49C4=10 item1=ITEM8:50:0` | Up, Up (the dragon's cave, 10,9), Enter, ENTER CAVE: Diogenes's thanks (0xA3C7) | **MATCH** (chat 20, after two engine fixes: a band's LOAD_AREA_MAP leaves 0x49C5; a band step writes 0x49F0/0x49F1) |
| 3 | 4:2 the chest and seal | `mksave.py J D 4 2 11 14 E 4A97=255 strong` | Up, Up: the ogre chief's fight (ogre, 18 hobgoblins, 4 more), then OPEN IT / TAKE IT UNOPENED | reachable; the original's QUICK fight took ~16 minutes and stalls on GUARDING: the check needs a fight played with fixed keys and the original's dice (`cmpfight2.sh`, side lane) |
| 4 | 2:9 paying past the gate | `mksave.py J C 2 9 7 12 N 4A77=96 4A64=0 4A78=0 4AB9=0` | Up, Up (7,11): the bugbear's 15 gold, YES; Enter (at 8,5) | **MATCH** (chat 20): 3 platinum paid, 2 by the first member and 1 by the second, in both |
| 5 | 5:7 the finale | `mksave.py J B 5 7 3 7 S strong wplus1=10 wplus2=10 wplus3=10 wplus4=10 wplus5=10 wplus6=10` (chat 23) | Up, Up: the audience hall (event 8 at 3,8) | reachable; fights to Tyranthraxus follow (as 3) |

## The fights before checks 3, 5 and 10 (combat lane, Combat Chat 1)

Each fight is played roll for roll in both games with `cmpfight2.sh` (the combat lab: everyone on QUICK with MAGIC on,
CONTINUE BATTLE answered NO), so the state comparison can go on from the fight's end with both games' dice in step.
The start saves are made as above, then **`fixthac0.py J <letter>`**: the original ignores a character file's THAC0
(bytes 0x2D and 0x110; it works it out again before the fight, lab: the strong save's THAC0 1 fought as THAC0 19-20),
ours uses it, so `strong` alone gives ours a party that hits every time. Seeds are Turbo Pascal Random seeds set
with `seed.py` in the original and `tpseed=` in ours, at the point shown.

| check | save | keys before the seed | seed | keys after | fight | result |
|---|---|---|---|---|---|---|
| 3 | D: `mksave.py J D 4 2 11 14 E 4A97=255 strong`, `fixthac0.py J D` | Up | 11111111 | Up, Enter, Enter | the ogre chief, 18 hobgoblins and 4 leaders | **MATCH** roll for roll (15863 draws; regress.sh `orig_D_ogrechief`). Ours: `--keys=load=D,up,tpseed=11111111,up,enter,enter,quickall,magic,fightend,n` |
| 5 | B (not I: I is regress.sh's basilisk save): `mksave.py J B 5 7 3 7 S strong wplus1=10 ... wplus6=10` (chat 23: each member's readied weapon +10; `strong` no longer writes THAC0, so `fixthac0.py` isn't needed; in DOSBox the guards' fight then ends in about 6 minutes, QUICK, the party winning) | Up | 11111111 | Up, Enter, Enter, C (COMBAT at the menu) | the audience hall's guards (8TH LVL FIGHTERs) before Tyranthraxus | **matches 53157 draws** (122 rounds, everything recorded) once main lands the magic-armour movement fix (board request); without it ours splits at draw 960. **But the fight is a stalemate**: the strong party (AC -10) and the guards hit each other only on a 20, and the original had not finished after 45 minutes (59574 draws). For the state check this start needs a party that ends the fight (proposal on the board). Long fights: `OSECS=<s>`, `OWAITS=<n>`, `GTIME=<s>` (cmpfight3.sh) |
| 10 | G: `mksave.py J G 7 23 5 1 W strong wplus1=10 wplus2=10 wplus3=10 wplus4=10 wplus5=10 wplus6=10` (chat 23; was `strong` + `fixthac0.py J G`, which loses: in DOSBox the +10 party, QUICK, beat Yarash in about 40 s) (5,1 facing west: Up steps into 4,1, event 25, Yarash's room) | Up | 11111111 | Up, Enter, C (`MAGIC=1 KW=4 ./cmpfight2.sh G 11111111 up up,enter,c`) | Yarash (7:81) and 6 MUTANT LIZ-MEN (7:58) | **matches all 3689 draws** (Combat Chat 2; regress.sh `orig_G_yarash`, once main lands the magic-armour fix): computer-run item use (0xAFA4) built. **But the party loses**: Yarash's wand of paralyzation holds them one by one and the lizard men slay the held (the original goes to its death screen). For the state check (Yarash beaten) this start needs a party that wins: same proposal as check 5 (strong magic weapons), or another seed |

Kept in the lab: `data/diff_<area>_ours.cfg` and `data/diff_<area>_orig/` for each check run.

**State checks after the fights (chat 24, main lab, `ptrace_scope` 0).** Each fight replayed with `cmpfight2.sh` as in the
table, then the same keys in both games to the next walking menu and a save (the original: ENCAMP, SAVE, F; ours F2). Ours' keys
need `wait`s after `fightend,n` (the won screen and the treasure take a few frames). Kept: `data/diff_<area>_start/`,
`data/diff_<area>_orig/`, `data/diff_<area>_ours.cfg`.

| check | after the fight (both) | ours' keys | result |
|---|---|---|---|
| 10 (7:23) | Enter, E (EXIT), N (don't go back for the treasure) | `load=G,up,tpseed=11111111,up,enter,c,quickall,magic,fightend,n,wait,wait,wait,enter,wait,wait,e,wait,wait,n,wait,wait,F2` | fight MATCH; state **3 differences, the clock only**: original 11:00, ours 10:57 (3 rounds) |
| 3 (4:2) | Enter, E, N, T (TAKE IT UNOPENED: the iron box with Cadorna's seal) | `load=D,up,tpseed=11111111,up,enter,enter,quickall,magic,fightend,n,wait,wait,wait,enter,wait,wait,e,wait,wait,n,wait,wait,t,wait,wait,F2` | all 15863 draws identical; state **3 differences, the clock only**: 11:18 against 10:57 (21 rounds) |
| 5 (5:7) | Enter, E, N, Enter x2 (the dragon's offer), **seed 22222222** in both, A x6 (each member votes ATTACK), Tyranthraxus's fight on QUICK, then Enter, E and Enter through the spirit's scene (PROGRAM 8) to New Phlan's gateway (3:0 0,4 E); save | `load=B,up,tpseed=11111111,up,enter,enter,c,quickall,magic,fightend,n,wait,wait,wait,enter,wait,wait,e,wait,wait,n,wait,wait,enter,wait,enter,wait,tpseed=22222222,a,wait,a,wait,a,wait,a,wait,a,wait,a,wait,wait,quickall,magic,fightend,n,...` | the guards MATCH (9284 draws); **Tyranthraxus's fight splits at draw 794 of 1718** (his first own turn: the original draws a second target d6 at OVR 0x160DB, then the breath's saves; ours draws "breathe? d100"); request to Combat. The original's trace: lab `data/fin_orig_c24.txt` |

**Found: fights don't move our clock.** The original adds a minute at each round's end (GAME.OVR 0xA093: the clock routine
0x241A1 with digit 1, count 1, which also runs the effects down). Ours' `main.gd` adds `_combat.rounds()` after a fight, but
`combat_screen.gd` `_leave()` sets `_combat = null` before `finished`, so it adds 0 (request to Combat). With that fixed,
checks 3 and 10 should match with 0 differences. Also seen: the original keeps the party on QUICK from one fight
to the next (Tyranthraxus's fight played itself); ours' QUICK is per fight.

## The wilderness after the pyramid: save and load (chat 24, main-path gap)

Start: `mksave.py J G 7 26 0 5 E 4AB3=254 4AA2=0` (Yarash beaten, the land not yet seen recovering; into 7:26 from 1:24's
edge, as the pyramid's own way out isn't in the exits graph). Both: Up ("AS YOU LEAVE THE SORCERER'S PYRAMID..."), Enter,
G (GO BACK at the pyramid's door, 20,17), save F (`data/diff_7-26_orig/`; ours `load=G,up,wait,wait,enter,wait,wait,g,wait,wait,F2`).
Then both load that save (ours loads the original's F) and step north twice (19,14 -> 19,12), save again (`data/diff_7-26_orig2/`,
ours `data/diff_7-26_ours2.cfg`, keys `load=F,wait,up,wait,up,wait,F2`).

- First save: **1 difference**, 0x4A0A (original 0, ours 7): the tile loop's `ADD [6E7E], [6E7B], [4A09]` is a word write
  (operand type 3) that can pass 255; ours spills the high byte into 0x4A0A, the original keeps each ECL address of this
  window as its own 16-bit slot (GAME.OVR reads 0x49E5 at [0x49D2] + 0xE5 x 2). A per-visit byte, so the harm ends at the
  next area change; the general rule (word writes in the 0x4900-0x4AFF and 0x6B00-0x6EFF windows) needs an audit.
- Fixed: CALL 0xC003 / 0xC009 printed "[not built yet: call C003 ...]" in the message box after the recovery text. The
  original's CALL handler (GAME.OVR 0x3A36) acts only on 0x2C90, 0x8000/0x8001, 0xBA03, 0xC01E, 0xC018: the rest do nothing.
- After the load: **0x4A1E** original 0, ours 1. The original runs 7:26's init on load and keeps what it writes (its tile
  routine zeroes 0x4A1E at 0xAD6A); ours' `load_original_save` runs the init, then puts all of 0x4900-0x52FF back as saved.
  Chat 25: done (below). Also **0x4AFA-0x4AFF**: ours wrote the last dungeon's wall sets in a wilderness save, the
  original 0 / 0xFFFF (words; they are read back on a load).

**Chat 25: fixed, 0 differences in both halves** (wall-set slots included, no ignore list). (1) A load keeps the
init's writes: `load_original_save` runs the init from the saved image (the original's main loop skips its block load
while 0x49F8 is set, GAME.OVR 0x4093/0x7799) and puts nothing back but the square. (2) Each ECL address of
0x4900-0x4CFF, 0x6B00-0x6EFF and 0x9700-0x98FF is a 16-bit cell (GAME.OVR 0x814A write, 0x82DF read, classes at
0x7BCE), whatever the operand's type; the script image holds bytes. (3) The save's 0x1400 bytes after the data set are
those three cell arrays (0x800, 0x800, 0x400 bytes; the save writer at 0x1FE77), not 0x4900-0x52FF: ours' old
"0x5012" and "0x503E" were 0x6E12 (the data set) and 0x6E3E (the party's size). (4) The wall-set slots: in the
wilderness the original saves them as they stand (stale after a NEW_ECL, as the first save shows); a load in a band,
a new game and `LOAD_AREA_DECO 127` (the city: checks 1 and 5's original saves) leave wall set 0 in slot 1 and -1 in
2-3 (0, 0xFFFF, 0xFFFF / 1, 0xFFFF, 0xFFFF). (5) Byte 0x3206 of a save is the view (DS 0x49FA): 1 a 3D area, 2-4 the
bands 6:25, 7:26, 8:27; ours wrote 1 and **the original stopped on ours' wilderness saves with "Unable to load geo in
Load3DMap"**; now they load and walk (lab). Bytes 0x3204-5 are the wall ahead and the square's info (0xC04E/F), and
the image is restored whole on load (0x1E00 bytes: what longer scripts left past this one's end). Ours' save after
loading the original's and walking the same steps now equals it byte for byte up to the names but for 3 bytes (a
scratch cell, and the wall ahead / square info the original keeps from the last 3D square).

## Chat 25: checks re-run after the load and word-cell changes

Every check's start save and the original's end save loaded in ours before and after the change, saved at once:
only 7:26's moved (its init's writes, now as the original's), and the shipped save A's 0x6B00-0x6EFF cells, which
the old layout didn't restore (loading A in DOSBox and saving at once: ours now differs from the original in 4 of
the 0xA00 cells, the door-menu flags ours keeps at 0x6DDE-0x6DE0 and the party size the original writes at save
time; before, 36). Then each check against its original save (`statediff.sh` now compares words):

| # | keys, ours (with waits; saves in `data/diff_<area>_start/`) | result |
|---|---|---|
| 1 | `load=G,Up,Up,Enter,Enter,Enter,S,E,Enter x5,F2` | **MATCH** |
| 2 | `load=G,Up,Up,Enter,Enter,Enter,2 (IGNORE CAVE),F2` | 0x49F0/0x49F1 (original 5, 5; ours 10, 10), **the same on the old engine**; it matched in chat 20, so bisect (chat 26). Lead: a band step writes the party's map square there (main.gd `_overland_step`); the original's save has the map square 5, 5 (bytes 0x3201-2), ours keeps the 10, 10 `mksave.py` put in 0xC04B/C: find what sets 5, 5 in the original (the band's LOAD_AREA_MAP 4,4,0?) |
| 3 | chat 24's seeded keys (`tpseed=11111111`) | **MATCH** (after Combat Chat 4's clock fix: fights move the clock) |
| 4 | `load=C,Up,Up,Y,Enter x3,F2` | **MATCH** (needs waits: a Y before the menu is up is lost) |
| 6, 7, 9 | as above | **MATCH** (7 with the ignore list) |
| 8 | as above | **MATCH** with the ignore list (its quick save doesn't hold the save-time slots) |
| 10 | chat 24's seeded keys | **MATCH** (the same) |
| 5 | chat 24's seeded keys through the vote, both fights and the closing scene to New Phlan, F2 (after Combat Chat 4's 49a5ec7) | **all but 2 bytes**: 0x49FD/0x49FE (the sky) original 11/10, ours 8/9 after the ending (the same on origin/main without chat 25's changes); the fights MATCH draw for draw (Tyranthraxus: 1718 draws, the same survivors), party and flags agree. Open for chat 26: where the original sets the sky after the closing scene (New Phlan's day values 11/10; ours keeps the night or 5:7's) |

Keyed runs are not always repeatable when the PC is busy (check 5's first run lost a key during a reference check and ended with another member dead; run again, it matched). Reference check (seeded), with all of chat 25's changes: 3:11 87/84, 5:5 91/88 (= baseline).

## Chat 26: 10 of 10

**All ten checks match** (5 with the usual ignore list, its save-time wall-set slots), re-run after the two rule changes
below; driver and logs in the lab, `data/c26/checks/` (`run.sh <n> <area>` takes the keys from chat 25's log of that
check, with Left/Right/Down kept).

- **Check 2** was never broken: `data/diff_6-19_orig/` held an end save the original made from another start (its
  clock, map square 5,5 and other bytes differ too). Played again in DOSBox from `data/diff_6-19_start/` (G: Up; Enter on
  the dragon text; Up to the cave 10,9; ENTER CAVE, Diogenes's three pages, back on the band; IGNORE CAVE; save F),
  the original has 0x49F0/1 = 10, 10 and the map square 10, 10, as ours: **0 differences**. The old save is kept as
  `data/diff_6-19_orig_old/`. Lesson: a check's original save belongs with its start save; re-take both together.
- **Check 5's sky** (0x49FD/E): after any NEW_ECL the original (GAME.OVR 0x3EFA) runs the new block's init, then its
  **on-move** (0x3FFF, the entry at DS:0x49E3) and, unless that moves on, the square's event (0x400E). Ours ran the
  on-move only when a step brought the party (chat 13's rule); the closing scene's NEW_ECL into New Phlan comes from a
  square's event, so 3:0's on-move (sky 11/10 before 14:00) never ran and 5:7's 8/9 stayed. Lab: a jump into 3:0 0,4 E
  saved at once has 0x49FE = 10 (J's was 9). Ours now runs the on-move after every NEW_ECL; a new game and a load go
  through the main loop (0x403E: the init, then the adventure menu) and don't. Check 5: **0 differences**. Its keys
  need ~75 s of `wait` after the closing scene starts (Combat Chat 4's timed pages): `...,fightend,n,wait x6,enter,wait,
  wait,e,wait x150,enter,wait,wait,enter,wait,wait,wait x150,F2` (`data/c26/checks/5.log`).
- **Script DELAY** (opcode 0x3A, GAME.OVR 0x3465) waits game speed x 225 ms, no key (START.EXE 0x709:0xDBE); ours waited
  0.45 s x (speed + 1) / 5, half the original's at speed 4 (P59: the hemp market's "YOU WANDER..." then two DELAYs and a
  random overheard line, 2:20 0xA535). No check moves (the checks run `--fast`).

## Chat 26: main-path gaps (queue item 2)

Rules built in main's files from GAME.OVR, each seen in DOSBox; the screens that use them are Combat's (board request).

- **Load and item limits.** 0x23795 (an item for a character; treasure TAKE via 0x6F0D, the shop's BUY, TRADE): refused
  when the character holds more than 15 items (0xC7) or load (0x102) + the item's weight (0x37, x the count 0x39 when
  above 0) > START.EXE 0xBA:0x13AB (the STR allowance table, ours `load_allowance`) + 1500. Money (0x24CDD, TAKE MONEY
  0x2570F): every coin, gem or jewel weighs 1; over the ceiling nothing is taken. Lab: save E = `mksave.py J E 3 8 4 5 E
  4AE7=254 pp1=1351` (Thrender at 1995 of 2000), the clerk's reward: TAKE, MONEY, GOLD 6 refused, 5 taken.
  `PartyMember.max_load`, `can_take_item`, `can_take_coins`, `coins_room`.
- **Raise Dead** (the temple, 0x4A86): HP 1, status 0, effects 0x20 and 0x37 off; CON - 1; then if CON >= 14:
  cut = (max HP - HP rolled 0xB1) / w, w = the sum over classes of level x (fighters CON - 14, others 2 above CON 15,
  else 1); max HP - cut, except at CON 17+ without fighter levels. Lab: `mksave.py J E 3 0 8 6 W pp1=3000`, Brother
  Sean's CHRDAT patched dead; POOL, HEAL (End moves the list), RAISE DEAD, YES: CON 15, max HP 5 (from 10, rolled 5),
  as `PartyMember.raised_from_dead`.
- **Detect Magic** (spells 5 and 11, effect 5; its handler is empty): START.EXE 0xBA:0x443 builds an item list's line
  and puts "* " before the name when any party member has effect 5 and the item's byte 50 or 51 is above 0 or byte 54
  is set. Lab: `mksave.py J E 3 8 4 5 E wplus1=1 4AC0=1` (0x4AC0 stops City Hall's rest interruptions), Darkstar
  memorizes and casts Detect Magic in camp; Thrender's items: " YES  * FLAIL", " YES  BANDED MAIL".
  `GameItem.detect_magic_marks`, `PartyMember.party_detects_magic`.
- **CALL 0x2C4E, 0x2C51, 0xC003, 0xC009** (7:26 and 8:27's wilderness recovery): the original's CALL handler (0x3A36,
  value - 0x7FFF) acts only on 0x2C90, 0x8000/1, 0xBA03, 0xC01E and 0xC018, so these do nothing there, as in ours
  (chat 24's note confirmed).

## Chat 54: checks 49 (8:27, a bump into the water at the boat) and 50 (8:16, the moat), DIFFCHECKS 50/50; the band's refused step, the wilderness box, the nomads' kobolds

- **Check 49, 8:27 the boat again:** check 34's keys to the boat at overland 9,29 (shown 35,29; tpseed 11111111),
  STAY, Right into the water east: the original asks WILL YOU TAKE IT? again, facing E, no minute passing (DOSBox);
  TAKE BOAT: New Phlan 15,1 facing E. **DIFFERS on 586f0cf** (8 differences: ours stayed on the band, the clock
  18 minutes on), **MATCH on f5818d1**. Break test at 49: SUBTRACT 45/49, ADD 48/49.
- **Check 50, 8:16 the ruined castle's moat** (8:16's second check; check 7's start): the arrival at 8,14 N, PRESS,
  east to 11,14, south onto 11,15 (event 14: its on-move entry wants facing S and prints nothing on arrival), south
  again: AHEAD OF YOU IS A MOAT ... YOU CANNOT PROCEED (0x9C4D, 0x6DC9 = 255), the party stays at 11,15 S 11:00 in both
  (DOSBox, seed 11111111). **MATCH** on df5f23f. Break test at 50: SUBTRACT 46/50, ADD 49/50.
- **Fixed: a refused step on the band runs the square's event** (Player 20's (b), 7:26 11,28): GAME.OVR's band move
  (0x16EE3) refuses water and the poisoned river with no time passing, and the step routine then runs ECL entry
  [0x49E5] whether the party moved or not (0x4228), as in 3D (chat 48). p19c2 `begin s10d`: draws agree to 5003 of
  5410 (were 1568); the next difference is a fleeing goblin guard (Combat's).
- **Fixed (display): the wilderness box after leaving a non-wilderness block** (chat 53's (b)): the walking input
  (0x17054) ends with 0x49F9 = 0x49FA (0x173E7); an arrival sets 0x49F9 to the mode left (0x3F2B); the modes come
  from the block number (0x3F4C: 25-27 the wilderness, everything else 1, 6:19's cave too); on the wilderness branch
  (0x17285) a 0x49F9 under 2 redraws the whole screen (START.EXE 0xBA:0x2B5E: the ICONs, the view, the party list), so
  the box is empty at the first walking menu. Start-up sets 0x49F9 = 1 (0xE9BE). The redraw at the end of the arrival
  (0xBA:0x767) is the party list only. A 3D arrival (8:27's boat into New Phlan): an empty box in both (no text there).
- **Not PARTY_STRENGTH: the nomads' kobolds** (Player 20's (a)): ours' formula is the original's (0x200C, ECL opcode
  0x1D; the original adds into a byte, ours caps at 255). 7:17 0x9B20 asks for max(PARTY_STRENGTH, 56 - [4A00]) / 2
  per LOAD_MON; at the first wave [4A00] is 0, so 28 + 28 kobolds in both; the original's LOAD_MON (0x1196) stops only
  at 63. The original seats 36, ours 48: to Combat (placement). The ECL dispatch: a cmp chain at GAME.OVR 0x3C79-0x3EAD
  (`3C op 75 07 0E E8 rel`), e.g. 0x0B LOAD_MON 0x1196, 0x1C CLEAR_MON 0x1FA3, 0x1D PARTY_STRENGTH 0x200C.

## Chat 53: checks 47 (6:19, the silver dragon's cave) and 48 (7:22, the rocks), DIFFCHECKS 48/48; two input and display differences seen

- **Check 47, 6:19 (the dragon's cave, the CHALLENGE path):** `mksave.py J G 6 25 10 10 N 4A87=0 49C3=10 49C4=10
  strong`, tpseed 11111111. Up (the jump: "OFF IN THE DISTANCE..."), Up (10,9, 22:56: the dragon lands by a cave),
  E (ENTER CAVE: 6:19's magic mouth), S (STATE NAME AND INTENT), Enter, End, Enter (the vertical menu's CHALLENGE),
  Enter, S (SLAY DRAGON), Enter, F (FOLLOW), A (ATTACK: 0xA0DF `DAMAGE 192, 11, 6, 0, 4`: BAKSHI, RHIANNON and
  PHINEAS hit for 36 each in both), Enter, Enter (NEW_ECL 25: the cave menu again), E (the magic mouth again: 6:19's
  0x9918 tests 0x4A87's bit 128 with `COMPARE [6E7A], 1`, so the bit never stops it, in both), L (LEAVE), I (IGNORE
  CAVE). **MATCH** on 93d286e and 8c87c86. Lab `data/c53/chk47/`.
- **Check 48, 7:22 (outside Yarash's pyramid, the rocks):** `mksave.py J G 7 22 15 0 S`, tpseed 11111111. Up (the
  jump; the init puts the party on 15,0 S; the arrival's event: the secret-door roll, "A SECRET DOOR IS FOUND
  BEHIND YOU." in both), Enter, S (SEARCH on), Up x7 (15,7, ten minutes a step), Right (W), Up (14,7, 12:16: "YOU
  SEE ROCKS SCATTERED ABOUT..."), Enter (searching: the tingle, GO BACK / MOVE ON / THROW A ROCK), T, Enter (the
  menu again, 0x4A4D bit 2), G (GO BACK: 0x992D's table index 8 puts the party on 15,7 E), Left. **MATCH**. Lab
  `data/c53/chk48/`. (7:22's event tables: kind 0x9B91 + event, kind 5 the rocks at events 15-17, as ours reads them.)
- **The gate is DIFFCHECKS 48/48** (~60 s). Break test at 48: SUBTRACT 44/48, ADD over 200 47/48 (the same checks
  as at 46).
- **Seen, not changed (input): a script's horizontal menu with two or more choices ignores Enter in the original**
  (6:25's ENTER CAVE / IGNORE CAVE, 6:19's STATE NAME AND INTENT / LEAVE: Return and keypad Enter do nothing, End
  and Right don't move the lit choice; only the letters choose). One-choice menus (PRESS <RETURN>) and vertical menus
  take Enter. Ours takes Enter for the lit choice (the first). To design (board), like Q13's arrows.
- **Seen, not changed (display): after a NEW_ECL arrival the original redraws the whole screen once the scripts
  end, and the box goes blank:** the jump's NEW_ECL 25 prints "OFF IN THE DISTANCE..." (seen printing, the position
  line still the old area's) and then the box is empty, the overland drawn; after 6:19's LEAVE (NEW_ECL 25), IGNORE
  CAVE leaves an empty box, where the same IGNORE after a step (no NEW_ECL) keeps the question. Ours keeps the text
  in all three. Only seen in the wilderness (6:25); 3D areas and the rule's place in GAME.OVR (the arrival,
  0x3EFA-0x403E) not read. Next main chat.

## Chat 52: check 41 (6:1, the captain's door), five NO checks (42-46), the previous square after a stopped edge step, DIFFCHECKS 46/46

- **Check 41, 6:1's captain's door:** check 39's keys, then Right, Up (7,10), Left, Up to 7,11 (event 4, 0xAA17;
  0x4A09 and 0x4A0E are 0 from check 39's start): the two guards, SHOW PASS / LEAVE / BRIBE / ATTACK; B (refused:
  "GET OTTA' HERE YA SCUM'", ATTACK / LEAVE), L: 0xB5A5 puts the party back on its previous square, 7,10 S 18:35,
  no fight, the refusal's text kept in both games. **MATCH** on 246a7c8. Lab `data/c52/chk41/`.
- **Answering NO where the script prints nothing** (chat 51's box rule; statediff compares the state, the text was
  compared on the screens by hand), each from a `mksave.py J G` jump save, tpseed 11111111, in areas with no NO check:
  - **42, 8:13:** 10,14 S, Up to 10,15 (event 28, 0x99C1): DO YOU WANT TO LEAVE?, NO (EXIT), Left: the question
    stays through the turn in both. **MATCH**.
  - **43, 3:14 Kovel Mansion:** 7,5 W, Up to 6,5 (event 15, 0xAC2E): the two thieves, WILL YOU CHASE THEM?, NO
    (0xB343: SPRITE_OFF, PICTURE 255, EXIT; 0x4A16 = 255 from before the menu), Left: the text stays. **MATCH**.
  - **44, 2:20 the stable:** SEARCH on, 4,2 E, Up to 5,2 (event 5, 0xA3F6; 11:06): the original prints the stable's
    text and at once the leather bag's question (ours shows only the second: display only, the same box after);
    NO (0xB250: PICTURE 255, EXIT), Left: the question stays. **MATCH**.
  - **45, 4:21 Sokal Keep's south edge:** 7,15 S jump (the keep's init: 8,14 N, THE BOAT DISEMBARKS YOU), Enter,
    Right, Right, Up (8,15), Up through the edge door: DO YOU WANT TO TAKE A BOAT BACK TO PHLAN?, NO (0x9992: the
    stop 0x6DC9 = 255): the stopped step clears the box in both, no minute (10:57). **DIFFERED** on 246a7c8:
    0x49F1 original 15, ours 14.
- **The fix (`main.gd`):** a step off the map that the on-move script stops writes the current square to
  0x49F0/0x49F1, as any refused step (chat 42); one that leaves the area keeps the square before (check 7, 8:16's
  south edge into the wilderness). Still inferred from cases (the original reaches 0x49F0 through a base register:
  no literal address in GAME.OVR). Check 45 MATCH after it; the other 44 unchanged.
- **A lab trap found:** `data/c51/dc_new.sh` copies `$DC_DATA/game` with `cp -r`; the lab's `cd/game` is a symlink,
  so each check ran in the one shared `~/gbr/checks/data/game` (two checks at once raced: check 41 once played 42's
  start). `data/c52/dc_new.sh` copies with `cp -rL`. `diffcheck.sh` itself was never affected (its `data/game` is a
  folder); the shared copy's F and G slots were overwritten, which no check reads (each removes them first).
- **Check 46, 3:0 at night (the locked shop door):** `mksave.py J G 3 0 14 8 N 49C9=20` (the on-move's 0x99AF asks
  only from 20:00 on, 0x49C9 >= 14 giving 0x6E7D = 8, at a square with no event facing wall 9: 14,8 E), Up (jump),
  Right, Up: THE DOOR IS LOCKED. DO YOU WANT TO BREAK IN?, NO (0x99E4: the stop): the box cleared, no minute, in
  both. **MATCH**. Lab `data/c52/chk46/`.
- **Seen, not changed (a jump-save artifact, maybe more):** started facing E, ours asked the door's question at the
  jump's arrival (the arrival's on-move with 0xC04E computed for 14,8 E); the original asked nothing and its next Up
  walked through the door into the shop (15,8, 20:57): after a script's jump its 0xC04E/0xC04F keep the old area's
  values until a turn or step (after a turn it asks, 14,8 E 20:58). Real arrivals (an edge step, a boat) may show
  the same in a rare case (arriving at night facing such a door); not checked.
- **The gate is DIFFCHECKS 46/46.** Break test at 46: SUBTRACT 42/46, ADD over 200 45/46 (the same checks as at 40).

## Chat 51: check 38 (8:29 -> 2:20 -> 8:29: across the map edge both ways, no step carried on), checks 39 and 40 (6:1), the place compared, DIFFCHECKS 40/40

- **The fix** (Player 18's request): ours carried a step through a map edge (the leaving script's CALL 0xC01E) on into
  the new area when the arrival showed nothing: one square further in, a minute later (`main.gd` `_arrival_event`,
  from a chat 6 note "Slums 0,4 W arrives in Kuto's Well at 14,4"). DOSBox shows no such carry: 2:20 0,4 W arrives at
  8:29 **15,4 W, 07:20** (the minute of the step only), and 8:29 15,11 E at 2:20 **0,11** (with the Slums' greeting,
  where ours already stopped). Player 18's logs (p12-p18) agree in all 54 crossings. The carry and the VM's
  `stepped_through` flag are gone; a step through the edge now ends on the edge square, as a jump does.
- **Check 38:** check 36's start (8:29 7,14 S 06:52), tpseed **33333333** (60606063 and 11111111 and 44444444 roll an
  encounter on the way), the route 7,14 -> 7,8 -> 12,8 -> 12,9 -> 13,9 -> 13,10 -> 15,10 -> 15,11, east into the Slums
  (0,11 E 07:09, the greeting), 0,11 -> 0,8 -> 1,8 -> 1,7 -> 2,7 -> 2,4 -> 0,4, west into Kuto's Well (15,4 W 07:20),
  Left, Right; ENCAMP SAVE (slot J, copied as F). Ours: the same keys, `wait,wait` after them, then F2. **DIFFERS** on
  bdf2ea6 (ours at 14,4 07:21: 0x49C7 the clock, 0x49F0 the previous square); **MATCH** with the fix. Lab
  `data/c51/chk38/` (keys in `data/c51/k38.txt`), sealed as `~/gbr/checks/data/38`.
- **The box after a declined question (display only, chat 50's open item):** the original's MENU_HORIZONTAL leaves the
  text box as it is; what follows decides. DOSBox: NO at Kuto's Well (8:29 0xAF71: MENU, EXIT; both after a plain step
  onto 7,7 and after the climb up) keeps the question, through a turn, until a step to a square with its own text or
  none; the rowboat's NO (7:26 0xAD47) and the altar's two NOs (5:6, subroutine 0x9AD7) clear it with their own
  PRINT_CLEAR " "; the nailed door's NO (8:29 0xAA96, an on-move script that sets the stop 0x6DC9 = 255 first) clears
  it with the stopped step that follows. Ours cleared the box at any menu choice; now a script's horizontal menu
  leaves the script's text (`main.gd`, the menu branch of `_unhandled_input`; vertical, encounter, WHO, PARLAY and
  DAMAGE's pages as before). Ours from the same starts and keys shows what the original shows in all four cases.
- **Check 39, 6:1 at last (the Buccaneer base):** check 35's start and route (6:25, tpseed 11111111) to 12,31, ENTER
  instead of LEAVE: the party is taken in to 6:1's merchants' camp, 8,10 S ("YOU ARE IN THE MERCHANTS' CAMP AREA.", no
  minute passing; the gate text at 0x9BCF never shows in the original, nor in ours). **MATCH** on 317e966. Lab
  `data/c51/chk39/`, sealed as `~/gbr/checks/data/39`. **Every area now has a check.** The slave pen (0x9D96: the boy,
  the vertical menus) and the captain's door (0xAA4B: SHOW PASS / LEAVE / BRIBE / ATTACK) are the next 6:1 checks from
  this start (walks inside 6:1, guards' rolls on the way).
- **Check 40, 6:1's slave pen:** check 39's keys, then Right, Up (7,10: the camp text again), Right, Up to 7,9 facing the
  pen (0x9D96 wants the wall ahead, 0xC04E, to be 8): the three pages (the pen, the boy, the merchant), the vertical
  menu WHAT WILL YOU DO?, End, End, Enter: SAY NOTHING (0xB59A: PICTURE 255, EXIT; 0x4A01 = 1, the box cleared in
  both games, as a vertical menu's choice clears it). **MATCH** on 635dfbc, ours' log on the same squares and pages.
  Lab `data/c51/chk40/`, sealed as `~/gbr/checks/data/40`.
- **The gate is DIFFCHECKS 40/40** (~50 s). Break test (the clone `data/c44/brk` on origin/main): at 38 SUBTRACT 34/38,
  ADD over 200 37/38; at 39 (with the place compared) 35/39, 38/39; at 40 36/40, 39/40.
- **statediff.gd compares the party's square and facing** in a 3D area (the original's save 0x3201 x, y, facing x 2
  when the view byte 0x3206 is 1; ours' `[place]`): memory alone caught check 38's carried step only through 0x49F0
  and the clock. All 39 match with it; on bdf2ea6 check 38 now also shows `place: original 15,4 W, ours 14,4 W`.
- Lesson: `pl.py do` keys at 0.6 s apart were fine here, but a save made into the check's own start slot (J) loads the
  end state on the next `boot j`: put J back (`data/c50/slot.py`) after every ENCAMP SAVE J.

## Chat 50: checks 36 (8:29, climbing out of Kuto's well) and 37 (7:26, the rowboat and the pyramid), DIFFCHECKS 37/37

- **The fix first** (663cf93, Player 17's request): 8:29's climb up (0xA245: "YOU MAKE THE LONG, ARDUOUS CLIMB UP THE
  WELL.", LOAD_AREA_MAP 29, CALL 0x2C90, GOTO the search entry 0x9A23) reads the square's event from the map just
  loaded: on the street the well square (event table 0xAFCE -> 0xA2D1) asks "RUNGS ARE SET IN THE SIDES OF THE WELL
  WALL. DO YOU WANT TO CLIMB DOWN?". Ours followed a script's LOAD_AREA_MAP only when the script stopped, so 0x2C90 read
  the catacombs' square at 7,7 (event 16: "YOU ARE JUST EAST OF KUTO'S WELL.", no question). Now the VM's square read
  (`main.gd` `_script_square_info`) takes the map the script loaded.
- **Check 36:** check 30's start (8:29 7,14 S 06:52), Right, Right, seven steps north to the well at 7,7 (CLIMB DOWN?),
  YES (the catacombs: CLIMB UP THE RUNGS?), YES (the street: CLIMB DOWN?), NO; tpseed 60606063. The original: slot J
  (`data/c50/slot.py` copies a save renamed, the character-file names patched), `pl.py boot j`, `seed.py set 60606063`,
  the same keys, ENCAMP SAVE J (renamed F). Ours: `load=G,tpseed=60606063,Right,Right,Up x7,y,wait,wait,y,wait,wait,n,
  wait,wait,F2`. **MATCH** on 5a0764c; **DIFFERS** on 0a28128 (before the fix: ours asked nothing after the climb and the
  NO's `n` reached the walking screen's N key, which set the clock: 0x49C7). Lab `data/c50/chk36/`, sealed as
  `~/gbr/checks/data/36`. Break test at 36 (the clone `data/c44/brk` moved to 5a0764c): SUBTRACT 32/36, ADD over 200
  35/36.
- **Check 37, 7:26 again: a second event in the middle band, the cheap way.** 7:26's table (y 0xB04A [10, 11, 12, 26,
  27, 28, 14, 16, 29], counts 0xB061 [2, 3, 2, 2, 1, 1, 1, 1, 1], x 0xB053, kinds 0xB06A): 0 the abandoned camp
  (around the nomad camp; 0x4A0E), 1 the nomad camp at 12,11 (check 33), 2 the city's north edge (12,26 13,26: CITY /
  GRAVEYARD / LEAVE), 3 its east edge (13,27: NORTH / SOUTH / BOAT / LEAVE), 4 its west edge (11,28), 5 the rowboat
  (6,14), 6 the pyramid (6,16), 7 the boat home (7,29). Band-local x is the shown x minus 13. Start: check 33's
  (`bot_band1`, overland 14,20 W 06:33 in 6:25); nine north, five east (across the band edge at shown 15,11), three
  south to shown 19,14: "YOU HAVE FOUND A ROWBOAT HIDDEN AMOUNGST THE REEDS. WILL YOU TAKE IT TO THE PYRAMID?", YES
  (0x49C3 6, 0x49C4 16: "YOU ARE IN FRONT OF A MAGNIFICENT PYRAMID...", ENTER / GO BACK), GO BACK (0x49C4 14); tpseed
  11111111, no encounter. **MATCH** on 5a0764c. Honest limit: YES + GO BACK ends in the same state as NO (the party back
  at 6,14), so the check holds the route, the rolls and the clock, not the choice. Lab `data/c50/chk37/`, sealed as
  `~/gbr/checks/data/37`. Break test at 37: SUBTRACT 33/37, ADD over 200 36/37.
- **Seen, open for main (display only):** after NO at the well (0xAF71: MENU, then EXIT) the original keeps the question
  in the box (row 24 back to the walking menu); ours clears the box at any menu choice (`main.gd`, `_message.text =
  ""`). Not general: the rowboat's NO (0xAD47) clears the box in the original too. So the original's menu doesn't clear;
  the script's next ops do. Not changed yet: what ours does at 0xAD47-like paths must be checked first.
- Areas no check visits: 6:1 only, as before.

## Chat 49: checks 34 (8:27, the boat to New Phlan) and 35 (6:25, the slavers and the Buccaneer base), DIFFCHECKS 35/35

- **Check 34, 8:27 again: a second event in a checked band, the cheap way.** 8:27's band table (y at 0xABA6
  [8, 14, 15, 16, 29], counts 0xABB4 [1, 2, 3, 2, 1], x 0xABAB [11, 6, 7, 5, 6, 7, 6, 7, 9], kinds 0xABB9 [0, 1, 1,
  1, 2, 1, 1, 1, 3]): 0 the ruined castle (check 31), 1 the kobold horde (a fight), 2 the two caves (6,15: every
  neighbour is a kobold square), 3 the boat at 9,29. Start: check 31's (c34d's `bot_band3`, overland 3,20, shown 29,20
  E 12:50); six steps east and nine south (tpseed 11111111; no encounter on this route): "THERE IS A BOAT DOCKED HERE
  THAT WILL RETURN YOU TO THE CIVILIZED SECTION OF PHLAN. WILL YOU TAKE IT?", TAKE BOAT / STAY: STAY (`S`; 0xAAA2
  redraws the band's marks, writes nothing). The original: `boot j`, `seed.py set 11111111`, `right` x6, `down` x9,
  `s`, ENCAMP SAVE J (renamed F, the character-file names patched). Ours: `load=G,wait,tpseed=11111111,` the same
  arrows, `wait,S,wait,wait,F2`. **MATCH** on c6f6d30; one step short DIFFERS (0x49C4 28 / 29, the clock). Lab
  `data/c49/chk34/`, sealed as `~/gbr/checks/data/34`. Break test at 34: SUBTRACT 30/34, ADD over 200 33/34.
- **Check 35, 6:25 again.** 6:25's table (y 0xADD6 [8, 9, 10, 24, 30, 31, 32, 33], counts 0xADF5 [3, 3, 2, 1, 2, 5,
  5, 2], x 0xADDE, kinds 0xADFD; kinds 0-2 the dragon, 3 the anhkhegs (a fight), 4 the slavers ride by (0x9D2E: when
  0x4A8C = 255 and 0x4AA9, 0x4A10 are 0, the text and 0x4A10 = 1), 5 the Buccaneer base (ENTER / LEAVE), 6 the guards
  ride by (0x4A11 = 1), 7 the outpost (YES / NO)): slavers at 12,30 13,30 11,31 13,31 12,32 13,32 around the base at
  12,31; guards at 2-4,31-33 around the outpost at 3,32. Start: check 32's (`bot_band1`, overland 14,20 W 06:33);
  ten steps south (the tenth, to 14,30, refused by the map: no time passes, no roll, in both), west, south to 13,30:
  "A SMALL CARAVAN OF SLAVERS RIDE BY YOU TOWARD THE BUCCANEER BASE." (0x4A10 = 1), south refused, west to 12,30
  (nothing: 0x4A10 set), south to 12,31: "YOU HAVE REACHED THE BUCCANEER BASE...", ENTER / LEAVE: LEAVE; tpseed
  11111111, no encounter. **MATCH** on c6f6d30. Lab `data/c49/chk35/`, sealed as `~/gbr/checks/data/35`. Break test at
  35: SUBTRACT 31/35, ADD over 200 34/35 (35 uses neither).
- Seen, not a difference: the band scripts' eight-way tables (0x033D) are the heading times two; the original takes no
  diagonal step either (Home, PgUp, keypad 7 and 9 do nothing in the band).
- Areas no check visits: 6:1 only, as before.

## Chat 48: checks 30-33 (8:29 the catacombs' secret door; the three wilderness bands 8:27, 6:25, 7:26), DIFFCHECKS 33/33

- **Two engine fixes first** (7ce7091, d15afe3; Player 16's request): a script's [6B72] reads a plain cell, not the race
  (GAME.OVR 0x7C8F, the character window's read, has no case for 0x72; DOSBox at 8:29 5,8: the cell 0, 0x980D 0 after
  the search loop), so the secret-door searches' elf / half-elf +1 never applies; and every step attempt runs the
  square's event (ECL entry [0x49E5]) afterwards, a wall bump, a step the on-move script refuses and a locked door's
  refused try too (GAME.OVR 0x41A1-0x422D), unless the on-move script loaded a new script.
- **Check 30** is a Player run, not a lab save: Player 16's p16c3 in the original (start `p2start/p16c1_s6well`, the
  original's dice from tpseed 60606063), its keys as `segment.py` gives them (without `tplog`), slot H renamed G (start)
  and F (the original's checkpoint `s6pre12` at 8:29 1,10), the character file names in the saves renamed with them.
  It walks into Kuto's well, the arrow volley at 7,8, the secret door at 5,8 (eight d6 on arrival, nothing found; eight
  more at the bump north; LOOK finds it), the arrows at 4,13 and 2,10. Files in main's lab `data/c48/chk30/`.
- **Results:** MATCH on d15afe3; DIFFERS on f37a477 (before the fixes: ours found the door on arrival). All thirty:
  **DIFFCHECKS 30/30, ~40 s.** Break test (`data/c44/brk.py` on the clone `data/c44/brk` at d15afe3): SUBTRACT off by one
  caught (26/30), ADD over 200 caught (29/30). Also replayed (main's `data/c48/seglab/`, `OP_LAB` set): p16c2 (20 bumps
  north) 186 of 186 draws identical; p13b5 (Player 14's PICK) identical to draw 2350, then the kobold fight (Combat).

- **Check 31, 8:27 (the east wilderness band): the ruined castle, LEAVE.** The first check in a band. Start: c34d's
  `bot_band3.cfg` (overland 3,20 in band 2, shown as 29,20, 12:50) saved by ours' ENCAMP SAVE as slot G (as check 24's
  start); the original loads it. Keys: twelve steps north and eight east (the band's arrows move by compass; each step
  is 12 hours and an encounter roll; with tpseed 11111111 no encounter on this route), arriving at overland 11,8 (the
  band's position tables at 0xABA6 / 0xABB4 / 0xABAB / 0xABB9: y 8, x 11 is the castle; the docs' earlier "8,11" was
  y,x): "YOU FIND A RUINED CASTLE SURROUNDED BY QUICKSAND..." (0x4AA0 bit 0 set on arrival), ENTER / LEAVE: LEAVE. The
  original: `boot j`, `seed.py set 11111111`, `up` x12 and `right` x8 with waits, `l`, then ENCAMP SAVE J (renamed F).
  Ours: `load=G,wait,tpseed=11111111,` the same arrows, `wait,L,wait,wait,F2`. **MATCH**; one step short DIFFERS (a
  scratch copy, removed). Lab `data/c48/chk31/` (the start from `data/c48/g27/`), sealed as `~/gbr/checks/data/31`.
- **Check 32, 6:25 (the west band): the dragon.** Start: c34d's `bot_band1.cfg` (overland 14,20, 06:33) as G the same
  way. Eleven steps north and four west (tpseed 11111111): at 11,9 "OFF IN THE DISTANCE YOU SEE A LARGE DRAGON..."
  (0x4AA1 = 1), at 10,9 "...LANDS IN FRONT OF A CAVE" (0x4AA1 = 255), ENTER CAVE / IGNORE CAVE: IGNORE (`I`). The
  band's tables: y at 0xADD6, counts 0xADF5, x 0xADDE, kinds 0xADFD. **MATCH**; one step short DIFFERS (0x49C3).
- **Check 33, 7:26 (the middle band), entered from 6:25:** the same start, nine steps north and eleven east: at 15,11
  the next step east crosses the band edge (6:25's on-move: 0x49C3 = 3, NEW_ECL 26; no time passes on that step, in
  both), then east to overland 12,11: "YOU HAVE STUMBLED UPON A LARGE NOMAD CAMP..." (0x4A9F = 1), ENTER / LEAVE:
  LEAVE. **MATCH.** Seen, not changed: right after the crossing the original's place line shows 15,11 (ours' log
  16,11); one step on, both show the same numbers (25,11 at the camp).
- `diffcheck.sh` runs 33 (**DIFFCHECKS 33/33, ~40 s**). Break test repeated at 33: SUBTRACT 29/33, ADD over 200
  32/33 (at 31: 27/31, 30/31).
- **Areas no check visits now: 6:1 only** (the slave pen's GET HIM is behind a gate needing earlier state). A band
  check is cheap (a c34d checkpoint in or next to the band, ours' ENCAMP SAVE, a seed with no encounter on the route,
  the original from DOSBox: `pl.py boot`, `seed.py set`, arrows, ENCAMP SAVE); lab `data/c48/chk31..33/`, starts in
  `data/c48/g25/`, `g27/`.

## Chat 44: the replay waits for the engine, not for frames

No new checks (the Lead's note: the release's map first). Combat Chat 15 found checks 21 (3:11) and 24 (5:3) passing only
because the old automap's parchment made frames slow: ours' replay waited at most 300 frames after a key, and with the new
map's fast frames a chain of script DELAYs (24: AN ALARM..., A VOLLEY...) outlasted them, so Enter, E and F2 landed mid-text
and F2 never wrote. `_replay_keys` now waits until nothing is busy (ceiling 300 frames and 5 s, whichever later). Proof:
DIFFCHECKS 29/29 on origin/main, on origin/main + the new map (8b86606), and 21 / 23 / 24 / 25 with the old map's ink time
cut to 0.0001 s (Combat's failing case); break test repeated (SUBTRACT and ADD both caught). No key list or seal changed.

## Chat 43: DAMAGE's pages and PRESS <ENTER>, checks 25-29 (5:6 the altar, New Phlan's shops, 5:5 the giants, 7:22 the rocks room), DIFFCHECKS 29/29

- **The pause after scripted damage (the Lead's item 1, chat 42's finding):** the original's DAMAGE handler ends,
  whatever the form and whoever was hit, by drawing "press <enter>/<return> to continue" (GAME.OVR 0x37CD-0x37DF,
  colour 15) through START.EXE 0x709:0xBF5: row 24 cleared, the text at column 0, then GetKey (0x899:0x59), so any
  key goes on. Not after THE ENTIRE PARTY IS KILLED (ours opens the end program there, as before).
- **The hit lines (GAME.OVR 0x959F, seen in DOSBox at check 25):** "  NAME is hit FOR n points of Damage." / "  NAME
  dies. ", printed with the column set to 38 first (0x9691), so each starts on a new row; a line that fills its row
  leaves the cursor on the next one (a blank row follows it: CEDRIC's and DIRTEN's 38-character lines); a new row
  past row 22 makes the printer show "PRESS ANY KEY TO CONTINUE" and start a cleared box at row 17; a cursor already
  past row 22 before a line gives a "PRESS <ENTER>/<RETURN>" page instead (0x9661, not seen). Each member's HP drops
  as their line prints. Ours (`ecl_vm.gd _box_line`): the same rows and pages as a queue of "press" menus
  (`_press_queue`); `main.gd` draws the page's prompt on row 24 in white, takes any key, and keeps a page's leading
  blank row. **Left:** ours' party list shows every member's new HP from the first page (the original lowers them
  page by page; the list is drawn by `game_screen.gd`, Combat's). Ours' pages at the altar: lab
  `data/c43/shot/press.png`; the original's in the run's dumps (`data/c35/chk25/orig.log` has only the end).
- **Check 24's ours keys** gain the key the original's already had (`...End,wait,Enter,wait,wait,wait,Enter,wait,E,
  ...`), resealed (`seal.sh 24`). With the old keys ours now fails check 24 (0x49C0: the E went to the prompt).
- **Check 25, 5:6 (Valjevo, temple side): the altar** (1,0, square type 8 → 0xA758, inside: bit 64, no patrol
  roll). Start: c34d's `bot_valjevo6.cfg` (0,0 W, 07:39) saved by ours' ENCAMP SAVE into an empty slot G (the
  original loads it). "YOU ARE BEFORE THE ALTER. NEAR IT IS THE OFFERING BOX..." YES: 0x4A6A bit 1, the treasure
  (THE PARTY HAS FOUND TREASURE!, EXIT, NO to going back), "THERE IS A FEELING OF SOMETHING IMMENSE AND EVIL..."
  (PRESS BUTTON), DAMAGE 224, 2, 10, 2, 0 (the whole party, no save: one roll, 12 each at seed 11111111), two pages
  (four lines, then three), the swords: NO. Keys: the original `wait=2 right wait=1 right wait=1 up wait=3 y wait=3
  enter wait=2 e wait=2 n wait=4 enter wait=4 space wait=3 enter wait=3 n wait=2` (SEED=11111111); ours
  `load=G,wait,tpseed=11111111,Right,wait,Right,wait,Up,wait,wait,Y,wait,wait,Enter,wait,E,wait,N,wait,wait,Enter,
  wait,wait,Space,wait,Enter,wait,N,wait,wait,F2`. **MATCH**, 0 differences. Lab `data/c35/chk25/`
  (`mkcheck35.sh 25`), sealed as `~/gbr/checks/data/25`; `diffcheck.sh` runs 25 (~38 s). Break test repeated (a lab
  copy, removed): SUBTRACT off by one caught (4, 18, 20, 21: 21/25); ADD over 200 caught (18: 24/25).
- **Checks 26 and 27, 3:0 (New Phlan): EXIT from a shop with no purchase** (the Lead's question for Jeremy: where
  does the party stand after a shop?). Starts: c34d's `bot_shopped.cfg` with its place set beside a shop door (13,9
  N for the arms and armour shop at 13,8; 11,9 S for the silver shop at 11,10), saved by ours' ENCAMP SAVE into slot
  G. Keys: the original `wait=2 up wait=3 y wait=3 e wait=3`; ours `load=G,wait,Up,wait,wait,Y,wait,wait,E,wait,
  wait,F2`. Both games leave the party on the shop's square, facing as it came in (13,8 N / 11,10 S, 06:01).
  **MATCH**, 0 differences each; no engine change. Pool's only shops are New Phlan's four (a scan of every ECL
  block for a COMBAT with 0x6EF6 = 1: 3:0 only). Lab `data/c35/chk26/`, `chk27/`. DIFFCHECKS 27/27; break test
  repeated (SUBTRACT 23/27, ADD over 200 26/27).
- **Check 28, 5:5 (Valjevo, the tower giants, LEAVE)** (10,11, square type 2 → 0xA485): from c34d's
  `bot_valjevo3.cfg` (11,7 W, 12:43) by ours' ENCAMP SAVE; nine steps over outdoor squares (patrol rolls: none at
  seed 11111111) to "THIS TOWER IS OCCUPIED BY FOUR GIANTS...", PRESS BUTTON, "'FROGS AND TOADS NOT SAME THING...'"
  YES / NO / ATTACK / LEAVE: LEAVE ("AS YOU QUICKLY LEAVE THE ROOM...", 0x9D0C) puts the party back on its previous
  square (0x49F0/1: 9,11) turned round (W). No flag; it checks the previous-square fix of chat 42 in a third place.
  Keys: the original `wait=2 left wait=1 up wait=1 right wait=1 up wait=1 up wait=1 up wait=1 left wait=1 up wait=1
  left wait=1 up wait=1 right wait=1 up wait=1 up wait=1 left wait=1 up wait=3 enter wait=3 l wait=3`; ours the same
  turns and steps from `load=G,wait,tpseed=11111111,`, then `Enter,wait,wait,L,wait,wait,wait,F2`. **MATCH**. Seen,
  not changed: the original's status line still shows the old facing (E) after LEAVE until its next redraw (the
  CAMPING line shows W); ours shows W at once.
- **Check 29, 7:22 (Yarash's pyramid, outside): the rocks room with SEARCH on** (14,7, square type 14): from c34d's
  `bot_pyramid2b.cfg` (15,12 S, 20:17); S (SEARCH), right, right, up x5, left, up: "YOU SEE ROCKS SCATTERED ABOUT THE
  SMOOTH FLAGSTONES.", PRESS BUTTON, GO BACK / MOVE ON / THROW A ROCK: THROW A ROCK ("SUDDENLY IT DISAPPEARS WITH A
  FLASH!", 0x4A4D bit 0), PRESS BUTTON, GO BACK. Seed 11111111. **MATCH**. (Without SEARCH the party is flashed away
  to 7:23: coverage-areas.md, 7:22.)
- `diffcheck.sh` runs 29 (**DIFFCHECKS 29/29**, ~45 s). Break test repeated at 29: SUBTRACT off by one caught (4,
  18, 20, 21: 25/29); ADD over 200 caught (18: 28/29).
- Not done: 6:1 (the slave pen's GET HIM, 0x4AA9 = 254, is behind a gate needing earlier state: `bot_heir` is after
  it), the wilderness bands 6:25, 7:26, 8:27 (events by the overland position 0x49C3/0x49C4 through byte tables, an
  encounter roll each step; 8:27's ruined castle, ENTER / LEAVE, sets 0x4AA0 bit 1 at overland 8,11).
- 5:6's other no-fight events with a flag: the smokehouse (0,6: 0x4A69 bit 64) and the coal storeroom (9,5 / 1,13:
  bit 16), both outside squares away (patrol rolls on the way). Areas no check visits now: 6:1, 6:25, 7:26, 8:27.

## Chat 42: check 24 (5:3 the portcullis), two engine fixes, DIFFCHECKS 24/24

The standing list (Q6, item 1), after the Lead's items (showcase item 5, test build 2's dry run).

- **The start (new way into the castle):** c34d's checkpoint `data/c34/cp_c34d/bot_valjevo5.cfg` (5:3 at 12,7 E,
  17:04) loaded in ours and saved by ours' ENCAMP SAVE into an empty slot G (`--keys=wait,E,wait,S,wait,G,wait,wait,
  N`): **the original loads it** (chat 40's jump into 5:3 dropped it to DOS). Any c34d checkpoint can start a check
  this way.
- **Check 24, 5:3 (Valjevo's outer castle): the portcullis** (the step west from 12,8 into the gate, on-move script
  0xA8A0): "A DEEP VOICE CALLS DOWN, 'WHAT IS THE PASSWORD?'" GIVE THE PASSWORD / FORCE THE GATE OPEN; FORCE: "AN
  ALARM STARTS RINGING!" (0x99D8: 0x4A64 = the hour + 1, the hour kept in 0x49C8/9), 0x4A6A bit 64, "A VOLLEY OF
  BOULDERS..." (DAMAGE 12, 2, 6, 0, 48: twelve throws at random members, each a d20 to hit, 2d6), then the door's
  LOCKED menu, EXIT. Seed 11111111: CEDRIC 5, ARN 10, BRAM 4, ELWEN 9 in both. (GIVE THE PASSWORD: the password is
  RHODIA, 0xAA5C; it writes only 0x6DC9, so FORCE is the one checked.) Keys: the original `wait=2 up right up right
  up up end enter wait=15 enter e` (End moves its vertical menu, Up/Down don't; it waits on PRESS <ENTER> after the
  boulders); ours `load=G,wait,tpseed=11111111,Up,wait,Right,wait,Up,wait,Right,wait,Up,wait,Up,wait,End,wait,Enter,
  wait,wait,wait,E,wait,wait,F2`. **MATCH**, 0 differences. Lab `data/c35/chk24/`, sealed as `~/gbr/checks/data/24`.
- **Fix 1, DAMAGE's draws (`ecl_vm.gd _damage`):** the original rolls the damage, then **always** picks a random
  member (dice 1 x party size, GAME.OVR 0x354C-0x355E) unless 0x40 (the whole party) is set, before it tests 0x80;
  the volley form (no 0x80) and the selected member's form never use that pick. Ours drew it only in the random
  member's form, so the volley form was one draw short (the first take: the same four hits but ARN's on the wrong
  members). Found with `trace.py` (the draws in `data/c42/trace24.txt`: 2 damage, the pick at 0x355e, then per
  throw member 0x36ad, d20 0x2bb4d, the next damage 0x3702).
- **Fix 2, the previous square (`main.gd _try_move`):** the original writes the square it stands on to
  0x49F0/0x49F1 at a step's attempt, before the on-move script, so a refused step (the gate) leaves the current
  square there; ours wrote it only on a completed step (0x49F0: original 12, ours 13). Not for a step off the map:
  check 7 (8:16's south edge into the wilderness) keeps the square before in the original. Inferred from these two
  cases; a wall bump with no script in between wasn't seen separately.
- `diffcheck.sh` runs 24 (**DIFFCHECKS 24/24, ~35 s**). Break test repeated (a lab copy, removed): SUBTRACT off by
  one caught (4, 18, 20, 21: 20/24); ADD over 200 caught (18: 23/24).
- Seen, not changed: ours doesn't wait on "PRESS <ENTER>" after the boulders' damage lines (the original does), so
  the keys differ there; a pacing difference left open for main (board), not in the saved state.
- Areas no check visits now: 5:5, 5:6, 6:1, 6:25, 7:22, 7:26, 8:27. 5:6 next: `bot_valjevo6.cfg` the same way.

## Chat 41: checks 22 (the save files) and 23 (5:4 the records building), DIFFCHECKS 23/23

Player 12's request (Lead's item 1): ours' save writer left 0-byte `CHRDAT<x><n>.ITM` / `.SPC` files for a member with
no items / no standing effects; the original loads a 0-byte .ITM as one garbage readied item (THAC0 148, ENCUMBRANCE
60420, every purchase refused as overloaded).

- **The original (DOSBox, lab `data/c41/`):** from save G with member 1's items taken out (record 0xC7 = 0, no .ITM)
  and member 4 (a human: only a Bless) without its .SPC, ENCAMP SAVE F over a slot holding a stale `CHRDATF1.ITM`,
  a stale `CHRDATF4.SPC` and a whole stale member 7: the original writes **no** .ITM for member 1 and **no** .SPC
  for member 4, and **removes** the stale ones; member 7's files (past the party's size) **stay as they were**.
- **Ours (`scripts/game/original_save.gd`):** an empty list now writes no file and removes the member's old one
  (`_put_or_remove`); files past the party's size are left, as the original. The record's item count (0xC7) is now
  the number of records written.
- **Check 22** (`~/gbr/checks/data/22`, sealed): that start, ours' keys `load=G,wait,E,wait,S,wait,F,wait,wait,N,
  wait,E,wait,wait,F2` (F2 is ignored while ours' camp is open: EXIT first). A check with a `files` list (new in
  `diffcheck.sh`) clears slots F and G in its game copy before the start (the shared copy's own G files would fill
  the start's gaps), then compares the `CHRDATF*` files ours left (names and sizes) with the original's before the
  usual statediff. **MATCH**; on the old writer: `DIFFERS (files) > CHRDATF1.ITM 0 > CHRDATF4.SPC 0`.
  **DIFFCHECKS 22/22, ~35 s.**
- **statediff fix:** it read every `CHRDAT<X>1-8.SAV` beside the save as the party; it now reads the members the
  save names (count at 0x3208, names from 0x3209), so a stale member past the party's size isn't counted (check 22's
  member 7 showed as "DIRTEN is in the original's party"). The other twenty-one still MATCH.
- **Break test repeated** (lab copy `data/c41/oldrepo`): SUBTRACT off by one caught (checks 4, 18, 20, 21: 18/22);
  ADD off by one over 200 caught (check 18: 21/22).
- `tools/check_save_files.gd <game folder> <slot> <scratch>`: the same rule without either game (loads a slot,
  empties member 1, saves over stale files, checks the files): PASS on the fix, 2 FAILs on the old writer.
- **Check 23, 5:4 (Valjevo Castle, north side): the records building** (event 8, entered at 15,9 facing S): "YOU ARE
  IN A BUILDING FULL OF RECORDS. DO YOU WISH TO SPEND HOURS READING THE RECORDS?" YES; with no alarm (0x4A64 = 0) and
  the hour 17 or less, each round draws RANDOM 19 (under 3: a scribe walks in); seed 11111111 gives none: "...RED
  WIZARDS OF THAY ARE ALLIED TO TYRANTHRAXUS" (0x4A68 = 1), the pattern of his activities (two texts, 0x4A68 = 2),
  "TO FIND ANYTHING MORE YOU WILL HAVE TO SPEND SO MUCH TIME...". No fight; the steps roll no patrol while 0x4A64 = 0
  (0x995D returns "less" and the step skips the RANDOM). **Start:** not a jump (chat 40: the original dropped to DOS
  on 5:3's jump): c27a's own checkpoint `data/c29/fx/c27a_5-4_giant` (written by ours' bot, loaded by the original
  since Player 5), at 13,12 E, slot I -> G, its 0-byte .SPC files left out (the writer's old bug). Route (route.py,
  avoiding events): Left, Up x4 (13,8), Right, Up, Up (15,8), Right, Up (15,9 S). Keys, the original `wait=2` first;
  ours `load=G,wait,tpseed=11111111,Left,wait,Up,wait,Up,wait,Up,wait,Up,wait,Right,wait,Up,wait,Up,wait,Right,wait,
  Up,wait,Y,wait,Enter,wait,Enter,wait,Enter,wait,wait,F2`. **MATCH**, 0 differences (both at 15,9 S 13:33, 0x4A68
  = 2). Lab `data/c35/chk23/` (`SEED=11111111 mkcheck35.sh 23 5-4 ...`), sealed as `~/gbr/checks/data/23`.
- **`diffcheck.sh`: every check now clears slots F and G in its game copy before its start** (was only check 22):
  the shared copy's own G files filled a start's gaps (check 23's members with no .SPC got the copy's). All 23 MATCH
  after it; the break test repeated on 23: SUBTRACT caught (4, 18, 20, 21: 19/23), ADD over 200 caught (18: 22/23).
- Areas no check visits now: 5:3, 5:5, 5:6, 6:1, 6:25, 7:22, 7:26, 8:27. For the castle's other parts, start from an
  original-loadable save already inside (c27a's checkpoints; the Player's) rather than a jump.
- Seen, not changed: a dwarf whose .SPC is missing loads in ours with its racial effect (0x7C) back (`from_bytes`
  adds the race's effects), where the original would have none. Only a hand-edited save gets there (every original
  save of a demihuman carries the .SPC), so it is noted, not matched.

## Chat 40: check 21 (3:11 the dueling room), DIFFCHECKS 21/21

The standing list (Q6, item 1). Areas no check visits now: 5:3, 5:4, 5:5, 5:6, 6:1, 6:25, 7:22, 7:26, 8:27 (6:25, 7:26 and 8:27 are wilderness: their events sit on the overland's coordinate tables, e.g. 6:25 0xADD6 / 0xADDE; 6:25's outpost approach writes 0x4AB4 253 -> 254 with no menu when 0x4A98 = 255).

- **Check 21, 3:11 (the Training Schools; the school shares New Phlan's map, its squares 5-9 by 0-2, with its own
  script):** the dueling room (event 14 at 7,2): "THE ROOM IS FILLED WITH DUELING PAIRS." (0x4A05 = 1), Enter, the
  arena master's figure walks up (three DELAYs and SPRITE_ADVANCEs), DUEL? NO (0x4A01 = 1), "DO YOU SEEK A PARTNER
  FOR YOUR ADVENTURING?" NO (0x4A08 = 1). On the way the notices at 6,2 (event 10, 0x4A00 + 1). No fight, no dice on
  the path (the seed set anyway, as 20). Start `mksave.py J G 3 11 5 2 E` (one real step before the notices). Keys,
  both games: Up (the jump), Up, Up, Enter, N, N; ours
  `load=G,wait,tpseed=11111111,Up,wait,Up,wait,Up,wait,Enter,wait,N,wait,N,wait,wait,F2`. **MATCH**, 0 differences.
  `~/gbr/checks/data/21` (lab `data/c35/chk21/`, made with `SEED=11111111 mkcheck35.sh 21 3-11 ...`). The original
  took the first Up only after a 2 s wait from the boot (the first take ended at 6,2: one Up lost, not a game
  difference); its keys now start `wait=2`. `diffcheck.sh` runs 21: **DIFFCHECKS 21/21, ~34 s**.
- **Deliberate-break test repeated** (the check list changed; a scratch copy in /tmp, removed): SUBTRACT off by one
  **caught** (checks 4, 18, 20 and now 21, `17/21`, exit 1); ADD off by one over 200 **caught** (check 18, `20/21`,
  exit 1).
- **Tried and set aside: 5:3 (Valjevo's outer castle), the loose stone** (event 5 at 0,2, entered from 1,2 W with
  SEARCH on: "UNDER A LOOSE STONE YOU FIND SOME TREASURE. DO YOU TAKE IT?" YES: 0x4A65 bit 8, a treasure find of
  200 gold, no monsters; event 5 found through the table at 0x9B99 (event -> index) and the ON_GOTO at 0x9B5D).
  Ours plays it from `mksave.py J G 5 3 1 2 W` (keys `load=G,wait,tpseed=11111111,Up,wait,S,wait,Up,wait,Y,wait,
  wait,Enter,wait,wait,E,wait,N,wait,wait,F2`), but **the original drops to DOS on the jump's first step** (the
  same as chat 35's jump into 1:24's map 31). A start needs the original's own save in 5:3 (walked in, or a jump to
  a square of 5:3's that loads, then ENCAMP SAVE there). Lab `data/c35/chk22/` (not installed).
- The same session's display fix (Rule changes, chat 40: a script's SPRITE_ADVANCE to distance 0 shows the
  encounter's picture; cleared after a fight) changed no check: 20/20 before check 21 was added.

## Chat 39: checks 19 and 20 (8:29 the nailed door and the woman; 3:0 the harbour master), DIFFCHECKS 20/20

The standing list (Q6, item 1): the next checks go to the areas none of the eighteen visits (3:0, 3:11, 5:3-5:6, 6:1,
6:25, 7:22, 7:26, 8:27, 8:29). One this chat:

- **Check 19, 8:29 (Kuto's Well's catacombs):** the nailed door south of 7,13 (event 21 facing S: "THE DOOR HAS BEEN
  NAILED SHUT. WILL YOU FORCE IT OPEN?", YES: 0x4A23 bit 16, the step goes on into 7,14) and the wide-eyed woman behind
  it (event 22: her warning, 0x4A23 bit 2). No dice, no fight. Start `mksave.py J G 8 29 7 11 S 4A23=8` (bit 8: the
  lizard patrol before the door, a set fight, already beaten). Keys, both games: Up (the jump), Up, Up (7,13), Up (the
  question), Y, Enter, Enter; ours `load=G,wait,Up,wait,Up,wait,Up,wait,Up,wait,Y,wait,Enter,wait,Enter,wait,wait,F2`.
  **MATCH**, 0 differences (0x4A23 = 26 in both, the party at 7,14 S, 10:59). Lab `data/c35/chk19/` (made with
  `mkcheck35.sh 19 8-29 ...`), installed and sealed as `~/gbr/checks/data/19`.
- **Check 20, 3:0 (New Phlan): the harbour master** (event 2 at 11,1, entered facing N): EAST (0x4AC4 = 1), WHO WILL
  PAY? the second member (End), BAKSHI's platinum 2 -> 1 (SUBTRACT on the member's record through LOAD_CHAR), 0x4A07
  and 0x4A01 = 1. No dice on the path. Start `mksave.py J G 3 0 12 4 N 4AC5=1 4AA7=254` (Rolf's tour done; Sokal Keep
  cleared, so the harbour offers all four boats and asks for the fare). Keys, both games: Up (the jump), Up, Up, Left,
  Up (11,2: "TO THE NORTH IS THE PASSENGER DOCK."), Right, Up (the harbour master), E, End, Enter, Enter; ours
  `load=G,wait,tpseed=11111111,Up,wait,Up,wait,Up,wait,Left,wait,Up,wait,Right,wait,Up,wait,E,wait,End,wait,Enter,wait,Enter,wait,wait,F2`.
  **MATCH**, 0 differences. `~/gbr/checks/data/20`. `diffcheck.sh` runs twenty: **DIFFCHECKS 20/20, ~33 s**.
- **Deliberate-break test repeated** (the check script's list changed; scratch copies in /tmp, removed): SUBTRACT off
  by one **caught** (checks 4, 18 and now 20, `17/20`, exit 1); ADD off by one over 200 **caught** (check 18, `19/20`,
  exit 1).
- **Found making check 20 (not in the check): the original's WHO WILL PAY? ignores Down** (the first take with Down
  had THRENDER GRONE pay in the original, BAKSHI in ours); End moves the choice in both. Ours also takes the arrows
  in WHO menus (`main.gd`, the "who" menu keys): an addition, on the board to design.
- **Lab-only, not a game difference: a jump save leaves the original's square byte (0xC04F) stale.** From the first
  start (`mksave ... 7 12 S`, the jump straight onto the square before the door) the original asked about the door on
  the first step from 7,12, at 10:56, then opened it into 7,13; ours (and the original after a real step, start
  7,11) asks only when stepping south from 7,13. The original's on-move script reads 0xC04F, which the jump (the
  patched on-move's NEW_ECL) doesn't refresh until a real step; ours refreshes it on loading the area. Start a
  jump save at least one real step before any on-move event (as 7,11 here).

## Chat 37: Main item 7 (an init that stops for the player), no new check

- **Fixed in `main.gd`:** after a step or NEW_ECL into an area, the original (GAME.OVR 0x3EFA) runs the init, the
  on-move script and the square's event in turn, however long the init runs. Ours did so only for an init that ran
  through at once; one that stopped for the player (Rolf's tour, 3:0's init when 0x4AC5 is 0) ended with nothing
  after it. Now `_after_vm` runs the arrival (`_arrival_event`) when such an init ends. Rolf's tour from
  `mksave.py J G 3 0 15 1 W 4AC5=0`, Up, Enter x9: ours ends at 0,4 W 10:56 with the gateway text (0xAAD8) and the
  AREA menu, as chat 36's DOSBox screens (lab `data/c36/rolf_orig_dumps.txt`). 4:10's init doesn't stop (it places
  the party at 0,4 E and exits), so it already took the immediate path.
- **No differential check for it:** with this save the gateway event writes nothing (Cadorna's treasure isn't
  carried), so the end states match with and without the fix; statediff compares memory and the party, not the
  text. A check would need an arrival whose square's event changes state after a stopping init; none found yet.
- DIFFCHECKS 18/18 on every push of this chat (29-34 s).

## Chat 36: check 18 (2:9 the wagon: an ADD past 200), DIFFCHECKS 18/18; the break test's gap closed

The Lead's item: a check whose path adds past 200 (chat 35's break test: ADD off by one over 200 was not caught).

- **4:10's ADD 5 to 249 can't be reached in play.** The shadowy form's fight (event 15 at 0,15) needs 0x4A05 (the
  skeletons still to come, set at the area's init as PARTY_STRENGTH / 2 - 0x4A39) or 0x4A08 (0x4A39 = PARTY_STRENGTH /
  2 exactly). PARTY_STRENGTH is at most 255 (ours caps it there), so 0x4A39 stays at most 127 and the event's
  `ADD 5` gives at most 132; the cap at 249 never acts. A fight check there would not add past 200.
- **2:9's payment routine does, with no fight.** The wagon (event 9 at 4,14, before 14:00, 0x4A77 bit 64 clear):
  PARLAY, YES, 250 gold = 50 platinum. The routine (`GOSUB 0x9956`) pays platinum first; with none in the party
  it converts what is left to gold by repeated ADD (`0x9A82`: 50 + 50 + 50 + 50 + 50, the last sum 250), and pays
  that from the members' gold. So an ADD over 200 that is off changes what is paid. The coin sums at `0x9978` ff.
  (gold + the smaller coins) also pass 200 when a member holds 300 gold, but they only feed a comparison.
- **Check 18:** start `mksave.py J G 2 9 4 15 N 4A77=0 4A64=0 4A78=0 4AB9=0 pp1=0 ... pp6=0 gp1=300` (the lab's
  mksave takes `gp<n>=` since this chat); both games: Up (the jump), Up, Enter, P (PARLAY: the seller's offer), Y,
  Enter x3. Ours `load=G,wait,Up,wait,Up,wait,Enter,wait,P,wait,wait,Y,wait,wait,Enter,wait,Enter,wait,Enter,wait,wait,F2`.
  No dice on the path (2:9's patrol roll is for rows 0-6). **MATCH**, 0 differences: THRENDER GRONE's gold 300 -> 50
  in both, 0x4A77 = 64. Lab `data/c35/chk2-9w/` (made with `mkcheck35.sh 2-9w 2-9 ...`); installed and sealed as
  `~/gbr/checks/data/18`; `diffcheck.sh` runs eighteen: **DIFFCHECKS 18/18, ~28 s**.
- **Deliberate-break test repeated** (scratch worktree in /tmp, removed, never pushed): ADD off by one when the sum
  is over 200: **caught**, check 18 DIFFERS (THRENDER GRONE coins 3: 50 vs 49: ours paid 251), `DIFFCHECKS 17/18`,
  exit 1. SUBTRACT off by one: **caught**, checks 4 and 18 (`16/18`).
- Not a fight check with the original's dice as the Lead's note had it: that note followed chat 35's two candidates,
  both after fights; the payment path reaches the case without one, so the check needs no seed.
- `diffcheck.sh` fix: a result with exactly one difference ("1 difference") was shown as "no comparison"; it now
  shows the count and the difference.

## Chat 35: checks 11-17 (the next seven: 1:24, 4:10, 7:17, 8:13, 6:28, 2:15, 2:20), DIFFCHECKS 17/17

Approved by Jeremy (Q6). One event per area, each with no fight and a fixed answer, story flags first (found with
`writers.py`, now `ECL_PY=` for the lab, and a readers grep over every block's listing). Made with the lab's
`mkcheck35.sh <n> <area> <original's keys> <ours' keys>` (`SEED=<hex>` sets the original's dice after boot; ours'
key list then has `tpseed=` after `load=G`). Installed as `~/gbr/checks/data/11`-`17`, sealed (`seal.sh`), and
`diffcheck.sh` runs all seventeen: **DIFFCHECKS 17/17 in about 30 s** (4 at once), on 56a7d30 and on this push.

| # | area | event | flag (readers) | start save | keys (ours) | result |
|---|---|---|---|---|---|---|
| 11 | 1:24 | the goblin slaves, LET THEM GO (map 31, 14,8) | 0x4A2E bit 32 (1:24) | ours at 13,8 E (mksave J G 1 24 13 8 E 49C5=31 49F2=24, then ENCAMP SAVE) | `load=G,wait,tpseed=11111111,Up,wait,L,wait,wait,F2` | **MATCH** |
| 12 | 4:10 | the black marble coffin: read the scroll, SANCTIFY (12,4) | 0x4A43 = 251 (4:10's vampire) | ours at 12,5 N after the arrival scene | `load=G,wait,Up,wait,Enter,wait,Y,wait,Enter,wait,Y,wait,S,wait,F2` | **MATCH** |
| 13 | 7:17 | the nomads: PARLAY, the feast refused, LEAVE (7,14) | **0x4AD2 = 1 (7:26)**; out to 7:26 13,0 | ours at 6,14 E | `load=G,wait,tpseed=11111111,Up,wait,wait,Enter,wait,P,wait,wait,Enter,wait,N,wait,Y,wait,wait,F2` | **MATCH** |
| 14 | 8:13 | the kobold king falls into his pit (10,1) | **0x4AB6 = 254 (3:8, 8:27)**, 0x4A8D = 6 | mksave J G 8 13 10 2 N 4A8D=5 (jump save) | `load=G,wait,Up,wait,Up,wait,F2` | **MATCH** |
| 15 | 6:28 | the outpost's wall, CLIMB OVER WALL (14,3) | **0x4AB4 = 253 (3:8, 6:25)**; out to 6:25 | the original's own save at 14,4 N (jump with 49F2=28, then ENCAMP SAVE G in DOSBox) | `load=G,wait,tpseed=11111111,Up,wait,C,wait,wait,F2` | **MATCH** |
| 16 | 2:15 | the mad fighter, IGNORE (11,12) | **0x4A31 bit 1 (3:8)** | ours at 10,12 E | `load=G,wait,tpseed=11111111,Up,wait,I,wait,wait,F2` | **MATCH** |
| 17 | 2:20 | the old woman: PAY, the fortune, LEAVE (3,5) | 0x4A0B = 251, the party put at 3,4 N | mksave J G 2 20 3 4 S (jump save) | `load=G,wait,Up,wait,Up,wait,P,wait,Enter,wait,Enter,wait,L,wait,F2` | **MATCH** |

The original's keys are in each check's `orig.log` in the lab (`data/c35/chk<area>/`).

- **Why the original's seed in 15 (and 11, 13, 16):** the first 6:28 end save from DOSBox had a wandering giant-snake
  encounter at 14,3 instead of the wall (the original's dice, not the script's); with the seed set (seed.py set
  11111111) and `tpseed=11111111` in ours both games take the same path. Checks 11-17 hold only ours' side in the
  gate (as 1-10), so the stored end save fixes the original's run once.
- **Lab-only, not a game difference:** a jump save (mksave) with 49F2 (the current block) set loads in the original
  with that value kept (so an area's init that tests 49F2 skips its arrival scene); ours sets 49F2 from the area
  it loads into, so it plays the arrival scene. Real saves always hold the current block there, so start saves for
  6:28 were made in the original instead. A jump save into 1:24's map 31 (49C5=31) crashed the original to DOS;
  ours' start save there loads in both.
- **Deliberate-break test repeated** (Lead, 2026-11-16, on the seventeen): SUBTRACT off by one in `ecl_vm.gd`:
  **caught**, check 4 DIFFERS (THRENDER GRONE coins 4: 0 vs 65535), `DIFFCHECKS 16/17`, exit 1. ADD off by one only
  when the sum is over 200: **still not caught (17/17)**: none of the seventeen paths adds past 200 (the candidates,
  4:10's `WRITE_MEM 249` then `ADD 5` and 2:20's kill count to 25, both follow fights). Scratch worktree in /tmp,
  removed, never pushed.

## Chat 34: c33b's 5:4 and 4:10 shortcuts: three bot causes, then the dice; the acceptance run's fourth try

c33b's shortcut wins at 4:10 9,1 (the spectres) and 5:4 9,1 (four fire giants) were not the game: the original wins
them without a death about half the time (Player 7, Player 8), and so does ours from the same squares on QUICK.
Three causes in the bot, all in main's files:
- **The restore shortcut took the racial abilities away.** `DevShortcuts.restore` cleared every effect, and the racial
  ones (`SpecialAffects.RACIAL`: the dwarf's 0x5A/0x61/0x1A/0x2F, the elf's 0x6B...) come back only on a load. The
  restore runs right after the reload, so every try after a loss was fought without them: DORN without 0x2F (the
  dwarf's defence against FIRE GIANT and HILL GIANT) at 5:4, ELWEN without the elf's sleep and charm resistance. The
  log showed it as the same "ELWEN (1 effects); LIRA (1 effects); DORN (4 effects)" at every restore. Now the racial
  standing effects stay; only spell effects and conditions go.
- **Back onto the fight after training.** After an event, explore went to New Phlan to train and then toured back
  to the square it had left, which is the event's own square: at 4:10 that was 9,1, and the spectres fought again.
  In c33b's second try at 4:10, the first 9,1 fight was won with no death, and BRAM and LIRA died in that second
  fight. `_tour_back` (also used by the inn trip) now stops if that square holds an event, and explore goes on from
  wherever the party came in.
- **A death was noticed late.** The training trip and `_heal_if_low` ran with a member already dead (c33b at 5:4:
  DIRTEN killed at 9,1, then the trip to train, the patrols, a wipe at 5:6), so the reload blamed the last fight, not
  the one that killed. Both now wait for the main loop's reload.

Measured from c33b's own checkpoints (`zhentil`, `valjevo3`; resume plans that stop after the area, random seeds):
**4:10 9,1** shortcut in 3 of 3 runs on the old code, 1 of 5 with the fixes. **5:4 9,1**: 48 bot fights over 20
runs, 41 won, **23 without a death (48%)**, the same as Player 8's QUICK (4 of 8) and the original (1 of 2). FLEE,
COMBAT and PARLAY at the giants' menu make no difference (5 runs each). So 5:4 is the dice: with the shortcut after
two losses, about one run in four will take it there. Not a fight rule.

**The retry budget.** A full run stops after 8 reloads since the plan's last `checkpoint` line. c34a (fresh, the first
fourth try) was drained by random wights on the road from 4:2 at day 63 (ARN and BRAM back to level 3) and ran
out of tries in the kobold caves (8:13), several events apart. Explore's own checkpoint now resets the count, once
per event (a reset at every checkpoint looped: an event done again after a reload set the count back to 1 each time,
and the ladder never got past "restore"; c34b and c34c were stopped for it).

## Chat 33: Tyranthraxus was a shared record (the bot's branch explorer), the acceptance run's third try

- **Tyranthraxus (c32a, c33a: every bot fight lost): a bug in ours, now fixed.** `PartyMember.clone()` passed the
  record's bytes to `from_bytes`, which keeps them (`m.raw = d`), and a Packed array assigned in Godot 4 is the same
  array (checked: a write through the copy shows in the original). The bot's branch explorer (`ShadowExplorer`) forks
  the script VM with cloned members and tries every choice of each menu three deep; at the finale's vote its tries
  of JOIN TYRANTHRAXUS (5:7 0xA771, `WRITE_MEM 129, [6C0C]`) set record byte 0x10E (the side) in the **real**
  ARN, BRAM and CEDRIC, so in every bot fight they fought for Tyranthraxus (logs: "ARN ATTACKS ELWEN", the party
  "fallen" while ARN and CEDRIC stood). Found by logging every side write: at ARN's vote, seven writes from 0xE71
  (0xA771 - 0x9900), the explorer's tree. Fix: `clone()` duplicates the record. Only the vote wrote a side that
  matters (1:18, 3:0, 7:17 write 128 for monsters); the arena's ROLF (`copy.raw[0x84] = 0xB2`) also wrote the
  duelist's morale byte (now its own). Since Combat Chat 6 made 0x10E the side. DIFFCHECKS 10/10 with the fix.
  From c33a's `valjevo6` on the fixed code the party fights together; Tyranthraxus still beats this party in most
  tries (its breath does 80, the party has 30-70 HP, levels 5-7; 1 win in 5 tries, `data/c33/e1-e4.log`, and 0 of
  ~12 in `f1-f4`), as the original beat c32a's party in 2 of 3 (Player 7).
- **The bot's spell planner is not the cause:** with the party's own casting off (`party_casts = false`, plain
  QUICK as Player 7's runs) the party lost 6 of 6 tries from c33a's `valjevo6`, with it 4 of 5 (both before the
  fix, `data/c33/tA*`, `tB*`).
- **The finale won with a member dead ends the run** (bot only): Methods 4's reload on a death is for fights the run
  goes on from; after Tyranthraxus falls (0x4ABA = 254, written at 5:7 0xA815) nothing depends on that member. The
  plan's new `won 4ABA 254` line names the flag (data, not engine); a death once it's set is logged ("the run's end,
  no reload"). c33b: BRAM died in the winning fight.
- **c33a's teleport 6:28 -> 3:0 (bot):** a thri-kreen fight on the last walk into Zhentil Outpost, after the band's
  heal, left ARN hurt; inside, the rest rule sent the party to the inn and the quarters have no way out. The plan
  now says `rest 6:28 none` (no rest there, the cleric's memorized cures only); 4 of 4 resumes from c33a's
  `buccaneers` reached `zhentil` with no teleport.
- **The drained party (c33a):** 4:10's wights and spectres drained BRAM 2, ARN 1, DORN 2 levels; with no temple
  Restoration in Pool and no scrolls, the party went into 2:9 at levels 4-5 and into 5:7 a level under the plan's
  7 (`ISSUE ... is behind`). 9 of c33a's 24 member deaths came after fights the party won (4:10's spectres drain a
  member to "DEAD FOREVER"). Methods 4 (no resurrection) and "level drain earned back in play" are design's.
- **Acceptance run, third try, c33b** (fresh from creation, seed 2c2220da, on the fixed code; refcheck on the same
  code below): plan line `stop` reached, **Tyranthraxus beaten in play** (the first time in a full run), **11 shortcut
  wins in 7 fights**: 2:20 0,14 [8 x2, 31 x4] (day 44), 4:2 3,11 [28 x1, 7 x3, 6 x12] (day 50), 8:13 4,3 the throne room's waves x5 (one a stalemate, round 53), 4:10 9,1 [17 x2] (spectres: BRAM drained
  to "DEAD FOREVER" in a won fight, then ARN), 2:9 7,6 the two magic-users, 5:4 9,1 [56 x4], 5:7 3,8 the guards [85 x12]. No teleport.
  Of these, the original loses too from c32a's saves: the throne room (Player 2-3), 2:9 7,6 and the guards (Player 7,
  both seeds). Still to the Player: 2:20 0,14, 4:2 3,11, 5:4 9,1 and 4:10 9,1 from c33b's checkpoints.

## Chat 32: c31a's stop and shortcuts explained (the bot), the acceptance run's second try

- **5:4's chain of patrols (c31a's stop; c29b had the same chain and was luckier): the bot, not our rules.** Every
  Valjevo area (5:3-5:6 on rest, e.g. 5:4 0x9B32) gives a rest interruption check **every 5-minute step at 17%**
  while the alarm cell **0x4A64** is set (else none). The alarm is set by the scribes' officers at 5:4 14,12
  (0xABCB, at their menu, so on the first visit), a fled fight (0x9B83), and others; **only a step** clears it
  (0x995D: once the clock passes the alarm's hour and minute, 0x4A64/0x4A63; resting never clears it). The
  interruption is a giant patrol (0x9BD1: [75 x1, 55 x5]). The bot healed by camping in 5:4 after every fight,
  so patrol followed patrol until a wipe. The original runs the same script with the same dice (Player 5: ours
  interrupts at the original's minute), so a player camping there would meet the same. Fix (bot only): the plan's
  new `rest <area> inn-while 4A64 1` for 5:3-5:6 (the inn while the alarm is up, else camp), and memorized cures
  are cast before an inn trip. From c31a's `valjevo3` checkpoint (`data/c32/v1.log`): **5:4 with no shortcut**
  (two member deaths reloaded), 5:5, 5:6 through; 5:7's guards [85 x12] and Tyranthraxus [66 x1] still by
  shortcut, as in c29b (the gate's "Tyranthraxus alone" item, the Player's rerun).
- **The teleport 3:0 -> 2:9 and "summoned to City Hall but not inside": the bot, not a commit.** The training trip
  started inside 2:9's `explore 3 4 5 6 7 8 9 12 13`, and `main.avoid_events` (explore's events walked round, global
  since the pyramid, eff2a26) blocked those event numbers **in every area**: New Phlan's dock at 3:0 15,1 (where the
  boat lands) is closed in by squares with events 2, 3 and 6, so "no route from (15, 1)", no clerk, no inn, and the
  trip back teleported. c29b never trained during such an explore. Reproduced from c31a's `stojanow` checkpoint
  (`data/c32/t3.log`; also 2:9 -> 1:18 bounced through 5:6 and teleported), fixed in `t5.log`: avoided events hold
  only in their own area (`main.avoid_area`), and on a trip (`_travel`) the walk goes through them when there's no
  way round.
- **6:1 7,0's stalemate (round 54): the dice on this party, not systematic.** From c31a's `heir` checkpoint (the
  same party, just before the gate fight), 7 runs on other dice all win the fight [100 x4, 99 x30] in 3-18 rounds
  (`data/c32/b2-b8.log`). c31a's stalemate left two buccaneers, one fleeing every round without getting away, one
  guarding, while the QUICK party guarded for 50 rounds. Whether the original's QUICK party also guards there is
  Combat's question (board request); the bot's stalemate now prints every standing figure's square.
- **2:15 5,4 [26 x1] and 8:13 4,3** (c31a): earlier in the run, not looked at in this chat; see the second try.

## Chat 31: check 4's flake, the finale's vote, the poison cure

- **Check 4 failed about 1 run in 5** (THRENDER GRONE coins 4: original 0, ours 2): not load or timing. 2:9 7,11 rolls
  between the bugbear's toll (the original's end save) and "THEY ARE IMPOSTERS!" (then SURRENDER: 4,14, nothing paid).
  Ours' script dice came from the clock: `--seed=` seeded only Godot's global generator. Now `--seed=<n>` seeds every
  generator (the script's dice, the screens', the doors, the global one, as the bot's `_seed_all`), and
  `~/gbr/checks/diffcheck.sh` runs ours with `--seed=1`. Seed 7 gives the impostors three times in three, seed 1 the
  toll three in three (lab `data/c31/one4.sh`); **10 full diffcheck runs, two at a time (8 Godot jobs): 10/10 each**
  (`data/c31/ten.log`). Checks 3, 5 and 10 switch to the original's dice (`tpseed=`) in their key lists as before. For a
  check whose path hangs on a script draw, seed 1 is simply one that takes the original's branch (not the original's
  own dice); a future check with such a draw either matches on seed 1 or gets `tpseed=` with the original's seed.
- **The finale's vote** (Player 5): 5:7's script asks only members whose control byte (0x6BB8) is under 128 (0xA72D);
  in the record it is byte **0xB8** (DIRTEN 150 = 128 + morale 44 / 2; player characters 0; in a monster record the
  same byte is the experience value). Ours didn't read it from an original's save, so DIRTEN voted. From c27a's save
  ours now asks ARN..DORN only (lab `data/c31/vote.sh`, before: DIRTEN seventh).
- **Poison (Jeremy, (b))**: checked in DOSBox (slot G's party, THRENDER dead with effect 0x37, New Phlan's temple
  at 3:0 2,12): Slow Poison from BROTHER SEAN in camp: "IS AFFECTED", "GETS BACK UP", HP 1, OKAY, **CON 16**; the
  temple's NEUTRALIZE POISON (1000 gold): "IS CURED.", **CON 16**, and the original's own save after it has CON 16,
  status 0, HP 1 and no 0x37 or 0x16 (lab `data/c31/slotJ_cured`). Neither costs constitution. The bot keeps one
  Slow Poison memorized (the first free level-2 cleric slot), casts it on a member dead of poison before it counts a
  death, and buys NEUTRALIZE POISON at a temple.
- **The acceptance run, first try c31a** (from creation, on Combat Chat 7's three fights + chat 31; refcheck held at
  87% / 91%): **stopped at plan line 557 of 626** in 5:4, the bot's 8 retries spent on the 14,9 giant patrol (won by
  shortcut four times; each time more patrols came until a wipe). Shortcut wins before it: 2:15 5,4, 8:13 4,3, 6:1 7,0
  (stalemate, round 54), 2:9 7,6; a teleport 3:0 -> 2:9 (travel found no way). Not yet explained (board, Main item 4).
  Five Slow Poisons replaced five reloads.
- In the original's lists (temple cures, spell targets) **End moves the cursor down and Home up**; Up and Down don't
  (lab note for `pl.py`).

## Chat 30: check 5 was the driver's, 10 of 10; c29b's three new shortcuts

- **Check 5 never regressed in the code.** Chat 26's matched commit cc5a14d fails the same way (8 differences) under chat
  29's `run1.sh`, while every commit up to origin/main (b242219) gives **0 differences** with chat 26's key list. The
  driver took its keys from chat 25's logs (`data/c25/checks/<n>_<area>.log`), which have 2 `wait`s after the
  treasure's `e` at 5:7 3,8; since chat 26's P59 fix (DELAY waits game speed x 225 ms, twice what it was) the closing
  scene needs ~150, so ours got F2 before the scene ran. Chat 26 ran check 5 with longer waits (its
  `data/c26/checks/5.log`). Lab driver now `data/c30/run1.sh <n> <area> <abs dir>` (keys from chat 26's ten logs; it
  also clears slot F before copying the original's save in, as chat 26's did); `data/c29/run1.sh` calls it.
  **All ten checks: 0 differences on b242219** (lab `data/c30/checks_main.out`, check 5 `data/c30/ck_main`).
- **The checks join the push gate** (Jeremy, Methods 5): `~/gbr/checks/diffcheck.sh <repo or worktree>` runs all ten
  from its own data (`~/gbr/checks/data`, copied from this lab: start saves, ours' start cfgs, the original's end
  saves, chat 26's key lists), each in its own temporary game copy and Godot user folder, so lanes can run it at the
  same time; per check MATCH or the first difference, `DIFFCHECKS n/10`, exit 0 only on 10/10. **Wall time: 36 s for
  all ten** (3 at once, with refcheck's two bots running beside it). Checked failing: check 5 with chat 25's keys gives
  `DIFFERS (8 differences)`, exit 1. CLAUDE.md's "Before every push" runs it for any push touching `scripts/` or
  `content/`.
  Safeguards (design office): `~/gbr/checks/known_failures.txt` (a check failing for a known reason, with its lane and
  board entry; exit 0 only when every failure is listed; empty since chat 30, and empty before the acceptance run) and a
  `manifest` per check (sha256 of keys, start cfg, start save, the original's end save; a mismatch is `INVALID`;
  `seal.sh <n>` after a deliberate change). Checked: a stale key list gives INVALID (exit 1); a listed failure exit 0.
- **c29b's three new shortcut wins** (against c28a), from `data/logs29/full_c29b.log.gz`:
  - **8:13 14,8, the wyvern** (event 17, 1 wyvern): won all three times, but each time a sting's failed save killed a
    member (CEDRIC and DORN; then LIRA; then the third try), and in a full run a death is a reload. The poison rule
    (effect 0x40, save or die) is Combat's, `checked` in `docs/coverage.md`. **The game's difficulty under the run's
    death rule.** A poisoned member is the original's poison, not death proper: Slow Poison stands them up at 1 HP and a
    temple's NEUTRALIZE POISON cures them, which the bot never tries (question to design on the board: whether a full
    run may cure poison before counting a death). Same cause as c28a's 4:21 scorpions.
  - **4:10 9,1, the brass doors' two spectres** (event 23, [17 x2]): won both times, but BRAM drained 2 levels a hit
    until DEAD FOREVER (the original's rule: a drain below level 2 kills, GAME.OVR 0x10F15) and CEDRIC killed. The fight
    is Combat's `orig_A_spectre`, matched roll for roll. **The game's difficulty**, with a party weaker than c28a's at
    that point (c29b ends ARN 7 / BRAM 7 / LIRA 6/6 / DORN 6/7, c28a ARN 8 / BRAM 8 / LIRA 7/6 / DORN 7/8).
  - **5:4 9,1, four fire giants** ([56 x4]): **the bot's.** It beat the party only once (won, with ELWEN killed), but the
    bot's retry counter was per checkpoint, not per fight: 14,9's patrol had used tries 2 and 3, so 9,1's first loss
    (try 4) took a shortcut win and logged "this fight beat the party twice". Fixed in `bot.gd` (`_losses`: a fight
    is won by shortcut only after it has beaten the party twice itself; a first loss restores and retries). The
    acceptance run will show whether the giants' room is hard (melee only; Combat's melee rules are in regress.sh).
- **For the Player:** none of the three needs the original: the wyvern's and the spectres' rules are checked, and the
  giants' room was not actually lost twice. If the acceptance run loses the giants' room twice, that one is for the
  Player.

## Chat 29: loading 5:4/5:7, P63, NPCs' side, full runs c29a/c29b (stopped by the Lead)

- **The original's LOAD** (GAME.OVR 0x1FBB3): with the view byte 0x49FA below 2 it loads GEO<data set> block
  **[0x49C5]** (the map last loaded; not 0x49F2), then the wall sets from 0x4AFA-0x4AFF. Ours now loads that map before
  the init. The Player's fixtures (`c27a_5-7_finale`, `c27a_5-4_alarm`, `c27a_5-4_giant`, slot I, lab `data/c29/fx`):
  GEO5 block 7 / 4 after load; 5:7 3,6's stairs ask; 5:4 13,12 E, Up: "YOU ENTER A BRIGHTLY LIT BUILDING ..." at 13:27, the
  same as the original from the same save (DOSBox).
- **Checks on chat 29's load change:** 1, 2, 3, 4, 10: 0 differences. **Check 5: 8 differences** (ours ends in 5:7 3,8:
  the guards surrender at once, Tyranthraxus's fight ends at CONTINUE BATTLE and the closing scene never comes). **The
  same on origin/main, on 6eff49e (chat 28's end, before Combat Chat 6) and on 464f521 (before chat 28's random
  treasure)**: not chat 29's, and older than chat 28's treasure. Next: bisect further back (chat 26's cc5a14d matched),
  then hand the fight to Combat if it is a fight rule. Checks 6-9 not re-run (stopped). Driver:
  `data/c29/run1.sh <n> <area> <abs dir>` (an absolute folder: a relative `--save` replays no keys and idles 25 minutes).
- **P63** (the inn at New Phlan 6,12, `PICTURE 24 ... PROGRAM 9`): after paying and EXIT from camp the original shows the 3D
  view (the party at 6,13 N); ours kept the innkeeper. Leaving camp now clears the event picture (lab: before/after
  screens `data/c29/ours_inn3*.png`, the original's `data/c29/inn3.png`). Seen on the way, not fixed: **indoor squares
  draw a pink ceiling in the original** (6,13, map flag 137; both games hold sky 11/10), ours always the sky colour.
- **ADD_NPC** (GAME.OVR 0x38C4) sets record 0x10E = 0 (1 only for monster 0x18). Full run **c29a** (before the fix):
  DIRTEN fought the party from his first fight (2:15's lizardmen, BRAM ATTACKS DIRTEN in round 1) and the run ended wiped at
  1:18 (plan line 244, 8 retries). **c29b** (with the fix, training as the original): **reached the plan's end** (line
  626, day ~558, 0 teleports), 10 fights won by shortcut (c28a 7): 4:21 2,11; 8:13 14,8; 8:13 4,3 x2 (one a stalemate);
  4:10 9,1; 2:9 7,6; 5:4 14,9; 5:4 9,1; 5:7 3,8 x2. **Not yet explained one by one** (new against c28a: 8:13 14,8, 4:10 9,1,
  5:4 9,1); levels at the end ARN 7, BRAM 7, CEDRIC 6, ELWEN 5/6/6, LIRA 6/6, DORN 6/7, DIRTEN 6. Logs: lab `data/logs29/`.

## Chat 28: fresh full run c28a (from creation, chat 28's code: random treasure, mop-ups)

Reached the end, day 498, **0 teleports**, 0 level grants, 16 party restores on first retries. Fights won by shortcut
(each beat the party twice): Sokal Keep 4:21 2,11's huge scorpions (day 27, levels 1-3: poison kills, and a death is a
reload; c27a had left that room for later), the kobold king's hall once (c27a x4), 2:9 7,6's ettins, 5:4 14,9's hill
giant and fighters once (c27a x2), and in 5:7 the guards (twice) and Tyranthraxus. The Player plays 2:9, 5:4 and
Tyranthraxus in the original (its item 3); the guards and the king's hall lost in the original too (Player 2). The
mop-ups: 2:20 events 13 and 15 and 7:17 event 1 won later; 2:20 20 and 4:2 18 still judged unwinnable; Sokal Keep has
no travel route back. End levels: ARN 8, BRAM 8, CEDRIC 6, ELWEN 6/5/6, LIRA 7/6, DORN 7/8 (c27a: DORN 6/7, ELWEN
6/6/5). Log: `data/logs28/full_c28a.log.gz`, checkpoints in the lab archive (`data/c28/cp_c28a`).

## Chat 28: more honest experience before the finale (Jeremy, Q1: both)

- **Where c27a's experience stood**: the bot trains as soon as anyone qualifies (`_can_train` after every event), so
  the lag (ARN 6 on day 306, 7 on day 483, 8 only after the finale) is experience not earned, not training missed.
  Commission rewards do count: the original gives a treasure's worth as experience (gold value, 250 a gem, 2200 a
  piece of jewellery, 400 a plus; `Spoils`), and City Hall pays through TREASURE (no GIVE_EXP in any Pool script);
  the random treasure (above) now adds its items' pluses too.
- **Experience left on the table**: set fights `explore` judged unwinnable and never came back to (c27a: Sokal Keep
  4:21 [9, 12, 8], the Textile House 4:2 [18], the nomads 7:17 [1], the graveyard 4:10 [28, 5]). Built: the plan's
  **`mopup`** (after the graveyard and after Stojanow Gate): back to each such area once the party has gained half a
  level a member since, training first, taking on those events it now judges winnable. Test (c27a's `graveyard`
  checkpoint with those lists): 7:17's event won; 4:2's 18 and 4:10's 28/5 still judged unwinnable; Sokal Keep has no
  travel route back (reached by the plan's own menu steps), so it stays logged.
- **The hard fights in the original**: given to the Player (its item 3) with c27a's checkpoints named on the board.
- **Tried and dropped**: weighing poisoners in the bot's odds (c28a's Sokal Keep scorpions killed members at levels 1-3):
  the insect room is reached as event 5 too, where the bot sees no monsters ahead, so the rule didn't stop it.

## Chat 28: random treasure at TREASURE (combat's request)

- **The original rolls an event's random treasure at the TREASURE, before the fight.** TREASURE's handler (GAME.OVR
  0x26F5) reads the coins and the item list; a list of 128 or more makes (list - 128) items at once (0x2886..0x2AA9),
  each put at the front of the treasure list DS:0x6810 (so the last made shows first). Per item a d100 (0x28B4) picks
  the kind: 1-60 a weapon or armour (a second d100, 0x28D3, gives the type; 60-90 a d10 at 0x2910), 61-85 a
  magic-user's scroll (type 61), 86-92 a cleric's scroll (62), 93-98 a d16 among wands, rings and the like, 99-100
  type 69. The item is then built from its type (0x25C99): a d20 plus (0x25C5B: 1-14 +1, 15-19 +2, 20 +3), name words,
  weight and price by type; scrolls get d3 spells, each a d3 for its level and a die for the spell (0x26224...); the
  other kinds take an entry of START.EXE's table DS:0x970 (eight words: three name words, weight, price, three special
  bytes). The second d100's 48 and 49 set no type (the variable keeps the last item's). Built:
  `scripts/game/treasure_maker.gd`, called at ECL TREASURE (`ecl_vm.gd`); the treasure screen shows those items.
- **The monsters' records load at LOAD_MON, not at the fight.** LOAD_MON's handler (0x1196) loads the record at once
  (0x78E4 -> 0x1EEAA: the five icon-colour d6s); ours loaded them when the fight began, which put the colours after
  the treasure's dice. Lab dice now draw them at LOAD_MON (`PartyMember.draw_colours`), the fight takes them.
- **Lab, 2:20 0,14's ogres and trolls** (`TREASURE 0,0,0,30,50,0,1,131`; Combat's start `combat5/saves/troll`, seed
  11111111 after the step into the building): the original's 16 treasure draws and ours' are the same, and the three
  items are **byte for byte the original's** (bytes 0x2E-0x3E of each record read from DS:0x6810 in DOSBox, held
  after the treasure): BASTARD SWORD +1, TWO-HANDED SWORD +1, a CLERICAL SCROLL with spells 38, 42, 6 (2100 gold). The fight then
  matches to **draw 701 of 2561** (was 11; MAGIC on): at 702 the original aims Bakshi's spell (d6 target pick,
  0x160DB) where ours picks a spell again (Combat's). Spectre (`orig_A_spectre`, MAGIC): 3195 of 3195 draws on this code.
- Where it plays: lists 129-131 at 2:20 (0xA390, 0xB0FB), 6:25 (0xAAA4), 7:23 (0xA3CF), 8:13 (0xAD3A), 8:27 (0xA39E,
  0xA5EC); 1:24, 3:8 and 8:16 take the list from a variable.
- Lab note: a save's SAVGAM names its character files (CHRDATA1...), so a fixture copied to another slot letter
  needs those names patched (`tools/lab/slot.sh`), or it loads slot A's party.

## Chat 27: Valhingen's "dead forever" and the full run's teleports

- **Record byte 0x73, the highest level.** A level drain (0x10D7D) kills "forever" when 0x73 is under 2 (0x10F15).
  The original raises 0x73 only in its level recount (0x2AA87: to the highest class level, never down), which runs
  **after training** (0x1C8D9, after "CONGRATULATIONS...") and **as a character joins the party** (0x1F55A: loading a
  save, ADD CHARACTER); creation sets 1 (0x1A521). Ours never raised it, so every drained character of any level died
  forever (c26a's 8 reloads at 4:10). Lab: `mksave.py J G 3 0 4 13 N`, CHRDATG1 patched to fighter 3 with 0x73 = 1;
  the original loaded it and saved it to E with **0x73 = 3** (lab `data/c27/o_73_load_*.SAV`). Built:
  `PartyMember.raise_highest()`, called from `apply_class_tables` (training, the drain's recount) and as a party is
  loaded (`load_files`, the quick save). Also from 0x1C89C: **a level trained while drained pays back the drain's
  record** (0x75 less 0x75 / 0x74, 0x74 - 1), so a later Restoration doesn't give that level twice.
  Run c27v (c26a's `zhentil` checkpoint, this code): the spectres now drain levels ("DRAINED 2 LEVELS", no "DEAD
  FOREVER"), the graveyard is checkpointed, and the party reaches the plan's end.
- **c26a's three teleports** (`data/logs26/data_full_c26a.log.gz`):
  1. *8:29 -> 3:0, day 26*: the training trip began at the bottom of Kuto's Well (8:29's well map, 0x4ADB = 2, after
     CLIMB DOWN YES), whose only way out is the rungs' menu (0xA1DA "CLIMB UP THE RUNGS?" YES, then LOAD_AREA_MAP); the
     area graph has no walking exit from it. Rare (a trip starting there); not fixed, logged with its cause.
  2. *7:26 -> 7:17, day 60*: on the nomad camp's square (12,11) the band's **random site** came first (7:26 0xA10E ->
     0xA44C: "A SMALL WOODED GROVE" or "SOME RUINED HUTS", a sub-map, 0x49E6 = 1), and the gate's answer ENTER took
     the party into it. Bot fixed: a gate's answer is never given at those two sites (travel leaves them).
  3. *7:26 -> 3:0, day 68*: a knock-on of 2: the teleport left 0x49E6 = 1, so the next arrival in 7:26 from the
     nomads ran the grove's edge ("ABOUT TO LEAVE THIS AREA", 0xAA9A) and RETURN put the party in the grove's map.
     Bot fixed: a teleport out clears 0x49E6 and 0x4A9E as the site's own LEAVE does (0xAAE7).

## Chat 27: fresh full run c27a (from creation, no level grants)

Code: chat 27's (0x73, Restoration scrolls in the bot, no level grants in a full run). From creation to the plan's
end (plan line 612, after Tyranthraxus), game day 497, in about 40 minutes of wall time. Lab log
`data/logs27/full_c27a.log.gz`. Counters: won 17, lost 11, wipes 4, deaths 10 (each a reload), **restorations 12**
(the drained given levels back by the clerical scrolls the party found), **0 level grants**. Final levels: ARN 8,
BRAM 8, CEDRIC 6, ELWEN 6/6/5, LIRA 7/6, DORN 6/7, DIRTEN 6. Every shortcut and its cause:

| Shortcut | Where | Cause |
|---|---|---|
| teleport 6:28 -> 3:0 | Zhentil Outpost, day 392 | Arrived hurt (an ankheg fight in 6:25 on the way); the escort confines the party to its quarters and the rest rule's inn trip found no way out. Plan fixed: heal and memorize in 6:25 before going in. |
| win x4 | 8:13 4,3 (the kobold king's hall) | Difficulty: the Player lane's throne-room fight (its queue item 2). |
| win | 2:9 7,6 (ettins and company) | Difficulty: a fight the party lost twice at level 6-8; not yet compared with the original (Combat's LEVEL 6 MU fight is in this area). |
| win x2 | 5:4 15,9 / 14,9 (a hill giant, five 6th-level fighters) | Difficulty: lost twice; not yet compared. |
| win | 5:7 3,8 (**Tyranthraxus**) | Difficulty: his fight matches the original roll for roll (check 5, Combat Chat 4); the party (levels 6-8) lost it twice. Question for design on the board. |
| restore x14 | the first reload after each loss | The run's rule: the party restored on the first retry from the checkpoint (logged). |

The finale's guards (5:7, 85 x12) were won in play this time. Left as issues, not shortcuts: events left "for later"
(the party couldn't win them yet) in 7:17, 7:23, 5:5, 4:2, 4:21, 4:10, 2:9, 2:20; CEDRIC behind at 3:14 (level 3,
the area expects 5); 4:2's "WHAT DO YOU DO WITH THE MAN?" repeating.

## Proposed next five (chat 21, for Jeremy)

One per closed area without a check, story flags first: the flags below are written in that area and read by another area's
script (found by listing every write of 0x4A20-0x4AFF and the areas that read it; City Hall, 3:8, reads most of them for its
commission rewards). The first four need no fight: the start save sets the counter or state just before the event, so they
run like checks 1, 2 and 4. The fifth follows a set fight and waits on the side lane like 3 and 5.

| # | area | event | flag (readers) | start save | fight? |
|---|---|---|---|---|---|
| 6 | 4:21 Sokal Keep | Ferran Martinez freed: the password SAMOSUD (0xAD42-0xADAA) | 0x4A26 = 255, 0x4AA7 = 254 (3:0, 3:8) | at the keep's ghost, parley (as the playthrough) | no · **MATCH** (chat 22) |
| 7 | 8:16 ruined castle | the castle cleared (0x9CBD-0x9CCF) | 0x4AB5 = 254 (3:8) | 0x4A5D = 40 (its count) | no · **MATCH** (chat 22, after a fix) |
| 8 | 3:14 Kovel Mansion | the thieves cleared (0xB343-0xB361) | 0x4AB2 = 254 (3:8) | 0x4A45 = 21 (its count) | no · **MATCH** (chat 22) |
| 9 | 1:18 Podol Plaza | the plaza's report (0xB241-0xB24E) | 0x4AE7 = 254, 0x4A34 = 10 (3:8: check 1's reward) | 0x4A34 = 9, a plain square searched | no · **MATCH** (chat 22) |
| 10 | 7:23 Yarash's pyramid | Yarash beaten (0xAC23-0xAC53) | 0x4AB3 = 254 (3:0, 3:8, 7:26, 8:27) | before Yarash's fight | yes (side lane) |

**Recommendation:** run 6-9 next (no fight, about an hour together in the lab), and ask the side lane for 10's fight with
checks 3 and 5's. The other closed areas without a check (1:24, 4:10, 7:17, 8:13, 6:28, 2:15, 2:20...) follow in the same
way after these (done in chat 35: checks 11-17, section "Chat 35").

## Checks 6-9 (chat 22)

**Start saves made by ours.** Where the area's own init would move a party that jumps in by `mksave.py` (Sokal Keep puts
every first arrival on the pier) and the way to the event crosses random patrols, ours writes the start save: load the
`mksave.py` save, `at=x;y;dir` puts the party at the square, ENCAMP, SAVE. Both games then load that same file. Ours'
original-format saves load in DOSBox since chat 22 (before, a save made after a change of data set stopped the original
with "Unable to load geo in Load3DMap": ours kept the old data set at 0x5012 and the old wall sets at 0x4AFA-0x4AFC).
Typing in a text prompt: the original takes the letters, ours' `--keys` needs `say=<word>` (replayed letter keys carry
no text).

| # | start save | keys, original | keys, ours | result |
|---|---|---|---|---|
| 6 | `mksave.py J G 4 21 9 10 W`; ours `--keys=load=G,Up,Enter,at=8;9;2,E,S,G,N,E` (save G at 8,9 S) | Up (8,10: A PALE FORM RISES), P, N (NICE), LUX, Enter, T (TELL THE TRUTH), Enter until the walking menu; save F | `load=G,Up,P,N,say=LUX,T,Enter,Enter,Enter,F2` | **MATCH**, 0 differences (with or without the ignore list); both 0x4A26 = 255, 0x4AA7 = 254. The word that frees Ferran is LUX (any other lays him to rest: 0x4A13 = 255) |
| 7 | `mksave.py J G 8 16 8 14 S 4A5D=40` (the castle's init puts the party at 8,14 N) | Up (YOU SENSE AN ANTI-MAGIC SHELL), Enter, Right, Right, Up (8,15), Up (out onto the band, 8:27 26,0); save F | `load=G,Up,Enter,Right,Right,Up,Up,F2` | **MATCH** after a fix: first 0x49E5 differed (original 0, ours 1). The castle's init sets it (the anti-magic shell) and the original's area entry clears it every time (GAME.OVR 0x771B, the routine at 0x7689 that also sets 0x49E6); ours kept it. Fixed in `main.gd`; then 0 differences (with the ignore list; 0x4AFA-C are save-time values ours' quick save doesn't hold). Both 0x4AB5 = 254 |
| 8 | `mksave.py J G 3 14 8 7 S 4A45=21` | Up (in at 8,7 S), Up (walled), Left, Up (9,7: a square with no event runs 0xB343); save F | `load=G,Up,Up,Left,Up,F2` | **MATCH**, 0 differences; both 0x4AB2 = 254 |
| 9 | `mksave.py J G 1 18 8 4 W`; ours `--keys=load=G,Up,mem=4A34:9,E,S,G,N,E` (1:18's init zeroes 0x4A34 on a fresh arrival, so the count is set inside) | Up (7,4: a plain square, d25, then 0xB241); save F | `load=G,Up,F2` | **MATCH**, 0 differences without the ignore list; both 0x4AE7 = 254, 0x4A34 = 10 |

Kept in the lab: `data/diff_<area>_start/` (each start save with its CHRDAT files; copy into `game/` to replay), `data/diff_<area>_orig/`
and `data/diff_<area>_ours.cfg`. Lab save G is the scratch slot for start saves (check 1's G: remake it with its recipe).

**Found by checks 6-9, outside the events themselves:** ours' original-format saves didn't load in DOSBox after a change of data
set (the data set at 0x5012 and the wall sets at 0x4AFA-0x4AFC, written by the original only at save time; fixed); the
anti-magic flag 0x49E5 survived leaving the ruined castle (fixed); the anti-magic shell itself is not modelled in ours (the
original tests 0x49E5 at 0x9F59, 0xAFF6, 0x17BB2 and 0x21FD6; not yet read: on the board as a gap).


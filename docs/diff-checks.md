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
way after these.

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


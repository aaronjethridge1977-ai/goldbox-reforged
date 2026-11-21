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

## Chat 79: the camp's USE of a Magic User scroll (checks 179 and 180, a fix), money TRADE to a member who can't carry it (ready check 181, to Combat), the silver shop's SELL (check 182), a buff CAST with SEARCH on then a step (check 183), a scroll's combat-only spell in camp (check 184)

Main path, against the original in DOSBox (lab `data/c79/chk179`, `chk180`, links in `data/c79/cd/`), tpseed 11111111, check 159's start (LIRA, fighter/magic-user 1, with a read scroll of PROTECTION FROM GOOD and SHOCKING GRASP).

- **179**: ENCAMP, End x4 (LIRA), VIEW, ITEMS, READY (the long sword off: a scroll takes both hands), End x4, READY (the scroll), USE (LIRA'S SPELLS ON SCROLL, in the record's order, the light on the last line), Home, CAST, Home x2 (CEDRIC), SELECT (back to the items, the scroll WITH 1 SPELL), EXIT x3, save: CEDRIC's .SPC holds effect 9 for **12 minutes, power 6**. **Ours differed** (2 minutes, power 1: LIRA's magic-user level). **Fix:** `SpellCaster.cast_outside` casts a spell from an item at level 6 (spell_caster.gd). 3 of 3 with it; without it differs; one Home fewer (ELWEN) differs.
- **180**: the same with LIRA's magic-user level (+0x9B) made 8: the original still 12 minutes, power 6, so a scroll's level is a fixed 6 (not the reader's level, not "at least 6"); ours without the fix 16 minutes, power 8. 3 of 3 with it.
- **181** (ready, not in the gate: Combat's file): the view page's money TRADE to a member who can't carry it: check 178's start with DORN's platinum 30000: ENCAMP, Home (DORN), VIEW, TRADE, End (ARN), SELECT, Enter, 30000, Enter (refused: nothing moves, no message on the screen), Enter, 3000, Enter, Enter, 3000, Enter (both taken: ARN's cached word never rises, GAME.OVR 0x250D5), EXIT x4, save: ARN 6000, DORN 24000. Ours moves the 30000 (then the gold). The fix (one test in character_sheet.gd) is with Combat (board); 3 of 3 with it. Lab `data/c79/chk181`, the diff `data/c79/chk181_fix.diff`.
- **182** (3:0 the silver shop's SELL): check 157's start: Up, YES, End x4 (LIRA), VIEW, ITEMS, End x2 (SHORT BOW), SELL (7 gold, as the arms shop's), YES, EXIT x3, save. Matched at once, 3 of 3; NO differs.
- **183** (3:0 the adventure menu's CAST of a buff with SEARCH on, then a step): check 173's start: SEARCH, End x2 (CEDRIC), CAST, End (PROTECTION FROM EVIL), CAST, Home x2 (ARN), SELECT, EXIT, Up (a searching step: 10 minutes, into the arms shop's square), NO, save: ARN's 3-minute effect gone, 06:10. Matched at once, 3 of 3; without SEARCH differs (the clock).
- **184** (3:0 the camp's USE of a scroll's combat-only spell): check 179's keys to USE, CAST on SHOCKING GRASP: THAT ITEM / IS A COMBAT-ONLY ITEM... / USE IT?, YES: the spell gone, the scroll WITH 1 SPELL. Matched at once, 3 of 3; NO differs.
- Not checked: whether a wand or potion used by a spell caster also casts at 6 (the fix assumes so: ours already gave 6 to anyone who casts no spells, the original's rule for items); combat's scroll USE (combat_spells.gd, Combat's file) still takes the reader's level: to Combat.

## Chat 78: the camp's DROP of a stack (check 169), the adventure menu's CAST (check 170), a combat-only spell there (check 171), ALTER SPEED (check 172, a fix), CAST PROTECTION FROM EVIL on another member (check 173), ENLARGE and SHIELD (check 174), an effect running out in REST (check 175), the shop's POOL, TAKE and SHARE (check 176), back for the money (check 177), the view page's money TRADE and DROP (check 178)

Main path, against the original in DOSBox (lab `data/c78/chk169`, links in `data/c78/cd/`), tpseed 11111111, both from check 165's start.

- **169** (3:0 the camp's DROP of a stack): ENCAMP, End x4 (LIRA), VIEW, ITEMS, End x3 (10 ARROWS), READY (off), DROP: YOUR 10 ARROWS WILL BE GONE FOREVER / DROP IT? YES NO (no count asked: the whole stack goes), YES, EXIT x3, save. Matched at once, 3 of 3; without DROP, YES differs.
- **170** (3:0 the adventure menu's CAST, outside camp): check 102's start (ARN at 5 HP): End x2 (the party cursor to CEDRIC), CAST (his memory, on the last line), CAST (CURE LIGHT WOUNDS), Home x2 (ARN), SELECT (5 -> 8, one d8; the list comes back), EXIT, save. Matched at once, 3 of 3; tpseed 22222222 and BRAM as the target differ.
- **171** (3:0 the adventure menu's CAST of a combat-only spell): check 102's start: End x4 (LIRA), CAST (SLEEP her only spell), CAST: SLEEP / IS A COMBAT-ONLY SPELL... / LOSE IT? YES NO; NO keeps it (the list again), CAST, YES loses it (the list closes), save. Matched at once, 3 of 3; NO then EXIT differs.
- **172** (3:0 the camp's ALTER SPEED): check 102's start (speed 0): ENCAMP, ALTER, SPEED (GAME SPEED = 0 (0=FASTEST 9=SLOWEST), SLOWER EXIT), SLOWER x3, FASTER, EXIT x3, save: the original's save has **2 in cell 0x49FC** (SAVE writes DS:0x49E2 into the live script memory, GAME.OVR 0x1FECE, high byte 0). **Ours differed (0): its quick save kept the speed only in [qol] speed**, its original-format save only in the file's copy. **Fixed** (main.gd `_quick_save` and `_save_original` write the speed into the live cell, as the original). Then 3 of 3; without FASTER differs (3). Main path: only the save's contents (no script reads 0x49FC that we know of); DIFFCHECKS 172/172.
- **173** (3:0 the camp's CAST PROTECTION FROM EVIL on another member): check 102's start with CEDRIC given spell 6 (+0x28): ENCAMP, End x2, MAGIC, CAST, End (the list wraps from its last line to PROTECTION FROM EVIL), CAST, Home x2 (ARN), SELECT, EXIT x3, save: ARN's .SPC holds effect 8 for 3 minutes, power 1. Matched at once, 3 of 3; BRAM as the target differs.
- **174** (3:0 the camp's CAST ENLARGE on another member, then SHIELD): check 102's start with LIRA given ENLARGE (+0x2A = 12) and SHIELD (+0x29 = 19): ENCAMP, End x4, MAGIC, CAST, Home (ENLARGE), CAST, Home x2 (CEDRIC), SELECT, Home (SHIELD: after a cast the light stays on the same line), CAST (the caster, no question), EXIT x3, save: CEDRIC effect 12 for 10 minutes (STR 18/00 unchanged: already above Enlarge's level-1 target), LIRA effect 17 for 5 minutes. Matched at once, 3 of 3; ELWEN as the target differs.
- **175** (3:0 an effect running out in the camp's REST): check 173's cast, then EXIT x2, REST, MINS, INC x2 (10 minutes: five a step), REST, save: 06:10, ARN's 3-minute effect gone, no healing in 10 minutes. Matched at once, 3 of 3; 5 minutes differs (the clock).
- **176** (3:0 the arms shop's POOL, TAKE and SHARE): check 156's start (DORN holds all the money: 3 gold, 1000 platinum): Up, YES, POOL (the menu gains TAKE and SHARE), TAKE, End (PLATINUM), Enter, 400, Enter (to ARN), EXIT, SHARE, EXIT: YOU HAVE LEFT SOME MONEY HERE... GO BACK AND GET YOUR MONEY? NO; save. The original's SHARE is uneven: ARN 1 gold 500 platinum, BRAM and CEDRIC 1 gold 100, ELWEN and LIRA 100, DORN nothing, 100 platinum left behind. Ours matched at once, 3 of 3; TAKE 300 differs.
- **177** (3:0 the arms shop, back for the money SHARE left): check 176 to the question, YES: the pile shows PLATINUM 100 and **JEWELRY 44936**, and SHARE has given every member jewelry up to his load (ARN 3999 ... DORN 4503: check 110's word wrap on the load word), so every TAKE (100 or 10 platinum, by ARN or BRAM, 1 jewelry) is refused with no message; EXIT, EXIT, NO, save. Matched at once, 3 of 3; without SHARE the TAKEs go through and it differs. The jewelry is the original's bugs #9/#10 (docs/original-bugs.md: SHARE's wrap on the stale load word); the gate runs with the bugs on.
- **178** (3:0 the view page's money TRADE and DROP): check 156's start: ENCAMP, Home (DORN), VIEW, TRADE, End (ARN), SELECT, Enter (PLATINUM), 250, Enter, End (GOLD), Enter, 5 (more than his 3: all go), Enter, EXIT, EXIT, DROP, Enter, 100, Enter, EXIT x3, save: ARN 3 gold 250 platinum, DORN 650 platinum. Matched at once, 3 of 3; 2 gold differs.
- Not in the gate (they repeat check 116, chat 67): LIRA's short bow refused while her long sword is readied and the sword refused while the bow is; and (lab `data/c78/chk171r`) ARN's bow refused with the shield readied, the shield refused with the bow: both matched 3 of 3.

## Chat 77: CAST READ MAGIC then SCRIBE from an unread scroll (check 162), the shop's SELL (163), the shop's ID of a scroll then SCRIBE (164), TRADE of a stack (165), a Potion of Healing's USE (166), a Potion of Giant Strength's (167, 168); the checks run ours with QoL off

Main path, against the original in DOSBox (lab `data/c77/chk162`, links in `data/c77/cd/`), tpseed 11111111.

- **162** (3:0 the camp): check 159's start with LIRA's scroll unread (byte 53 = 6) and READ MAGIC memorized (+0x2B = 18): ENCAMP, End x4, MAGIC, CAST, CAST (on herself, at once), SCRIBE (PROTECTION FROM GOOD, SHOCKING GRASP listed), Home, SCRIBE, EXIT, EXIT, YES, REST, REST (4:15), EXIT x2, save. The original: 17 in the book, the scroll 210 with 20 and **byte 53 cleared** (read), READ MAGIC gone from memory, no affect left in the .SPC. Ours matched, 3 of 3; without the CAST differs.
- **The gate's settings (a check-script change):** the first run differed: ours' REST put the cast READ MAGIC back (4:30 of rest, +0x2B = 18) because ours ran with the release's QoL defaults (REST REMEMORIZES on). `diffcheck.sh` now writes ours' settings.cfg with every QoL switch that changes play off, the same list as segment.py's `QOL_OFF` (rememorize, fix, magic_menu, aim_skips_party, start_memorized, quick_bandages, smart_quick, smart_monsters): the 161 earlier checks still match (161/161); the deliberate-break test 142/162. Not a game difference: no code change.
- **163** (3:0 the arms shop, SELL): check 156's start: Up, YES, End x4 (LIRA), VIEW, ITEMS, End x2 (SHORT BOW, not readied), SELL (I'LL GIVE YOU 7 GOLD PIECES), YES (paid as 1 platinum and 2 gold), SELL on the readied 10 ARROWS (nothing happens), READY (off), SELL (0 GOLD PIECES), YES, EXIT x3, save. Matched at once, 3 of 3; SELL of the still-readied stack with YES differs (ours too keeps it).
- **164** (3:0 the arms shop's ID of an unread scroll, then SCRIBE): check 156's start with LIRA's gold 500 and the unread scroll (byte 53 = 6, spells 17, 20): VIEW, ITEMS, End x4, ID (FOR 200 GOLD PIECES), YES (MAGIC USER SCROLL WITH 2 SPELLS: byte 53 cleared), EXIT x3, ENCAMP (the shop's pick carried over: End x4 lands on CEDRIC; SCRIBE on a cleric does nothing), End x2, MAGIC, SCRIBE (both spells listed), Home, SCRIBE, EXIT, EXIT, YES, REST, REST (4:15), save: 300 gold left as 60 platinum, 17 in the book, the scroll 210. Matched at once, 3 of 3; without the ID differs.
- **165** (3:0 the camp's TRADE of a stack): check 156's start: ENCAMP, End x4 (LIRA), VIEW, ITEMS, End x3 (10 ARROWS), READY (off), TRADE (TRADE WITH WHOM?, the cursor on LIRA), End (DORN), SELECT: the whole stack of 10 moves to DORN, unreadied. Matched at once, 3 of 3; to ELWEN differs.
- **166** (3:0 the camp's USE of a Potion of Healing): no save of ours had one; the record (type 70, byte 60 one charge, byte 61 = 85: item spell 62, value 200, unread) copied from a Player save, appended to LIRA with HP 1 of 9: ENCAMP, End x4, VIEW, ITEMS, End x4 (POTION), USE (**nothing while the potion isn't readied**), READY, USE (the potion gone, no message on the list), EXIT x2, save. tpseed 22222222 (simulated so the two d4 draws are low: 0, 1; the original's trace: two draws of 4 at OVR 0x2A001): 2d4+2 = 5, HP 6 (tpseed 11111111 gives 8, the maximum: a cap could hide an error). Ours matched at once, 3 of 3; USE without READY differs (HP 1).
- **167** (3:0 the camp's USE of a Potion of Giant Strength): a Player save's record (byte 61 = 82: spell 59; link bytes zeroed) appended to LIRA (long sword only): ENCAMP, End x4, VIEW, ITEMS, End x4, READY, USE, EXIT x3, save: STR 21 (exceptional byte cleared), affect 38 for 70 minutes, power 76 (the minutes from one d4 draw at OVR 0x2783D: tpseed 22222222 gives 50). Matched at once, 3 of 3; tpseed 22222222 differs.
- **168** (the same potion on ARN, long sword and shield readied): READY refused without a message (no free hand), USE does nothing: STR 18(00) kept. Matched at once, 3 of 3; with the shield unreadied first differs (STR 21).

## Chat 76: the shop's HALVE and JOIN (check 156), the silver shop's BUY of a ring (check 157), MEMORIZE then REST (check 158), SCRIBE from a scroll (check 159, a fix; ready check `scrord` for Combat), the temple's RAISE DEAD (check 160), SCRIBE using up a one-spell scroll (check 161); DIFFCHECKS 161/161

All main path, each against the original in DOSBox (lab `data/c76/chk156`-`chk159`, links in `data/c76/cd/`), tpseed 11111111.

- **Check 156, HALVE and JOIN** (3:0 the arms and armour shop): check 154's start (LIRA's 10 arrows, readied): Up, YES,
  End x4 (LIRA), VIEW, ITEMS, End x3 (the arrows), HALVE (5 readied, 5 not), HALVE (3 readied, the new 2 inserted after it,
  then the 5), End (the 2), JOIN (all three into the 2: one stack of 10, not readied), EXIT x3, F2 (the original: ENCAMP,
  SAVE F). Matched at once, 3 of 3; JOIN on the readied 3 differs (readied).
- **Check 157, the silver shop's BUY** (3:0): check 27's start with DORN given 1000 platinum: Up, YES, End x5 (DORN), BUY
  (the list opens on page 2: BUY PREV EXIT), End x10 (SILVER RING, 90), BUY, Home x4 (20 SILVER ARROWS, 20), BUY, EXIT x2,
  F2: 22 platinum paid (110 gp), the ring unidentified (words 0.66.177). Matched at once, 3 of 3; one Home fewer (a quarrel)
  differs. No jewel is sold in Pool's shops; the ring is the silver shop's one piece of jewellery.
- **Check 158, MEMORIZE then REST** (3:0 camp): check 157's start with LIRA's memory cleared (+0x2B = 0): ENCAMP, End x4,
  MAGIC, MEMORIZE (the list opens on its last line, SLEEP), Home (SHIELD), MEMORIZE, EXIT, EXIT, YES, REST (4:15 offered),
  REST (06:00 -> 10:15), EXIT x2, F2: SHIELD (19) memorized. Matched at once, 3 of 3; SLEEP instead differs.
- **Check 159, SCRIBE** (3:0 camp): check 158's start with a read Magic User Scroll appended to LIRA's items (byte 53 = 0,
  spells 17 and 20, word 48 = 211 "WITH 2 SPELLS"): ENCAMP, End x4, MAGIC, SCRIBE, Home (PROTECTION FROM GOOD), SCRIBE,
  EXIT, EXIT, YES, REST, REST (4:15), EXIT x2, F2: 17 in the book, the scroll kept with 20 and word 48 = 210. **Ours left
  word 48 at 211 (the difference; main path): fixed.** The original spends a scroll spell through GAME.OVR 0x2A2A2: the
  last of bytes 60-62 holding the spell is emptied, byte 48 counts one down, and below 210 the scroll is removed whatever
  its slots hold (a made-up 212 scroll with one spell stayed, 211 and empty; a 210 scroll is gone): `PartyMember.
  spend_scroll_spell` (ours removed it when all three slots were empty and didn't count the word down). 3 of 3; SCRIBE of 20
  instead differs. An unread scroll (byte 53 = 6) offers nothing to SCRIBE in the original either (no message seen).
- **Check 161, SCRIBE from a one-spell scroll:** check 159 with the scroll's spells 20, 0, 0 and word 48 = 210, no Home:
  20 in the book, the scroll gone (210 - 1 < 210). Matched at once, 3 of 3 (ours removed it before the fix too); without
  the REST differs.
- **Check 160, RAISE DEAD** (3:0 Tempus' temple): check 155's start (RHIANNON dead, +0x10C = 6, with the poison 0x37 in
  her .SPC): check 144's walk, YES, POOL, End x2 (RHIANNON), HEAL, End x6 (RAISE DEAD), HEAL (WILL ONLY COST 5500 GOLD
  PIECES), YES (RHIANNON / IS CURED.: no survival roll seen), EXIT, SHARE, EXIT, NO, F2: OKAY, HP 1, CON 14 -> 13, the
  poison record gone. Matched at once, 3 of 3; NO at PAY FOR CURE differs.
- **The shop's OVERLOADED** (check 154's BUY of a sixth PLATE MAIL): no text caught on the original's screen even 0.02 s
  after the key (GAME.OVR holds "Overloaded" at 0x250CB and 0x25707); ours flashes the same word: display only, left.
- **Ready check `scrord` (for Combat, camp_screen.gd):** the same with the scroll's spells 20, 17. The original lists a
  scroll's spells in record order, a level heading wherever the level changes (17, 34, 20 shows 1ST PROTECTION FROM GOOD /
  2ND STINKING CLOUD / 1ST SHOCKING GRASP), the cursor on the last; ours sorts them by number, so Home picks 17, not 20
  (`DC_DATA=<lab>/data/c76/cd DIFFCHECK_ONLY=scrord bash data/c52/dc_new.sh <repo>`; differs now by the scroll's slots).

## Chat 75: the camp's CAST CURE DISEASE, then a day's REST (check 149), and on effect 0x22 alone (check 150, a fix), REST with a diseased member (check 151), the shop's ID twice (check 152; statediff compares record byte 53), the temple's APPRAISE (check 153), the shop's BUY that overloads (check 154), SLOW POISON then the temple's NEUTRALIZE POISON (check 155); DIFFCHECKS 155/155

- **Check 149, CURE DISEASE cast in camp** (main path; Gold Box Guide 4's request: Jeremy is sure it works): check 144's
  start (3:0, THRENDER GRONE with the mummy's disease 0x32 and rot 0x39) with THRENDER at 3 HP and BROTHER SEAN given
  CURE DISEASE in memory (a made-up state: no cleric of this party reaches 3rd-level spells), tpseed 11111111. In the
  original (DOSBox): ENCAMP, MAGIC, CAST (the list opens on its last line: End wraps to CURE DISEASE), CAST, THRENDER:
  "THRENDER GRONE / IS CURED", both effects gone from his .SPC; then MAGIC's REST, 24 hours (twelve d100 interruption
  rolls, none): THRENDER 3 -> 4, as every living member. So the camp spell does cure, and the cured heal on rest as
  others (a diseased member doesn't: check 148's rule). Ours the same (`SpellCaster` CURE_DISEASE ->
  `SpecialAffects.cure_disease`): matched at once, 3 of 3; the cure cast on BAKSHI instead differs (THRENDER HP 3).
- **Check 150, the same spell on effect 0x22 alone** (main path; **a difference, fixed**): check 149's start with
  THRENDER's 0x32 record made 0x22 and the rot dropped. The original: "THRENDER GRONE / IS CURED", 0x22 gone. Cure
  Disease's handler is GAME.OVR 0x29347, a wrapper of 0x292A2 (Neutralize Poison's cure on the unpoisoned): each of
  0x22, 0x2B (with 0x2C, 0x1F) and 0x32 (with 0x39) found is named cured through 0x2BF6B and removed; nothing on the
  healthy (the spell is spent; no message). Ours' camp spell went through `SpecialAffects.cure_disease` (0x32, 0x39,
  0x1F, 0x2B, 0x2C, no 0x22, no message): ours kept 0x22. Now `SpellCaster._cure_292a2`, shared with Neutralize
  Poison: "IS CURED" per cure, as the original. 3 of 3; before the fix and with the cure on BAKSHI it differs. The
  temple's CURE DISEASE still uses `SpecialAffects.cure_disease` (Combat's; check 144 matches; 0x22 there untested).
- **Check 151, the camp's REST of a day with a diseased member** (main path, the standing list): check 149's start, no
  cure: ENCAMP, REST 24 hours (twelve d100 interruption rolls, none). The original: THRENDER (the mummy's disease) stays
  at 3 HP, BAKSHI and PHINEAS 4 -> 5; ours the same (the heal skips the diseased). Matched at once, 3 of 3; with the
  disease taken from the start, ours heals him (differs). Ours' keys wait after REST: a key sent while ours still
  rests leaves it in camp, where F2 doesn't save (a first try compared a stale save).
  Check 149's keys had the same fault under load (the Lead's autocheck on 4fd2c88: "F2 not reached"): 30 waits
  after its REST now, resealed.
- **Check 152, the arms shop's ID twice** (main path, the standing list): check 143's start with ARN given 500 gold.
  The original: ID on the unreadied BROAD SWORD (record byte 53 = 6), YES: the list shows BROAD SWORD -2 CURSED (the
  reply was gone within 0.5 s); ID on the LONG SWORD (byte 53 = 0), YES; 400 gp paid, the 100 left regrouped as 20
  platinum, the sword's byte 53 cleared. Ours the same (`character_sheet.gd` `_identify`). **statediff.gd now compares
  byte 53** (`h` in the item key; it compared neither it nor any check's ID before): all 152 checks match with it;
  the first ID moved to the Long Sword (coins the same) differs only by `h6`. NO at the second ID differs (coins).
- **Check 153, Tyr's temple APPRAISE** (main path): chat 74's ready check `data/c74/tapp` joins the gate after Combat
  Chat 36's fix (d4d9d13: the temple's APPRAISE is the shop's, KEEP only when one more coin fits and under 16 items,
  SELL through 0x24E8C). MATCH 3 of 3 on 3c24252 (5 differences before the fix); KEEP at the first offer differs.
- **Check 154, the arms shop's BUY that overloads** (main path, the standing list): check 146's start with DORN given
  1000 platinum; PLATE MAIL (400 gp, weight 450) bought eight times. The original: five bought (600 platinum left,
  load word 3163), the last three refused with nothing paid (the refusal's text flashes too fast for the dumps). Ours
  the same (`PartyMember.can_take_item`: the load plus the item over the ceiling). Matched at once, 3 of 3.
- **Check 155, SLOW POISON in camp, then the temple's NEUTRALIZE POISON** (main path, the standing list): check 144's
  start (RHIANNON dead of poison, 0x37) with BROTHER SEAN given SLOW POISON. The original: RHIANNON / IS AFFECTED,
  GETS BACK UP (HP 1); the walk to the temple; NEUTRALIZE POISON, 1000 gp, RHIANNON / IS CURED.: 0x37, 0x16 (slowed)
  and 0x0F (the tick) gone, HP 1, OKAY. Ours the same. Also seen: the temple's party cursor starts on the camp's last
  pick (SEAN), not the first member; ours follows it (the keys go through PHINEAS and back). 3 of 3.

## Chat 74: the shop's SELL of a readied item (check 143), the temple's CURE DISEASE (check 144), the camp's ALTER DROP (check 145), the shop's BUY four times and BUY refused for money (checks 146, 147), the temple's CURE LIGHT WOUNDS on a diseased member (check 148); DIFFCHECKS 148/148

- **Check 143, SELL of a readied item** (main path): check 132's start (3:0's arms and armour shop, tpseed 11111111).
  In the original (DOSBox): VIEW, ITEMS, SELL with ARN's readied Long Sword lit does nothing (no message on the bottom
  line, grabbed at once, 0.3 s and 0.7 s; the list unchanged), as ours (`character_sheet.gd`: SELL only of an unreadied
  item); READY unreadies it, SELL: I'LL GIVE YOU 7 GOLD PIECES FOR YOUR LONG SWORD, YES, the sword gone and 7 gp to
  ARN. Matched at once, 3 of 3; without the READY it differs (ARN's coins).
- **Check 144, the temple's CURE DISEASE** (main path): check 136's start (3:0, the walk to Tyr's temple) with
  THRENDER GRONE given a mummy's disease in his CHRDATG1.SPC: 0x32 (14400 minutes, power 255) and 0x39 (43200 minutes,
  0x3F: 3 months). In the original: POOL, HEAL, End, HEAL: CURE DISEASE WILL ONLY COST 1000 GOLD PIECES, YES: both
  effects gone (the other standing effects kept), as ours (`SpecialAffects.cure_disease`). Matched at once, 3 of 3; a
  variant with a standing 0x24 added to ours' start only differs (statediff compares the effects).
- **Check 145, the camp's ALTER, DROP** (main path): check 142's start (check 130's party at 3:0). In the original:
  ENCAMP, ALTER, End x2 (CEDRIC), DROP: CEDRIC / WILL BE GONE and DROP FROM PARTY? YES NO; YES: the message area is
  cleared and the party is five (the slot's save holds five CHRDAT files). Ours the same. Matched at once, 3 of 3; NO
  instead of YES differs (CEDRIC still in ours).
- **Check 146, the shop's BUY four times** (main path): check 98's start, DORN (3 gold, 8 platinum) buys four
  Bardiches (7 gp each): 43 gp -> 15 gp, his purse regrouped as 3 platinum, seven items. Matched at once; three BUYs
  differ.
- **Check 147, BUY refused for money** (main path): check 146's end (slot.py F -> G), DORN with 15 gp buys the
  Glaive-Guisarme (10 gp) twice: the first bought (1 platinum left), the second refused (GAME.OVR 0x712C, "Not enough
  Money." through the message routine; not caught on screen by any grab). Matched at once; the Glaive (6 gp, both
  bought) differs.
- **Check 148, the temple's CURE LIGHT WOUNDS on a diseased member** (main path): check 144's start with THRENDER
  GRONE at 3 HP. The original: CURE LIGHT WOUNDS WILL ONLY COST 100 GOLD PIECES, YES, THRENDER GRONE IS CURED., the
  gold taken, HP still 3 and the disease kept, as ours (`temple_screen.gd`: the wound cures skip the diseased).
  Matched at once; without the disease it differs (ours heals him to 7).

## Chat 73: the camp's USE of a Potion of Giant Strength (check 137), TRADE of a readied cursed item (check 138), REMOVE CURSE with effect 0x24 and a cursed item (check 139), a half-elf cleric at the hall (check 140), a band REST interrupted that fights (check 141), the camp's ALTER ORDER (check 142; statediff compares the party's order); DIFFCHECKS 142/142

- **Check 137, the camp's USE of a potion** (main path): check 130's start with ARN given a Potion of Giant Strength
  (the record from check 100's start: type 84, byte 61 = 82, the item spell 59; ARN's item count +0xC7 3 -> 4). In the
  original (DOSBox, tpseed 11111111): VIEW, ITEMS; with sword and shield readied, READY of the potion is refused (no
  message to be seen) and USE of an unreadied potion does nothing; the shield unreadied, READY, USE: one d4 (GAME.OVR
  0x2783D: 2), the potion gone without a message, effect 0x26 for 70 minutes (3 x 10 + 40; power 101), STR 21/00 on the
  sheet and in the save. Ours the same (also the refusal with hands full). Matched at once; variants: without USE
  differs (STR 18), tpseed 11111115 differs (the effect's minutes 50). No potion of Healing exists in any save of the
  lab (only Giant Strength's record), so Healing's 2d4+2 stays without a check.
- **Check 138, TRADE of a readied cursed item** (main path): check 131's start (THRENDER GRONE's readied Broad Sword -2):
  TRADE says MUST BE UNREADIED (the bottom line, as DROP's) and nothing moves; there is no curse message, the readied
  test comes first. Ours the same; matched at once.
- **Check 139, the temple's REMOVE CURSE on a member with Bestow Curse's effect and a cursed item** (main path): check
  136's start with THRENDER GRONE's .SPC given a standing 0x24 record; HEAL, REMOVE CURSE, 3500 gp, YES: the original
  lifts the effect and leaves the readied Broad Sword -2 cursed (one curse a cure, the effect first: GAME.OVR 0x4DB6),
  as Combat Chat 35's fix does. Matched at once; without the effect it differs (the sword uncursed).
- **Check 140, a half-elf cleric 5 at the clerics' hall** (main path): check 135's start remade (THRENDER GRONE a half-elf
  cleric 5, 40000 experience); 3:11's clerics' room is 5,0 (through 6,0's west door; the magic-users' 7,0, east):
  YES, TRAIN: NOT ENOUGH EXPERIENCE (Pool's half-elf cleric cap, GAME.OVR 0x1C3F7-0x1C501, ours' race_capped).
  Matched at once; as a cleric 4 it trains (differs).
- **Check 141, a band REST interrupted that fights** (main path): check 133's start (8:27, tpseed 35353535), REST 8
  hours: YOU SURPRISE A GROUP OF GNOLLS, COMBAT (the party already on QUICK), 5642 draws identical, CONTINUE BATTLE NO,
  93 XP each, DIRTEN at 0 HP, the treasure left. Matched at once. In the original's trace a fleeing gnoll is put back
  on the square it left while the two free blows' d20s (GAME.OVR 0x2BBBF) are rolled, then steps on; ours rolls the
  same two without that position (a logging difference: same draws, same end).
- **Check 142, the camp's ALTER, ORDER** (main path): check 130's start, SELECT ARN, End x2, PLACE: BRAM, CEDRIC, ARN.
  **statediff.gd compares the party's order now**: it paired the members by name, so no check ever compared the order
  (the variant with one End matched before the change; it differs now). All 141 earlier checks keep their order;
  the deliberate-break test (SUB broken) 121/141. Display only, to Combat: the original clears the message at PLACE,
  ours keeps ARN HAS BEEN SELECTED until the camp menu.
- **Item type table** (DS:0x5582, 16 bytes a type): +0 the slot, +1 hands, +0xD the classes allowed (and-ed with the
  character's +0xB0); READY's results (GAME.OVR 0x22585-0x2274C): 1 "Wrong Class", 2 a slot taken.

## Chat 72: Player 34's three state differences (the wall ahead twice, 0x4A5F) explained and two fixed; the camp's USE of a clerical scroll (check 130); a cursed item readied (check 131), SELL of a cursed item (check 132), a REST interrupted in a wilderness band (check 133), USE of a combat-only wand in camp (check 134), a race-capped fighter at the hall (check 135), REMOVE CURSE on a cursed item (check 136, Combat's fix); DIFFCHECKS 136/136

- **p22c2's wall ahead (original 1, ours 0): fixed** (`ecl_vm.gd` CALL 0xC018). DOSBox from a jump save to 1:18 1,4 W
  (`mksave.py J G 1 18 1 4 W`, `dsread.py 6aad 5` after each key): 0,4 W 1; the step off the west edge 0 (the on-move's
  CALL 0xC01E at the wrapped 15,4); the wilderness leaves it; the step into 8:27's band writes **1** = 1:18's wall at
  15,4 facing E. The arrival (GAME.OVR 0x3EFA) sets 0x49FA = 1 (0x3F2E) before it runs the new block's init and sets
  the band's / wilderness's kind (0x3F4C-0x3F94) after, so the band init's CALL 0xC018 (8:27 0xAACF, 0xAAF3, 0xAB14)
  takes the 3D branch (0x3AFA-0x3B12) on the geo still in memory at 0x6AAD-0x6AAF. Ours now reads it in any init.
- **p16d1's wall ahead (original 8, ours 2): a replay artefact, no change.** DOSBox from p16d1's `s6norris`: 2 after
  the climb up and NO; **ENCAMP writes 8**: the camp runs the area's rest block (8:29 0x9BDD: CALL 0xC018 in the plaza's
  map 29 at 7,7 N). The original's checkpoint is saved in camp; the segment's replay stops before the checkpoint's
  ENCAMP, so ours' F2 is taken outside camp. Ours does the same when it camps (from `s6norris` with ENCAMP, SAVE,
  EXIT: statediff 0 for the wall ahead). Asked of the Player: end the replay with the checkpoint's ENCAMP and EXIT.
- **p25e4's 0x4A5F (original 8, ours 6): fixed** (`main.gd`, ECL 0x6DC8 after a fight). 8:16 0x99D0 adds the fight's
  0x6DC8 to 0x4A5D (lizard men, capped) and 0x4A5F (giant lizards). The first fight (20 lizard men, 4 giant lizards,
  two got away): the original 24 (0x4A5D 20, 0x4A5F 4 at `s22d`), ours 22. GAME.OVR 0x672A counts every monster figure
  taken off the list that is out of the fight (record +0x10D not 1), those that got away too; ours counted only the
  ones put down. Spoils still go by `defeated()`. Both replays now identical (p25e4 0 differences; p22c2 only the
  ignored 4AFx). DIFFCHECKS 129/129 with both changes, then 131/131.
- **Check 130, the camp's USE of a clerical scroll** (main path): chat 71's open question answered in GAME.OVR: USE
  needs the item readied (0x222F4 "Must be Readied"), a scroll's type (62) takes **both hands** (DS:0x5582 table,
  hands byte 2; READY 0x225AC: "Your hands are full!"), so CEDRIC must unready mace and shield first; then USE opens
  "CEDRIC'S SPELLS ON SCROLL", CAST, the target, one d8. Ours already did this (Combat Chat 5). Matched at once.
- **Check 131, a cursed item readied** (main path, 3:14's Broad Sword -2): READY refused (IT'S CURSED, 0x22547),
  DROP refused (MUST BE UNREADIED), another weapon refused (ALREADY USING BROAD SWORD). Matched at once.
- **Check 132, a SELL of a cursed item** (main path): check 98's start, ARN given the Broad Sword -2 unreadied: the
  arms shop offers 0 gold (its value is 0), YES, the sword gone. Matched at once.
- **Check 133, a camp REST interrupted in a wilderness band** (main path): check 31's start in 8:27, tpseed 35353535
  picked by simulating the dice (the rest draws one d100, interrupted under the rest block's 10: 1); the 8 hours
  pass, then 8:27's rest-interrupted block (0x4A15 = 1, the band's encounter): YOU SURPRISE A GROUP OF GNOLLS, FLEE.
  Matched at once.
- **Check 134, the camp's USE of a combat-only wand** (main path, 4:10's Wand of Lightning Bolt, ITEM4 list 28):
  LIRA readies it (one hand with her sword), USE: THAT ITEM / IS A COMBAT-ONLY ITEM... / USE IT?, YES: a charge
  spent (record byte 60: 3 -> 2), nothing cast. Matched at once.
- **Check 135, a race-capped fighter at the training hall** (main path; made-up start): check 103's start with
  THRENDER GRONE an elf fighter 5, STR 16, 40000 experience: TRAIN says NOT ENOUGH EXPERIENCE in both (an elf
  fighter stops at 5 under STR 17). The start carries the elf's effect 0x6B in its .SPC: ours adds a race's
  missing standing effects on load, the original doesn't (only made-up starts show it).
- **Check 136, REMOVE CURSE on a member with a cursed item** (main path): chat 71's ready check `curse`, joined
  when Combat Chat 35's fix (87e2f9a, main chat 71's patch with the spell's own text) reached origin/main: MATCH;
  with the fix's clear of byte 54 left out it differs (the sword still cursed).
- **Racial level limits:** Pool enforces them at the hall (GAME.OVR 0x1C3F7-0x1C501; ours `LevelDrain.race_capped`
  already does); Curse's are in its GAME.OVR 0x24DDE-0x24F5B (playbook Inbox).
- **match_gate.sh** replays four recordings side by side (`OP_MATCH_JOBS`, default 4).

## Chat 71: 3:14's poison gas trap (check 125), STONE TO FLESH on a member not stoned (check 126), a wilderness save loaded and stepped (check 127), a shop's BUY over the load and at it (checks 128-129), REMOVE CURSE on a cursed item (ready, Combat's fix); the shortcut win's segment 28 replayed; DIFFCHECKS 129/129

- **Check 125, 3:14 Kovel Mansion, the poison gas trap** (event 4 at 13,11: the step's dispatch 0x99D6 -> the find-traps
  test 0xB3A2 -> 0x9AA4, `DAMAGE 129, 1, 3, 0, 0`: 0x80 one random member, save bonus 1, kind 0): a jump save
  (`mksave.py J G 3 14 13 10 S`), tpseed 222238ba (picked by simulating TpDice: seed x 134775813 + 1, (seed >> 16) mod n,
  which reproduced the first try's five draws exactly); Up (the jump), Up onto 13,11: d100 11 finds the trap (AVOID TRAP
  DISARM TRAP), D, SELECT (THRENDER GRONE, the first): d100 95 fails, THE PARTY HEARS THE CRACKING OF GLASS, d3 = 3,
  d6 picks PHINEAS, d20 = 4 (+1 fails): PHINEAS IS HIT FOR 3 (4 -> 1); Enter, F2. **Matched at once, 3 of
  3.** Variant (tpseed 2222224b: d20 12, PHINEAS saves) differs: PHINEAS HP 1 / 4. Lab `data/c71/chk125`.
- **Check 126, the temple's STONE TO FLESH on a member who isn't stoned** (check 122's start and keys, End x8): IS NOT
  STONED, CAST CURE ANYWAY YES, 2000 gp, YES; nothing else changes in the original. **Matched at once, 3 of 3**; check
  122's keys against this end differ (the coins). Lab `data/c71/chk126`.
- **Ready check `curse`: REMOVE CURSE on a member with a cursed item** (check 122's start, THRENDER GRONE's Flail
  unreadied and ITEM3 list 27's first record appended, readied: the Broad Sword -2 from 3:14's weapons pile, record
  byte 54 = 1, count +0xC7 3, weight +0x102 721). The original (GAME.OVR 0x4DB6): a carried item with byte 54 set, or
  effect 0x24, means cursed: no "IS NOT CURSED", the price, YES, then the spell (0x29558): effect 0x24 goes if there is
  one, else the first cursed item's byte 54 is cleared ("'S ITEM IS UN-CURSED"). Ours' temple doesn't model curses
  (temple_screen.gd `_needs`): it stops at IS NOT CURSED and the keys part. **A difference on the main path** (3:14's
  sword, 4:2's Cursed Necklace); Combat's file: requested on the board, with `data/c71/remove_curse.patch` (MATCH with
  it). Joins the list once it lands.
- **Check 127, a save made in the wilderness band loaded and stepped** (Player 10's `p10b1/band` save of the original,
  view byte 0x3206 = 3, at 24,27 W 00:10, ARN unconscious; slot H -> G by slot.py), tpseed 33333333: Up x3 (north is
  blocked there: the party only turns N), Left x2 (23,27, 22,27: each step half a day, 12:10 then 00:10), F2. **Matched
  at once, 3 of 3**; one Left fewer differs (0x49C3, the wilderness x). Lab `data/c71/chk127`.
- **Checks 128 and 129, the arms shop's BUY over the load and at it** (check 98's start and keys; DORN, STR 18/99: load
  limit 2000 + 1500 = 3500, items 310, coins 11; the cached load word +0x102 written to match): 3130 silver (128): the hand
  axe (weight 50) would make 3501: **refused**, nothing paid, no message seen; 3129 silver (129): exactly 3500: **bought**
  (limit inclusive, as `can_take_item`), the purse regrouped to 39 platinum 3 gold (20 silver = 1 gold). Both matched at
  once, 3 of 3; 128's start against 129's end differs. Lab `data/c71/chk128`, `chk129`.
- **The shortcut win, segment 28 (p27c2, the Stojanow wall at 2:9 7,6)** replayed in ours with `shortcutwin` after the
  fight's opening key (`segment.py p27c2 begin stojanow --start=p27a1_s28p --tplog --ours-key=46:shortcutwin`, in a
  scratch copy of the Player's lab): **draws identical to 1057** (the shortcut's point, as segment 34's 801); then the
  original's party plays the round on against the "dead" figures left on its map (ELWEN aims at one), ours has ended
  the fight. statediff 1: LIRA's memorized Sleep (spent in the original's extra round). With `GBR_PLAYOUT=1` ours plays
  the round but has no figures to aim at (138 differences, stops at CONTINUE BATTLE). Both shortcut runs are labelled
  "known shortcut" (the Lead, 2026-11-20).

## Chat 70: CURE BLINDNESS as check 123; a save made with a NEW_ECL pending (check 124); the Player's shortcut win in ours; DIFFCHECKS 124/124

- **Check 123, the temple's CURE BLINDNESS** (main chat 68's lab check `chkblind`, now numbered; Combat Chat 34
  landed the fix in temple_screen.gd): a blind member (effect 0x21 in his .SPC), the walk, YES, POOL, End x3, HEAL,
  HEAL, YES (1000 gp), EXIT, SHARE, EXIT, NO, save. MATCH 3 of 3; on the code before the fix (4689ebf^) 41
  differences.
- **A save made while a NEW_ECL's arrival is pending loads in the 3D view** (Player 33's `p20a3_s11k`, fixed in
  main.gd `load_original_save`, read in GAME.OVR, the Player's recording the evidence). The party left 7:17's
  nomad camp after its waves: the NEW_ECL to 26 loaded 26's script but its arrival waits for the main loop
  (0x442F; the view and menu stay 3D, chat 59), and the Player camped and saved there: image 26, 0x49F2 17, view
  byte 1. The original's load runs the image's init (the main loop 0x403E skips the block load while LOAD's 0x49F8
  is set) and **keeps the save's view**: only the arrival routine sets the wilderness view, from the block number
  (0x3F4C: 25, 26, 27 -> 2, 3, 4); 26's init's `LOAD_AREA_MAP 5,5,0` doesn't. Ours turned the wilderness on at
  that LOAD_AREA_MAP. Now the view after a load is the save's: 7:17's map at 0,0 W, 26's script running (one step
  north: LARGE NOMAD CAMP ENTER/LEAVE), as the original. The Player's segment p20a4 (`begin nomads`) was 78
  differences from its first keys; now its draws are identical to 16668 of 19860, then the QUICK-caster
  family (the replay's MAGIC timing: no MAGIC lines in the trace). **Check 124** (the save as slot G, tpseed 70700001): load,
  Right, Up (0,15 N: LARGE NOMAD CAMP, ENTER LEAVE), L (LEAVE: the 3D view stays, 0,15 N), save: MATCH 3 of 3; on
  the code before the fix (3583e43^) and without the L it differs.
- **The Player's logged shortcut win in ours' replay** (the Lead's Stage 1 item; lab key `shortcutwin`, main.gd):
  the same write as tools/original_player game.py `_shortcut_win` (every monster HP 0, status dead, out of the fight,
  no blows or spells), sent after the fight opens (`segment.py ... --ours-key=<n>:shortcutwin`). Segment 34 (p29f2:
  the finale's 12 guards, then Tyranthraxus): draws identical to 801 (the shortcut's point); then the original's
  party plays out the round against the "dead" figures, which stay on its map as targets (the hack skips the kill
  routine that takes a fallen figure off the map), ELWEN and CEDRIC casting, while ours' have left the field. With
  `GBR_PLAYOUT=1` (ours plays the round out and asks CONTINUE BATTLE) and 70 waits for the closing scene, statediff
  at valjevo7 is 8: the wall-set cells match.py ignores and 4 from those casts (CEDRIC's and ELWEN's memorized
  spells, Bless-type effect 2 on ARN and DORN, CEDRIC's 49). Ours applies the same state change; the parting is the
  hack's artefact, not a game difference. (The bot's own shortcut is different again: `dev_auto_win` ends the fight
  before any round, no CONTINUE BATTLE; unchanged, the Lead holds bot changes.)

## Chat 69: 5:5's poisonous hedge; the square left behind after a script moves the party; REMOVE CURSE on a member who isn't cursed; checks 121-122, DIFFCHECKS 122/122

- **Check 121, 5:5's poisonous hedge** (ECL 5:5 0x9B4B: CUT THROUGH, `DAMAGE 128, 1, 1, 200, 0`, then CALL 0xC01E;
  check 28's start at 11,7 W, tpseed 22222222): Right, Up (11,6), Up into the hedge, YES: SOMEONE IS PRICKED, **ARN
  fails the save: 200 damage, ARN DIES** (status 6, HP 0), Enter, the party is through at 11,5; save. (Seeds 11111111:
  the save made, nobody hurt; 33333333: LIRA dies.) **Found a difference: 0x49F1, the original 5, ours 6.** After a
  step's on-move the original writes the party's square (GAME.OVR 0x41B9: DS:0x6AAD / 0x6AAE) to 0x49F0 / 0x49F1;
  ours wrote the square of the attempt, which is the same square unless the script moved the party (the hedge's
  CALL 0xC01E, 5:7's stairs). Fixed in `main.gd` `_after_vm` (the VM's party square after the on-move). Three runs
  MATCH; NO instead of YES differs (5); the code before the fix differs (1).

- **Check 122, 3:0 the temple, REMOVE CURSE on a member who isn't cursed** (check 112's start; the walk, YES, POOL,
  THRENDER GRONE, HEAL, End x7, HEAL): **THRENDER GRONE / IS NOT CURSED. / CAST CURE ANYWAY: YES NO**, YES: REMOVE
  CURSE WILL ONLY COST 3500 GOLD PIECES., PAY FOR CURE YES: paid, no text after (the list back with an empty box);
  EXIT, SHARE, EXIT, NO, save. Matched at once (ours' `_needs` has no curses yet, which is right for a member with
  none). Three runs MATCH; NO at CAST CURE ANYWAY differs (20). The cure on a cursed member (a cursed item readied)
  is not checked.

## Chat 68: the tavern brawl, DROP and HALVE on a readied item, BUY at 16 items; CURE BLINDNESS ready for Combat; the game's poison death read; checks 118-120, DIFFCHECKS 120/120

- **Check 118, 3:0 New Phlan's tavern brawl** (ECL 3:0 0xA696; check 93's start, tpseed 62620001, GRAB; 46 drunks
  against the party and 13 patrons on its side): the whole party on QUICK, won (114 experience each), Enter x2, EXIT,
  NO (THERE IS STILL TREASURE LEFT), THE CITY WATCH CHARGES IN: RUN (3,11 W), save. The original's end and trace from
  chat 63 (6402 draws; ours identical since Combat Chat 32's 1e269a3). Three runs MATCH; tpseed 62620002 differs (44);
  1e269a3^ differs (16: ours lost the brawl).
- **Check 119, camp DROP and HALVE on a readied item** (check 106's start): DROP on ARN's readied long sword does
  nothing (no YES NO, no message), HALVE does nothing; READY off, HALVE on the single sword: nothing (**a stack of 1
  isn't split**). Matched at once; READY off before DROP, then YES, differs (1).
- **Check 120, the arms and armour shop, BUY at 16 items** (check 98's start with DORN holding 16 items: check 115's
  13 single arrows appended, 0xC7 = 16): BUY on the hand axe twice: refused, nothing paid, no message seen in the
  original (ours flashes OVERLOADED). Matched at once; DORN at 15 items differs (2).
- **Ready for Combat: CURE BLINDNESS on a blinded member** (lab `data/c68/chkblind`, `cd/blind`; check 113's start with
  effect 0x21 appended to BROTHER SEAN's `.SPC`): the original tests 0x21 (GAME.OVR 0x47D9), asks 1000 gp and removes
  the first 0x21 (0x4834 -> 0x2AF10). Ours' temple says IS NOT BLIND and stays on its screen (DIFFERS 41). A tested
  fix for `temple_screen.gd` (`_needs` and `_pay`, 10 lines) is in the lab (`data/c68/temple_blind.diff`): three
  runs MATCH with it; SEAN not blind then differs (41). It joins the gate as a numbered check when Combat lands it.
- **The game's own poison death** (read in the code; the standing list's open question from check 112): the poison
  routine (GAME.OVR 0x101A0) adds 0x37 through 0x2BD3C with minutes 0, **power (+3) 0xFF**, +4 0, then the kill
  routine 0xECB3 sets status 6, +0x10D 0, HP 0 and sends the death event (0xD) through 0x2B1E4. NEUTRALIZE POISON
  (0x4CC9) removes 0x37, 0x16 and 0x0F only and never touches status or HP; 0x37's handler (0xFFB7) is empty. So
  check 112's made-up state is the game's own, and a member dead of poison stays dead after the temple's cure in
  the original; chat 31's THRENDER stood at HP 1 because Slow Poison had stood him up before the temple. **Ours
  writes the poison effect with value 0** (`combat.gd`'s poison hit; the lab hook too): a save-file difference only
  (to Combat on the board).

## Chat 67: the temple's wound cures, camp JOIN, TRADE to a full member, READY of a two-handed weapon, the inn without money; checks 113-117, DIFFCHECKS 117/117

Coverage checks (the post's standing list), each played in DOSBox; all matched at once (no code change).
- **Check 113, 3:0 the temple, CURE SERIOUS and CURE CRITICAL WOUNDS** (check 110's start with THRENDER GRONE's
  platinum = 3000 and HP 1, BROTHER SEAN HP 1): POOL, SEAN, HEAL, End x3, HEAL, YES (2d8+1: draws 20-21), EXIT,
  THRENDER (End x3 wraps), HEAL, End x4, HEAL, YES (3d8+3: draws 22-24), EXIT, SHARE, EXIT, NO. All 24 draws
  identical; NO at the second cure differs (11); fails before Combat Chat 30's 60e9ec1 (33).
- **Check 114, camp JOIN** (check 107's start, LIRA's 10 arrows): HALVE, JOIN (10 readied); HALVE, Down to the
  unreadied half, JOIN: **10 arrows, not readied: the join keeps the lit stack's readied flag**. The other half lit
  differs (1); no second JOIN differs (1).
- **Check 115, TRADE to a member with 16 items** (check 105's TRADE with BRAM's .ITM holding 13 single arrows more,
  record byte 0xC7 = 16): refused, the sword stays with ARN. BRAM at 15 items differs (2).
- **Check 116, READY with a two-handed weapon** (ARN with a Short Bow beside his sword and shield): the bow is refused
  while the sword or the shield is readied; with the bow readied the shield and the sword are refused (no message in
  either game). One shield unready left out differs (1).
- **Check 117, 3:0 the inn, STAY with no money** (check 97's start, THRENDER GRONE's coins 0): YOU DON'T HAVE ENOUGH
  PLATINUM. and the inn's script ends: no second payer, no rest. THRENDER with his money differs (22).
- **Made-up starts:** an .ITM record's bytes 42-45 (the in-memory link) are 0 in every record we append (the original's
  own files have them on all but the last). A record read and written in one Python line with `open(p,'wb')` first
  empties the file (chat 67 lost ARN's items that way before the boot showed it).

## Chat 66: camp TRADE, DROP and HALVE, a shop's APPRAISE; ENCOUNTER_MENU's choices read; statediff compares whole items and effects; checks 105-112, DIFFCHECKS 112/112

- **Check 112, 3:0 the temple, NEUTRALIZE POISON and CURE DISEASE** (check 110's start with THRENDER's platinum = 3000;
  RHIANNON dead, HP 0, with effect 0x37 added to her `.SPC`; BROTHER SEAN with effect 0x32, disease, 14400 minutes):
  POOL, RHIANNON, HEAL, NEUTRALIZE POISON (End x5), HEAL, YES (1000 gp): **the 0x37 goes, but she stays DEAD at HP 0**
  (a made-up state: chat 31's THRENDER, poisoned by the game itself, came back at HP 1; what the game's poison death
  holds beyond 0x37 is not read); SEAN, CURE DISEASE, YES: the 0x32 goes; EXIT, SHARE, EXIT, NO. Matched at once,
  effects and the jewelry slot's share too. Three runs MATCH (lab `data/c66/chk112`).
- **Check 111, 3:0 the temple, RAISE DEAD** (check 110's start with RHIANNON dead, +0x10C = 6 and HP 0, and THRENDER
  GRONE's platinum +0x90 = 3000): the walk, YES, POOL, End x2, HEAL, End x6 (the list opens on CURE BLINDNESS), HEAL:
  RAISE DEAD WILL ONLY COST 5500 GOLD PIECES. / PAY FOR CURE YES: HP 1, OKAY, **CON 14 -> 13**, max HP kept (CON under
  14); EXIT, SHARE, EXIT, NO, F2. No draws past the walk's 19. Matched at once; NO instead of paying differs (23).
  **statediff compares the ability scores** (+0x10-0x15, STR 18/xx +0x16) from here: 111/111 with it; break test
  rerun: SUBTRACT 94/111, ADD 110/111 (17 and 1 caught, as before). Three runs MATCH (lab `data/c66/chk111`).
- **Check 110, 3:0 the temple of Tempus (COMBAT with 0x6DE2 = 1: the handler table's temple line now runs in a matching
  check)**: chat 64's ready check (`data/c64/chk_temple`): THRENDER GRONE's 2000 gp, tpseed 11111111, the walk, YES;
  BAKSHI, HEAL, CURE LIGHT WOUNDS, HEAL, YES (no money on him: nothing), EXIT, POOL, HEAL, the cure (the game's d8,
  draw 20), EXIT, SHARE, EXIT, the retrieve question, NO. **All 20 draws, statediff 0 (whole items and effects too)**
  since Combat Chat 31's 1e9660d (the temple's pile as the shop's; the jewelry slot's 3500 / 2333 / ... is SHARE's
  word wrap on THRENDER's stale load word); fails on the code before (15 differences). Three runs MATCH. The tavern
  brawl still waits (Combat asked the Lead whether it is a gate item).
- **statediff compares the standing effects** (the original's `.SPC` beside each record: type, minutes, power; ours'
  `affects`). Across the 109 checks five differed: **(1) stale `.SPC` files in four checks' original ends** (19 and 21:
  F4, F5; 34 and 35: F1-F3, F7: ARN with a dwarf's race effects): DOSBox shows the original **deletes a member's `.SPC`
  when it saves one with no effects** (check 19's start, LOOK, ENCAMP SAVE: SEAN's and DARKSTAR's went when their
  2-minute effect 1 ran out) and writes none for ARN (check 34's start and keys played again: no F1-F3/F7 `.SPC`), and
  that it **loads any `.SPC` it finds** beside a record (a stale one put by hand came back in the next save): the files
  were left by how those folders were made. Removed from `~/gbr/checks/data/{19,21,34,35}/orig` and resealed.
  **(2) Check 95, 1:18's buccaneer duel: a difference fixed.** The members set aside for a duel kept a 2-minute effect 1
  in ours (the fight ticks only its fighters; the clock moves by its rounds after it); the original's save has it gone
  from all six (its figure list holds them). `main.gd` `_on_event_fight_finished` now passes the fight's rounds for the
  members set aside. Fails on the code before. Break test rerun: SUBTRACT 91/109, ADD 107/109 (on origin/main without
  the duel fix, so 95 fails in both; otherwise as before).
- **statediff compares the items whole** (`tools/statediff.gd` `_items`): until now only the name words (bytes 47-49)
  were compared, though its header said plus, count and readied; now type, the name words, plus and save plus,
  readied, cursed, count, price and bytes 60-62. **All 109 checks match with it** (check 26 with ARN's sword unreadied
  after it now differs on `r1`/`r0`). Deliberate-break test rerun (`data/c44/brk`, on origin/main 94e810d + the new
  statediff): SUBTRACT off by one 92/109 (17 caught), ADD off by one over 200 108/109 (1 caught), as before.
- **Check 108, 3:0 the arms and armour shop, APPRAISE gems** (check 101's start with ARN's gems, record +0x92, = 2;
  tpseed 11111111): Up, YES, APPRAISE (YOU HAVE A FINE COLLECTION OF: 2 GEMS), GEMS: a d100 (OVR:26900, 38): THE GEM
  IS VALUED AT 50 GP. / YOU CAN : SELL KEEP, SELL; GEMS (68: 100 GP), KEEP; EXIT, F2 (the original: ENCAMP SAVE).
  Draws identical (3, with the shop step's d20). Matched at once; KEEP replaced by SELL differs (ARN's platinum).
  Three runs MATCH (lab `data/c66/chk108`, the original's trace `data/c66/gem/trace.txt`).
- **Check 109, the same shop, APPRAISE jewelry** (ARN's jewelry, +0x94, = 2): JEWELRY: a d100 (OVR:26b8d, 38), then
  START.EXE 0x8D1D's d1500 (1068: VALUED AT 1368 GP), SELL: ARN gets 273 platinum (the 3 gp over dropped); JEWELRY
  (97, then a d10000: 8144 GP), KEEP: the jewel leaves the coin slot. Draws identical (5); three runs MATCH
  (`data/c66/chk109`, trace `data/c66/jewel/trace.txt`).

- **Check 105, 3:0 camp VIEW ITEMS, TRADE** (check 26's start, tpseed 11111111): ENCAMP, VIEW, ITEMS, READY (ARN's long
  sword off; TRADE on a readied item does nothing in the original, no message), TRADE: TRADE WITH WHOM? SELECT EXIT,
  End (BRAM), SELECT: the sword is BRAM's fourth item; EXIT x3, F2 (the original: ENCAMP SAVE). Matched at once; the
  same keys without the TRADE differ (ARN's items), so the check sees it. Three runs MATCH (lab `data/c66/chk105`).
- **Check 106, camp DROP**: the same start, READY (off), DROP: YOUR LONG SWORD WILL BE GONE FOREVER / DROP IT? YES NO,
  YES. Matched at once. Three runs MATCH (`data/c66/chk106`).
- **Check 107, camp HALVE**: the same start, Down x4 (LIRA), VIEW, ITEMS, Down x3 (her 10 ARROWS, readied), HALVE: 5
  ARROWS readied and 5 ARROWS not, after them. Matched at once. Three runs MATCH (`data/c66/chk107`).
- **ENCOUNTER_MENU's choice logic (GAME.OVR 0x2EEF-0x32ED) read beside `ecl_vm.gd` `_encounter_choice`: the five
  reactions agree branch for branch** (outcome 1 a fight, 2 away, 0 the monsters flee with THE MONSTERS FLEE., 3
  talk; BOTH SIDES WAIT. and the close-in loop back to the menu at 0x2D8D). **One difference fixed:** the party's
  slowest and fastest come from 0x9484 (each figure's +0x11C, **doubled as a byte under Haste, effect 39, else halved
  under Slow, effect 42**); ours ignored both (`_party_moves`). Only a member still hasted or slowed when a menu
  comes can see it (reaction 0's FLEE, reaction 2's COMBAT): no check. A reaction above 4 writes nothing and leaves
  the menu (ours would show it again); none of Pool's 94 ENCOUNTER_MENUs has one or takes one from a cell.
  **DS 0x4A00, 0x84E9 and 0x84E4 are display:** 0x4A00 set makes the text printer wait 0x49E2 x 10 ms a character
  (START.EXE 0x777B: the typewriter text during the menu; cleared at the end), 0x84E9 set (with 0x49F6 = 0) skips
  0x7A21's redraw of the approaching figure, 0x84E4 = 0 makes the walking-key routine clear the text window once
  (0x173ED).
- **The walking-key routine and the main loop (GAME.OVR 0x17060, 0x40FF-0x418F) beside `main.gd`: they agree.** S
  toggles bit 0 of the search word (+0x594 from 0x49D6) with no time and no step; a step costs 0x241A1(2, 1), ten
  minutes, with the bit set, else (1, 1), a minute (0x16E99); L sets bit 1, passes ten minutes and the loop runs the
  look entry [0x49E5] with the word at 1, then puts SEARCH's bit back (0x4136-0x416D); E calls the camp (0x3B19) and
  reads the next key without the step scripts. Left and Right call a sound (0x8AE:0xDC with DS 0x2628), Down (turn
  round) doesn't.

## Chat 65: the arena's duel, a band fight, a SELL, a camp's Bless and cure, a second training level; checks 99-104, DIFFCHECKS 104/104

**The handler table's last line closes: CALL 0x8000 now runs in a matching check (99).** Every opcode Pool's scripts
use, and every CALL target the original acts on (but 0xBA03, a sound), runs in a check that matches.

- **Check 99, 3:11 the arena's duel (CALL 0x8000, 0x9CA6)**: chat 64's ready start at 7,4 W, tpseed 11111111: Up x3,
  YES to the duel, QUICK: **all 1488 draws identical** (the double, morale 0xB2, fights on hurt: Combat Chat 30's
  3741bdd; the duelist's 100 experience per level through the class adjustments: THRENDER GRONE 158), then CONTINUE
  NO, the treasure, EXIT, F2. Fails on the code before Combat Chat 30's a6c7afb (the clock: the copy fled). Three runs
  MATCH (lab `data/c64/chk_arena`).
- **Check 100, 8:27 a band fight** (check 31's start, tpseed 31310016): one step north, YOU SPOT A GROUP OF KOBOLDS,
  COMBAT, QUICK: the wilderness battlefield (GAME.OVR 0xD785's field: 0xCE75's flags, the scatter, the clutter;
  Combat Chat 30's 0c76388), **7979 draws identical**, CONTINUE BATTLE NO, the treasure left (E, N), F2. Main chat
  61's band kobold request, closed. Fails on the code before 0c76388. Three runs MATCH (lab `data/c65/chk100`).
- **Check 101, 3:0 the arms and armour shop, a SELL** (check 26's start, tpseed 11111111): Up, YES, VIEW, ITEMS,
  SELL on ARN's readied long sword (the original does nothing: a readied item isn't sold), READY (off), SELL: I'LL
  GIVE YOU 7 GOLD PIECES FOR YOUR LONG SWORD / IS IT A DEAL? YES: ARN gets **1 platinum and 2 gold** (the price
  paid in the larger coins), EXIT x3, F2 (the original: ENCAMP SAVE). A coverage check (matched at once). Three runs
  MATCH (lab `data/c65/chk101`; the original's end `data/c65/sell/orig`).
- **Check 102, camp MAGIC: Bless, then Cure Light Wounds** (check 26's start with ARN's HP, record +0x11B, set to 5;
  tpseed 11111111): ENCAMP, MAGIC, End x2 (CEDRIC), CAST (the light starts on the list's last spell), End (it wraps
  to BLESS), CAST, then CAST again (CURE LIGHT WOUNDS), Home x2 (ARN), SELECT, EXIT x3, F2. **The original draws two
  d100s for the Bless** (trace `data/c65/cure_orig.txt`: OVR:11a4d -> 70, OVR:115fb -> 38), then the cure's d8 is
  draw 3 (1: ARN 5 -> 6). Those are the race handlers the add-effect routine (GAME.OVR 0x2C540) runs for every effect
  it adds, in or out of a fight: the half-elf's 30% (0x11A3F, ELWEN) and the elf's 90% (0x115ED, LIRA), each a d100
  whatever the effect (Combat's `SpecialAffects.blocks`, used in fights since Combat Chat 2). **Ours added a camp
  spell's effect without them** (no draws: the cure took draw 1, ARN 8). Fixed in `scripts/game/spell_caster.gd`
  `cast_outside`: each target's effect goes through `SpecialAffects.blocks` (with the spell's level, for magic
  resistance) after its duration; a blocked one says IS UNAFFECTED (not seen out of a fight: Sleep and Charm can't be
  cast there). Fails on the code before; three runs MATCH (lab `data/c65/chk102`).
- **Check 103, 3:11 the training hall, level 2 to 3**: the start is check 96's end in the original (after BEGIN
  ADVENTURING, 8,0 N) with THRENDER GRONE's experience 9000 and gold 5000; tpseed 11111111: Down, Up, Down, Up (back
  onto 8,0), YES, TRAIN, YES, BEGIN ADVENTURING. The original: level 3, one d10 (OVR:1dc04, 1): HP 22 -> 25, experience
  cut to 8000, 1000 gp (trace `data/c65/train2_orig.txt`). A coverage check (matched at once). Three runs MATCH.
- **Check 104, the training hall, TRAIN twice in one visit**: check 96 with a second TRAIN after the first (4000
  experience, short of level 3's: the original shows nothing and stays on CHOOSE A FUNCTION), then BEGIN ADVENTURING.
  Matched at once (a message needing a key in ours would put the keys out of step). Three runs MATCH.
- **ENCOUNTER_MENU (GAME.OVR 0x2C3E) read beside ours, part:** the set-up (operand 1 the sprite -> DS 0x6F81, 2 the
  maximum -> +0x580, 3 the picture -> 0x6F82, three texts, operands 13/14; the distance +0x582 = min(0x7955's open
  squares, the maximum)) and the text by distance (0x2DB9-0x2E94: distance d starts at text d+1 and wraps until one
  isn't empty) agree with `ecl_vm.gd`. Not in ours, effect unknown: the handler's first writes DS 0x84E9 = 1, 0x84E4 =
  0, 0x4A00 = 1 (DS bytes, not ECL cells). For a distance above 2 the original picks no text (its buffer is left as
  it was) where ours shows the third; Pool's constant maxima are 0-2, the cell ones are capped by the open squares.
  **The choice logic (0x2EEF on, ~1 KB) is not read yet.**
- **Still not checks:** the temple (COMBAT with 0x6DE2: the cure's d8 matches since Combat Chat 30's b8db5a7; the pile
  menus TAKE / SHARE and the retrieve question, and the jewelry slot, wait on Combat) and the tavern brawl (the
  patrons' placement, asked of the Lead by Combat Chat 30).

## Chat 64: the handler table (Methods 7: every ECL opcode Pool's scripts use, and the checks that run it); ECL CLOCK; a lost duel; the training hall, the inn, a purchase; checks 94-98, DIFFCHECKS 98/98

**How the table was made.** `~/gbr/checks/diffcheck.sh` copied with `--coverage=/tmp/opcov/cov/$n.json` added to ours'
command line (main.gd's dev coverage option, M6: each block's instruction offsets that ran), all 93 checks played
(93/93), then lab `data/c64/opcov.py <cov dir> data/c62` maps each offset to its opcode through chat 62's listings
(address = 0x9900 + offset). "Sites": how often the opcode appears in Pool's 29 blocks; "run": how many of those
sites ran in at least one check; "checks": the checks whose replay ran it (ours ran it and the end state matched the
original's). A check only compares state (ECL 0x4900-0x4AFF, the party, the place, the clock), so a handler whose
effect is display only (PICTURE, SPRITE_*, PRINT_*, CLEAR_BOX, DELAY, CALL 0xBA03) is run but not judged.

| opcode | sites | sites run | checks |
|---|---|---|---|
| ADD | 317 | 87 | 1 2 3 4 5 6 7 12 ... (61 checks) |
| AND | 356 | 109 | 1 2 3 4 5 6 7 8 ... (90 checks) |
| CALL | 180 | 55 | 2 3 4 5 7 10 12 13 ... (55 checks) |
| CLEAR_BOX | 27 | 8 | 2 31 32 33 34 35 37 39 ... (13 checks) |
| CLEAR_MON | 251 | 14 | 1 3 5 10 25 26 27 64 ... (19 checks) |
| CLOCK | 1 | 1 | 94 |
| COMBAT | 245 | 14 | 1 3 5 10 25 26 27 64 ... (19 checks) |
| COMPARE | 1504 | 488 | 1 2 3 4 5 6 7 8 ... (93 checks) |
| COMPARE_AND | 65 | 28 | 1 4 5 7 12 13 14 18 ... (39 checks) |
| COPY_MEM | 271 | 90 | 1 2 4 5 7 10 13 15 ... (53 checks) |
| DAMAGE | 48 | 11 | 24 25 30 47 60 69 70 87 ... (9 checks) |
| DELAY | 188 | 31 | 4 5 13 16 21 24 30 37 ... (20 checks) |
| DIVIDE | 29 | 9 | 4 18 51 67 71 72 73 77 ... (13 checks) |
| ENCOUNTER_MENU | 94 | 9 | 5 6 10 13 18 71 72 73 ... (14 checks) |
| EXIT | 985 | 172 | 1 2 3 4 5 6 7 8 ... (93 checks) |
| FIND_ITEM | 7 | 2 | 2 59 62 |
| GOSUB | 916 | 223 | 1 2 3 4 5 6 7 8 ... (77 checks) |
| GOTO | 1844 | 242 | 1 2 3 4 5 6 7 9 ... (84 checks) |
| IF_EQ | 690 | 257 | 1 2 3 4 5 6 7 8 ... (92 checks) |
| IF_GE | 127 | 61 | 1 2 3 4 5 6 7 8 ... (92 checks) |
| IF_GT | 281 | 65 | 1 3 4 5 6 7 12 13 ... (56 checks) |
| IF_LE | 24 | 9 | 2 4 7 13 15 17 31 32 ... (25 checks) |
| IF_LT | 180 | 59 | 1 4 5 7 9 12 13 18 ... (56 checks) |
| IF_NE | 634 | 167 | 1 2 3 4 5 6 7 8 ... (90 checks) |
| INPUT_NUMBER | 2 | 1 | 73 |
| INPUT_STRING | 20 | 1 | 6 |
| LOAD_AREA_DECO | 35 | 21 | 1 2 3 4 5 6 7 8 ... (70 checks) |
| LOAD_AREA_MAP | 61 | 29 | 1 2 3 4 5 6 7 8 ... (78 checks) |
| LOAD_CHAR | 36 | 14 | 3 4 5 18 20 30 48 51 ... (12 checks) |
| LOAD_MON | 330 | 11 | 3 5 10 67 68 69 70 71 ... (12 checks) |
| MENU_HORIZONTAL | 204 | 86 | 1 2 3 4 5 6 7 10 ... (74 checks) |
| MENU_VERTICAL | 15 | 7 | 24 40 47 51 60 74 77 78 ... (13 checks) |
| MULTIPLY | 12 | 2 | 71 72 73 77 78 79 80 84 |
| NEW_ECL | 79 | 13 | 2 5 7 13 15 21 33 37 ... (15 checks) |
| NPC_ADD | 8 | 1 | 54 |
| ON_GOSUB | 37 | 12 | 1 2 7 13 15 31 32 33 ... (23 checks) |
| ON_GOTO | 427 | 121 | 2 3 4 5 6 7 8 9 ... (91 checks) |
| OR | 208 | 30 | 2 4 5 10 11 16 18 19 ... (23 checks) |
| PARLAY | 41 | 5 | 6 54 59 71 72 73 86 |
| PARTY_CHECK | 4 | 3 | 65 71 |
| PARTY_SKILL_CHECK | 22 | 4 | 63 71 72 73 81 82 83 84 ... (9 checks) |
| PARTY_STRENGTH | 18 | 4 | 17 38 44 51 67 71 72 73 ... (15 checks) |
| PICTURE | 137 | 55 | 1 2 4 5 6 7 8 11 ... (61 checks) |
| PRINT | 289 | 36 | 1 2 5 6 13 23 25 30 ... (34 checks) |
| PRINT_CLEAR | 1401 | 278 | 1 2 3 4 5 6 7 10 ... (88 checks) |
| PRINT_RETURN | 20 | 3 | 6 60 |
| PRINT_RUNES | 12 | 2 | 60 |
| PROGRAM | 4 | 1 | 5 |
| RANDOM | 144 | 43 | 4 5 7 9 13 14 15 17 ... (55 checks) |
| RETURN | 440 | 147 | 1 2 3 4 5 6 7 8 ... (77 checks) |
| ROB | 14 | 6 | 72 73 74 76 93 |
| SPELL | 1 | 1 | 90 91 |
| SPRITE_ADVANCE | 97 | 12 | 4 13 21 51 57 68 69 70 ... (9 checks) |
| SPRITE_OFF | 56 | 30 | 2 4 5 6 7 8 10 11 ... (58 checks) |
| SPRITE_START | 187 | 29 | 3 4 10 11 13 16 21 28 ... (29 checks) |
| SUBTRACT | 76 | 20 | 1 2 4 7 13 15 18 20 ... (29 checks) |
| SURPRISE | 22 | 4 | 63 71 72 73 81 82 83 84 ... (9 checks) |
| TREASURE | 77 | 7 | 1 25 26 27 64 76 92 |
| WHO | 11 | 2 | 20 58 |
| WRITE_MEM | 2341 | 553 | 1 2 3 4 5 6 7 8 ... (93 checks) |
| WRITE_MEM_BASE_OFF | 17 | 5 | 1 4 18 90 91 |

**Every one of Pool's 61 opcodes now runs in a matching check.** CLOCK was the only one with none (7:17 0x9D37, the
nomads' escorted walks): check 94 is new. The five the Next step named: **LOAD_MON** checks 3, 5, 10, 67-71, 77, 79,
80, 84; **CLEAR_MON** 1, 3, 5, 10, 25-27, 64, 67-71, 76, 77, 79, 80, 84, 92; **SPRITE_START** 3, 4, 10, 11, 13, 16,
21, 28, 30, 41, 43, 51, 54, 55, 57, 59, 61, 63, 67-70, 74, 76, 81-83, 85, 87; **ENCOUNTER_MENU** (GAME.OVR 0x2C3E)
5, 6, 10, 13, 18, 71-73, 77-80, 84, 86; **PARLAY** 6, 54, 59, 71-73, 86. **The fight's end** (ECL 0x6DE3 / 0x6DE6
zeroed, chat 63) runs in every fight check (3, 5, 10, 67-71, 77, 79, 80, 84) but statediff doesn't compare 0x6Dxx
and only the tavern brawl sets them: the brawl check (Combat's placement first) is its check. **LOOK's flag through
the script** (chat 63): 4:21's elf skeleton changes no state either way (text, then PICTURE 255 / EXIT on both
paths): no check; 7:22's corpse (0x4A00) would be one, behind its secret doors.

**CALL by target** (the original acts on 0x2C90, 0x8000/0x8001, 0xBA03, 0xC01E, 0xC018; GAME.OVR 0x3A36):
0x2C90 41 of 114 sites run (checks 3, 4, 5, 10, 12, 13, 16, 17, 18, 23, ...), 0xC018 13 checks, 0xC01B 17, 0xC01E
checks 19 and 38, 0x0806 13 checks. **Not run by any check:** 0x8000 (3:11's duel, 0x9CA6: ready, waits on Combat, below; **chat 65: check 99**);
0x8001 (1:18's buccaneer challenge 0xA9D3, 8:16 0xA344) is run by check 95 (new); 0x2C4E / 0x2C51 / 0xC003 / 0xC009 (7:26
0xAD66-0xAE89 and 8:27 0xAB25-0xAB99, the bands' land-recovery loops: no-ops in the original, chat 24); 0xBA03 (a
sound: nothing to compare).

**ECL CLOCK (GAME.OVR 0x3807) passes no time after a GOSUB.** The handler reads its operand (0x74D3), then pushes
`[bp-1]`, a stack byte it never sets, as the *operand number* to fetch (0x7609: operand slots 1..n at DS 0x7005 /
0x7045 / 0x7085), and calls 0x241A1(that value, 1): add it to clock word 1 (0x49C7, minutes; the carries through
DS 0x363A's limits 10, 10, 6, 24, 30, 12) and tick durations (0x23DCC). So the minutes come from whatever operand slot
the previous handler's leftover byte names, as SPELL's stop flag (chat 62). Pool's only CLOCK (7:17 0x9D37) is
reached only by GOSUB (0x9CF5, 0x9D2D), and there the slot holds 0: **in DOSBox the clock cells stay 10:57 through
the 13 steps to the clearing and the 5 to the lodging** (read live with `ecl_poke.py`), and the party is in camp at
18:57 (the script's WRITE_MEM 18 to the hour). Ours added a minute a step (18:15). `ecl_vm.gd`: CLOCK after GOSUB
passes no time; any other CLOCK keeps its operand (not seen in Pool).

- **Check 94, 7:17 the nomads' feast** (check 13's start, tpseed 11111111): Up, PARLAY, YES to the feast, seven
  PRESS RETURNs (the escorted walks: the clearing at 9,9, then the lodging at 9,12 S), 'HERE YOU MAY REST.', camp
  (PROGRAM 9), EXIT: 9,12 S 18:57 (the original's ENCAMP SAVE after the EXIT). Fails on the code before (18:15).
  Three repeat runs MATCH.
- **Check 95, 1:18 the tavern's drunk buccaneer, CHALLENGE** (check 74's start, tpseed 11111111): DISGUISE, the
  tavern, CHALLENGE, THRENDER GRONE duels the 4th-level fighter (CALL 0x8001, the first check to run it), QUICK:
  **1063 draws identical** (in a duel the original's figure list holds the members set aside: the fighter is its
  figure 6, at 27,12 as ours'), THRENDER GRONE loses. **The original: YOU HAVE LOST THE DUEL. / THE DUELIST RECEIVES
  0 / EXPERIENCE POINTS., the treasure menu (VIEW POOL EXIT), then the script's 0x6DC7 <= 128 branch (THE BATTLE IS
  OVER, THE PATRONS RETURN TO DRINKING.)**: the members set aside stand, so it isn't a lost fight. Ours went on with
  129 (THE BUCCANEER SMILES ...): `main.gd` now ends a lost duel as any fight. Both branches write the same state,
  so the check sees the fix only through the key list falling out of step (THE CREATURES IGNORE YOU, LEAVE: 4,9 N
  11:01); it fails on the code before. Three runs MATCH.
- **PROGRAM by operand** (each opens a different engine screen): 9, camp (check 94; the inn's 3:0 0xA1AD below), 8,
  the closing scene (check 5), **0, the training hall (3:11 0xA049): check 96, new**, from check 21's start with
  THRENDER GRONE's record edited (experience +0xAC = 5000, gold +0x8E = 2000): YES to train, TRAIN, YES, BEGIN
  ADVENTURING. The original: level 2, a d10 for hit points (8: 11 -> 22), the experience cut to 4000 (one level per
  visit), 1000 gp paid from silver and gold (144 sp -> 4, 2000 gp -> 1007); ours the same at once (a coverage check,
  no fix). Three draws identical. Three runs MATCH.
- **Check 97, 3:0 the inn at 6,12** (check 46's start, tpseed 11111111, 20:56): twelve steps by route, STAY? YES,
  WHO WILL PAY? THRENDER GRONE (a platinum piece), camp (PROGRAM 9), REST 8 hours (no interruption roll at the
  inn), EXIT: 6,12 W 05:08; 13 draws identical. A coverage check (matched at once). Three runs MATCH.
- **Check 98, 3:0 the arms and armour shop, a purchase** (check 26's start, tpseed 11111111): YES, DORN selected
  (End x5; the only member with coins), BUY, BUY the hand axe (1 gp: gold 3 -> 2, one item more), EXIT, EXIT. The
  first check with a purchase (26-27 leave without one). A coverage check (matched at once). Three runs MATCH. (A
  `files` list can't be used with an F2 end: ours' quick save writes no CHRDAT files; statediff compares items.)
- **The temple (COMBAT with 0x6DE2 = 1), not a check yet:** 3:0's temple of Tempus (event 24, 2,12): the original's
  cure draws a d8 from the game's dice (OVR:049B0) that ours doesn't, and POOL / SHARE / the retrieve question
  differ (Requests, main -> combat); lab `data/c64/chk_temple` is ready.
- **3:11's arena duel (CALL 0x8000), not a check yet:** draws identical to 1018 of 1486, then ours' copy flees in
  panic where the original's attacks (Requests, main -> combat); lab `data/c64/chk_arena` is ready for when it
  matches.
- **A coverage artefact, not the game:** blocks recorded as 2:20 hold two offsets (0x9926, 0x992C) that aren't
  instruction starts in any Pool block (2:20's 0x9921 is a 6-byte WRITE_MEM); cause not found (no shadow VM in
  these runs). Dev-only (M6 coverage), outside the checks' comparison; left as is.

## Chat 62: ECL SPELL and the character window's record bytes; memorized spells in statediff; the comparison flags; RANDOM 255; checks 90-93, DIFFCHECKS 93/93

Read from the original's ECL dispatcher (GAME.OVR 0x3C73: the opcode in DS 0x6F7F, a near call per opcode; SURPRISE
0x240F, PARTY_SKILL_CHECK 0x236F, FIND_ITEM 0x33B0 and the door's KNOCK 0x16D13 agree with ours).

- **SPELL (0x3949) never clears its stop flag** ([bp-8]): the flag holds what the previous handler left in that
  stack slot. Pool's only SPELL (3:14's cabinets at 14,10, CAST KNOCK, 0x9ECA) follows the menu's ON_GOTO, whose last
  call pushed a jump target's high byte there (never 0), so the loop never runs and SPELL answers place 1, member 0:
  **the first member "casts a Knock spell and opens the lock" whoever has Knock, even when no one does, and no spell
  is spent.** Seen in DOSBox with three parties (Knock on the second member; no Knock; the first member holding two
  other spells): THRENDER GRONE casts every time, every spell kept. Ours answered "NO ONE IN THE PARTY HAS THE KNOCK
  SPELL!" or named the holder and spent his Knock. (With the flag clear the loop would read only the first member's
  record bytes 0x18..0x69 and count one past him; not seen.)
- **The character window's 0x20-0x70 is the record's bytes** (the write, 0x7F6C: record byte = offset - 8, and the
  cell too; the read 0x7C9F has no case for them: a plain cell). Ours had 0x21.. as the memorized list from its top,
  so SPELL's follow-up write (0, at 0x6B21: record 0x19) took a spell away. 6:19's on-rest writes 0x6B32 (record 0x2A,
  a memorized byte) but the dragon's den sends the party straight back to the band: no rest happens there.
- **statediff compares each member's memorized spells** (record 0x17..0x2B, sorted: where they sit isn't compared, as
  ours keeps no gaps). All 89 earlier checks still match; the deliberate-break test rerun at 89 checks: SUBTRACT
  80/89, ADD 88/89.
- **PARTY_STRENGTH (0x200C) adds into a byte** (wraps past 255; ours capped). Not reachable with Pool's parties; no check.
- **The comparison flags** (DS 0x6F78-0x6F7D, EQ NE LT GT LE GE; the IFs 0x1898 test one each): COMPARE (0xE6C)
  sets all six from its two numbers (0x8DBE, the first against the second: ours' `compare = a - b` holds); **AND and
  OR (0x1B35) compare 0 with the result**, so after them IF_GT is never true, IF_LT means "not 0", IF_LE always,
  IF_GE "0" (ours had "not 0" for GT and GE); **COMPARE_AND (0x1833) and FIND_ITEM (0x33B0) clear the six and set
  only EQ or NE**, so the other four IFs are false after them (`compare_eq_only`). In Pool only one script tests an
  AND with anything but IF_EQ / IF_NE: **3:14's rugs and tapestries (14,14, 0xA274: AND 4, [4A47]; IF_GT; GOTO
  leave): the original shows them and their treasure on every visit** (DOSBox: bit 4 set, LOOK, the treasure again);
  ours left once the bit was set.
- **RANDOM's top is a byte raised by one only below 255** (0xF7A): RANDOM 255 is Random(255), 0..254; ours rolled
  Random(256). Pool's one RANDOM 255 is New Phlan's taverns (3:0 event 20, 0xA328: 25 or less, a pickpocket), and
  with the original's dice the two part on most seeds (Turbo Pascal's Random(n) is the high word mod n).
- **Check 90, 3:14 the three cabinets, nobody with Knock** (a save from the original's own walk there: check 43's start
  with 0x4AB2 = 1, doors bashed, THRENDER given memorized spells 5 and 21): LOOK, A, CAST KNOCK, LEAVE: 0x4AEA = 1, the
  spells kept. Fails on the code before (ours refused, then LEAVE: 12 differences).
- **Check 91, the same with BAKSHI holding Knock**: THRENDER casts, BAKSHI keeps it. Fails on the code before (BAKSHI's
  memorized spells: ours spent the Knock), with the new statediff.
- **Check 92, 3:14 the rugs again** (a save of the original at 14,13 S after a first visit, 0x4A47 = 4): Up, the rugs'
  text and treasure, EXIT, NO, Down, Up: 14,13 N 11:35. Fails on the code before (ours left at once; the later keys
  opened camp).
- **Check 93, 3:0 the tavern at 15,10** (check 46's start, tpseed 62620001, chosen so the two part at 25): Random(255)
  gives 6, the pickpocket (ROB 1, 20, 5), IGNORE, NO, TAVERN TALE 17; 22 draws. Fails on the code before (59: no
  robbery). (Consecutive seeds, and the golden-ratio spread, kept landing just above 25: pick seeds by computing the
  draw.)

## Chat 61: the wall ahead in statediff; checks 75-86 (2:20 the Down key, 6:1 the seedy little man's ROB 0, 1:18 the plaza's fights and FLEE, 5:4 the scribe, rests in 2:20, 3:0, 8:13 and 3:14, a band PARLAY, a dying member outside fights), DIFFCHECKS 89/89

- **The wall ahead joins statediff.** The original's save keeps ECL 0xC04E (DS 0x6AB0) at byte 0x3204; statediff
  now compares it in a 3D area (`wall ahead (0xC04E)`). On the code before chat 61, **13 of the 74 checks differed
  there** (41-46, 48, 49, 57, 59, 71-73): ours wrote the square's own wall at every position sync. The original
  writes it only on a step (0x16E71: the new square's wall; at an edge the wrapped square on the map being left), a
  turn (0x171AE, 0x171F5, 0x1723A), CALL 0xC01E (0x8F33, with the square's byte at 0x8F1F) and CALL 0xC018 in a 3D
  area (0x3B12), and a LOAD reads it back from the save (DOSBox: check 71's start reads 0 after loading; after Up
  2:20's patrol script put the party on 3,4 with the 0 of the step onto 14,6). Ours now does the same (`main.gd`
  `_write_wall_ahead`, `_script_wall`; `ecl_vm.gd` CALL): 74/74 with the comparison on. The deliberate-break test
  was rerun (statediff changed): SUBTRACT 66/74, ADD 73/74 (check 18). No arrival that shows it on screen found: the
  Slums' two gates into New Phlan (15,4 and 15,12 east) land on events 25 and 24, not 3:0's night locked-door
  squares (event 0 with wall 9, 4 with 7, 26 with 11).
- **Check 75, 2:20 the Down key** (check 71's start, tpseed 11111111): Up (the arrival: 3,4 S), Left (E), Down, Up
  into the wall. **Found:** the original's Down turns the party round where it stands (GAME.OVR 0x17187, scan code
  0x50: the facing + 4 of 8, the wall ahead read again, no sound; DOSBox 3,4 E -> 3,4 W); ours stepped backwards.
  Two d14 identical. Fails on the code before chat 61 (3 differences).
- **Check 76, 6:1 the seedy little man** (event 6 at 2,11; `mksave.py J G 6 1 2 12 N 49F2=1`, tpseed 11111111): BUY
  PASS: `ROB 0, 25, 0`, the selected member only (two d100 for THRENDER's two items, 70 and 38: nothing taken; his
  coins at 25), the pass as treasure, TAKE, TAKE, EXIT. **Found:** the original's LOAD keeps 0x49F2 as saved (DOSBox:
  a jump save in 2:20 holding 1 reads 1 after loading; check 74's reads its 20); ours wrote the block after the
  load's init, so 6:1's init placed the party at the gate. Fails on the code before (12 differences).
- **Check 77, 1:18 the plaza, STRIDE BOLDLY FORWARD** (check 51's start, tpseed 5151000a from a 40-seed search in
  ours): THE MONSTERS STAND READY at once, COMBAT, QUICK: goblins, **1866 draws identical**, BAKSHI falls,
  CONTINUE BATTLE NO, the treasure left. MATCHes on chat 60's code too (guards the fight). PARLAY there plays the
  same fight, draw for draw (no check); WAIT shows the menu again with no draws in both.
- **Check 78, the same encounter, FLEE**: THE PARTY RUNS AND ESCAPES to 9,4 W (a d4 and a d8), 0x49FB = 1 (no
  square on the place line). Five draws identical.
- **Checks 79 and 80, the plaza's STRIDE with seeds 5151001c (ogres, 1292 draws identical, RHIANNON falls) and
  51510026 (orcs, 1320, BAKSHI falls)**; HP and status member for member as the original's.
- **Checks 81-83, 5:4 the records building's scribe** (check 23's start, tpseed 54540005: the reading's d19 under
  3): RUN AWAY (AN ALARM STARTS RINGING!, 0x4A62-0x4A64 from the clock, put back on 15,8 N), AMBUSH AND KILL HIM and
  AMBUSH AND TIE HIM UP (each PRESS BUTTON OR <RETURN> TO CONTINUE as written, then NO to reading); four draws
  identical each. 82 and 83 write no flags: they guard the vertical menu's routing.
- **Check 84, 2:20 a rest interrupted** (check 71's start, tpseed 20200001): the rest's first d100 (21) interrupts at
  12:56, ANGRY GOBLINS, COMBAT on QUICK: **1864 draws identical**, 3,4 S 13:02.
- **Check 85, 3:0 a rest in the street** (check 46's start, tpseed 30300001): 3:0's rest odds are 101, so every rest
  there is interrupted (21:01): ROUSTED BY THE CITY WATCH, GO. Two draws identical. STAY (the watch's fight)
  destroys check 46's party in ours: not a check.
- **Check 86, 8:27 a band encounter's PARLAY** (check 31's start, tpseed 31310016): kobolds, PARLAY, HAUGHTY: a d31,
  back on the band with no text (every attitude the same in ours). Seven draws identical. COMBAT, WAIT and FLEE
  there go to the fight, which parts at the wilderness clutter (below).
- **Check 87, 8:13 a rest interrupted by the kobolds' rocks** (check 42's start, tpseed 61610001): ECL DAMAGE on
  every member, two pages, 11:01; PHINEAS (4 HP) hit for 5. **Found:** the original's save has him **dying** (status
  5, 0 HP); ours made him unconscious. The original's damage routine (START.EXE 0xBA:0x2228, from GAME.OVR 0x96BF)
  follows the fight's rule (ours' `combat.gd`): 0 HP unconscious, below 0 dying, more than 9 below dead; ours'
  `ecl_vm.gd` `_hurt` now does too. That moved check 69 (the priest's fireball fells DIRTEN before the fight): the
  original's save after the fight has him at 4: **a fight's end turns every dying member unconscious, one down before
  the fight too** (its figure list holds the whole party); `main.gd` `_on_event_fight_finished` now does (Combat's
  `finish()` covers the fighters). 25 draws identical; fails on the code before.
- **Check 88, 3:14 a rest interrupted by three thieves with slings** (check 43's start, tpseed 61610001): DAMAGE's
  volley form (a random member and a d20 to hit per bullet), PHINEAS hit for 4 and 3 at 4 HP: dying. 12 draws
  identical; fails on the code before.
- **Check 89, a dying member outside fights** (check 88's end as the start, six LOOKs: an hour): the original's save
  still has PHINEAS dying at 0 HP (no bleeding outside fights), as ours. The damage routine read in START.EXE
  (0xBA:0x2228, image 0x2DC8): HP at or above the damage drops (0: unconscious); short of it the excess decides (over
  9 dead, else dying, the bleed count set in a fight); an ANIMATED member at 0 dies; the down keep HP 0. Ours kept a
  negative HP on a member a script killed outright: now 0. **Open (to Combat, Rule changes):** a member left dying by
  a script bleeds from 0 in ours' next fight; the original sets the count only inside a fight.
- **Not a check yet: a band fight** (8:27, check 31's start, tpseed 31310016: YOU SPOT A GROUP OF KOBOLDS, COMBAT;
  c34d's party): parts at the field's setup, the wilderness clutter (GAME.OVR 0xD3A1: a d100 of 0 at 0xD3AC, then
  a d10 at 0xD3BF; ours, the dungeon rule, draws the next cell's d100), Player 21's open request (a) to Combat. The
  original's trace (from draw 7: the step's six ecl draws came before the reader attached; 7973 to CONTINUE BATTLE)
  and its ENCAMP SAVE are in the lab (`data/c61/kobold_orig.txt`, `data/c61/kobold_band/orig`): a check once the
  clutter lands. **The trace hook blocks the game when its buffer is full and no reader runs** (after ~7980 draws
  the original froze at CONTINUE BATTLE until a second `trace.py run` drained it): give a long fight's reader time.
- **Also fixed, from the original's walking-key routine (0x17060):** AREA where 0x49FB is set prints NOT HERE on row
  24 and opens no map (0x170B3); CAST does nothing when the selected member isn't OKAY (0x170FC; DOSBox: status 4).

## Chat 60: checks 72-74 (2:20 a patrol's SURRENDER and PAY, 1:18 the tavern: ROB as the original), DIFFCHECKS 74/74

- **Check 72, 2:20 a slums patrol, SURRENDER** (check 71's start and tpseed 33330018; lab `data/c60/chk72/`): Up,
  YOU SPY A GROUP OF SEEDY-LOOKING KOBOLDS, PARLAY, HAUGHTY, SURRENDER: THE MONSTERS ROB AND BLINDFOLD YOU (`ROB 1,
  100, 100`), PRESS RETURN, the random spot (0xB225: 11,2 N in both). 23 draws identical (14 d100 at GAME.OVR 0x9337,
  one per item). **Found:** the original's item loop (0x92C3) is called once per member with the chance as a
  parameter, so the cut after a heavy item (-90 over 255, -50 over 24) lasts only for that member's items; ours
  lowered one chance for the whole party, so after THRENDER's banded mail nobody lost anything. Fails on the code
  before chat 60 (BROTHER SEAN's mace, DARKSTAR's and PHINEAS's darts and dagger).
- **Check 73, the same patrol, PAY 99 gp** (`data/c60/chk73/`): THEY PAW THROUGH YOUR COINS AND LEAVE (`ROB 1, 50,
  0`); DARKSTAR's darts go on a d100 of 48. **Found:** the original's ROB handler (0x2AF7) reads operand 2 twice
  (0x7609 with 1, 2, 2): the items' chance is the coins' percentage and the third operand is never read. Ours now
  does the same (`ecl_vm.gd` `_rob`); every ROB in Pool whose two numbers differ takes items more or less often than
  the script's third number says (1:18 `ROB 1, 100, 50`; 2:9 `1, 100, 20`; 3:0 `1, 20, 5`; 6:1 `1, 75, 50`, `1, 75,
  10`, `0, 25, 0`; 6:28 and 8:13 `1, 100, 255`; 8:13 `0, 20, 20`, `1, 25, 10`). 20 draws identical. Fails on the
  code before chat 60.
- **Check 74, 1:18 the tavern** (event 2 at 4,8; `mksave.py J G 1 18 4 9 N 4AB0=1`, tpseed 11111111;
  `data/c60/chk74/`): DISGUISE, north onto 4,8: A DRUNK BUCCANEER, BRIBE, YES (`ROB 1, 10, 10`: 14 d100, nothing
  under 10), the creatures ignore you, DRINK HEAVILY: put on 2,10 S, `ROB 1, 100, 50` (at 100 per member in the
  original). 28 draws identical. Fails on the code before chat 60 (5 differences: ours robbed at 50 for the party).
- **Also found:** a script's one-choice menu reading exactly `PRESS <RETURN> OR BUTTON TO CONTINUE` is shown as the
  game's `PRESS <ENTER>/<RETURN> TO CONTINUE` (MENU_HORIZONTAL, GAME.OVR 0x1E5A; the other wordings as written): ours
  now does the same (fbdb7fe; display only).
- **The stale wall ahead after a real arrival (the standing question): answered.** The original's ECL reads of
  0xC04B-0xC04F (GAME.OVR 0x82DF, 0x83C4) are DS 0x6AAD (x), 0x6AAE (y), 0x6AAF / 2 (facing), 0x6AB0 (the wall
  ahead) and 0x6AB1 (the square's byte). The arrival (0x3EFA: init, on-move, event) refreshes 0x6AB1 only; 0x6AB0 is
  written by a step (0x16E71: the new square's wall, on the old map with the coordinates wrapped at an edge), a turn
  (0x171AE, 0x171F5, 0x1723A), CALL 0xC018 (0x3B12, when 0x49FA = 1) and CALL 0xC01E (0x8F33). So after a NEW_ECL
  arrival or CALL 0x2C90 the wall ahead stays the last step's: check 49's original save (the boat to New Phlan
  15,1 E) holds 1, the band's, where New Phlan's wall there is 14. Ours writes the new square's wall on every sync.
  Scripts reading 0xC04E: 3:0's on-move (the night locked door, after 14:00 on an event-0 square: 0x997E), 5:5's
  hedge, 6:1's slave pen, 7:17's camp. Not changed yet (main, open): no case found where an arrival shows it.
- PAY with 0 gp (the cheapskates, then the fight) plays check 71's fight draw for draw in ours (1109, INPUT_NUMBER
  draws nothing): not made a check (it would repeat 71).

## Chat 59: checks 68-71 (5:6 the priest of Bane: KILL THEM, ACCEPT BLESSING, LEAVE; 2:20 a patrol's RUN: fight checks), DIFFCHECKS 71/71

- **Check 68, 5:6 the priest** (check 25's start with 0x4A69 bit 128 cleared: c34d's party had cleared the temple;
  lab `data/c59/chk68/`): tpseed 11111111, Left, Up, Up, Left, Up, PRESS RETURN, A PRIEST AND TWO ACOLYTES ..., KILL
  THEM; everyone on QUICK. **966 draws identical, every figure's cells** in both games (the original re-traced by hand:
  boot J, `trace.py install`, `seed.py set`, the keys, `presser.py 280 noenter`), since Combat 25's a93a0d0 (DORN's load
  tested signed: chat 57's parting at 940). CONTINUE BATTLE NO, THE PARTY HAS WON, 450 XP each, the treasure's EXIT,
  THERE IS STILL TREASURE LEFT NO; the original's ENCAMP SAVE J; DIRTEN at 0 HP. **MATCH.** It also MATCHes on the
  code before a93a0d0 (the parting at 940 changed only moves, not the end state), so it guards the fight's outcome, not
  that draw.
- **Check 69, the priest's ACCEPT BLESSING** (check 68's start and seed, A): the blessing's DAMAGE page by page (a d10 and
  a d7 per member, DIRTEN twice), THE PRIEST SHOUTS ... A FIREBALL EXPLODES (15 each: DIRTEN down before the fight), 13
  Enters in all (ours pages the fireball's lines as the original), QUICK. **981 draws identical, every cell.** The
  original numbers the downed DIRTEN as figure 6 (30,14), ours lists him apart (`downcell`), so cmpdraws' "positions"
  lines name figures 6-8 differently: the cells agree. **MATCH.**
- **Check 70, the priest's LEAVE** (L): the fireball first, 5 Enters, QUICK. **1164 draws identical, every cell**;
  CEDRIC falls; at CONTINUE BATTLE the original holds him dying (status 5, `partyrec.py`), ours 4; both saves 4, HP 0.
  **MATCH.** (Q4: a win with a death; the check guards the state, not the verdict.)
- **Check 71, 2:20 a slums patrol's RUN** (guards chat 57's PARTY_CHECK change): check 17's start; the seed found in
  ours (a batch run: `load=G,tpseed=<s>,Up,wait,wait` for 60 seeds in one run, 8 s): tpseed 33330018 meets SEEDY-LOOKING
  KOBOLDS on the first step (0x9B3A's d13 above 12; 0x9D58's menu). PARLAY, HAUGHTY (0xB2A1's 10 + d30 + [6DCF] lands
  in 75-85): PAY / SURRENDER / RUN / FIGHT; RUN: 0xB488 `PARTY_CHECK [6C1B], 0, [6E81], [6E79], [6E79], [6E79]` leaves 0
  in [6E79] (operand 6 written last), [9805] is above it: the fight (0xB157). QUICK: **1109 draws identical, every
  cell**; BAKSHI down; CONTINUE BATTLE NO, 9 XP each, the treasure's EXIT, NO: 3,4 S 10:58. **MATCH; 8 differences on
  the code before 6b2428f.**

## Chat 57: PARTY_CHECK's cells (Player 22's (d)), checks 65-67 (3:14 a door trap, 5:3 Cadorna's cell, 1:18 a rest interrupted by a fight: the first fight check), DIFFCHECKS 67/67; two fights compared draw for draw

- **ECL PARTY_CHECK** (opcode 0x1E, GAME.OVR 0x217B; its writer 0x211D): operands 3, 4, 5, 6 get the party's worst,
  best and average and 0 (a field), or 0, 0, an unset stack byte (left alone in ours) and the effect flag (field 0).
  Two fields only: [6BA7] (record +0x79, find / remove traps) and [6C1B] (record +0x11C, movement); any other writes
  nothing. Ours wrote 0, the average, the best, the worst. The scripts: 3:14's B3A2 (every Kovel trap: d100 under
  [6E7A], now the best, finds it; the disarm uses it too), 2:20's RUN at PAY / SURRENDER / RUN / FIGHT (0xB488:
  COMPARE [9805] (the monsters' movement) with [6E79], 0 in the original: RUN goes on to 0xB157, never away), 3:14's
  and 8:13's Find Traps tests (field 0). `ecl_vm.gd` `_party_check`.
- **Check 65, 3:14 a door trap** (`mksave.py J G 3 14 11 9 S`, tpseed 2222224b): south onto 11,10 (event 3 ->
  0x99D6 -> B3A2): d100 = 21 under the best find-traps (28-32 with this party; the average far lower): YOUR PARTY
  DETECTS A TRAP, AVOID TRAP (0x4A13 = 1). **MATCH on 6b2428f; 3 differences on the code before** (the blade fell:
  0x4A00 = 1, RHIANNON's HP).
- **Check 66, 5:3 Porphyrys Cadorna's cell:** 5:3's init picks its map by 0xC04D ([3,5,5,3] at 0x9C24, DAX block data
  2 bytes in), so the cell is map 5's 14,10 (value 178, & 31 = 18 -> table 0x9B99 -> 14 -> 0xAFD5). It needs 0x4A66
  bit 2 clear and 0x4A6B bit 8 set (16, 32 clear). Start: `mksave.py J G 5 3 14 11 E 4a6b=8`, ours took the jump and
  ENCAMP SAVEd (H, renamed G). tpseed 11111111, Left, Up through the door; PRESS RETURN; KILL ('WAIT!...' 0x6E7C bit 1),
  LEAVE ('...I'LL RAISE THE ALARM' bit 2), RELEASE, TAKE ME WITH YOU? YES: 0x4A6B = 24, 0x4A66 = 2, the party back on
  14,11 turned round (0x9C4B). **MATCH.**
- **Check 67, 1:18 a rest interrupted by a fight (the first fight check):** check 56's start, ENCAMP REST eight hours,
  the plaza's rest entry at 13:16 (0x9960: 0x9F86's d8 picks orcs, COMBAT), everyone on QUICK, CONTINUE BATTLE NO, PRESS
  RETURN, the treasure's EXIT, NO: 12,8 E 13:18. **Draws compared first** (`cmpfight2.sh G 11111111 ""
  "up,e,r,h,i,i,i,i,i,i,i,i,r"`, OSECS=240): **1290 draws identical, every figure's cells, the same end.** Chat 55's
  "ours won in round 2" was the harness: `quickall,fightend` reached ours while the party still rested; ours' keys wait
  eight times first. **MATCH**, three repeat runs too.
- **5:3's awake giants** (check 63's start, tpseed 22222222, SEARCH on, west: the bucket, PRESS RETURN, THE GIANTS ...
  CHARGE!, COMBAT, PRESS RETURN): **1041 draws identical, the party destroyed in both.** No end save (the game ends):
  not a check.
- **5:6's priest** (check 25's start with 0x4A69 bit 128 cleared: c34d's party had cleared the temple; tpseed 11111111,
  Left, Up, Up, Left, Up onto 1,2, PRESS RETURN, KILL THEM): the party wins in both, the same end (CONTINUE BATTLE, HP,
  DIRTEN at 0), but **the draws part at 940 of 966**: at DORN's turn the original draws a d8 at GAME.OVR 0x0AC3A and a d4
  at 0x0AC63, ours the d4 the others drew at 0x0AC2B (BRAM, LIRA move further in the original after it). To Combat
  (board). Not a check until it matches. The original's trace: lab `data/c57/priest_orig.txt` (the presser never saw QUICK
  on row 24 here, so CONTINUE BATTLE was answered by hand; `partyrec.py ARN ... DIRTEN` for the end).
- **The gate is DIFFCHECKS 67/67** (~80 s).

## Chat 56: Q24 (a script's menus of two or more choices: the letters only), checks 62-64 (6:19 / 6:25 Q24, 5:3 the sleeping giants, 4:10 the marble chest), DIFFCHECKS 64/64; diffcheck.sh's no-save guard

- **Q24 (Jeremy, 2026-11-18): the original's keys only.** GAME.OVR's menu routine 0x8B57 (shared by MENU_HORIZONTAL
  0x1E17, PARLAY 0x3311 and ENCOUNTER_MENU 0x2C3E) reads a key; 0x0D is taken only when its argument [bp+8] is set,
  and then gives choice 0 (the first, never a lit one). MENU_HORIZONTAL sets it for a one-choice menu (0x1E5A:
  PRESS <RETURN>), PARLAY (0x3370: push 0) and ENCOUNTER_MENU (0x2F18: push 0) never. Ours (`main.gd`
  `_unhandled_input`): a script's horizontal menu of two or more choices takes its letters (digits too, ours' fallback
  where two choices share a first letter: the original builds distinct highlight letters, 0x8A40) and the mouse;
  Enter, keypad Enter, Space and Left / Right do nothing. One-choice, vertical and WHO menus keep Enter.
- **Check 2's keys:** Enter (ENTER CAVE) and 2 (IGNORE CAVE) became E and I, the original's keys; resealed. With Enter
  ignored ours had stayed at the menu and ended with 0x4A87 = 1 (the original 3).
- **diffcheck.sh: a run that never saved is a difference** ("no save: ours.cfg unchanged by the run"). Check 2's start
  cfg was an end-like state at the cave: a run ending in camp (F2 doesn't save there) compared equal to the original's
  end. Every check saves (64/64). Break test at 61 with the guard: SUBTRACT 54/61, ADD 60/61.
- **Check 62, 6:19 / 6:25 (Q24):** check 2's start and the original's end; at ENTER CAVE / IGNORE CAVE Right, End,
  Enter, keypad Enter (nothing), E; the dragon's two pages; at the menu again Right, Enter, keypad Enter, I. Its start
  cfg is check 32's. **MATCH on 9f5b101, 15 differences on 18c3cd1** (the old code took IGNORE by Right + Enter and
  then camped on E). The original's end is check 2's: the ignored keys weren't replayed in DOSBox (the routine above
  and chat 53's DOSBox observation).
- **Check 63, 5:3 the sleeping giants:** `mksave.py J G 5 3 2 7 W`'s jump drops the original to DOS (as chat 40's
  into 5:3), so ours took the jump and saved (ENCAMP SAVE H, renamed G), as check 24's start: 2,7 W 10:56, the hour
  under 14 (four giants). tpseed 11111111, west onto 1,7 (its map value 39, & 31 = 7: 0xA51F): the surprise roll (0x9914:
  PARTY_SKILL_CHECK, SURPRISE) gives AS YOU ENTER THE ROOM YOU SEE SOME SLEEPING GIANTS in both; Enter (nothing),
  SNEAK OUT QUIETLY: back on 2,7 facing E (0x9C4B). **MATCH.** Seen (display): the original's position line keeps
  "W" after SNEAK OUT until the screen is redrawn (the camp shows E); ours shows E at once. The awake branch
  (seeds 22222222, 33333333, 60606063 with SEARCH on: the bucket kicked aside, THE GIANTS ... CHARGE!) ends in a
  fight on every choice, FLEE included: left for a fight check.
- **Check 64, 4:10 the marble chest:** check 12's real start (12,5 N; a jump into 4:10 lands at 0,4 E) with cells set
  in the start save, read by both games: 0x4AF2 = 10 (the giant skeleton beaten), 0x4A01 / 02 / 03 / 07 = 0 (the
  skeleton, zombie and wight squares quiet), 0x4A43 = 251 (the crypt at 12,4 done). 37 steps (route.py) to 6,6 E,
  SEARCH on, east onto 7,6 (event 5, 0x9DDC: 0x4AF2 over 9, 0x6DCA = 1): YOU FIND A MARBLE CHEST. OPEN IT? Enter
  (nothing), YES: THE PARTY HAS FOUND TREASURE, 5095 experience each, the treasure screen, EXIT, NO (leave the rest):
  0x4A49 = 255, 7,6 E 11:41 (the searched step ten minutes). **MATCH.**
- **The gate is DIFFCHECKS 64/64** (~75 s).

## Chat 55: checks 51-61 (1:18, 7:23, 1:24, 2:15, 6:28, 1:18's rest, 3:8, 5:7, 4:2, 5:4, 5:5), DIFFCHECKS 61/61; an arrival's square event after its on-move, the previous square after a step that leaves the area

- **Check 51, 1:18 Podol Plaza** (`mksave.py J G 1 18 12 8 E 4AB0=1`): PLAZA AHEAD: DISGUISE (0x4A35 = 1), then the
  square's event: 12,8's d25 (YOU SPOT A GROUP OF GOBLINS ... LAUGH TO THEMSELVES AND WALK ON), the shrine at 13,8, the
  robed orc at 14,8: GREET, NO (escorted out to 13,8: 0x4A38 = 1, 0x4A19 = hour + 2), back onto 14,8 (nothing).
  **DIFFERS on ab4d271** (4 differences: ours ran no event after the arrival's menu), **MATCH on 70cfcd3**.
- **Check 52, 7:23 Yarash's pyramid** (jump to 5,1 N): the dial at 5,0, CHANGE THE SETTING? YES, COPPER (0x4A50 = 1);
  back to 5,1, SEARCH on, Yarash's desk at 6,1: five journal entries (0x4A52 bits 64, 128). MATCH.
- **Check 53, 1:24 on map 31** (jump onto the hay beds 10,14 W, 0x4A44 = 2): SEARCH THE BEDS (nothing), 9,14 and a bump
  west (a d60 each), 9,15 (the beds again: 0x4A0A = 1, nothing). MATCH.
- **Check 54, 2:15 Mendor's library** (jump onto 11,12 W): the mad fighter, PARLAY, NICE (a d4 scream), invite YES,
  insist YES: MAD MAN joins (NPC_ADD 25). **DIFFERS on 70cfcd3** (0x49F1: ours wrote the jump step's square 14,5, the
  original keeps the save's 14,4), **MATCH on d1279ef**.
- **Check 55, 6:28 Zhentil Outpost** (jump to 6,0 W): the init puts the party on 7,0 S at hour 0, the escort and the
  guard's tour (nine texts), the quarters at 5,0, east and back: WALK AROUND. MATCH.
- **Fixed: an arrival's on-move that stops (a menu) or prints is followed by the square's event** (GAME.OVR 0x3FFF
  on-move, 0x400E [0x49E5] unless 0x442F, a NEW_ECL): ours ended the arrival with the on-move's menu.
- **Fixed: a step's previous square is written after its on-move, and not when the on-move leaves the area**
  (GAME.OVR 0x4199 on-move; 0x41A1: 0x442F set, the arrival, then 0x423B; else 0x41B9-0x41CE write 0x6AAD/0x6AAE to
  ECL cells 0x49F0/0x49F1). Ours wrote it before the on-move.
- **Check 56, the first rest** (1:18 12,8 E, a jump save: the plaza's rest odds 2, encounter 16): ENCAMP REST two
  hours: twelve interruption rolls in ours, none hit; 12:56 in both. MATCH. (Eight hours: interrupted at 13:16 by
  orcs in both; the fight not compared draw for draw, so not a check.)
- **Check 57, 3:8 City Hall** (jump to 4,5 S): the council guard at 4,6, DO YOU LEAVE? YES (4,5 N); ENCAMP REST two
  hours: interrupted at 11:02 in both (City Hall's rest entry: 0x6DD2 = 1, 0x6DD3 = 101, the guard again), YES. MATCH.
- **Check 58, 5:7 the trap door** (jump onto 8,5 N): OPEN IT? YES, WHO WILL OPEN IT? THRENDER GRONE, the d20 + 1
  against his record: he looks away; JUMP THROUGH? NO. MATCH.
- **Check 59, 4:2 the chained man** (jump onto 2,15 N): FREE: UNLOCK (no key), PICK LOCK, BREAK CHAINS; PARLAY NICE;
  LEAVE. MATCH.
- **Check 60, 5:4 the kitchen** (check 23's start: the only way in is from 15,8): TALK TO THE OVERSEER twice (the
  boiling oil: DAMAGE, four d6/d7 and a d20), KILL THE OVERSEER (no fight): the paper's runes, the hedge maze's
  password, 0x4A66 bit 128. MATCH. From a jump save the original quit to DOS at the runes' press: a jump-save artifact.
- **Check 61, 5:5 the tower giants** (check 28's start and walk): NO at the argument, the laughter, STAY / LEAVE:
  LEAVE (9,11 W). MATCH.
- Break test at 51: SUBTRACT 47/51, ADD 50/51; at 61: SUBTRACT 55/61, ADD 60/61.
- Jump saves: `mksave.py J G ...` reads lab slot J: put the pristine J back first (`data/c50/slot.py
  data/c48/slotJ_backup J game J`); 52-54's starts were made from 51's (0x4AB0 = 1 in both games' start, no effect).
  A jump save's patched 0x49F2 survives the original's load (6:28's init then skips its placement), ours writes the
  block on load: only a jump save can tell the two apart (a real save holds its own block there).
- Driving the original: a key pressed while the original walks the party (6:28's tour) can be dropped; ours' replay
  waits for idle, so the key list counts one Enter per text.

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


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
  Next chat: drop the second restore (keep the square), re-run checks 1-10 to see nothing else moves. Also **0x4AFA-0x4AFF**:
  ours writes the last dungeon's wall sets in a wilderness save, the original 0 / 255 (they are read back on a load).

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


# The original player (Player lane)

Plays the **original** Pool of Radiance (DOS, GOG copy) in DOSBox Staging by program: reads its memory, sends a
key only when it waits for one, follows a plan, records. Method: ai-business-ideas `plans/player-lane.md`.
Owned by the Player lane (Gold Box Player N).

## Lab

- Lab folder `~/gbr/player_lab` (`OP_LAB`), copied from the main lane's `~/gbr/lab` (its tools, `font.json`,
  `wheel.json`, DOSBox Staging, `re/start.img`, a copy of the game in `root/POOLRAD`, Godot). Never writes into
  `~/gbr/lab`. Saves, logs and DOSBox's files stay in the lab; checkpoint saves in `$OP_LAB/.lab/player/saves/`
  (game data: never in a repo).
- Its own virtual display `:97` (`OP_DISPLAY`; main uses `:99`) and its own pids (`$OP_LAB/run/*.pid`): `orig.py
  stop` stops only this lab's DOSBox and Xvfb, never another lane's (the lab's `pl.py stop` kills every DOSBox).
- Pinned versions (every run logs them): GOG Pool of Radiance (START.EXE md5 `4c28d37e6d94930e865dd59b528f4cfc`,
  GAME.OVR md5 `2ac38b4b35a33dafd375b76957463804`, the same as the Windows `Pool of Radiance/POOLRAD`); DOSBox
  Staging 0.83.0 (7b400); `por.conf`: machine svga_s3, core normal, **cpu_cycles 15000 (fixed)**, nosound,
  640x400 window, aspect off.
- `ptrace_scope` must be 0 (`/proc/<pid>/mem` is read and written).

## Files

| file | what |
|---|---|
| `orig.py` | start/stop this lab's DOSBox; `Mem`: the original's memory (linear, DS, far, ECL words, the dice seed) |
| `hooks.py` | the key-wait hook (below) and `Locator` (a caller's address -> START.EXE image or GAME.OVR file offset) |
| `game.py` | `Game`: wait kind, screen rows, party, area; `settled()` (waits for an input wait and a still screen); `press()`; `boot()` |
| `screens.py` | which screen is up (from the wait site and the screen's text and colours) |
| `plans.py`, `plans/` | area plans (format in `plans.py`); dialogue answers come from main's `tools/plans/playthrough.plan` |
| `player.py` | the driver: `player.py run <plan> --save=G --seed=<hex> --run=<id>` |
| `watchdog.py` | supervisor: heartbeat (the run's log growing, DOSBox alive), restart from the last checkpoint, stop after three restarts at one |
| `twice.sh` | repeatability: one plan, save and seed twice (each under the watchdog), checkpoints compared with `cmpsaves.py` |
| `cmpsaves.py` | two of the original's saves byte for byte (ECL addresses named) |
| `segment.py` | segment check: the original's keys between two checkpoints replayed in ours from the first save and seed; `statediff.gd` at the second |
| `explore.py`, `memdiff.py` | lab tools: press keys and show each wait; find state bytes by DS snapshots |

## A run

`player.py run plans/pilot_1-18.plan --save=G --seed=12345678 --run=p1b` (or under `watchdog.py` with the same
arguments). Boot: a fresh DOSBox, the hook, title -> LOAD -> the save (the code word answered whenever asked);
then the game's speed setting is set to 0 (DS:0x49E2, x 225 ms a message: delays only, no dice; logged) and the
seed (DS:0x4428). Every key is logged with the area, square, facing, seed, wait site, row 24 and the reason;
`logs/<run>.log`, `logs/<run>.summary.txt` (the short numbered summary), `logs/<run>_screen_<kind>.png` (the first
of each kind of screen). Checkpoints: ENCAMP, SAVE, slot H (`OP_SLOT`), **NO to QUIT TO DOS** (asked after every
save), EXIT; the save and its character files copied to `$OP_LAB/.lab/player/saves/<run>/<name>/` and one line in
`index.txt` there:

    pool <set>:<block> <x>,<y> <facing> | <checkpoint> | flags <ECL addr>=<value> (non-zero, 0x4A20-0x4AFF) | party <name> L<levels> <hp>/<max> ... | seed <hex> | key <n> | run <id> | <dir>

Stops (with the reason in the summary): a screen no rule answers, the party destroyed (a loss), the same key 20
times on an unchanged screen, no goal done in 300 keys, 60 s with no input wanted and no dice drawn.
**A stalled fight** (Player 2): while a fight plays itself the heartbeat (every 30 s while dice are drawn) logs
`BEAT figures <n> standing <n> hp <sum>` for the whole fight list (the party, then the monsters); when no figure's
hit points or status change for `OP_STALE` seconds (default 600) the run stops with "stalemate: ..." and the
monsters still standing. A boot that meets a screen it doesn't know (the original refusing a save: "Unable to load
wallset in LoadWallSet.") stops with the screen's text and `logs/boot_stop_<time>.png`.

## Starts from ours' saves (Player 2)

The hard fights are played from the state ours' bot had before them (main's full run c24f). In the Player lab's
`p2/` (lab files, not in git): `p2bot.sh` runs a private copy of c24f's bot (main lab `botproj_c24f`, read only;
its own user folder "Gold Box Reforged p2 <id>") resumed from a c24f checkpoint, with two lab hooks: `P2_RING=1`
(a quick save at every walking key, the last 32 kept) and `P2_FIGHT="<area> <min monsters> [x,y]"` (quit as such a
fight opens; the ring save before it is the start). `mkorig.sh <cfg> <name>` writes a quick save in the original's
format through ours' camp SAVE (slot I only: A-D and J are the shipped saves, G and H Player 1's) and keeps it in
`.lab/player/saves/p2start/<name>`; `useslot.sh <name>` puts it back in slot I; `queue.sh` plays several plans in
turn in the one DOSBox. **`fixwalls.py`** was needed on every such save until main fixed the save writer (chat 27, 6a8fd16; neither it
nor `cachepatch.py` is needed since): ours wrote a wall-set slot whose id is 255 or has no WALLDEF block as that id, and the original stops
with "Unable to load wallset in LoadWallSet."; written as 0xFFFF (id and slot number) it loads.

Plans can cross event squares on a walk: `walk 12,9 through 10,11` (Podol Plaza is all event squares).

## Screens and keys (lab, 2026-11-15)

| screen | how it is read | keys |
|---|---|---|
| walking | row 24 AREA ... ENCAMP | arrows; position from memory |
| text box | row 24 PRESS <ENTER>/<RETURN> TO CONTINUE | Enter |
| horizontal menu | row 24 items (CHALLENGE ATTACK FLEE BRIBE, NORTH SOUTH LEAVE, YES NO ...) | the item's first letter |
| vertical menu | row 24 empty, question row 17, items rows 18-22, the highlighted one white (others green) | **End = next, Home = previous** (the arrows do nothing), Enter |
| member choice | row 24 `... SELECT`, the party list's highlighted name white (others cyan) | End / Home, S |
| combat menu | row 24 MOVE VIEW AIM USE (CAST TURN) QUICK DONE, the member on row 1 | Q (QUICK) |
| encounter | COMBAT WAIT FLEE ADVANCE / PARLAY | C |
| CONTINUE BATTLE:YES NO | | N |
| treasure | VIEW TAKE POOL SHARE EXIT | S (coins), E; YES NO "go back and claim": N (pilot: items left) |
| camp | CAMP: SAVE VIEW MAGIC REST ALTER EXIT; SAVE WHICH GAME: A-J; QUIT TO DOS YES NO | S, slot, **N**, E |
| party destroyed | GetKey at START.EXE 0x7CC6, THE MONSTERS REJOICE ... PARTY HAS BEEN DESTROYED | (a loss: stop) |
| title / main menu / load | OVR 0x10F poll / CHOOSE A FUNCTION / LOAD WHICH GAME | Enter / L / the letter |

Learned on the way: the screen is **not redrawn** when a save's patched first step moves the party (the coordinates
line kept 14,5 S while memory said 8,4 W): memory is the truth for position and area. The code word was not asked
on most boots in this lab.

## How the Player knows the original waits for a key

All keyboard input goes through two routines (found in the unpacked START.EXE, `re/start.img`):

- **GetKey**, START.EXE seg 0x899:0x59 (image 0x89E9): calls Turbo Pascal CRT **ReadKey** (0xA40:0x30F, image
  0xA70F), which blocks in the BIOS; handles Ctrl-S etc. Callers: START.EXE 0x43B6, 0x7ABB, 0x7CC1, 0x81EF,
  0x826B; GAME.OVR 0xBB97, 0xBBA5, 0x24F84, 0x2CE41, 0x2CE4F, 0x2F7A6, 0x2FA45, 0x32352, 0x32416.
- **CRT KeyPressed** (0xA40:0x2FD, image 0xA6FD), polled by the menu loop and by fights between turns.

`hooks.py` patches three places in DOSBox's memory (nothing on disk) with far jumps to stubs in the unused
interrupt vectors C0-EF (linear 0x300-0x3BF, all zero in DOSBox; the dice-trace stub uses the PSP, so both can
run): GetKey's entry (count + caller), just after ReadKey returns (count + key), KeyPressed's entry (count +
caller). Installed before the title (`boot()` polls for START.EXE in memory from DOSBox's start), so no GetKey
is in progress when it goes in.

**Waiting** = GetKey entered and not left, or KeyPressed polled again and again from one **known input site**
(`waits.json`). Polls at other sites are not waits:

| site (the poll's return address) | what | evidence |
|---|---|---|
| GAME.OVR 0x2CE3A (KeyPressed at 0x2CE35, then GetKey at 0x2CE41) | **every menu**: the title's main menu, LOAD WHICH GAME, the walking screen's AREA CAST VIEW..., text boxes' PRESS <ENTER>, horizontal and vertical menus, member selection, the combat menu, treasure | lab 2026-11-15, each screen seen polling there |
| GAME.OVR 0x0010F | the title picture | lab, boot |
| GAME.OVR 0x0BB90 (KeyPressed at 0xBB8B, GetKey at 0xBB97) | **not a wait**: fights poll between turns on QUICK (a key here takes the party back from QUICK) | lab, the tavern fight |

The original draws **no dice while it waits** (the seed DS:0x4428 stays put at a menu: lab, 6 s at the tavern
menu), so key timing should not change outcomes; the repeatability test checks it.

## Memory table

DS = START.EXE's data segment (image segment 0xC7C + the load segment). ECL memory 0x4900-0x4CFF = words in the far
buffer [DS:0x49D2] at offset (addr - 0x4900) x 2; 0x6B00-0x6EFF = words in [DS:0x49D6] at 2 x addr + 0x2A00
(research/pool-of-radiance-formats.md).

| what | where | evidence |
|---|---|---|
| party x, y | DS:0x6AAD, DS:0x6AAE | lab: 14,5 -> step N -> y 4; 8,4 after the move into 1:18 (the screen still showed 14,5: the original doesn't redraw on that arrival) |
| facing x 2 | DS:0x6AAF (0 N, 2 E, 4 S, 6 W) | lab: S -> E -> N gave 4, 2, 0 |
| data set | ECL 0x6E12 (also DS:0x6AB2) | the lab's mksave (`WRITE_MEM 6E12`); 2 in the Slums, 1 in Podol Plaza |
| block | DS:0x84DC | lab: 20 (save J, the Slums) -> 18 after the step into Podol Plaza (the only DS byte that did so) -> 26 out the west gate (7:26) |
| party list | far pointer DS:0x5D96 -> records; next record at +0x104; in fights the monsters follow the party in the same list | lab: THRENDER GRONE at linear 0x3E198, BAKSHI +0x220 |
| record fields | name +0 (length byte first), max HP +0x32, HP +0x11B, class levels +0x96..+0x9D, status +0x10C | the CHRDAT .SAV layout (0x32, 0x11B) and the lab: HP 0 after a lost duel |
| dice seed | DS:0x4428 (Turbo Pascal RandSeed) | the lab's seed.py |
| key-wait hook | linear 0x300: enter, leave, caller IP, CS, key, polls, poll caller IP, CS | `hooks.py` |
| game speed | DS:0x49E2 (x 225 ms a message; ALTER's setting) | research/pool-of-radiance-formats.md; the Player sets 0 |

## Segment checks and first-difference triage

`segment.py <run> <from checkpoint> <to checkpoint>`: ours (`$OP_LAB/proj`, rebuilt by `check_godot.sh` after each
rebase) loads the `<from>` save as lab slot F, `tpseed=` its index line's seed, then the original's keys from the
log (camp keys left out; a fight's QUICK keys become `quickall,fightend`; two `wait`s after every key off the walking
screen), F2, and `statediff.gd` against the `<to>` save. On a difference:

1. **Count the original's draws between keys** from the log: every KEY line has the seed, and Turbo Pascal's
   generator is an LCG (`tp.steps(a, b)` in the lab), so the draws between two keys are the steps between seeds.
2. **Ours' draws**: the same keys with `tplog` after each one (each draw printed with what drew it).
3. **The original's draw list**: rerun the stretch from its checkpoint with `OP_TRACE=1` (the lab's `trace.py`
   installed after the seed is set, its reader writing `logs/<run>.trace.txt`; the lab copy of `seed.py` finds this
   lab's DOSBox by its pid file). Compare the two lists draw by draw (size and result): the first difference, with
   the original's caller (GAME.OVR offset), goes to the board.

## Pilot (Player 1, 2026-11-15): passed

- **Unattended, save to exit**: `plans/pilot_1-18.plan` from check 9's start with `strong` (Podol Plaza 1:18 8,4 W):
  the tavern (CHALLENGE, THRENDER GRONE, the duel on QUICK, main's DRINK HEAVILY|LEAVE), a hobgoblin patrol at 5,4
  (QUICK, about 50,000 draws), out the west gate to 7:26; 69 keys, about 8.5 minutes at speed 0; checkpoints entry,
  tavern, exit. (A level-1 party J loses the duel and is wiped by ATTACK: hence `strong`.)
- **Repeatable**: runs p1d and p1e (same save, seed 12345678) byte-identical at all three checkpoints; key lists,
  squares and seeds identical. A restart from the tavern checkpoint replays p1b key for key.
- **Segment check**: entry -> tavern 0 differences (walking: the patrol rolls draw for draw); entry -> exit splits
  at the duel's draw 926: the original rolls the turn-order d100 (GAME.OVR 0x9969) for all seven figures, ours for
  the two duellists (request to Combat on the board).
- **Watchdog**: restarted p1b from its tavern checkpoint after a heartbeat miss (fixed: a BEAT line every 30 s while
  dice are drawn); the restored run replayed exactly.
- **Screen state from memory**: no screen misread in the final runs; each new screen met (the wilderness walking
  menu, the band's NORTH SOUTH LEAVE) stopped the run with its reason and a screenshot, as intended.

Open: the treasure's items (the pilot takes coins only); the wilderness square (ECL 0x49C3/0x49C4 on the bands;
DS:0x6AAD/0x6AAE hold the 3D map's square there); member menus tried only with the first member highlighted.

## Queue item 2: the full run's hard fights (Player 2, 2026-11-15)

Played in the original from c24f's party (starts above), every fight on QUICK, two seeds each (12345678, 2468ace1):

| fight (c24f) | in ours (c24f's bot) | the original | verdict |
|---|---|---|---|
| 8:13 4,3, the kobold king's throne room [31 x4, 0 x35, 1 x11] | beat the party twice, then won by shortcut | **party destroyed** on both seeds (p2a, p2f: 3.4 and 4.3 min) | the game: the party is too weak there; no rule bug shown |
| 5:7 3,8, the finale's guards [85 x12] | beat the party twice (c24f); lost once, won once (p2 bot from valjevo6) | **party destroyed** on both seeds (p2g, p2h: about a minute) | the game (Combat's checks: this fight matches roll for roll) |
| 6:1 7,2, the run for the gate [100 x4, 99 x30] | stalemate at round 47 (c24f); won (p2 bot from buccaneers) | **won** on both seeds (p2c: two waves; p2e: one) | decided in the original: **rule difference found** (below) |
| 1:18, Podol Plaza's goblin hordes (13,9 [2 x40, 3 x5], random) | stalemate at round 52 (c24f) | **won**: waves of 11, 22, 27 and 29 figures (p2d, one seed) | decided in the original; ours' replay of the same stretch: below |

**6:1, first difference** (README triage: p2i = p2e rerun with `OP_TRACE=1`, `segment.py p2e entry gate --tplog`,
`cmpdraws.py logs/p2i.trace.txt logs/p2e.segment_entry-gate.txt`): the first 960 draws match (the walk, the alarm,
initiative, every "who acts next" d100); at **draw 961** LIRA (QUICK, round 1, nobody down yet) picks a target: the
original rolls **d32 at GAME.OVR 0x160DB** and attacks, ours rolls **d31** (one enemy fewer in sight) and re-picks.
Request to Combat on the board.

Both of ours' stalemates end alike: one monster left "FLEES IN PANIC" and "IS GUARDING" every round (it can't get
away) while every member on QUICK guards. Not seen in the original in five decided fights.

Tool changes on the way: stalemate stop and fight heartbeat (`OP_STALE`), `walk ... through`, `step` done on an area
change (out onto a band), the 5:7 text box (PRESS BUTTON OR RETURN TO CONTINUE), a plan's stop under `__main__`, back-
to-back fights counted, boot stops with the screen's text and picture, `segment.py --tplog`.

## Queue item 3: the service sweeps (Player 2, started 2026-11-15)

New Phlan (3:0) from c24f's `shopped` checkpoint (`p2start/3-0_shopped`, written with the record cache: `p2/cachepatch.py`).
The door plans are generated in the Player lab (`p2/svc/*.plan`: walk to the open side, step in, `snap` every screen);
ours from the same checkpoint with `at=<square>,up,y,b,screen=...`; `p2/cmpshop.py <door>` merges every list page of
both and compares them line by line (`p2/rows.py` reads a capture's 25 rows in the game's font).

- **Shops: all 13 doors match** item for item and price for price: the general store (event 19 at 15,8 9,10 12,10 9,11
  11,11: 7 items), the jeweller (21 at 8,10: 11), arms and armour (22 at 13,8 8,11 11,12 8,13 9,13: 57), silver (23 at
  11,10 10,13: 13). Both open the list one item down (the original's highlight is kept from an earlier menu).
  **One difference, row 24**: the original offers NEXT only when items lie below the window and PREV only when the
  window isn't at the first item (`ITEMS: BUY EXIT` for a short list at its top); ours always shows `BUY NEXT PREV EXIT`.
- **Temples** (Tyr: event 6 at 11,3 8,4 8,6; Sune: 7 at 1,1 3,1 1,3; Tempus: 24 at 0,12 2,12): DO YOU SEEK HEALING,
  then HEAL VIEW POOL APPRAISE EXIT, then the same nine services in both (CURE BLINDNESS ... STONE TO FLESH, EXIT).
  Prices and Tyr's DORN: Player 3, below.
- **Training halls**: Player 3, below.
- The town's other event squares, read in ours: 8 the river, 25 the gateway, 1 the pier (boat to 4:21), 2 the harbour
  master, 26 and 10 into 3:11, 9 the inn (WHO WILL PAY?).

## Queue item 3, the rest (Player 3, 2026-11-15): done

**The files first.** Every block of ECL1-8.DAX scanned (`tools/ecl.py dis`) for a shop (`WRITE_MEM 1, [6EF6]` after
TREASURE), a temple (`WRITE_MEM 1, [6DE2]` then COMBAT), training (`PROGRAM 0`) and the inn (`PROGRAM 9`): shops only in
New Phlan (3:0, four kinds); temples in New Phlan (Tyr, Sune, Tempus) and **the hidden temple of Ilmater in Podol Plaza
(1:18 1,15, event 4)**; training only in New Phlan's halls (3:11: the halls are ECL block 11 on New Phlan's map, entered
from 3:0's events 10 and 17); inns in 3:0 and 7:17. So there is nothing more to sweep outside New Phlan but Ilmater.

**Temples' prices: all match.** In the original (lab `p3/templeprices.py`: at the HEAL list, each service in turn, CAST CURE
ANYWAY YES where asked, the price read, PAY NO): Tempus 2,12, Sune 3,1, Tyr 8,6 and Ilmater 1,15 all ask the same: CURE
BLINDNESS 1000, CURE DISEASE 1000, CURE LIGHT WOUNDS 100, CURE SERIOUS WOUNDS 350, CURE CRITICAL WOUNDS 600, NEUTRALIZE
POISON 1000, RAISE DEAD 5500, REMOVE CURSE 3500, STONE TO FLESH 2000 ("<CURE> WILL ONLY COST n GOLD PIECES." then PAY FOR
CURE YES NO; "<NAME> IS NOT ..." and CAST CURE ANYWAY first for the six that need a condition): ours' `temple_screen.gd`
CURES table and texts (ours read from its code, not played).

**Tyr's DORN explained.** Tyr's greeting runs the mad-man check (ECL3 block 0, 0xAF56: `LOAD_CHAR` 0..7 over the party
looking for the MAD MAN), which leaves the last member selected (ours' VM does the same since chat 21). The original's
temple then addresses the selected member (DORN); ours' `temple_screen.gd` always opens on member 0 (request to Combat).
The same check runs on 1 step in 20 anywhere in New Phlan (on search, RANDOM 19), so any temple or shop can open on
another member in the original.

**Training halls: four differences** (request to main, one to Combat). Method: a start written from c24f's `shopped`
checkpoint with each member's experience and gold set (`p3/mktrain.py` -> `p3start/3-0_train`: ARN F 2001 XP, BRAM F
2000, CEDRIC C 1501, ELWEN C/F/MU 5000, LIRA F/MU 2501, DORN F/T 1251; 1500 gold, CEDRIC 1000, ELWEN 3000), each hall
played in the original (`p3/train_<hall>.plan`: in the party menu every member in turn T, Y, and L on a spell page,
then BEGIN ADVENTURING; checkpoints before and after), then `segment.py` and `p3/cmprec.py` (levels, spell book,
experience, HP, coins: statediff.gd doesn't compare levels or spell books). Runs p3t_thievesb, p3t_fighters,
p3t_clerics, p3t_mub (seed 12345678); dice: p3t_fightersT with `OP_TRACE=1`.
1. **Multi-class members train the hall's class in the original** when their experience reaches its next level: ELWEN
   (C/F/MU, 4000 XP) trained fighter in the fighters' hall, cleric in the clerics', magic-user in the magic-users';
   LIRA (F/MU, 2501) fighter in the fighters'. Ours refused them ("NOT ENOUGH EXPERIENCE"): `training_plan` first keeps
   only the slowest ready class and then checks the hall. Who can't train: nothing happens in the original (as ours'
   notes say), also for one a point short (the table is 1501 / 2001 / 2501 / 1251).
2. **The fee's change**: the original takes 1000 gold from the gold (1500 gold -> 500 gold; ELWEN 3000 -> 2000); ours'
   `pay_gold` gives the rest back as platinum (100 platinum; ELWEN 400 platinum). Not tried: a purse short of gold.
3. **Hit points from the game's dice**: the original draws one Random(hit die) per training at GAME.OVR 0x1DC04 (the
   fighter's d10 in all three of the fighters' hall: draws 6, 3, 1 -> +7, +4, +2 before the split), record 0xB1 rises
   by roll / classes (ARN 6 -> 13, ELWEN 5 -> 6, LIRA 4 -> 5) and max HP by that plus the CON bonus share (ARN 14 -> 25,
   ELWEN 9 -> 12, LIRA 9 -> 12: CON 18 all). Ours rolls with its own generator (`party_menu.gd`'s `_rng`, best of two),
   so its HP differ (ARN 27, CEDRIC 16 for 13, DORN 14 for 13, ...) and the shared dice don't move.
4. **Experience lowered at TRAIN** (when the fee can be paid; trained or not): the original sets XP to the largest
   "experience for the level after next, less 1" over the member's classes (levels before training) that is below the
   XP; one equal to it doesn't count. Seen in 10 cases: ELWEN C/F/MU L1/1/1 5000 -> 4000 (caps 3000/4000/5000) in all
   four halls; with 99999 XP (`p3start/3-0_xpcap`, fighters' hall): ARN 4000, BRAM 4001 -> 4000, CEDRIC 3000 (refused,
   still lowered), ELWEN and LIRA 5000, DORN 4000. Not at load, nor when the fee can't be paid. Ours keeps the XP.
5. **The spell page after a magic-user's training** (Combat): the original shows "ELWEN'S SPELLS TO CHOOSE FROM" (row 1,
   rope under it), "1ST LEVEL" (magenta) and the unknown first-level spells (the same set as ours), row 24 "CHOOSE
   SPELL: LEARN", the **last** spell lit (SHOCKING GRASP); L at once learned spell 20 for both ELWEN and LIRA. Ours
   shows "LEARN WHICH SPELL?", row 24 "CHOOSE SPELL:", the first lit (both learned BURNING HANDS). Picture:
   `logs/p3t_mu_stop.png`.
The same in both: the hall greetings, the party menu, WILL BECOME / A LEVEL 2 <CLASS> / DO YOU WISH TO TRAIN?, the
classes refused, the levels gained where both trained (DORN thief, ARN, CEDRIC), CEDRIC's exact 1000 gold.

Tool changes: plan lines `answer <words>|seq:<name>:<keys>` (a fixed key list, one key a wait, every screen snapped,
`@NAME` moves the lit member) and `alias <area>` (walks go on in another ECL block on the same map: 3:11);
`mainmenu` reads the party list and the lit member; checkpoints copy only the character files the save wrote (a stale
`CHRDATH7.*` from an older seven-member save had statediff report DIRTEN in the party). Note: a run id used twice
appends to the same log, and `segment.py` then replays the first run's keys: use a fresh id per run.

## Queue item 3: c27a's shortcut-won fights (Player 3, 2026-11-15): done

The fights c27a (main's chat 27 full run) won by shortcut after losing twice, played in the original from c27a's state,
QUICK for every member. **Checkpoints** (named here from c27a's log `data/logs27/full_c27a.log.gz`): `graveyard` before
2:9's ettins, `valjevo3` before 5:4's patrol, `valjevo6` before the finale. **Starts**: c27a's own bot (main lab
`botproj_c27a`, read only) resumed from those checkpoints in the Player lab (`p3/p3bot.sh`, Player 2's hooks: a quick save
at every walking key, quit as the fight opens; `p3/hook.py` adds a most-monsters word), the quick save before the fight
written in the original's format by ours' camp SAVE (`p2/mkorig.sh` -> `p2start/c27a_*`).

| fight (c27a) | in ours (c27a) | the original, QUICK | verdict |
|---|---|---|---|
| 2:9 7,6 [24 x2, 53 x2, 71 x6] "A GROUP OF MONSTERS IS WAITING ON THE OTHER SIDE OF THE WALL" (start 7,7 N; the bot answered FLEE, the Player COMBAT) | lost twice, won by shortcut | **party destroyed** on both seeds (p3x_ettins1b, p3x_ettins2b; about a minute) | the game |
| 5:4 patrol of giants led by a human fighter [75 x1, 55 x5] (5:4's "on rest interrupted" while Valjevo's alarm is up: start `c27a_5-4_alarm`, the alarm set as the script sets it, ENCAMP, REST) | lost twice, won by shortcut (c27a met it camping at 13,12) | **won 3 of 4 seeds** (p3x_patrol1, 3, 4: nobody down; p3x_patrol2: destroyed) | decided, mostly won: tactics or a rule gap; ours' rest interruption is off the shared dice (below), so the replay in ours splits before the fight |
| 5:7 3,8 the finale's guards [85 x12], then the vote and Tyranthraxus (start 3,6 S) | guards won in play, Tyranthraxus lost twice after them, won by shortcut | **party destroyed by the guards** on both seeds (p3x_finale1, p3x_finale2b) | the game (as Player 2 found with c24f) |
| 5:7 Tyranthraxus alone [66 x1] (the same start with ECL 0x4A6D \|= 0x0C: speech seen, guards beaten) | (not fought alone in c27a) | **won on both seeds** (p3x_dragon1, p3x_dragon2: the ending, the party in New Phlan) | a fresh c27a party beats him on QUICK; c27a met him after the guards |

So: 2:9's ettins and the finale's guards are the game for this party; Tyranthraxus alone and 5:4's patrol are won in
the original. Ours on the same footing could not be replayed yet: **ours loads the original-format saves of 5:4 and 5:7
onto the wrong map** (GEO3 block 0: both areas' inits skip LOAD_AREA_MAP when 0x49F2 already holds their block, and ours
doesn't take the map from the save; request to main), and **ours' rest interruption isn't on the game's dice**: the
original draws one Random(100) at GAME.OVR 0x24BC9 every 5-minute step (seed 12345678: 59, 31, 16 -> interrupted at
13:41 with 5:4's 17%), ours rolls the same rule with its own generator (`camp_screen.gd`; ours' patrol came at 13:31,
14:21, 13:56 on runs of the same seed; request to Combat). From ours' own quick save (right map) on QUICK the patrol
fight starts at another minute, so no like-for-like replay yet.

Wrong first try kept as a lesson: the step from 13,12 into 14,12 meets 5:4's fixed event (two officers and six scribes,
"YOU DON'T BELONG HERE!"), not the patrol (p3x_giant1b/2: won); c27a's patrol came from the bot's camp.

Tool changes: plan goal `keys <name> <k1>,...` (camp, REST: keys whatever the screens); "PRESS BUTTON OR <RETURN> TO
CONTINUE" is a text box (2:9, 5:4); `segment.py` reads keys logged with a negative time (WSL's clock stepped back during a
run: a stairs YES was dropped from the replay); Player 2's `queue.sh` reuses DOSBox and every second boot timed out at the
title, `p3/queue.sh` stops it before each boot.

## Player 4 (2026-11-15): item 1's reruns (c) and (d), TAKE first seen

Stopped early by the Lead (the design office: one lane at a time, Combat's gate items first). Ours on main's code before
chat 29 (origin/main eba466e: chat 28's training, Combat Chat 6's draw 961), replaying the original's runs from Player 2
and 3 (lab `p4/rerun_cd.sh`, no DOSBox needed; the old outputs kept in `logs/p3old/`):

- **(d) Training: all four halls match now.** `segment.py p3t_<hall> entry trained` + `p3/cmprec.py`: thieves', fighters'
  and clerics' halls **0 differences** (levels, experience, HP, coins); the magic-users' hall differs only in the spell
  learned (ELWEN and LIRA: the original SHOCKING GRASP, spell 20; ours BURNING HANDS, 9): the page lights the last spell
  in the original, the first in ours (Player 3's screen request to Combat, still open).
- **(c) 6:1: Combat's fix holds to draw 1010.** `segment.py p2e entry gate --tplog`, `cmpdraws.py logs/p2i.trace.txt`:
  7348 draws in the original, 9849 in ours; **the first difference is draw 1011**: ELWEN's target pick (d31 = 28) is the
  same in both, then the original rolls her to-hit d20 at GAME.OVR 0x2BBBF (a missile: she shoots), ours re-picks a
  target (d31) and walks (Combat's open "next split at 1010": ELWEN's bow). Ours still asks CONTINUE BATTLE at the end
  and still ends in the stalemate pattern (a buccaneer FLEES IN PANIC, members guarding); the original's fight ends won.
  Rerun this after Combat's bow fix (and on chat 29's ADD_NPC change, record 0x10E).
- (a) and (b) not run: main's load fix landed during this chat (chat 29, e0f20a3), Combat's rest dice not yet.

**TAKE in the original, first look** (lab, p1d's tavern checkpoint loaded as slot I: it loads c24f's party ARN...DORN;
the duel won by ARN, the tavern's treasure with items and no coins):
- Treasure menu `VIEW TAKE POOL SHARE EXIT` (SHARE only while coins lie there). **VIEW** is the selected member's sheet
  (`VIEW:ITEMS TRADE DROP EXIT`), the member lit in the party list (ARN here).
- **TAKE** -> `TAKE: MONEY ITEMS EXIT`; **ITEMS** -> a full-screen list headed `LOOT` (row 1), items from row 4
  (LONG SWORD, CHAIN MAIL), the lit one white, row 24 `ITEMS: TAKE EXIT`; **End** moves the light down (as the
  vertical menus). T on CHAIN MAIL for ARN left the list unchanged and showed no message the probe caught (ARN carries
  about 55,000 jewelry coins: overloaded? not confirmed). Not yet seen: how the member who takes is chosen (End on the
  treasure menu didn't move ARN's light), the refusal's message, a taken item's list.
- Plan line for probes: `default treasure stop` (the run stops at the treasure screen, DOSBox left up for
  `explore.py --attach`). Probe plan: lab `p4/probe_take.plan` (start p1d/tavern, seed 9d100b63).

Next for TAKE (Player 5): pick the member, take an item, read the refusal; then the policy: the same items main's bot
takes (`bot.gd` `_worth_taking`: magic and keepers, plain gear priced 20+ and weighing 400 or less, handed round the
party in turn), which needs each item's price and weight from memory (the treasure's item list) rather than its name.

## Player 5 (2026-11-15): item 1's reruns (a) Tyranthraxus alone and (b) 5:4's patrol

Ours on origin/main cd840bb (main's chat 29 load fix, Combat Chat 7's rest dice). Lab script `p5/rerun1.sh`: the original
traced again (`OP_TRACE=1`, runs `p5_dragon1T`/`p5_dragon2T` from `p2start/c27a_5-7_dragon`, seeds 12345678 and
2468ace1: the same outcome as Player 3's p3x_dragon1/2, won on both), then `segment.py <run> entry after --tplog` and
`cmpdraws.py logs/<run>.trace.txt logs/<run>.segment_entry-after.txt`. New: **`segment.py --ours-key=<n>:<key>`** sends
ours an extra key after the segment's n-th kept key, for a screen only ours shows (once it is on the board), so the
replay reaches the next difference.

**(b) 5:4's patrol: explained, the shortcut was ours' rest dice (now fixed).** Ours rests to the same minute as the
original (13:41 on seed 12345678, the same three d100s at 0x24BC9 and the surprise d6s). Two differences after that:
ours waits for a key on "THE PARTY IS RUDELY INTERRUPTED!" where the original goes straight to the patrol's text (so
replays need `--ours-key=5:Enter`); and **draw 780** (seed 12345678): LIRA, first to act on QUICK, steps to 26,13 and
attacks once in the original (0x0B95D d1, 0x2BBBF d20), ours shoots the hill giant twice from her square. With the
Enter, ours **wins on all three seeds the original won** (p3x_patrol1U 8 rounds, p3x_patrol3 8, p3x_patrol4 10;
ARN, BRAM and DIRTEN dying but the fight won on seed 13579bdf); the original lost seed 2468ace1 (the game). Side note:
after SHARE every member's coins differ (ours larger in kinds 0-4, the original keeps 50,000-63,000 in kind 6 where
ours has 0): not chased (treasure is item 2's).

**(a) Tyranthraxus alone: ours does not finish the fight the original wins** (both seeds). Draws match through the map
clutter (742 and 748 draws), then:
1. **Draw 743/749: the fear's half-elf roll.** Tyranthraxus's fear (GAME.OVR 0x10705) saves each enemy (0x2BC4D) and
   adds its effect through 0x2C540 by the record's level byte 0x73 (0-3 paralyzed, 4-5 weakened = Curse), saved or
   not; 0x2C540 runs the race handlers, so ELWEN (a half-elf, 0x73 = 5) draws the half-elf d100 (handler 0x11A3F,
   <= 30 throws off 0x0B/0x35) after her save. Ours (`combat.gd` `_afflict`) draws it only for paralysis. Tried in the
   lab build only (`SpecialAffects.blocks(tm, effect, ...)` for every effect): both seeds then match through
   initiative and "who acts next" (761 and 767 draws).
2. **The vote:** the original asks the six player characters; ours also asks DIRTEN (an NPC, record 0x10E = 1).
   Replays need `--ours-key=10:a`.
3. **Placement:** the original stands DIRTEN (0x10E = 1, with the monsters) at 27,13 and Tyranthraxus at 28,14, beside
   the party (25-28,11-12, facing S); ours at 37,23 and 40,23. Ours' QUICK party then guards round after round while
   Tyranthraxus breathes (ELWEN killed by 80 electricity in round 2) and the fight runs past segment's 600 s; the
   original wins in under a minute (seed 12345678: ARN, CEDRIC, ELWEN dead; seed 2468ace1: BRAM).
Requests to Combat (1, 3) and main (2) on the board.

## Player 6 (2026-11-15): Tyranthraxus alone, rerun: ours wins as the original does

Ours on origin/main 62f27f6 (Combat Chat 7's fear d100 and encounter distance 0, chat 31's vote by record byte 0xB8);
no `--ours-key`. Lab script `p6/rerun1.sh`: `segment.py p5_dragon1T|p5_dragon2T entry after --tplog` against Player 5's
traces, then `cmpdraws.py` (ours' log kept as `logs/<run>.segment6.txt`, results `logs/<run>.cmpdraws6.txt`).

**Ours now finishes and wins on both seeds** (seed 12345678 in 26 s, 2468ace1 in 39 s: "THE PARTY WINS."), as the
original does. c27a's loss there is explained: the fear's half-elf d100, the vote asking DIRTEN and the placement (all
three fixed). The vote asks the six; DIRTEN and Tyranthraxus stand beside the party. Draws now match much further:
- **Seed 12345678: to draw 785.** Tyranthraxus casts a spell whose area takes in CEDRIC and himself (ours: three saves,
  CEDRIC, TYRANITHRAXUS, TYRANITHRAXUS). The original rolls **a d100 at GAME.OVR 0x115BF after each of his saves**
  (draws 786, 788): the magic-resistance check (`cmp ds:0x6817,0` / `ds:0x6819 & 8`, then d100 against the resistance
  less `(11 - level) * 5`; at or under it calls 0x1EC5B). Ours rolls none. Who dies differs (the original: ARN,
  CEDRIC, ELWEN; ours: CEDRIC). The original's trace has one lost draw (unchecked).
- **Seed 2468ace1: to draw 817.** LIRA on QUICK steps 25,12 -> 26,13 and attacks once in the original (d20 2, then
  initiative); ours shoots DIRTEN twice from her square (d20 2 and 1): the same split as 5:4's patrol (draw 780,
  Combat's open request). Who dies differs (the original: BRAM; ours: ELWEN, DORN).
Both to Combat (board): not gate gaps (both games win), but they are the next draw-for-draw differences.

## Player 7 (2026-11-15): c32a's shortcut-won fights in the original, from c32a's own saves

Main's request (chat 32): c32a's 10 shortcut wins in 5 fights, the original from the same saves, QUICK. **Starts:** c32a's
bot (main lab `botproj_c32a`, read only) resumed from c32a's checkpoints (`data/c32/cp_c32a`, copied) in the Player lab
(`p7/p7bot.sh`, Player 2's hooks: a quick save at every walking key, quit as the fight opens), the ring save before the
fight written in the original's format by ours' camp SAVE (`p2/mkorig.sh` -> `p2start/c32a_*`); Tyranthraxus alone is
the finale's save with ECL 0x4A6D |= 0x0C (save byte 0x2DB, as Player 3). QUICK for all: c32a's records carry QUICK
(0x10F = 1 for the six), so the original fights with no keys. Runs `p7_*` (T = traced), lab logs.

| fight (c32a) | the original, QUICK (same save) | ours, QUICK (same save, `p7/oursrate.sh`, 8 dice seeds) | verdict |
|---|---|---|---|
| 5:7 Tyranthraxus alone [66 x1] (`valjevo6`) | **won 2 of 4** (12345678, 13579bdf), lost 2468ace1, 0badf00d; **every win with deaths** (BRAM, CEDRIC, DIRTEN / ARN, DIRTEN) | won 7 of 8, 6 of the 7 with deaths | the original never wins without a death: by the bot's rule (a death reloads) the game. Ours wins more often (below) |
| 4:10 9,1 [17 x2] spectres (`zhentil`) | **won 4 of 4**; DIRTEN dies in all four, ARN (seed 1) and BRAM (seed 2, drained to nothing) too; seeds 3, 4 no PC dies | won 8 of 8; DIRTEN guards and lives; one death (DORN drained, seed 1) | won in the original; c32a's two "losses" were **wins where BRAM was drained dead** (the bot reloads on a death): the bot's rule and the dice. First differing draw: DIRTEN's turn (below) |
| 2:9 7,6 [24 x2, 53 x2, 71 x6] the two magic-users (`mopup1`) | **party destroyed on both seeds** (p7_mu1Tc, p7_mu2Tc) | (not measured) | the game |
| 8:13 4,3 throne room [31 x4, 0 x35, 1 x11] (`band3`) | **party destroyed on both seeds** (p7_throne1T/2T) | (not measured) | the game (as Player 2 found with c24f) |
| 5:7 3,8 the guards [85 x12] (`valjevo6`) | **party destroyed on both seeds** (p7_guards1T/2T) | (not measured) | the game (as Players 2 and 3 found) |

**c32a's log shows what the bot counted as losses:** at Tyranthraxus (try 5) and at 4:10 (both tries) the party **won**,
then "!! <member> died ... reload" (CEDRIC killed; BRAM drained "DEAD FOREVER"). Try 4 at Tyranthraxus was a real wipe
in which LIRA and DIRTEN fought the party (LIRA attacks ARN, CEDRIC holds DIRTEN, ARN slays LIRA): not seen in any of
the 8 replays from the same save (a main/Combat question; c32a's log lines 47800-47878).

**Draw for draw (segment.py <run> entry end --tplog, with ours-only `quickall,fightend,tplog` after the step or the
votes: the original needed no fight keys):**
- Tyranthraxus seed 12345678: matches to draw 770; draw 771 is the original's **magic-resistance d100 at GAME.OVR
  0x115BF** (Player 6's request to Combat, still open). Ours wins this seed as the original does.
- Tyranthraxus seed 2468ace1 (the original loses) and **4:10 seeds 12345678 / 2468ace1** (match to 791 / 787): the same
  split, **DIRTEN's first turn**: the original draws the pattern (d8 at 0x0AC3A, d4 at 0x0AC63) and then nothing (the
  next draw is the next round's initiative); ours goes on (weighs an item, turns undead or attacks). In GAME.OVR the
  turn ends at 0x0ACC6 -> 0x0ADBD when [bp-2] != 0, set by the morale routine 0x0BC97 (record +0x84 = 0xFF for DIRTEN,
  0x10E = 0) or before. In the original DIRTEN dies in every 4:10 run; in ours he guards and lives.
- 2:9 7,6: screens differ before the fight: the original waits a key on the rocks' damage lines ("DIRTEN IS HIT FOR 4
  POINTS OF DAMAGE...", EXE:07cc6) before LOCKED, ours goes straight to LOCKED; the encounter menu after KNOCK is
  **COMBAT WAIT FLEE ADVANCE** in the original, COMBAT WAIT FLEE PARLAY in ours. Draws differ from draw 3. Not needed for
  the verdict (the original loses).

Tool changes: `segment.py <run> <from> end` (every key to the run's last, no statediff: for a run that stopped before
its next checkpoint); `screens.py`: EXE:07cc6 alone no longer means "wiped" when the bottom row is PRESS <ENTER> (2:9's
damage lines), and "HAS BEEN DESTROYED" is matched across the line break; plans `p7_2-9_7-6.plan` (KNOCK at the locked
gate, as c32a's bot did) and `p7_4-10_9-1.plan`. Lab: `p7/p7bot.sh`, `p7/hook.py` (Player 3's), `p7/rerun1.sh`
(segment + cmpdraws, `SEGX` for ours-only keys), `p7/oursrate.sh` (ours' rate from a save over dice seeds).

**Rerun on Combat Chat 8's push (b4b0cb5, the breath's magic resistance and the hands rule), the Lead's item 2:**
- Player 5's traces from c27a's save (`p7/rerun1.sh p5_dragon1T p5_dragon2T`): **both match to ours' last draw** (1273 /
  1042; the original then plays the round out, ours ends the fight: Combat's QoL note). Combat's result holds here.
- c32a's save, seed 12345678 (`p7_dragon1T`): now **matches to draw 853** (was 770), then splits at **DIRTEN's turn**
  (the same split as 4:10 below); ours wins as the original does. Seed 2468ace1 (`p7_dragon2T`): both lose; ours' fight
  ran to "THE PARTY HAS FALLEN" and then hung the lab key `fightend` (killed by pid after 8 minutes: draws cut at 799).
- 4:10 (`p7_zh1T`, `p7_zh2T`): unchanged, DIRTEN's turn at 792 / 788.
- **The clue for DIRTEN's turn:** c27a's save (written before main's chat 29) has DIRTEN's record 0x10E = 1 and its
  replays don't split there; c32a's has 0x10E = 0 (chat 29's ADD_NPC rule) and they do. The morale routine reads 0x10E
  at GAME.OVR 0x0BDA5 (0 -> on to 0x0BDB0, which can mark the figure fleeing and end the turn).

## Player 8 (2026-11-16): c33b's three new shortcut wins in the original, from c33b's own saves

Main's request (chat 33): c33b's new shortcut wins at 2:20 0,14 (`kuto`), 4:2 3,11 (`podol`), 5:4 9,1 (`valjevo3`), the
original from the same saves, QUICK, two seeds each, with deaths counted. **Starts:** as Player 7's: c33b's bot (main lab
`botproj_c33b`, read only) resumed from those checkpoints (`data/c33/cp_c33b`, copied) in the Player lab (`p8/p8bot.sh`,
Player 2's hooks), the ring save on the square before the fight (`p8/ring/`) through `p2/mkorig.sh` ->
`p2start/c33b_2-20_0-14`, `c33b_4-2_3-11`, `c33b_5-4_9-1`; plans `p8_*.plan` (one step; at 5:4 the encounter menu
answered FLEE, as c33b's bot did: the fight follows in both games). The records carry QUICK (0x10F = 1). **A death** is
status 6 (DEAD) in the `after` save (`p8/after.py <run>`: HP +0x11B, status +0x10C), as the bot counts it; 0 HP with
status 4 is UNCONSCIOUS. Ours: `p8/oursrate.sh kt|pd|v3 <seeds>` from the same ring saves (quickall), 8 dice seeds.

| fight | the original, QUICK (same save) | ours, QUICK (same save, 8 seeds, a26e676) | verdict |
|---|---|---|---|
| 2:20 0,14 [8 x2, 31 x4] | **won 2 of 2, both with deaths** (12345678: LIRA; 2468ace1: LIRA, DORN) | won 8 of 8, 2 without a death; 12345678 ends equal member for member | never deathless: the game under option (a) |
| 4:2 3,11 [28 x1, 7 x3, 6 x12] | **won 3 of 4, every win with deaths** (BRAM, DORN / BRAM, CEDRIC / ARN, BRAM, ELWEN, LIRA), lost 0badf00d | won 4 of 8 (lost 12345678 and 2468ace1; 12345678 won on the code before a26e676) | never deathless: the game under (a); ours parts at GRISHNAK's spell (below) |
| 5:4 9,1 [56 x4] | **won 2 of 2; 12345678 with no death** (DIRTEN unconscious), 2468ace1 LIRA and DORN dead | won 8 of 8, 4 without a death; both seeds end equal member for member | deathless half the time in both games: c33b's losses were the dice and the bot's tactics |

c33b's own tries there were wipes under the bot's tactics (2:20 x2, 4:2 x2, 5:4: two falls, then a win with LIRA dead),
where QUICK from the same square wins every seed at 2:20 and 5:4.

**Draw for draw** (`SEGX="--ours-key=2:quickall --ours-key=2:fightend --ours-key=2:tplog" p7/rerun1.sh <run>`):
- 4:2 (`p8_pd1T` to draw 1926, `p8_pd2T` to 1331, every cell agrees): **GRISHNAK's spell**: the original draws the aim d6
  (GAME.OVR 0x160DB) three times, then the saves (0x2BC5D) and a d100 at 0x115FB; ours aims once, then DORN's save. To
  Combat.
- 2:20 seed 2468ace1 (`p8_kt2T` to 804): an ogre's d20 = 15 against CEDRIC hits in the original, misses in ours ("needs
  18"). To Combat.

**Correction to Player 7:** at 4:10 9,1 DIRTEN ends every original run at 0 HP with status 4 (UNCONSCIOUS), not dead; so
the original won 4 of 4 there, 2 of them (13579bdf, 0badf00d) with no death at all.

**DIRTEN reruns on Combat Chat 9's push (a26e676, morale on the party's side):** `p7_zh1T`, `p7_zh2T` (4:10) and
`p7_dragon1T` (Tyranthraxus, c32a's save) **match to the end, every figure's cells** (1275 / 1320 / 1194 draws).

Lab: `p8/p8bot.sh`, `p8/oursrate.sh`, `p8/after.py`, `p8/ring/`, `p8/rate.log` (a26e676), `p8/rate_old_code.log`
(before it, partial). A boot timeout at the title (`p8_pd4T`, key not taken at OVR:0010f) was rerun as `p8_pd4Tb`.

## Player 9 (2026-11-16): c34d's three shortcut fights and c34e's Sokal Keep in the original, from their own saves

Main's request (chat 34): c34d's shortcut wins (the throne room 8:13 4,3 x4, 2:9 7,6, the guards 5:7 3,8: the same
fights as c32a's) and c34e's new one (Sokal Keep 4:21 2,11 [39 x2], event 8), the original from the same saves, QUICK.
**Starts:** as Player 8's: the run's bot (main lab `botproj_c34d` / `botproj_c34e`, read only) resumed from its
checkpoint (`data/c34/cp_c34d`, `cp_c34e`, copied) in the Player lab (`p9/p9bot.sh`, `P9RUN=c34d|c34e`), the ring save
before the fight (`p9/ring/`) through `p2/mkorig.sh` -> `p2start/c34d_8-13_throne` (4,4 N), `c34d_2-9_7-6` (7,7 N),
`c34d_5-7_finale` (3,6 S, before the stairs), `c34e_4-21_2-11` (2,12 N). Plans: `p2_8-13_throne.plan`, `p9_2-9_7-6.plan`
(no lock at 7,6 on c34d's way; COMBAT, as Player 7), `p3_5-7_finale.plan`, `p9_4-21_2-11.plan`. The throne-room save
comes from a second resume of `band3` (`p9_b3b`): the first went a different way through the caves (the bot's dice) and
never stepped on 4,3; the party there: ARN 33, BRAM 49, CEDRIC 33, ELWEN 28, LIRA 30, DORN 29, DIRTEN 20 HP.

| fight | the original, QUICK (same save) | ours, QUICK (same save, 8 seeds, 43d02cb) | verdict |
|---|---|---|---|
| 8:13 4,3 throne room [31 x4, 0 x35, 1 x11] (c34d `band3`) | **party destroyed** (`p9_th1T`, 12345678) | (not measured) | the game, as for c32a |
| 2:9 7,6 [24 x2, 53 x2, 71 x6] (c34d `mopup1`) | **party destroyed** (`p9_mu1T`) | (not measured) | the game, as for c32a |
| 5:7 3,8 the guards [85 x12] (c34d `valjevo6`) | **party destroyed** (`p9_gd1T`) | (not measured) | the game, as for c32a |
| 4:21 2,11 [39 x2] huge scorpions (c34e `sokal0`) | **won 4 of 4, 3 with no death** (12345678, 2468ace1, 13579bdf); 0badf00d: ELWEN, DORN dead | won 8 of 8, 3 without a death; 12345678 and 2468ace1 end equal member for member | won in the original: c34e's two losses were the bot's tactics and the dice |

**Draw for draw** (`SEGX="--ours-key=2:quickall --ours-key=2:fightend --ours-key=2:tplog" p7/rerun1.sh <run>`): Sokal
Keep `p9_sk3Tb` to draw 889 of 1002, `p9_sk4T` to 926 of 1119, then the same split: **the huge scorpion's poison save.**
After its first attack (d3 damage) both games draw the save (0x2BC5D); after a hit by its second or third attack (d8)
ours draws "<member> saves", the original doesn't (its next to-hit at 0x2BBBF, or the next round's initiative). Ours
loses CEDRIC on both seeds there. To Combat (not gate: both games win).

Lab: `p9/p9bot.sh`, `p9/oursrate.sh sk <seeds>`, `p9/ring/`, `p9/rate.log`, `p9/queue1-4.log`. A boot timeout at the
title (`p9_sk3T`) was rerun as `p9_sk3Tb`.

## Player 10 (2026-11-16): reruns on Combat Chat 10, showcase item 6, TAKE and the bands

**Reruns on Combat Chat 10's 0d4be44** (`SEGX="--ours-key=2:quickall --ours-key=2:fightend --ours-key=2:tplog"
p7/rerun1.sh`; rates `p9/oursrate.sh sk`, `p8/oursrate.sh pd`, seeds 12345678 2468ace1 13579bdf 0badf00d):

| fight | draw for draw | ours (4 seeds) against the original (same 4) |
|---|---|---|
| 4:21 2,11 Sokal Keep (`p9_sk3Tb`, `p9_sk4T`) | **both to the end** (1002, 1119; every cell) | **won 4 of 4, 3 deathless; 0badf00d ELWEN and DORN dead: the original's result seed for seed** |
| 4:2 3,11 (`p8_pd1T`, `p8_pd2T`) | seed 1 **to the end** (4839, every cell); seed 2 to 2506 of 3620 (GRISHNAK's to-hit at 2507: Combat's open item) | **won 3 of 4, every win with deaths, member for member as the original** (BRAM, DORN / BRAM, CEDRIC / ARN, BRAM, ELWEN, LIRA; 0badf00d lost) |
| 2:20 0,14 (`p8_kt2T`) | **draws identical to the end** (2556); positions of 3 figures differ in the record (below) | (not rated: both won before) |

`p8_kt2T`'s positions: figures 8, 9 and 11 in the original's record step back and forth (27,11 26,11 27,11 26,11 25,10
...), ours' go straight (27,11 26,11 25,10 ...), ending on the same cells; the draws are identical, so it's likely how
the original's trace records a move (figure redrawn on its old cell), not a rule. To Combat as a note, not gate. The
"end differs: ours ASKED CONTINUE BATTLE" line in every cmpdraws output is the replay's `fightend` key, as before.

**Showcase item 6** (`.lab/showcase/player/`, README.txt there): the Player driving the original (Podol Plaza's goblins,
379 s, lossless 640x400, recorded from the save's load: no title screens), its own log as a terminal at the same
pace, and a morning summary. Lab `p10/film.sh` (a Player run filmed), `p10/logtty.py`, `p10/termvid.py` (main's).
**Fight count fixed:** with every member already on QUICK the original shows no combat menu, so the count missed
those fights (the goblins: 1 of 4); a fight is now also counted at a CONTINUE BATTLE with no menu seen.

**TAKE in the original** (lab, p10t2-p10t5, Podol Plaza's goblin treasure, c24f's party; `loot.py`):
- The loot: the far pointer **DS:0x6810** to a list of 63-byte item records (next at +42; ours' `game_item.gd`
  layout), in the ITEMS screen's order. The name is a display cache without the plus (a Long Sword +1 shows as
  LONG SWORD; +50 holds the 1, the price 2000). A member's items: the far pointer at **record +0xC8** (+0xCC, +0xD0,
  +0xD4 look like the readied weapon, shield and armour).
- **Who takes: the selected member, the far pointer DS:0x5D92.** End / Home on the treasure menu (VIEW TAKE POOL
  ... EXIT) and on TAKE: MONEY ITEMS EXIT select the next / previous member (Player 4 judged by the screen's light,
  which doesn't show it). With coins left T opens TAKE: MONEY ITEMS EXIT; with none, T goes straight to the list.
- On the list (`LOOT`, row 1; items from row 4, the lit one white; `ITEMS: TAKE EXIT`): T gives the lit item to the
  selected member (appended to their list); the light stays on its row (the next item); End / Home move it and
  wrap. **A 17th item, or one over the load, is refused with the screen unchanged** (no message seen, game speed 0).
  Not yet seen: a list longer than the screen (the policy stops there).
- **Policy** `default treasure take` (plans.py): SHARE the coins, then main's bot's rule (`_worth_taking`: magic,
  quest types 74/75/82/91, the loot words, or plain gear priced 20+ and weighing 400 or less), handed round the party
  in turn, skipping a member with 16 items, at 0 HP, or who was refused that item. p10t5: 13 items taken (the Mace left: 3 gp), 9 refusals
  passed on (ARN and LIRA were over their load), then EXIT, the plan to its end.

**The wilderness bands** (lab, p1d/exit on 7:26; `p10/wild.py`): the view **DS:0x49FA = 2-4** on the bands (6:25,
7:26, 8:27; 1 in a 3D area); the band's square is **ECL 0x49C3 / 0x49C4** (ours' OVERLAND_X/Y), x from the band's
left edge (7:26 shows x + 13 on screen: 12,27 -> "25,27"); the 3D square stays put, the facing DS:0x6AAF follows the
last arrow; each arrow moves that way, no turning; a square it can't enter leaves the party where it stands.
`player.py where()` reads the band's square there, `step` sends the arrow, and `walk x,y` on a band goes the longer
axis first and the other when a step is refused (no band map in the tools yet), stopping when both are. p10b1
(walks and a checkpoint saved on the band) and p10b2 (11,26 refused, around by 12,27; 12,26 is the city's north edge
menu: a plan answer).

Lab: `p10/` (film.sh, logtty.py, termvid.py, findlists.py, memitems.py, selptr.py, wild.py, band*.plan,
gob_take*.plan, rates.sh), logs `p10*`.

## Player 11 (2026-11-16): showcase item 6 re-shot, the monotonic clock, 4:2 seed 2 to the end, TAKE against ours

**Showcase item 6 re-shot** (`.lab/showcase/player/`, README.txt there). p10f1 showed AC 60 for six members: its
start save `p2start/1-18_podol` (15 Nov 12:26) predates main's save-writer fix (6a8fd16), so the records' combat
cache (0x110-0x11C; the AC at 0x111) was 0, which the original shows as AC 60. The new start save
`p2start/1-18_podol_p11` (`p2/mkorig.sh p2/c24f/bot_podol.cfg`, today's code) shows ARN -1, BRAM -1, CEDRIC -1, ELWEN -1,
LIRA -2, DORN 0, DIRTEN 5 in the original. With real armour the run goes differently: 158 keys, 2 fights (was 4),
DIRTEN falls in the first. Filmed as p11f2; p11f3 (unfilmed, same keys) gave the summary.

**Timing: the monotonic clock.** The Player's log times, its waits and the watchdog now use `time.monotonic()`
(WSL steps the wall clock: measured here as one ~1.95 s step back about every 30 s); the log's second line is
`CLOCK monotonic <t0>`. **ffmpeg 6.1's x11grab paces and stamps its frames on the wall clock** (the first take, p11f1,
came out 219.0 s for 232.9 s of play, freezing ~2 s at each step), so the lab films with `p11/moncap.py` (a grab at
start + k/30 on the monotonic clock; a late grab repeats the last frame for the slots it missed): p11f2 is 7012 frames
= 233.733 s for 233.726 s of play, 0 repeats; the log video starts at (capture start - CLOCK) = 0.072 s into the log.
The summary now names members lost since the start ("gone since the start: DIRTEN").

**4:2 seed 2468ace1 on Combat Chat 11's c433eed** (`p8_pd2T`, `SEGX="--ours-key=2:quickall --ours-key=2:fightend
--ours-key=2:tplog" p7/rerun1.sh`): **draws identical to the end (3620 of 3620), every figure's cells agree.**

**TAKE against ours** (p11t1: `p10/gob_take2.plan` from `p2start/1-18_podol_p11`, seed 12345678, traced; ours replays its
keys, `segment.py p11t1 entry end --tplog`; ours' state just after the treasure: lab `p11/takecmp.py`, screens
`p11/oshot/`). The original took 13 items, refused 9 (as p10t5). Draws match to 2520 of the goblins' fight and the
script dice after it; then:
- **The original drops DIRTEN after the first fight and puts his items in the treasure**; ours keeps him in the party
  at 0 HP (status 4, shown red) with his 16 items. The party in the original then takes some of them back (a Long Bow,
  two Composite Short Bows, Scale Mail, Chain Mail, a Bastard Sword). Draw 2521 (the next encounter's script die,
  OVR:03cc4) is d16 in the original, Random(17) in ours: likely the party's size (6 against 7). To Combat (Requests).
- **Ours' T after SHARE opens TAKE: MONEY ITEMS EXIT**; the original, with no coins left, goes straight to the list,
  so the original's keys take nothing in ours. Likely a result of the above (ours shares among 7; a remainder stays in
  the pool): recheck once DIRTEN's rule matches. Ours' "X TAKES THE Y." / "OVERLOADED" texts are not reached by these
  keys: a TAKE check item for item waits for that.

Lab: `p11/` (film.sh, moncap.py, logtty.py with an offset, termvid.py, takecmp.py, ac.plan, oshot/), logs `p11*`.

## Player 12 (2026-11-16): Pool's full run, shape (c)/(a): segment 1 matches; segment 2 blocked by the heal gap

The Lead (design office) chose **(c), starting with (a)**: segments between c34d's checkpoints, the original playing
main's plan from each checkpoint (written in the original's format, `p2/mkorig.sh`) to the next, end states compared.

**New plan lines** (plans.py; all three are main's bot's own actions turned into keys):
- `buy <m> <item> | ...` (main's `shop` list without the door; one line per visit): the shop's list is the loot
  pointer DS:0x6810 (arms and armour: 57 items), the buyer DS:0x5D92 (End / Home on BUY VIEW POOL); on the list
  End / Home move the light, NEXT / PREV page. **POOL before every purchase** (ours' bot does); at the end the pool's
  coins are TAKEn back by the last buyer (SELECT TYPE OF COIN, the amount typed), as ours' POOL leaves them.
- `readyall` (main's bot's `_ready_all` after a shop): each member VIEW, ITEMS, READY every item showing NO, one try.
- `memorize <NAME> <spell>, ... | ...` (main's bot's `_pick_spells` at the inn): at the next camp, MAGIC, MEMORIZE,
  each spell lit and M, EXIT, YES; then REST for the time the original offers, EXIT.

**Segment 1, start -> shopped** (`plans/p12_c34d_01_shopped.plan`, run p12a6; lab `p12/cpdiff.sh` = main's
statediff.gd between ours' checkpoint and the original's): **one difference: the clock, 06:04 against ours' 06:00**
(the Player's own route reaches the inn at 01:04; both rest the 5:00 the memorizing needs). Items, readied flags
(LIRA's Short Bow stays NO in both), coins (DORN 3 gp 8 pp in both), HP and every script flag agree.

Found on the way:
- **ours' save writer leaves a 0-byte `CHRDAT<x><n>.ITM` (and .SPC) for a member with none; the original loads a
  0-byte .ITM as one garbage readied item** ("YES 254 PASSS"; the sheet then shows THAC0 148, ENCUMBRANCE 60420, DAMAGE
  0D0-128, and purchases are refused: overloaded). The original's own saves leave such files out (shipped save A).
  Lab workaround: `mkorig.sh` deletes 0-byte CHRDAT files. To main (Requests).
- **The shop's POOL differs**: ours hands every member's coins to the buyer; the original keeps them in the shop's
  pool (the menu then reads BUY VIEW TAKE POOL SHARE APPRAISE EXIT; leaving with coins in it asks "YOU HAVE LEFT SOME
  MONEY HERE. DO YOU WANT TO GO BACK AND GET YOUR MONEY"). To Combat (screens).
- The original lists memorized spells sorted (BLESS, CURE LIGHT WOUNDS, CURE LIGHT WOUNDS); ours keeps the bot's
  order ([3, 3, 1]). Not compared by statediff; noted only.
- New Phlan's inn (event 9) does nothing while ECL 0x4A07 = 1 (set by paying, cleared by a plain square's event):
  a second inn visit needs a step off and back.

**Segment 2, shopped -> slums** (`plans/p12_c34d_02_slums_a.plan`, run p12b1, traced): main's `explore` is the bot's
own code (event order by odds, rests and Cure Light Wounds in camp, inn trips, trades), not keys, and ours' bot draws
Godot's dice, not the original's, so the two runs part at the first fight; an end state can only agree on flags.
**Lane decision:** the original follows the bot's event order taken from c34d's log (lab `p12/botorder.py <from> <to>`),
with the Player's own fight (QUICK), TAKE and heal rules; ours then replays the original's keys from the same checkpoint
and seed (segment.py, draw for draw and statediff), and the flags are checked against ours' next checkpoint.
First pass: 3 fights won (event 2's goblins at 10,1, 8,2, 3,4), then **stopped: no route 1,7 -> 1,5** (event 14 is
reached only across a square of an event the walk excludes); the party was down to ARN 8/14, BRAM 9/14, CEDRIC 4/10,
ELWEN 5/9, LIRA 2/9, DORN 7/10. **Gaps before segment 2 can run:** (1) a heal step (camp MAGIC CAST Cure Light Wounds on
the lowest, then REST to memorize again, as the bot's `_heal`; the inn when spells are out); (2) the walks' crossing
rules as the bot's tour (which events it may cross); (3) segment.py keeping camp keys (MAGIC/MEMORIZE/REST/CAST change
state) so ours replays them. Segment 1 can't be replayed in ours for the same reason (3).

Lab: `p12/` (seg01.plan, seg02a.plan, cpdiff.sh, cfgparty.py: ours' checkpoint's members, botorder.py, lit.py,
find.py, scr.py: probes), saves `p2start/c34d_start`, `c34d_start_noitm`, `c34d_shopped`, runs `p12a6` (segment 1),
`p12b1` (segment 2's first pass), logs `p12*`.

## Player 13 (2026-11-16): segment 2's three gaps closed; segment 2 runs to event 3; segment 1 in ours parts at the shop

**Lead's item 2:** main's chat 41 (addbfc7) writes no empty `.ITM`/`.SPC`; lab `p2/mkorig.sh` no longer deletes 0-byte
files. A fresh start save (`p2start/c34d_start13`, no 0-byte files) loads clean: segment 1 rerun from it (p13a1)
matches ours' `shopped` as p12a6 did (statediff: only the clock, 06:04 against 06:00).

**New plan lines and tools** (plans.py, segment.py):
- `heal` (main's bot's `_heal_if_low` / `_heal`, camp areas): if a member is below half HP or not OKAY: ENCAMP; every
  memorized Cure Light Wounds cast on the most hurt (4+ HP missing; MAGIC, CAST, the CHOOSE SPELL list, CAST SPELL ON
  WHOM with End / Home and S); the bot's picks MEMORIZEd in the free level-1 slots (clerics CLW, CLW, Bless; magic-users
  Sleep, Magic Missile, if in the book); REST for the time offered; in rounds while cures heal, then rests of
  min(most missing HP, 10) days (REST: DAYS is Y, HOURS H, MINS M, INC / DEC). A member dead stops the run (death rule).
  An interrupted rest is fought out and the heal goes on (the bot walks to the inn there; noted, not copied).
  Probed in the original first: learning spells are id | 0x80 in record bytes 0x17-0x2B; the memorize list shows CAN
  MEMORIZE: CLERIC SPELLS: n; a rest ends on the CAMP menu.
- `walk x,y avoid 9,12,16`: the route crosses every event square but those, as the bot's tour (main.gd `_find_path`
  walks round only `explore`'s left-out events). Player 12's 1,7 -> 1,5 dead end came from also avoiding the bot's
  odds-deferred events (13 15 20).
- `answer <words>|type:<WORD>`: a typed answer (the Rope Guild booth's OHLO).
- TAKE pages a loot list longer than the screen: 19 rows a page, ITEMS: TAKE NEXT [PREV] EXIT; a 37-item pile's second
  page shows its last 19 items (overlapping). The window is found from the rows' names (counts like "10 ARROWS"
  stripped on both sides).
- segment.py keeps the heal's and memorize's camp keys (only a checkpoint's camp keys are left out), adds ours' waits
  for each REST's length, clears slot F before installing (an older save's .ITM/.SPC were loaded with a new .SAV), and
  `segment.py <run> begin <to> --start=<p2start save>` replays from a run's own start.

**Segment 2 (shopped -> slums)**, `p13/seg02b.plan` (the bot's event order 2 4 5 8 7 14 17 18 21 11 10 6 1 3 19, heal
after each), traced: p13b5 won 15 fights on QUICK with 7 heals (every heal back to full HP, no rest interrupted), and
stopped at event 3's commission menu (ACCEPT THE COMMISSION / REJECT IT: answer fixed to ACCEPT). p13b6 (with
checkpoints `s2a` before event 3 and `s2b` before 19) was running when the chat ended.

**Segment 1 replayed in ours** (`segment.py p13a1 begin shopped --start=c34d_start13`): ours stays in the shop. **First
difference: on the shop's item list NEXT / PREV keep the light on its screen row in the original** (Long Sword lit on
row 19, NEXT, one End lights Banded Mail on row 20); **ours puts the light on the page's top row**
(`shop_screen.gd` `_page`: `_cursor = _top`), so the same keys buy a Voulge. With that changed in the lab's copy only,
ours buys Banded Mail; a second difference remains around the pool's TAKE and EXIT (original keys 220-227: ours'
pool after the purchases was 2 gp 64 pp against the original's 3 gp 9 pp before the patch; not yet rechecked).
Request to Combat (board).

Lab: `p13/` (seg02b.plan, heal_test.plan, idle.plan, sethp.py: probe HP in memory, align.py: a segment's ours lines
next to the original's keys, oursat.py: ours' screens after chosen keys), saves `p2start/c34d_start13`,
`c34d_shopped13`, runs `p13a1` (segment 1), `p13h1` (heal probe), `p13b1`-`p13b6` (segment 2).

## Player 14 (2026-11-16): p13b6's loss explained (the route); the inn trip; segment 1 in ours matches with two shop fixes

**Why p13b6's party died at 14,10 (queue item 1): the route, not the dice.** The walk to event 3's square 11,9 went
through 13,10, event 3's door: PICK, the commission (TALK, SLY, ACCEPT), and then the event puts the party back on
14,10 facing E. The walker turned round and tried the same step ~30 times; each try rolled the Slums' encounters, and
the party, at 3 of 6 standing after fight 16, fought on until it was destroyed. Main's bot's tour refuses such a step
(main.gd `_tour`, `_refused`: "the square ahead turned the party back"), finds no other way to 11,9 and counts the
event visited; it also stops a tour after a fight that leaves the party hurt (bot.gd `_hurt`, then `_prepare`), and
walks to the inn when a camp's rest is interrupted (`_heal` → `_rest_at_inn`).

**New in the tools (plans.py, segment.py):**
- Walks: a step the square's script turns back (the party on the same square, facing elsewhere) is refused for the
  rest of the run and walked round; a walk to an event whose square turned the party back, with no way on, is done.
  A fight on a walk that leaves the party hurt (bot.gd `_hurt`: someone unconscious or dying, or the standing members
  under 60% of their HP) inserts a heal of anyone hurt (`heal (after a fight)`) before the walk goes on.
- `inntrip` ... `inntrip end` and `innheal`: an interrupted rest inserts the plan's trip to the inn (2:20: walk to
  15,4, step E; 3:0: walk to the inn at 4,12, TO REST HERE YES, the payer `@platinum` as the bot, the heal in the
  inn's camp; walk to 0,4, step W). The bot's tour back to the square it left is left out (the plan's next walk
  routes from where the party comes back in). `plans/p14_c34d_02_slums_c.plan` (lab `p14/seg02c.plan`).
- The stall guard (no goal in 300 keys) counts from an inserted heal or trip.
- segment.py: ours' waits after a REST also cover each spell being memorized (ours holds each HAS MEMORIZED line for
  the game speed x 225 ms with the rest's clock paused; p13a1's inn REST was still running at F2).

**Seeds:** a run resumed from a checkpoint with the same seed and keys can replay the original's dice exactly (p14b4
from p14b3's `s2b`: the same seed at every step, the same fight at 6,14), though not always (p14b1 and p14b2, both
from `s2a` with one seed, parted in their first fight). A "reload" after a loss therefore takes another seed (the
bot's reload meets new dice because the clock has moved on).

**Queue item 1, segment 2 to `slums`:** from `s2a` with the new rules: p14b1 stopped on the stall guard (fixed), p14b2
on 5 interrupted rests at 14,10 (before the inn trip existed). **p14b3** made the inn trip (New Phlan's inn, healed to
full, back by 0,4 W) and saved `s2b` (2:20 15,4 W), then was destroyed at 6,14 S (a 20-figure encounter in event 18's
southern streets, the only route to event 19); p14b4 (same seed) met the same fight; p14b5 (seed 2468ace1) lost ELWEN
there (death rule); **p14b6 (seed 12345678) reached `slums`** (2:20 15,12 E, two fights, a heal). At level 1 that
stretch is the dice: c34d's bot crossed it without a fight. Its flags against c34d's bot's `bot_slums.cfg`
(`p12/cpdiff.sh`): the same but counters 4A80 (13/15) and 4ABB (19/21), 4A16 (35/0), the 4AFA-4AFF words, the day,
and the party's XP, coins and loot (other fights).

**Segment 2 in ours (p13b5 replayed, `--tplog`): parts at draw 27 of 44733, the locked door's PICK** at 2:20 10,2 N
(→ 10,1, event 2): the original rolls a d100 for each of the six members (OVR:16be3), the lock opens and event 2's
fight begins; ours draws nothing from the game's dice (main.gd `_door_choice` "P" rolls `_door_rng`, its own
generator, and stops at the first success) and the party stays on 10,2. Request to main (board). The p14b6 replay
(`segment.py p14b6 begin slums --start=p14b3_s2b --tplog`) waits for that fix.

**Queue item 2, segment 1 in ours: matches but for the clock** with two lab-only patches of `shop_screen.gd`: NEXT /
PREV keep the light's row (Player 13's request), and **BUY opens the item list at its top again** (ours reopened it
where the last purchase left it: the last page, Shield lit, no NEXT; the original's NEXT + End keys then reach other
items, and ours' pool held GOLD 4 PLATINUM 58 against the original's 3 gold 9 platinum). With both, all 416 keys
follow the original square for square and statediff shows only the clock (ours 05:49, the original 06:04). Added to
the board request to Combat.

**Lead's item 3:** no fight compared to its end this chat (the segment 2 replay parted before its first fight).

Lab: `p14/` (q.sh: a queue run with player.py args such as `--after`; seg02c.plan), saves `p2start/p13b6_s2a`,
`p2start/p14b3_s2b`, runs p14b1-p14b6, ours' replays `logs/p14_*.out`, screens `p14/*.png`.

## Player 15 (2026-11-16): segment 1 checked on Combat's BUY fix; the inn's rest time; `prepare`; segment 3 to `slums2`

**Queue item 1 (segment 2 in ours) still waits:** main's `_door_choice` "P" still rolls `_door_rng` (origin/main
a0ea85d), so the replay parts at segment 2's first PICK as before.

**Queue item 2, segment 1 in ours:** Combat's BUY fix (867d3b1, "BUY opens the item list at its top") is on the
`combat-lane` branch, **not on origin/main yet**. On origin/main alone segment 1 still parts at key 64 (BRAM's BUY:
the list on its last page, Shield lit), ours' pool holds GOLD 4 PLATINUM 58 and the shop's last EXIT (key 230)
leaves the party in the shop. With 867d3b1 applied to the lab's copy only, **all 416 keys follow the original and
statediff shows only the clock** (3 differences: ours 05:49, the original 06:04). **The clock is the inn's REST
TIME:** after the same MEMORIZE (CEDRIC Cure Light Wounds x2, Bless; ELWEN Cure Light Wounds x2, Bless, Sleep;
LIRA Sleep) the original offers 00:05:00 (p13a1.log key #415), ours 00:04:45 (ours' screen at key 414:
`p13/oursat.py <seg txt> 414`). Both games arrive at 01:04. The original's offers fit "4 hours plus 15 minutes a
spell being memorized, the member with the most": ELWEN's four = 5:00 (ours counts three: her magic-user spell left
out?); p15c7's CEDRIC with two cures = 4:30. Request to Combat (board).

**New in the tools (plans.py):**
- `prepare`: main's bot's `_prepare` before each event of an `explore` (bot.gd: `_pick_spells` fills the free slots,
  `_memorize` rests for them, then `_heal`): camp, MEMORIZE the bot's picks in every free slot, REST for the time
  offered, and the heal of anyone hurt; nothing when no slot is free and nobody is hurt. Without it the party walked
  into event 9's 30-figure fight with its Sleep spells spent (p15c1, p15c2: lost at 3,3).
- The heal inserted after a fight on a walk that leaves the party hurt is now that `prepare` (the bot's stop on the
  way calls `_prepare`, which memorizes too).
- `innheal` always runs through the camp (memorize, then leave), whether or not anyone is hurt (the inn's camp is
  already open after TO REST HERE).
- Known gap: right after a cure in the inn's camp the cure's slot isn't seen free until the next camp, so the
  memorizing waits for the next `prepare` (one camp rest more than the bot).

**Queue item 5, segment 3 (slums -> slums2): reached** (p15c5 to `s3t`, p15c6 from `s3t`; plan
`plans/p15_c34d_03_slums2.plan`, lab `p15/seg03.plan`). The bot's order (`p12/botorder.py slums slums2`): a town
trip (out by 15,4: the only way from 15,12 is through event 18's southern streets, so the next walks start in the
north), explore 16 touring events 2 4 5 8 9 7 14 17 18 21 12 with `prepare` before each, `heal` after; the training
trip to the clerics' hall (3:11 6,0 W, Player 3's keys), the inn, back to 15,12 (event 19). **Walks avoid only
explore's left-out event (16)**: main.gd `_find_path` doesn't avoid the deferred ones (13 15 20; with them avoided
1,7 -> 1,5 had no route, p15c4). Left out: the clerk, temple and shop of the town trips (no gem-sale tool), the
second town trip (an inn rest) and the re-tour of 1 6 11 10 3. Losses: p15c1 (seed 12345678) and p15c2 (2468ace1)
at 3,3 (event 9, no `prepare` yet); p15c3 (87654321) a death in a 25-figure fight on the southern streets (before the
town trip was put back); p15c4 (13572468) stopped on 1,7 -> 1,5 (fixed); **p15c5 (13572468)**: 3 fights won, nobody
down, `s3a` (2:20 0,0 W) and `s3t` (3:11 5,0 W; nobody had the experience to train: the bot had one more fight and
trained CEDRIC); **p15c6** (24681357, `--after=s3t`, the halls' walk out needs `through 9,10,11,25`) to `slums2`
(2:20 15,12 E). Against c34d's bot's `bot_slums2.cfg` (`p12/cpdiff.sh`): the flags the same but the counters 4A80
(15/16) and 4ABB (22/24), **4A81 (250/255: the bot fought the goblin guards' group, the original's walks never met
it)** and 4AFA-4AFF; the party still level 1 (the bot's ARN 26 HP), coins (no gem sale, no pooling) and loot.

**Segment 3's town trip again, as the bot's (the party reached `slums2` at level 1 above; c34d's bot had sold its
gems for 19511 gold and trained ARN, BRAM 2, CEDRIC 3, DORN 1/2):** new in plans.py:
- `sell gems [share]`: at the next shop visit every member's gems and jewellery (record 0x92 / 0x94) APPRAISEd and
  SOLD (the original: APPRAISE: GEMS JEWELRY EXIT, a word dropped when none is left; "THE GEM IS VALUED AT 500 GP."
  over "YOU CAN : SELL", no KEEP); `share`: then everyone's coins POOLed and SHAREd, the Player's way to fund each
  trainee (main's bot moves the coins itself, bot.gd `_fund`, which the original has no key for).
- `innwait`: `innheal`, then from hour 14 (0x49C9) a rest in the inn's camp till midnight (bot.gd `_wait_for_day`:
  New Phlan locks its shop, City Hall and halls from hour 14; p15d1 met "THE DOOR IS LOCKED. DO YOU WANT TO BREAK
  IN?" at the arms shop at 16:00).
- The inn's camp, opened before the walk sees the inn's square, now carries the `prepare` / `innwait` flags (it was
  a plain heal: the "cure slot not seen free" gap above).
- The halls are on New Phlan's map (GEO3 block 0 events): 10 (6,1 6,2), 11 (6,0), 12 clerics (5,0), 13 magic-users
  (7,0), 14 corridor, 15 (8,1), 16 fighters (8,0), 17, 18; walks between halls need them in `through`. One
  `answer CHOOSE A FUNCTION|seq:<name>:...` per hall visit (a hall may ask twice: keep spares).
Plan `p15/seg03t.plan` (from `s3a`): the inn till midnight, the arms shop (sell, pool, share: each member ~331
platinum), the fighters', clerics', magic-users' and thieves' halls, the inn, back to 15,12.
**p15d8 (seed 11223344, `--after=s3a` from p15c5's `s3a`) reached `slums2` trained:** ARN 2 (25 HP), BRAM 2 (24),
CEDRIC 2 (18), DORN 1/2 (15); c34d's bot: the same but CEDRIC 3. Save `p2start/p15d8_slums2`; plan
`plans/p15_c34d_03_slums2_train.plan`. (p15d1-p15d7: the locked shop, the halls' routes, the sale screens, the answers.)

**Segment 3 in ours:** it has PICKs too (p15c5's first at key 55), so it waits for main's fix like segment 2; its
first fights come before the first PICK (p15c7, a traced rerun: below).

**Lead's item 4 (a fight ours ends on its last kill while the original plays the round out):** Tyranthraxus alone
(Combat Chat 8, regress.sh `orig_B_tyr1/2`): the original's traces `logs/p5_dragon1T.trace.txt` /
`p5_dragon2T.trace.txt` go on after his fall (draws 1274-1305 / 1043-1062: the round's rest), ours ends the fight
at once. Named to main on the board (Findings).

Lab: `p15/` (seg03.plan, screens `c_*.png`, `d_*.png`, `r_414.png`/`r_415.png` (ours' REST TIME), segment 1's
replay on 867d3b1 `p13a1.seg_combat867.txt`), saves `p2start/p14b6_slums`, `p2start/p15c5_s3a`, `p2start/p15c5_s3t`,
runs p15c1-p15c7.

**Segment 4 (slums2 -> sokal0): reached** (p15e3, seed 55667788, from `p2start/p15d8_slums2`; plan
`plans/p15_c34d_04_sokal0.plan`). The bot's order: the tours 14,11 and 11,9 (Ohlo at 13,10: "GIVE ME THE POTION
AND YOU WILL BE REWARDED": GIVE, main's plan's Ohlo's errand; the bot's run met only the locked door there), the
inn (`innwait`: before hour 14, no wait), the harbor master (11,1), then 14,1 and a step E onto the pier's end (a
walk onto 15,1 ends in 4:21 and the walk stops: "in area 4:21, not 3:0"). Sokal Keep's gate 4:21 8,14 N, no
encounter on arrival (the bot fought five there: undead, zombies). Against `bot_sokal0.cfg`: the counters 4A80
(15/16), 4ABB (23/24), the arrival fights' 4A03-4A0E (the bot's 4A0E 255), 49F0/49F1, XP and HP (CEDRIC 2 against
the bot's 3). Save `p2start/p15e3_sokal0`. (p15e1/p15e2: Ohlo's GIVE; the walk onto the boat.)
- `walk x,y avoid 99` for a walk that crosses every event (an `explore` with nothing left out): `avoid 0` avoids
  every plain square (event 0).

**Segment 5 (sokal0 -> sokal, Sokal Keep), open.** Plan `plans/p15_c34d_05_sokal.plan` (lab `p15/seg05.plan`): the
bot's event order 13 14 17 10 20 9 11 3 7 16 12 6 15 4 2 1 8 5, `prepare` / `heal` round each, checkpoints
`s5c13` (after 15,1), `s5c9`, `s5a`, `s5c16`, `s5c4`; answers A PALE FORM RISES -> PARLAY (main's `parley` line),
DO YOU TAKE IT -> YES (event 17's armour stands, the bot's choice). So far: p15f1-f3 (plan fixes: `avoid 99`, the
armour's answer), **p15f4 and p15f7 destroyed in event 9 at 7,4** ("A LARGE FORCE OF ORCS AND HOBGOBLINS": 56
figures; c34d's bot won it with CEDRIC at level 3 and casting), **p15f5, p15f6, p15f8 lost in the rest fights at
15,1** (the `prepare` after the two fights on the way there: four interruptions in five rests, undead). The rest
odds are the original's in ours too (p15f6 replayed: the same dice and interruptions, to draw 2935).
- **MAGIC (Player 15):** the original's QUICK members cast only after Alt-M (MAGIC ON, off at every fight's start,
  GAME.OVR 0xE457); the Player's fights so far all ran with MAGIC OFF (no Sleep), while main's bot casts. New:
  `OP_MAGIC=1` (game.py) presses Alt-M once a fight, at its first computer turn (the original polling the keyboard
  at a site that is no input screen, with monsters in the figure list), logged `MAGIC alt+m`; segment.py turns that
  line into ours' `magic` key. From p15f8 on, Sokal runs use it.
- **segment.py, fights with no combat menu:** the original's all-QUICK fights take no key, so nothing made ours wait
  for their end; the CONTINUE BATTLE `n` and the Enter after it reached ours mid-fight and were lost (p15f6: ours
  then took a later `y` as CONTINUE BATTLE YES). Now each "fight N ended" note inserts `fightend` (ours waits for the
  fight's end or its CONTINUE BATTLE). p15f6's replay went from draw 2179 to 2935.
- **Fights compared in ours:** p15c7 (segment 3's kobolds) matches to 876 (ARN's long sword: the original 2d4,
  ours d8 against a kobold; zombies 2d4 in both); p15f6 (Sokal's rest fights) to 2935 (a member at 0 HP: one more
  "who acts next" d100 in the original). Both to Combat (board).
- **A start save names its own character files.** SAVGAMx.DAT holds the party's file names (`CHRDATH1`-`6` at
  offset 12810 for a checkpoint written to slot H). The lab's `p2/useslot.sh` renames a start to slot I, but the
  original then reads `CHRDATH*` from the game folder: the characters of the last checkpoint written (p15f12 and
  p15f13 loaded `s5c13` with p15f11's dead DORN). The lab's `p14/q.sh` now also copies the start under its own names.
  Earlier runs that loaded another checkpoint's characters: p15d1-p15d8 (from `s3a`, slot H then held p15c6's
  `slums2`: the same party, no fight or training between, so likely no difference); the p15e and p15f runs read their
  own. Player 14's reloads should be checked the same way (p14b4-p14b6 from `s2b`).
- **Resting in Sokal Keep:** every camp so far (15,1 five times, 13,0 once) was interrupted four times; four of the
  15,1 camps ended with a death. The bot's c34d rested 11 times there with one interruption. Not a rule difference:
  p15f6 replayed in ours draws the same rest checks and the same interruptions. The plan drops the camp on 15,1.
- **Event 9 (7,4), the orcs and hobgoblins (56 figures), five losses:** p15f4 and p15f7 (no magic), p15f9 (Alt-M at
  EXE:08abd, before the fight's own reset: now only at OVR sites), p15f14 (from the camp-free plan, the checkpoint
  `s5pre9` at full HP and spells just before it, MAGIC ON), p15f15 (from `s5pre9`, traced). c34d's bot won it in ours
  with its own tactics (`smartquick`) and CEDRIC 3. Ours replaying p15f15 (`OP_SEG_TIMEOUT=600`) matches to draw
  1031 and then logs no more draws although its fight goes on to round 16 (the tplog lines stop after the last
  `tplog` key: inconclusive; rerun with a longer `OP_SEG_TIMEOUT` and a `tplog` after `fightend`). Lab script
  `p15/oursfight.py` (ours from a Player save, all on QUICK + magic, several seeds; ~12 minutes a seed): **ours from
  `s5pre9`: seed 11111111 won after 22 rounds with BRAM alone standing (LIRA, CEDRIC, DORN, ELWEN dying, ARN down:
  a loss under the death rule), seed 22222222 the whole party down in 7 rounds.** The original at event 9 in all, 10 tries:
  8 wipes, 2 wins each with a member dead (p15f17, p15f20). So ours' QUICK fares as the original's: no rule difference
  seen; c34d's bot won with its own tactics (`smartquick`, which the original doesn't have). **Decision (lane):** the
  Player's run defers event 9 until the party is stronger (as the plan defers the Slums' trolls to level 3), and logs
  the departure from c34d's order. Events 11 (7,6) and 12 (7,10, the pale form: Ferran Martinez and the library's
  word) are reached only across event 9's squares, so they wait too. Plan `p15/seg05b.plan` (repo
  `plans/p15_c34d_05b_sokal_part.plan`): from `s5pre9` the other events, ending at checkpoint `s5b`.
  **p15g1/p15g2 reached `s5b`** (4:21 2,8 E, nobody lost; p15g2 from p15g1's `s5c4` with event 1's TALK and NICE as
  the bot: the plan's ATTACK|LEAVE had taken LEAVE on that menu). Against the bot's `bot_sokal.cfg`: the counters,
  and the deferred events' flags 4A05 (0/1), 4A26 (0/255), 4AA7 (0/254), 4AD7 (0/255). Save `p2start/p15g2_s5b`.
  segment.py now also puts `fightend` after a wipe (it had only "fight N ended").
- **Queue item 3 (the fallen NPC), rechecked** on origin/main 00e56ab (Combat Chat 16): `segment.py p11t1 entry end
  --tplog`: draws identical to the original's, all 5974 (`logs/p11t1.cmpdraws15b.txt`; was 3613 at 747cb9e).

Lab (Player 15): `p15/` (seg03.plan, seg03t.plan, seg04.plan, seg05.plan, oursfight.py, tries.sh, screens), the lab's
`p14/q.sh` (copies a start under its own names too), saves `p2start/p14b6_slums`, `p15c5_s3a`, `p15c5_s3t`,
`p15d8_slums2`, `p15e3_sokal0`, `p15f4_s5c13`, `p15f14_s5pre9`; runs p15c1-c7, p15d1-d8, p15e1-e3, p15f1-f17.

**Segment 6, part a (s5b -> s6t): reached** (p15h6, seed 20202020, from `p2start/p15g2_s5b`; plan
`plans/p15_c34d_06a_town.plan`): the boat back (a walk onto Sokal's 7,15, then a step S: TAKE A BOAT BACK TO PHLAN
YES), the walk from the pier crosses the temple of Tyr (3:0 event 6 at 11,3; no route round it): DO YOU SEEK
HEALING YES, then the temple's HEAL VIEW POOL APPRAISE EXIT: EXIT (the bot's "leaving temple"; NO puts the party
back on 11,2 and the walker, whose refusal rule only sees a turn on the same square, tried again: a gap to close),
the inn till midnight, the clerk, the sale with pool and share (each ~255 platinum), the four halls: **ARN 3, BRAM 3,
CEDRIC 3** (c34d's bot at `kuto`: ARN 3, BRAM 3, CEDRIC 4, ELWEN 2/2/1, LIRA 2/2, DORN 2/3). Save `p2start/p15h6_s6t`
(3:0 4,12, the inn). Part b, Kuto's Well (travel 8:29 by the Slums' 0,4 W, explore: CLIMB DOWN NO until no event is
left, NAILED SHUT YES, SURRENDER/FIGHT FIGHT, the catacombs), is for Player 16.

**Segment 5's deferred events at level 3** (plan `plans/p15_c34d_05r_sokal_rest.plan`, lab `p15/seg05r.plan`, from
`p2start/p15h6_s6t`: the pier, the boat, a walk to 7,2 that crosses event 9's squares, then 7,6 and 7,10, checkpoint
`sokal`): p15i1 (seed 30303030) **won event 9 with nobody dead** (ELWEN and LIRA unconscious) and then stopped on a
tool bug (an interrupted rest's MEMORIZE seen as a repeat: fixed, `memo_last` cleared on an interruption); p15i2
(the same seed: other dice) and p15i3 won it with members dead, as did p15i4, p15i5 and p15i6 (lab `p15/tries3.sh`): **at level 3, 6 tries: 1 win with
nobody dead, 5 with deaths** (at level 2: 8 wipes, 2 wins with a death in 10). No `sokal` checkpoint yet.

## Player 16 (2026-11-17): `sokal`; segment 6b, Kuto's Well and Norris (`s6k`); segment 7 (`slums3`); the secret door

**Queue items 1 and 2.** Main's PICK still rolls `_door_rng` (origin/main a19aed7): segments 2 and 3 in ours wait.
Combat's answers rerun on origin/main: **segment 1 in ours, 0 differences** (`segment.py p13a1 begin shopped
--start=c34d_start13`); **p15f6 matched to 5646** of 9841 on a19aed7 and, on Combat Chat 17's 9b677c8 (members down get squares too), **draws identical, all 9841**.

**Segment 5's deferred events: `sokal` reached** (plan `plans/p15_c34d_05r_sokal_rest.plan`, lab `p16/seg05r.plan`).
p16a1 (seed 40404041) lost a member in event 9; **p16a2 (40404042) won event 9 with nobody dead** (fight 6, 56
figures: CEDRIC and ELWEN down, healed) and went on to 7,10, where it typed the plan's old `OHLO` at the pale form's
WHAT DO YOU SAY (a leftover answer from the Slums); **p16b2** from p16a2's `s5r9` (after event 9) with `LUX` (main's
bot's word), then HAS THE CITY BEEN FREED: TELL (the truth): checkpoint `sokal` (4:21 7,10; save
`p2start/p16b2_sokal`). Event 9 at level 3 in all: 8 tries, 2 wins with nobody dead. Against c34d's `bot_sokal.cfg`
(`p12/cpdiff.sh`): the deferred events' flags now agree (4A05, 4A26, 4AA7, 4AD7); left: the clock, the counters 4A80
(15/16) and 4ABB (23/24), the arrival fights' 4A06-4A10 (the bot fought at the gate, the Player's walks met none
there), 49F0/49F1/4A18, 4AFA-4AFF; XP, HP, coins and items (the bot's party is ahead: its own fights).
- An hmenu's answer is one of its words (`answer HAS THE CITY BEEN FREED|TELL`, not `TELL THE TRUTH?`).

**Segment 6 part b, Kuto's Well: reached `s6k`** (plan `plans/p16_c34d_06b_kuto.plan`, lab `p16/seg06b.plan`, from
`p2start/p16b2_sokal`): the boat back, the town trip as part a's (nobody had the experience to train: checkpoint
`s6t2`), the Slums' 0,4 W, the well's events 5 1 17 16 2 3 18 4 19 21 22 with CLIMB DOWN NO and NAILED SHUT YES
(`s6well`, 4 fights, nobody down), down the rungs (the catacombs are GEO8 block 32; the area stays 8:29), events 9
6 7 14 8 15 10 11 (`s6pre12`), Norris the Gray (event 12; its squares 1,5 5,5 10,3: FIGHT), the hideout's rest, up
the rungs: `s6k` (8:29 7,7 N, everyone whole: ARN 37, BRAM 34, CEDRIC 25, ELWEN 9, LIRA 9, DORN 15; save
`p2start/p16d1_s6k`). Runs: p16c1 (seed 60606061) to `s6well`, then gave up the secret door after two bumps, walked
round and met Norris early (LIRA dead); p16c2 (20 bumps, traced: below); p16c3 (LOOK) to `s6pre12`, then Norris
killed three; **p16d1 (70707071, from `s6pre12`) beat Norris with nobody dead**, 1 try. Against c34d's
`bot_kuto.cfg` (taken after the bot's next town trip): the well's and Norris's flags agree (4A21-4A24, 4AA6/4AA7);
left: 4A0F, 4A12-4A14, 4A1F (Sokal Keep's, the bot's 0), 4A22, 4AB0, 4AC1, 4ADB, the counters.

New in plans.py (README of the format at its top):
- **The walker's gap closed:** a step that leaves the party on its square still facing the same way (the temple of
  Tyr's NO; a wall that looks open) is refused the third time running and walked round (`bumps <n>`: the n-th).
- `bumps <n> look`: a LOOK before each new try of such a step (a secret door: one LOOK found the catacombs' 5,8 N).
- `map 8:32`: the following walks' map when it isn't the area's own block (the catacombs).
- `answerfrom <words>|<choice>`: an answer that holds from that step of the plan on (CLIMB DOWN: NO, then YES).
- `cure` and `norest`: main's bot's `_prepare` where the plan's rest rule is the inn (Kuto's Well before Norris):
  the memorized cures in camp, no MEMORIZE or REST; `norest` makes the walks' stop after a fight that `cure`.

**In ours (segment.py, draws by cmpdraws.py):**
- **The catacombs' secret door (8:29, map 8:32, event 6 at 5,8), to main.** p16c3 (from `p2start/p16c1_s6well`,
  seed 60606063): draws 1-22 agree (the well's d11/d21, the arrow volley at 7,8, four d6 on reaching 5,8). The
  original rolls **eight** d6 there (OVR:03cc4; draws 19-26: 1 1 2 0 0 2 0 3) and the door stays shut; **ours
  stops at the fourth (the 0), prints YOU FIND A SECRET DOOR IN THE NORTH WALL and lets the party through.** The
  original then rolls eight more at the bump N (draws 27-34: **a blocked step runs the square's script again**;
  p16c2: 20 bumps, 160 d6, never found, zeros among them; ours draws none at a bump) and finds the door at the
  LOOK (five d6, 35-39). So without SEARCH or LOOK the original never finds it on a 0; ours does.
- **Norris's fight matches draw for draw** (p16d1 from `p2start/p16c3_s6pre12`, seed 70707071: 3110 draws, every
  figure's cells). After it, to Combat: **the LOOT list.** The original's ITEMS list pages (`ITEMS: TAKE NEXT EXIT`,
  then `TAKE PREV EXIT`; Chain Mail is its item 21, taken at row 24 after NEXT and 17 Ends); ours shows `ITEMS:
  TAKE EXIT` and scrolls, so the same keys took Studded Leather Armor (ours' screens `p16/t_15.png`, `t_32.png`,
  `t_55.png`). **And the lit member:** the original keeps the member lit on the treasure screen (4, ELWEN) into the
  walk and the camp (Home there lights CEDRIC); ours is back on ARN after the treasure (`p16/n_61.png`), so Home
  wraps to DORN (`n_77.png`) and MAGIC MEMORIZE does nothing: the replay parts there.

**Segment 7 (kuto -> slums3): reached `slums3`** (plan `plans/p16_c34d_07_slums3.plan`, lab `p16/seg07.plan`, from
`p2start/p16d1_s6k`): out of the well by 15,4 E, the Slums, the town trip (inn, sale, the halls: nobody had the
experience; `s7t`), back by 0,4 W, the bot's tour 2 4 5 8 9 7 13 14 15 16 17 18 with `prepare` / `heal` round each
and the walks going round event 20's squares (`avoid 20`), `s7pre20`, then **the trolls and ogres at 0,14 (event
20): won with nobody dead** (CEDRIC down, healed), checkpoint `slums3` (2:20 0,14 N; save `p2start/p16e2_slums3`).
p16e1 (seed 80808081) lost LIRA in event 15's fight at 3,11; **p16e2 (80808082) went through**, 3 fights. The party
is still ARN, BRAM, CEDRIC 3, ELWEN 1/1/1, LIRA 1/1, DORN 1/2 (c34d's bot there: CEDRIC 4, ELWEN 2/2/1, LIRA 2/2,
DORN 2/3: it had fought more). Against `bot_slums3.cfg`: 4ABB 254 against the bot's 255, 4A80 (15/18), 4A00,
4A0A/4A0B, 4A14, 4A17 (the Player's 255, the bot's 0), 4A97, 4A9B/4A9C (the bot's), 4AB0, 4AC1, the counters.
The plan now also checkpoints `s7a` (after 1,5) and `s7b` (after 6,10) for a reload.
- **The troll fight in ours: draw for draw, all 2445** (`segment.py p16e2 s7pre20 slums3 --tplog`; the trace cut at
  the checkpoint by `slicetrace.py logs/p16e2.trace.txt <segment txt> logs/p16e2.trace_s7pre20.txt`, new: cmpdraws.py
  lines up from draw 1, and a from-checkpoint segment starts mid-trace). One thing after the last draw: **the
  original's records show figure 9 moving twice more (23,9, then 24,10), ours ends the fight at the last draw**
  (the last draws are a round's "who acts next" for two ogres and four trolls; no draw follows in either): to
  Combat with the Lead's standing item (a fight ours ends while the original plays on). The replay then parts in the
  camp (the lit member after the treasure, as after Norris).

Lab: `p16/` (the plans, tries*.sh, slice.py, screens), saves `p2start/p16a2_s5r9`, `p16b2_sokal`, `p16c1_s6well`,
`p16c3_s6pre12`, `p16d1_s6norris`, `p16d1_s6k`, `p16e1_s7t`, `p16e2_s7pre20`, `p16e2_slums3`; runs p16a1-a2,
p16b1-b2, p16c1-c3, p16d1, p16e1-e2.

## Player 17 (2026-11-17): segment 2 in ours whole; segment 8 (`library`, the mirrors) and segment 9 (`podol`)

**Queue items 1 and 2 (reruns on main chat 48's and Combat Chat 18/19's fixes).**
- **Segment 2 in ours: 0 differences** (`segment.py p14b6 begin slums --start=p14b3_s2b --tplog`, statediff against
  the original's `slums`, on Combat Chat 19's 932a8a8). On Combat Chat 18's push the replay parted in the last camp:
  CEDRIC's CAST list read CURE LIGHT WOUNDS, CURE LIGHT WOUNDS, BLESS (the record's order since Combat Chat 18, the
  last spell lit), so `c c` cast BLESS where the original cured. The original's saves show its slot rule: a cast
  spell's byte is cleared in place and MEMORIZE fills the free ones (ELWEN's start record 0x28-0x2B: BLESS, 0, CLW,
  CLW 21; at `slums` the gap holds the new CLW); Combat Chat 19's MEMORIZE sorted by id gives the original's list here.
  p14b6 has no trace, so statediff is the comparison. (p13b5 is main's chat 48 request to Combat: draw 2351.)
- **The catacombs' secret door** (main chat 48): `segment.py p16c3 begin s6pre12 --start=p16c1_s6well --tplog`: draws
  1-46 identical to the checkpoint (the trace's later draws are past it); statediff: the counters 4AFA/4AFB only.
- **The loot list and the lit member** (Combat Chat 19): p16d1 **draws identical, all 3122** (every figure's cells);
  statediff 5: the original asks DO YOU WANT TO CLIMB DOWN right after CLIMB UP THE RUNGS (8:29 7,7), ours doesn't, and
  the replay's `n` reached ours' walking screen, where **N sets the clock to 20:00 (a lab key left live in the
  release: to main, flagged to the Lead)**; the rest are the counters 4AFA/4AFB.
- **The troll fight's end** (Combat Chat 19: not a difference): p16e2 **draws identical, all 2460**, statediff 0; cmpdraws still
  lists figure 9's two extra positions in the original's records (no draw follows them).

**Segment 8 (slums3 -> library): reached `library`** (plan `plans/p17_c34d_08_library.plan`, lab `p17/seg08.plan`,
from `p2start/p16e2_slums3`): the town trip as segment 7's (the sale, the halls: ELWEN, LIRA and DORN trained:
`s8t`), **the shops: Brass Mirrors at 15,8** (CEDRIC, ELWEN, LIRA, DORN bought one; ARN and BRAM were refused, no gold
or a full pack: the tool notes it and goes on, as main's bot, whose six all said OVERLOADED in c34d), two 10 Arrow for
LIRA at 13,8, `readyall` after each (`s8shop`), out by 3:0 0,4 W, 2:20 0,4 W, the well's 11,15 S, then the bot's 20
events 73 9 7 6 10 15 14 18 11 12 13 16 74 8 1 5 3 17 4 2 with `heal` / `prepare` round each: **`library` (2:15
12,6 W; save `p2start/p17a7_library`), 4 fights won, nobody dead** (the mad man and the basilisk: COMBAT, the bot's
two `menu >> 1`). Runs: p17a1-a6 tool stops (below), **p17a7** (seed 90909097, from `p2start/p17a6_s8shop`).
- **The mirrors in the original:** only a **readied** mirror turns a stoning gaze back on the gazer (GAME.OVR
  0x10908, Combat's `_act_powers`), and a mirror takes a hand. The original's READY refused it for CEDRIC, ELWEN and
  DORN (hands full) and took it for LIRA: so LIRA holds a mirror (her bow then can't be held: Player 5/6's note). The
  basilisk died in the fight before it gazed at anyone.
- The library's door at 8,2 N: after a failed PICK and BASH only KNOCK is left at every new bump (the original keeps
  the door's tries); on the way out the walker went round by 11,14 to 11,0 (`bumps 12` first).

**Segment 9 (library -> podol): reached `podol`** (plan `plans/p17_c34d_09_podol.plan`, lab `p17/seg09.plan`, from
`p2start/p17a7_library`): out by 11,0 N, the well's 15,11 E, the Slums' 15,4 E, the town trip (`s9t`), back by the
three 0,4 W exits (a fight in Kuto's Well), Podol (`cure` / `norest`: its rest rule is the inn; `s9in`), events 8 7 1
3 2 11 9 5 6 10 4: **`podol` (1:18 1,15 S; save `p2start/p17b2_podol`), 5 fights, nobody dead** (p17b2, seed
91919192). **Not the bot's way through:** no PLAZA AHEAD IS CROWDED question came (the bot answered DISGUISE), yet
0x4A35 (written only by that menu's answer, 1:18 0x9AAC) is 255, STRIDE BOLDLY FORWARD's, at `s9in`; the arrival took
0.6 s with no input wait. So no auction at 7,6, a fight at the tavern (4,8: CEDRIC took a Long Sword +1) and at the
robed orc (14,8). Against c34d's `bot_podol.cfg`: 4A34 2 (bot 64), 4A35 255 (254), 4A36 0 (1), 4A38 2 (0), 4A01 2
(22). Open for Player 18: rerun from `p2start/p17b2_s9t` with a trace and screens on arrival, find where 4A35 is set.

New in the tools:
- plans.py: an empty `buy` line is a visit that buys nothing (a `sell gems` visit takes one: p17a1 bought mirrors at
  the sale); a purchase refused is noted and skipped (was a stop); the pool's TAKE types at most 999 a round (the
  field takes three digits) and, when the TAKE leaves the pool as it was (more than the member can carry: p17a5,
  LIRA and 1036 platinum), EXIT and SHARE it instead.
- player.py `--after=<checkpoint>`: the `sell` / `buy` visits before the checkpoint are done too (p17a3 sold again).
- Plan answers learnt: the general store's `CAN I SHOW YOU SOMETHING` (YES), `BASH PICK KNOCK EXIT` (PICK), `LOCKED.
  BASH KNOCK EXIT` (BASH), `KNOCK EXIT` (EXIT: nobody has Knock; main's bot gives up so).
- segment.py: a rest of a day or more gets a wait more for every 2 hours of it (p16d1's last day rest was still
  running at F2: ours' clock 6 hours short); Godot's timeout is 900 s (`OP_SEG_TIMEOUT`). A wait an hour of every
  rest was tried first: p16d1's replay then passed 600 s and ours' save came out empty.

Lab: `p17/` (seg08.plan, seg09.plan, reruns*.sh, screens), saves `p2start/p17a2_s8t`, `p17a6_s8shop`,
`p17a7_library`, `p17b2_podol` (and `.lab/player/saves/p17*`); runs p17a1-a7, p17b1-b2.

## Player 18 (2026-11-17): Podol's question (the clerk); segment 9 redone the bot's way; replays with the original's rules

**p16d1 on main chat 50's CLIMB DOWN fix (663cf93):** draws identical (3122), statediff the counters 4AFA/4AFB only.

**Podol's DISGUISE question (queue item 1): the tool's plans never met the clerk.** Podol's on-init (1:18 0x998D) asks
THE PLAZA AHEAD IS CROWDED only when 0x4AB0 is 1 (the clerk's auction commission, 3:8 0xAA2A); otherwise it writes
0x4A34 = 0 and **0x4A35 = 255 itself** (so "written only by the menu" was wrong). City Hall's clerk is event 29 at 3:0's
5,5 (events 26-34 on New Phlan's map: 27 the hall, 28 outside her door at 4,5, 30 Cadorna at 6,5, 34 the guard).
Main's bot (`bot.gd _clerk`) walks to 4,5, turns to its facing 1 (**east**: ours' `"NESW"[_facing]`) and steps in; every
plan since Player 12's segment 1 said `step N` there, back to 4,4. So the original's run (segments 1-9) never had the
clerk's rewards (0x4ABB, 0x4AA7 stayed 254: cleared, not paid) nor her commissions; the bot's had them from segment 1.
- Decision (Player lane): the run goes on from segment 9 with the clerk, not redone from segment 1 (rewards are paid
  whenever the party next comes; the earlier segments stay a valid run of the original, a later-paid one). Board, to
  design, for information. Segments 1-8's plans keep `step N` as they ran.
- **Segment 9 redone** (plan `plans/p18_c34d_09_podol.plan`, lab `p18/seg09.plan`): the town trip's City Hall is the
  bot's round: in, the clerk (three reward pages, each a treasure screen, SHAREd as the bot), out; back in for the
  summons (the clerk again, then east to Cadorna, 6,5: the Textile House commission, 0x4A97 255); in once more. At
  `s9t` 0x4ABB 255, 0x4AA7 255, 0x4AB0 1, 0x4A97 255, as the bot's `library`; the rewards trained ARN, BRAM, CEDRIC
  to 4 and ELWEN, LIRA, DORN one level more (2/2/1, 3/1, 3/2). Podol then asked; DISGUISE; the auction (STAND, MAKE,
  FOLLOW), the buccaneer (CHALLENGE, ARN), LEAVE at the tavern and the robed orc. Runs: p18a1 (from `p17a7_library`,
  to the question: the tool's vmenu answer, below), p18a2 (from `s9t`: the tool's stuck limit in a long heal after
  the well's fight), p18a3 (to `s9b`, then a death), p18a4 (`s9b` -> `s9c`, a death), **p18a5 (`s9c` -> `podol`)**.
  Against the bot's `podol`: 0x4A34 64 and 0x4AB0 254 as the bot; 0x4A35 255 (bot 254: the cover blown, a 1-in-5
  RANDOM at 0xA882 or the tavern's 0xAC95), 0x4A38 2 (the robed orc's fight), 0x4A36 0 (overheard talk): the dice.
  Party at `podol`: ARN, BRAM, CEDRIC 4, ELWEN 2/2/1, LIRA 3/1, DORN 3/2.

**Segment 9 in ours** (on 4f4d19c):
- p18a1 (`library` -> `s9t`): **the well's east exit**: the original lands on 2:20 0,11, ours on 1,11 (ours carries
  the step on after the leaving script's CALL 0xC01E, main.gd `_arrival_event`; the same on 5b50367, so not 663cf93).
  In the Player's logs the original lands on the edge square in all 54 crossings (2:20/3:0 15,4, 2:20/8:29 0,4, 8:29
  15,4 E and 15,11 E, 2:15/8:29). To main. With `--ours-key=44:Down`: **the clerk's rewards, Cadorna, the halls: every
  flag and member equal; 8 differences: the clock (ours 4 hours later) and the counters.** The clock: the inn's REST
  offered 4:15 in ours (LIRA's DETECT MAGIC scroll to scribe: `learn_minutes` counts `scribe_pending`), 0:00 in the
  original, so the plan's 9 hours became 13:15. To Combat.
- **Ours ran the replays with the release's QoL switches on** (no settings.cfg in the shared user folder: REST
  REMEMORIZES put CEDRIC's cast CURE LIGHT WOUNDS back at the inn, the original's MEMORIZE keys found no free slot and
  the replay left the camp early). segment.py now runs ours in its own user folder (`<lab>/seg_xdg`, as diffcheck.sh)
  with a settings.cfg turning off every switch that changes play (`QOL_OFF`).
- p18a3 (`s9t` -> `s9b`: the question, DISGUISE, the auction, the duel): draws identical to the checkpoint (8214);
  statediff 6: the counters and **ARN's experience, ours 900 more** (the buccaneer duel, CHALLENGE with ARN). To Combat.
- p18a5 (`s9c` -> `podol`): draws identical to 10128; at 10129 **a fleeing GOBLIN GUARD**: after its run step (d2)
  from 33,24 ours draws "gets away?" d2, the original none (the next round's "who acts next"). To Combat.

**Segment 10 (podol -> textile), trip 1 of the bot's six: `s10a`** (plan `plans/p18_c34d_10_textile.plan`, lab
`p18/seg10.plan`, from `p2start/p18a5_podol`): `cure`, out by Podol's 0,11 W onto the band (7:26 11,28: WHICH
ENTRANCE, LEAVE), the band east to 12,27 and `step E` onto 13,27 (WHICH ROUTE at once: BOAT; the bot's "by 13,27 N" was
its facing), the boat to New Phlan's pier (3:0 15,1), west past the harbor master (he speaks only to a step north onto
11,1) and the temple of Tyr (11,2: HEALING YES, EXIT), the inn (`innwait`), the clerk twice (the Podol reward; **the
Valhingen Graveyard commission, YES: a Two-Handed Sword +1, +3 vs. Undead, BRAM**, as the bot), the halls, the inn
(`s10t1`), back by the three 0,4 W exits and Podol's 11,15 S into 4:2, events 23, 24, 1 with `heal` / `prepare`: **`s10a`
(4:2 4,10; p18b7, from `p2start/p18b6_s10t1`), nobody dead.** Runs: p18b1 (the band walk: the tool's AttributeError,
below), p18b2-b4 (the boat square, the pier's route: plan fixes), p18b5 (the stuck limit at the inn), p18b6 (to
`s10t1`, then 5 interrupted rests at the last heal), p18b7. Trips 2-6 to write: 2: events 2 4 22 5; 3: 12 13 16 14 15
20 21 (the box: TAKE IT UNOPENED); 4: 7; 5: 3 6 8 19 17 (the chained man: the bot answers FREE / UNLOCK three times,
then LEAVE "asked too often": the tool has no such count yet). Each trip leaves 4:2 by 0,11 W onto the band.

New in the tools:
- plans.py: a vmenu answer may be one word of a single item (the plan's DISGUISE for DISGUISE PARTY AS MONSTERS.).
- segment.py: ours with the original's rules (above).
- plans.py: `Walk.band_step` was a function nested in `hurt()` (Player 14's `route_refusing` and `hurt` had landed
  between Walk's methods), so every band walk failed (p18b1); back in Walk.
- player.py: the stuck limit is 4 x 300 keys for a heal goal (a hurt party's inn heal took more: p18a2, p18b5);
  `OP_STUCK_KEYS` sets the base.
- Lab: `p18/memflags.py <addr,...> <cfg>...` prints script bytes from ours' or the bot's .cfg (memory is the whole 64K).

Lab: `p18/` (seg09.plan, seg10.plan, memflags.py, archive.sh, old_src: 5b50367 for the crossing test), saves
`p2start/p18a1_s9t`, `p18a3_s9b`, `p18a4_s9c`, `p18a5_podol`, `p18b6_s10t1` (and `.lab/player/saves/p18*`; `s10a` is
`.lab/player/saves/p18b7/s10a`); runs p18a1-a5, p18b1-b7.

## Player 19 (2026-11-18): edge reruns; segment 1's inn since eae6114; segment 10 to `textile`; Combat's answers

**Main chat 51's edge crossing (302704b), the replays that cross an edge rerun** on 474e030: p18a1 (`library` -> `s9t`)
without `--ours-key=44:Down` the same 8 differences as before with it (main's fix confirmed; the clock was REST's
offer, Combat); p14b6 (segment 2) 0; p16d1 (6b) 2 (the counters); p18a3 6 and p18a5 its first difference at 10129 as
before. **p13a1 (segment 1) now 18 differences** (was 0): ours stops at New Phlan's inn on YOU DON'T HAVE ENOUGH
PLATINUM, the original's `s` paid with DORN (lit at WHO WILL PAY?). Ours' DORN holds the 9 platinum just before the inn
(the lab's `p19/money_probe.py`: ours saved at 4,11). Bisected on lab builds of each commit (`p19/src_<commit>`):
a19aed7 0, 9b677c8 0, **eae6114 18** (Combat Chat 18: `walk_selected`, LOAD_CHAR undone at EXIT / PROGRAM), f37a477,
7ce7091, d15afe3, 5b50367 and 1e7ef5c 18. Not segment.py's QoL settings (the release's defaults: 18 too) nor `--tplog`.
To Combat.

**Combat's answers to Player 18 (e8fc4e5) rerun on 1e7ef5c:** p18a1 5 differences (the counters: the clock now equal),
p18a3 5 (the counters: ARN's experience equal), **p18a5 0 differences, draws identical (11643)**.

**Segment 10, trips 2-5 to `textile`** (plan `plans/p19_c34d_10b_textile.plan`, lab `p19/seg10b.plan`, from
`p2start/p18b7_s10a`). Each trip: 4:2 0,11 W onto the band (LEAVE), 12,27, `step E` (BOAT), the town round of trip 1
(the clerk twice: no summons, 0x4A97 255 and 0x4A98-0x4A9A 0 every trip), back by the three 0,4 W exits and Podol's
11,15 S; then the bot's events. Checkpoints `s10t2`, **`s10b`** (p19a10), `s10t3`, **`s10c`** (p19b2), `s10t4`,
**`s10d`** (p19c2), `s10t5`, **`textile`** (p19d1, 4:2 2,15), nobody dead at any.
- **4:2's rest rule is the inn.** Main's bot never rested there (its tally: "4:2 rests 0"); every trip back to town in
  its log is "== to the inn to rest" after a fight left it hurt, and between events it cast its memorized cures. The
  first plan rested (`prepare` / `heal`) as trip 1: p19a3 (a death on the way back), p19a4 (destroyed in 4:2's
  interrupted rests), p19a5 and p19a7 (5 interruptions at 11,0), p19a6 (a death at event 2), p19a8 (5 at 5,9), p19a9
  (destroyed at 3,3). Then `norest` and `cure` in 4:2 (the bot's): trips 2-5 went through at the first try each.
- Event 22 is the whole floor of the house (every square but the rooms' events): the walk out avoids only the events
  still to come; event 7's room (6,14) opens only onto event 3's squares (the bot crossed one: its text printed).
- Event 13's body: the bot SEARCHes twice, then LEAVEs (its "asked too often"): `SEARCH*2`, then `LEAVE`.
- **Event 17's chained man: p19d1 LEFT at once** (FREE ATTACK PARLAY LEAVE matched the plan's older generic
  `ATTACK|LEAVE` before the new `FREE*3`); the bot tried FREE / UNLOCK three times, then LEAVE. No flag differs for it;
  the plan's answers are reordered for a rerun.
- **`textile` against the bot's** (`p12/cpdiff.sh`, `p18/memflags.py`): besides the clock, counters and members
  (levels, coins, items: our run's own), 4A32, 4A36, 4A38, 4A80, 4A9C differ already at `podol` (segment 9's dice);
  segment 10 adds **4AB8 (ours 255, bot 254) and 4AE4 (1, bot 2)**, both set at trip 4's event 7 (the ghouls; the bot's
  fight turned one and two got away): the dice.

**Segment 10's trip 1 in ours** (`segment.py p18b7 begin s10a --start=p18b6_s10t1 --tplog`, on 474e030 and 1e7ef5c): draws
identical to 989; **at 990 (the kobolds at 8:29 12,4, MAGIC ON) CEDRIC weighs a spell (d7 = 0), then the original
picks a target (d10 at 0x160DB) and moves 28,14 -> 27,13, ours picks a spell (d5) three times and a target**. To Combat.

New in the tools:
- plans.py: `answer <words>|<choice>*<n>`: a counted answer, given n times, then the next answer for the words applies
  (main's bot's "asked too often").
- plans.py: `OP_REST_INTERRUPTS` (default 5): a heal's interruptions before the stop.

**Segment 11 (textile -> nomads), open** (plan `plans/p19_c34d_11_nomads.plan`, lab `p19/seg11.plan`). Part A, the
town trip: **`s11t`** (p19e1, from `p2start/p19d1_textile`). Part B (to the nomads, 7:17, by Podol's 0,4 W, which lands on
the band's 11,28, and the band's 12,11): p19e2 (the band's SMALL WOODED GROVE: `WILL YOU ENTER|LEAVE` after the camp's
ENTER), p19e3 (the band's rests interrupted 5 times: `cure` there instead), p19e4 (the camp asks on arriving at 12,11:
`walk 12,12`, `step N`), p19e5 (the tool's hmenu answers are one word: STAY, DESTROY, ADVANCE, FOLLOW), p19e6 (the feast
at the ring's 3,12, the script's lodging at 9,12; then a `prepare` at 9,11 whose rests the kobolds interrupted three
times, and the walk on stopped: "in area 7:26, not 7:17" with the party still at 9,11, so the area bytes read 7:26 in
the nomads' camp then). **Next:** find what the area bytes hold there (p19e6's log, keys #400-#408), then the bot's
order: the lodging rest, 9,12, 0,0, `campday 3` (STAY), the step that sets off event 1 (DESTROY), the shaman's reward;
then its two town trips and 9,11 / 9,12 for `nomads`.
- plans.py: `campday <n>` (main's bot's): n day rests in camp whatever comes, an interrupted day counted, cures first
  (untested in the original: p19e6 stopped before it).

Lab: `p19/` (seg10b.plan, segment_qol.py, money_probe.py, src_<commit> builds, the pre-rerun replay outputs
`*.pre51.txt`), saves `p2start/p19a3_s10t2`, `p19a10_s10b`, `p19b1_s10t3`, `p19b2_s10c`, `p19c2_s10d` (and
`.lab/player/saves/p19*`; `textile` is `.lab/player/saves/p19d1/textile`); runs p19a1-a10, p19b1-b2, p19c1-c2, p19d1, p19e1-e6; `p19/archive.sh`.

## Player 20 (2026-11-18): segment 1's inn fixed; segment 11 to `nomads`; segment 10's trips 2-5 in ours

**Combat Chat 23's inn fix (8c87c86):** `segment.py p13a1 begin shopped --start=c34d_start13 --tplog`: **0 differences**
(was 18 since eae6114).

**Why p19e6 saw 7:26 in the nomads' camp:** its `prepare` at 9,11 rested before the bot's lodging, 9,12 and 0,0. The
first rest after the feast brought the headman's STAY, then one kobold wave a rest (ECL 7:17 0xB483 on 0x4A7E). The third
wave (0xB52A) is DESTROY THE KOBOLDS (0xB075 / 0xB30F), then the shaman's reward (0xB3D4), then `GOTO 0xA1C2`, whose
`NEW_ECL 26` (0xA1FC) puts the party on the band. The original then shows the walking screen with the camp's 3D view at
the same square (area bytes 7:26, 0x49FA not the band's mode) and asks nothing. The heal took that for a broken rest
and camped on in 7:26.

**Segment 11 part B to `nomads`** (plan `plans/p20_c34d_11_nomads.plan`, lab `p20/seg11.plan`; reloads: p20a1 lost on
the band at 11,27, p20a2 a stalemate in 8:29 at 12,4 with all on QUICK (stopped by pid), p20a3 from `s11t` to `s11k`,
p20a4 from `p2start/p20a3_s11k`). The bot's order: the feast (9,11), `cure` in the script's lodging, **`s11c`**, 9,12,
0,0, `campday 4` (STAY on day 1, waves on days 2 and 3, DESTROY on day 4, the shaman's reward, NEW_ECL 26), **`s11k`**.
Then trip 1 (the bot's "to the inn to rest": the boat, the temple, the inn), **`s11t1`**. Back by the band's 12,11
(ENTER), 0,0, out by 0,0 N, LEAVE at the camp. Trip 2 (the halls, the inn: nobody had the experience to train),
**`s11t2`**. Back, 9,11, 9,12: **`nomads`** (p20a4, 7:17 9,12 S, the bot's square).
- A save made right after NEW_ECL 26 (`s11k`) loads in 7:17 at 0,0. The step N then gets the camp's ENTER question at
  0,15, so the plan goes out by 0,14 W (THIS DIRECTION ... YES) and LEAVEs the camp, as the bot did.
- **`nomads` against the bot's** (`p12/cpdiff.sh`): the quest's flags agree (4A7C 9, 4A7E 3; 4AB8 now equal). New
  since `textile`: **4A22 (ours 10, the bot's 9): ECL 8:29's fight counter** (six references there; ours had 4 fights
  in 8:29 this segment, the bot 3: the dice), and **4A74 (1, the bot's 2)**: no script on the route mentions it (open).
- **In ours** (`segment.py p20a3 s11c s11k --tplog`; the original's trace cut at `s11c` by matching ours' first 12
  draws, `p20/p20a3_from_s11c.trace.txt`): STAY, then the walking screen, then wave 1 on the next rest, as in the
  original. But **wave 1 has 48 kobolds in ours and 36 in the original** (42 figures there, 54 in ours; 7:17 0xAF84 /
  0xAF8C load 0x6E81 each, from PARTY_STRENGTH at 0x9B24): draws identical to 628, then ours rolls more initiatives.
  To main (`ecl_vm.gd` `party_strength()`).
- plans.py: `campday` ends when a fight's script moves the party to another area.

**Segment 10's trips 2-5 in ours** (on 8c87c86): p19a10 (trip 2) 5 differences (the counters), draws identical (7986);
p19b2 (trip 3) the counters, draws identical to 9378. **p19c2 (trip 4) and p19d1 (trip 5) part on the band at 11,28:** the
plan's `right` there is a blocked move east. The original runs the square's event again (WHICH ENTRANCE WILL YOU TAKE,
answered `l`), ours only turns the party, so the `l` is a LOOK in ours (10 minutes, the question again) and the keys
fall out of step. Trips 2 and 3 never made that move. To main (the band's moves).

**The Lead's standing item (a fight ours ends while the original plays on):** p19e6's fight 1 (8:29 15,4, the
surprised gnolls; `segment.py p19e6 begin end --start=p19e1_s11t --tplog`): draws identical to 1348. In round 12 a gnoll
fleeing in panic ends at 23,13, next to ARN (24,12) and CEDRIC (24,14). The original draws two attacks (d20 17, d6 3,
then d20 13, d6 2) and plays on; ours draws ARN's only, then round 13's initiatives, and asks CONTINUE BATTLE. To
Combat. Also p20a3's first fight (8:29, the gnolls): LIRA's Sleep picks a target among 3 in the original (d3 at
0x160DB), among 2 in ours (draw 1434).

Lab: `p20/` (seg11.plan, the replay outputs `*.seg.out`, `*.cmpdraws.txt`, `nomads.cpdiff.txt`), saves
`p2start/p20a3_s11c`, `p20a3_s11k` (and `.lab/player/saves/p20a*`); runs p20a1-a4; `p20/archive.sh`.

## Player 21 (2026-11-18): segment 12 to `bane`; segment 13 to `library2`; `search`, `revisit`, a trainee's new spell

**Segment 12 (`nomads` -> `bane`)** (plan `plans/p21_c34d_12_bane.plan`, lab `p21/seg12.plan`): main's "town" (out by
7:17 8,15 S, the band, BOAT, the inn, City Hall, the halls, the inn: **`s12t`**), then 3:0 0,4 W, 2:20, 8:29, 1:18, the
band's 11,28 (LEAVE) and 13,27 SOUTH into 1:24 at 15,4 W (**`s12a`**). Trip 1: events 4 7 3 2 1 6 (the goblin slaves
KILL; **`s12b`**), out by 15,4 E (LEAVE), BOAT, the inn (**`s12c`**); trip 2: 5 8 9 11 12 10 (the hay beds SEARCH;
**`s12d`**), out by 15,11 E, the inn (**`s12e`**); back to 1:24 15,4 W: **`bane`**. Runs: p21a1 lost CEDRIC and LIRA to a
band fight before `s12t` (death rule: reload), p21a2 to `s12a`, p21a3 from `s12a` to `bane` (nobody lost).
- **1:24 walks on GEO1 block 31** (`map 1:31`; the bot's line says `map 31`), not block 24.
- **Event 5's trap door (10,9) is a find roll** (ECL 1:24 0x9DC2 -> 0xACE0: per member RANDOM 5 against SEARCH
  [0x6DCA] plus race bonuses): the original's party failed it, the bot's found it (scroll, potion, ring).
- **`bane` against the bot's:** 80 differences (79 at `nomads`); new only 4A2E 48 / 52 (bit 4: the trap door).
- **In ours** (on f5818d1): the town trip (`segment.py p21a2 begin s12a --start=p20a4_nomads --tplog`) parts at
  draw 119 of 4731, in the band's lizard men's fight setup: the original's wilderness clutter (GAME.OVR 0xD397-0xD459:
  for each ground-0x16 cell random(100), and if it is <= [bp-2], 0 here, a d10 for the kind, above 8 4 + d2, else
  (v + 1) / 2, then a d3 when 0xCE75 & 0x40), 16 of 16 times in the trace; ours only has the dungeon clutter
  (0x0C5D2). To Combat. 1:24 (`p21a3 begin bane --start=p21a2_s12a`): parts at 2967 of 13277 in the orcs' fight
  (event 4): LIRA (QUICK) weighs a spell d7 = 2, then ours draws "picks a spell" d1 twelve times before a target, the
  original a target d7 (0x160DB) at once. To Combat, with Player 19's (b).

**Segment 13 (`bane` -> `library2`)** (plan `plans/p21_c34d_13_library2.plan`, lab `p21/seg13.plan`): out by 15,4 E,
BOAT, the inn, the clerk twice, the arms shop (`sell gems share`), the halls, the inn (**`s13t`**); 3:0 0,4 W, 2:20,
8:29's 11,15 S into 2:15; segment 8's events 73 9 7 6 10 15 14 18 11 12 13 16 74 8 1 5 3 17 4 2 (**`s13a`-`s13d`**);
`search on`, `revisit 2 4`, `revisit 3 4`, `revisit 4 4`, `revisit 5 4`, `search off`: **`library2`** (p21b5 to `s13d`,
p21b6 from it; nobody lost). p21b1-b4 stopped on the new screens below.
- **Nobody knows Knock in the original here**: the party has trailed the bot's in experience since `slums3` (ELWEN
  15 max HP against 30 at `nomads`), LIRA and ELWEN were magic-users of level 1 at `bane`. Played in the bot's order
  anyway: PICK, then BASH where the bot KNOCKs.
- **This trip the party trained** (the clerics', magic-users' and thieves' halls, after the gems' sale and SHARE):
  ELWEN, LIRA and DORN went up, each left at exactly 5000 experience (the original's cap, "the level after next less
  1", which ours has: `party_member.gd` training_plan). Possibly the earlier halls' "TRAINING COSTS 1000 GP." (a member
  without 1000 gold of their own) is why the party fell behind: open.
- **`library2` against the bot's:** 72 differences; new: 4A2F 4 / 14 (the stacks: the original gave one book in 16
  visits, the bot three: the dice), 4AAB and 4AAD (0 / 254).
- plans.py: **`search on|off`** (the walking screen's SEARCH; the plan keeps the state) and **`revisit <event> <n>`**
  (main's bot's: the nearest square chosen first; on it, off to the first neighbour one step away, N E S W, whatever
  its event, then back); a running training seq answers **<NAME>'S SPELLS TO CHOOSE FROM** (bottom row CHOOSE SPELL:
  LEARN) with main's bot's LEARN_ORDER (Knock, Magic Missile, Sleep, ...; else the first offered). After SELL and SHARE
  some coins stay on the counter: the plan answers GO BACK AND GET YOUR MONEY with NO.

**Reruns on main's chat 54 (f9ad14d, the band's refused step):** p19d1 (trip 5, `segment.py p19d1 begin textile
--start=p19c2_s10d --tplog`): 10 differences at `textile`, draws agree to **984** of 2704 (were 19): ELWEN (QUICK) weighs
a spell d7 = 0, then the original picks a spell (d5 three times at 0x0B1CD), ours a target. To Combat (the same family).
p19c2 was rerun by main (5003 of 5410).

**Combat Chat 23's note on p17a7 (its re-run of the original parts at 990):** p17a7 ran with `OP_MAGIC=1` (Alt-M at
the fight's first poll, OVR:0bb90) from `p2start/p17a6_s8shop`, seed 90909097, `--after=s8shop`, plan `p17/seg08.plan`
(unchanged since); a re-run without `OP_MAGIC=1` leaves the original's QUICK casters without spells.

Lab: `p21/` (seg12.plan, seg13.plan, the replay outputs `*.seg.out`, `*.cmpdraws.txt`, `bane.cpdiff.txt`,
`library2.cpdiff.txt`), saves `p2start/p20a4_nomads`, `p21a2_s12a`, `p21a3_bane`, `p21b5_s13d` (and
`.lab/player/saves/p21*`); runs p21a1-a3, p21b1-b6; `p21/archive.sh`.

## Player 23 (2026-11-18): segment 17 (the kobold king) lost five of five and deferred; segment 18 to `band1`; segments 14 and 16 in ours

**Segment 17 (`kobold_caves` -> `kobold_king`)** (plan `plans/p23_c34d_17_kobold_king.plan`, lab `p23/seg17.plan`): out
by 10,15 (the truce kobold of event 3 asks again on the way: LET IT GO, the bot's answer), the boat, the inn (**`s17a`**;
then `innwait`: the rest had taken the party past hour 14 and City Hall was locked, 3:0's ECL 0x9920), the town (ELWEN
trained to MU 4), the trip in, `cure`, the throne room's door 8:13 4,4 (**`s17door`**: ARN 32/32, BRAM 52/54, CEDRIC
30/33, ELWEN 28/28, LIRA 22/22, DORN 29/32). The bot gives no order here: it reached `kobold_caves` with 0x4A8D = 5
already (the throne room and the king's quarters by shortcut restores in its segment 16).
- 8:13's ECL (`p23/ecl8_13.txt`): event 9 (4-6,3) is three fights in a row with no camp between: the horde (LOAD_MON 31 x4,
  0 x35, 1 x11: 50 figures), then the ballista (DAMAGE, then 120 x5, 0 x45, 1 x8), then the envoys; 0x4A8D 0 -> 1 -> 2 ->
  3 -> 4 ("THE KING HAS ESCAPED"). Event 20 (7,0 / 7,2, 0xA45B) is the king's guards (4 -> 5), event 11 (10,1, 0xA4C1)
  the pit (5 -> 6, 0x4AB6 = 254), event 10 (5,1) a secret-door search, events 24 and 25 nothing.
- **Five tries from `s17door` (p23a3-p23a7, seeds 23230003-07): the party destroyed every time in the first fight**,
  the horde (56 figures; at the wipe 16-23 still standing). **Deferred** (lane decision, as Sokal's event 9): events 9,
  20 and 11. Consequence: 0x4A8C (the Bivant commission that opens the Buccaneers' base, 6:25 12,31) stays 0 (board,
  to design).
- **The same fight in ours** (`segment.py p23a4 begin end --start=p23a3_s17door --tplog`, `p23/p23a4.cmpdraws.txt`):
  **draws identical to 16203 of 26521**, and ours loses too (THE PARTY HAS FALLEN). At 16204 a KOBOLD LEADER shoots BRAM
  "from behind": d20 = 15 hits in ours (needs 15), misses in the original (it shoots again: 19, then d6). To Combat.

**Segment 18 (`kobold_king` -> `band1`)** (plan `plans/p23_c34d_18_band1.plan`, run p23b1 from `p2start/p23a3_s17door`):
`kobold_king` taken at the door (the deferred state), out by 10,15, the town (**`s18a`, `s18t`**), 2:20, 8:29, 1:18,
7:26 2,20 and the step W onto 6:25 14,20 W, `cure`: **`band1`**. Nobody lost, everyone at full HP. Against the bot's
`band1`: 81 differences; new 4A8C 0 / 255, 4A8D 0 / 6, 4AB6 0 / 255 (the kobold king), 4AC1 6 / 7.

**In ours (on 122d6fb, main chat 57):**
- p22a4 (segment 14, the cabinet's trap roll; main's (d) fix): **draws identical through all of ours' 7942** (was 5473),
  86 differences down to 5 (4AFA-4AFF: the tail seen in every segment). Main's PARTY_CHECK fix confirmed.
- Segment 16: p22c4 identical to **1744** of 16466: a fleeing KOBOLD LEADER, after its eight run moves (d2s at 0xB492),
  shoots DORN twice in ours (d6 target, d20 d20), the original goes on to the next round's initiatives; ours then ends
  the fight where the original plays on (to Combat). p22c5 parts at 1163 (a QUICK caster's spell pick: the Alt-M timing
  below), p22c7 at 162 and p22c8 at 49 (the wilderness clutter, Player 21's (a)).

**Tools:** `segment.py` sends ours `magicat=<draw>` for a fight's Alt-M (Combat Chat 25's request: the original reads
the harness's Alt-M some computer turns late): from `OP_MAGICAT=<draw>,<draw>,...` (one per Alt-M of the run in turn,
`-` for a plain `magic`), or for a `begin` replay from the trace's `MAGIC 1 between draws <a> and <b>` lines (the lab's
`trace.py` is now the repo's, which prints them). Checked only to the point that ours takes the key: p21a3 with
`OP_MAGICAT=2987` put 2987 on the first Alt-M, which belongs to fight 1 (the original's MAGIC on by 949 there), so it
parted at 950. The per-fight values from the old trace (the last spell weighing with no list before the first with
one): fight 1 (from draw 2) 928, fight 2 (from 1985: 1:24's orcs) 2987; the rest not worked out. Stopped there (the
Lead's stop).

Lab: `p23/` (seg17.plan, seg18.plan, `*.seg.out`, `*.cmpdraws.txt`, `band1.cpdiff.txt`, `ecl8_13.txt`, `ecl3_0.txt`,
`trace_before_p23.py`, `archive.sh`), saves `p2start/p22c8_kobold_caves`, `p23a2_s17a`, `p23a3_s17door` (and
`.lab/player/saves/p23*`); runs p23a1-a7, p23b1; archive `player23_lab.tar.gz`.

## Player 24 (2026-11-18): `magicat=` settles the QUICK casters' replays; segment 19 to `pyramid1`; segment 20 to the mage

**The Alt-M replays with `magicat=`** (Combat Chat 25's request). The draw for an old trace, per fight: the last spell
weighing (OVR:0b16c) with no list (no OVR:0b1cd right after it) before the first with one, plus 2 (lab
`p24/magicat.py <trace> <fight start draw> ...`, `p24/weigh.py <trace>` lists every weighing, L = with a list).
**segment.py now sends a `magicat=<draw>` key where the walk to its fight began** (after the previous fight's end, or
at the segment's start), not at the Alt-M's place: ours' QUICK fight can play past the draw before a key sent mid-fight
arrives (p19d1: ELWEN's turn at 980 came before `magicat=958` reached ours). Ours keeps the draw
(`Combat.magic_at_draw`, static) until a computer turn reaches it. A plain `magic` (no draw known) stays where it was.
- **p21a3** (`OP_MAGICAT=928,2987,4677,6891,9608,11479,12736`, `OP_SEG_TIMEOUT=1100`: ours needs ~15 minutes, so run
  it in the background and poll): **draws identical, all 13277; 0 differences at `bane`** (was 2966).
- **p19d1** (`OP_MAGICAT=958`): **draws identical, all 2704; 0 differences at `textile`** (was 984; the reverse case was
  the key's timing too).
- **p22a1** (`OP_MAGICAT=1020,2300`; the second fight drew no list before the trace ends): identical through all of
  ours' 1279 draws to `s14a`, only the 4AFB/4AFC tail (was 943).
- **p22c5** (`OP_MAGICAT=1194`): past 1163 to **2124**, the wilderness clutter (Player 21's (a), with Combat).
- **p17a7** (on 61b091b with `GBR_PLAYOUT=1`; Combat 25's helpless shot): without `magicat` identical to 5165 (was
  3232: BRAM's bow settled), then the basilisk fight's QUICK CEDRIC (MAGIC not yet on in the original); with
  `OP_MAGICAT=968,2827,5167` (Alt-Ms in fights 1, 2 and 4; fight 3 had none): **draws identical, all 5289**, only
  the 4AFA-4AFF tail.
- p22c4 with `GBR_PLAYOUT=1`: still 1744 (the fleeing kobold leader's shot: Player 23's (b), open with Combat).

**Segment 19 (`band1` -> `pyramid1`)** (plan `plans/p24_c34d_19_pyramid1.plan`, lab `p24/seg19.plan`; runs p24a1-a4
from `p2start/p23b1_band1`, reloads from `p2start/p24a1_s19t`): 6:25 15,20 E onto 7:26, 12,27 E into the town, the inn
and `innwait` (**`s19a`**), seg18's town round (City Hall twice, sell and buy, the halls), the inn (**`s19t`**); 2:20,
8:29, 1:18, onto 7:26; round the poisoned river's west side to **6,14, the rowboat's own square** (TAKE IT TO THE
PYRAMID YES, the secret door ENTER: 7:22 15,0 S), `cure` (**`s19p`**); 15,7 and a step W onto the rocks (14,7: on a
first visit with SEARCH off, the flash into 7:23 4,15): **`pyramid1`** (7:23 4,15 N, as the bot's). No fights in
p24a4, nobody hurt. Against the bot's `pyramid1` (`p24/pyramid1.cpdiff.txt`): 86 differences, new beside `band1`'s
only the clock and coin kind 5 (the sale); the pyramid's flags agree.
- Lane decision: main's ten LOOKs at 7:22 15,0 (SEARCH on, facing N) are left out: they teach main's route finder the
  door north (0x9A0B) and cost 100 minutes; the original's party needs nothing from them here.
- **The wilderness has no map in the tools** (the band walk is greedy and stops at water): new `bandmap.py <band 6|7|8>
  [x0,y0 x1,y1] [--river-ok]` reads START.EXE's overland map (format as ours' `scripts/formats/overland_map.gd`) and
  prints the band, or a BFS route as waypoints. p24a1 stopped at 7:26 6,22 (the river, 0x4AA2 unset); p24a2 found
  6,14 is the rowboat (the plan's step N was wrong); p24a3 met RUINED HUTS (5,26 on the new route: LEAVE, main's
  bot's "only passing", c34d 26690).
- 7:22's ECL: lab `p24/ecl7_22.txt` (`tools/ecl.py dis game/ECL7.DAX 22`).

**Segment 20, first part (`pyramid1` -> `s20m`)** (plan `plans/p24_c34d_20a_mage.plan`, lab `p24/seg20a.plan`; runs
p24b1-b6 from `p2start/p24a4_pyramid1`, `p24b1_s20a`, `p24b5_s20f`): 7:23 in the bot's order: events 5, 3, 4, 18, 1, 2,
then 6 (3,13, five lizard men: **the original's reaction roll gave COMBAT WAIT FLEE ADVANCE, not the bot's "wary"
PARLAY menu**, so the party fought and won; 0x4A51 bit 1 is set either way, the parley sets nothing more:
`p24/ecl7_23.txt` 0x9E76-0x9F94; **`s20a`**), 7, 8, the rocks at 15,12 (THROW A ROCK, MOVE ON: to 11,3), **round to 13,3
and a step W onto the second rocks room** (12,3 opens only east; 11,3 only south), to 0,4, 0,3 and a step N onto the
third (to 0,0), 1,1 (the password NOKNOK), 2,1 (the fountain: MOVE QUICKLY AWAY; **`s20f`**), 4,1 (locked: PICK then
BASH; the mage and his mutated guards, 13 figures): **p24b5 destroyed, p24b6 won** (nobody dead; ARN 3/32): **`s20m`**
(7:23 4,1 E; 0x4AB3 = 254, the commission done). Left of the segment: the rest, the dial (event 26, NO), the
teleporter (event 16, 6,0) into 7:22, and the bot's 7:22 wanderings, town trip and return (c34d 30288-31048).
- **The harness and animated pictures** (`game.py`): 7:23's fountain animates while its text box waits; the two reads
  of the key polls name different callers and the screen's rows never read the same twice (the picture's rows are read
  as text), so the harness saw "busy" and stopped (p24b2-b4). Now: with the poll count moving, a known input site
  among the two callers is the wait; a known site whose text box (rows 17-24) reads the same over five reads is
  settled; and after 15 s busy, a text box asking PRESS BUTTON OR <RETURN> that reads the same twice is the menu's wait.
- 7:23's ECL: lab `p24/ecl7_23.txt`.

Lab: `p24/` (seg19.plan, `*.seg.out`, `*.cmpdraws.txt`, `pyramid1.cpdiff.txt`, `bot_band1_pyramid1.txt`,
`ecl7_22.txt`, magicat.py, weigh.py, bandmap.py, `archive.sh`), saves `p2start/p23b1_band1`, `p24a1_s19t` (and
`.lab/player/saves/p24*`); runs p24a1-a4, p24b1-b6 (`p24/tries.sh`); saves also `p2start/p24a4_pyramid1`, `p24b1_s20a`,
`p24b5_s20f`; archive `player24_lab.tar.gz`.

## Player 22 (2026-11-18): segments 14 to `kovel`, 15 to `band3`, 16 to `kobold_caves`; segments 13 and 14 in ours

**Segment 14 (`library2` -> `kovel`)** (plan `plans/p22_c34d_14_kovel.plan`, lab `p22/seg14.plan`): out of the library
by 11,0 N (the spectre: ARN drained to level 2, as the bot's), 8:29 15,11 E, 2:20 15,4 E; the clerk twice, the arms
shop (`sell gems share`), the halls, the inn (**`s14t`**); then Kovel Mansion (3:14, from the band's 13,27 NORTH, 15,4 W)
in the bot's four trips with the inn between (out by 11,0 N, the north edge LEAVE, 13,27 BOAT): events 2 1 8 14
(**`s14a`-`s14c`**) | 15 (the two thieves: chase, SOUTH; **`s14d`, `s14e`**) | 16 17 19 6 12 20 7 13 18 (**`s14f`-`s14h`**)
| 3 9 4 10 5 11: **`kovel`** (3:14 14,14 S). Runs: p22a1 (to `s14a`), p22a2 (stopped at 3,13 by a tool fault, below),
p22a3 (stopped by hand: a lock answer that couldn't match), p22a4 (to `s14g`, stopped in the inn's heal, below), p22a5
(to `kovel`). Nobody lost.
- **The original's party finds Kovel's traps; the bot's never did** (ECL 3:14 0xB3A2: `PARTY_CHECK [6BA7], 0, ...`, then
  RANDOM 99 against the second cell): event 8 (4,3), the cabinet (event 12, 3,13) and casket A (event 13). The menu
  AVOID TRAP / DISARM TRAP has no rule in main's bot (its party never saw it): the plan takes the bot's default, the
  first item (AVOID), and the bot's three-asks rule on the cabinet (EXAMINE*3, then LEAVE). So the scrolls (4A47 bit 3)
  and the casket's gems (4A46 bit 0) stay. AVOID then EXAMINE again rolls again; once (p22a2) the trap went off.
- Locks (cabinets, caskets): the bot PICKs once with the best at locks (DORN), then BREAKs: in the plan a counted
  `answerfrom <words>|PICK*1` per lock with its own words (a count is per words and choice), BREAK the standing answer.
  Words that end in `?` never match (the screen reader strips it).
- **`kovel` against the bot's:** 84 differences; new only 4A46 / 4A47 (the two untaken trap rooms) and the clock.

**Segment 15 (`kovel` -> `band3`)** (plan `plans/p22_c34d_15_band3.plan`): out to the inn (**`s15a`**), the clerk, the
shop, the halls (ARN trained to 3), the inn (**`s15t`**); 3:0 0,4 W, 2:20, 8:29, 1:18, the band's western edge LEAVE,
15,20 and the step E off it into 8:27 (3,20 E; the bot's "by 15,20 E" is the square stepped *from*: p22b1 stopped on
it, p22b2 made the step): **`band3`**. No trolls this time (a random encounter). 73 differences; new 4A00 / 4A02 (0 in
the original, set in the bot's).

**Segment 16 (`band3` -> `kobold_caves`)** (plan `plans/p22_c34d_16_kobold_caves.plan`): the boat at 8:27 9,29 (walk to
9,28, step S: a walk onto a square whose script moves the party ends in the wrong area), the temple of Tyr, the town
round (**`s16a`, `s16t`**); into the caves by 8:27 6,15 (from 6,16 step N: LARGE, then NO to DO YOU WANT TO LEAVE; the
bot's YES/LARGE loop left out); out by 8:13 10,15 (from 10,14 step S: YES), `cure`, and straight to the boat as the bot
("to the inn to rest"; a `prepare` at the cave mouth met fight after fight: p22c3). Trips: 17 (**`s16b`-`s16d`**; p22c2
lost ARN there, reloaded) | 16 6 5 4 (**`s16e`, `s16f`**) | 5 4 6 16 17 26 18 19 8 (**`s16g`-`s16i`**) | 19 4 5 6 16 17 26 18 21 8 25 (**`s16j`-`s16l`**) | 17 26 18 16 6 5 4 19 8 21 22 7 2 1 28 (**`s16m`**): **`kobold_caves`** (8:13 6,15 S). Nobody lost in the end (p22c2 ARN and p22c6 LIRA died: reloads). **Event 9 (4,3, the throne room) walked round
(`avoid 9`)**: the bot wiped there seven times and went on by logged shortcut restores; main's plan wins it by
shortcut in log 11b. Events 24 (4,2), 10 (5,1) and 20 (7,0) lie behind it (p22c7: no route round 4,3): deferred with it. On the band `cure`, not `prepare` (p22c5: the rest at 8:27 3,20 was interrupted five times). Against the bot's `kobold_caves`: 91 differences; new 4A8D 0 / 5 (the throne room's story, event 9 left), 4A01-4A18 (1 in the original), the place.

**In ours (Player 22, on 981bd33 / 44811de):**
- Segment 13: p21b6 (`s13d` -> `library2`) **0 differences, draws identical**. p21b5 (`bane` -> `s13d`) parts at draw 58:
  the arms shop's APPRAISE draws from its own generator in ours (`shop_screen.gd` `_rng`), the original's from the
  game's (GAME.OVR 0x26900 per gem, 0x26B8D and START.EXE 0x8D1D per piece of jewellery); then nobody trains in ours.
- Segment 14: p22a1 identical to 943 (the QUICK caster's spell pick, Player 21's (b)); p22a2 to 1962 (**ours kills
  Kovel's thief, the original's goes down dying and the fight plays on**: one point of HP or damage); p22a4 to 5473 (the
  cabinet's trap-find roll: ours' PARTY_CHECK cell is the party's average); p22a5 **0 differences, draws identical**.
- Segment 15: p22b1 parts at 77 (APPRAISE again).
- Segment 16: p22c3 (`s16b` -> `s16e`) identical to 1183 of 57219: at the fight after the walk out of the caves the
  original draws a d8 at GAME.OVR 0x280A2 (when DS:0x6C94 is set) before the monster colours; ours doesn't.
- p17a7 (Combat 23's note): identical to 3232; the original's BRAM readies his flail and shield during the kobolds
  (`s8b` -> `s8c`), ours keeps shooting. All to Combat and main (board, Requests "player (Player 22)").

Tools: `screens.py`: a "PRESS ANY KEY TO CONTINUE" at EXE:07cc6 (a trap's text) is an enter screen, not the wipe;
`plans.py`: the heal's MEMORIZE pages back with PREV from the last page (ELWEN's MAGIC MISSILE before SLEEP).

Lab: `p22/` (seg14.plan, seg15.plan, seg15b.plan, seg16.plan, `*.seg.out`, `*.cmpdraws.txt`, `kovel.cpdiff.txt`,
`band3.cpdiff.txt`, `kobold_caves.cpdiff.txt`, `readme_section.md`), saves `p2start/p21b6_library2`, `p22a1_s14a`, `p22a2_s14e`, `p22a4_s14g`, `p22a5_kovel`,
`p22b1_band3`, `p22b2_band3`, `p22c2_s16b`, `p22c3_s16e`, `p22c4_s16f`, `p22c5_s16i`, `p22c7_s16j` (and `.lab/player/saves/p22*`); runs
p22a1-a5, p22b1-b2, p22c1-c8; `p22/archive.sh`.

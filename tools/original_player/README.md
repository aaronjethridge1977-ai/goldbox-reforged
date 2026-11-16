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

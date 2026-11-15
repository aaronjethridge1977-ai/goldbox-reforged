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

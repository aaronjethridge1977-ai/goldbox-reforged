# Test lab

## Current method (read this first)

This page is the lab as it is used now. The history, chat by chat, with the detail behind each command, is in
[HISTORY.md](HISTORY.md). A chat that changes the method updates this page in the same push.

**Where the labs run**
- Main lane: Claude Code in WSL Ubuntu on Jeremy's PC, lab at `/home/claude/lab`, both repos in `~/gbr`
  (`/home/claude` links to `~/gbr`), 12 threads. Setup: `~/gbr/restore_lab.sh` restores a lab archive
  (`labNN.tar.gz`, kept in the Windows `.lab` folder: `/mnt/d/ai_projects/goldbox-reforged/.lab`), then
  `./check_godot.sh /home/claude/goldbox-reforged`. The lab keeps its own copy of the game files in `game/`; the
  Windows folders are read only, except for writing the lab archive at the end of a chat.
- Side lane: the cloud workspace, its own lab built with `rebuild.sh` (see "The whole lab inside the cloud
  workspace").
- The original runs in DOSBox Staging and our engine in Godot 4.7.2, both on virtual displays (Xvfb).
  Game files, `font.json`, `wheel.json` and `wheel_solver.py` stay in the git-ignored `.lab` folder or the lab, never in a repo.

**Before every push** (CLAUDE.md): fetch and rebase; `./check_godot.sh`; `~/gbr/checks/diffcheck.sh <repo>` when
`scripts/` or `content/` changed (10/10 or no push; lab-independent, its own data in `~/gbr/checks/data`, chat 30);
`refcheck.sh` after any change to
`scripts/dev/bot.gd` (3:11 and 5:5 must not drop below `data/refcheck_base.txt`; since chat 21 each area replays the
baseline's dice seed from `data/refcheck_seeds.txt`, so a difference is the code's, not the dice's: on one code a fresh
seed had moved 3:11 between 83% and 88%); `git status`. A push that
changes game behaviour adds a line to the board's "Rule changes".

**Coverage (M6, main lane)**
- One area per run: `tools/plans/cover_<set>-<block>[-variant].plan` (a checkpoint, travel, then
  `cover <area> <minutes> [all] [full] [states=<n>] [seed=<hex>] [only=<events>]`). Runs are started with
  `runcover.sh <area>` or `cover_all.sh <area> ...`, resumed with `cover_resume.sh`, and summed with
  `covsum.sh` (one line per area, SCRIPT ERROR counts included); `merge_cov.py` unions results.
- What a run does: walks every part of each map, arrives at each event square from every open side, uses
  SEARCH and LOOK, wins every fight at once by logged shortcut (and flees each set fight once), replays
  every untaken menu choice from a snapshot (WHO, encounter, PARLAY and dice jobs included; a die of more
  than 8 values gets jobs for the values the script compares it with; a number prompt gets 1, 100, 1001 and
  9999), and walks the
  flag states the run opens, quest flags first (up to 16). State walks are light by default; an area's
  closing run uses `full`. Every run logs its dice seed, so it can be replayed.
- Speed and repeatability: `bot.sh` runs Godot with `--fixed-fps 1000` (a fixed frame, no real-time sync) and
  `--fast --no-draw --time-scale=1000`, so a run walks the same on a busy machine as on an idle one; every
  generator draws from the run seed (`== run seed <hex>` in the log; `seed=<hex>` on the plan's cover line
  replays the whole run). An `-all` run takes 1-4 minutes. In parallel (measured): 8 lanes while Jeremy uses the PC,
  10 when it is idle (P=10: 3.9 runs a minute; P=12: 4.1 at 100% CPU; memory and swap never the limit). One
  area's variants in one lane. `dettest.sh` re-checks the repeatability.
- Report: `covreport.sh <abs file> --areas= --missed= --critical=`; `--dead=<block>` lists dead outcomes
  with the rule behind each; a `DEAD BUT TAKEN` line means a dead rule is wrong.
- Finding the way to a missed branch: `CHAIN=1 ./missctx.sh <area>` (tests from the entry to each missed
  branch, with each byte's writers from `data/writers.json`), `misswhy.py` (a first guess at the reason),
  `mkreasons.py` (a first draft of the area's reasons table). Variants are hand-built plans, each a state
  some script writes, and each is logged (`shortcut flag`, `teleport`, `item`, `npc`, ...).
- Maps: `geo.sh mapdump|mapparts|mapedge <GEO file> <block> [x,y ...]` shows a map's walls, doors and events,
  its connected parts, and a square's four sides (a door can be on one side only).
- Variants of one area share `data/cov_<area>.json`: keep them in one lane and don't run them at once.
- Results go in `docs/coverage-areas.md` (per area, with reasons) and `docs/cover-fights.md` (fights won by
  shortcut, for the combat suite).
- **Done** for an area: 90% of reachable instructions, 85% of reachable branches, 100% of story-critical
  paths, every leftover listed with a reason. **Stuck areas** (hand-play rule, ideas/game-modernizer.md 2026-11-14):
  bot run, two directed attempts; if they add < 1 point, play the area by hand in the lab (~1 hour), leaving a key
  list or plan that replays it; still unclear: a save and a Test List request; then close with reasons. DOSBox
  questions are answered in the lab, not by Jeremy (Methods 3). M6 coverage ends when all 29 are closed (done in
  chat 21).
- Keyed replays for coverage (chat 21): `ours.sh --save=<any .cfg> --keys='load=<letter>,...' --coverage=<file>` records
  coverage from a lab save outside the bot (it adds to the file); merge with `merge_cov.py`. Kept as a script per area
  (`hand_2-9-toll.sh`: the toll paid by a poor party; lab save H, never J). A plan can also answer another area's
  arrival menu (`answer 8:27 WHAT CAVE|LARGE`) and place the party (`shortcut teleport 8:13 5,4 N`).
- Jobs queued inside a flee or ally job inherit it (chat 21): a menu that comes only after a fled fight (8:13's
  SURRENDER OR DIE) is replayed fleeing the same fight.

**Differential checks (main lane, from chat 20)**: `docs/diff-checks.md` (how to run one, the ignore list with
reasons, each event's start save and result). `mksave.py ... item<n>=<DAX>:<block>:<index>` gives a member an item.
Never save over the shipped saves (J is every `mksave.py` save's base; chat 20 restored it from the game folder):
the checks save to F.

**Full screen (P25, chat 22):** a run embedded in the Godot editor's Game tab can't change its window mode, so
Alt+Enter / F11 only flip the setting there; test full screen in a floating window ("Embed Game on Next Play" off) or an
export.

**Walking-screen checks (chat 22):** `ours.sh --save=<writable .cfg> "--keys=load=F,...,screen=<png>"` saves our
320x200 screen; lab save F (New Phlan 14,5) has poked spells for CAST; `automap` prints the squares the automap holds.

**Full runs and lab saves (chat 22):** a full run from creation: `BOT_ID=<id> BOT_TIMEOUT=36000 BOT_COVERAGE=$PWD/data/cov_<id>.json
BOT_BRANCHES=$PWD/data/br_<id>.json BOT_CHECKPOINTS=$PWD/data/checkpoints_<id> ./bot.sh playthrough.plan > data/<log> &` (its own
coverage files, not merged; about an hour to the end of the plan). Start saves for checks 6-9 are kept in `data/diff_<area>_start/`
(copy into `game/`); lab save G is the scratch slot; ours can write a start save in the original's format from inside an area
(`at=`, `mem=`, ENCAMP, SAVE): such saves load in DOSBox since chat 22.

**Chat 23:** a full run resumes at a checkpoint of an earlier run: copy `bot_<name>.cfg` and `.json` from that run's
user folder (`~/.local/share/godot/app_userdata/Gold Box Reforged bot <id>/`) and add
`--resume=<path>/bot_<name>.cfg:<name>` after the plan (about 10 minutes from `valjevo4` to the end). Plan answers can
hold on a flag: `answer <area> [4A4D&1=1] <words>|<choice>`. `seed.py` and `trace.py` need
`kernel.yama.ptrace_scope` 0 (`sudo sysctl kernel.yama.ptrace_scope=0`; WSL starts with 1, and the fight traces come
back empty). Never `pkill -f` with a pattern that is in your own command line (it kills the shell running it).

**Combat Chat 3 (cloud lab):** lab keys `temple` (the temple screen on the party) and `poison=<member>` (poisoned as a
fight leaves one: dead, effect 0x37); `posdump.py` prints the running original's figures and cells; `seed.py`/`trace.py`
now find DOSBox under `pl.py` too (they took its `sh` wrapper's pid). The original's memory while a fight runs:
the ground table DS:0x2744 (4 bytes an id: move cost, 0, sight, picture). Ad hoc scripts in the lab archive's
`combat3/` film the original's screen (`p40film.py`, `restfilm.py`).

**Chat 24:** `trace.py` needs `re/start.img` (the unpacked START.EXE: `mkdir -p re && python3 unexepack.py game/START.EXE
re/start.img`); without it the trace reader dies at once and `cmpfight2.sh` compares an empty original trace. This lab's fight
tools are synced from the repo's `tools/lab/` (older copies in `data/old_tools_c23/`). With the trace patch installed the
original waits for a reader at every draw: keep `trace.py run` going whenever `seed.py` has been used. Ours' keyed runs
need `wait`s after `fightend,n` before Enter (the won screen and the treasure take a few frames). `pathkeys.gd`
(`geo.sh pathkeys <GEO> <block> <x,y> <goal> <facing> [hedges|-] [avoid x,y ...]`): the shortest walk on one map as
`--keys`, never through an event of 30 or more (5:5's ways out), and the open edges. The ending by hand: `data/ending_c24/`
(c23c's `valjevo6` checkpoint, `route_v3.txt` to 5:7's 3,6, `hall_door_v3.cfg` saved there, `finale_keys.txt` from it to
New Phlan); `screen=` now also captures the closing pictures.

**Lab rule (Methods 5):** a script stops only the DOSBox it started: `orig.sh` keeps its DOSBox's pid in `/tmp/gbr_dosbox_98.pid` (reused while alive), `./orig.sh stop` stops that one and the trace reader in `/tmp/gbr_trace_98.pid`; `seed.py`/`trace.py` attach to it first.

**Combat Chat 4 (cloud lab):** `fallen.py` prints the running original's fallen list, figure table and ground around
the fight (a body is ground 0x1F); `poison=<member>` in an open fight now also downs the fight's copy of the member
(poisoned dead on its square, for Slow Poison on the body). In the original, MOVE's **Esc undoes the walk** (use Enter to
keep steps in lab key lists) and EXIT from a spell's aim asks ABORT SPELL? (YES spends the spell). A poison fight from a lab
save: `mksave.py J A 4 21 14 9 N`, walk to 12,7, then east and north into 14,6 (Sokal Keep's frogs; flee the undead patrols);
give the party 200 HP, AC 10 so they are hit and poisoned. Ad hoc scripts in the lab archive's `combat4/`.

**Combat Chat 5 (cloud lab):** the late fights need start saves that `mksave.py` alone can't make (4:10's first visit puts the
party at the gate whatever the save says: area entry clears 0x4A00-0x4A1F). Recipe: `mksave.py J A ...` plus
`combat5/levels.py A` (the party at levels 4-6 with the class tables' THAC0 and saves written, since ours reads them and the
original recomputes them), let the original walk in and SAVE to A, then set the square in SAVGAMA.DAT at 0x3201 (x, y,
facing x 2). The result is kept in the lab archive as `combat5/saves/<fight>/` (game data: never in a repo) and
`savein.sh <fight>` copies it into save A (scratch) before `cmpfight2.sh A ...` (regress.sh's `orig_A_spectre`).
`HOLDFULL=1` with `HOLD=` makes `trace.py` dump the original's whole 50 x 25 combat map (ground icons). `combat5/chrpoke.py
<letter> <n> off=val[,4]` pokes character-file bytes. cmpdraws.py leaves out a step the trace shows twice around free
attacks (the original puts the mover back on its square while the blows land).

**Chat 25:** `pl.py stop` (and `start`) now kill only this lab's DOSBox (`[d]osbox -conf .*/por.conf`): the Player lane
runs its own beside it (`player_lab`, display :97). Lab rule (Methods 5): a script stops only what it started
(Combat Chat 4's `orig.sh` pid files for the fight tools). Keyed checks need `wait`s between keys (a Y sent before a menu is up is
lost). Saves: ours' original-format saves are now the original's layout (wilderness saves load in DOSBox); the start saves
of checks 1 and 2 are kept in `data/diff_3-8_start/` and `data/diff_6-19_start/` (letter G). GAME.OVR listing: build one with
`ovr.units()` and `ovr.dis(fo, size, stop=False)` (about 76,000 lines, a few seconds).

**Chat 26:** `pl.py stop` matches this lab's own `por.conf` by its full path (`player_lab` has a `por.conf` too). The
GAME.OVR listing needs the lab's `ndisasm` on the PATH (`PATH=$PWD:$PATH python3 -c "import ovr; ..."`); START.EXE
segments: slice `ovr.image()` at seg x 16 and run `./ndisasm -b16 -o <offset>` on the slice (the stand-in ignores `-e`).
A check's original end save belongs with its start save: re-take both together (check 2's stored end save came from
another start). Clear `game/CHRDATF*` before copying a check's original save in (a stale `CHRDATF5.ITM` showed as an item
difference). In the original, **lists move with Home/End**, not the arrows (the temple's cure list, MEMORIZE's spell
book; the highlight starts on the last entry there), and keys sent before a list is drawn are lost. Resting in New Phlan
or City Hall brings the watch or the guards: City Hall rests quietly with `4AC0=1` in the save. Checks driver:
`data/c26/checks/run.sh <n> <area>` (keys from chat 25's logs).
The bot's full runs reload the last checkpoint at a member's death (chat 26); full run c26a: `data/logs26/full_c26a.log.gz`.
**Chat 27:** a record edit is checked by letting the original load and save it: `mksave.py J G ...`, patch
`game/CHRDATG<n>.SAV`, `pl.py boot g`, then E (ENCAMP), S (SAVE), E (the letter), N (not QUIT TO DOS), and read
`game/CHRDATE<n>.SAV` (the original's recount ran on load: 0x73). Clear `game/CHRDATE*` first. A full run resumed
from another run's checkpoint: copy `bot_<name>.cfg` and `.json` from that run's user folder
(`~/.local/share/godot/app_userdata/Gold Box Reforged bot <id>/`) and pass `--resume=<copy>:<name>`. ECL blocks
disassembled: `godot --headless --path <repo> -s res://tools/dis.gd -- <game> <file> <block>`.
A Monitor or tail pipeline must flush every stage (`cut` buffers; use `awk '{print substr($0,1,200); fflush()}'`).
**Chat 28 (three lanes on one PC):** the Combat lane runs DOSBox on :98 and its fight tools prefer
`/tmp/gbr_dosbox_98.pid`, a file every lab on the PC shares: in main's lab start DOSBox yourself on :99 (`setsid nohup
Xvfb :99 ...`, `setsid nohup dosbox -conf $PWD/por.conf`, note both pids) and give the tools its pid:
`GBR_DOSBOX_PID=<pid> python3 seed.py ...` (main's lab copy of `seed.py` reads it first; `trace.py` and `dsread.py` go
through `seed.pid()`). Stop it by pid with `kill <pid>` (the Lead's guard refuses `pl.py stop`'s pattern kill). A save
names its character files (SAVGAM 0x3209: CHRDATA1...), so a fight's start save copied to another letter must have those
names patched (`slot.sh <fixture dir> <letter>`), or it loads slot A's party. Ours' first step of a recipe
that runs before `tpseed` uses Godot's dice and may meet a random encounter: seed it too. The original's treasure list
(DS:0x6810, far pointers; next item at record +0x2A) can be read while a fight waits for input. TREASURE with item list
128+ is GAME.OVR 0x26F5 / 0x25C99 (`docs/diff-checks.md`, Chat 28).
**Chat 29 (DOSBox by this lab only, the Lead's finding; main's lab copies of Combat's `seed.py`, `orig.sh`, `cmpfight*.sh`,
`origvid.sh`, which stay as they are in the repo):** `seed.pid()` (and so `trace.py`, `dsread.py`, `partyrec.py`,
`origfight.py`) takes `GBR_DOSBOX_PID`, else the lab's pid file `data/dosbox.pid` if that process lives, else the one
DOSBox whose working directory is this lab (none or several: it stops and asks for `GBR_DOSBOX_PID`). `pl.py start`
starts Xvfb :99 and DOSBox and writes `data/xvfb.pid` / `data/dosbox.pid`; `pl.py stop` SIGKILLs only those pids.
`orig.sh` uses :99 and `pl.py start` (no `pgrep`); `cmpfight.sh`, `cmpfight3.sh`, `origvid.sh` and `botstop.sh` stop
helpers with `killmine.py <word>...` (SIGKILL to processes whose command line holds a word **and** whose working
directory is this lab). `ours.sh` takes `PROJ=<built copy>` (a second build, e.g. origin/main's, beside `proj`).
`eclread.py <cell> [n]` reads ECL cells (words) in the running original: cell N at the far pointer DS:0x49D2 +
(2N + 0x6E00) & 0xFFFF (GAME.OVR 0x1FC04). `slotfrom.sh <fixture dir> <from> <to>`: `slot.sh` for a fixture saved in
another slot (the Player's are slot I). Checks driver with its own output folder: `data/c29/run1.sh <n> <area> <dir>`
(chat 26's `run.sh` globbed old logs too: give it the ten areas, not `data/c25/checks/*`).

**Chat 50:** `data/c50/slot.py <src dir> <letter> <dst dir> <letter>` copies a save renamed (SAVGAM + CHRDAT files, the
character-file names inside SAVGAM patched; the destination slot's old files removed first): a check's start into the
original's slot J (`slot.py ~/gbr/checks/data/<n>/start G game J`), the original's ENCAMP SAVE J out as F
(`slot.py game J data/c50/chk<n>/orig F`), slot J back (`slot.py data/c48/slotJ_backup J game J`). Checks 36 and 37 in
`data/c50/chk36/`, `chk37/`. The break-test clone `data/c44/brk` now sits at 5a0764c (it was at d15afe3, where check 36
fails anyway): `git -C data/c44/brk fetch origin && git -C data/c44/brk checkout --detach origin/main` before a break
test; run `brk.py restore` between `sub` and `add` (each applies on top of the other). A quick ours-side try needs no
check: copy `~/gbr/checks/data/game` and a check's `start/` into /tmp, then `godot --headless --path ~/gbr/lab/proj --
--game-path=<copy> --save=<cfg> "--keys=..."` (each key's line shows place, clock, screen and the box's text).

**Chat 49:** P74 seen in DOSBox from check 26's start in slot J (3:0 13,9; `pl.py do walk=3:0:4,12`, `y`, `s` for ARN
with no coins): the inn's not-enough path leaves the party at 4,12 S, and a rest there brings the watch, as ours. Ours
from the same save: `KEYS=... data/c44/onecheck.sh <repo> 26 <out>` (a check's start with other keys; the log shows each
key's screen). Checks 34 (8:27's boat, STAY) and 35 (6:25's slavers and the Buccaneer base) in `data/c49/chk34/`, `chk35/`. Start time measured with two `git archive` copies in
/tmp (old and new main.gd with `Time.get_ticks_msec()` prints at the folder line and the first `process_frame`). The
Windows build runs from WSL headless: `GoldBoxReforged.exe --headless --quit-after 400 --log-file 'D:\...\x.log' --
'--game-path=D:\...\POOLRAD'` (no window; the log gets the report line). The "1 ObjectDB instance was leaked at exit"
line in `--keys` replays is old (932a8a8 has it too). Slot J put back from `data/c48/slotJ_backup/`.

**Chat 48:** the original's character-window cells and script bytes: `c48/cell.py <hex addr> [n]` reads the 16-bit
cells of 0x6B00-0x6EFF (DS:0x49D6 + 2*addr + 0x2A00) and 0x9700-0x98FF (DS:0x49DA + 2*addr - 0x2E00); `c48/scr.py
<hex addr> [n]` the script image 0x9900-0xB6FF (DS:0x49DE + addr + 0x6700). **A DAX ECL block has a 2-byte header:**
script address A is the block's byte A - 0x9900 + 2 (`tools/ecl.py` handles it; a hand read without the +2 is two bytes
off). **The Player's segment replays run in any lab:** `OP_LAB=<lab> OP_SAVES=~/gbr/player_lab/.lab/player/saves
segment.py <run> begin <cp> --start=<p2start save> --tplog` with `<lab>/logs/<run>.log,.queue.txt,.trace.txt`, `qs.cfg`,
`godot`, `proj` and `root/POOLRAD` (main's: `data/c48/seglab/`, never the Player's lab). **The original from a Player
save in slot J:** copy the save with H renamed J and the character-file names inside `SAVGAMJ.DAT` patched (`CHRDATH` ->
`CHRDATJ`): the save names its character files, so a renamed save without the patch loads another slot's party. The lab's
slot J was put back from `data/c48/slotJ_backup/`. **Band checks** (31-33): ours' ENCAMP SAVE of a c34d checkpoint into a
scratch game copy (`data/c48/g25`, `g27`), the original from it in slot J (`pl.py boot j`, `seed.py set 11111111`,
arrows, `e s j n`), the check's files in `data/c48/chk30..33/`.

**Chat 45:** test build 2 and 0.1.0 from cbfa5e7 (`tools/build/windows_test.sh`; a version with no suffix is a
release build: `README-windows-release.txt`, the zip `goldbox-reforged-<version>-windows.zip`). Delivered:
`builds/windows-test-2026-11-17/` (0.1.0-test2) and `builds/release-0.1.0/` (+ `release-notes.md` for `gh release
create`). `ui45.sh` (main's lab only) = `ui42.sh` plus `GAMEP=<game folder>`, for takes from a scratch game copy (the
lab's slot F is now a 7:22 save; chat 42's slot F is check 23's original end, `data/c35/chk23/orig`, copied into
`data/c45/gF`). Since chat 44's replay fix a `wait` passes in a few frames: pad `KEYS` with ~400 waits, or the
replay runs out and the game quits mid-take (a black end). Step lists of the re-shot clips: `data/c45/shots/`.

**Chat 44:** the `--keys` replay (main.gd `_replay_keys`) waits after each key until the engine is idle (no script DELAY
or walk playing), at least 4 frames, ceiling 300 frames and 5 s whichever later (was 300 frames: with fast frames a
chain of DELAYs outlasted them and checks 21 / 24 failed with Combat Chat 15's automap). `data/c44/onecheck.sh <src> <n>
<out>` plays one check's ours side as diffcheck.sh does and keeps the log (`KEYS=` / `EXTRA=` override); `data/c44/wt`
was origin/main + c15-automap merged (the proof: 29/29), `data/c44/ink` the old map at INK_SECONDS 0.0001 (21, 23-25
MATCH), `data/c44/brk` + `brk.py` the break test's copy. Showcase re-shoots: the key lists of chat 40's takes rebuilt
from their `.out` logs into `data/c44/townwalk_keys.txt` / `quicksave_keys.txt` (one key a line), filmed with `shot40.sh`.

**Chat 43:** new checks 25-29 (5:6 the altar, New Phlan's two shops, 5:5 the giants, 7:22 the rocks room), each from
a c34d checkpoint saved by ours' ENCAMP SAVE into an emptied slot G (`data/c43/slotG_backup/` holds the lab's own G:
put it back after) and `mkcheck35.sh <n> <area> "<orig keys>" "<ours keys>"` (SEED=11111111 for the seeded ones);
built in `data/c35/chk<n>/`, copied to `~/gbr/checks/data/<n>` and sealed **only once the engine change a check needs
is on origin/main** (check 25 went in early and failed the other lanes' gates for ~15 minutes). Finding a no-fight
event: `tools/dis.gd` for the block's script, `route.py` (`R.load(f, b)`, `R.route(start, goals, avoid)`,
`R.keys(path, facing)`) for the keys; an ECL block's data tables sit at address - 0x9900 + 2 in the DAX block. For a
route over outdoor squares with patrol rolls, try seeds in ours first (tpseed shares the original's dice).
`shot43.sh` (main's lab only): ours windowed on :98 from a check's start (`CHK=<n>`, `K=<keys with shot=<png>>`).
The wilderness bands (6:25, 7:26, 8:27) key their events to the overland position and roll encounters each step; 6:1's
slave pen is behind a gate that needs earlier state: none of the four has a check yet.

**Chat 42:** showcase item 5's new parts (main's lab only): `ui42.sh` = `ui40.sh` plus `SAVE=<cfg>` (start the
`KEYS` replay from any save or checkpoint, copied); `uisteps.py` takes `esc`, not `Escape`; the recorder starts
`LEAD` s after launch (`LEAD=6` keeps Godot's boot splash out of a take with `KEYS`). The takes' step lists are in
`data/c42/shots/<take>` (README in the PC's `.lab/showcase/main/`, "Chat 42"). Test build 2's dry run: give the out
dir as the third argument inside the lab (`windows_test.sh origin/main 0.1.0-test2 ~/gbr/lab/data/c42/build/...`) so
it can be deleted after; the README comes from the checkout running the script, not from the commit. **A c34d
checkpoint as an original start:** load the cfg in ours and ENCAMP SAVE an empty slot (`--keys=wait,E,wait,S,wait,
G,wait,wait,N`): the original loads it (5:3 included). In the original's vertical menus End moves down (Up/Down
don't). 5:3 routes: GEO5 block 3, events are `INFO & 31` (bits 32/64 are other flags). Check 24 with
`SEED=11111111 mkcheck35.sh 24 5-3 "<orig keys>" "<ours keys>"`; `trace.py install` then `trace.py run 20 end enter`
logged the original's DAMAGE draws (`data/c42/trace24.txt`). `tools/dis.gd` takes the game folder as its first
argument (`-- <game> <file> <block>`; `--game-path=` hangs it).

**Chat 41:** **test build 2: `tools/build/windows_test.sh <commit> <version> [<out dir>]`** (in the repo, not the lab):
`tools/build/windows_test.sh origin/main 0.1.0-test2` builds into `/mnt/d/ai_projects/goldbox-reforged/builds/
windows-0.1.0-test2/` (+ `.build-info.txt`, `.pck-list.txt` beside it; refuses an existing folder) from a `git archive`
of the commit without tools/ and docs/; stamps the version into the copy (project.godot, the .exe's file version
0.1.0.2), scans the copy for game data, exports, checks the .pck list (only .godot/, content/, scenes/, scripts/, the
icon, project.binary), writes the README (`tools/build/README-windows.txt`, the 8 steps) and the zip, and smoke-tests
the same pack under the Linux release template: no game; check 22's start (load G, ENCAMP SAVE F, F2); the window
title on Xvfb `:95` (`SMOKE_DISPLAY`; `tools/build/xtitle.py` reads it through libX11). ~45 s; dry run at addbfc7:
BUILD OK (147 .pck files). Check 22 (the save files): the start and the original's end in `data/c41/chk22/`
(DOSBox runs: `data/c41/orig22.log`), sealed as `~/gbr/checks/data/22`; a check with a `files` list compares the
CHRDATF files ours leaves. `data/c41/oldrepo` is the break test's copy of the repo (SUBTRACT/ADD broken in turn).

**Chat 40:** showcase item 5 (main's lab only, in `lab40.tar.gz`): `shot40.sh <out.mkv> <secs> "<keys>" <log>`
(coldours39.sh without the draw log; each take gets a scratch copy of `qs.cfg`: an F2 in a take used to write the
lab's own) and `ui40.sh <out.mkv> <secs> <log> <steps...>` (ours from the title, no `--keys`, or `KEYS="..."` for a
replay start padded with `wait`s since the replay quits when its keys run out; `PRE="..."` steps run before filming,
e.g. past the original's title screens; a scratch HOME, `SETTINGS="[qol]\n..."` seeds its settings) driven by
`c40/uisteps.py` (XTest: key names, `wait=`, `move=x,y`, `glide=x,y`, `click`, `rclick`, `wheelup/down`, `grab=`)
and filmed by `moncap40.py` (moncap.py plus `MONCAP_POINTER=1`: draws an arrow where X has the pointer; ImageGrab
grabs none). `c40/townwalk.py` / `c40/walkfit.sh` route a walk round New Phlan avoiding event squares (`route.py`
with 3:0's tables) and run it headless to see where it stops. `coldorig40.sh <save> <seed> <out> <secs> <log>
"<keys before the seed>" "<keys after>"` films any fight in the original (KW= the wait after each key). Check 21:
`SEED=11111111 mkcheck35.sh 21 3-11 "wait=2 up wait=3 ..."` (the original takes the first Up only after ~2 s).
3:11 has no GEO block of its own: it is New Phlan's map (`area=3:11,find=<event>` lists its squares).

**Chat 39:** the cold-open pair re-shot on the monotonic clock: `coldorig39.sh` / `coldours39.sh` (same arguments as
the chat 38 scripts) film with `moncap.py`, a copy of Player 11's `p11/moncap.py` (frame k grabbed at start + k/30 s
on CLOCK_MONOTONIC, a late grab repeats the frame for the missed slot; its count of frames and repeats goes to
`<log>.cap`; REC in `<log>` is moncap's own start). The lab's copy takes `MONCAP_FAST=1` (lossless x264 RGB, qp 0,
ultrafast): at 1280x800 beside Godot, FFV1 dropped 11% of slots, x264 2%. Then `coldlog38.py` as before. The take:
`coldorig39.sh H 22222222 data/c39/orig_H22.mkv 75 data/c39/orig_H22.log`; `MONCAP_FAST=1 coldours39.sh
data/c39/ours_H22b.mkv 75 "<chat 38's keys>" data/c39/ours_H22b.log`. `check_godot.sh` and `bot.sh` now copy
`content/` into their project copies (the area names, the quest data and FEATURES were missing there; the bot
recorded no quest offers). Checks 19 and 20 were made with `mkcheck35.sh 19 8-29 ...` / `mkcheck35.sh 20 3-0 ...`
(docs/diff-checks.md "Chat 39"; the original's keys in `data/c35/chk19|20/orig.log`). A jump save leaves the
original's 0xC04F stale until the first real step: start one step before an on-move event. `route.py` routes on any
area once its tables are swapped (`R.NE, R.SW, R.INFO, R.DOORS = R.load(set, block)`). `tools/save_list.gd ...
--label <slot> <name>` names a slot. Lab archive: `lab39.tar.gz`.

**Chat 38:** the showcase's cold-open pair (main's lab only): `coldorig38.sh <save> <seed> <out.mkv> <secs> <log>`
(origvid.sh with `trace.py run` going, each line stamped by `tstamp.py`; REC/ENTER/END in `<log>`, the draws in
`<log>.trace`) and `coldours38.sh <out.mkv> <secs> "<keys>" <log>` (oursvid36.sh with `--anim --tplive`: ours prints
each TpDice draw as it is made, `DRAW #n ...`; stamped into `<log>.out`); then `coldlog38.py <orig log> <ours log>
<out dir>` checks the two draw lists are identical, trims both clips to the fight and writes the draw logs. Stamps
use the monotonic clock: WSL steps the wall clock (Findings). The take: `coldours38.sh data/c38/ours_H22.mkv 75
"load=H,up,up,tpseed=22222222,enter,quickall,magic,fightend,n,wait,wait,wait,wait,wait,wait,tplog,partyhp"
data/c38/ours_H22.log`; `coldorig38.sh H 22222222 data/c38/orig_H22.mkv 75 data/c38/orig_H22.log`. Never put
`dosbox` in the command line that runs `coldorig38.sh` (its `killmine.py ... dosbox` kills that shell, and the
orphaned script then runs on beside the next one). The code-wheel answer is `wheel_solver.py`, kept out of the repo. `tools/save_list.gd <game folder> [<quick save>]` prints the save
menu's data (SaveSlots). Lab archive: `lab38.tar.gz`.

**Chat 37:** `oursvid36.sh` records with no pointer (Xvfb `-nocursor` and ffmpeg `-draw_mouse 0`: Godot sets its
own pointer, which x11grab draws unless told not to). `fullrun37.sh <out.mkv>`: showcase item 7, c34d's 37 checkpoints
in the plan's order, 4 s each, with the automap off through a scratch `HOME` whose user settings say `automap=false`
(the same trick switches any user setting for one recording without touching the lab's). `tools/quest_report.gd
<save.cfg | SAVGAMx.DAT> ...` prints the quest tracker's view of a save (absolute paths: Godot resolves relative ones
inside the project). The Windows build: Godot 4.7.2's export templates are in `~/.local/share/godot/export_templates/
4.7.2.stable/` (Windows and Linux x86_64 only); export from a clean copy of the tracked files (`git ls-files` minus
tools/ and docs/) with `--headless --import` then `--export-release "Windows Desktop" <exe>`; the file list is the
export log's "Storing File:" lines; a smoke test runs the same pack (`--export-pack`) beside a copy of
`linux_release.x86_64` named like it (`smoke_runner` + `smoke_runner.pck`: release templates refuse `--main-pack`).

**Chat 36:** `mksave.py` takes `gp<n>=<gold>` (character file n's gold; `pp<n>=` the platinum). Check 18 (2:9 the
wagon, `data/c35/chk2-9w/`) was made with `mkcheck35.sh 2-9w 2-9 "<keys>" "<ours' keys>"` (the first argument only
names the lab folder). Showcase captures: `oursvid36.sh <out.mkv> <secs> "<keys>"` (oursvid.sh on its own display
`VD`, default :98, never :96/:97; `SAVE=<cfg>` loads a checkpoint, `LEAD=<s>` the delay before recording);
`termvid.py <log> <timing> <out.mkv>` renders a `script --log-timing` recording as a 1280x800 terminal video (home
folder shown as ~). Area events: `evmap.py <ecl file> <block>`; every block's listing in a scratch folder:
`for s in 1..8: ecl.py list game/ECL$s.DAX`, then `ecl.py dis` per block (the repo's `tools/ecl.py`).

**Chat 35:** new differential checks: `mkcheck35.sh <n> <area> "<pl.py do steps for the original>" "<ours' keys>"`
plays a check in both games from `game/SAVGAMG.DAT` (+ CHRDATG*), saves the original's end in F (ENCAMP SAVE F, N at
the quit prompt), writes `data/c35/chk<n>/` and prints `statediff`; `SEED=<hex>` sets the original's dice after boot
(then put `tpseed=<hex>` after `load=G` in ours' keys). Start saves: a jump save (mksave) where the area has no
arrival scene; else ours' `at=x;y;dir,E,S,G,N,E` after the scene; or, where ours' load re-derives 49F2 (6:28's init
skips its escort only on 49F2 = 28), the original's own ENCAMP SAVE G after a jump with `49F2=28`. `writers.py` takes
`ECL_PY=` (the lab has no `../ecl.py`). In DOSBox the dungeon screens show coordinates only after a redraw: trust
ours' log for positions. LOOK in the original moves the clock at once (P67).

**Chat 34:** short test plans can live untracked in the repo's `tools/plans/` (`t34_*.plan`: `playthrough.plan` with a
`stop` after an area's checkpoint; bot.sh copies every plan), so no source copy is needed; resume from another run's
checkpoint with random dice and count the outcomes (`data/c34/count.py "<explore: event N at (x, y)>" <logs>`: each
fight of that event, won or lost, the members killed). `fight <area> <cue>` / `parley <area> <cue>` in a test plan
choose an encounter menu's answer. Racial abilities are standing effects that only a load adds back
(`SpecialAffects.RACIAL`): anything that clears `affects` has to keep them. Chat 34's runs and checkpoints:
`data/c34/` (`cp_<id>`). Repo deletions are refused by the Lead's guard: move scratch files into the lab instead.
Starting a second `refcheck.sh` while one runs spoils both (they reset `data/ref/` at the start): this chat did it once.

**Chat 33:** c33a's and c33b's checkpoints are in `data/c33/cp_c33a`, `data/c33/cp_c33b` (copy them out of the
user folder `~/.local/share/godot/app_userdata/Gold Box Reforged bot <id>/` after a run: `BOT_CHECKPOINTS` isn't
where the quick saves go). Two `refcheck.sh` at once share `data/ref/` and spoil each other's figures: one at a
time. A scratch copy with `print`s (`data/c33/srcD`) found the shared record; `awk -f data/c33/tyr.awk <log>` lists each
Tyranthraxus try's result after the guards. Godot 4: a Packed array assigned to another variable is the same
array; `duplicate()` it for a copy.

**Chat 32:** a run can be resumed from another run's checkpoint: copy its user folder's `bot_*.cfg/.json` (e.g.
`data/c32/cp_c31a/`) and pass `--resume=<file>:<checkpoint name>` to `bot.sh` (plan lines after that checkpoint).
For a short test plan, copy the repo to `data/c32/src` (scripts, scenes, tools, project.godot, icon.svg), cut
`playthrough.plan` after the checkpoint and add lines, and run with `BOT_SRC=$PWD/data/c32/src`. Never reuse a
running job's `BOT_ID` (bot.sh deletes its project). A wait loop with `pgrep -f <pattern>` matches its own shell:
wait on a pid with `kill -0`.

**Chat 31:** `--seed=<n>` seeds every generator of ours (the script's dice too), and the gate's `diffcheck.sh` runs
ours with `--seed=1` (check 4's 1-in-5 failure was an unseeded script draw). `data/c31/one4.sh <src> <out>` plays check
4 alone keeping its log (`EXTRA=--seed=<n>`); `data/c31/ten.sh <src>` runs ten full diffchecks two at a time. In the
original's lists `pl.py do End` moves the cursor down, `Home` up. Lab slot J was used for the poison test and
restored from `data/c31/slotJ_backup`.

**Chat 30:** a check's key list holds its `wait`s, and how many a scene needs depends on the code (chat 26's DELAY
fix made 5:7's closing scene ~150 waits long): chat 29's driver took chat 25's lists and check 5 "failed" on every
commit. Checks now come from chat 26's lists: in the lab `data/c30/run1.sh <n> <area> <abs dir>` (`data/c29/run1.sh`
calls it), for the push gate `~/gbr/checks/diffcheck.sh <repo>` (its own copy of everything; README beside it).
Bisect builds: `data/c30/mkproj.sh <commit>` makes `proj_<commit>` (for `PROJ=`). The bot's shortcut win now needs the
same fight to have beaten the party twice since the checkpoint (`_losses`), not just a third try.

**Combat Chat 6 (Jeremy's PC):** DOSBox Staging ignores SIGTERM, so a stop by `kill` leaves it running and the next
`orig.sh` reuses it: the PC lab's `killmine.sh` sends SIGKILL a second later. Never run `killmine.sh`/`pgrep -f` with the
pattern on your own shell's command line (it matches the shell). `savein.sh` also reads `combat6/saves/<fixture>`
(`mu`: 4:10's LEVEL 6 MU at 8,10 N, 0x4A42 = 3; `mu29`: 2:9's event 13 from 7,5 S, 0x4A77 = 16). `trace.py`'s HOLD
prints the pick list (`HOLD picklist <count> figure:distance:direction ...`, DS:0x671A; the figures are 1-based, as the
occupancy grid). Ours on a separate game folder (so regress's slots stay): the lab archive's `combat6/oursg.sh <keys>`
with `combat6/g61` (a copy of `game/` without saves; `combat6/mksave.py` writes there through the `combat6/game` link).

**Running the original from Claude Code (WSL):** `export DISPLAY=:99` before `pl.py` (WSL sets `:0` and `pl.py`
only defaults to `:99`; the symptom is an X `BadMatch` in `X_GetImage`), and run `pl.py` outside the sandbox.

**Fights against the original (side lane)**
- `trace.py` records every draw the original makes; our engine replays them with Turbo Pascal's own Random
  (`--keys tpseed=<hex>`).
- `cmpfight2.sh <save> <seed> "<keys before>" "<keys after>"` plays one fight in both and `cmpdraws.py`
  compares draws, cells, CONTINUE BATTLE and the party's HP and status, ending `VERDICT: MATCH` or the
  first difference. `cmpfight3.sh` varies a fight with a second seed.
- `regress.sh` replays every recorded fight (all 23 MATCH since Combat Chat 1, the kobold caves' 8905 and 6825 draws included; `cmpdraws.py` leaves out a diagonal step the trace caught half done); `regress.sh record` records
  them again from the original. Run it after any change in `scripts/combat/`.

**Checking anything else against the original**
- `pl.py boot <save>` / `pl.py do <steps>`: a running session of the original (`dump` reads the screen as
  text). `mksave.py` makes a lab save that starts in any area.
- `ours.sh` / `t.sh --keys=...`: our engine headless with keys; `run_godot.sh` on a display for screenshots.
- `origvid.sh`, `oursvid.sh`, `vtl.py`: film both and time what's on screen (display work).
- `ovr.py dis <GAME.OVR offset>` reads the original's code (chat 21: LOAD_CHAR is 0x1026, the character window's reads
  0x7D00-0x7F3E). It calls `ndisasm`; the PC's WSL has no nasm (and no package installs), so the lab has a stand-in,
  `tools/lab/ndisasm` (objdump in 8086 mode, printed in ndisasm's format): `PATH=/home/claude/lab:$PATH python3 ovr.py dis 1026`.

**Where findings go:** engine facts in ai-business-ideas `research/pool-of-radiance-formats.md`; anything
another lane needs on the board; the end-of-chat entry at the top of ai-business-ideas `plans/chat-log.md`.

Runs the original Pool of Radiance in DOSBox Staging on an invisible X display (Xvfb), so
Claude can press keys and take screenshots on Jeremy's PC without taking over his screen.
See `plans/test-lab-roadmap.md` in the ai-business-ideas repo.

Setup (in the Linux workspace on the PC):
1. Unpack `.lab/dosbox-staging-linux-x86_64-v0.83.0.tar.xz` into `~/lab/`.
2. Copy `Pool of Radiance/POOLRAD` to `~/lab/root/POOLRAD` (a copy: the lab never touches real
   saves; the game's POOL.CFG expects `C:\POOLRAD\`).
3. Copy these scripts to `~/lab/`, with `font.json`, `wheel.json` and `wheel_solver.py` from `.lab`, and link the
   game copy for our engine: `ln -s root/POOLRAD ~/lab/game`.
4. For our engine: unzip `.lab/Godot_v4.7.2-stable_linux.x86_64.zip` into `~/lab/godot/`.

The lab's home path changes between sessions; `run.sh` rewrites the paths in `por.conf` each
time.

Loading a game asks the code-wheel question; the `solve` step answers it with `wheel_solver.py`, which is kept
outside the repo (chat 38, Jeremy: before the repo goes public), beside `wheel.json` in the git-ignored `.lab` folder
and in each lab; `keys.solve_wheel()` only calls it.
From launch to a loaded save: `./run.sh wait=7 enter wait=3 l wait=3 solve wait=3 l wait=3 a wait=8 grab=cap/game.png`.

Use: `./run.sh wait=7 enter wait=3 grab=cap/a.png ...` starts everything, runs the steps
(key names, `wait=seconds`, `grab=file.png`) and stops. Each call to the PC is a fresh
process space, so a whole session runs inside one call (up to three minutes).

`unupx.py` unpacks UPX-compressed (NRV2E) Windows programs; used to read GOG's code-wheel
program.

`check_godot.sh /path/to/goldbox-reforged` (with Godot 4.7.2 for Linux unzipped into
`~/lab/godot/`) parse-checks every script in a copy of the project and runs the main scene
headless for two seconds. Run it before every push.

`lab.py` runs whole sessions: `./run.sh --py lab.py fight 1` boots, loads save A, walks to
event 1's squares (routes from `route.py` on the decoded map) and captures the first fight it
meets: the opening combat screen, then Aim → Next across the monsters. It reads the screen
as text with the game's own 8×8 font (`font.json`, generated from `8X8D1.DAX` block 201 and
kept in `.lab`, since it is game data): the command line, the coordinates line and messages.
Shots and a log go to `$LAB_OUT`.

Source from the cloud workspace arrives as `.lab/src_now.tgz`; `sync.sh` unpacks it into
`~/lab/src` and runs the Godot check. `ours.sh <user args>` then runs our engine headless,
e.g. `./ours.sh --battle=GEO2.DAX:20:13:1:W:2:4:4:4:0 --battle-fight=1:away`.

`c3lab.py` holds the combat checks against the original: `./run.sh --py c3lab.py away`
fights the first battle met on the way to the Slums orcs (13,1), lets party members wait
until monsters attack them, then steps the attacked one away (free attacks), logging and
shooting every change of the right-hand panel.

`./run.sh --py c3lab.py tactics` (LAB_OUT=..., SECS=90) walks toward the Slums kobolds (event 6),
puts everyone on Quick and logs every screen: monster turns show "MOVE/ATTACK, MOVE LEFT = n"
on each approach step, so step counts, diagonal steps (n drops by 1.5), targets and GUARDING
can be compared with ours. Random encounters usually get in first, which serves as well.
`./run.sh --py c3lab.py win` quick-fights the Slums orcs and captures the results and treasure.

`run_godot.sh <quicksave.cfg> steps...` runs **our engine** on a second virtual display
(1280×800) starting from a quick save file (`--save=`), with the same key/grab steps (or
`--py script.py`). Example: a save at Slums 14,1 facing west, then `up wait=3 enter` walks
into the orcs' event and starts the fight. Our engine also has two headless check modes:
`--battle=GEO2.DAX:20:13:7:W:2:4:6:4:-1` prints where everyone starts (and
`--battle-image=` saves the field); `--battle-fight=<seed>` fights it out and prints every roll.

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
  Game files, `font.json` and `wheel.json` stay in the git-ignored `.lab` folder or the lab, never in a repo.

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
3. Copy these scripts to `~/lab/`, with `font.json` and `wheel.json` from `.lab`, and link the
   game copy for our engine: `ln -s root/POOLRAD ~/lab/game`.
4. For our engine: unzip `.lab/Godot_v4.7.2-stable_linux.x86_64.zip` into `~/lab/godot/`.

The lab's home path changes between sessions; `run.sh` rewrites the paths in `por.conf` each
time.

Loading a game asks the code-wheel question; the `solve` step reads the runes and path off
the screen and types the word, using `wheel.json` from the git-ignored `.lab` folder. (Espruar runes 17-27 are the cell
pairs 98/99 to 118/119 of `8X8D1.DAX` block 201; fixed 2026-11-10, when one boot in two
failed on them.)
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

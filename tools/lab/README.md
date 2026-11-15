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

**Before every push** (CLAUDE.md): fetch and rebase; `./check_godot.sh`; `refcheck.sh` after any change to
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

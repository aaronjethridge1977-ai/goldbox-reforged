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

**Chat 93:** **Jeremy's crashes after TARGET** (0.1.7-test2): `combat_screen.gd` `_bevel` set two pixels outside the combat image for a figure off the view; debug builds (every lab Godot) skip them with an `Index p_x = ... out of bounds` error line, **release templates write them** (4.7.2 Linux release: `set_pixel(-1, 0)` dumps core). **`tools/lab/treplay.sh`** (new) plays a RECORD MY GAME session windowed (`DISPLAY_N`, default :95: start your own Xvfb) and paced (`--anim`), its keys at their recorded times (main.gd's `timed=<.gbrrec>` item after `seed=`/`load=`); `REL=<release binary>` with a `.pck` beside it (`godot --export-pack Linux`, the template copied from `~/.local/share/godot/export_templates/4.7.2.stable/linux_release.x86_64`) runs what a tester's build runs; audio ALSA to the null device (no sound out loud). For an older build's commit, `data/c93/timed.py <checkout>` adds `timed=`. holds_crash2 kept all 99 complete lines of Jeremy's log (key-by-key headless parted at 17). **Checks 312-316** in `data/c93/chk312`-`chk316` (links `data/c93/cd/`, keys `k<n>`; ~/gbr/checks/README.md "Chat 93"); 312 and 314 in the gate (DIFFCHECKS 312/312), and 295-304, 306-311 (Combat Chat 41 landed them). Ready diffs: `data/c93/bevel.diff` (the crash), `rest0.diff` (313), `whom_esc.diff` (315), `scroll_esc.diff` (316); all four `c93_fixes.diff`; edit scripts `<name>.py <checkout>`. Tools: `data/c93/orun2.sh` (orun.sh without the last ENCAMP: saves F from the camp menu). **Seen:** unlearned picks dropped by a later camp's first action other than SAVE; REST at 00:00:00 straight back (SAVE / CAST lit); Esc at the camp's and a scroll's CAST SPELL ON WHOM: light off (bug 19's second and third places); the CAST list opens on its last spell; the view sheet's ITEMS never pages (16 rows). **Mind:** `orun.sh`'s out dir keeps old files (save_f.sh copies over): give each run a fresh dir. **Build:** 0.1.7-test3 from `wip/main-93-test3` (24b1426 = origin/main 0478ad6 + bevel.diff) in `.lab/for-jeremy/build-0.1.7-test3/`. Slots G, F restored; J = `data/c48/slotJ_backup`.

**Chat 105:** copies in `data/c105/` (as chat 104's) plus `ours.sh <checkout> <start dir> <work> <keys>` (ours headless from `load=G`, one state line per key; the proj kept per work dir), `hreplay.sh` (a RECORD MY GAME session key by key: drifts for a new game; use `timed=` paced instead), `names.gd` (ours' item names for an .ITM: `godot --headless --path <proj> --script res://tools/names.gd -- <game> <ITM>`). **Keys at times without a recording:** write a small .gbrrec (`{"k":"Up","t":500}` lines after a header) and pass `timed=<file>` after `load=G` with `--anim` (P90's test: Up at 500 ms, L at 600). **The original's game speed:** SAVGAM cell 0x49FC (9: a DELAY of 2 s, to press keys inside it). **Checks 401-408** in `chk401`-`chk408` (ends `o<n>`, breaks `brk<n>`): 401 a creation save (`o401sv`, from the original's PARTY CREATION SAVE CURRENT GAME; `s401` as slot G), 402-404 2:20's floorboard chest (`s90`: check 71's start jumped to 5,9 E; `s90s` the same at speed 9), 405-406 3:8's clerk (`s405` = check 57's start; `s406` with 0x4A39 = 5, 0x4A3A = 3), 407-408 3:0's proclamations (`s407`: a jump to 4,2 S then a step; `s408`: a jump onto 4,3 S). P91's test items: `s91`, `s91b` (DORN's ITM with ten word / type variants).

**Chat 109:** copies in `data/c109/` (as chat 108's; `vid.sh` takes `VD=<display>`, default :98, so it can film beside a windowed replay). `dis/<f>_<b>.txt`: every Pool block through `tools/ecl.py dis` once (grep them instead of re-running the scan). `o.sh <start> <work> <keys>`: ours.sh on main with the effects column dropped. **Replays:** `rep.sh <checkout> <replay dir> <work>` (key by key, headless) and `trep.sh <checkout> <replay dir> <.gbrrec> <work> [waits]` (a quick-save session at its recorded times, windowed on :98, `--anim`; prints "   at <state>" before each key); `src865/` is b865613 (Jeremy's build) from `git archive`; `t865/ours.log` his 21:42 session replayed to its end on b865613 (the hidden temple's YES at 1:18 1,15; the scorpions and the frogs at 4:2; the well), `tmain`/`repmain.log`/`rep865.log` the partings (docs/diff-checks.md "Chat 109"). `tools/lab/treplay.sh` now does quick-save sessions itself. **Check 440** in `chk440` (start chat 108's `s426`; end `o440`, steps `o440.steps`, keys `k440`, break `brk440`). DOSBox captures: `run1.png`-`run8.png` (the elf's runes, then the empty view), `pw1.png`/`pw2.png` (5:4's paper, inline runes), `fl1-3.png` (1:18's FLEE); ours' films in `vid/` (`elf3.mp4`, `pw.mp4`, `fl2.mp4`). In the original's vertical menus End moves down (Down doesn't).
**Chat 110:** copies in `data/c110/` (as chat 109's). **Checks 441-445** in `chk441`-`chk445` (starts: `sx/o429` (check 429's original end in slot G) for 441, `s442` (check 45's start jumped to 2:20 1,1 N), check 64's start for 443, `s444` (check 45's start jumped to 2:20 14,1 W), check 367's start for 445; ends `o<n>`, keys `k<n>`, breaks `brk<n>` in `cdb/`); `sx/o426`, `sx/o430`, `sx/o431` the other 4:21 ends in slot G. **Jeremy's replays:** `r140322`, `r141709` (replay_recording.py's dirs); `t1403/` and `t1417f/` their timed replays on b865613 (`src865` from chat 109) with a key/mode print in the treasure and shop screens (`TRS`/`SHP` lines); `f_rep2.txt` / `f_his2.txt` the 14:17 session's combat lines against his game log (identical). The tower's films: `vid/tw.mp4` (before the fix), `vid/tw2.mp4` (after); DOSBox grabs `tw1.png` (after YES), `tw2.png`, `tw3.png`; the smithy's `a*.png`. `s445`/`s445g`: the grain sack tries (wiped). Xvfb :98 and :92 started by this chat (pids 2644096, 2644100), :99 by pl.py.
**Chat 114:** copies in `data/c114/` (as chat 113's) plus `timr.py <key> <seconds>` (tim.py with the rows from `ROWS=' 9|,10|,...'`) and `picscan.py` (a figure after a PICTURE in code order). No new check (display only). Grabs in `g/`: `i*`/`j*` the Ilmater temple (check 439's start), `o*` the overhear event (424's, tpseed 7171000a), `k*`/`m*` 8:13's rocks (87's, tpseed 61610001), `s*` 3:0's Skullcrusher farewell (start `sSk` = 369's original end jumped to 3:0 4,2 S; Down, Up, Down, Up, Up), `t*`/`u*`/`v*`/`w*` 6:28's tour (55's start), `x*`/`y*` 5:4's kitchen (60's keys: the oil's empty page, the menu with row 24 left); each `*sheet.png` tiles them. `vid.sh` now records 1280x1024 (row 24 in the frame: crop `1280:800:0:108`). Ours' films `vid/ov1` (overhear), `rk1`/`rk2` (rocks before/after), `sk3`-`sk5` (farewell), `tour1`/`tour2` (tour before/after), `rk3`/`rk4` (the rocks' colours before/after), `oil1`/`oil2` (row 24 before/after), `dbg.mp4` with `src1/` (a debug copy). `dc1.log`-`dc6.log` the gate runs.

**Chat 113:** copies in `data/c113/` (as chat 112's). **Check 450** in `chk450` (start `sUp` = check 58's start jumped to 5:7 6,7 W; end `o450`; keys `k450`; break `brk450`): the stairs; grabs `u1`-`u8.png`. **Check 451** in `chk451` (start `sPr` = check 370's original end in slot G jumped to 8:13 6,14 S; end `o451`; keys `k451`; break `brk451` in `cdb/`): the princess's farewell; grabs `p1`-`p4.png`. Skullcrusher's join `k1`/`k2.png` (check 369's start); 2:20's PAY `py1`/`py2.png`, the SURRENDER `r0`-`r3.png` (check 72's start); 1:18's tavern `t1`-`t3.png` (check 74's start). Ours' films `vid/up1.mp4` (the stairs), `pr1`/`pr2` (princess before/after the fix), `sk1`/`sk2` (Skullcrusher), `pay1`/`pay2`, `tv1`/`tv2` (the tavern); frame sheets `vid/s1`-`s9.png`. `dc1.log`, `dc2.log` the gate runs.
**Chat 112:** copies in `data/c112/` (as chat 111's). **4:2's flee, confirmed:** `sCo2`/`sCo2F` (chat 111's `sCoG` with BROTHER SEAN's splint mail dropped in camp, so movement 12; 4,11 N), `autoflee.py` (each member: MOVE, down-right then down off the field's south edge, FLEE Y), `runflee.sh` (tpseed 11111111; end `oFl`, keys `fkeys.txt`, log `runflee.log`), `flee.sh`; grabs `f*.png`/`g*.png`; ours' film after the fix `vid/fl.png`. **Checks 447-449** in `chk447`-`chk449` (starts `s447`-`s449` from check 45's start jumped beside each room; ends `o447`-`o449`; keys `k447`-`k449`; breaks `brk447`-`brk449`; `press44*.log`); `dc1-4.log` the gate runs. Chat 112 was cut off (API 529) before its wrap-up; chat 113 archived it (`lab112.tar.gz`).
**Chat 111:** copies in `data/c111/` (as chat 110's). **The tower's walking-menu tests:** `sTw`/`sTwG` (a camp save at 4:10 15,5 S, from check 443's start walked by `pl.py walk`), `tow2.sh <tag> <keys...>` (boot, Up into the tower, the texts, YES, then each key, grabs `tw_<tag>_<n>.png`), `towall.sh`/`towall2.sh` and their logs (S, L, E, V, A, C; A twice, End + C), `towX.log` (X, S, S, C); side-by-sides `cmpS.png`, `cmpLEV.png`, `cmpAC.png`, `cmpA2.png`, `cmpC2.png`, `cmpX.png`; ours' film after the fix `vid/s1.mp4`. `sSt` (check 442's start jumped to 2:20 3,0 S: the storage room, then LOOK). **Check 446** in `chk446` (start `s446` = check 441's original end in slot G, SEARCH on; end `o446`; keys `k446`; break `brk446` in `cdb/`); `step.py <keys...>` sends walking keys one by one and stops at a new text (logs `sent.txt`). **4:2's flee, not finished:** `sCo`/`sCoF`/`sCoG` (s426 jumped to 4:2 4,11 N with `mksave.py G H 4 2 4 11 N strong`, then a camp save with the courtyard's LOAD_MONs cut to 1 and 1), `turn.py` (DONE QUIT for every member but DARKSTAR), `mv.sh`, grabs `co*.png`/`c1*.png`. In the original's combat DONE opens DELAY QUIT SPEED EXIT: QUIT ends the member's turn.
**Chat 108:** copies in `data/c108/` (as chat 107's) plus `tim.py <key> <seconds>` (the original, DISPLAY=:99: presses the key, then prints rows 3, 17, 22 and 24 with the time each time they change, a dump every ~0.05-0.1 s: how long a text types before the next screen; run from the lab with the game at the point). **Checks 426-439** in `chk426`-`chk438` (starts `s426` (check 45's start jumped into 4:21 with 0x4AD7 = 255) for 426-428, `s429` (426's original end), `s430` (427's), `s431` (430's), `s432` (check 12's start with 0x4A18 = 1), `s434`/`s435`/`s437` (check 45's start jumped to 2:20 14,10 W / 14,12 E / 3,4 S), `s436` (435's end jumped to 14,10 W), `s438` (437's end), `s439` (check 51's start jumped to 1:18 1,14 S: P110's temple); ends `o<n>`, steps `o<n>.steps`, keys `k<n>`, breaks `brk<n>` in `cdb/`); 433 (`s433`, the graveyard's arrival) made but not in the gate (0x4A16's uninitialized read, docs/diff-checks.md "Chat 108"). A jump save onto a square takes the area's init first (4:21 puts the party at 8,14; 2:20's on the first step) and its area cells are reset by the NEW_ECL: set area cells on an original's save made inside the area instead. Ours' window recordings `vid432*.mp4`, `vidp109.mp4`, `vidp111.mp4`; Jeremy's 21:42 recording made into keys in `p110/` (its replay `wp110/replay.log` drifted into camp: his place came from the keys' times); frame sheets in `vid/` (ffmpeg `fps=1,scale=240:150,tile=6x2`). The scan for a PRINT followed by a screen change with no stop (COMBAT 78, NEW_ECL 6, CALL 2C90 25, LOAD_AREA_MAP 8): `python3 data/c108/scan.py COMBAT NEW_ECL CALL LOAD_AREA_MAP` (every block through `tools/ecl.py dis`, ~3 minutes).

**Chat 107:** copies in `data/c107/` (as chat 106's) plus `orunS.sh` (orun.sh with `SEED=<tpseed>`). **A seed search in ours, one run:** `ours.sh` with keys `load=G,wait,tpseed=<s>,Up,wait,...` repeated for 40 seeds, then grep the state lines (how 417's encounter at distance 2 was found). **Timing the original's text:** a python loop of `pl.py do dump` after one key, printing rows 17-24 when they change (each dump ~0.15 s; data/c107 notes in docs/diff-checks.md "Chat 107"); `PYTHONPATH=. python3 data/c107/dswrite.py 49e2 01` sets the game speed (DS:0x49E2) to 1 (dswrite needs the lab on its path). **Ours windowed with screenshots:** `CHK=<n> K=<keys with shot=<png>> bash shot43.sh` (:98; used for P102's picture). **Checks 417-425** in `chk417`-`chk425` (starts `s106j` 417, `s104` 418, `s419`, `s420` 420/421/424/425, `s422` (check 327's original end as G), `s423` (422's end as G); ends `o<n>`; keys `k<n>`; breaks `brk<n>` in `cdb/`). **The original's catacomb walk:** `pl.py do walk=8:32:13,1` (geo file number, block, x,y) routes on the decoded map; `route.py`'s `R.route` / `R.keys(p, 0)` give the same keys for ours. **Ours recorded windowed:** `data/c107/vid.sh <start dir> <keys> <out.mp4>` (Xvfb :98, ffmpeg x11grab 10 fps; frames then with `ffmpeg -vf crop=...`): how a text up for a moment is seen in ours, where the key driver waits through it. Jeremy's 17:25-17:49 recordings replayed by hreplay.sh drift on current main (17:49's stops in 2:9 at an encounter menu): his places were found from the script instead.

**Chat 106:** copies in `data/c106/` (as chat 105's) plus `setcell.py <src slot dir> <dst> <cell hex>=<value>...` (a start with ECL cells set), `origwrap.py` (the original printer's rows, START.EXE 0x77F8, against ours' old wrap over every PRINT_CLEAR; `wrapcases.json` its 1615 texts with the model's rows), `p97_edit.py` / `p97.diff` (Combat's: TRADE TO?'s picture). **The printer's layout check:** `godot --headless --path <proj> --script res://tools/lab/printwrap_check.gd -- <cases.json>` (PrintWrap.lines against the model; 0 of 1615 differ). **Disassembling START.EXE:** `./ndisasm -b16 -o <start> <file>` on a slice of `re/start.img` (the lab's objdump stand-in); START.EXE's DS is image offset 0xC7C0 (a Pascal small set at DS:x with `mov ax,0x404` is the set's bytes 4-7 at x). **Checks 410-411** in `chk410`-`chk411` (ends `o410`, `o411`, starts `s410` / `s411` = `s405` with 0x4ABB / 0x4AA7 = 254; the original's steps `o410steps`, long waits: the clerk's texts print slowly at speed 4). **412-414:** `s412` (`s405` with 0x4AE7 = 254, 0x4ABB = 255), `s413` (check 327's start jumped to 3:8 4,5 S), `s414` (`s413` with 0x4AC1 = 3; steps `o414steps`). 415-416: `s415` (`s405` with 0x4AAA, 0x4AAD = 254; steps `o415steps`), `s416` (check 327's original end as slot G, jumped to 3:8 4,5 S). An original's save in another slot: `mkdir <dst>` first, then `data/c50/slot.py <src> F <dst> G`.
**Chat 104:** copies in `data/c104/` (as chat 103's) plus `ofight.sh <start> <out> <pre steps file> <post steps file>` (the original through a fight on QUICK by presser.py, then ENCAMP and save F; `ofight2.sh`: POKE="<hex addr> <hex bytes>" writes DS memory first, `dswrite.py`), `coins.py <dirs>` (each record's coins, experience, HP, status). **Checks 393-400** in `chk393`-`chk400` (ends `o<n>`, breaks `brk<n>`, `brk395b`, `brk397s`-`brk400s` with SWORDSMAN's 0x84 = 0): 393-394 a rest fight in 1:18 with the hired SWORDSMAN (`s393`: check 373's start jumped to 12,8 E; `s394`: PHINEAS on the monsters' side with 3000 gold), 395 a fresh game (ours' key `create`; the original from its title: C, End, Enter x4, Y, ZED, Enter, K, E, Y, A, A, E, B, Rolf's 8 texts), 396 and 399-400 the hall's ADD (check 103's start; `data/c103/s387` with SWORDSMAN), 397-398 SWORDSMAN's VIEW (camp; the arms shop from `data/c103/s383`). Ready for Combat: `add_close.py`, `hide_page.py`, `npc_trade.py`, `npc_tag.py` (diffs `c104_*.diff`). **Guide 13's step 3:** `fin/` (the Player's `p45i1_s45ready` as slot G, 0x4A6D |= 12, jumped to 5:7 3,7 S: Up, Up, two texts, six votes A, his fight), `fin_ord/`, `fin_p47/` (the same reordered), `quick.plan`; `GBR_FIELDLOG=1 PF_KEEP=1 tools/lab/planfight.sh ... data/c104/fin "<prelude>" n:60:47040001 data/c104/quick.plan`, then `breath.py <work folder>` (the first breath per run: who, which slot, killed or not); tables `breath60.txt`, `breath60_ord.txt`, `breath60_p47.txt`. `trace.py run <s> <key>` prints POS lines (DS:0x5F2B) at the fight's first draws: the formation as placed.
**Chat 103:** copies in `data/c103/` (as chat 102's). **p17a6** replayed with `MATCH_GATE_ONLY=p17a6 MATCH_GATE_KEEP=1 tools/build/match_gate.sh <ref>`: LIRA's 10 ARROWS bought as LIGHT CROSSBOWs: GAME.OVR's shared list top DS:0x6B29 and Home / End on the page (list routine 0x2D669; overlay stubs: START.EXE segment `seg*16` holds `CD 3F`, the overlay's file base as a dword at +4, entries `CD 3F <off>` from +0x20, 5 bytes apart: target = base + off). `shoplist.gd` prints the shop lists in ours' order (`GAME=$PWD/game godot --headless --path proj -s data/c103/shoplist.gd`). Ready for Combat: `list_top.py`, `c103_list_top.diff`. **Checks 378-392** in `chk378`-`chk392` (ends `o<n>`, breaks `brk<n>`; `brk382s` a start with SWORDSMAN's 0x84 = 0): 378-379 the arms shop's list (check 176's start), 380-381 the hall's SAVE (check 103's start; `s381` with a stale CHRDATF6; `files` lists), 383 the arms shop's POOL / SHARE with SWORDSMAN (`s383`, `brk383s`), 384-385 the hall emptied by REMOVE x6 (385: REMOVE x5 and DROP) then LOAD SAVED GAME (ready for Combat: `hall_load.py`, `c103_hall_load.diff`), 386-392 SWORDSMAN's TRADE, a BUY (392), ALTER DROP, the inn's REST (`s391`), the temple's cure (`s390`: 3:0's temple from 2,11 S; route.py's GEO1 18 isn't 3:0's map), the hall's REMOVE and TRAIN of him (`s387`, `s388`: jump saves onto the hall's 8,0 N), 382 the inn with SWORDSMAN (`s382b`: check 373's start jumped to 3:0 7,12 W; `s382` failed: an original's SAVGAM names its CHRDAT files, so a renamed slot loads the old ones).
**Chat 102:** chat 102's copies in `data/c102/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`, `gen.py`, `brk.py`). **Checks 367-377** in `chk367`-`chk377` (ends `o<n>`, breaks `brk<n>`, links `cd/`, `cdb/`): every NPC_ADD site (367 4:10's mystic from `s_dirten`, 368 3:0's bishop from `s368`, 369 4:2 from `s369`, 370 8:13 from `s370`, 371 5:7 from the jump save `s371j` (a camp save made there crashes the original's load), 372 3:11's partner from check 21's start), 373 (an original's save with the hired SWORDSMAN: the duel refused; start `s373`), 374-375 (the hall's ADD list; ready for Combat: `add_list.py`, `c102_add_list.diff`), 376-377 (ALTER PICS: cell 0x49FF, 2 monsters, 1 portraits). `jump.py <SAVGAM file> <x> <y> <N|E|S|W> <ecl file> <block> [cell=value ...]`: mksave.py's jump patch on a save in a folder (no slot copy). DIRTEN's 0, 4 is slot J's shipped record. Guide 12's step 3: `plans_throne44_c102_60b.log` (60 more seeds, 4419003d on).

**Chat 101:** chat 101's copies in `data/c101/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). `gen.py <n> <race> <sex> <class> <alignment> <rerolls> <NAME>`: a creation check's keys (`k<n>`) and the original's steps (`o<n>.steps`) from list positions (race 0 dwarf .. 5 human; chat 100's 344 recipe); `o2k.py <steps>`: ours' keys from the original's steps (End in the lists). `aim.py <race> <sex> <class> [rerolls]`: the original's creation generator in python (offset 0 = tpseed 11111111 at CREATE from check 103's start; reproduces 351). `show.py <dir>`: a save's members (race, sex, class, alignment, abilities, age, HP, gold, levels, spells). `brk.py <n> <file> <hex offset> <value>`: a break copy `brk<n>` linked from `cdb/`. `clean.py`: deletes the lab game folder's `.CHA` and `CHARLIST.TXT`. `iconx.sh <out> <steps>`: the camp's ALTER ICON on THRENDER GRONE in the original, saved, prints the icon bytes. **Checks 351-360** in `chk351`-`chk360` (ends `o<n>`); ready for Combat: `icon_size.py` (`c101_icon_size.diff`); landed: `creator_exit.py`. `gen358.py`: 358's keys. `s365`: check 103's start with BROTHER SEAN's experience 0 (MODIFY opens). Guide 12's step 3: `plans_throne44_c101_60.log`, `_waves.txt`, runs `w3runs60/` (60 seeds, two plans). The original's NPC_ADD draws traced on check 54's start (2:15 MAD MAN: the d4, five colour d6s at LOAD_MON, Random(256), the class pick, body d5, head d8).
**Chat 100:** chat 100's copies in `data/c100/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). **Checks 336-346** (3:11, training and money, a magic-user's racial limit, a three-class member, the wrong class, an unconscious trainee; character creation) in `data/c100/chk336`-`chk343`; starts `s336`, `s337` (check 103's with THRENDER GRONE's gold 900 / 995), `s338` (sfm, RHIANNON gold 1500), `s339` (sfm, RHIANNON magic-user 11, 800000 experience), `s340` (sfm, RHIANNON a half-elf cleric/fighter/magic-user 1/1/1; 340 and 341), `s342` (DARKSTAR 6000 experience, 5000 gold), `s343` (THRENDER GRONE unconscious); **Checks 344-350** (CREATE NEW CHARACTER and ADD; 350 MODIFY from check 103's start; ours' keys `k344`-`k349` use Down where the original's steps `o344.steps`-`o349.steps` use End; 347's 19 rerolls found by running the original's generator in python) ; the original's creation draws traced (`trace.py run` in the background while `pl.py do` drives the keys); creating in DOSBox leaves `<NAME>.CHA` and `CHARLIST.TXT` in the lab's game folder: delete them after. Ready for Combat: `creator_keys.py <checkout>` (`c100_creator_keys.diff`). `waves.py <runs dir>`: planfight's kept logs summed per wave. The throne room's three waves, three more plans: `plans_throne44_c100.log`, `plans_throne44_c100_waves.txt`, runs `w3runs/`, plans `plans/`. the original's steps `o<n>.steps`, ends `o<n>`; deliberate breaks `brk<n>`, links `cdb/`.

**Chat 99:** chat 99's copies in `data/c99/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). **Checks 333-335** in `data/c99/chk333`-`chk335` (start `data/c98/sfm`, 335 `data/c99/scap`: RHIANNON at fighter 7 and 130000 experience; the original's steps `o333.steps`-`o335.steps`; deliberate breaks `brk333`-`brk335`, links `cdb/`). Ready for Combat: `arrows_feature.py <checkout>` (`c99_arrows_feature.diff`: chat 98's FEATURES text naming the shop's lists too). **`planfight.sh` follows waves:** a plan line `waves <n>` and `wave <n>` sections (scripts/dev/plan_fight.gd; entries before any `wave` line are the first fight's); between fights it presses Enter past the texts, EXIT and NO at the treasure (left behind), sets the QUICK flags for the next wave's round 1 and turns MAGIC on again (ours, as the original, turns it off at each fight's start); a `PLANFIGHT WAVE` line per fight in the run's log; the table counts a win only when every wave is won and adds the mean waves reached. (Chat 98's PF_POST `E,wait,wait,N` didn't take because the first key lands on THE PARTY HAS WON: Enter first.) The throne room's three waves (Player 44's door save, 20 seeds): `data/c99/plans_throne44_w3.log`, per wave `plans_throne44_w3_waves.txt`, plans `data/c99/plans/`.

**Chat 98:** chat 98's copies in `data/c98/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). **Checks 331, 332** in `data/c98/chk331`, `chk332` (start `data/c98/sfm`: check 330's with RHIANNON, elf fighter/magic-user, at 5000 experience and 5000 gold; the original's steps `o331.steps`, `o332.steps`). Ready for Combat: `arrows_feature.py <checkout>` (`c98_arrows_feature.diff`: FEATURES' ARROWS IN WHO LISTS widened to ARROWS IN LISTS, the Lead's (a)). **Plans in ours from the Player's save:** `data/c98/s44door` (Player 44's `p2start/p44s1_s44door` as slot G, LIRA's Fireball scroll and Fatima's Broad Sword +1 readied by byte 52 of their item records, as the plan's `ready` lines), `s44haste` (LIRA's second Fireball made Haste, record 0x2B = 48); prelude `Down,wait,wait,Up,wait,wait,Up,wait,wait,Left,wait,wait,Up,wait,wait,Enter,wait,wait` (E, E, N onto 6,3, the text); plans `data/c98/plans/`; results `data/c98/plans_throne44.log`. planfight measures **the first fight only** (wave 1: it stops at its end; ours then shows the treasure, and `PF_POST` keys after it didn't get past it: open). `continue yes` loops for ever on QUICK members (they guard; a plan needs cure entries for those rounds). **cmpfight3.sh's MAGIC=1 doesn't take in the original** (the throne room, seed 39600002: no party spell pick in 17382 draws, CEDRIC's turn skips at GAME.OVR 0xB187, the MAGIC test of 0x6E30; ours 160 picks): such a compare isn't valid until presser.py's Alt-M is checked.

**Chat 97:** chat 97's copies in `data/c97/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). **Checks 329, 330** in `data/c97/chk329`, `chk330` (start `data/c97/smu`: check 103's with DARKSTAR at 4000 experience and 5000 gold; the original's steps `o329.steps`, `o330.steps` for `orun.sh`; the sign at 3:11 6,0 swallows keys sent too soon: a 4 s pause after it). Ready (Combat's files): `aligned_rate.py <checkout>` (`c97_aligned.diff`); `learn_keys.py` (`c97_learn_arrows.diff`) only if the Lead drops ours' arrows in the spell lists. **Seen:** the camp's MEMORIZE list takes only Home / End too (End wraps). **A fight against the original draw by draw:** `cmpfight3.sh G <seed> "" "right,up,enter"` (slot G from `data/c79/putg.py <start>`; its original side names the shipped party in `partyrec.py`, so other parties' end lines show `?`); ours' weapon choice traced with `APDBG=1`. The throne room's original trace (seed 39600001): `data/c97/throne_39600001_orig.txt`; the plans with the fix: `data/c97/plans_throne_fixed.log`. `partystats` (lab key) prints each member's levels, HP, slots, damage dice and weapon type.

**Chat 96:** chat 96's copies in `data/c96/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`). **Check 327** in `data/c96/chk327` (keys `k327`; the original's run `o327.sh <out>`: the walk `o327a`, presser.py's QUICK fight, then `o327b`; ends `o327_r1`, `o327_r2`): Norris the Gray (8:29) from the Player's `p16c3_s6pre12` as slot G (`data/c96/s6pre12`), CEDRIC takes from a 20-item pile after PgDn x2 and PgUp x2. Ready (Combat's files): `loot_pg.py`, `coin_xp.py <checkout>`, both `c96_fixes.diff`, with chat 95's `c95_c96_both.diff`. **Seen:** PgDn / PgUp are NEXT / PREV in the LOOT list; a TAKE keeps the page's top; ARN and BRAM there hold 16 items (TAKE refused, no message); the pile's coins count kind by kind (GAME.OVR 0x57B1, read with `objdump -D -b binary -m i8086 --start-address=0x57b1 game/GAME.OVR`: ndisasm isn't installed, so `ovr.py dis` fails). **Plans in ours (Guide 12's step 3):** `tools/lab/planfight.sh <checkout> <start dir> <prelude keys> <seeds> <plan>...` plays each plan file (format at the top of `scripts/dev/plan_fight.gd`; key `planfight=<file>`) headless over the seeds (tpseed: ORIGINAL'S BUGS on; QoL off as the checks), prints a line per run and a table per plan (wins, rounds, HP lost, who fell); each run prints the field (`PLANFIGHT FIELD`: figures, cells, HP, memorized spells). The throne room from Player 39's door save: `data/c96/s39door` (slot G), prelude `Right,wait,wait,Up,wait,wait,Enter,wait,wait`; about 20 s a run, 4 at once (`PF_JOBS`). Plans tried: `data/c96/plans/` (20-seed table on the board, Guide 12's request). A fight's first menu eats the first key: the runner sends it again after 3 s (`PLANFIGHT c` twice in the log: harmless). `magic on` toggles at the fight's start.

**Chat 95:** chat 95's copies in `data/c95/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`: chat 94's with c95 paths). **Checks 321-326** in `data/c95/chk321`-`chk326` (links `data/c95/cd/`, keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 95"): 325 in the gate (a magic-user scroll's CAST SPELL ON WHOM, matched), and 317-319 after Combat's c8ef896: DIFFCHECKS 320/320. Ready (Combat's files): `data/c95/drop_esc.py`, `camp_esc.py`, `treasure_esc.py <checkout>`, all three `c95_esc.diff`. **Seen:** Esc does nothing at the hall's DROP <NAME> FOREVER? and ARE YOU SURE?, the camp's DROP FROM PARTY?, QUIT TO DOS, LOSE IT?, MEMORIZE THESE SPELLS?, the treasure's GO BACK AND CLAIM YOUR TREASURE?; the treasure menu's and TAKE's Esc is EXIT. **A fight in the original as a check plays it:** `python3 presser.py 240 noenter` (DISPLAY=:99) once QUICK is on the menu, then the keys after the fight; check 326 did it after check 67's rest keys (`data/c95/o326`). `data/c95/s41g`: the Player's `s41trained` (slot H) copied as slot G (ELWEN's magic-user scroll; not used for a check). **Smoke test (e):** tools/build/windows_test.sh replays fireball_crash and holds_crash2 on the release template; a test from a dangling commit (`git commit-tree` with a deliberate break, no branch) with `SKIP_MATCH_GATE=1` and an out dir in /tmp.

**Chat 94:** chat 94's copies in `data/c94/` (`mkchk.sh`, `orun.sh`, `orun2.sh`, `mk.py`: chat 93's with c94 paths). **Checks 317-320** in `data/c94/chk317`-`chk320` (links `data/c94/cd/`, keys `k<n>`, the original's ends `o317b`, `o318`, `o319`, `o320b`; ~/gbr/checks/README.md "Chat 94"): 320 in the gate (the inn's STAY? Esc, matched), and 313, 315, 316 (after Combat's 7d1152d): DIFFCHECKS 316/316. Ready (Combat's files): `data/c94/shop_esc.py`, `temple_esc.py`, `hall_esc.py <checkout>`, all three `c94_esc.diff` (Esc at the shop's, temple's and hall's menus and YES NO questions does nothing; checks 317-319). **Seen:** Esc at the shop's menu, YOU HAVE LEFT SOME MONEY, the temple's menu, CAST CURE ANYWAY, PAY FOR CURE, the hall's menu, DO YOU WISH TO TRAIN?, QUIT TO DOS and the inn's STAY?: nothing; Esc in the BUY list, HEAL's list and APPRAISE: EXIT; SHARE leaves a remainder in the pool (EXIT asks again); YES at YOU HAVE LEFT SOME MONEY adds TAKE and SHARE; TRADE in the view sheet fails silently when the receiver can't take the item. **Release replays:** `/tmp`-built exports (`godot --export-pack Linux` + the release template) of test3 (24b1426) and origin/main; a timed replay drifts under load (other lanes' gate runs): fireball_crash's last TARGET gave NO TARGET THERE on both. Jeremy's `182145_finale` (test3) replays to THE PARTY WINS (about 20 minutes).

**Chat 92:** **Checks 308-311** in `data/c92/chk308`-`chk311` (links in `data/c92/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 92"); none in the gate (each waits for its ready diff: `data/c92/trade_esc.diff` (308, 309), `shop_pg.diff` (310), `camp_pg.diff` (311); all three `c92_fixes.diff`; with chat 90-91's `c92_all.diff`; the edits as scripts `trade_esc.py`, `shop_pg.py`, `camp_pg.py <checkout>`). **Tools:** `data/c92/mk.py <keys out> <key>...` (ours' key list with load G, tpseed and two waits a key, plus the pl.py steps for `orun.sh` on stdout); `data/c92/mkchk.sh`, `orun.sh` (chat 91's writing to `data/c92`). **Seen:** Esc at the view sheet's TRADE TO? / WITH WHOM? takes the light off the party (a null member, by the look of it: Home gives the last member, End one past the end: original's bug 19, the item or coins lost); TRADE's coin page EXIT / Esc goes to the view page until HOW MUCH is asked; PgDn / PgUp page the shop's BUY list and the camp's spell lists (the lit word stays); Left / Right do nothing in the spell lists; **picks not yet learned are gone after leaving camp and coming back** (one DOSBox session; check 260's end says otherwise: open). `coins.py` reads the first copy of a name in memory: after a TRADE that can be a stale copy (DORN showed garbage coins while his sheet said 750 platinum). **Jeremy's logs:** Godot names a rotated log by the time the next session started. Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`.

**Chat 91:** **Checks 304-307** in `data/c91/chk304`-`chk307` (links in `data/c91/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 91"); 305 joined the gate (DIFFCHECKS 294/294); 304, 306, 307 wait for Combat (`c90_bundle.diff` then `data/c91/c91_on_c90.diff`, or `c91_all.diff` from origin/main; parts: `useit.diff`, `take_pgup.diff`, `camp_light.diff` (+ `camp_light.py`, the edit as a script)). **Tools:** `data/c91/mkchk.sh`, `orun.sh` (chat 90's, writing to `data/c91`); `data/c91/o307.sh` (check 100's fight, then T, PgUp, Enter); `data/c91/t91.sh` (the fight, then scan-code keys at the treasure's menus, no save); **`data/c91/replay.sh <commit|checkout> <replay_recording.py out> <work> [bugs]`** (a RECORD MY GAME session headless on a commit, as diffcheck.sh plays a check; needs a start cfg for --save: without one ours never starts the keys). **Seen:** the light in the camp's menus keeps the index of the word last chosen (past the menu's end: the first word); GAME SPEED offers FASTER / SLOWER only where they apply; PgUp at the treasure's TAKE is ITEMS (0x49 = I); no scan-code letters on the view sheet's menus, the temple's menu and HEAL list, the treasure's main menu. **A fight replays differently headless and windowed** (Jeremy's Fireball session parts in round 1): a recording through a fight is not a faithful copy of his game. **Careful:** in camp, S then E saves the original to slot E (done once by mistake; slot E restored from lab90.tar.gz's ./game). Slots G, F restored; J unchanged.

**Chat 90:** **Checks 295-303** in `data/c90/chk295`-`chk303` (links in `data/c90/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 90" (2)-(4)); they wait for Combat (`data/c90/c90_bundle.diff`: SELL KEEP with bug 18, APPRAISE's menu keys, the treasure's TAKE and LOOT, the view sheet's questions and menus). 284-286, 288-294 joined the gate (DIFFCHECKS 293/293). **Tools:** `data/c90/mkchk.sh`, `orun.sh` (chat 89's, writing to `data/c90`); `data/c90/o299.sh` (check 100's fight in the original with `presser.py`, then the treasure's keys: a won fight's treasure with money and items); `data/c90/lw.py <NAME>` (each live copy of a record: the cached load word +0x102 and the money); `data/c90/brief.py <key> <prefix> [s]` (press a key, save every distinct 320x200 screen: brief messages). **Seen:** DOS's extended keys reach some GAME.OVR menus as their scan codes read as letters: Left 0x4B = K (KEEP), Right 0x4D = M (the treasure's MONEY), Home 0x47 = G (APPRAISE's GEMS); not on the camp's or shop's main menus. APPRAISE's menu works the cached load out again on Enter, Space, digits, the arrows and End. Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab90.tar.gz`:** lab89's file list (the files still there) plus `data/c90`, then POOLRAD as ./game.

**Chat 89:** **Checks 284-294** in `data/c89/chk284`-`chk294` (links in `data/c89/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 89" (1)-(5)). 287 in the gate (and chat 88's 281-283 after Combat Chat 40); 284-286, 288-294 wait for Combat (`data/c89/c89_five.diff`: the temple's, shop's, camp's, hall's and treasure's menus letters-only; one by one `<temple|shop|camp|hall|treasure>_letters.diff`). **Tools:** `data/c89/mkchk.sh` (chat 88's writing to `data/c89`); `data/c89/orun.sh <start> <out> <pl.py do steps...>` (the original from a start in slot G, tpseed 11111111, the steps, then ENCAMP and save F to <out>: one command per original end); `data/c89/walk278.txt` (check 278's walk to 3:0's temple as pl.py steps); `data/c89/dc_nolist.sh` (chat 88's). **Seen:** at the shop's YOU CAN: SELL KEEP the original sells on Enter, Right, keypad 6 and Esc and keeps on Left (scan code 0x4B = K; to the Lead); the original's lit word after a camp submenu's EXIT is the submenu's last index (ORDER's EXIT: DROP; ALTER's or MAGIC's EXIT: EXIT; VIEW's EXIT: VIEW); the hall's SAVE with a letter: no message, no QUIT TO DOS. `data/c89/coins.py <NAME>...` (a live record's money words +0x88: copper ... platinum, gems, jewelry; run with `python3 -I`); `data/c89/lit.py <grab.png>` (the white runs in rows 192-199: the lit word). Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab89.tar.gz`:** lab88's file list (the files still there) plus `data/c89`, then POOLRAD as ./game.

**Chat 88:** **Checks 275-283** in `data/c88/chk275`-`chk283` (links in `data/c88/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 88" (1)-(4)). 275-280 in the gate; 281-283 wait for Combat (`data/c88/hall_drop_remove.diff`). **Tools:** `data/c88/mkchk.sh` (chat 87's plus a 5th argument: the check whose `ours.cfg` and `area` it copies, default 192); `data/c88/dc_nolist.sh` (dc_new.sh with the QoL save list off too: the faithful SAVE prompt). **Ready diffs for Combat:** `save_esc.diff`, `temple_take_exit.diff`, `hall_drop_remove.diff`. **Seen:** `esc` must be lower case in keys; the original's REMOVE writes `<NAME>.CHA/.ITM/.SPC` and `CHARLIST.TXT` into its game folder (the lab's game has them now, harmless); Esc at the inn's WHO WILL PAY? locks the original (DOSBox restarted). Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`.

**Chat 87:** **Checks 260-274** in `data/c87/chk260`-`chk274` (links in `data/c87/cd/`; keys `k<n>`, the original's ends `o<n>`; ~/gbr/checks/README.md "Chat 87" (1)-(5) has each recipe). All in the gate; 271 (the shop's VIEW without money) and chat 86's 250, 252-253, 256-258 joined after Combat Chat 39's 72d52ba (gate: 273 checks). **Tools:** `data/c87/mkchk.sh` (chat 86's writing to `data/c87`); run with `data/c86/dc_new.sh` (`DC_DATA=$PWD/data/c87/cd`); ours' screen at a key: a scratch check 299 with `screen=` (deleted in python after). **A brief message in the original:** `/tmp`-style poll: `keys.key('n', hold=0.03)` then `keys.screen320()` in a loop (every ~8 ms) shows whether a message flashes (chat 87: ALTER DROP's NO says nothing). **Lit word on a menu row:** per column, white pixels in rows 192-199 of a grab (a whole white word is the lit one). **Ready diffs for Combat:** `data/c87/alter_both.diff` (ALTER's EXIT at PLACE keeps the message; DROP's NO says nothing), screens `o261_orig_alter.png`, `o261_ours_fixed.png`. **Seen:** Enter does nothing on the original's item menu; after a NO the original keeps the item or cure lit and lights the menu's first word. Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab87.tar.gz`:** lab86's file list (the files still there) plus `data/c87`, then POOLRAD as ./game.

**Chat 86:** **Checks 245-259** in `data/c86/chk245`-`chk259` (no 255; links in `data/c86/cd/`; ~/gbr/checks/README.md "Chat 86" (1)-(6) has each recipe; starts `data/c86/s<n>` or the named check's, keys `k<n>`, the original's ends `o<n>`). In the gate: 245-249, 251, 254, 259 (and chat 83's 219, 225, 226 after Combat Chat 38's fixes). **Waiting for Combat, ready diffs:** `data/c86/scroll_light.diff` (250: a scroll's page lights its last spell), `whom_exit.diff` (252-253: EXIT at CAST SPELL ON WHOM rebuilds the list), `view_money.diff` (256-258: VIEW's money TRADE/DROP only with money; back to VIEW after the last coin). **Tools:** `data/c86/mkchk.sh` (chat 85's, writing to `data/c86`); **`data/c86/dc_new.sh`: use this one** (`cp -rL`: older copies shared one game folder through `cd/game` when several checks ran at once: the "flaky" 219/225/226); `data/c86/dc_keep.sh` (the same, keeps ours' log in /tmp/dck/<n>.log); ours' screen at any key: add `screen=/tmp/x.png` to a scratch copy of a check's keys. **Seen:** the original's own save F can start a check (`data/c50/slot.py <dir> F <dst> G`); money at record 0x88 + 2i (copper ... platinum, gems 0x92, jewelry 0x94). Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab86.tar.gz`:** lab85's file list (the files still there) plus `data/c86`, then POOLRAD as ./game.

**Chat 85:** **Checks 240-244** in `data/c85/chk240`-`chk244` (links in `data/c85/cd/`; ~/gbr/checks/README.md "Chat 85" has each recipe; `data/c85/mkchk.sh` is chat 84's writing to `data/c85`): the CAST list's light after a cast (240: the last row), STRENGTH twice (241), the adventure menu's HASTE (242), a cleric with a magic-user's scroll (243: READY refused silently), BLESS after PRAYER (244); all in the gate. **Seen:** an adventure-menu cast returns to the walk screen, so `save_f.sh` needs an `e` (ENCAMP) first. Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab85.tar.gz`:** lab84's file list plus `data/c85`, then POOLRAD as ./game.

**Chat 84:** **Checks 233-239** in `data/c84/chk233`-`chk239` (links in `data/c84/cd/`; ~/gbr/checks/README.md "Chat 84" and "Chat 84 (2)" have each recipe; starts `data/c84/s<n>`, the original's ends `o<n>`, keys `k<n>`): WHOM after MAGIC's EXIT (233), ENLARGE twice (234), HASTE over a Haste (235; 236 **a fix**: GAME.OVR 0xF8A5 gets the first record), ANIMATE DEAD's limits (237, 238), a clerical scroll of REMOVE CURSE (239). **Tools in `data/c84/`:** `mkchk.sh` (chat 83's, writing to `data/c84`), `run_haste.sh <start> <orig out>` (LIRA's camp HASTE, save F), `run_anim.sh <start> <orig out>` (CEDRIC's camp ANIMATE DEAD, save F; prints status, HP and +0x9F of each). **Seen:** a cast with no target question (HASTE, ANIMATE DEAD) returns to the MAGIC menu, one EXIT fewer than a targeted one before `save_f.sh`; the camp's CAST list reopens with the light on its last row (SLEEP below REDUCE). **Pool's experience table** (START.EXE image 0x10863, 56 bytes a class: eight levels' experience then the spell slots) has -1 for every druid, paladin, ranger and monk level. Slots G, F restored (`data/c80/gbak`, `fbak`); J = `data/c48/slotJ_backup`. **Lab archive `lab84.tar.gz`:** lab83's file list (the files still there) plus `data/c84`, then POOLRAD as ./game.

**Chat 83:** **Checks 218-232** in `data/c83/chk218`-`chk232` (links in `data/c83/cd/`; ~/gbr/checks/README.md "Chat 83" (1)-(7) has each recipe): an effect cast twice (218 BLESS, 223-224 FRIENDS: GAME.OVR 0x2C540 keeps an equal or shorter one, removes the old for a longer or 0-minute one), MEMORIZE picks (220-222: 0x80 + id in the record, gone by the next camp or a load; start `data/c83/mem_start`, Player 36's s27t with ELWEN's memory emptied: **copy a Player save with `data/c50/slot.py`, never by renaming files: SAVGAM names its CHRDAT files**), REDUCE (227: 0x28387), ANIMATE DEAD (231: 0x29087), coverage 228-230 and 232. **Waiting for Combat:** 219 (the MEMORIZE list's NEXT/PREV: `data/c83/camp_paging.diff`; p36h1 identical with it) and 225-226 (CAST SPELL ON WHOM starts on the last target: `data/c83/camp_whom.diff`). `data/c83/mkchk.sh` and `dc_new.sh` as chat 82's; **run lab checks one at a time with `dc_new.sh`** (two at once mixed their starts; the real gate doesn't). **Reading the light** in a grab: `PIL` crop (130,30,320,80) of a 320x200 grab, resized x3: the lit name is white. **Seen:** a save copied by renaming its files loads the party from the letter its SAVGAM names (the renamed s27t brought slot H's party).

**Chat 82:** **The records' cached THAC0 and AC** (Combat Chat 37's p36h1 request; docs/diff-checks.md "Chat 82"). **Tools in `data/c82/`:** `rec.py <name>...` (a party record live in the running original, found by its name in guest memory: base THAC0 +0x2D, cache +0x110/+0x111, HP, the readied pointer +0xCC); `recpoke.py <name> <hex off> <value>` (write one record byte live); `dspoke.py <hex> <value>` (a DS byte: `dspoke.py 49e2 0` is the Player's message speed 0); `replay_log.py <player log> <first #> <last #>` (send a Player run's keys to the original, each when the bottom line matches the log's; an Enter for a PRESS ENTER the log didn't wait for; **after an area change the screen's place line lags: read `dsread.py 6aad 2` and send the next key by hand**); `dc_new.sh` (diffcheck with `DC_DATA` and the `--cache` pass). Slot G held `mu_start` (check 103's end with DARKSTAR and BAKSHI given 9000 experience, 5000 gold, cache 30) and the graveyard save in turn; the slot-F checkpoint of the p36h1 replay went to F (restored). **Checks 214-216** (`chk214`-`chk216`: copies of 103, 96 and 54 with a `cache` file). **Seen:** VIEW refreshes the cache; a load, camp, MEMORIZE, REST, both halls' TRAIN, the inn, an encounter whose monsters flee don't. **The match gate's PARTS NOW line quotes the baseline's note in brackets** ("[game: draw 3932 ...]"): the new difference follows it (p36h1: statediff 1, ELWEN's memorized spells); `MATCH_GATE_KEEP=1` keeps the scratch lab, where `segment.py` can be run again with a print in its `proj/`.
**Chat 81:** **Checks 196-213** in `data/c81/chk196`-`chk213` (links in `data/c81/cd/`; ~/gbr/checks/README.md "Chat 81" has each recipe; starts from checks 192's and 193's): the camp's CAST of PROTECTION FROM GOOD, DETECT INVISIBILITY, MIRROR IMAGE, FRIENDS (**a fix**, and its end after a 5-minute REST), PRAYER (cleric 5), DISPEL MAGIC (**a fix**: kept at 48%, gone at 75%), HASTE (**a fix**: magic-user 5 and 3), INVISIBILITY 10' RADIUS, PROTECTION FROM NORMAL MISSILES, SPIRITUAL HAMMER (**a fix**: the hammer item, and its end), REMOVE CURSE (**a fix**: a cursed item; Bestow Curse), PROTECTION FROM EVIL 10' RADIUS. `run_lira_on.sh <start> <orig out>` (LIRA's spell on CEDRIC). Check 181 and `scrord` (as 206) joined the gate after Combat Chat 37's fixes. **Tools:** `data/c81/mk.py <src> <dst> <file>:<hex off>=<decimal>...` (copy a start and patch bytes); `mkchk.sh <n> <start> <orig> <keys file>` (a check folder, sealed, linked); `run_self_lira.sh <start> <orig out>` and `run_cedric.sh <start> <orig out> ["Home wait=1 Home wait=1 s"]` (boot G, seed, cast, save F, copy); `save_f.sh <out>` (empty F, `s f n` from the camp menu, copy); `variant.sh <n> <sed on keys>` and `variant_s.sh <n> <file>:<off>=<v>` (a /tmp copy, resealed, run). **Seen:** trace.py prints a die as `hi % n` (0-based: `-> 70` is a d100 of 71); ours' camp messages need ~20 waits after a party cast (HASTE's ten lines) or the EXITs land while it still prints and F2 saves nothing; a camp party spell's targets are the first (level) members in party order. **Reading GAME.OVR:** a handler's strings sit just before it, cs-relative: GAME.OVR offset = 0x27018 + the `mov di,<x>` value for the 0x27xxx-0x29xxx handlers (Friends 0x283F1, Dispel Magic 0x293A0, Prayer 0x294ED); the effect handlers near 0xF000 (0xF231 Friends' end, 0xF8A5 Haste's ageing). Slots G and F backed up in `data/c80/gbak`, `fbak` and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab81.tar.gz`:** lab80's file list (the files still there) plus `data/c81`, then POOLRAD as ./game.

**Chat 80:** **Checks 185-195** in `data/c80/chk185`-`chk195` (links in `data/c80/cd/`; ~/gbr/checks/README.md "Chat 80" has each recipe; starts from checks 130/167/173's): a clerical scroll read in camp (level 6), a Potion of Speed (**a fix**: the item spells, ids 57-67, cast at 12, START.EXE 0xba:0x26c2, image 0x3262; party_member.gd `caster_level`), Disappearance, Neutralize Poison on the unpoisoned, Bodily Health, the camp's CAST of RESIST COLD, DETECT MAGIC, RESIST FIRE (cleric 3), STRENGTH (on STR 12: an 18 hides the dice), INVISIBILITY, FIND TRAPS. **Made-up potions:** a Player save's Potion of Speed record (`data/c29/fx/c27a_5-4_giant/CHRDATI4.ITM`, type 71, byte 61 = 80) with byte 61 changed gives any item spell (spell = byte 61 - 23). **A spell's class byte live:** `dsread.py <0x31FA + 16 x id> 1` (0 cleric, 1 magic-user, 2 item spells). **Reading START.EXE:** `ndisasm -b16 -o 0 re/start.img`; a far call `0xba:X` is at image `0xBA0 + X`. Slots G and F backed up in `data/c80/gbak`, `fbak` (= chat 79's) and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab80.tar.gz`:** lab79's file list (the files still there) plus `data/c80`, then POOLRAD as ./game.

**Chat 79:** **Checks 179-184** in `data/c79/chk179`-`chk184` (links in `data/c79/cd/`; ~/gbr/checks/README.md "Chat 79" has each recipe; starts from checks 159/178/157/173's): the camp's USE of a Magic User scroll (**a fix**: a scroll's spell is cast at level 6, spell_caster.gd), the same with LIRA a level-8 magic-user (`data/c79/v179`: still 6), **ready check 181** (money TRADE to a member who can't carry it: DORN's platinum 30000; Combat's file, the fix in `data/c79/chk181_fix.diff`; not in the gate), the silver shop's SELL, a buff CAST with SEARCH on then a step (10 minutes), a scroll's combat-only spell in camp (USE IT?). **`data/c79/putg.py <dir> [letter]`** empties a slot in game/ and copies a start in (G by default). **Seen:** the original's "Overloaded" (money TRADE) never shows on the screen; LIRA'S SPELLS ON SCROLL opens on the last line; a scroll takes both hands (unready the sword first). Slots G and F backed up in `data/c79/gbak`, `fbak` (= chat 78's) and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab79.tar.gz`:** lab78's file list (the files still there) plus `data/c79`, then POOLRAD as ./game.

**Chat 78:** **Checks 169-178** in `data/c78/chk169`-`chk178` (links in `data/c78/cd/`; ~/gbr/checks/README.md "Chat 78" has each recipe; starts `data/c78/s173`, `s174` (made-up memorized spells, chat 75's way), the rest from checks 165/102's): the camp's DROP of a stack, the adventure menu's CAST (Cure Light Wounds on another member), a combat-only spell there (LOSE IT? NO / YES), ALTER SPEED (**a fix**: SAVE writes DS:0x49E2 into script cell 0x49FC, GAME.OVR 0x1FECE; ours' quick save hadn't), CAST PROTECTION FROM EVIL on a member, ENLARGE and SHIELD, an effect running out in a 10-minute REST (MINS, INC: five minutes a step), the shop's POOL / TAKE / SHARE (uneven, money left behind), back for it (every TAKE refused: bugs #9/#10's jewelry), the view page's money TRADE and DROP. **`chk171r`** (and the overwritten LIRA one): READY refusals that repeat check 116: **grep ~/gbr/checks/README.md for the verb and the item kind before building a check.** **Driving:** coin lists (TAKE, money TRADE/DROP) pick with `enter` (pl.py's `Return` was lost once), amounts with digit keys; the shop's TAKE goes to the shop's member; ALTER PICS (MONSTERS / PORTRAITS) changes nothing the gate compares. Slots G and F backed up in `data/c78/gbak`, `fbak` (= chat 77's) and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab78.tar.gz`:** lab77's file list (the files still there) plus `data/c78`, then POOLRAD as ./game.

**Chat 77:** **Checks 162-168** in `data/c77/chk162`-`chk168` (links in `data/c77/cd/`; ~/gbr/checks/README.md "Chat 77" has each recipe; starts in `data/c77/s162`, `s164`, `s166`-`s168`, all from checks 159/156's): CAST READ MAGIC then SCRIBE from an unread scroll, the shop's SELL, the shop's ID of a scroll then SCRIBE, TRADE of a stack, a Potion of Healing's USE, a Potion of Giant Strength's USE (LIRA; ARN refused). **The gate runs ours with QoL off:** diffcheck.sh writes a settings.cfg (segment.py's `QOL_OFF` list) into each check's `$W/xdg/godot/app_userdata/Gold Box Reforged/`; the lab copy `data/c77/dc_new.sh` (chat 52's with the same lines: use it, not `data/c52/dc_new.sh`, for new checks). **Potions:** records copied read-only from the Player's saves (`data/c77/potion.rec`: Healing, byte 61 = 85; `potion_gs.rec`: Giant Strength, 82, link bytes to zero); a potion is USEd only after READY, and READY needs a free hand (sword and shield: refused, no message). **Low dice by simulation:** TpDice's step (seed x 134775813 + 1, (seed >> 16) mod n) picked tpseed 22222222 for two low d4s (check 166). **Driving:** after the shop the camp's member cursor stays on the shop's pick; a slip outside camp (S is SEARCH) is undone by S again. Slots G and F backed up in `data/c77/gbak`, `fbak` and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab77.tar.gz`:** lab76's file list (the files still there) plus `data/c77`, then POOLRAD as ./game.

**Chat 76:** **Checks 156-161** in `data/c76/chk156`-`chk161` (links in `data/c76/cd/`; ~/gbr/checks/README.md "Chat 76" has each recipe; starts built from checks 154/27/155's in `data/c76/s157`-`s161`): the arms shop's HALVE and JOIN, the silver shop's BUY (ring, arrows), MEMORIZE then REST, SCRIBE from a two-spell scroll (the fix), RAISE DEAD, SCRIBE using up a one-spell scroll. **Ready check `scrord`** (`data/c76/scrord`, for Combat: SCRIBE's list order). **Made-up scrolls:** a Magic User Scroll record (type 61) copied from `~/gbr/checks/data/36/orig/CHRDATF2.ITM`, link bytes 42-45 = 0, readied 52 = 0, spells in 60-62, **word 48 = 209 + the number of spells** (210/211/212 "WITH n SPELLS"; keep it consistent: the original counts it down and removes the scroll below 210, GAME.OVR 0x2A2A2), byte 53 = 0 (read: an unread scroll offers nothing to SCRIBE without Read Magic), and +0xC7 one more. **Driving:** the shop's VIEW opens the member's sheet (ITEMS: READY TRADE DROP HALVE JOIN SELL ID EXIT; HALVE inserts the new half after the stack); the silver shop's BUY list opens on its page 2 (BUY PREV EXIT); MEMORIZE's and SCRIBE's lists open on their last line; SCRIBE then needs EXIT, EXIT, YES (two EXITs: the marked page, then the question); the magic menu's REST offers 4:15. The shop's OVERLOADED never shows on the original's screen (not even 0.02 s after the key). **Bug #8's drained classes** go in a slot save's companion ([qol] drained). Slots G and F backed up in `data/c76/gbak`, `fbak` and restored; J = `data/c48/slotJ_backup`. **Lab archive `lab76.tar.gz` (57 MB):** lab75's file list (the files still there) plus `data/c76`, then POOLRAD as ./game (a python list, `tar --no-recursion --transform 's,^\./root/POOLRAD,./game,' -T <list>`).

**Chat 75:** **Checks 149-155** in `data/c75/chk149`-`chk155` (links in `data/c75/cd/`, 153 a link to `data/c74/tapp`; ~/gbr/checks/README.md "Chat 75" has each recipe): the camp's CAST CURE DISEASE then a day's REST, CURE DISEASE on effect 0x22 alone, REST with a diseased member, the arms shop's ID twice, Tyr's temple APPRAISE, BUY that overloads (five Plate Mails, three refused), SLOW POISON then the temple's NEUTRALIZE POISON. **Made-up casters:** a cleric's memorized spells are record bytes 0x17-0x2B (the first in the last byte); put a spell id in a free byte (BROTHER SEAN's 0x29: 39 Cure Disease, 26 Slow Poison) and the original casts it whatever his level or spell book. **The camp's spell list opens on its last line** (End wraps to the first); the CAST SPELL ON WHOM cursor starts on the caster; the temple's party cursor starts on the camp's last pick. **REST in ours' keys:** a day takes ours about 1.2 s and a `wait` is 0.5 s: give REST 30 waits before the next key, else E and F2 land while ours still rests (F2 doesn't save in camp: the check compares a stale save; the Lead's autocheck caught 149). **Cure Disease's handler** is GAME.OVR 0x29347 -> 0x292A2 (found by a full far-call scan: `ndisasm -b16 -o 0 game/GAME.OVR` with ovr.stub on every `call seg:off`; the lab's ndisasm stand-in needs `-o`). **statediff.gd compares item byte 53** (`h`); break test 132/152. Slots G and F backed up in `data/c75/gbak`, `fbak` and restored. **Lab archive `lab75.tar.gz` (57 MB):** lab74's file list (the files still there) plus `data/c75`, then POOLRAD as ./game.

**Chat 74:** **Windows test build 0.1.7-test2** (`SKIP_MATCH_GATE=1 tools/build/windows_test.sh origin/main 0.1.7-test2 <out>`, from 2fde91b) in `.lab/for-jeremy/build-0.1.7-test2/` with its README (built from test1's: the new items, no known recording gaps). **A RECORD MY GAME replay and ORIGINAL'S BUGS:** a `--keys=` run forces the original's bugs on (`OriginalBugs.lab_run`), but a session played with the default (fixes on, since Combat Chat 35's six fixes) would part at the first fixed bug: run the replay with `GBR_ORIGINAL_BUGS=0` when the session's settings say `original_bugs` off; replay_recording.py prints which (`GBR_ORIGINAL_BUGS=<n>`); the `settings.cfg` it writes carries the switch. Test-1 files: the switch didn't change play then (no fix had landed), either value. **Checks 143-148** in `data/c74/chk143`-`chk148` (links in `data/c74/cd/`; ~/gbr/checks/README.md "Chat 74" has each recipe): SELL of a readied item, CURE DISEASE, ALTER DROP, BUY x4, BUY refused for money (147's start is 146's orig end through `slot.py`; back into the shop's square with Down, Up, Down, Up), CURE LIGHT WOUNDS on a diseased member. **The temple's APPRAISE** (`data/c74/tapp`, a ready check for Combat's fix, not in the gate): the original's KEEP needs 0x24CDD's room (0x269D3) and SELL pays through 0x24E8C (the overloaded seller's 16-bit room: THRENDER's platinum 3000 -> 64816); ours' temple APPRAISE does nothing. **The inn's REST is never interrupted:** 3:0's rest block (ECL1 block 18, 0x992B-0x993F) sets the period to 0 on the inn squares (C04F 132, 138). The break test on chat 74's code: 128/148. Slots G and F backed up in `data/c74/gbak`, `fbak` and restored. **Lab archive `lab74.tar.gz` (57 MB):** lab73's file list (the files still there) plus `data/c74`, then POOLRAD as ./game.

**Chat 73:** **RECORD MY GAME records the mouse:** the recorder listens from its own node, the root's last child (`GameRecorder.attach`, `Tap`): its `_input` comes before every screen's, so the keys a click becomes (MouseInput.press: a menu word, a list line, a view step, a fight square, the wheel, the right button) are recorded as keys, and so are keys a screen takes in its own `_input` (the quest log's: **0.1.7-test1 and older lost them**); its `_unhandled_input` records a click no screen made into keys as `{"c": button}` (replayed as `click` / `click<n>`, a button press off any menu: tested at check 25's PRESS ENTER, save identical to Enter's). **A slot load keeps the script memory outside the save's image**, and the replay starts from a quick save: the header now says `vm_fresh` (else `vm_mem` gzip+base64, `vm_size`, `vm_hi`), replay_recording.py writes `vm=fresh` or `vm=<out>/vm.cfg` before `load=` (old files: fresh assumed; wrong only for a slot loaded after a wipe's return to the start menu). `alt+m` now replays as Alt-M (main.gd's replay sets the modifiers; it pressed nothing before). **A windowed test:** `tools/lab/c73/mt.py` (keys.py plus XTest buttons: `click=x,y`, `rclick=`, `mclick=`, `dclick=`, `wheelup=`, `wheeldown=`, `grab=`; the window is 1280x800 = 4x on Xvfb :95), a session from the start menu (load G, view clicks, the quest log, ENCAMP and VIEW / ITEMS / READY by clicks, a list line, the wheel, F2): the headless replay's quick save byte-identical. Without `vm=fresh` it parted (the start quick save's memory carried into G). **Checks 137-142** in `data/c73/chk137`-`chk142` (links in `data/c73/cd/`), the gnoll fight's trace `data/c73/t141.txt`; ~/gbr/checks/README.md "Chat 73" has each recipe. **statediff.gd compares the party's order** (check 142); the deliberate-break copy `data/c44/brk` refreshed to chat 73's code (`rsync -a --delete --exclude .git <repo>/ data/c44/brk/`, `python3 data/c44/brk.py sub`, diffcheck: 121/141; `brk.py restore`). Slots G and F backed up in `data/c73/gbak`, `fbak` and restored. **Lab archive `lab73.tar.gz` (57 MB):** lab72's file list (the files still there) plus every file newer than lab72.tar.gz (only `data/c73`), then POOLRAD as ./game, as chat 72 did.

**Chat 72:** **reading DS live in the original:** `python3 dsread.py <hex> [n]` (e.g. `dsread.py 6aad 5`: x, y, facing x2, the wall ahead, the square's byte) after each `pl.py do` key: how the wall-ahead answers were found (an arrival's init runs with DS 0x49FA = 1; ENCAMP runs the area's rest block). **A jump save to any square:** `mksave.py J G <ecl> <block> <x> <y> <dir>`, boot G, `wait=2 up`. **A segment replay with a debug build:** a private lab like Chat 70's (`/tmp/w72/lab`: `root/POOLRAD` copied, `proj` your build, links to the scratch lab's `godot`, `qs.cfg`, `cmpdraws.py`, `.lab/player/saves`, the run's log and trace in `logs/`), then `OP_LAB=<lab> OP_SEG_TIMEOUT=3200 python3 segment.py ...` (900 s cut long segments short: 92 differences that were only ours stopping); a print in `write_byte` for one address finds its writers. **Checks 130-133** in `data/c72/chk130..133` (linked from `data/c72/cd/`): 130 the scroll (chat 71's `chk130/start`), 131 the cursed sword (`c71/chkcurse/start`), 132 SELL (check 98's start + the cursed record appended), 133 the band REST (check 31's start, tpseed 35353535 by simulating the d100). Ours' F2 doesn't save inside camp: end ours' keys outside camp (ENCAMP, EXIT when the original's end was saved in camp). **The curse check** passes on Combat's `wip/combat-35b` (REMOVE CURSE landed there, not yet on main) and its variant (the clear left out) differs: add it as check 134 when it reaches origin/main. **RECORD MY GAME with dice:** session on `Xvfb :95` (title: Enter, Enter, Enter, Down x6, L for slot G), `replay_recording.py` now writes `record_game=false`; the character sheet's own dice need Combat's `data/c72/sheet_seed.patch` (with it the replay's save is byte-identical). **Curse's files:** `/tmp/w72/curse/start.img` was its START.EXE unpacked (`unexepack.py`); its training code's racial limits are at GAME.OVR 0x24DDE-0x24F5B. refcheck re-recorded on chat 72's code: unchanged (3:11 87%, 5:5 91%). Slots G, F and J restored (G, F from `data/c72/gbak`, `fbak`). **Lab archive `lab72.tar.gz` (56 MB):** a plain tar of the lab with the usual exclusions is 2.6 GB (`data/c38`-`c46` hold big captures that lab archives never carried), so it was built from lab71's own file list (the files still there) plus every file newer than lab71.tar.gz and `data/c72`'s links: `tar -cf ... --no-recursion -T <list>`, then `tar -rf ... -C root --transform 's,^POOLRAD,./game,' POOLRAD`, gzip.

**Chat 71:** **a scratch Player lab without writing in theirs:** `MATCH_GATE_ONLY=" " MATCH_GATE_KEEP=1 tools/build/match_gate.sh origin/main` builds and keeps `/tmp/mgate.*/lab` (ours at the commit, imported; every recording's logs and saves), then `cd /tmp/mgate.*/src/tools/original_player && OP_LAB=<lab> python3 segment.py <run> ...` and `cd <lab> && python3 cmpdraws.py logs/<run>.trace.txt logs/<run>.segment_begin-<cp>.txt`. **Picking a seed for a dice check:** simulate TpDice (seed = seed x 134775813 + 1 mod 2^32, Random(n) = (seed >> 16) mod n, one step a draw) over the trace's draw sizes; it reproduced the original's draws exactly (check 125). **Checks 125-129** in `data/c71/chk125..129` (linked from `data/c71/cd/`): 125 the gas trap (`mksave.py J G 3 14 13 10 S`), 126 STONE TO FLESH (check 122 + End), 127 a wilderness save (Player's `p10b1/band`, slot.py H -> G), 128/129 BUY over / at the load (check 98's start, DORN's silver 3130 / 3129, +0x102 written to match). **Ready check `curse`** (`data/c71/chkcurse`, REMOVE CURSE with ITEM3 list 27's Broad Sword -2 readied; `data/c71/remove_curse.patch` for Combat). Slots G and F were backed up to `data/c71/gbak`, `fbak` and restored. **Scrolls:** a clerical scroll record keeps its spells at bytes 60-62 (CLW x2: [3, 3, 0]); in the original's camp neither USE nor READY took one (CEDRIC, mace readied, shield off) and CAST lists only memorized spells: how a scroll is used is still to read (GAME.OVR's USE). **RECORD MY GAME, a real session:** `Xvfb :95`, ours windowed (`godot --path <proj> -- --game-path=<copy>`, `XDG_DATA_HOME` with `[qol] record_game=true` in its settings.cfg), keys by `DISPLAY=:95 GRAB_SIZE=1280x800 python3 keys.py ...` (no xdotool on this PC), then `replay_recording.py` and a headless replay with `,F2`: 0 differences (lab copy `data/c71/rec71_session.gbrrec`; scratch `/tmp/rec71`).
**Chat 70:** **a private copy of the Player's lab for segment replays** (never write in `~/gbr/player_lab`): `/tmp/pl70` with `logs/<run>.log` + `.trace.txt`, `.lab/player/saves/index.txt` and `p2start/<start>`, `root/POOLRAD`, `qs.cfg`, `cmpdraws.py`, `godot/` (a link) and `proj/` (check_godot's); then `cd tools/original_player && OP_LAB=/tmp/pl70 OP_SEG_TIMEOUT=3200 python3 segment.py <run> begin <cp> --start=<save> --tplog` (a long segment needs more than the default 900 s: run it in the background and poll). `tools/build/match_gate.sh <commit>` builds such a copy itself (`MATCH_GATE_ONLY="<run>"` for a quick test, `MATCH_GATE_KEEP=1` keeps it). **Lab keys:** `shortcutwin` (the Player's logged shortcut win: every monster HP 0, dead, out of the fight; with `GBR_PLAYOUT=1` ours plays the round out and asks CONTINUE BATTLE as the original did), `seed=<n>` (every generator, before a load: RECORD MY GAME replays). **RECORD MY GAME:** `python3 tools/lab/replay_recording.py <file.gbrrec> <out>` writes `start/`, `settings.cfg` and `keys` (`seed=<n>,load=<L>,...`). **Checks 123** (CURE BLINDNESS, was `data/c68/chkblind`) **and 124** (the p20a3_s11k load) in `data/c70/chk123`, `chk124`, linked from `data/c70/cd/`; check 124's original side: slot J from `chk124/start` (slot.py G -> J), `boot j`, Right, Up, `l`, `e s j n`.

**Chat 69:** **the magic-gear map:** `tools/lab/gearmap.gd` (`godot --headless --path <proj with tools/lab> -s
res://tools/lab/gearmap.gd -- <game>` > `data/c69/gear.tsv`: every ITEM*.DAX / MON*ITM.DAX item with type, plus, price,
class byte and a scroll's spells; MON*CHA names; each GEO square's info byte) and `tools/lab/gearmap.py <gear.tsv>
data/c62 [all]` (needs `game/ECL<f>.DAX`; joins each TREASURE and each LOAD_MON with the area's search dispatch:
direct, a `[9800]` loop, or a byte table `COPY_MEM [T], [event], [var]`, ECL address A at block byte A - 0x9900 + 2;
ON_GOTO is 0-based) > `data/c69/gearmap.txt`; the summary is in docs/strategy/poolrad.md. **Check 121** in
`data/c69/chk121/` (`data/c69/cd/` links `game` and 121; the original's trace `data/c69/hedge/trace121.txt`): 5:5's hedge
from check 28's start (already in 5:5 at 11,7 W). **A start's seed for a save-or-die:** try a few `seed.py set` values
with the same keys (boot, seed, keys, dump the HP column) and keep one where the save fails. **refcheck** restarted after
any later change to main.gd (it copies the source at its start).

**Chat 68:** checks 118-120 in `data/c68/chk118..120/` (`data/c68/cd/` links `game`, each, and `blind`, the ready
CURE BLINDNESS check for Combat in `data/c68/chkblind`; its tested fix `data/c68/temple_blind.diff`). **Ours' keys
after a won fight with treasure:** `fightend`, Enter (the fight's last line), Enter (THE PARTY HAS WON / experience: the
treasure screen's results mode), then E (EXIT), N (the treasure-left question). **Whole-file GAME.OVR disassembly**
for a grep: `/tmp/c60bin/ndisasm -b16 -o 0 game/GAME.OVR > /tmp/x.txt` (the lab wrapper needs `-o`); a near `call`
in that listing crosses a 64K wrap wrongly (0x10230's `call 0x1ecb3` is 0xECB3: `ovr.py dis` the lower address
when the target isn't a `push bp`). **Effect records in memory:** 0x2BD3C adds one (type +0, minutes +1, power +3,
+4 the flag that makes removal (0x2AF10) run the type's handler 0x2AEEA). The original's shop BUY at 16 items and
DROP / HALVE on a readied item show no message in a grab 0.3 s after the key.

**Chat 67:** checks 113-117 in `data/c67/chk113..117/` (`data/c67/cd/` links `game` and each); the original's traces
`data/c67/trace113..117.txt`. **The original's vertical menus take End / Home, not Down / Up** (Down in ours' keys is
fine in a menu, but on the walking screen Down turns ours' party round: use End in ours' keys where the original's
menu may already have closed, check 117). **The case-blind lookup test:** `/tmp/c67case/run.sh`-style: a check's keys
on the game copy with every name lower-cased against the upper-case copy (logs and every file's MD5 the same).
**Builds:** `tools/build/windows_test.sh <sha> 0.1.6 <builds>/release-0.1.6` and `tools/build/linux_build.sh <sha>
0.1.6`; the extra Linux smoke on a lower-case copy is the build script's (b) by hand with the names lower-cased.

**Chat 66:** checks 105-112 in `data/c66/chk105..112/` (`data/c66/cd/` links `game` and each); the original's ends and
traces: `trade/`, `drop/`, `halve/` (orig only), `gem/`, `jewel/`, `raise/`, `cures/` (start, orig, trace.txt). A start
made by editing check 101's or chat 64's temple start: gems +0x92, jewelry +0x94, platinum +0x90, status +0x10C (6 dead),
a `.SPC` record appended (9 bytes: type, minutes u16, power, 5 zero bytes). **The original loads any `CHRDATxn.SPC`
beside a record and deletes it when it saves a member with no effects** (so a stale `.SPC` in a lab folder is the
copy's, not the game's: checks 19, 21, 34, 35 had some). **statediff** now compares whole items, the effects and the
ability scores; a break test is `data/c44/brk` at origin/main + the new `tools/statediff.gd` copied in (then
`git -C data/c44/brk checkout -- tools/statediff.gd`). **A variant to prove a check sees its step:** copy the check
folder to /tmp, change its keys, reseal it there (`sha256sum keys ours.cfg area orig/* start/* > manifest`), link it
from a /tmp `cd/` beside `game`, `DC_DATA=<that cd> DIFFCHECK_ONLY=<n>`. **Shop APPRAISE in the original:** A, then G
(gems) or J (jewelry), SELL or KEEP; the camp item menu's TRADE / DROP / HALVE: T (TRADE WITH WHOM? End, SELECT), D (YES),
H; a readied item is neither traded nor sold. **The temple's HEAL list** opens on CURE BLINDNESS (End x5 NEUTRALIZE
POISON, x6 RAISE DEAD). **The Linux build:** `tools/build/linux_build.sh <commit> <version> [<out>]` (try it with a /tmp
out first). ENCOUNTER_MENU's choice logic: `ovr.py dis 2eb0 1100`; the party speeds 0x9484; the walking-key routine
`ovr.py dis 17060 1200`, the main loop's key handling `ovr.py dis 4060 400`.

**Chat 65:** checks 99-104: 99 and 100 were chat 64's / Combat 30's ready checks (`data/c64/chk_arena`, `data/c65/chk100`);
101-104 in `data/c65/chk101..104/` (`data/c65/cd/` links `game` and each). The original's ends: `data/c65/sell/orig` (a SELL),
`cure/orig` (camp Bless + cure; its start `cure/start`: check 26's with ARN's HP +0x11B = 5; trace `cure_orig.txt`),
`train2/s1` (check 96 + a second TRAIN, slot G names: also check 103's base), `train2/start` / `orig` (level 2 -> 3; trace
`train2_orig.txt`). **Camp MAGIC in the original:** the spell list's light starts on the last spell and End wraps it to the
first. **A shop's SELL** sits under VIEW, ITEMS (not on the shop menu); a readied item isn't sold (no message). **`slot.py`**
wants its target folder made first; renaming slot files by hand skips the SAVGAM name patch (use slot.py). **Testing a
diffcheck.sh copy:** keep it beside the original (`~/gbr/checks/dc65.tmp.sh`): it finds `data/` beside itself. **Trace in a
booted session:** `trace.py install` after each `pl.py boot` (the boot reloads the game). ENCOUNTER_MENU's disassembly:
`ovr.py dis 2c3e 900` (the choice logic from 0x2EEF not read yet).

**Chat 64:** checks 94-98 in `data/c64/chk94..98/` (`data/c64/cd/` links `game` and each; `cd/arena` and `cd/temple`
are ready checks waiting on Combat: `DIFFCHECK_ONLY=arena` / `temple`). **The handler table:** `~/gbr/checks/diffcheck.sh`
copied to `/tmp/opcov/dc.sh` with `--coverage=/tmp/opcov/cov/$n.json` added to ours' command line (main.gd's dev
coverage, a debug build's option) and `H=` pointed at `~/gbr/checks`, run on the repo; then `python3 tools/lab/opcov.py
<cov dir> data/c62` (lab copy `data/c64/opcov.py`; the result `data/c64/opcov_93.txt`) prints per opcode its sites in
Pool's 29 blocks and the checks that ran it; a CALL split by target is the same idea (docs/diff-checks.md "Chat 64").
**Reading a clock cell live:** `data/c61/ecl_poke.py 49C7` while the original runs a script (CLOCK's no-op seen so).
**ECL CLOCK** is GAME.OVR 0x3807 -> 0x241A1 (the clock words, the limits at DS 0x363A) -> 0x23DCC (durations). **A record
edit for a start:** `CHRDATG<n>.SAV` experience +0xAC (u32), coins +0x88 + 2 x kind (u16; gold +0x8E) (`data/c64/train/start`,
`data/c64/temple/start`). **Routes:** `route.py` `load(geo, map)`, `route(start, goals, avoid events)`, `keys(path, facing)`
(3:0 is GEO3 map 0, 7:22 GEO7 map 22; `evmap.py <geo> <map>`); 7:22 hides the square on the place line, so `walk=` can't
steer there. **7:22's corpse region** (13,4) connects only one way, out through 6,1 into 7:23 (the x=15 corridor, the
rocks room and 7:23's returns all stay outside): no cheap start. In a duel the original's trace numbers the members set
aside as figures (the opponent is figure 6), so cmpdraws' positions line is off by that. Ours' keys after a lost duel need
one Enter more than the original's (fightend stops at the fight's last line). Lab slot J put back; G untouched.

**Chat 63:** 0.1.5 built (`builds/release-0.1.5/`, from 6d34e55; the Windows exe's native smoke line in `builds/smoke-0.1.5-win.log`). **ECL handlers read beside ours** (`ovr.py dis <hex>`): CLEAR_MON 0x1FA3 (also empties the coin pile 0x67F4 and the item pile 0x6810; 0x4435 the creature count, 0x84E7 "a LOAD_MON since", 0x6F83 the icon slot), LOAD_MON 0x1196 (63 creatures since CLEAR_MON), COMBAT 0x24E1 (fight only when 0x84E7; else temple 0x6E6C / shop 0x6DE2 / the treasure routine 0x6AA5), the fight's end 0x6AA5-0x6BEE (zeroes ECL 0x6DE3 / 0x6DE6; 0x5A47 the party-destroyed test, 0x6DE6 at 0x5B0F), TREASURE 0x26F6, PARLAY 0x3311, SPRITE_START 0x10FA / SPRITE_ADVANCE 0x155D, NEW_ECL 0x1918-0x19B2, the main loop 0x40DB-0x424D (LOOK 0x4136, the step 0x4192, the arrival 0x3EFA), the walking menu's keys 0x170AC-0x171C5 (unit 0x166CB). ECL cell offsets from [0x49D6]: address = 0x6B00 + offset / 2 (+0x5C6 = 0x6DE3); DS 0x6DE3 is a different byte (the round counter). **Scanning every block's listing** (`data/c62/ecl_*.txt`) with awk for an opcode pattern (TREASURE before CLEAR_MON, a test of [6DCA] after a stop, the creatures per fight) tells whether a finding reaches Pool. **The tavern brawl** (3:0, check 93's start, tpseed 62620001, GRAB): the original's trace `data/c63/brawl_orig.txt` (6402 draws, won) and end save `data/c63/brawl/orig` (Enter, E, N, RUN, ENCAMP SAVE at 3,11 W); ours parts at draw 765 (Combat's request); a 1-HP party (`data/c63/brawl/weak`, HP is record +0x11B) still won in the original. **Q26's replay:** a private OP_LAB `/tmp/oplab63` (oplab59's files, `logs/p20a3.log` and `.trace.txt` copied, `proj` copied from the repo and imported) gave p20a3 s11c -> s11k 0 differences. `mksave.py ... 49F2=<block>` skips an init that tests 0x49F2 before its LOAD_AREA_MAP (7:22: the old map stays): not for 7:22. Lab slots J and G put back.

**Chat 62:** checks 90-93 in `data/c62/chk90..93/` (`data/c62/cd/` links `game` and each). **The ECL dispatcher:**
GAME.OVR 0x3C73 (the opcode in DS 0x6F7F, a near call per opcode; the handler table printed by walking its `cmp al` /
`call` pairs, e.g. SURPRISE 0x240F, SPELL 0x3949, RANDOM 0xF7A, the arithmetic 0xEE9, AND/OR 0x1B35, COMPARE_AND
0x1833, FIND_ITEM 0x33B0, PARTY_STRENGTH 0x200C, WHO 0x3879). `data/c62/ecl_ECL<f>_<b>.txt`: every Pool block
disassembled (`tools/ecl.py dis`), for grepping an opcode's uses and what follows it. **Getting a party to a square in
the original:** editing SAVGAM's 0x3201 position doesn't move the party (the step starts from another copy); walk with
`pl.py do walk=<geo>:<block>:<x>,<y>[:<event to avoid>...]`, bash locked doors, and turn a script off by its cell
(0x4AB2 = 1 stopped 3:14's thieves; a cell is byte 1 + 2 x (address - 0x4900)); then ENCAMP SAVE J there and use that
as the start (`data/c62/cab` at 3:14's cabinets, `rugstart` by the rugs). The first key after `boot` is sometimes
lost: start with `wait=2`. **Picking a seed for an ECL roll:** compute it (TpDice: seed = seed x 134775813 + 1,
Random(n) = (seed >> 16) mod n) instead of searching: consecutive seeds and a golden-ratio spread all landed just
above the tavern's 25. Lab slots J and G put back.

**Chat 61:** checks 75-88 in `data/c61/chk75..88/` (`data/c61/cd/` links `game` and each). **The wall ahead in
statediff:** `tools/statediff.gd` compares the save's byte 0x3204 with ours' 0xC04E in a 3D area; the survey that found
13 checks differing ran from a worktree (`/tmp/wa61`) with the comparison patched in, through `diffcheck.sh <worktree>`
(90 s): a quick way to test a new comparison against every check before it joins. **Reading the original's state
live:** `dsread.py <DS hex> <n>` (0x6AAD: x, y, facing x 2, the wall ahead, the square's byte); ECL cells through the
far pointer at DS 0x49D2 (cell = 0x4900 + 2 x index; `/tmp/c61/ecl_poke.py`, kept in `data/c61/ecl_poke.py`, reads and
writes one: 0x49FB = 1 showed AREA's NOT HERE), the selected member's record through DS 0x5D92 (`data/c61/selstat.py`:
status at +0x10C). **Seed searches in ours:** one run over 40 seeds (`load=G,wait,tpseed=<s>,...` repeated) found the
plaza's encounters (check 51's start), the scribe (check 23's), a band encounter (check 31's) and rest interruptions
(an eight-hour rest after the arrival: `E,R,H,I x8,R`; the original `e r h i x8 r`). **Trace:** start the reader 3 s
before the first key (`sleep 3`), or it misses the first draws (an empty trace, or one starting at draw 7); **a full
buffer blocks the game** (~7980 draws: the original froze at CONTINUE BATTLE until a second `trace.py run` drained
it), so give a long fight's reader enough seconds. **Mksave jump saves:** the original's LOAD keeps 0x49F2 as saved,
so `49F2=<block>` makes the target area's init keep the jump's square (6:1's would place the party at the gate).
Traces: `data/c61/*_orig.txt`; the band's kobold fight (for Combat's clutter) `data/c61/kobold_orig.txt` (from draw
7) and its end save `data/c61/kobold_band/orig`. Lab slot G backed up in `data/c61/gbak/` and put back; J put back.

**Chat 60:** checks 72-74 in `data/c60/chk72..74/` (`data/c60/cd/` links `game` and each). 72/73 start from check
71's start (`slot.py data/c59/chk71/start G game J`, `boot j`, `seed.py set 33330018`); 74 from `mksave.py J G 1 18 4
9 N 4AB0=1` (lab slot G backed up to `data/c60/gbak/` and put back, the extra G files mksave wrote deleted). Traces:
`data/c60/surr_orig.txt` (23), `pay99_orig.txt` (20), `tavern_orig.txt` (28). The original's INPUT_NUMBER takes digit
keys (`pl.py do 9 wait=1 9 wait=1 enter`), ours `9,9,wait,Enter`. **`ovr.py dis` needs `ndisasm` on the PATH:**
`mkdir -p /tmp/c60bin && ln -sf ~/gbr/goldbox-reforged/tools/lab/ndisasm /tmp/c60bin/ndisasm`, then `PATH=$PATH:/tmp/c60bin`.
Finding a routine from a draw: the trace gives the caller (`OVR:09337` = ROB's item roll); its callers by scanning
every unit: `for fo,size in ovr.units(): ovr.dis(fo,size,stop=False)` and grep `-> 0x<routine>`. ECL operand reads
are `0x7609(<operand number>)` (ROB's handler 0x2AF7 asks for 1, 2, 2); ECL memory reads `0x82DF` (0xC04B-0xC04F:
0x83C4). Every ROB / one-item menu / 0xC04E reader in Pool: loop `tools/ecl.py dis` over each ECL block and grep.

**Chat 59:** checks 68-71 in `data/c59/chk68..71/` (`data/c59/cd/` links `game` and each). **cmpfight2.sh's
original side dropped the walk's keys from check 25's start (the party ended at the offering box): drive the original by
hand instead:** `pl.py boot j`, `trace.py install`, `seed.py set <hex>`, the walk with `pl.py do <key> wait=4`, then
`(DISPLAY=:99 setsid timeout 400 python3 trace.py run 380 > <trace> &)` before the first drawing key, the menu keys with
`dump`, `presser.py <s> noenter`, `killmine.py "trace.py run"`, `partyrec.py <names>` appended; then CONTINUE BATTLE
`n`, `enter`, `e`, `n`, ENCAMP SAVE J (`e s j`, `n`), `slot.py game J <dir>/orig F`. Traces: `data/c59/accept_orig.txt`
(981), `leave_orig.txt` (1164), `run220_orig.txt` (1109). **Never write the word the kill helper matches in a command
line that runs cmpfight2.sh** (`cat data/<that>.pid` killed the shell). **A seed search in ours in one run:** keys
`load=G,wait,tpseed=<s1>,Up,wait,wait,load=G,wait,tpseed=<s2>,...` through `data/c51/run.sh <check dir>` (60 seeds, 8 s).
A Player segment in a private OP_LAB: `/tmp/oplab59` (godot linked, `qs.cfg`, `root/POOLRAD`, `logs/<run>.log` and
`.trace.txt` copied, `proj/` imported), `OP_LAB=/tmp/oplab59 OP_SAVES=~/gbr/player_lab/.lab/player/saves
OP_SEG_TIMEOUT=1300 setsid nohup timeout 1500 python3 segment.py p20a3 s11c s11k --tplog` (12 minutes).

**Chat 57:** checks 65-67 in `data/c57/chk65..67/` (`data/c57/cd/` links `game` and each; run one with
`DC_DATA=$PWD/data/c57/cd DIFFCHECK_ONLY=<n> bash data/c52/dc_new.sh <repo>`). `data/c57/oursrun.sh <game dir> <cfg>
"<keys>"` runs ours on a kept game folder (for ours' ENCAMP SAVE after a 5:3 jump: run.sh keeps nothing). **A fight
check:** record the original with `cmpfight2.sh <slot> <seed> "" "<keys>" orig` (OSECS=240-360; give the texts
`wait=<s>` tokens and an `enter` where the original waits: 5:3's giants want one after COMBAT), then ours by hand
(`ours.sh --save=$PWD/qs.cfg --fast "--keys=load=<slot>,tpseed=...,<keys with waits>,quickall,fightend,n,wait x6,tplog,partyhp"`)
and `cmpdraws.py <orig> /tmp/cmp_ours.txt`; a fight that comes after a rest needs ours' waits before `quickall`
(else ours' fightend lands in camp and the fight is never played). With a party whose QUICK prompt the presser never
sees (c34d's, 5:6) answer CONTINUE BATTLE by hand and run `partyrec.py <the names>`. Traces: `data/c57/rest118_orig.txt`
(1290, MATCH), `giants_orig.txt` (1041, MATCH, party destroyed), `priest_orig.txt` (966, parts at 940). Cells in a
DAX block: data 2 bytes in (`dax.read_dax(...)[b][addr - 0x9900 + 2]`). Lab slot G was backed up to `data/c57/gbak/`
and put back; J put back from `data/c48/slotJ_backup`.

**Chat 56:** checks 62-64 in `data/c56/chk62..64/` (`data/c56/cd/` links `game` and each; run one before joining with
`DC_DATA=$PWD/data/c56/cd DIFFCHECK_ONLY=<n> bash data/c52/dc_new.sh <repo>`; **`cd/game` must be linked first**, or
the driver hangs on a missing game copy until its timeout). Ours' keys at a script's menu of two or more choices are
its letters now (Q24: Enter and the arrows do nothing there, as in the original). A start in an area whose jump drops
the original to DOS (5:3): `mksave.py` the jump save, let ours take it and ENCAMP SAVE into an empty slot
(`--keys=load=G,wait,Up,wait,wait,E,wait,S,wait,H,wait,wait,N`, in a /tmp copy of the checks' game), then
`slot.py <tmp>/game H data/c56/chk<n>/start G` (leave out ours' `.GBR`). Cells in a real start save: byte
`1 + 2 * (cell - 0x4900)` of SAVGAM (check 64 quietened 4:10's random squares that way). `route.py` takes map values:
for 5:3 the event is the value & 31 (`R.INFO[y*16+x] & 31`), and `keys(path, facing)` wants the facing as 0-3.
Lab slot G was backed up to `data/c56/gbak/` and put back at the end; J put back from `data/c48/slotJ_backup`.

**Chat 55:** checks 51-61 in `data/c55/chk51..61/` (`data/c55/cd/` links `game` and each; run one before joining with
`DC_DATA=$PWD/data/c55/cd DIFFCHECK_ONLY=<n> bash data/c52/dc_new.sh <repo>`). **`mksave.py J G ...` reads lab slot J:
put the pristine J back first** (`data/c50/slot.py data/c48/slotJ_backup J game J`); after `slot.py <start> G game J`
for a DOSBox run J holds that start, and the next `mksave.py` builds on it (52-54's starts carry 51's 0x4AB0 = 1).
Rest in a check: ours' keys `E,wait,R,wait,H,wait,I,wait,I,wait,R,wait,...,E` (camp, REST, HOURS, INC twice, REST,
EXIT); the original `e r h i i r`, then `e` to leave camp (checks 56, 57). WHO WILL ...? in the original: `enter`
takes the first member (check 58). When a jump save misbehaves in the original (5:4's runes press dropped to DOS),
start from an existing check's real save instead (`slot.py ~/gbr/checks/data/<n>/start G game J`; route with
`route.py`: `R.NE,R.SW,R.INFO,R.DOORS = R.load(<geo>,<block>)`, `R.route(start, set(R.squares(<event>)), [])`).
`origfight.py <secs> <out> noenter` plays an open fight on QUICK in the original and logs the screens (a rest
interrupted in 1:18 after 2:20 h, orcs: ours won in round 2, the original asked CONTINUE BATTLE; not compared draw for
draw, left out). Cells 0xC04B-0xC04F aren't in `eclread.py`'s array (junk there): the original keeps them as DS
variables (0x6AAD/0x6AAE for x, y). A private OP_LAB for a Player segment: `/tmp/oplab55` (README Chat 54's recipe);
Player 20's `p20a3 s11c s11k` replay takes over 590 s here: run it detached (`setsid nohup timeout 1500 ...`) and poll.

**Chat 54:** checks 49 and 50 in `data/c54/chk49/`, `chk50/` (`data/c54/cd/` links `game` and 49; run before joining with
`DC_DATA=$PWD/data/c54/cd DIFFCHECK_ONLY=49 bash data/c52/dc_new.sh <repo>`). A pre-fix run: `git worktree add --detach
/tmp/<dir> <commit>` and pass that path (remove the worktree after). A segment replay without touching the Player lab:
a private `OP_LAB` in /tmp (`godot` linked, `qs.cfg`, `root/POOLRAD` a copy of the checks' game, `logs/` with the run's
`.log` and `.trace.txt`, `proj/` copied from the repo and imported) with `OP_SAVES=~/gbr/player_lab/.lab/player/saves`;
`cmpdraws.py` reads from the Player lab. The band's water: `OverlandMap.load_from(...)`, `band_x(band)`, `water(value(x, y))`
in a small `--script` (band 2's water at the boat: east and south). The ECL dispatch is a cmp chain at GAME.OVR 0x3C79
(`3C op 75 07 0E E8 rel16`). START.EXE routines: unpack with `ovr.image()`, cut with `dd`, `./ndisasm -b16 -o <offset>`.

**Chat 53:** checks 47 and 48 in `data/c53/chk47/`, `chk48/` (run before joining with `DC_DATA=$PWD/data/c53/cd
DIFFCHECK_ONLY=<n> bash data/c52/dc_new.sh ~/gbr/goldbox-reforged`; `data/c53/cd/` links `game` and each check).
Driving the original with `pl.py do`: keys are lowercase names (`enter`, `up`, `end`); **a script's horizontal menu of
two or more choices takes only its letters** (Enter, End and Right do nothing there); its vertical menus move with
`end` (not `down` or `kp2`) and take `enter`. ENCAMP SAVE J is `e s j`, then `n` at QUIT TO DOS. Event tables in a
script block: `dax.read_dax(...)[block]` puts address A at index A - 0x9900 + 2 (the block's two leading bytes);
`evmap.py <geo> <block>` gives the squares' events. Lab slot G was backed up to `data/c53/gbak/` (put back at the end).
0.1.2's smoke extra: the Windows exe run natively (`--headless --log-file 'D:\...\smoke-0.1.2-win.log' --quit-after 300
-- '--game-path=D:\...\POOLRAD'`) logs the report line.

**Chat 52:** use `data/c52/dc_new.sh` (not c51's) for a new check: `DC_DATA=$PWD/data/c52/cd DIFFCHECK_ONLY=<n> bash
data/c52/dc_new.sh ~/gbr/goldbox-reforged`; it copies the linked game folder with `cp -rL` (c51's `cp -r` copied the
symlink, so every check played in the shared `~/gbr/checks/data/game` and two at once raced). Checks 41-46 in
`data/c52/chk41..46/`. A jump save starts with the original's 0xC04E/0xC04F stale (the old area's) until a turn
or step: start facing away from a door the on-move tests, then turn (check 46). A NO check from a jump save: `mksave.py J G <ecl> <block> <x> <y> <dir>`, copy `game/SAVGAMG.DAT`
and `game/CHRDATG*` to `chk<n>/start/`, ours.cfg from any jump-save check (`~/gbr/checks/data/8/ours.cfg`); keys
`load=G,wait,tpseed=11111111,Up,...` (the first Up jumps); on the walking screen N is a test key (the clock), so send
N only while the menu shows. Lab slot G was backed up to `data/c52/gbak/` before the jump saves.
`/tmp/ecl52/<file>-<block>.txt`-style listings: `tools/ecl.py dis game/ECL<n>.DAX <block>`.

**Chat 51:** a new check before it joins `~/gbr/checks`: `data/c51/dc.sh` is diffcheck.sh reading its checks from
`$DC_DATA` (`DC_DATA=$PWD/data/c51/cd DIFFCHECK_ONLY=38 bash data/c51/dc.sh ~/gbr/goldbox-reforged`; `data/c51/cd/`
links `game` to the checks' game copy and `<n>` to `data/c51/chk<n>`; `dc_new.sh` is the same from the 39-check script).
`data/c51/run.sh <check dir> "<keys>"` plays ours from a check's start and prints the key log (place, clock, the box's
text), all in /tmp (deletions in python, as the guard wants). **Never ENCAMP SAVE into the start slot J and then
`boot j` again**: J then holds the end; put J back with `slot.py` after each save (chat 51 lost two tries this way).
`pl.py do` keys 0.6-1 s apart; `seed.py set` right after `boot`; 60606063, 11111111 and 44444444 roll an encounter on
check 38's walk in 8:29, 33333333 doesn't. Checks 38-40 in `data/c51/chk38..40/` (keys of 38 also in `k38.txt`).
`ovr.py dis` needs the lab's `ndisasm` stand-in on the PATH (`PATH=$PWD:$PATH`).

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

# Test lab

## Current method (read this first)

This page is the lab as it is used now. The sections after it are the history, chat by chat, and hold
the detail behind each command. A chat that changes the method updates this page in the same push.

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
`scripts/dev/bot.gd` (3:11 and 5:5 must not drop below `data/refcheck_base.txt`); `git status`. A push that
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
  replays the whole run). An `-all` run takes 1-4 minutes. In parallel: about 8 lanes while Jeremy uses the PC,
  10-11 when it is idle (one area's variants in one lane). `dettest.sh` re-checks the repeatability.
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
  paths, every leftover listed with a reason. **Closed:** done, or two directed attempts in a row that add
  less than 1 point, with the leftovers listed (decided 2026-11-14). M6 coverage ends when all 29 are closed.

**Fights against the original (side lane)**
- `trace.py` records every draw the original makes; our engine replays them with Turbo Pascal's own Random
  (`--keys tpseed=<hex>`).
- `cmpfight2.sh <save> <seed> "<keys before>" "<keys after>"` plays one fight in both and `cmpdraws.py`
  compares draws, cells, CONTINUE BATTLE and the party's HP and status, ending `VERDICT: MATCH` or the
  first difference. `cmpfight3.sh` varies a fight with a second seed.
- `regress.sh` replays every recorded fight (18 of 20 MATCH as of 2026-11-14); `regress.sh record` records
  them again from the original. Run it after any change in `scripts/combat/`.

**Checking anything else against the original**
- `pl.py boot <save>` / `pl.py do <steps>`: a running session of the original (`dump` reads the screen as
  text). `mksave.py` makes a lab save that starts in any area.
- `ours.sh` / `t.sh --keys=...`: our engine headless with keys; `run_godot.sh` on a display for screenshots.
- `origvid.sh`, `oursvid.sh`, `vtl.py`: film both and time what's on screen (display work).

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

## Working from the cloud workspace (2026-11-10)

- If `~/lab` is gone, run `.lab/rebuild.sh` (a copy of `rebuild.sh` here): it unpacks DOSBox and
  Godot, copies the game, the scripts (from `.lab/tree/tools/lab`) and the git-ignored `font.json` /
  `wheel.json`, fills in the lab path in `por.conf` and copies `saves/quicksave.cfg`.
- `.lab/tree` is a copy of the repo on the PC. Changes go over as a gzip+base64 patch on stdin:
  `echo '<b64>' | .lab/apply.sh <md5>` (plain `patch`, since `.lab/tree` sits inside the repo
  folder and `git apply` would silently skip it), then `./check_godot.sh $HOME/mnt/goldbox-reforged/.lab/tree`.
- Our engine headless with key presses: `./ours.sh --save=$PWD/quicksave.cfg --keys=up,wait,1,...`
  prints position, clock, screen, script block and message after each key. Helpers in the list:
  `find=<event>` (squares with that event), `at=x;y;dir` (place the party), `xp=i:n`, `gold=i:platinum`,
  `program=0:<mask>` (open the party menu as a training room), `scroll=i:<spell_name>`, `party`
  (levels, HP, THAC0, saves, slots, money, spell book), `sheet=0` (the character sheet's text).
- `dump.py` prints the original's screen as text; `unexepack.py` unpacks START.EXE for reading tables.

## The whole lab inside the cloud workspace (2026-11-11)

The cloud workspace has Xvfb, ffmpeg and the X libraries, so the lab can run there too, with no
three-minute limit per command. Stage `.lab/tmp/poolrad.tgz` (a tar of the game folder),
`labextra.tgz` (font.json, wheel.json), the DOSBox and Godot archives and `saves/quicksave.cfg`,
unpack them into `/home/claude/lab` as `rebuild.sh` does, and nothing leaves the workspace.

- `pl.py`: a persistent session of the original. `pl.py boot <save letter>` starts it; then
  `pl.py do <steps>` sends keys while the game keeps running: key names, `wait=s`, `dump`
  (screen as text), `face=N|E|S|W`, `walk=<geo>:<block>:<x>,<y>[:<event to avoid>...]`, and
  `go=` (the same, but it flees encounters, quick-fights, bashes locked doors and leaves the
  treasure screen, until it arrives). The coordinates line only redraws after a step, so step
  once after an area change before `walk`.
- `exits.py <geo> <block>`: the squares where a step leaves the map.
- `t.sh --keys=...`: Godot check, then our engine with keys. Extra helpers: `area=<set>:<block>`
  (enter that area's script), `mem=<hex address>:<value>`.
- `sweep.sh [--only=<set>:<block>] [--depth=3]`: runs every area's scripts through our VM (every
  event square from every facing, every menu choice to a depth, fights taken as won) and lists what
  isn't built yet: opcodes, unknown CALLs, notes, script errors, and where each area leads.
- Saves made in the original's lab copy: B = Slums 0,11 W (west exit to Kuto's Well).

### Lab saves for any area, and tours (chat 5)

The original's load menu offers only A-J, and only A and J ship with the game copy. Make the
others from J:

- `mksave.py <base> <new> <ecl file> <block> <x> <y> <N|E|S|W> [strong] [xp<n>=…] [pp<n>=…] [addr=val]`
  copies the save and patches its script image's on-move entry with the game's own area change:
  load it (`pl.py boot <new>`), press Up once, and the original moves there. Our engine loads the
  same file (`--keys=load=<new>,up`). `strong` gives everyone 200 HP, AC -10, THAC0 1.
- `tour.py <geo> <block> <x,y> ...` plays squares in the original with a fixed policy and logs
  every settled screen to `cap/tour.txt` (`TOUR_ENCOUNTER=f` flees encounters; `answers=` feeds
  script menus). The same in ours: `--keys=...,tour=x;y,...` (add `--fast`).
- `plan.py <geo> <block> <x,y>` lists one square per event in walking order; `evmap.py` prints
  an area's events. A whole area in ours: `./t.sh --fast '--keys=load=J,area=<set>:<block>,tour=x;y,tour=x;y,...'`
  (quote the keys: the shell splits on `;`).
- The original's quick fights are slow and can stall (both sides guarding); check events, not
  fights, there. Where 0x49FB is set (Valjevo, the pyramid, the graveyard, many dungeons) the original hides the square, so
  `tour.py` can't route: step by hand.


### Chat 6 additions

- `settle.py [seconds]` answers the original's prompts (quick-fights, says no to CONTINUE BATTLE,
  leaves treasure, flees encounters) until the AREA menu is back. Run it in the background: the
  original's quick fights can take many minutes and sometimes stall with both sides guarding (then
  reload a save and try another way round).
- Reading the original's state: save in camp (ENCAMP, SAVE, a letter B-I) and read
  `SAVGAMx.DAT` (ECL memory 0x4900-0x52FF as words from byte 1, so `s[1 + 2 * (addr - 0x4900)]`).
  This is how chat 6 settled the area-memory rule.
- Our engine: `--battle-strong` (with `--battle=... --battle-fight=<seed>`) gives the party 200 HP,
  AC -10 and THAC0 1, to see a monster's powers play out (trolls getting up, the boar, the mummy).
  Monster files and ids for the powers: basilisk 2:26, troll 2:31, hill giant 2:55, mummy 4:114,
  vampire 4:23, wight 4:20, wraith 4:21, juju zombie 4:29, medusa 5:49, Tyranthraxus 5:66,
  ankheg 6:65, wild boar 6:120.

### Chat 7 additions

- `ovr.py` reads GAME.OVR: `dis <offset>` (far calls resolved through the overlay stubs, Pascal
  strings shown), `handler <type>` (an effect type's handler), `stub <seg> <entry>`, `cats` (when
  each effect type runs). The spell-cast handlers are a second table at DS:0x6B88 (GAME.OVR
  0x2A452 fills it), one per spell id 1-67.
- `tools/coverage.py <POOLRAD>` regenerates `docs/coverage.md`; update its STATUS lists as gaps close.
- `check.sh <tool>` runs the Godot check, then `tools/<tool>.gd` headless: `check.sh check_items`
  tests magic items and strength outside fights.
- Our engine: `--battle-give=<member>:<item name>` gives a readied item from the game's lists
  before a test battle; `--battle-fight=<seed>:use` has each member use its first usable item.

### Chat 8 additions (the playthrough bot)

- `bot.sh [plan] [args]` runs the bot from a fresh copy of the project (`BOT_ID=a|b|...` gives each
  run its own copy and its own `user://` folder, so two runs go side by side; `BOT_TIMEOUT` in
  seconds, default 7200). Logs go wherever you send them (`> data/botNNa.log`). `botstop.sh` stops
  every run (the engines run inside `botproj_*`, matched by working folder).
- The bot needs the area graph: `sweep.sh --depth=2`, keep the EXIT lines (strip ` >n`, `sort -u`)
  in `data/exits.txt`. Boats and the wilderness band's entrance menus aren't in it: the plan walks
  those (`answers`, `tour x,y`, `expect a:b`).
- Checkpoints: each `checkpoint <name>` line of the plan saves `user://bot_<name>.cfg` (in
  `~/.local/share/godot/app_userdata/Gold Box Reforged bot X/`). `--resume=<cfg>:<name>` starts
  another run from it. They are saves (game data): keep them in the git-ignored lab folder
  (`data/checkpoints/`; chat 8's set is in the PC's `.lab/tmp/checkpoints_chat8.tgz`).
- Plan commands added in chat 8: `modify` (every stat 18, 18/00 for fighters), `town` (the clerk,
  selling gems, jewellery and spare gear, the temple, every training hall, the inn), `grind <hex
  address> <value>` (camp and fight the interruptions until a script counter reaches the value: the
  Slums' 0x4ABB = 254), `level <n>` (camp and fight until every player character is level n,
  training as they qualify), `explore <events to skip>`.
- `tools/areas.gd` prints each ECL block's first texts (to name areas); `tools/dis.gd <game folder>
  <ecl file> <block>` prints a block disassembled (`-s res://tools/dis.gd`).
- Watching a run: `tail -F log | grep --line-buffered ...`; don't put `cut` or `awk` (mawk buffers
  its input) after it in a Monitor, or nothing arrives.

### Chat 11 additions (screens in the original's form)

- `cmp.py orig.png ours.png` prints the differing 8x8 cells of two 320x200 captures.
- `fast.sh --keys=...` copies the repo's scripts into `proj` (no full check) and runs ours.
- `sheetcmp.sh` replays each original VIEW capture (`cap/v/`, kept in `.lab`) in ours with the
  same keys (`screen=` saves the open screen) and compares them. Saves: I is J with Thrender
  holding every coin type and 16 items and Bakshi with spells of two levels; G is J moved to
  New Phlan 13,9 N (Up twice reaches the arms shop).
- The original: Home/End pick the character on the walking screen and in lists; a message
  stays about 0.7 s on row 24 (`timeit`-style polling of `lab.text(screen, 24)`).
- `combatcmp.sh` does the same for the combat screen (`cap/c/`, save E: J moved to the Slums at
  14,1 W, Up twice meets the orcs). `combatseed=<n>` fixes our fight's dice: seed 2 lets Thrender
  act first, as in the capture. Combat captures: the menu, MOVE, VIEW and its ITEMS, AIM (self,
  NEXT, MANUAL), USE, DONE, GUARDING, a cleric's menu and CAST page, DONE with BANDAGE.

### Chat 12 additions

- The bands' site tables (row y values, counts, x values, site types) sit two bytes past the
  addresses the listing shows: 7:26's rows are at 0xB04C, not 0xB04A. 7:26's rowboat to the
  pyramid is at 6,14 (site type 5); the pyramid's door, 6,16, is on the island.
- Plan additions: `answer <area> <text>|<a>,<b>,...` takes the choices in turn, one each time the
  question comes; `gate ... <a>,<b>` gives a way through more than one menu (the rowboat's YES,
  then the door's ENTER); a `parley` cue whose menu offers ADVANCE instead of PARLAY advances
  until it can talk; `explore <events>` also walks round the skipped events' squares.
- Secret doors (Yarash's pyramid): the step script refuses a move until a roll on arrival finds
  the door (0x4A4F); the tour now searches, steps off and back on, up to six tries per door.
- `data/exits.txt`: the sweep's picks for 7:22 14,7 (the rocks room) were recorded on the first
  visit's flash and come out as GO BACK later; the lab copy keeps that exit without picks.

### Chat 13 additions

- Runs side by side: `BOT_ID=b BOT_COVERAGE=$PWD/data/coverage_b.json BOT_BRANCHES=$PWD/data/branches_b.json`
  (start from copies of the main files), then `merge_cov.py <out> <in>...` unions them. Set
  `BOT_TIMEOUT` for long runs (default 7200 s). Coverage is saved every two minutes and on exit
  (a run stopped by `timeout` still saves).
- `settle2.py` is `settle.py` that also prints each "EACH CHARACTER RECEIVES n EXPERIENCE
  POINTS" screen (experience checks against ours).
- Plan: `restuntil <hour>` rests in camp to that hour (Stojanow's trader comes before 14:00).
  A `parley` cue also matches the text shown just before a bare encounter menu.
- Lab saves: C is J moved by `mksave.py` as each check needs (Podol Plaza with `4AB0=1`,
  Sokal Keep 8,14, the Zhentil outpost `strong`); remake it before use.
- `data/exits.txt`: 6:28's exits at 4,0 (ATTACK, then SURRENDER: stripped and thrown out) and
  5:3's 0,11 W (it lands in a walled-off part of 5:6 with no way on) are left out.

### Chat 14 additions (coverage runs, area by area)

- `cover <set:block> [minutes]` (plan command): a coverage run of one area, as decided
  2026-11-13. Every map and every part of a map the block runs on (5:5 runs on maps 3-6), each
  event square visited (through walls the script lets the party pass when there is no walking
  route: the inner castle's hedges), then a step from it in each direction and a second arrival
  (the "already done" side); a rest and a step off each edge per part. Every fight is won at
  once by shortcut (`COVER FIGHT` lines, for the combat suite); the party is restored between
  events. At each menu each choice no run has taken is queued; afterwards each is played for
  real from an in-memory snapshot of the step that led there (`main.dev_snapshot` /
  `dev_restore`): the same step, the same answers, then that choice, and on with the bot's
  policy. A typed answer also queues a wrong one (`XYZZY`). `COVER JOB`, `COVER WIPE` and the
  closing `==== COVER ... done: {...}` line are the log's landmarks.
- Cover plans are `tools/plans/cover_<set>-<block>[-variant].plan`: `rules playthrough.plan`
  (the standing answers), `start <checkpoint>` (from `--checkpoints=`, which `bot.sh` sets to
  `data/checkpoints`: `start chat13a_latest/valjevo4`, `start chat10a_latest/slums`), travel,
  `cover`. The party is raised to the area's `expect_level` by the level shortcut (logged).
  `shortcut keep <n>` keeps the first n members (scripts that branch on the party's strength).
- `covreport.sh <abs coverage file> --areas=5:5 --missed=5:5 --critical=5:5`: `--critical`
  counts the story-critical instructions (ways in and out, set fights, quest flags
  0x4A20-0x4AFF) and lists those not run. `BRANCHES=<file>` names the shadow file to merge.
  Give the coverage file as an absolute path (the report runs inside `proj`).
- In a coverage run ladders and stairs are always taken (the area's other level); a menu inside
  a subroutine (a shared YES/NO) queues its other choice once per caller (`key@<return address>`);
  `cover <area> <minutes> all` replays every other choice whether taken before or not (variant
  runs: `cover_5-5-small.plan`, one member, for the false Tyranthraxus's collapse).
- The report leaves "dead" outcomes out of its counts: an ON_GOTO right after an ENCOUNTER_MENU
  can't take an outcome no choice gives under the menu's reactions, and ADVANCE isn't offered
  at distance 0 (`dead n` in the last column).
- `cover_all.sh <area> ...` runs areas two at a time (`runcover.sh <area>`: its own
  `data/cov_<area>.json`, started from `data/coverage.json`, log `data/cover_<area>.log`;
  `ROUND=n` adds `_r<n>`); `covsum.sh` prints one line per area; `merge_cov.py` unions them.
  Results by area: `docs/coverage-areas.md`; fights won by shortcut: `docs/cover-fights.md`
  (`cover_fights.py <logs>`).
- Travel knows the parts of a dungeon area (squares that reach each other on foot on the area's
  own map): an exit is only used from the part it is in, and an arrival is placed in the part
  of the square the sweep arrived on (`-> <to> at x,y,dir`).

### Chat 15 additions (coverage runs, per-area fixes)

- Ways in are grouped by the part of the area's own map they arrive in (`_cover_ways_in`): an edge
  way in whose arrival side is walled on the area's map is left out; each part's ways are tried in
  turn until one gets in; if none does, the part ends with a logged teleport to its arrival square
  (`SHORTCUT teleport ... no walking way into part`). 5:4's south edge reaches four parts of map 4.
- A menu brought by a rest (the city watch in 3:11, a patrol) queues jobs that rest again, up to 8
  tries, until it comes (an interruption is a roll).
- States: a job that ends in the area with the area markers or quest flags (0x4A00-0x4AFF) switched
  on or off (a counter going up doesn't count) keeps its end snapshot; after the jobs, up to six
  such states are walked again like an arrival, their own menus queued and played
  (`==== COVER ... walking again in the state 4A0E=1 ...`, `"states"` in the closing line).
- Stairs and ladders are taken (YES) only on the square the walk is going to; on the way they are
  passed (2:9's tower stairs bounced the walk up and down).
- Wilderness bands (6:25, 7:26, 8:27): `cover` walks every square of each part arrived in, nearest
  first, a step at a time (`_cover_band`); a step that leaves the band is undone and that square
  isn't walked through again; then a rest. Plans `cover_6-25.plan` etc. start from "zhentil".
- `cover_<area>-all.plan`: the area's plan with `all` (every other choice replayed, taken before or
  not), 40 minutes: the variant that opens states. `cover_5-4-alarm.plan` / `cover_5-4-late.plan`:
  5:4 from "valjevo4" (alarm on) and "valjevo6" (after 5:6).
- `runcover.sh`: `PLAN=<plan>` runs a variant into the area's own files. `cover_q.sh
  5-4:cover_5-4-late.plan:_late 6-25 ...` runs a queue two at a time. `covsum.sh` takes any
  `cov_<set>-<block>[-variant].json`.
- Report: a test of flag bits that no script of any data set ever sets (OR, WRITE_MEM, AND
  from elsewhere, any other write to the byte) is dead (5:5's 0x9C93: 0x4A67 bit 7).
- Flee jobs: each set fight a run meets queues one replay in which the party flees at once
  (`SHORTCUT flee`, `combat_screen.dev_flee`), so the scripts' "fled" side (0x6DC7 = 129) runs.
- Coming back onto an event square happens three times, the script's dice rerolled for the 2nd
  and 3rd (a restore brings the same dice back: a RANDOM in an event always came out the same).
- A map a band's own script loads (7:26's lizard men's village) is walked like any map of the area.
- `shortcut flag <hex addr> set|or|and <value> <why>`: a story flag as a player can have it, for
  variant runs (`cover_5-4-disguised.plan`: 5:6's disguise worn into 5:4). Logged.
- `missctx.sh 5-4`: each missed branch with the two instructions before it, for writing reasons.
- `cover <area> <minutes> all fresh`: "fresh" walks to each event from the part's arrival, not from
  where the last event left the party (an alarm one fight raises hid 5:4's fighter). `-fresh` plans.
- A step that puts the party in another part of the same map (2:9's tower stairs move it within
  map 9) is a new arrival, walked later.
- The tour's repeated-question rule cycles through the choices once its "way out" has been taken
  five times (7:23's "DO YOU REALLY MEAN NOKNOK?": NO only asked for the word again).
- Report: the encounter dead-outcome rule looks past instructions (and subroutines that leave the
  menu's variable alone) between the menu and its ON_GOTO.
- The runs are frame-bound (about 10% CPU each): `NOWAIT=1 P=3 cover_q.sh ...` runs three at once
  beside another queue.

### Chat 16 additions

- **Speed:** headless Godot runs in low-processor mode, which sleeps 6.9 ms a frame (145 frames a
  second): that, not the work, held every bot run to about 10% of a core. `--fast` now turns it off
  (`OS.low_processor_usage_mode`), so a run takes all of a core and goes about 30 times faster
  (4:21's `-all` run: 52 s, was 1628 s, the same jobs and squares). `--frame-sleep` keeps the old
  pacing. The bot's `_settle` limits are real time now (140 s, and a quiet window of 70 ms), as
  they were in frames before: counted in frames, 6:28's guided tour outran them. The cloud
  workspace has two cores: `P=2`. `GODOT_ARGS=--print-fps ./bot.sh ...` shows the frame rate.
- Coverage runs visit every square of every event (scripts tell an event's squares apart by
  position), and come back onto each from every open side in turn (at least three times, dice
  rerolled), so the party arrives facing each way (6:1's slave pen tests the wall ahead, 0xC04E).
- Loot: the bot keeps the item types some script looks for (FIND_ITEM 74, 75, 82, 91: 6:1's
  captain's pass, bought from the seedy man, has no price and was left on the treasure screen).
- Report: a flag byte's possible values come from every write to it (WRITE_MEM constants,
  indexed constant writes; anything else makes it "any"); 0x4A00-0x4A1F are zeroed on entering an
  area, so only the area's own writes count for them. A COMPARE with a constant that every
  possible value answers the same way makes the IF's other outcome dead (4:21's "if the visit
  flag is over 1, reset it", where nothing writes more than 1).
- `misswhy.py <listing> < missctx output` puts a first guess before each missed branch: unreached,
  roll, counter, clock, fight, party, menu, a flag's written values, or "outside" (nothing in the
  area writes it). `missctx.sh` leaves the listing in `/tmp/dis_<area>.txt`.
- Coverage walks also LOOK facing each way at every event square (LOOK runs the step script from
  where the party faces); a menu LOOK brings queues jobs that look again.
- A flee job flees only the fight it was queued for (`flee_at`); before, it fled the first fight it
  met, so chained fights (6:28's guard waves, then the commandant) never had their own fled side.
- A typed answer: the word the script compares just ahead is worked out through the numeric
  COMPAREs and IFs on the way (4:21's patrol wants SHESTNI unless 0x4A26 is 255, then SAMOSUD).
- `_settle`'s quiet window is 15 ms and at least 10 frames (`QUIET_MS`).
- `runcover.sh` gives each variant its own project copy (`BOT_ID=<area><suffix>`); two variants of
  one area still share `data/cov_<area>.json`, so don't run them at the same time (the last to
  save wins).
- The bands' plans replay every choice (`all`): the plan's IGNORE CAVE had kept 6:25's caves (the
  boars, the anhkheg, the thri-kreen) from ever being walked once ENTER CAVE had been taken once.
- `walls.gd` (copy into `proj/` as `_walls.gd`): `godot --headless --path . --script res://_walls.gd --
  <GEOn.DAX> <block> <event|-1>` lists event squares and their walls.

### Chat 17 additions

- **Speed, again (about 6 times):** a profile of a coverage run (each routine timed) showed two
  costs that weren't work. Drawing the screen took about 9 ms a call (`_show`: the 3D view and
  the adventure screen, in GDScript), a third of the time; `--no-draw` (dev builds) skips it
  and keeps what the game needs from `_show` (the area's script for the map). Then `_settle`'s
  quiet window of 15 ms real time was most of the rest: it is now counted in game time (the
  same 375 ms of game time as 15 ms at `--fast`'s 25 times), and `--time-scale=1000` makes that
  a few frames. `bot.sh` passes both. 4:21's `-all` run: 504 s → 83 s on a shared core, the
  same jobs, squares, tries and states (64, 637, 5096, 6). `BOT_SRC=` runs another copy of
  the source (for before/after tests).
- The tour's fixed 60 frames after each step end once nothing has been busy for 8 frames
  (`main._step_wait`).
- **Resuming a run cut off by a restart:** `runcover.sh` sets `BOT_RESUME=data/resume_<area><suffix>.txt`;
  the run writes each finished job and state walk there. Rerun (`cover_resume.sh`), it walks
  the maps again (that queues the jobs with their snapshots) and skips what was done, except a
  job that opened a state not yet walked. Before, an `-all` run longer than the 30 minutes
  between restarts started over each time and never reached its later states (1:24, 2:20, 7:22
  in chat 16).
- **The fight's result (0x6DC7) in the original:** the ECL window 0x6B00-0x6EFF is a word
  array at the far pointer DS:0x49D6, address - 0x6B00 times two (GAME.OVR 0x8314; 0x4900-0x4CFF
  are at DS:0x49D2, 0x9700-0x98FF at 0x49DA, 0x9900-0xB6FF bytes at 0x49DE). 0x6DC7 is +0x58E:
  GAME.OVR writes it only as 0 (a fight starts, 0x6AB1), 0x80 (0x6B3B) and 0x81 (fled, 0x5C2F).
  So "0x6DC7 = 1" (1:24, 2:20, 3:0, 8:29) never holds; the report knows (`ENGINE_VALUES`) and
  also works out COMPARE_AND pairs that never match, and leaves an instruction only a dead IF
  leads to out of the critical counts. 0x6DC8 (+0x590) is counted by 0x672A (called at 0x6AC5):
  combatants by +0x108→0x13, +0x10E and +0x10D; not worked out yet, our engine leaves it 0.
- Every event square is also come onto the first time with SEARCH on (`_cover_first_search`):
  7:22's rocks room flashes a party away unless it searches the first time (then "A STRANGE
  TINGLE" and THROW A ROCK).
- A choice at an encounter or PARLAY menu is played three times, the dice rerolled for the 2nd
  and 3rd (the reaction is a roll); a rest job's later tries reroll too (a restore brings the
  same dice back, so its 8 tries were one). ADVANCE from distance 2 has its own job key, so a
  job's ADVANCE leads to another and PARLAY at distance 0 (2:15's kobolds).
- A menu choice is queued again when the area's flags (0x4A00-0x4AFF) differ from when it was
  queued (up to three ways a run meets it; repeats are `key#n`): 7:22's second THROW A ROCK.
- `shortcut item <type> <name>`: the first member carries an item of that type (a bare record),
  logged, for variants (`cover_6-19-bottle.plan`: pledged to Diogenes, carrying the silver bottle).
- Report: a COMPARE of what an AND with a constant mask just wrote, against a constant with bits
  outside the mask, is never equal (6:19's 0x9927).
- `cover_6-25.plan` answers STAY IN at the caves' passage (the walk of a cave part had answered
  LEAVE CAVE on its first square).
- Stairs are taken once per square the walk goes to (2:9's tower stairs land on the other
  stairs, which asked again: up and down until the loop rule stopped it).
- An area that sends every party out and changes the story flags on the way in (6:19) is come
  into again by the same way, from there.
- The tour's repeated-question rule counts since the last `dev_restore` (`main.dev_restores`):
  a coverage walk comes back to a square from a snapshot on purpose (6:25's cave passage).
- An area whose script reads the hour (0x49C8/0x49C9; 20 areas do) is walked once more twelve
  hours later (`SHORTCUT clock +12 hours`, a state named "part clock +12h"): 5:6's smith works
  only until 14:00, and the runs' checkpoints came at night.
- A fight with allies in it (0x80) queues an "ally attacked" job: won, with 0x6E33 set as after
  a YES at ATTACK ALLY (logged `SHORTCUT ally`).
- `cover_2-9-towers.plan`: the walk flees the gate's bugbears (fighting them marks both towers,
  0x4A77 |= 12, so the tower rooms were always empty).
- A job that ends in the area takes one more step its way (6:1: SHOW PASS lets the party by,
  and the captain's room is through the door).
- An event at which the walk itself changes the story flags opens a state too (7:17's kobold
  attack moves 0x4A7E on with each fight won; its later stages come on later arrivals).
- The band caves checked in the original (chat 17, save H from `mksave.py J H 6 25 <x> <y> <dir> 4A9E=255`, which
  puts the party in the cave map, GEO6 block 25): the entrance at 15,3 is walled north, south and west in the
  original too (a dead end facing out); from 0,9 north is open and the party walks 0,8 and 0,7, as in ours.
  The walks had stopped at the entrance: the four searches in a row asked the passage question four times, and
  the repeated-question rule answered LEAVE CAVE. In coverage runs the rule now waits for a seventh time.
- A part's arrival square, when it has an event, is LOOKed at facing each way before the walk
  (7:23's storeroom: arriving by teleport, any step off flashes the party away again).

### Chat 19 additions

- **Runs no longer depend on machine load:** `bot.sh` runs Godot with `--fixed-fps 1000` (each frame is a fixed
  1 ms, times `--time-scale=1000`: one game second; `BOT_FPS=` drops it). Game timers and the bot's frame-counted
  waits now see the same time on a loaded machine as on an idle one. Every generator that rolled from the clock
  now draws from the run seed (`_seed_all` in bot.gd: the script's dice, `main.dev_rng` for the screens' fights,
  camp, shops, temples and party menu, the doors, the bot's own choices, Godot's global one, level grants), at the
  start of the run (`== run seed <hex>` in the log; the plan's `cover ... seed=` if it has one) and again when a
  coverage run begins. A coverage run without `seed=` uses the run seed, so the one logged value replays the
  whole run, travel in included. Checked with `dettest.sh` (2:15 -all): alone and all 10 of P=10 the same walk line
  for line; a run replayed from its logged seed the same. Side effect: 2:15 -all takes 85 s alone (was 5-6 min),
  160 s each at P=10. All diverged jobs in those runs are reroll jobs (new dice by design). Open: 2:20 has 34
  plain jobs whose replay goes another way (0x9D7E vs 0x9DDE); not explained yet.
- `dettest.sh <tag> <n> [source]`: n copies of 2:15 -all (`cover_2-15-det.plan`, a fixed seed) at once from the
  same coverage files, each walk compared with the first.
- **Number prompts:** at an INPUT_NUMBER the bot typed its words (read as 0) every time, so 3:0's wager was never
  placed. Each number prompt now also gets jobs typing 1, 100, 1001 and 9999.
- **`shortcut npc <monster id> <morale> <why>`:** a monster record of the area's file joins as NPC_ADD makes it
  (5:7's party of eight). Logged.
- Map tools (run in `proj/` by `geo.sh <tool> <GEO file> <block> [x,y ...]`): `mapdump` (the map as text: event
  numbers, walls with their type, D/L/W doors), `mapparts` (connected parts and their events), `mapedge` (a
  square's walls and doors on each side). A door can be on one side only (2:9's towers: the door is on the inside,
  the outside square is walled on all four sides; the way in is the stairs' script move).
- Findings (scripts): 7:23's event squares 1-10 are secret doors (0x9A09: a RANDOM 5 per member against search and
  race; 0x4A4F bits; the on-move script blocks the step until found, 0x9C24). 2:9's towers are entered by the
  stairs on (4,5)/(11,5) facing south (0x9CB7 table, 0xA16A); the rooms are manned only until the gate's
  bugbears are beaten (0xA60E sets both tower bits). 3:8's clerk takes reports first (each byte 255, 0x9F5A),
  then lists at most three commissions in order (0xA845); with 5:7's report taken the report loop leaves for the
  end game at 0x9D3E (0xB589), so the list never runs then. 4:10's kill counters only grow, and a byte add wraps:
  past 249 they are reached by placing the party on the event square, not by walking (wandering fights wrap them).
- Directed plans (chat 19): `cover_6-1-boyleave`, `cover_7-23-vats`, `cover_7-23-store`, `cover_3-0-procl`,
  `cover_5-7-dagger`, `cover_5-7-eight`, `cover_4-10-counters`, `cover_3-8-later`, `cover_3-8-later2`,
  `cover_2-9-climb`, `cover_5-3-disguised`, `cover_5-3-temple`, `cover_5-6-disguised`, `cover_2-20-fortune50`,
  `cover_2-20-fortune100`, `cover_2-20-killed`; `cover_3-8-reports2` heals in 3:0 first (chat 18's run never reached
  the clerk: hurt, it left for the inn and came back to a locked hall).

### Chat 18 additions

- **States, in order and more of them:** chat 17 walked six states, in the order they were opened, and nearly every
  run opened 12-18; the first six were mostly the area's own per-visit markers (0x4A00-0x4A1F), and states with
  quest flags were dropped (4:2's sealed chest, 0x4AC8 = 1; 2:9's states past the gate after paying). Now parts
  no walk has been in come first, then states inside the area that change a quest flag (0x4A20 up) or bring a
  quest item, fewest changes first, then the rest (`_cover_state_rank`); up to 16 are walked (`cover <area>
  <minutes> all states=<n>`), 48 kept waiting. A state walk takes about 20 s, so an `-all` run takes 5-6 minutes.
- The log's `==== COVER` lines carry the seconds since the run began (`[123s]`), with a "first jobs done" line:
  in 4:2, the first walk 16 s, its 69 jobs 5 s, each state walk 16-20 s. Walking is where the time goes.
- **Quest items open states:** a job or a walk's event that leaves the party with more of an item type some
  FIND_ITEM looks for (74, 75, 82, 91) names the state `item<type>+` (6:1's captain's pass).
- **WHO jobs:** the member picked at a WHO prompt is read next (4:2's thieves' well: RANDOM 99 against the
  climber's climb-walls skill, 0x6BAB), and the bot always picked the first member, so Restal never appeared. Each
  other member gets a job once a run (`<area>|<menu>:who<n>`). 4:2's last fight and flag came from it.
- **Encounter and PARLAY rerolls until dry:** a reroll job tries up to eight times (was three), stopping after
  two tries in a row that add nothing to the area's coverage.
- Report: ON_GOTO / ON_GOSUB on a byte the game itself sets leaves the entries no value picks out (dead). 0x033D,
  the wilderness heading, is read as the heading doubled (0, 2, 4, 6: GAME.OVR's ECL memory) and no script writes
  it, so the bands' 8-way ON_GOTOs never take 1, 3, 5, 7 (6:25 71 -> 76% of branches, 8:27 73 -> 80, 7:26 78 -> 84).
- Report: an ENCOUNTER_MENU's dead outcomes are worked out when only its reactions are constants (the distance
  may be a variable: then ADVANCE's reaction stays in), and a GOSUB to a routine that is only the menu (7:17's
  0x9914, 0x9934) stands for the menu at its caller's ON_GOTO.
- Report: `DEAD BUT TAKEN` lines name any outcome a rule calls dead that a run took (a wrong rule). The first two
  rules it caught: the never-set-bits rule didn't know indexed writes (WRITE_MEM_BASE_OFF reaches any byte from
  its base up: 3:14's lock routine writes 0x4AEA + n) or writes by other instructions; fixed, none left.
- `mkreasons.py < missctx.sh output`: a first draft of an area's reasons table, missed branches grouped by
  misswhy's guess, for docs/coverage-areas.md (check each row against the listing).
- **Light state walks (default, decided 2026-11-14):** in a state walk, an event square whose arrival and
  first-arrival search add nothing to the coverage gets no more tries (`"light"` in the closing line). 4:2's
  `-seal` run from no 4:2 coverage: 189 s and 90/86, against 656 s and 90/87 with every try (`cover ... full`).
  An area's closing run uses `full`. (A first attempt, skipping squares whose scripts read none of the state's
  flag bytes, skipped nothing: the step scripts read them on every step. Removed.)
- **Dice jobs:** a script's RANDOM with up to 8 outcomes (top 7 or less), in the area during a walk step, queues
  a job for each other value: the same step and answers, the die forced (`{"r": v, "at": offset}` in the job's
  path, `>> the die at ...` in the log). 6:25's ENTER lands at one of four cave entrances by RANDOM 3 (0xA472),
  and the walks had only ever explored behind one: the boars, the sow and five other set fights.
- **Seeds:** a run's dice come from one seed, logged at the start (`dice seed ... (seed=<hex> replays it)`); each
  reroll is drawn from it and logged (`dice reseeded`). `cover <area> <minutes> all seed=<hex>` replays the dice.
- `refcheck.sh [source]`: the reference-area check after any bot change (decided 2026-11-14): 3:11 and 5:5 from
  coverage without those areas; compare with `data/refcheck_base.txt` (must not drop).
- **Directed coverage (decided 2026-11-14):** `writers.py <game> data/writers.json` indexes every instruction of
  ECL1-8 that writes each byte (and the engine's own writes into the flag range); `chaintests.py <listing>
  <offset> [T|F|n] data/writers.json <area>` prints the tests on a shortest way from an entry point to that
  instruction and outcome, with each byte's writers; `CHAIN=1 ./missctx.sh <area>` does it under every missed
  branch. Variants stay hand-built and logged. `cover ... only=4,7,12` walks just those event numbers.
- Report `--dead=<block>`: each dead outcome with the rule that made it (`data/dead_all.txt`: 199 across the 29
  areas, 109 from the encounter reactions, 86 from value sets, 4 never-set bits).
- Engine: ADVANCE at an encounter menu only while ECL 0x49E6 is set (GAME.OVR 0x2EC1; set on entering an area,
  0x7792; the wilderness bands clear it). See research/pool-of-radiance-formats.md, "The encounter menu".
- Travel ignores exits to anything but areas 1-8 and the wilderness: the chat 12 sweep had recorded Kuto's Well's
  walled top row as exits to "16:1" (the script's north table, 0xAFC7/0xAFCA: file 16, block 1), and travel asked for
  ECL16.DAX ("cannot read", then a SCRIPT ERROR; in 57 of chat 17's 120 logs). The lab's `data/exits.txt` lost those
  10 lines. `covsum.sh` prints each run log's SCRIPT ERROR count.
- Engine: ECL 0x6DC8 is the number of monsters the fight put down (checked in the original, 4:10's skeleton army:
  research/pool-of-radiance-formats.md); ours had left it 0, so 4:10's, 2:20's and 8:16's kill counters never grew.
- Reference check (`refcheck.sh`, decided 2026-11-14), chat 18's walker against the code before it, from no
  coverage of those areas: 3:11 72/64 -> 85/79, 5:5 91/87 -> 91/88 (`data/refcheck_base.txt`).
- **Script landings:** the squares an area's own script moves the party to (constant writes to 0xC04B/0xC04C in
  either order, and table moves `COPY_MEM [table], [i], [C04B]` beside the 0xC04C one, each entry) become logged
  teleport arrivals, one per part of the area's map no way in reaches ("a square the area's script moves the party
  to"). 7:23: six parts placed (its vats room is still in none). Reference check: 3:11 87/83, 5:5 91/88.
- Directed plans (chat 18): `cover_1-18-report` (the plaza count at 9, a search on a plain square), `cover_1-18-plaza`
  (0x4A35 = 2, SNEAK), `cover_3-8-reports2`, `cover_2-9-paid` (walked fresh).
- `cover_3-8-reports.plan`: City Hall with every report byte (0x4AA6-0x4ABF) at 254, as each area's script writes it.
- `cover_7-17-war.plan`: the kobold war at its third stage (0x4A7E = 3, 0x4A7C = 1, 0x4A7D = 3).

### Side chat 2 additions (fights roll for roll against the original)

The original draws every random number from Turbo Pascal's generator (START.EXE 0AF8:118F):
seed = seed * 134775813 + 1 (a dword at DS:0x4428, DS = program segment + 0x0C7C), Random(n)
= (seed >> 16) mod n, a die Random(size) + 1 (GAME.OVR 0x2BCCD). With the same seed both
games draw the same numbers, so a fight can be compared draw by draw.

- `seed.py` reads or sets the seed in the running DOSBox (found through /proc/<pid>/mem by
  START.EXE's NextRand code; nothing on disk changes). The seed doesn't move while the game
  is idle, so timing doesn't matter.
- `trace.py install` patches the original's Random in memory (a stub in the PSP's unused
  FCB area); `trace.py run <secs>` prints every draw: count, roll_dice's caller (located in
  GAME.OVR or START.EXE by its code bytes), n and the result, and `POS` lines when a
  combatant's cell changes (DS:0x5F2B, 4 bytes each: x, y). Each entry is checked against
  the seed sequence; `LOST` marks draws the poller missed (use `CONF=por_slow.conf`, 1500
  cycles, for traces).
- `tp.py`: the generator in Python (`tp.steps(a, b)` counts the draws between two seeds).
- Ours: `tpseed=<hex>` in `--keys` turns on TpDice (the original's dice, lab only) from that
  seed; `tplog` prints every draw with what it was for; `quickall` puts the whole party on
  QUICK. With the dice on, the fight also logs `cell`, `field` and `pos` lines.
- `cmpfight.sh [seed] [orig|ours|both]` runs the Slums orc fight (save E, made by ours at
  2:20 14,1 W) in both from the same seed, everyone on QUICK, and `cmpdraws.py` prints the
  first draw where they differ, with the moves before it.
- `origfight.py` / `presser.py`: the original's fight on QUICK (with or without a log of
  the screen and the draws between lines).
- Found and fixed this way (side chat 2, 2026-11-13): battlefield clutter, monster icon
  colours, who acts next, the movement patterns (d8 rule and row), the range penalty's
  sign, hand-to-hand targets, the approach direction. The draw log matched to draw 861 of
  the orc fight, then (target lists nearest first; QUICK never bandages) all 965 draws.
- Setup for these: `por_slow.conf` is `por.conf` with `cpu_cycles = 1500`; `trace.py` reads
  `game/GAME.OVR` and `re/start.img` (START.EXE unpacked with `.lab/unexepack.py`), both in
  the lab folder only.
- Seed 0badf00d also matches all draws. Open (no dice involved): at 25,13 the original's
  Phineas, heading for the orc at 26,11 on pattern 1 with 25,12 taken, stepped west (24,13)
  then north, where ours steps north-west (24,12); the floor there is plain (DS:0x6716's grid
  read in the lab) and nobody stands on it. Its step check (GAME.OVR 0xB235) allows a step
  when the movement left is at least its cost (ours now does too).
- `cmpfight2.sh <save> <seed> "<keys before>" "<keys after>"` does the same for any fight a
  save leads to (ours writes the saves: `load=E,at=14;8;2,e,s,f,n` made F, one step north of
  the Slums' 14,9 S; the goblin patrol there: `cmpfight2.sh F 10000012 "" "up,c"`).
  `MAGIC=1` presses Alt-M after the first QUICK (ours: `--keys ...,magic`), so QUICK
  members cast. `cmpfight3.sh` adds a second seed (and starts the trace) after the first
  keys: the encounter from one seed, the fight from another. `--keys` knows `pgup`/`pgdn`
  (the original's diagonals, as orig.sh). `cmpmoves.py` lists each combatant's cells in both. `dsread.py <hex>
  [n]` prints bytes at DS:hex in the running original.
- Slums goblin patrol (save F, seed 10000012: "up,enter" then "up,c"): matches all draws
  to the last goblin's surrender, after two more fixes: the target list's tie order (the
  original's exchange sort at GAME.OVR 0x2FB80) and the morale check before the spell and
  item d7s.
- Found for the main chat (script, not combat): on the Slums' first step after loading F
  (the "YOU HAVE ENTERED..." text at 14,9) the original draws no patrol RANDOM (its script
  exits at 9B2A COMPARE 0,[6E82] / IF_NE); ours draws one. Ours never sets 0x6E82; in the
  original it reads 0 once the step is over, and script addresses aren't DS offsets there,
  so where it lives is still to find.

### Side chat 3 (2026-11-14): the method checked and tightened

- **No lost draws.** `trace.py`'s stub now waits, while a reader runs (flag PSP:00B8), until the
  reader has taken all but 7 entries of its ring (the reader's count, PSP:00BC), so nothing is
  overwritten and no entry is read half-written. The old ring lost 2-13% of the draws and could
  pair one draw's size with another's result (the "next to lost ones" rule in `cmpdraws.py` is
  only for old traces now). With no reader the stub never waits.
- **Full speed.** With nothing lost, `cmpfight2.sh`/`cmpfight3.sh` run the original at
  `por.conf`'s speed (`SLOW=1`: `por_slow.conf`) and ours with `--fast` and the lab key
  `fightend` (waits until the fight is over or asks CONTINUE BATTLE): a fight takes about a
  minute both sides, `regress.sh` (all 14) 40 s. `regress.sh record` plays every fight in the
  original again and saves its trace.
- **More than dice.** CONTINUE BATTLE is answered NO in both and reported (`ASKED CONTINUE
  BATTLE`); each side then records the party's HP and status (`partyrec.py` reads the
  original's records by name; ours' key `partyhp`; lines `PARTY <n> <hp> <status>`).
  `cmpdraws.py` also checks every figure's cells (the original's are polled, so they must be a
  subsequence of ours and end on the same cell) and ends with `VERDICT: MATCH` or what differs.
  `fightend` also prints each enemy's HP and status (`FOE`).
- Before this, "matches to the end" meant to the end of what ours drew: ours ended every fight
  as soon as the last enemy went down, while the original plays out the round and asks CONTINUE
  BATTLE (fixed); the goblins' items make the pile on a d10 (fixed). Now 12 of the 14 match to
  the treasure; in 2 orc fights Phineas's first step from 31,14 is sampled at 30,14 before 30,13
  in the original (ours steps diagonally; no dice differ): open, as the 25,13 case above.
- `presser.py`: `CONTINUE=y` answers YES the first time (the original then plays another
  round with nobody to fight and asks again).
- Save H (ours writes it): `load=E,memorize=1:15;15,e,s,h,n`, Bakshi with two Magic Missiles
  (G: `memorize=1:21;21`, two Sleeps; no QUICK caster has picked Sleep yet). The lab key
  `memorize=<member>:<id>;<id>...` sets a member's memorized spells (no ids: lists them).
  `regress.sh` replays six H fights too: the original's Magic Missile rolls (level / 2)d4 +
  level / 2 (GAME.OVR 0x28451; nothing at level 1), and its aim is the blow's target pick,
  nearest first, which becomes the caster's target.
- `origfight.py <secs> <log> noenter magic` logs each screen change of the original's fight
  with the running draw count (how the Magic Missile was found: "SPELL: MAGIC MISSILE", an
  aim, and no damage dice).


### Side chat 4 (2026-11-14): P16, the original's fight display on film

- `origvid.sh <save> <seed> <out.mkv> <secs> [magic]` films the original's fight from a lab save
  (as `cmpfight2.sh` reaches it: load, "up up", the seed, Enter, everyone on QUICK) at 30 frames a
  second, losslessly (ffv1, the 640x400 game area only; ffmpeg's x11grab on :98). `PRE="<dump.py
  steps>"` runs steps after loading (e.g. `e a s f f f f e e e` sets game speed 0).
- `oursvid.sh <out.mkv> <secs> "<keys>"` films ours the same way (Godot on :97, 1280x800) with
  `--keys`; `EXTRA=--anim` turns on the original's pacing, which `--keys` runs otherwise leave off.
- `vtl.py <video> [start] [end]` prints a timeline: each frame where the map, the right-hand panel
  or row 24 changed, with the panel's and row 24's text and how many map pixels changed.
- Found (orc fight H, seed 11111111, speeds 0, 4 and 9): a blow's message appears ~0.2 s after the
  blow and stays game speed x 0.2 s (0.8 s at 4, 1.8 s at 9, a flash at 0), then the panel is
  cleared; "GOES DOWN / AND IS DYING" is added under the blow's lines; "YOUR TEAMMATE IS DYING" is
  on row 24 for the same time. A dart volley (three a round) shows each hit and no misses; a miss
  only when all missed, once. A step takes ~0.15 s and the view scrolls with it; a missile is a
  small sprite moved one position a frame (4-7 frames); the actor's grey box shows ~0.3 s at the
  start of a computer turn. Nothing blinks while the menu, AIM or MANUAL waits. Steps and missiles
  don't change with the speed. DONE -> SPEED: "GAMESPEED (n) : SLOWER FASTER EXIT" (magenta prompt).
- Seen, not P16: the original's level-1 Magic Missile shows only "CASTS A SPELL", then the target,
  where ours adds "SPELL: MAGIC MISSILE" and "ORC IS UNAFFECTED"; Darkstar starts with 8 darts in
  the original's save H and 11 in ours.
- Step 3 (the view and the steps): `viewlog.py <secs>` logs the original's view while a fight runs:
  its top-left cell (bytes 2 and 3 of the battlefield record at DS:[0x6716]) and each figure's
  cell (DS:0x5F2B, 4 bytes: x, y, number, flag). GAME.OVR 0x30F0E keeps a cell in view: more
  than `margin` from the centre on an axis, the centre moves onto it on that axis (centre column
  3-46, row 3-21); 0x310D0 (far 03E0:0052) wraps it with a direction. DS:0x604B / 0x6093 are each
  figure's column and row against the view (0x307A2 fills them). Seen: the fight opens centred on
  the party's first member; a turn starts with the actor at margin 2; each step keeps the new
  cell in view (margin 3); a hand-to-hand blow brings its target within 2. A dart throw reframed
  the view between thrower and target (step 4, missiles). Ours under `--anim` prints `view x,y`
  on each change, for comparing with viewlog.py.

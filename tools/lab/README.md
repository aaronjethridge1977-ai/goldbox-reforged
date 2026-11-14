# Test lab

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
  members cast. `cmpmoves.py` lists each combatant's cells in both. `dsread.py <hex>
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

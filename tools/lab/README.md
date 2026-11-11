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

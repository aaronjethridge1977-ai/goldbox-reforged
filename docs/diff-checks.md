# Differential checks

One check = a lab save just before a story-critical event; both games play the same keys from it, then save;
`statediff.sh` compares the saves (script memory 0x4900-0x4AFF; each member's HP, max HP, experience, status,
coins and items). **MATCH** means identical after the ignore list below, where every entry has a reason.
Plan and decisions: ai-business-ideas `ideas/game-modernizer.md` (Methods 2 and 3, 2026-11-14).

## How to run one (main lane lab, chat 20)

- The start save: `mksave.py J <letter> <ecl> <block> <x> <y> <dir> [addr=val ...] [item<n>=<DAX>:<block>:<i>] [strong]`
  (from the shipped save J; never save over J, A or the other shipped files). Up once moves the party there.
- The original: `export DISPLAY=:99` first (WSL sets `:0`, and `pl.py` only defaults to `:99`), then
  `pl.py boot <letter>`, `pl.py do <keys> dump`. Save with ENCAMP, SAVE, F (the check's own slot).
- Ours: `ours.sh --save=<writable .cfg> --keys='load=<letter>,...,F2'` (keys replay only when that file exists;
  Godot's key names: `Up`, `Enter`, letters).
- Compare: `statediff.sh <our .cfg> F --ignore=4AFA,4AFB,4AFC,4AFD,4AFE,4AFF`.

**Ignore list**
- 0x4AFA-0x4AFF: the original writes them at save time from engine words (GAME.OVR 0x1FE9C / 0x1FEC2,
  research/pool-of-radiance-formats.md); no script of any data set reads or writes them.

## The first five events

All five reach their event in both games from lab saves made as below (chat 20, checked in DOSBox and ours).

| # | event | start save | keys to the event | check |
|---|---|---|---|---|
| 1 | 3:8 the clerk's reward (Podol Plaza cleared) | `mksave.py J G 3 8 4 5 E 4AE7=254` | Up, Up, Enter x2 (ours Enter x3) to the treasure; SHARE, EXIT; Enter x5 | **MATCH** (chat 20) |
| 2 | 6:19 the silver bottle | `mksave.py J B 6 25 10 10 N 4A87=1 49C3=10 49C4=10 item1=ITEM8:50:0` | Up, Up (the dragon's cave, 10,9), Enter, ENTER CAVE: Diogenes's thanks (0xA3C7) | reachable |
| 3 | 4:2 the chest and seal | `mksave.py J D 4 2 11 14 E 4A97=255 strong` | Up, Up: the ogre chief's fight (ogre, 18 hobgoblins, 4 more), then OPEN IT / TAKE IT UNOPENED | reachable; the original's QUICK fight took ~16 minutes and stalls on GUARDING: the check needs a fight played with fixed keys and the original's dice (`cmpfight2.sh`, side lane) |
| 4 | 2:9 paying past the gate | `mksave.py J C 2 9 7 12 N 4A77=96 4A64=0 4A78=0 4AB9=0` | Up, Up (7,11): the bugbear's 15 gold, YES; Enter (at 8,5) | **MATCH** (chat 20): 3 platinum paid, 2 by the first member and 1 by the second, in both |
| 5 | 5:7 the finale | `mksave.py J I 5 7 3 7 S strong` | Up, Up: the audience hall (event 8 at 3,8) | reachable; fights to Tyranthraxus follow (as 3) |

Kept in the lab: `data/diff_<area>_ours.cfg` and `data/diff_<area>_orig/` for each check run.

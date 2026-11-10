# Gold Box Reforged

A modern, open engine for classic SSI Gold Box CRPGs, built with AI in Godot 4. Bring your own game files.

**First target:** the DOS version of *Pool of Radiance*, fully playable, with quality-of-life additions — automap, quest tracker, quick save and mouse support — and everything else left as the original had it.

> This project contains **no game data**. You need your own copy of the game (for example, from GOG's *Forgotten Realms: The Archives – Collection Two*). Game names are trademarks of their owners; this is an unofficial fan project, free and not for sale.

## Status

**M1 done in practice; M3 started.** Pictures, maps, text, the first-person view and the event scripts decode; New Phlan is walkable with its events running (checked against the original). Shops and the starting party are in; monsters and combat are next.

| # | Milestone | |
|---|-----------|--|
| M0 | Setup | done |
| M1 | Data inventory (file formats documented) | in progress |
| M2 | Viewers (maps, art, fonts, monster and item tables) | |
| M3 | Exploration | |
| M4 | Characters | |
| M5 | Combat | |
| M6 | Full playthrough | |
| M7 | QoL features | |
| M8 | Release | |

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (Standard build).
2. Put your *Pool of Radiance* install folder next to the project, so that `Pool of Radiance/POOLRAD/GEO1.DAX` sits beside `project.godot`. That folder is git-ignored and is never committed.
   Or point the engine at it from anywhere: run with `-- --game-path="D:/path/to/POOLRAD"`.
3. Open `project.godot` in Godot and press **F5**. It opens a data browser on the title screen:
   - **Tab** cycles pictures → maps → walk.
   - Pictures: ←/→ step through every decoded picture, ↑/↓ jump between files.
   - Maps: ←/→ step through the 29 area maps; **Enter** walks the current map.
   - Walk: first-person view with the map beside it. ↑ forward, ↓ back, ←/→ turn. The area's event scripts run as you walk (text, menus 1–9 / Enter, portraits, Rolf's tour); N switches day/night.
   - Shops open from their events with the game's starting party (Thrender Grone, Bakshi, Rhiannon, Brother Sean, Darkstar, Phineas): ↑/↓ or mouse to pick, Enter/BUY, POOL to gather the party's money, ◀ ▶ to change buyer, Esc/EXIT.

## Layout

```
project.godot      Godot project (Compatibility renderer, so web export works)
scenes/            Godot scenes
scripts/           GDScript
scripts/formats/   Readers for the original data files (.DAX and friends)
docs/              Engine notes
```

## Built with AI

The code is written by Claude (Anthropic) under the direction of Aaron Ethridge, as a showcase of what AI-assisted development can do.

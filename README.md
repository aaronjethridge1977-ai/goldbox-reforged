# Gold Box Reforged

## Download

**Windows:** **[Download Gold Box Reforged 0.1.6 for Windows (zip)](https://github.com/aaronjethridge1977-ai/goldbox-reforged/releases/download/v0.1.6/goldbox-reforged-0.1.6-windows.zip)**
1. Unzip it (right-click, Extract All).
2. Run `GoldBoxReforged.exe` (the build is unsigned, so Windows may warn: More info, Run anyway).
3. Choose your *Pool of Radiance* folder (the one with `GEO1.DAX`).

**Linux:** **[Download Gold Box Reforged 0.1.6 for Linux (tar.gz)](https://github.com/aaronjethridge1977-ai/goldbox-reforged/releases/download/v0.1.6/goldbox-reforged-0.1.6-linux.tar.gz)** (64-bit x86)
1. Extract it (`tar xzf goldbox-reforged-0.1.6-linux.tar.gz`).
2. Run `./GoldBoxReforged.x86_64`.
3. Choose your *Pool of Radiance* folder (the one with `GEO1.DAX`; upper- or lower-case file names both work).

**Bring your own copy:** GOG, Steam or the original disks. [All releases](https://github.com/aaronjethridge1977-ai/goldbox-reforged/releases/latest)

Found a problem? [Report it](https://github.com/aaronjethridge1977-ai/goldbox-reforged/issues/new/choose) and say where your copy came from (see [Reporting a problem](#reporting-a-problem)).

## About

A modern, open engine for classic SSI Gold Box CRPGs, built with AI in Godot 4. Bring your own game files.

**First target:** the DOS version of *Pool of Radiance*, fully playable, with quality-of-life additions — automap, quest tracker, quick save and mouse support — and everything else left as the original had it.

> This project contains **no game data**. You need your own copy of the game (for example, from GOG's *Forgotten Realms: The Archives – Collection Two*). Game names are trademarks of their owners; this is an unofficial fan project, free and not for sale.

## Status

**M6 (full playthrough) in progress.** The whole game's scripts run (every area, every opcode: `tools/sweep.gd`), with exploration, characters, combat, spells, magic items and monster powers built from the original's own data and code and checked against the original in a test lab (DOSBox beside our engine). `docs/coverage.md` lists every spell, usable item, script opcode and monster power with its state. A playthrough bot (`scripts/dev/bot.gd`) plays a new party through the game headless and logs what goes wrong. At the end of chat 8 it clears the Slums (the clerk pays), Kuto's Well with its catacombs, Podol Plaza, Sokal Keep and Mendor's library; the area south of Podol Plaza and the gate to Valjevo are beyond its level 4 party, and the city's other areas (the graveyard, the buildings entered from outside the walls) still need routes through the wilderness band's menus.

| # | Milestone | |
|---|-----------|--|
| M0 | Setup | done |
| M1 | Data inventory (file formats documented) | done (open points in the formats notes) |
| M2 | Viewers (maps, art, fonts, monster and item tables) | done |
| M3 | Exploration | done |
| M4 | Characters | done |
| M5 | Combat | done (gaps listed in docs/coverage.md) |
| M6 | Full playthrough | in progress |
| M7 | QoL features | automap (mini-map and full map), quick save, area-of-effect preview, battle auto-end done; quest tracker and mouse still to do |
| M8 | Release | started: the game asks for your own game folder; Web and Windows export presets |

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (Standard build).
2. Put your *Pool of Radiance* install folder next to the project, so that `Pool of Radiance/POOLRAD/GEO1.DAX` sits beside `project.godot`. That folder is git-ignored and is never committed.
   Or point the engine at it from anywhere: run with `-- --game-path="D:/path/to/POOLRAD"`. If it finds no game files, the game asks for the folder and remembers it.
3. Open `project.godot` in Godot and press **F5**. It opens a data browser on the title screen:
   - **Tab** cycles pictures → maps → walk.
   - Pictures: ←/→ step through every decoded picture, ↑/↓ jump between files.
   - Maps: ←/→ step through the 29 area maps; **Enter** walks the current map.
   - Walk: first-person view with the map beside it. ↑ forward, ↓ back, ←/→ turn. The area's event scripts run as you walk (text, menus 1–9 / Enter, portraits, Rolf's tour); N switches day/night. M shows or hides the mini-map, F the full map of the area (SETTINGS on the start menu turns the automap off).
   - **F2** quick-saves in walk mode and **F3** loads; the engine starts straight in the last quick save (saved in `saves/`, git-ignored). Delete `saves/quicksave.cfg` to start fresh.
   - **V** shows the party's character sheets (AC, THAC0, damage, movement, items) next to the values the original saved; **Shift+M** browses every monster record. ←/→ to page, Esc to close.
   - **B** starts a test battle where you stand: the battlefield is built from the map around you, the party and a group of monsters from the area are placed, and the 7×7 combat window can be moved around (arrows, Tab to jump between combatants, PgUp/PgDn to change monster, +/− for distance, Esc to leave). **F** starts the fight: arrows and Home/PgUp/End/PgDn (or the keypad) step or attack, Space ends a turn, Q lets the computer fight for that character; monsters move and attack on their own, and the battle ends as soon as the last enemy falls. Test fights use a copy of the party.
   - Shops open from their events with the game's starting party (Thrender Grone, Bakshi, Rhiannon, Brother Sean, Darkstar, Phineas): ↑/↓ or mouse to pick, Enter/BUY, POOL to gather the party's money, ◀ ▶ to change buyer, Esc/EXIT.

## Reporting a problem

Open an issue: [New issue](https://github.com/aaronjethridge1977-ai/goldbox-reforged/issues/new/choose) and fill in the form. It asks where your copy of the game came from (GOG, Steam, the original disks or other) and its version if you know it, our build (the window title, e.g. "Gold Box Reforged 0.1.0"), your Windows version, what happened and the steps to get there, and what the original game does there if you know.

A save helps most: zip the save file `SAVGAMx.DAT` (x is the slot letter) together with the `SAVGAMx.GBR` beside it in your game folder, and attach the zip. **Never attach the game's own files** (.DAX, .OVR, .EXE or anything else from the game folder).

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

## License

Gold Box Reforged, Copyright (C) 2026 Aaron J Ethridge. Licensed under the GNU GPL v3; see LICENSE. Game data is not included: bring your own copy.

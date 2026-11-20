GOLD BOX REFORGED @VERSION@ (Linux, @DATE@)
@RULE@

GETTING STARTED
 1. Extract @TGZ@ (tar xzf @TGZ@) and open the extracted folder.
 2. Have your own copy of Pool of Radiance on this machine (GOG, Steam or the original disks:
    the folder holding GEO1.DAX).
 3. Run ./GoldBoxReforged.x86_64 (64-bit x86 Linux; OpenGL 3.3 or OpenGL ES 3.0).
 4. "Choose folder...": pick the folder holding GEO1.DAX (or the one with POOLRAD inside it).
 5. At the title press a key; LOAD SAVED GAME (your original saves work) or NEW GAME.
 The next start finds the folder by itself; F2 quick saves, and CONTINUE picks it up.

TESTERS WANTED
Please report what you find (and what looks different from the original) on the project's
GitHub page: https://github.com/aaronjethridge1977-ai/goldbox-reforged/issues
Say where your copy of the game came from (GOG, Steam or disks, and which version), your
Linux distribution, and the version in the window title.

WHAT IT IS
Gold Box Reforged is a new engine that plays the DOS Pool of Radiance (SSI, 1988) from the
game's own files, faithfully, with a few quality-of-life additions (automap, quick save,
quest log, mouse; each can be switched off in SETTINGS on the start menu). It contains no
game data: you need your own copy of Pool of Radiance: GOG, Steam or the original disks.

WHERE TO POINT IT
The first start asks for the game's folder: the folder holding GEO1.DAX (for an install,
the "Pool of Radiance" folder with POOLRAD inside also works). It is remembered in
~/.local/share/godot/app_userdata/Gold Box Reforged/settings.cfg (the quick save is there
too). You can also start it with -- --game-path="/path/to/POOLRAD", or put a
"Pool of Radiance" folder (with POOLRAD inside) beside the program.
Saves made with ENCAMP, SAVE are written into the game folder as the original does
(SAVGAMx.DAT and the CHRDATxn files, plus a SAVGAMx.GBR beside it): the original loads them
too. Point it at a copy if you want to keep your original saves untouched.

KEYS
As the original (arrow keys, menu letters, Enter, Esc). Added: F2 quick save, F3 quick
load, M automap, Q quest log, F11 or Alt+Enter full screen. Mouse: click a menu word to choose it; in a
list, click a line to light it and double-click to take it.

LICENCE AND SOURCE
Gold Box Reforged is free software under the GNU General Public License, version 3
(LICENSE.txt). It comes with ABSOLUTELY NO WARRANTY. The source code is at
https://github.com/aaronjethridge1977-ai/goldbox-reforged (built from commit @COMMIT@).
Built with Godot Engine 4.7.2 (MIT licence, godotengine.org). Pool of Radiance and
Forgotten Realms are trademarks of their owners; this project is not affiliated with them
and ships none of their files.

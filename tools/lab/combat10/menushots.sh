#!/bin/bash
# menushots.sh: ours' start menu on :96 (no save), SETTINGS then ABOUT -> FEATURES pages 1 and 2, grabbed to tmp/c10_*.png.
cd /home/aaron/gbr/combat_lab
G=$PWD/godot/Godot_v4.7.2-stable_linux.x86_64
pgrep -f "Xvfb :96" >/dev/null || (Xvfb :96 -screen 0 1280x800x24 >/dev/null 2>&1 &)
sleep 1
DISPLAY=:96 $G --path proj --rendering-driver opengl3 --resolution 640x400 --position 0,0 -- --game-path=$PWD/game > tmp/menushots.log 2>&1 &
GP=$!
export DISPLAY=:96 GRAB_SIZE=800x600
python3 keys.py wait=8 space wait=2 space wait=2 space wait=2 grab=tmp/c10_menu.png s wait=1 grab=tmp/c10_settings.png e wait=1 a wait=1 f wait=1 grab=tmp/c10_features1.png n wait=1 grab=tmp/c10_features2.png
kill -9 $GP 2>/dev/null

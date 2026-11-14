#!/bin/bash
# Our engine from the start menu on the virtual display, then keys.py steps (side chat 5, P21).
cd "$(dirname "$0")"
G=$PWD/godot/Godot_v4.7.2-stable_linux.x86_64
REPO=${REPO:-/home/claude/goldbox-reforged}
rm -f /tmp/.X98-lock /tmp/.X11-unix/X98
Xvfb :98 -screen 0 1280x800x24 >/dev/null 2>&1 &
XP=$!
for i in $(seq 50); do [ -e /tmp/.X11-unix/X98 ] && break; sleep 0.1; done
DISPLAY=:98 $G --path $REPO --rendering-driver opengl3 --resolution 1280x800 --position 0,0 -- --game-path=$PWD/game > godot_menu.log 2>&1 &
GP=$!
DISPLAY=:98 GRAB_SIZE=1280x800 timeout 150 python3 keys.py "$@"; echo "exit $?"
kill -9 $GP $XP 2>/dev/null
rm -f /tmp/.X98-lock /tmp/.X11-unix/X98

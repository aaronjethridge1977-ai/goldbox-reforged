#!/bin/bash
# Run our engine on the virtual display with a given quick save, then the key/grab steps.
cd "$(dirname "$0")"
G=$PWD/godot/Godot_v4.7.2-stable_linux.x86_64
SAVE=$1; shift
rm -f /tmp/.X98-lock /tmp/.X11-unix/X98
Xvfb :98 -screen 0 1280x800x24 >/dev/null 2>&1 &
XP=$!
for i in $(seq 50); do [ -e /tmp/.X11-unix/X98 ] && break; sleep 0.1; done
DISPLAY=:98 $G --path proj --rendering-driver opengl3 --resolution 1280x800 --position 0,0 -- --game-path=$PWD/game --save=$PWD/$SAVE > godot.log 2>&1 &
GP=$!
if [ "$1" = "--sh" ]; then shift; DISPLAY=:98 GRAB_SIZE=1280x800 timeout 150 bash "$@"; elif [ "$1" = "--py" ]; then shift; DISPLAY=:98 timeout 150 python3 "$@"; else DISPLAY=:98 GRAB_SIZE=1280x800 timeout 150 python3 keys.py "$@"; fi; echo "exit $?"
kill -9 $GP $XP 2>/dev/null
rm -f /tmp/.X98-lock /tmp/.X11-unix/X98

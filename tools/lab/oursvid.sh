#!/bin/bash
# oursvid.sh <out.mkv> <secs> "<keys>": our engine on a virtual display (1280x800), with --keys, recorded losslessly (30 fps).
cd "$(dirname "$0")"; G=$PWD/godot/Godot_v4.7.2-stable_linux.x86_64
rm -f /tmp/.X97-lock /tmp/.X11-unix/X97; Xvfb :97 -screen 0 1280x800x24 >/dev/null 2>&1 & XP=$!
for i in $(seq 50); do [ -e /tmp/.X11-unix/X97 ] && break; sleep 0.1; done
R=vid_$$; rm -rf $R; cp -r proj $R
DISPLAY=:97 timeout $(( $2 + 15 )) $G --path $R --rendering-driver opengl3 --resolution 1280x800 --position 0,0 -- --game-path=$PWD/game --save=$PWD/qs.cfg $EXTRA "--keys=$3" > /tmp/oursvid.log 2>&1 & GP=$!
sleep 2; DISPLAY=:97 ffmpeg -loglevel error -y -f x11grab -framerate 30 -video_size 1280x800 -i :97 -t $2 -c:v ffv1 $1
kill -9 $GP $XP 2>/dev/null; rm -rf $R; rm -f /tmp/.X97-lock /tmp/.X11-unix/X97

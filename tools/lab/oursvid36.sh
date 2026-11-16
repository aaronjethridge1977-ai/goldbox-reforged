#!/bin/bash
# oursvid36.sh <out.mkv> <secs> "<keys>": oursvid.sh on its own display (VD, default :98; :96 and :97 are Combat's and
# the Player's), recorded losslessly at 30 fps, 1280x800. Stops only what it started (by pid). Chat 36.
L=/home/aaron/gbr/lab; cd $L; G=$L/godot/Godot_v4.7.2-stable_linux.x86_64; VD=${VD:-:98}; N=${VD#:}
[ -e /tmp/.X11-unix/X$N ] && { echo "display $VD is in use"; exit 1; }
Xvfb $VD -screen 0 1280x800x24 -nocursor >/dev/null 2>&1 & XP=$!
for i in $(seq 50); do [ -e /tmp/.X11-unix/X$N ] && break; sleep 0.1; done
R=$L/vid_$$; cp -r $L/proj $R
DISPLAY=$VD timeout $(( $2 + 15 )) $G --path $R --rendering-driver opengl3 --resolution 1280x800 --position 0,0 -- --game-path=$L/game --save=${SAVE:-$L/qs.cfg} $EXTRA "--keys=$3" > /tmp/oursvid36.log 2>&1 & GP=$!
sleep ${LEAD:-2}; DISPLAY=$VD ffmpeg -loglevel error -y -f x11grab -draw_mouse 0 -framerate 30 -video_size 1280x800 -i $VD -t $2 -c:v ffv1 $1
kill $GP 2>/dev/null; sleep 1; kill -9 $GP 2>/dev/null; kill $XP 2>/dev/null; wait $XP 2>/dev/null
rm -rf $L/vid_$$

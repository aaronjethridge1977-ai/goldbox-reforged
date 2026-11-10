#!/bin/bash
# Start the virtual display and DOSBox, run the key/grab steps given as arguments, stop.
cd "$(dirname "$0")"
sed -i "s#/sessions/[^/\"]*/lab#$HOME/lab#g" por.conf
D=$PWD/dosbox-staging-linux-x86_64-0.83.0-7b400
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 800x600x24 >/dev/null 2>&1 &
XP=$!
for i in $(seq 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done
DISPLAY=:99 SDL_AUDIODRIVER=dummy $D/dosbox -conf por.conf > dosbox.log 2>&1 &
DP=$!
if [ "$1" = "--py" ]; then shift; DISPLAY=:99 timeout 160 python3 "$@"; else DISPLAY=:99 timeout 150 python3 keys.py "$@"; fi; echo "exit $?"
kill -9 $DP $XP 2>/dev/null
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99


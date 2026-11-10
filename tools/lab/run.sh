#!/bin/bash
# Start the virtual display and DOSBox, run the key/grab steps given as arguments, stop.
cd "$(dirname "$0")"
D=$PWD/dosbox-staging-linux-x86_64-0.83.0-7b400
Xvfb :99 -screen 0 800x600x24 >/dev/null 2>&1 &
XP=$!
sleep 1
DISPLAY=:99 SDL_AUDIODRIVER=dummy $D/dosbox -conf por.conf > dosbox.log 2>&1 &
DP=$!
DISPLAY=:99 timeout 150 python3 keys.py "$@"; echo "keys exit $?"
kill -9 $DP $XP 2>/dev/null

#!/bin/bash
# Run our engine headless on a private copy of ~/lab/proj (made by check_godot.sh), so a
# check can rebuild proj while a long run goes on. GTIME: seconds allowed (default 120).
cd "$(dirname "$0")"
R=run_$$; rm -rf $R; cp -r proj $R
timeout ${GTIME:-120} godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path $R -- --game-path=$PWD/game "$@" 2>&1
rm -rf $R

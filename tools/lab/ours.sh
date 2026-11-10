#!/bin/bash
# Run our engine headless on ~/lab/proj (made by check_godot.sh) with the given user args.
cd "$(dirname "$0")"
timeout 120 godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path proj -- --game-path=$PWD/game "$@" 2>&1

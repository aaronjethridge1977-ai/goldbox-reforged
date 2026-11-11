#!/bin/bash
cd /home/claude/lab && ./check_godot.sh /home/claude/goldbox-reforged | grep -v "All scripts OK"
timeout 600 godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path proj --script res://tools/sweep.gd -- --game-path=$PWD/game "$@" 2>&1 | grep -v "^\s*\[[0-9]\|GDScript backtrace\|   at: "

#!/bin/bash
# Differential check (M6 item 4): statediff.sh <our quick save .cfg> <original save letter> [--ignore=...]
# Compares our engine's saved state with the original's SAVGAM<letter>.DAT (and its CHRDAT
# files) saved at the same point from the same lab save. See tools/statediff.gd.
L=/home/claude/lab; S=/home/claude/goldbox-reforged
Q=$1; X=$2; shift 2
cd $L/proj 2>/dev/null || { echo "run check_godot.sh first (it builds proj)"; exit 1; }
mkdir -p tools && cp $S/tools/statediff.gd tools/
timeout 60 $L/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/statediff.gd -- --ours=$Q --orig=$L/game/SAVGAM$X.DAT "$@" 2>&1 | grep -v "^Godot\|^$\|^\s*at:\|^WARNING"

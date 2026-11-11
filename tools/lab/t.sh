#!/bin/bash
# Sync the repo into the lab project (Godot check) and run our engine with --keys.
cd /home/claude/lab
./check_godot.sh /home/claude/goldbox-reforged | grep -v "All scripts OK" 
./ours.sh --save=${SAVE:-$PWD/quicksave.cfg} "$@"

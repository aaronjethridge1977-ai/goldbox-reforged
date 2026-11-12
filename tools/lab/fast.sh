#!/bin/bash
# Quick sync of the repo's scripts into proj (no full check), then ours.sh with the args.
cd /home/claude/lab
rm -rf proj/scripts && cp -r /home/claude/goldbox-reforged/scripts proj/scripts
(cd proj && timeout 60 ../godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1)
./ours.sh --save=$PWD/quicksave.cfg "$@"

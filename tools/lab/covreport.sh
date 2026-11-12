#!/bin/bash
# Script coverage report (M6): covreport.sh [coverage file] [extra args, e.g. --missed=7:17]
L=/home/claude/lab; S=/home/claude/goldbox-reforged
C=${1:-$L/data/coverage.json}; shift
cd $L/proj 2>/dev/null || { echo "run check_godot.sh first (it builds proj)"; exit 1; }
rm -rf tools && mkdir tools && cp $S/tools/*.gd tools/ && rm -rf scripts && cp -r $S/scripts .
timeout 120 $L/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/coverage_report.gd -- --game-path=$L/game --coverage=$C "$@" 2>&1 | grep -v "^\s*at:\|^WARNING"

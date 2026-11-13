#!/bin/bash
# Run the PlayBot from a fresh copy of the project: BOT_ID=x bot.sh [plan] [extra args]
# Each BOT_ID gets its own project copy and its own user:// folder (quick saves, checkpoints).
# Script coverage (M6) goes to data/coverage.json, shared by every run (BOT_COVERAGE= to change);
# the choices not taken, tried in a copy of the VM at each menu, to data/branches.json.
L=/home/claude/lab; S=/home/claude/goldbox-reforged; ID=${BOT_ID:-a}
PLAN=${1:-playthrough.plan}; shift
P=$L/botproj_$ID
rm -rf $P && mkdir $P
cp -r $S/project.godot $S/icon.svg $S/scenes $S/scripts $P/
sed -i "s/^config\/name=\"\(.*\)\"/config\/name=\"\1 bot $ID\"/" $P/project.godot
mkdir -p $P/tools/plans && cp $S/tools/*.gd $P/tools/ 2>/dev/null; cp $S/tools/plans/* $P/tools/plans/
cd $P && timeout 60 $L/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
timeout ${BOT_TIMEOUT:-7200} $L/godot/Godot_v4.7.2-stable_linux.x86_64 --headless $GODOT_ARGS --path . -- --game-path=$L/game --play=res://tools/plans/$PLAN --exits=$L/data/exits.txt --coverage=${BOT_COVERAGE:-$L/data/coverage.json} --branches=${BOT_BRANCHES:-$L/data/branches.json} --fast --checkpoints=${BOT_CHECKPOINTS:-$L/data/checkpoints} "$@" 2>&1 | grep --line-buffered -v "^\s*\[[0-9]\|GDScript backtrace\|   at: "

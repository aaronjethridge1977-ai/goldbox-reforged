#!/bin/bash
# cover_all.sh <area> ...: coverage runs of the areas (as 5-3), two at a time (the workspace has
# 2 CPUs), each with runcover.sh; waits for runs already going (botproj_*) to end first.
cd /home/claude/lab
while pgrep -f "Godot_v4.7.2-stable_linux.x86_64 --headless --path . -- --game" > /dev/null; do sleep 30; done
printf "%s\n" "$@" | xargs -P 2 -I{} ./runcover.sh {}

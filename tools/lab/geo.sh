#!/bin/bash
# geo.sh <tool: mapdump|mapparts> <GEO file number> <block>: chat 19's map tools, run in proj/.
L=/home/claude/lab; cp $L/$1.gd $L/proj/_$1.gd; cd $L/proj
timeout 60 $L/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://_$1.gd -- $L/game/GEO$2.DAX $3 "${@:4}" 2>&1 | grep -v "^Godot\|^$\|^ERROR\|^   at:"

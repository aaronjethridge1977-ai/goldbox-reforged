#!/bin/bash
# Stop every bot run (the engines run with --path . inside botproj_*, so match by cwd).
for p in $(ps -eo pid=,args= | awk '/Godot_v4.7.2-stable_linux.x86_64/ {print $1}'); do
	case "$(readlink /proc/$p/cwd)" in */botproj_*) kill $p ;; esac
done
python3 killmine.py "/bin/bash ./bot.sh"
true

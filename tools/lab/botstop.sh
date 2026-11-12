#!/bin/bash
# Stop every bot run (the engines run with --path . inside botproj_*, so match by cwd).
for p in $(pgrep -f Godot_v4.7.2-stable_linux.x86_64); do
	case "$(readlink /proc/$p/cwd)" in */botproj_*) kill $p ;; esac
done
pkill -f "^/bin/bash ./bot.sh" 2>/dev/null
true

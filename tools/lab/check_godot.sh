#!/bin/bash
# Parse-check every GDScript file in a copy of the project with Godot for Linux (headless),
# then run the main scene for a couple of seconds and report errors.
# Usage: check_godot.sh /path/to/goldbox-reforged   (run in the lab folder)
set -u
LAB="$(cd "$(dirname "$0")" && pwd)"
G="$LAB/godot/Godot_v4.7.2-stable_linux.x86_64"
SRC="$1"
rm -rf "$LAB/proj" && mkdir "$LAB/proj"
cp -r "$SRC/project.godot" "$SRC/icon.svg" "$SRC/scenes" "$SRC/scripts" "$LAB/proj/"
[ -d "$SRC/content" ] && cp -r "$SRC/content" "$LAB/proj/"   # chat 39: content packs (areas.json, quests.json, features.json)
mkdir -p "$LAB/proj/tools" && cp "$SRC"/tools/*.gd "$LAB/proj/tools/" 2>/dev/null
cd "$LAB/proj"
timeout 60 "$G" --headless --path . --import >/dev/null 2>&1
status=0
for f in $(find scripts -name "*.gd" | sort); do
	out=$(timeout 30 "$G" --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|ERROR" | head -5)
	if [ -n "$out" ]; then echo "== $f"; echo "$out"; status=1; fi
done
run=$(timeout 40 "$G" --headless --path . --quit-after 120 2>&1 | grep -E "SCRIPT ERROR|ERROR" | head -10)
if [ -n "$run" ]; then echo "== running main scene"; echo "$run"; status=1; fi
[ $status = 0 ] && echo "All scripts OK."
exit $status

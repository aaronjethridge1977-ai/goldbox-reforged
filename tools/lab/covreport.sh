#!/bin/bash
# Script coverage report (M6): covreport.sh [coverage file] [extra args, e.g. --missed=7:17]
# With data/branches.json present (bot.sh writes it), a second report covers what was played
# plus the choices not taken (tried in a copy of the VM at each menu).
L=/home/claude/lab; S=/home/claude/goldbox-reforged
C=${1:-$L/data/coverage.json}; shift
cd $L/proj 2>/dev/null || { echo "run check_godot.sh first (it builds proj)"; exit 1; }
rm -rf tools && mkdir tools && cp $S/tools/*.gd tools/ && rm -rf scripts && cp -r $S/scripts .
G=$L/godot/Godot_v4.7.2-stable_linux.x86_64
echo "== played"
timeout 120 $G --headless --path . --script res://tools/coverage_report.gd -- --game-path=$L/game --coverage=$C "$@" 2>&1 | grep -v "^\s*at:\|^WARNING\|^Godot"
if [ -f $L/data/branches.json ]; then
	python3 - "$C" $L/data/branches.json $L/data/merged.json <<'PY'
import json, sys
out = {}
for f in sys.argv[1:3]:
    for k, b in json.load(open(f))["blocks"].items():
        e = out.setdefault(k, {"ins": set(), "br": set(), "extra": set()})
        for t in e:
            e[t] |= set(b.get(t, []))
json.dump({"blocks": {k: {t: sorted(v) for t, v in e.items()} for k, e in out.items()}}, open(sys.argv[3], "w"))
PY
	echo "== played + choices not taken"
	timeout 120 $G --headless --path . --script res://tools/coverage_report.gd -- --game-path=$L/game --coverage=$L/data/merged.json "$@" 2>&1 | grep -v "^\s*at:\|^WARNING\|^Godot"
fi

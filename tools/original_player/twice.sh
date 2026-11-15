#!/bin/bash
# Repeatability test: the same plan, save and seed twice; then the two runs' checkpoints compared.
# twice.sh <plan> <save> <seed> <run a> <run b>
cd "$(dirname "$0")"
L=${OP_LAB:-$HOME/gbr/player_lab}
for r in "$4" "$5"; do
	python3 orig.py stop
	python3 watchdog.py "$1" --save="$2" --seed="$3" --run="$r"
done
python3 orig.py stop
for cp in $(ls "$L/.lab/player/saves/$4"); do
	echo "== $cp: $(python3 cmpsaves.py "$L/.lab/player/saves/$4/$cp" "$L/.lab/player/saves/$5/$cp" | tail -1)"
done > "$L/logs/twice_$4_$5.txt"
cat "$L/logs/twice_$4_$5.txt"

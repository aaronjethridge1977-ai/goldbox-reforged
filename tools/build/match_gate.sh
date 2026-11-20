#!/bin/bash
# match_gate.sh <commit>: the release gate (Player 33's request, Lead's Methods 8 item (e); main chat 70): every
# recording of the original's full run that was identical in tools/original_player/match/baseline.txt is replayed
# in ours at <commit>, and `match.py gate --run` fails (exit 1) when one parts now.
#
#   tools/build/match_gate.sh origin/main          (about 5 minutes a recording: ~3 hours for 40)
#
# Called by windows_test.sh and linux_build.sh before the export (SKIP_MATCH_GATE=1 skips it, said in the
# build-info). It never writes in the Player's lab: the recordings (logs, traces, start and checkpoint saves),
# the game copy, qs.cfg and cmpdraws.py are copied from PLAYER_LAB (default ~/gbr/player_lab, read only) into a
# scratch lab in /tmp (OP_LAB), whose proj/ is the tracked files at <commit>, imported; match.py, segment.py and
# the baseline come from <commit> too. Out: the gate's last line ("MATCH GATE OK|FAILED: ...") and its exit code;
# the full output is kept in $MATCH_GATE_LOG (default /tmp/match_gate.<commit>.log).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
REF=${1:?usage: match_gate.sh <commit>}
PL=${PLAYER_LAB:-$HOME/gbr/player_lab}
GODOT=${GODOT:-$HOME/gbr/lab/godot/Godot_v4.7.2-stable_linux.x86_64}
COMMIT=$(git -C "$REPO" rev-parse --short "$REF^{commit}")
LOG=${MATCH_GATE_LOG:-/tmp/match_gate.$COMMIT.log}
fail() { echo "MATCH GATE FAILED: $*"; exit 1; }
[ -x "$GODOT" ] || fail "no Godot at $GODOT"
[ -d "$PL/.lab/player/saves" ] || fail "no Player lab at $PL"
T=$(mktemp -d /tmp/mgate.XXXXXX)
trap 'rm -rf "$T"' EXIT
L=$T/lab
mkdir -p "$T/src" "$L/logs" "$L/godot" "$L/proj/tools" "$L/root" "$L/.lab/player/saves/p2start"
git -C "$REPO" archive --format=tar "$COMMIT" | tar -x -C "$T/src"
# ours at <commit>, as check_godot.sh builds the lab's proj
cp -r "$T/src/project.godot" "$T/src/icon.svg" "$T/src/scenes" "$T/src/scripts" "$T/src/content" "$L/proj/"
cp "$T/src"/tools/*.gd "$L/proj/tools/"
(cd "$L/proj" && timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1) || true
ln -s "$GODOT" "$L/godot/Godot_v4.7.2-stable_linux.x86_64"
cp "$PL/qs.cfg" "$PL/cmpdraws.py" "$L/"
cp -r "$PL/root/POOLRAD" "$L/root/"
cp "$PL/.lab/player/saves/index.txt" "$L/.lab/player/saves/"
# every recording's files (match.py verify checks them all against the manifest at <commit>); the baseline's are replayed
M=$T/src/tools/original_player/match
# MATCH_GATE_ONLY="<run> ...": only those baseline recordings (a quick test of the gate itself, never for a release)
[ -n "${MATCH_GATE_ONLY:-}" ] && printf '%s\n' $MATCH_GATE_ONLY > "$M/baseline.txt"
while read -r seg run start cp rest; do
	case "$seg" in ''|\#*) continue;; esac
	for f in "$run.log" "$run.trace.txt"; do [ -f "$PL/logs/$f" ] && cp "$PL/logs/$f" "$L/logs/"; done
	[ -e "$PL/.lab/player/saves/p2start/$start" ] && cp -r "$PL/.lab/player/saves/p2start/$start" "$L/.lab/player/saves/p2start/"
	mkdir -p "$L/.lab/player/saves/$run"
	[ -e "$PL/.lab/player/saves/$run/$cp" ] && cp -r "$PL/.lab/player/saves/$run/$cp" "$L/.lab/player/saves/$run/"
done < "$M/recordings.txt"
for run in $(grep -v '^#' "$M/baseline.txt"); do
	awk -v r="$run" '$2 == r' "$M/recordings.txt" | grep -q . || fail "$run is in the baseline but not in recordings.txt"
done
echo "== match_gate.sh: $(grep -vc '^#' "$M/baseline.txt") baseline recordings on $COMMIT ($REF), log $LOG"
st=0
(cd "$T/src/tools/original_player" && OP_LAB=$L python3 match.py gate --run) > "$LOG" 2>&1 || st=$?
# Every replay must have run to its end: ours' F2 and statediff's count line (match.py reads an empty run, ours
# stopped at its first draw with no statediff, as identical).
for run in $(grep -v '^#' "$M/baseline.txt"); do
	o=$(ls "$L/logs/$run".segment_begin-*.txt 2>/dev/null | head -1)
	if [ -z "$o" ] || ! grep -q '^F2 ' "$o" || ! grep -qE '^[0-9]+ differences?$' "$o"; then
		echo "NOT RUN: $run (ours' replay didn't reach F2 and statediff)" >> "$LOG"
		st=1
	fi
done
[ $st = 0 ] || grep -q '^MATCH GATE FAILED' "$LOG" || echo "MATCH GATE FAILED: a replay didn't run (NOT RUN lines above)" >> "$LOG"
grep -E '^(PARTS NOW|NOT RUN|MATCH GATE)' "$LOG" || tail -3 "$LOG"
[ "${MATCH_GATE_KEEP:-}" = 1 ] && trap - EXIT && echo "scratch lab kept: $L"
exit $st

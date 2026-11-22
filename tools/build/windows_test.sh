#!/bin/bash
# windows_test.sh <commit> <version> [<out dir>]: a Windows test build from a clean copy of the tracked files at
# <commit> (main lane, chat 41, for test build 2; chat 37's 0.1.0-test1 steps made into one script).
#
#   tools/build/windows_test.sh origin/main 0.1.0-test2
#
# Out (default /mnt/d/ai_projects/goldbox-reforged/builds/windows-<version>, never git): GoldBoxReforged.exe,
# README.txt (tools/build/README-windows.txt: the 8 clean-machine steps), LICENSE.txt and the zip; beside the folder
# <name>.build-info.txt (commit, sha256s, the checks' results) and <name>.pck-list.txt (the export log's
# "Storing File:" lines). Refuses an existing out folder.
#
# Checks (any failing stops the build, "BUILD FAILED: ..."): the copy holds no game data (no .DAX/.OVR/.DAT/.SAV/
# .ITM/.SPC/.GBR/.PDF/.EXE/.COM, nothing over 2 MB, no Pool of Radiance folder); the version is stamped into the copy's
# project.godot (the window title) and the .exe's file version (0.1.0-test2 -> 0.1.0.2) and is found in the .exe;
# the .pck holds only .godot/, content/, scenes/, scripts/, the icon and project.binary; the smoke test: the same
# pack (--export-pack) run by the Linux release template (release templates refuse --main-pack, so the pack sits
# beside a copy named like it): (a) no game folder: starts with no script error; (b) a copy of the checks' game
# (SMOKE_GAME, default ~/gbr/checks/data/game, with check 22's start save G) loads save G, ENCAMP SAVE F and F2 quick
# save, as check 22's keys, the files written; (d) the test keys (N, O, B, F12, Tab, F4) change nothing after load G
# (lab_keys in main.gd: off in a release build); (c) on Xvfb (SMOKE_DISPLAY, default :95: never :96-:99, the lanes'
# displays) the window title reads "Gold Box Reforged <version>".
# (e) Jeremy's crash sessions (SMOKE_REPLAYS, default fireball_crash and holds_crash2 from 0.1.7-test2) play to their
# end on the release template (main chat 95; about 8 minutes).
#
# GODOT (default the lab's 4.7.2) runs the import and export; the export templates are in
# ~/.local/share/godot/export_templates/4.7.2.stable/ (chat 37). Scratch in /tmp, removed at the end.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
REF=${1:?usage: windows_test.sh <commit> <version> [<out dir>]}
V=${2:?usage: windows_test.sh <commit> <version> [<out dir>]}
OUT=${3:-/mnt/d/ai_projects/goldbox-reforged/builds/windows-$V}
GODOT=${GODOT:-$HOME/gbr/lab/godot/Godot_v4.7.2-stable_linux.x86_64}
TPL=$HOME/.local/share/godot/export_templates/4.7.2.stable
GAME=${SMOKE_GAME:-$HOME/gbr/checks/data/game}
START=${SMOKE_START:-$HOME/gbr/checks/data/22/start}
CFG=${SMOKE_CFG:-$HOME/gbr/checks/data/22/ours.cfg}
SD=${SMOKE_DISPLAY:-:95}
NAME=$(basename "$OUT"); ZIP=goldbox-reforged-$NAME   # test 1: goldbox-reforged-<folder>.zip
# A release version (no suffix, e.g. 0.1.0; chat 45): README-windows-release.txt (no clean-machine test), the zip
# goldbox-reforged-<version>-windows.zip.
RELEASE=""; case "$V" in *-*) ;; *) RELEASE=1; ZIP=goldbox-reforged-$V-windows;; esac
fail() { echo "BUILD FAILED: $*"; exit 1; }
[ -e "$OUT" ] && fail "$OUT exists (a build is never overwritten)"
[ -x "$GODOT" ] || fail "no Godot at $GODOT"
[ -f "$TPL/windows_release_x86_64.exe" ] && [ -f "$TPL/linux_release.x86_64" ] || fail "export templates missing in $TPL"
case "$SD" in :96|:97|:98|:99) fail "SMOKE_DISPLAY $SD is a lane's display";; esac
COMMIT=$(git -C "$REPO" rev-parse --short "$REF^{commit}") || fail "no commit $REF"
FV=$(echo "$V" | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+)(-[a-z]*([0-9]+))?$/\1.\3/p')
[ -n "$FV" ] || fail "version $V is not like 0.1.0-test2"
case "$FV" in *.) FV=${FV}0;; esac
T=$(mktemp -d /tmp/wbuild.XXXXXX)
XPID=""; GPID=""
cleanup() { [ -n "$GPID" ] && kill "$GPID" 2>/dev/null; [ -n "$XPID" ] && kill "$XPID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
echo "== windows_test.sh: $V from $COMMIT ($REF) -> $OUT"

# 0. The release gate (chat 70, Player 33's request): the Stage 1 match's baseline recordings replayed in ours at
# the commit (tools/build/match_gate.sh: ~5 min a recording); SKIP_MATCH_GATE=1 skips it (said in the build-info).
if [ "${SKIP_MATCH_GATE:-}" = 1 ]; then GATE="match gate: SKIPPED (SKIP_MATCH_GATE=1)"
else
	g=$("$HERE/match_gate.sh" "$COMMIT" | tail -1) || fail "release gate: $g"
	GATE="$g"
fi
echo "$GATE"

# 1. The clean copy: the tracked files at the commit, without tools/ and docs/.
mkdir -p "$T/src" "$T/out" "$T/smoke"
git -C "$REPO" archive --format=tar "$COMMIT" -- . ':(exclude)tools' ':(exclude)docs' | tar -x -C "$T/src"
bad=$(cd "$T/src" && find . -type f \( -iname '*.dax' -o -iname '*.ovr' -o -iname '*.dat' -o -iname '*.sav' \
	-o -iname '*.itm' -o -iname '*.spc' -o -iname '*.gbr' -o -iname '*.pdf' -o -iname '*.exe' -o -iname '*.com' \
	-o -size +2M -o -ipath '*pool of radiance*' -o -path '*/POOLRAD/*' \) | head -5)
[ -z "$bad" ] || fail "game data or a large file in the copy: $bad"
echo "copy: $(cd "$T/src" && find . -type f | wc -l) files, no game data"

# 2. The version. The repo's own project.godot names the last release (P84: a copy run from source shows it
# in the title): if the commit's differs from this build's, say so; bump it in the repo with the release.
had=$(sed -nE 's/^config\/version="(.*)"$/\1/p' "$T/src/project.godot")
[ "$had" = "$V" ] || echo "NOTE: the commit's project.godot says $had: bump config/version to $V in the repo with this release (P84)"
sed -i -E "s/^config\/version=.*/config\/version=\"$V\"/" "$T/src/project.godot"
sed -i -E "s/^application\/(file|product)_version=.*/application\/\1_version=\"$FV\"/" "$T/src/export_presets.cfg"
grep -q "^config/version=\"$V\"$" "$T/src/project.godot" || fail "version not stamped in project.godot"
[ "$(grep -c "_version=\"$FV\"" "$T/src/export_presets.cfg")" -ge 2 ] || fail "file version not stamped"
echo "version: $V (file version $FV)"

# 3. Import and export.
(cd "$T/src" && timeout 300 "$GODOT" --headless --path . --import > "$T/import.log" 2>&1) || true
timeout 600 "$GODOT" --headless --verbose --path "$T/src" --export-release "Windows Desktop" "$T/out/GoldBoxReforged.exe" \
	> "$T/export.log" 2>&1 || true
[ -s "$T/out/GoldBoxReforged.exe" ] || { tail -20 "$T/export.log"; fail "no .exe exported"; }
sed 's/\x1b\[[0-9;]*m//g' "$T/export.log" | grep -o 'Storing File: .*' | sed 's/ *$//' > "$T/pck-list.txt" || true
n=$(wc -l < "$T/pck-list.txt")
[ "$n" -gt 50 ] || fail "the export log lists $n files (expected the scripts and the scene)"
odd=$(grep -vE '^Storing File: res://(\.godot/|content/|scenes/|scripts/|icon\.svg$|icon\.svg\.import$|project\.binary$)' "$T/pck-list.txt" | head -5 || true)
[ -z "$odd" ] || fail "unexpected files in the .pck: $odd"
odd=$(grep -iE '\.(dax|ovr|dat|sav|itm|spc|gbr|pdf)$' "$T/pck-list.txt" | head -3 || true)
[ -z "$odd" ] || fail "game data in the .pck: $odd"
grep -aqF "$V" "$T/out/GoldBoxReforged.exe" || fail "version $V not found in the .exe"
echo "pck: $n files, only ours"

# 4. The smoke test on the same pack.
timeout 600 "$GODOT" --headless --path "$T/src" --export-pack "Windows Desktop" "$T/smoke/smoke_runner.pck" > "$T/pack.log" 2>&1 || true
[ -s "$T/smoke/smoke_runner.pck" ] || fail "no smoke pack exported"
cp "$TPL/linux_release.x86_64" "$T/smoke/smoke_runner" && chmod +x "$T/smoke/smoke_runner"
R="$T/smoke/smoke_runner"
errs() { grep -E 'SCRIPT ERROR|^ERROR|Parse Error' "$1" | head -3 || true; }
# (a) no game folder
XDG_DATA_HOME=$T/xa HOME=$T/ha timeout 60 "$R" --headless --quit-after 300 > "$T/a.log" 2>&1 || true
e=$(errs "$T/a.log"); [ -z "$e" ] || fail "smoke (a) no game: $e"
# (b) a game: load G, ENCAMP SAVE F, F2
mkdir -p "$T/game" && cp -r "$GAME"/. "$T/game/" && rm -f "$T"/game/CHRDAT[FG]* "$T"/game/SAVGAM[FG].* && cp "$START"/* "$T/game/"
cp "$CFG" "$T/qs.cfg"; touch -d '2000-01-01' "$T/qs.cfg"
XDG_DATA_HOME=$T/xb HOME=$T/hb timeout 180 "$R" --headless -- --game-path="$T/game" --save="$T/qs.cfg" \
	"--keys=load=G,wait,E,wait,S,wait,F,wait,wait,N,wait,E,wait,wait,F2" > "$T/b.log" 2>&1 || true
e=$(errs "$T/b.log"); [ -z "$e" ] || fail "smoke (b) play: $e"
grep -q '(saved game F)' "$T/b.log" || fail "smoke (b): ENCAMP SAVE F not seen ($(tail -2 "$T/b.log" | tr '\n' ' '))"
grep -q '^F2 ' "$T/b.log" || fail "smoke (b): F2 not seen"
[ "$T/qs.cfg" -nt "$T/game/SAVGAMG.DAT" ] || fail "smoke (b): the quick save was not written"
[ -s "$T/game/SAVGAMF.DAT" ] && [ -s "$T/game/CHRDATF1.SAV" ] || fail "smoke (b): save F's files missing"
# (d) the test keys do nothing in a release build (chat 50, Player 17's request): after load G, N (the clock), O, B (a
# test fight), F12, Tab and F4 leave the place, the clock, the screen and the party as they were.
XDG_DATA_HOME=$T/xd HOME=$T/hd timeout 180 "$R" --headless -- --game-path="$T/game" --save="$T/qs.cfg" \
	"--keys=load=G,wait,N,O,B,esc,F12,TAB,F4,wait" > "$T/d.log" 2>&1 || true
e=$(errs "$T/d.log"); [ -z "$e" ] || fail "smoke (d) test keys: $e"
k=$(grep -E '^(wait|N|O|B|esc|F12|TAB|F4) ' "$T/d.log" | cut -c8- | sort -u | wc -l)
[ "$(grep -cE '^(wait|N|O|B|esc|F12|TAB|F4) ' "$T/d.log")" = 9 ] && [ "$k" = 1 ] \
	|| fail "smoke (d): a test key changed the game ($(grep -E '^(N|B) ' "$T/d.log" | cut -c1-40 | tr '\n' ' '))"
# (c) the window title on Xvfb
Xvfb "$SD" -screen 0 1280x800x24 -nolisten tcp > "$T/xvfb.log" 2>&1 & XPID=$!
sleep 2
DISPLAY=$SD XDG_DATA_HOME=$T/xc HOME=$T/hc "$R" -- --game-path="$T/game" > "$T/c.log" 2>&1 & GPID=$!
title=""
for i in $(seq 1 20); do
	sleep 1
	# The window opens as the project's name; main.gd adds the version in _ready.
	title=$(DISPLAY=$SD python3 "$HERE/xtitle.py" 2>/dev/null | grep -F "Gold Box Reforged" | sort -r | head -1 || true)
	[ "$title" = "Gold Box Reforged $V" ] && break
done
kill "$GPID" 2>/dev/null || true; wait "$GPID" 2>/dev/null || true; GPID=""
kill "$XPID" 2>/dev/null || true; wait "$XPID" 2>/dev/null || true; XPID=""
[ "$title" = "Gold Box Reforged $V" ] || fail "smoke (c): window title \"$title\""
e=$(errs "$T/c.log"); [ -z "$e" ] || fail "smoke (c) window: $e"
# (e) Jeremy's crash sessions replayed on the release template (main chat 95, the Lead's yes to chat 94's
# suggestion): 0.1.7-test2 segfaulted on a set_pixelv outside an image, which debug builds skip with an error, so
# only the release template shows it. Each recording (SMOKE_REPLAYS, space-separated .gbrrec paths; "none" skips)
# is played windowed and paced on Xvfb $SD by tools/lab/treplay.sh, about 4 minutes each. A timed replay drifts
# under load (aims land elsewhere), so the test asks only that the session plays to its end: exit 0, "timed done"
# and the waits after it, no script error.
REPLAYS=${SMOKE_REPLAYS:-/mnt/d/ai_projects/goldbox-reforged/.lab/stuck/finale_guards/jeremy/2026-11-21-140652_fireball_crash.gbrrec /mnt/d/ai_projects/goldbox-reforged/.lab/stuck/finale_guards/jeremy/2026-11-21-143144_holds_crash2.gbrrec}
RP=""
if [ "$REPLAYS" = none ]; then RP="(e) replays SKIPPED (SMOKE_REPLAYS=none)"
else
	Xvfb "$SD" -screen 0 1280x800x24 -nolisten tcp > "$T/xvfb.log" 2>&1 & XPID=$!
	sleep 2
	for rec in $REPLAYS; do
		[ -f "$rec" ] || fail "smoke (e): no recording $rec (SMOKE_REPLAYS=none skips)"
		b=$(basename "$rec" .gbrrec)
		python3 "$REPO/tools/lab/replay_recording.py" "$rec" "$T/rr_$b" > "$T/rr_$b.log" 2>&1 || fail "smoke (e) $b: replay_recording.py"
		x=$(REL="$R" DISPLAY_N=$SD TMO=900 bash "$REPO/tools/lab/treplay.sh" "$T/src" "$T/rr_$b" "$rec" "$T/rw_$b" || true)
		x=${x%%$'\n'*}
		L="$T/rw_$b/ours.log"
		[ "$x" = "exit 0" ] || fail "smoke (e) $b: $x ($(grep -v '^wait ' "$L" | tail -2 | tr '\n' ' ' | cut -c1-200))"
		e=$(grep -E 'SCRIPT ERROR|Parse Error|crashed' "$L" | head -3 || true); [ -z "$e" ] || fail "smoke (e) $b: $e"
		grep -q '^timed done' "$L" || fail "smoke (e) $b: the session didn't play to its end"
		[ "$(sed -n '/^timed done/,$p' "$L" | grep -c '^wait ')" -ge 100 ] || fail "smoke (e) $b: the waits after the session missing"
		RP="$RP $b"
	done
	kill "$XPID" 2>/dev/null || true; wait "$XPID" 2>/dev/null || true; XPID=""
	RP="(e) replays OK:$RP"
fi
echo "smoke: (a) no game OK; (b) load G, ENCAMP SAVE F, F2 OK; (d) test keys off OK; (c) title \"$title\"; $RP"

# 5. README, licence, zip, info.
DATE=$(date +%F)
HEAD_LINE="GOLD BOX REFORGED $V (Windows test build, $DATE)"; RM=README-windows.txt
[ -n "$RELEASE" ] && HEAD_LINE="GOLD BOX REFORGED $V (Windows, $DATE)" && RM=README-windows-release.txt
RULE=$(printf '=%.0s' $(seq 1 ${#HEAD_LINE}))
sed -e "s/@VERSION@/$V/g" -e "s/@DATE@/$DATE/g" -e "s/@ZIP@/$ZIP.zip/g" -e "s/@COMMIT@/$COMMIT/g" -e "s/@RULE@/$RULE/" \
	"$HERE/$RM" | sed 's/$/\r/' > "$T/out/README.txt"
grep -q '@' "$T/out/README.txt" && grep -n '@[A-Z]*@' "$T/out/README.txt" && fail "README placeholders left"
sed 's/$/\r/' "$T/src/LICENSE" > "$T/out/LICENSE.txt"
python3 - "$T/out" "$ZIP" <<'E'
import os, sys, zipfile
d, name = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(os.path.join(d, name + ".zip"), "w", zipfile.ZIP_DEFLATED) as z:
	for f in ("GoldBoxReforged.exe", "README.txt", "LICENSE.txt"):
		z.write(os.path.join(d, f), name + "/" + f)
E
mkdir -p "$OUT"
cp "$T"/out/* "$OUT/"
cp "$T/pck-list.txt" "$OUT.pck-list.txt"
{
	echo "built from goldbox-reforged $COMMIT ($REF) as $V (file version $FV), $(date '+%F %T'); Godot $(cat "$TPL/version.txt") official templates"
	(cd "$OUT" && sha256sum GoldBoxReforged.exe "$ZIP.zip")
	echo "copy: no game data; pck: $n files, only ours"
	echo "smoke: (a) no game OK; (b) load G, ENCAMP SAVE F, F2 OK; (d) test keys off OK; (c) title \"$title\"; $RP"
	echo "$GATE"
} > "$OUT.build-info.txt"
cat "$OUT.build-info.txt"
echo "BUILD OK: $OUT"

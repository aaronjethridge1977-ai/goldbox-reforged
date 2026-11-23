#!/bin/bash
# linux_build.sh <commit> <version> [<out dir>]: a Linux build from a clean copy of the tracked files at <commit>
# (main lane, chat 66; windows_test.sh's steps for Linux, Methods 7's Linux build).
#
#   tools/build/linux_build.sh 6d34e55 0.1.5
#
# Out (default /mnt/d/ai_projects/goldbox-reforged/builds/release-<version>-linux, never git): GoldBoxReforged.x86_64
# (the pack embedded), README.txt (tools/build/README-linux-release.txt), LICENSE.txt and
# goldbox-reforged-<version>-linux.tar.gz (a tarball keeps the program's executable bit); beside the folder
# <name>.build-info.txt (commit, sha256s, the checks' results) and <name>.pck-list.txt. Refuses an existing out folder.
#
# A commit whose export_presets.cfg has no "Linux" preset (anything before chat 66, e.g. 0.1.5's 6d34e55) gets this
# checkout's Linux preset added to the copy, so a Linux build pairs with the Windows build of the same commit.
#
# Checks (any failing stops the build, "BUILD FAILED: ..."): the copy holds no game data (as windows_test.sh); the
# version is stamped into the copy's project.godot (the window title) and found in the program; the .pck holds only
# .godot/, content/, scenes/, scripts/, the icon and project.binary; the smoke test runs **the exported program
# itself**: (a) no game folder: starts with no script error; (b) a copy of the checks' game (SMOKE_GAME, with check
# 22's start save G) loads G, ENCAMP SAVE F and F2, the files written; (d) the test keys change nothing (lab keys
# off in a release); (c) on Xvfb (SMOKE_DISPLAY, default :95: never :96-:99) the window title reads
# "Gold Box Reforged <version>"; (e) the tarball unpacks to an executable program.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
REF=${1:?usage: linux_build.sh <commit> <version> [<out dir>]}
V=${2:?usage: linux_build.sh <commit> <version> [<out dir>]}
OUT=${3:-/mnt/d/ai_projects/goldbox-reforged/builds/release-$V-linux}
GODOT=${GODOT:-$HOME/gbr/lab/godot/Godot_v4.7.2-stable_linux.x86_64}
TPL=$HOME/.local/share/godot/export_templates/4.7.2.stable
GAME=${SMOKE_GAME:-$HOME/gbr/checks/data/game}
START=${SMOKE_START:-$HOME/gbr/checks/data/22/start}
CFG=${SMOKE_CFG:-$HOME/gbr/checks/data/22/ours.cfg}
SD=${SMOKE_DISPLAY:-:95}
TGZ=goldbox-reforged-$V-linux
BIN=GoldBoxReforged.x86_64
fail() { echo "BUILD FAILED: $*"; exit 1; }
[ -e "$OUT" ] && fail "$OUT exists (a build is never overwritten)"
[ -x "$GODOT" ] || fail "no Godot at $GODOT"
[ -f "$TPL/linux_release.x86_64" ] || fail "export template linux_release.x86_64 missing in $TPL"
case "$SD" in :96|:97|:98|:99) fail "SMOKE_DISPLAY $SD is a lane's display";; esac
echo "$V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+[0-9]*)?$' || fail "version $V is not like 0.1.5"
COMMIT=$(git -C "$REPO" rev-parse --short "$REF^{commit}") || fail "no commit $REF"
T=$(mktemp -d /tmp/lbuild.XXXXXX)
XPID=""; GPID=""
cleanup() { [ -n "$GPID" ] && kill "$GPID" 2>/dev/null; [ -n "$XPID" ] && kill "$XPID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
echo "== linux_build.sh: $V from $COMMIT ($REF) -> $OUT"

# 0. The release gate (chat 70, Player 33's request): the Stage 1 match's baseline recordings replayed in ours at
# the commit (tools/build/match_gate.sh: ~5 min a recording); SKIP_MATCH_GATE=1 skips it (said in the build-info).
if [ "${SKIP_MATCH_GATE:-}" = 1 ]; then GATE="match gate: SKIPPED (SKIP_MATCH_GATE=1)"
else
	g=$("$HERE/match_gate.sh" "$COMMIT" | tail -1) || fail "release gate: $g"
	GATE="$g"
fi
echo "$GATE"

# 1. The clean copy: the tracked files at the commit, without tools/ and docs/.
mkdir -p "$T/src" "$T/out" "$T/unpack"
git -C "$REPO" archive --format=tar "$COMMIT" -- . ':(exclude)tools' ':(exclude)docs' | tar -x -C "$T/src"
bad=$(cd "$T/src" && find . -type f \( -iname '*.dax' -o -iname '*.ovr' -o -iname '*.dat' -o -iname '*.sav' \
	-o -iname '*.itm' -o -iname '*.spc' -o -iname '*.gbr' -o -iname '*.pdf' -o -iname '*.exe' -o -iname '*.com' \
	-o -size +2M -o -ipath '*pool of radiance*' -o -path '*/POOLRAD/*' \) | head -5)
[ -z "$bad" ] || fail "game data or a large file in the copy: $bad"
echo "copy: $(cd "$T/src" && find . -type f | wc -l) files, no game data"

# 2. The Linux preset (added from this checkout when the commit has none) and the version.
if ! grep -q '^platform="Linux"' "$T/src/export_presets.cfg"; then
	python3 - "$REPO/export_presets.cfg" "$T/src/export_presets.cfg" <<'E' || fail "no Linux preset to add"
import re, sys
src, dst = open(sys.argv[1]).read(), open(sys.argv[2]).read()
blocks = re.split(r"(?m)^(?=\[preset\.\d+\]$)", src)
lin = [b for b in blocks if b.startswith("[preset.") and '\nplatform="Linux"' in b]
if not lin:
	sys.exit(1)
n = max(int(x) for x in re.findall(r"(?m)^\[preset\.(\d+)\]$", dst)) + 1
blk = re.sub(r"(?m)^\[preset\.\d+(\]|\.options\])$", lambda m: "[preset.%d%s" % (n, m.group(1)), lin[0])
open(sys.argv[2], "w").write(dst.rstrip("\n") + "\n\n" + blk.rstrip("\n") + "\n")
E
	echo "preset: the commit has no Linux preset; this checkout's added"
fi
had=$(sed -nE 's/^config\/version="(.*)"$/\1/p' "$T/src/project.godot")
[ "$had" = "$V" ] || echo "NOTE: the commit's project.godot says $had: bump config/version to $V in the repo with this release (P84)"
sed -i -E "s/^config\/version=.*/config\/version=\"$V\"/" "$T/src/project.godot"
# The commit, for RECORD MY GAME's header (chat 109: a recording names the build it can replay on; editor runs
# read .git instead). After config/version, in [application].
sed -i -E "/^config\/version=/a config\/build_commit=\"$COMMIT\"" "$T/src/project.godot"
grep -q "^config/version=\"$V\"$" "$T/src/project.godot" || fail "version not stamped in project.godot"
echo "version: $V"

# 3. Import and export.
(cd "$T/src" && timeout 300 "$GODOT" --headless --path . --import > "$T/import.log" 2>&1) || true
timeout 600 "$GODOT" --headless --verbose --path "$T/src" --export-release "Linux" "$T/out/$BIN" > "$T/export.log" 2>&1 || true
[ -s "$T/out/$BIN" ] || { tail -20 "$T/export.log"; fail "no program exported"; }
chmod 755 "$T/out/$BIN"
sed 's/\x1b\[[0-9;]*m//g' "$T/export.log" | grep -o 'Storing File: .*' | sed 's/ *$//' > "$T/pck-list.txt" || true
n=$(wc -l < "$T/pck-list.txt")
[ "$n" -gt 50 ] || fail "the export log lists $n files (expected the scripts and the scene)"
odd=$(grep -vE '^Storing File: res://(\.godot/|content/|scenes/|scripts/|icon\.svg$|icon\.svg\.import$|project\.binary$)' "$T/pck-list.txt" | head -5 || true)
[ -z "$odd" ] || fail "unexpected files in the .pck: $odd"
odd=$(grep -iE '\.(dax|ovr|dat|sav|itm|spc|gbr|pdf)$' "$T/pck-list.txt" | head -3 || true)
[ -z "$odd" ] || fail "game data in the .pck: $odd"
grep -aqF "$V" "$T/out/$BIN" || fail "version $V not found in the program"
echo "pck: $n files, only ours"

# 4. README, licence, tarball (before the smoke test, so (e) tests the tarball itself).
DATE=$(date +%F)
HEAD_LINE="GOLD BOX REFORGED $V (Linux, $DATE)"
RULE=$(printf '=%.0s' $(seq 1 ${#HEAD_LINE}))
sed -e "s/@VERSION@/$V/g" -e "s/@DATE@/$DATE/g" -e "s/@TGZ@/$TGZ.tar.gz/g" -e "s/@COMMIT@/$COMMIT/g" -e "s/@RULE@/$RULE/" \
	"$HERE/README-linux-release.txt" > "$T/out/README.txt"
grep -n '@[A-Z]*@' "$T/out/README.txt" && fail "README placeholders left"
cp "$T/src/LICENSE" "$T/out/LICENSE.txt"
mkdir -p "$T/pkg/$TGZ" && cp -p "$T/out/$BIN" "$T/out/README.txt" "$T/out/LICENSE.txt" "$T/pkg/$TGZ/"
tar -C "$T/pkg" --owner=0 --group=0 -czf "$T/out/$TGZ.tar.gz" "$TGZ"

# 5. The smoke test on the program from the tarball.
tar -C "$T/unpack" -xzf "$T/out/$TGZ.tar.gz"
R="$T/unpack/$TGZ/$BIN"
[ -x "$R" ] || fail "smoke (e): the program in the tarball is not executable"
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
# (d) the test keys do nothing in a release build
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
	title=$(DISPLAY=$SD python3 "$HERE/xtitle.py" 2>/dev/null | grep -F "Gold Box Reforged" | sort -r | head -1 || true)
	[ "$title" = "Gold Box Reforged $V" ] && break
done
kill "$GPID" 2>/dev/null || true; wait "$GPID" 2>/dev/null || true; GPID=""
kill "$XPID" 2>/dev/null || true; wait "$XPID" 2>/dev/null || true; XPID=""
[ "$title" = "Gold Box Reforged $V" ] || fail "smoke (c): window title \"$title\""
e=$(errs "$T/c.log"); [ -z "$e" ] || fail "smoke (c) window: $e"
SMOKE="smoke (the tarball's program): (e) unpacks executable; (a) no game OK; (b) load G, ENCAMP SAVE F, F2 OK; (d) test keys off OK; (c) title \"$title\""
echo "$SMOKE"

# 6. Out and info.
mkdir -p "$OUT"
cp -p "$T"/out/* "$OUT/"
cp "$T/pck-list.txt" "$OUT.pck-list.txt"
{
	echo "built from goldbox-reforged $COMMIT ($REF) as $V (Linux x86_64), $(date '+%F %T'); Godot $(cat "$TPL/version.txt") official templates"
	(cd "$OUT" && sha256sum "$BIN" "$TGZ.tar.gz")
	echo "copy: no game data; pck: $n files, only ours"
	echo "$SMOKE"
	echo "$GATE"
} > "$OUT.build-info.txt"
cat "$OUT.build-info.txt"
echo "BUILD OK: $OUT"

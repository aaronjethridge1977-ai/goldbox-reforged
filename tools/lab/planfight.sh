#!/bin/bash
# planfight.sh <checkout> <start save dir> <prelude keys> <seeds> <plan file>... (main chat 96, Guide 12's step 3: try
# plans in ours first). Each plan is played in ours, headless, from the start save (its files copied in as they are:
# name them as slot G, e.g. with ~/gbr/lab/data/c50/slot.py), once per seed: load=G, tpseed=<seed> (the original's
# dice; ORIGINAL'S BUGS on with them), planprep=<plan> (each member's QUICK flag as round 1 wants), the prelude keys (comma-separated, ours' --keys words: the walk into the
# fight), then planfight=<plan> (scripts/dev/plan_fight.gd: the plan's format at its top). Every QoL switch that
# changes play is off, as in the differential checks. <seeds>: "11111111 22222222" (hex) or "n:<count>[:<first>]"
# (count seeds from first, default 50010001, step 1). Prints a line per run and a table per plan: wins, losses,
# mean rounds, mean HP lost (over all runs and over the wins), the members down or dead.
# Env: PF_JOBS (runs at once, default 4), PF_GAME (the game folder, default ~/gbr/checks/data/game),
# PF_KEEP=1 keeps the work folder (its runs' logs: <work>/<plan>_<seed>.log), PF_TMO (seconds a run, default 900),
# PF_CFG (ours' start cfg, as a check's ours.cfg; default ~/gbr/checks/data/38/ours.cfg: without one ours waits at
# its first screen and load=G never comes).
set -u
SRC=$(cd "${1:?usage: planfight.sh <checkout> <start dir> <prelude keys> <seeds> <plan>...}" && pwd) || exit 2
START=$(cd "$2" && pwd) || exit 2
PRE=$3; SEEDS=$4; shift 4
[ $# -ge 1 ] || { echo "no plan given" >&2; exit 2; }
G=${PF_GODOT:-/home/aaron/gbr/checks/bin/godot}
GAME=${PF_GAME:-/home/aaron/gbr/checks/data/game}
JOBS=${PF_JOBS:-4}; TMO=${PF_TMO:-900}; CFG=${PF_CFG:-/home/aaron/gbr/checks/data/38/ours.cfg}
T=$(mktemp -d /tmp/planfight.XXXXXX)
[ "${PF_KEEP:-0}" = 1 ] && echo "work folder: $T" || trap 'rm -rf "$T"' EXIT
if [[ $SEEDS == n:* ]]; then
	IFS=: read -r _ cnt first <<< "$SEEDS"; first=${first:-50010001}
	SEEDS=$(python3 -c "print(' '.join('%08x' % (int('$first', 16) + i) for i in range($cnt)))")
fi
echo "planfight: $SRC ($(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)$(git -C "$SRC" diff --quiet 2>/dev/null || echo ' + local changes')), start $START, seeds: $(echo $SEEDS | wc -w)"
mkdir -p "$T/proj/tools" "$T/plans"
cp -r "$SRC/project.godot" "$SRC/icon.svg" "$SRC/scenes" "$SRC/scripts" "$T/proj/"
[ -d "$SRC/content" ] && cp -r "$SRC/content" "$T/proj/"
cp "$SRC"/tools/*.gd "$T/proj/tools/" 2>/dev/null
(cd "$T/proj" && XDG_DATA_HOME=$T/xdg timeout 300 "$G" --headless --path . --import >/dev/null 2>&1)
names=()
for p in "$@"; do
	b=$(basename "$p" .plan); cp "$p" "$T/plans/$b.plan"; names+=("$b")
done

one() {   # one <plan name> <seed>
	local b=$1 s=$2 W=$T/w_$1_$2
	mkdir -p "$W/xdg/godot/app_userdata/Gold Box Reforged"
	{ printf '[qol]\n\n'; printf '%s=false\n' rememorize fix magic_menu aim_skips_party start_memorized quick_bandages \
		smart_quick smart_monsters; } > "$W/xdg/godot/app_userdata/Gold Box Reforged/settings.cfg"
	cp -rL "$GAME" "$W/game"
	rm -f "$W"/game/CHRDATG* "$W"/game/SAVGAMG.*
	cp "$START"/* "$W/game/"
	cp "$CFG" "$W/ours.cfg"
	local keys="load=G,wait,tpseed=$s,wait,planprep=$T/plans/$b.plan"
	[ -n "$PRE" ] && keys="$keys,$PRE"
	keys="$keys,planfight=$T/plans/$b.plan,wait,wait"
	XDG_DATA_HOME=$W/xdg timeout "$TMO" "$G" --headless --path "$T/proj" -- --game-path="$W/game" \
		--save="$W/ours.cfg" --fast --seed=1 "--keys=$keys" > "$T/${b}_$s.log" 2>&1
	local r; r=$(grep -m1 "^PLANFIGHT RESULT" "$T/${b}_$s.log" || echo "PLANFIGHT RESULT outcome=none (timed out or no fight: see the log)")
	echo "$b $s ${r#PLANFIGHT RESULT }" > "$T/${b}_$s.res"
	rm -rf "$W"
	cat "$T/${b}_$s.res"
}
export -f one; export T G GAME START PRE TMO CFG

for b in "${names[@]}"; do for s in $SEEDS; do echo "$b $s"; done; done | xargs -P "$JOBS" -n 2 bash -c 'one "$0" "$1"'

echo
python3 - "$T" "${names[@]}" <<'EOF'
import glob, os, re, sys
t, names = sys.argv[1], sys.argv[2:]
print("%-24s %5s %5s %6s %7s %7s  %s" % ("plan", "won", "runs", "rounds", "HP lost", "(wins)", "down / dead (times)"))
for b in names:
	rows = []
	for f in sorted(glob.glob(os.path.join(t, b + "_*.res"))):
		l = open(f).read().strip()
		d = dict(re.findall(r"(\w+)=(\S*)", l))
		rows.append(d)
	if not rows:
		continue
	won = [r for r in rows if r.get("outcome") == "won"]
	mean = lambda xs: sum(xs) / len(xs) if xs else 0
	rounds = mean([int(r.get("rounds", 0)) for r in rows])
	lost = mean([int(r.get("lost", 0)) for r in rows if "lost" in r])
	lostw = mean([int(r.get("lost", 0)) for r in won])
	who = {}
	for r in rows:
		for k in ("down", "dead"):
			for n in filter(None, r.get(k, "").split(",")):
				who[n + " " + k] = who.get(n + " " + k, 0) + 1
	print("%-24s %5d %5d %6.1f %7.1f %7.1f  %s" % (b, len(won), len(rows), rounds, lost, lostw,
		", ".join("%s %d" % (k, v) for k, v in sorted(who.items(), key=lambda kv: -kv[1]))))
EOF

#!/bin/bash
# mkcheck35.sh <n> <area> <orig keys (pl.py do steps) or -> <ours keys>: chat 35's new differential checks.
# Uses the jump save in game/SAVGAMG.DAT + CHRDATG* (made by mksave.py) as the start for both games.
# The original: boot G, the keys, ENCAMP SAVE F, then copies the end save; ours: the keys from load=G, F2.
# Writes data/c35/chk<n>/{area,keys,ours.cfg,start/,orig/} and prints statediff. (No deletions: files overwritten.)
set -u
L=$HOME/gbr/lab; cd $L; export DISPLAY=:99
n=$1; a=$2; ok="$3"; yk="$4"; C=data/c35/chk$n
mkdir -p $C/start $C/orig
cp game/SAVGAMG.DAT game/CHRDATG* $C/start/
echo -n "$a" > $C/area; echo -n "$yk" > $C/keys
cp ~/gbr/checks/data/9/ours.cfg $C/ours.cfg
if [ "$ok" != "-" ]; then
	t0=$(date +%s)
	python3 pl.py boot G > $C/orig.log 2>&1
	[ -n "${SEED:-}" ] && python3 seed.py set $SEED >> $C/orig.log 2>&1
	python3 pl.py do $ok dump E wait=1 S wait=1 F wait=3 dump N wait=1 >> $C/orig.log 2>&1
	[ $(stat -c %Y game/SAVGAMF.DAT) -ge $((t0 - 5)) ] || echo "!! the original's save F was not written"
	cp game/SAVGAMF.DAT game/CHRDATF* $C/orig/
fi
cp $C/ours.cfg /tmp/chk$n.cfg
cp $C/start/* game/
GTIME=600 ./ours.sh --save=/tmp/chk$n.cfg --fast --seed=1 "--keys=$yk" > $C/ours.log 2>&1
cp $C/orig/* game/ 2>/dev/null
./statediff.sh /tmp/chk$n.cfg F --ignore=4AFA,4AFB,4AFC,4AFD,4AFE,4AFF 2>&1 | tail -8
cp /tmp/chk$n.cfg $C/ours_end.cfg

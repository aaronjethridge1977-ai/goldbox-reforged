#!/bin/bash
# fullrun37.sh <out.mkv>: showcase item 7 again (chat 37): c34d's 37 checkpoints in the plan's order, 4 s each, the
# party turning once around, recorded with oursvid36.sh (own display, no pointer) and **the automap off** (a scratch
# HOME whose user settings say [qol] automap=false: the lab's own settings stay as they are). Joined losslessly.
L=/home/aaron/gbr/lab; cd $L; OUT=$1; W=/tmp/fullrun37; mkdir -p $W/home/.local/share/godot/app_userdata/"Gold Box Reforged"
printf '[qol]\n\nautomap=false\n' > $W/home/.local/share/godot/app_userdata/"Gold Box Reforged"/settings.cfg
: > $W/list.txt; n=0
for cp in $(grep -o "^checkpoint [a-z0-9_]*" ~/gbr/goldbox-reforged/tools/plans/playthrough.plan | cut -d' ' -f2); do
	n=$((n + 1)); f=$(printf "%s/%02d_%s.mkv" $W $n $cp)
	cp $L/data/c34/cp_c34d/bot_$cp.cfg $W/qs.cfg
	HOME=$W/home SAVE=$W/qs.cfg LEAD=3 ./oursvid36.sh $f 4 "wait,wait,Right,wait,wait,Right,wait,wait,Right,wait,wait,Right,wait,wait,wait,wait" > /dev/null 2>&1
	[ -s $f ] && echo "file '$f'" >> $W/list.txt || echo "missing $cp"
done
ffmpeg -loglevel error -y -f concat -safe 0 -i $W/list.txt -c copy $OUT && echo "done $n clips -> $OUT"

#!/bin/bash
# cover_q.sh <area>[:<plan>[:<suffix>]] ...: coverage runs two at a time (runcover.sh), a plan
# other than cover_<area>.plan given after the area (e.g. 5-4:cover_5-4-late.plan:_late).
# Waits for runs already going to end first.
cd /home/claude/lab
[ -n "$NOWAIT" ] || while pgrep -f "Godot_v4.7.2-stable_linux.x86_64 --headless --path . -- --game" > /dev/null; do sleep 20; done
printf "%s\n" "$@" | xargs -P ${P:-2} -I{} bash -c 'IFS=: read a p s <<< "{}"; PLAN=${p:-cover_$a.plan} ./runcover.sh $a ${s:-_q}'

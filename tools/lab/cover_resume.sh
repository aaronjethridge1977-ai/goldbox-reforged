#!/bin/bash
# cover_resume.sh <list file>: runs the queue in the list (area:plan:suffix ...), skipping entries whose
# log already has its closing "done:" line; after a restart of the workspace, run it again (chat 16).
cd /home/claude/lab
todo=""
for e in $(cat $1); do IFS=: read a p s <<< "$e"; grep -q "COVER .* done:" data/cover_$a$s.log 2>/dev/null || todo="$todo $e"; done
echo "to run:$todo"
[ -n "$todo" ] && NOWAIT=1 P=${P:-2} ./cover_q.sh $todo

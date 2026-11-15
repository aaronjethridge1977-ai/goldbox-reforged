#!/bin/bash
# The original in my lab: Xvfb :98 + DOSBox (por.conf), then dump.py steps.
cd "$(dirname "$0")"
export DISPLAY=:98
pgrep -f "Xvfb :98" >/dev/null || (Xvfb :98 -screen 0 800x600x24 >/dev/null 2>&1 &)
sleep 1
# Its own DOSBox only (lab rule, Methods 5): the one whose pid is in /tmp/gbr_dosbox_98.pid; another lane's or
# script's DOSBox is never reused or stopped. ./orig.sh stop stops ours (and the trace reader we started).
PIDF=/tmp/gbr_dosbox_98.pid
if [ "$1" = stop ]; then
  [ -f /tmp/gbr_trace_98.pid ] && kill $(cat /tmp/gbr_trace_98.pid) 2>/dev/null; rm -f /tmp/gbr_trace_98.pid
  [ -f $PIDF ] && kill $(cat $PIDF) 2>/dev/null; rm -f $PIDF; sleep 2; exit 0
fi
if ! { [ -f $PIDF ] && kill -0 "$(cat $PIDF)" 2>/dev/null; }; then
  (dosbox-staging-linux-x86_64-0.83.0-7b400/dosbox -conf ${CONF:-por.conf} >/tmp/dosbox.log 2>&1 & echo $! > $PIDF)
  sleep 2
fi
python3 dump.py "$@"

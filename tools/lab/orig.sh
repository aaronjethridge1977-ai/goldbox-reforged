#!/bin/bash
# The original in my lab: Xvfb :98 + DOSBox (por.conf), then dump.py steps.
cd "$(dirname "$0")"
export DISPLAY=:98
pgrep -f "Xvfb :98" >/dev/null || (Xvfb :98 -screen 0 800x600x24 >/dev/null 2>&1 &)
sleep 1
if ! pgrep -f dosbox >/dev/null; then
  (dosbox-staging-linux-x86_64-0.83.0-7b400/dosbox -conf ${CONF:-por.conf} >/tmp/dosbox.log 2>&1 &)
  sleep 2
fi
python3 dump.py "$@"

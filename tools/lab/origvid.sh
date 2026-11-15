#!/bin/bash
# origvid.sh <save> <seed> <out.mkv> <secs> [magic]: the original's fight from a lab save, recorded losslessly (30 fps).
cd "$(dirname "$0")"; ./orig.sh stop   # our own DOSBox only (Methods 5)
./orig.sh wait=15 enter wait=6 l wait=4 ${1,,} wait=10 $PRE up wait=3 up wait=3 >/dev/null
python3 seed.py set $2 >/dev/null
DISPLAY=:98 ffmpeg -loglevel error -y -f x11grab -framerate 30 -video_size 800x600 -i :98 -t $4 -vf crop=640:400:80:100 -c:v ffv1 $3 &
F=$!; sleep 1; ./orig.sh enter wait=1 >/dev/null
DISPLAY=:98 timeout $4 python3 presser.py $4 noenter $5; sleep 3; kill -INT $F; wait $F

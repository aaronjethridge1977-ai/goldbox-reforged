#!/bin/bash
# stirge_dq.sh <tag> [proj]: the Player's 7:26 13,22 stirge band (p53a1_s37stirge as fixture stirge2, game speed 2), seed
# b871d583, step north, COMBAT; every member DONE, QUIT each turn (so the stirges latch on and drink until sated).
# The original by combat38/orighand.sh + combat51/menukeys.py (rows logged), then ours (combat51/ours.sh), compared.
cd /home/aaron/gbr/combat_lab || exit 1
T=$1; P=${2:-proj54s}
if [ -z "$OURSONLY" ]; then
  OSECS=${OSECS:-900} HANDPY=combat51/menukeys.py MENUKEYS="$(cat combat54/dq_groups.txt)" bash combat38/orighand.sh stirge2 b871d583 c54$T "" "up,c" > tmp/c54_${T}_run.log 2>&1
  cp tmp/c33_c54${T}_orig.txt tmp/c54_${T}_orig.txt
fi
PROJ=$P OT=${OT:-600} combat51/ours.sh stirge2 b871d583 "" "up,wait,wait,wait,wait,wait,wait,c,$(cat combat54/dq_ours.txt),fightend,n,wait,wait,wait,wait,wait,wait,tplog" tmp/c54_${T}_ours.txt
grep "^ *#\|^ *pos \|^ *cell \|PARTY \|ASKED " tmp/c54_${T}_ours.txt > tmp/c54_${T}_ours_t.txt
DRAWS_ONLY=1 python3 cmpdraws.py tmp/c54_${T}_orig.txt tmp/c54_${T}_ours_t.txt | tail -3
echo DQDONE

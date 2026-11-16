#!/bin/bash
# walkcap.sh <save dir> [keys...]: a Player save in the original (slot A) with sound on (por_snd.conf), DOSBox's
# wave capture (Ctrl+F6) around the keys (default: turns and steps), then sndmatch on the new wave. Lab only.
cd /home/aaron/gbr/combat_lab
SD=$1; shift; KEYS=${*:-left wait=2 right wait=2 right wait=2 up wait=2 up wait=2 left wait=2 up wait=2}
rm -f root/POOLRAD/CHRDATA[A][1-8].*; bash combat9/inst.sh $SD game A
./killmine.sh '[d]osbox -conf'; sleep 1
export SDL_AUDIODRIVER=dummy CONF=por_snd.conf
./orig.sh wait=15 enter wait=6 l wait=4 a wait=10 >/dev/null
./orig.sh ctrl+f6 >/dev/null
for k in $KEYS; do ./orig.sh $k >/dev/null; done
./orig.sh ctrl+f6 >/dev/null; sleep 2
./orig.sh grab=tmp/walkcap_end.png >/dev/null 2>&1
W=$(ls -t cap/*.wav | head -1); echo "$W"
python3 combat10/sndmatch.py "$W" | grep -v '^row '
./killmine.sh '[d]osbox -conf'

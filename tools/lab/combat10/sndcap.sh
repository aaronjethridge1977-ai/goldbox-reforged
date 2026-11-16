#!/bin/bash
# sndcap.sh <save dir> <seed> <seconds> [keys...]: a Player save in the original (slot A) with sound on (por_snd.conf,
# SDL's dummy audio driver), DOSBox's wave capture (Ctrl+F6) running from the keys through <seconds> of QUICK play
# (presser), and the dice traced (tmp/sndcap_<seed>.txt). The wave lands in cap/. Prints DS:0x5372 (sound device:
# 0 Tandy, 1 PC speaker, 2 none) and DS:0x5374 read from the running game.
cd /home/aaron/gbr/combat_lab
SD=$1; SEED=$2; T=$3; shift 3; KEYS=${*:-up wait=3 enter wait=6}
rm -f root/POOLRAD/CHRDATA[A][1-8].*; bash combat9/inst.sh $SD game A
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1
export SDL_AUDIODRIVER=dummy CONF=por_snd.conf
./orig.sh wait=15 enter wait=6 l wait=4 a wait=10 >/dev/null
python3 trace.py install >/dev/null && python3 seed.py set $SEED >/dev/null
(DISPLAY=:96 timeout $((T + 60)) python3 trace.py run $((T + 40)) > tmp/sndcap_$SEED.txt &)
sleep 1
./orig.sh ctrl+f6 >/dev/null
for k in $KEYS; do ./orig.sh $k >/dev/null; done
DISPLAY=:96 timeout $((T + 10)) python3 presser.py $T noenter > tmp/sndcap_${SEED}_press.txt
python3 dssnap.py tmp/sndcap.ds 0x6000 && python3 -c "
d=open('tmp/sndcap.ds','rb').read(); print('DS:0x5372', d[0x5372], 'DS:0x5374', d[0x5374] | d[0x5375] << 8)"
./orig.sh ctrl+f6 >/dev/null; sleep 2
ls -t cap/*.wav 2>/dev/null | head -1
./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'

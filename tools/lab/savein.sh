#!/bin/bash
# savein.sh <fixture>: copies a fight's start save from combat5/saves/<fixture>/ or combat6/saves/<fixture>/ (lab only;
# game data, never committed) into game/ as save A, the scratch slot (Combat Chat 5 and 6: the late fights).
cd "$(dirname "$0")"
# Combat Chat 8: slot A's member files cleared first (a 7-member save left CHRDATA7 behind and 2:9 stalled).
rm -f /home/aaron/gbr/combat_lab/root/POOLRAD/CHRDATA[A][1-8].*
if [ -d combat8/saves/$1 ]; then cp combat8/saves/$1/* game/; elif [ -d combat6/saves/$1 ]; then cp combat6/saves/$1/* game/; else cp combat5/saves/$1/* game/; fi

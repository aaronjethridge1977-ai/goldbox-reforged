#!/bin/bash
# slotfrom.sh <fixture dir> <from letter> <to letter>: like slot.sh for a fixture saved in another slot (chat 29).
cd "$(dirname "$0")"
src=$1; F=${2^^}; L=${3^^}
for f in $src/CHRDAT$F*; do b=$(basename $f); cp $f game/${b/CHRDAT$F/CHRDAT$L}; done
python3 - "$src/SAVGAM$F.DAT" "game/SAVGAM$L.DAT" "$F" "$L" <<'PY'
import sys
s=bytearray(open(sys.argv[1],'rb').read())
for k in range(8):
    o=0x3209+k*41; n=s[o]
    if 0<n<=12 and s[o+1:o+7]==b'CHRDAT' and s[o+7]==ord(sys.argv[3]): s[o+7]=ord(sys.argv[4])
open(sys.argv[2],'wb').write(s)
PY

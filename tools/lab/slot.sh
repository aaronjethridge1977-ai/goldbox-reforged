#!/bin/bash
# slot.sh <fixture dir> <letter>: a fight's start save (slot A files) installed as another slot, the
# character file names in the SAVGAM patched to it (lab only, chat 28; run from the lab, e.g. `./slot.sh combat5/saves/troll G`).
cd "$(dirname "$0")"
src=$1; L=${2^^}
for f in $src/CHRDATA*; do b=$(basename $f); cp $f game/${b/CHRDATA/CHRDAT$L}; done
python3 - "$src/SAVGAMA.DAT" "game/SAVGAM$L.DAT" "$L" <<'PY'
import sys
s=bytearray(open(sys.argv[1],'rb').read())
for k in range(8):
    o=0x3209+k*41; n=s[o]
    if 0<n<=12 and s[o+1:o+8]==b'CHRDATA': s[o+7]=ord(sys.argv[3])
open(sys.argv[2],'wb').write(s)
PY

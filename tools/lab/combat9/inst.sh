#!/bin/bash
# inst.sh <save dir> <game dir> <slot>: an original's save (SAVGAM*.DAT + CHRDAT*.SAV) installed as <slot> in <game dir>,
# the old slot's member files cleared first and the save's member file names renamed to the slot (map61.sh's renaming).
python3 - "$@" <<'P'
import os, shutil, sys, glob
src, G, SLOT = sys.argv[1], sys.argv[2], sys.argv[3].upper()
for f in glob.glob(os.path.join(G, "CHRDAT%s*.SAV" % SLOT)): os.remove(f)
for f in os.listdir(src):
    u = f.upper()
    dst = "SAVGAM%s.DAT" % SLOT if u.startswith("SAVGAM") else "CHRDAT%s%s" % (SLOT, u[7:])
    shutil.copy(os.path.join(src, f), os.path.join(G, dst))
p = os.path.join(G, "SAVGAM%s.DAT" % SLOT); s = bytearray(open(p, "rb").read())
for k in range(8):
    o = 0x3209 + k * 41
    if 0 < s[o] <= 12 and s[o+1:o+7] == b"CHRDAT": s[o+7] = ord(SLOT)
open(p, "wb").write(s)
P

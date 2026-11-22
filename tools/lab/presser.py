"""Presses Q whenever the original offers QUICK, every half second, until the fight ends.
(noenter: no Enter first; magic: Alt-M right after the first Q, so QUICK members cast.)
"CONTINUE BATTLE" is answered NO and reported (ASKED CONTINUE BATTLE), as ours' fightend does
(CONTINUE=y in the environment: YES, the first time it is asked)."""
import os, sys, time, lab, keys
yes = os.environ.get("CONTINUE") == "y"
t0 = time.time(); seen = False
# QUICKSET=1 (Combat Chat 44): the save's party is already on QUICK, so the original shows no QUICK menu: the fight
# counts as begun from the start (CONTINUE BATTLE answered, the end text ends the run); no Q and no Alt-M are sent
# (MAGIC: cmpfight3's MAGICAT=<draw>).
if os.environ.get("QUICKSET"): seen = True
if "noenter" not in sys.argv: keys.key("enter")
while time.time() - t0 < float(sys.argv[1]):
    time.sleep(0.5)
    r = lab.text(lab.screen(), 24)
    if "QUICK" in r:
        if "magic" in sys.argv and not seen and os.environ.get("MAGICFIRST"):
            keys.key("alt+m"); time.sleep(0.3)   # Combat Chat 33: a lone member's first QUICK turn runs before a late Alt-M
        keys.key("q")
        if "magic" in sys.argv and not seen and not os.environ.get("MAGICFIRST"):   # Alt-M while that first QUICK turn runs
            time.sleep(0.2); keys.key("alt+m")
        seen = True
    if seen and "CONTINUE BATTLE" in r:
        print("ASKED CONTINUE BATTLE", flush=True)
        keys.key("y" if yes else "n"); yes = False; continue
    if seen and ("CONTINUE" in r or "PRESS <ENTER>" in r): break

"""Presses Q whenever the original offers QUICK, every half second, until the fight ends.
(noenter: no Enter first; magic: Alt-M right after the first Q, so QUICK members cast.)"""
import sys, time, lab, keys
t0 = time.time(); seen = False
if "noenter" not in sys.argv: keys.key("enter")
while time.time() - t0 < float(sys.argv[1]):
    time.sleep(0.5)
    r = lab.text(lab.screen(), 24)
    if "QUICK" in r:
        keys.key("q")
        if "magic" in sys.argv and not seen:   # Alt-M while that first QUICK turn runs
            time.sleep(0.2); keys.key("alt+m")
        seen = True
    if seen and ("CONTINUE" in r or "PRESS <ENTER>" in r): break

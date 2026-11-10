"""C3 checks against the original, from save A.

  python3 c3lab.py away     fight the first battle met on the way to the Slums orcs; party
                            members wait (DONE) until monsters attack them, then the
                            attacked one steps away from the monsters (free attacks).
Every change of the right-hand panel is logged and shot.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab, keys, route as R
from lab import key, log, status, shot, wait_for, screen, text

AWAY = {0: ["end"], 1: ["left"], 2: ["home"], 3: ["right"]}   # map facing -> step away keys
last = [None]

def panel(im):
    return [text(im, r)[23:].strip(" ?\\") for r in range(1, 23)]

def watch(tag, s=None):
    s = s or status()
    rows = [r for r in panel(s["im"]) if r]
    sig = (s["bottom"], tuple(rows))
    if sig != last[0]:
        last[0] = sig
        shot(tag, s["im"])
        log(tag, "|", s["bottom"], "|", " / ".join(rows))
    return s, rows

def to_fight():
    s = lab.boot("a")
    x, y = [int(v) for v in s["pos"].split()[0].split(",")]
    facing = "NESW".index(s["pos"].split()[1])
    p = R.route((x, y), {(14, 1)}, set(range(1, 22)))
    ks, f = R.keys(p, facing)
    ks += {0: ["left"], 1: ["left", "left"], 2: ["right"], 3: []}[f] + ["up"]
    for k in ks:
        key(k); time.sleep(0.5)
        s = status()
        if not s["bottom"].startswith("AREA"):
            break
    for i in range(12):
        s = status()
        log("at", s["pos"], "|", s["bottom"])
        if s["pos"]:
            facing = "NESW".index(s["pos"].split()[1])
        if lab.in_combat(s):
            return s, facing
        if s["bottom"].startswith("COMBAT"):
            key("c")
        elif "PRESS" in s["bottom"]:
            key("enter")
        time.sleep(1.2)
    return status(), facing

def away():
    s, facing = to_fight()
    log("facing", facing)
    attacked = set()
    t0 = time.time()
    while time.time() - t0 < 120:
        s, rows = watch("w")
        joined = " ".join(rows)
        if "ATTACKS" in joined and len(rows) > 2:
            i = [k for k, r in enumerate(rows) if "ATTACKS" in r][0]
            if i + 1 < len(rows):
                attacked.add(rows[i + 1].strip())
        if s["bottom"].startswith("MOVE VIEW"):
            name = rows[0].strip() if rows else ""
            if name in attacked:
                log("== stepping away:", name)
                key("m"); time.sleep(0.8); watch("move")
                for k in AWAY[facing] * 3:
                    key(k)
                    t = time.time()
                    while time.time() - t < 6:
                        s, rows = watch("away")
                        if s["bottom"].startswith("MOVE/ATTACK") and t + 1.5 < time.time():
                            break
                        time.sleep(0.25)
                return
            key("d"); time.sleep(0.6); key("q"); time.sleep(0.6)
        time.sleep(0.25)

if __name__ == "__main__":
    try:
        globals()[sys.argv[1]]()
    finally:
        open(os.path.join(lab.OUT, "log.txt"), "w").write("\n".join(lab.log_lines) + "\n")

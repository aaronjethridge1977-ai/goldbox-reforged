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

def to_fight(stand=(14, 1), face=3, through=()):
    """Walk from save A to `stand`, turn to `face` (0-3 = NESW) and step forward. The route
    avoids event squares except the events in `through`."""
    s = lab.boot("a")
    x, y = [int(v) for v in s["pos"].split()[0].split(",")]
    facing = "NESW".index(s["pos"].split()[1])
    p = R.route((x, y), {stand}, set(range(1, 22)) - set(through))
    ks, f = R.keys(p, facing)
    turn = (face - f) % 4
    ks += {0: [], 1: ["right"], 2: ["right", "right"], 3: ["left"]}[turn] + ["up"]
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

def full(im):
    return [text(im, r).rstrip() for r in range(25)]

def watch_full(tag, s=None):
    s = s or status()
    rows = full(s["im"])
    sig = tuple(rows)
    if sig != last[0]:
        last[0] = sig
        shot(tag, s["im"])
        log(tag, "||", " / ".join(r.strip(" ?\\") for r in rows if r.strip(" ?\\")))
    return s, rows

def win():
    """Quick-fight the first battle on the way to the orcs; capture what follows a win."""
    s, facing = to_fight()
    t0 = time.time()
    while time.time() - t0 < 125:
        s, rows = watch_full("w")
        b = s["bottom"]
        if "CONTINUE BATTLE" in " ".join(rows):
            key("n"); time.sleep(0.5)
        elif b.startswith("MOVE VIEW"):
            key("q"); time.sleep(0.4)
        elif "PRESS" in b or "CONTINUE" in b:
            time.sleep(1.0); watch_full("p"); key("enter")
        elif b.startswith("VIEW") or "TAKE" in b or "POOL" in b:
            watch_full("treasure")
            for k in os.environ.get("AFTER", "v esc").split():
                key(k); time.sleep(1.5); watch_full("after_" + k)
            return
        time.sleep(0.3)


def tactics():
    """Monster tactics: the feeding kobolds (Slums event 6, 15 kobolds and a leader) entered
    from 6,0 facing east. Most kobolds start behind the front rank and must work their way
    round to the party. Everyone on Quick; every screen logged. The route passes events 4
    and 5 (room descriptions). STAND="x,y,facing" picks another approach."""
    x, y, f = [int(v) for v in os.environ.get("STAND", "6,0,1").split(",")]
    s, facing = to_fight((x, y), f, (4, 5))
    t0 = time.time()
    while time.time() - t0 < float(os.environ.get("SECS", "110")):
        s, rows = watch_full("w")
        b = s["bottom"]
        if "CONTINUE BATTLE" in " ".join(rows):
            key("n"); time.sleep(0.5)
        elif b.startswith("MOVE VIEW"):
            key("q"); time.sleep(0.3)
        elif "PRESS" in b or b.startswith("VIEW") or "TAKE" in b:
            watch_full("end")
            return
        time.sleep(0.15)


def done_menu():
    """DONE's submenu, guarding and bandaging: the Slums orcs; on each party turn press D,
    log the menu, then B (bandage) if it is offered, else G (guard). Every screen logged."""
    s, facing = to_fight()
    t0 = time.time()
    while time.time() - t0 < float(os.environ.get("SECS", "100")):
        s, rows = watch_full("w")
        b = s["bottom"]
        if "CONTINUE BATTLE" in " ".join(rows):
            key("n"); time.sleep(0.5)
        elif b.startswith("MOVE VIEW"):
            key("d"); time.sleep(0.6)
            s, rows = watch_full("done")
            log("done menu:", s["bottom"])
            key("b" if "BANDAGE" in s["bottom"] else "g"); time.sleep(0.6)
        elif "PRESS" in b or b.startswith("VIEW") or "TAKE" in b:
            watch_full("end")
            return
        time.sleep(0.15)


if __name__ == "__main__":
    try:
        globals()[sys.argv[1]]()
    finally:
        open(os.path.join(lab.OUT, "log.txt"), "w").write("\n".join(lab.log_lines) + "\n")

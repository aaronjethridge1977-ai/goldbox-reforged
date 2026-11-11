"""Tour an area in the original (session started with pl.py boot), logging every screen text.

  python3 tour.py <geo> <block> <x,y> [<x,y> ...] [answers=...]

Walks to each square in turn (pl.walk), then plays whatever happens with a fixed policy and
logs the text rows 16-24 each time they change: Enter on PRESS ENTER; encounter menus ->
COMBAT; fights -> QUICK; treasure -> TAKE all then EXIT; LOCKED -> BASH; other menus take the
next letter from answers= (comma separated), else the first item's letter.
The log goes to stdout and cap/tour.txt.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab, keys, pl
OUT = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cap", "tour.txt"), "a")
def log(s):
    print(s, flush=True); OUT.write(s + "\n"); OUT.flush()
args = [a for a in sys.argv[3:] if not a.startswith("answers=")]
answers = []
for a in sys.argv[3:]:
    if a.startswith("answers="):
        answers = a[8:].split(",")
geo, block = sys.argv[1], sys.argv[2]
FIGHT = os.environ.get("TOUR_ENCOUNTER", "c")   # c: fight encounters; f: flee them
import re
POS = re.compile(r"\d+,\d+ [NESW] \d\d:\d\d")
def texts(im):
    return [lab.text(im, r).strip("?\\ ") for r in range(16, 25)]
def play(limit=1500):
    """Plays until the walking menu has been stable for a few reads; logs each settled screen."""
    prev = None; logged = None; same = 0; took = False
    for i in range(limit):
        t = texts(lab.screen()); b = t[-1]
        if t != prev:
            prev = t; same = 0; time.sleep(0.3); continue
        same += 1
        if t != logged:
            log("   " + " | ".join(x for x in t if x)); logged = t
        if b.startswith("AREA"):
            if same >= 2:
                return True
            time.sleep(0.4); continue
        if b.startswith("COMBAT WAIT FLEE"):
            keys.key(FIGHT); time.sleep(2)
        elif b.startswith("VIEW") and b.endswith("EXIT"):
            if not took and "TAKE" in b:
                keys.key("t"); time.sleep(1); keys.key("a"); took = True; time.sleep(1.5)
            else:
                keys.key("e"); time.sleep(1.5)
        elif b.startswith("TAKE") or b.startswith("ITEMS MONEY") or "ALL" in b.split():
            keys.key("e"); time.sleep(1)
        elif b == "YES NO" and "TREASURE" in " ".join(t):
            keys.key("n"); time.sleep(1.5)
        elif b.startswith("CONTINUE BATTLE"):
            keys.key("n"); time.sleep(2)
        elif b.startswith("LOCKED"):
            keys.key("b"); time.sleep(1.5)
        elif "PRESS" in b or b.startswith("ENTER"):
            keys.key("enter"); time.sleep(1.0)
        elif "QUICK" in b:
            keys.key("q"); time.sleep(2)
        elif "MOVE LEFT" in b or "AIM" in b or "ATTACK" in b or b == "GUARDING" or "GOES DOWN" in " ".join(t):
            time.sleep(1.0)
        elif b == "" and POS.search(lab.text(lab.screen(), 15)):
            log("   >> enter (vertical menu: the highlighted item)")
            keys.key("enter"); time.sleep(1.2)
        elif not POS.search(lab.text(lab.screen(), 15)):
            time.sleep(1.0)      # not the walking/event screen (a fight): wait, never guess
        else:
            k = answers.pop(0) if answers else b.split()[0][0].lower()
            log("   >> " + k)
            keys.key(k); time.sleep(1.2)
        prev = None
    log("   (gave up waiting)")
    return False
import route as R
R.NE, R.SW, R.INFO, R.DOORS = R.load(int(geo), int(block))
# Where the original hides the square (0x49FB set), TOUR_START=x,y,F walks by dead
# reckoning from there: turns and steps are counted on the decoded map (teleports and
# script moves are not followed, so the log is only good until the first of those).
_dr = None
if os.environ.get("TOUR_START"):
    a = os.environ["TOUR_START"].split(",")
    _dr = [int(a[0]), int(a[1]), "NESW".index(a[2])]
def step_to(gx, gy):
    """One square at a time, playing out whatever each step brings."""
    for _ in range(60):
        x, y, f, s = pl.where()
        if x is None and _dr is not None:
            x, y, f = _dr
        elif x is None:
            play(); continue
        if (x, y) == (gx, gy):
            return True
        p = R.route((x, y), {(gx, gy)}, set())
        if p is None or len(p) < 2:
            log("   no route from %s,%s" % (x, y)); return False
        ks, nf = R.keys(p[:2], f)
        for k in ks:
            keys.key(k); time.sleep(0.35)
        if _dr is not None:
            _dr[:] = [p[1][0], p[1][1], nf]
        time.sleep(0.5)
        play()
    return False
for sq in args:
    if sq.startswith("key="):
        log("== key %s" % sq[4:]); keys.key(sq[4:]); time.sleep(1); play(); continue
    log("== go %s" % sq)
    gx, gy = [int(v) for v in sq.split(",")]
    step_to(gx, gy)
    x, y, f, s = pl.where()
    log("   at %s,%s %s" % (x, y, s["pos"]))

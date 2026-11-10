"""Scripted sessions against the original game (runs inside run.sh's virtual display).

  python3 lab.py fight <event> [save_letter]   load a save, walk to the event's squares,
                                               capture whatever fight happens first
"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import keys
from keys import key, grab

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = json.load(open(os.path.join(HERE, "font.json")))
OUT = os.environ.get("LAB_OUT", os.path.join(HERE, "cap", "session"))
os.makedirs(OUT, exist_ok=True)
log_lines = []


def log(*a):
    s = " ".join(str(x) for x in a)
    log_lines.append(s)
    print(s, flush=True)


def screen():
    return keys.screen320()


def text(im, row):
    out = ""
    for c in range(40):
        g = bytes(sum(1 << (7 - x) for x in range(8)
                      if sum(im.getpixel((c * 8 + x, row * 8 + y))) > 60
                      and im.getpixel((c * 8 + x, row * 8 + y)) != (85, 85, 85))
                  for y in range(8)).hex()
        out += FONT.get(g, "?" if int(g, 16) else " ")
    return out.rstrip()


def status(im=None):
    im = im or screen()
    return {"bottom": text(im, 24), "pos": text(im, 15).strip("? "), "im": im}


n_shot = [0]


def shot(name, im=None):
    n_shot[0] += 1
    path = os.path.join(OUT, "%02d_%s.png" % (n_shot[0], name))
    (im or screen()).save(path)
    return path


def wait_for(pred, timeout=10, step=0.4):
    t = time.time()
    while time.time() - t < timeout:
        s = status()
        if pred(s):
            return s
        time.sleep(step)
    return status()


def boot(save="a"):
    time.sleep(7); key("enter"); time.sleep(3); key("l"); time.sleep(3)
    w = keys.solve_wheel(log)
    time.sleep(3); key("l"); time.sleep(3); key(save)
    s = wait_for(lambda s: s["bottom"].startswith("AREA"), 15)
    log("loaded at", s["pos"])
    return s


def in_combat(s):
    return s["bottom"].startswith("MOVE") or "AIM" in s["bottom"]


def combat_view(im):
    """True once the battlefield is drawn (the dark grey of the combat window)."""
    grey = sum(1 for x in range(8, 176, 8) for y in range(8, 176, 8) if im.getpixel((x, y)) == (85, 85, 85))
    return grey > 100


def capture_combat(tag):
    t = time.time()
    while time.time() - t < 15:
        im = screen()
        if combat_view(im):
            break
        time.sleep(0.1)
    shot(tag + "_first", im)
    s = wait_for(in_combat, 20)
    shot(tag + "_start", s["im"])
    key("a"); time.sleep(1.5)
    seen = []
    for i in range(12):
        s = status()
        shot(tag + "_aim%d" % i, s["im"])
        sig = s["im"].crop((8, 8, 176, 176)).tobytes()
        if sig in seen:
            break
        seen.append(sig)
        key("n"); time.sleep(1.2)
    log("combat captured:", len(seen), "aim views")


def walk_to_event(ev, start, facing):
    sys.path.insert(0, os.path.expanduser("~/work"))
    import route as R
    p = R.route(start, set(R.squares(ev)), set(range(1, 22)) - {ev})
    ks, _ = R.keys(p, facing)
    log("route", p)
    for k in ks:
        key(k); time.sleep(0.45)
        s = status()
        if s["bottom"].startswith("COMBAT") or s["bottom"].startswith("PRESS"):
            return s
    return status()


def fight(ev, save="a"):
    s = boot(save)
    x, y = [int(v) for v in s["pos"].split()[0].split(",")]
    facing = "NESW".index(s["pos"].split()[1])
    s = walk_to_event(ev, (x, y), facing)
    for i in range(8):
        log("at", s["pos"], "|", s["bottom"])
        if in_combat(s):
            capture_combat("fight"); return
        if s["bottom"].startswith("COMBAT"):       # encounter menu: fight it
            shot("before", s["im"])
            key("c")
            capture_combat("fight"); return
        if "PRESS" in s["bottom"]:
            shot("text%d" % i, s["im"]); key("enter"); time.sleep(0.3)
        else:
            shot("other%d" % i, s["im"]); time.sleep(2)
        s = status()


if __name__ == "__main__":
    try:
        if sys.argv[1] == "fight":
            fight(int(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "a")
    finally:
        open(os.path.join(OUT, "log.txt"), "w").write("\n".join(log_lines) + "\n")

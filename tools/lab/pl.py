"""Persistent lab session: the original keeps running between commands.

  python3 pl.py start                 start the virtual display and DOSBox (stays running)
  python3 pl.py stop
  python3 pl.py boot <save letter>    title -> load menu -> code wheel -> load the save
  python3 pl.py do <steps...>         key names, wait=s, dump (screen as text), grab=file.png,
                                      walk=<geo file>:<block>:<x>,<y>[:<event to avoid>...]
                                      (route on the decoded map from where the screen says the
                                      party is; stops when anything but the AREA line shows),
                                      face=<N|E|S|W>
Run from the lab folder; uses display :99.
"""
import os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("DISPLAY", ":99")
sys.path.insert(0, HERE)


def start():
    stop()
    subprocess.Popen("Xvfb :99 -screen 0 800x600x24 >/dev/null 2>&1", shell=True, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    for _ in range(50):
        if os.path.exists("/tmp/.X11-unix/X99"):
            break
        time.sleep(0.1)
    d = os.path.join(HERE, "dosbox-staging-linux-x86_64-0.83.0-7b400", "dosbox")
    subprocess.Popen("DISPLAY=:99 SDL_AUDIODRIVER=dummy %s -conf %s/por.conf > %s/dosbox.log 2>&1" % (d, HERE, HERE),
                     shell=True, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    print("started")


def stop():
    subprocess.run("pkill -f 'dosbox -conf' ; pkill -f 'Xvfb :99'", shell=True)
    time.sleep(0.3)
    for f in ("/tmp/.X99-lock", "/tmp/.X11-unix/X99"):
        try:
            os.remove(f)
        except OSError:
            pass


def dump():
    import lab
    im = lab.screen()
    rows = []
    for r in range(25):
        t = lab.text(im, r)
        if t.strip("?\\ "):
            rows.append("%2d|%s" % (r, t))
    print("\n".join(rows))
    return im


def where():
    import lab
    s = lab.status()
    try:
        xy, f = s["pos"].split()[:2]
        x, y = [int(v) for v in xy.split(",")]
        return x, y, "NESW".index(f[0]), s
    except Exception:
        return None, None, None, s


def walk(spec):
    import lab, keys
    a = spec.split(":")
    geo, block = int(a[0]), int(a[1])
    gx, gy = [int(v) for v in a[2].split(",")]
    avoid = {int(v) for v in a[3:]}
    import route as R
    R.NE, R.SW, R.INFO, R.DOORS = R.load(geo, block)
    x, y, f, s = where()
    if x is None:
        print("walk: no position on screen:", s["bottom"])
        return
    p = R.route((x, y), {(gx, gy)}, avoid)
    if p is None:
        print("walk: no route from", (x, y), "to", (gx, gy))
        return
    ks, _ = R.keys(p, f)
    print("route", p)
    for k in ks:
        keys.key(k)
        time.sleep(0.45)
        s = lab.status()
        if not s["bottom"].startswith("AREA"):
            print("stopped at", s["pos"], "|", s["bottom"])
            return
    print("arrived", lab.status()["pos"])


def go(spec, tries=8):
    """walk=, again and again: flees encounters, presses Enter on PRESS ENTER, quick-fights."""
    import lab, keys
    for t in range(tries):
        walk(spec)
        same, last = 0, None
        for i in range(250):
            s = lab.status()
            b = s["bottom"]
            if b.startswith("AREA"):
                break
            if b.startswith("COMBAT WAIT FLEE"):
                print("encounter:", lab.text(s["im"], 17), "-> flee"); keys.key("f"); time.sleep(2)
            elif b.startswith("VIEW TAKE POOL"):
                print("treasure -> exit"); keys.key("e"); time.sleep(1.5)
            elif b == "YES NO" and "TREASURE" in lab.text(s["im"], 19):
                keys.key("n"); time.sleep(1.5)
            elif b.startswith("CONTINUE BATTLE"):
                print("continue battle? -> no"); keys.key("n"); time.sleep(2)
            elif b.startswith("LOCKED"):
                print("locked door -> bash"); keys.key("b"); time.sleep(1.5)
            elif "PRESS" in b or b.startswith("ENTER") or b.strip() == "":
                keys.key("enter"); time.sleep(1.5)
            elif "QUICK" in b:
                print("fight:", b, "-> quick"); keys.key("q"); time.sleep(2)
            elif "MOVE LEFT" in b or "AIM" in b or "ATTACK" in b:
                time.sleep(1.5)
            else:
                same = same + 1 if b == last else 0
                last = b
                if same >= 8:
                    print("stuck at menu:", b); dump(); return
                time.sleep(1)
        gx, gy = [int(v) for v in spec.split(":")[2].split(",")]
        x, y, f, s = where()
        if (x, y) == (gx, gy):
            print("go: arrived", s["pos"]); return
    print("go: gave up")


def face(d):
    import keys
    x, y, f, s = where()
    if f is None:
        return
    turn = ("NESW".index(d) - f) % 4
    for k in {0: [], 1: ["right"], 2: ["right", "right"], 3: ["left"]}[turn]:
        keys.key(k)
        time.sleep(0.3)


def do(steps):
    import keys, lab
    for a in steps:
        if a.startswith("wait="):
            time.sleep(float(a[5:]))
        elif a == "dump":
            print("-----")
            dump()
        elif a == "solve":
            keys.solve_wheel(print)
        elif a.startswith("grab="):
            lab.screen().save(a[5:])
        elif a.startswith("big="):
            keys.grab(a[4:])
        elif a.startswith("walk="):
            walk(a[5:])
        elif a.startswith("go="):
            go(a[3:])
        elif a.startswith("face="):
            face(a[5:])
        elif a.startswith("type="):
            for ch in a[5:]:
                keys.key("space" if ch == "_" else ch)
        else:
            keys.key(a)
            time.sleep(0.15)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "start":
        start()
    elif cmd == "stop":
        stop()
    elif cmd == "boot":
        start()
        do(["wait=7", "enter", "wait=3", "l", "wait=3", "solve", "wait=3", "l", "wait=3",
            sys.argv[2] if len(sys.argv) > 2 else "a", "wait=8", "dump"])
    elif cmd == "do":
        do(sys.argv[2:])

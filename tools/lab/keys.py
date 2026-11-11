"""Send key presses to the X display (XTest via ctypes) and grab the screen.

Steps on the command line: a key name (enter, esc, up, a, ctrl+f5 ...), wait=seconds,
or grab=path.png (an 800x600 capture of the virtual display).
"""
import ctypes, os, subprocess, sys, time

X = ctypes.cdll.LoadLibrary("libX11.so.6")
XT = ctypes.cdll.LoadLibrary("libXtst.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
X.XStringToKeysym.restype = ctypes.c_ulong
X.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
XT.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
XT.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
X.XFlush.argtypes = [ctypes.c_void_p]

DISPLAY = os.environ.get("DISPLAY", ":99")
d = X.XOpenDisplay(DISPLAY.encode())
if not d:
    sys.exit("cannot open display " + DISPLAY)
# No window manager: keys go to the window under the pointer, so park it over DOSBox.
XT.XTestFakeMotionEvent(d, -1, 400, 300, 0)
X.XFlush(d)

NAMES = {"enter": "Return", "esc": "Escape", "up": "Up", "down": "Down", "left": "Left",
         "right": "Right", " ": "space", "space": "space", "shift": "Shift_L",
         "ctrl": "Control_L", "f5": "F5", "backspace": "BackSpace", "home": "Home", "end": "End",
         "pgup": "Prior", "pgdn": "Next", "f11": "F11", "f12": "F12"}   # Home / End pick the previous / next character


def keycode(name):
    return X.XKeysymToKeycode(d, X.XStringToKeysym(NAMES.get(name.lower(), name.lower()).encode()))


def key(name, hold=0.08):
    mods = []
    if "+" in name and len(name) > 1:
        *mods, name = name.split("+")
    mod_codes = [keycode(m) for m in mods]
    k = keycode(name)
    for c in mod_codes:
        XT.XTestFakeKeyEvent(d, c, 1, 0)
    XT.XTestFakeKeyEvent(d, k, 1, 0)
    X.XFlush(d)
    time.sleep(hold)
    XT.XTestFakeKeyEvent(d, k, 0, 0)
    for c in mod_codes:
        XT.XTestFakeKeyEvent(d, c, 0, 0)
    X.XFlush(d)
    time.sleep(0.05)


def grab(path):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "x11grab", "-video_size", os.environ.get("GRAB_SIZE", "800x600"),
                    "-i", DISPLAY, "-frames:v", "1", path], check=True)


# --- Code wheel ---------------------------------------------------------------------
# Loading a game asks the translation-wheel question: an Espruar rune (two 8x8 font cells,
# under "MATCH THE"), a Dethek rune (one cell, under "WITH THE"), and a path drawn as dots,
# dashes with ticks, or plain dashes. The runes are characters of the game's own font
# (8X8D1.DAX block 201), so the lab reads them exactly. The wheel itself (rune numbers,
# words, formula) is kept in wheel.json in the git-ignored lab folder, not in the repo.

def screen320():
    """The DOS screen (320x200) from the virtual display."""
    from PIL import Image
    tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_q.png")   # not /tmp: a
    grab(tmp)                                     # stale file there may belong to another user
    im = Image.open(tmp).convert("RGB")
    return im.crop((80, 100, 720, 500)).resize((320, 200), Image.NEAREST)


def solve_wheel(log=print, tries=5):
    """Answers the question; tries again while it is still being drawn."""
    import json
    w = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wheel.json")))
    for _ in range(tries):
        word = _solve_once(w, log)
        if word:
            return word
        time.sleep(1.5)
    return None


def _solve_once(w, log):
    im = screen320()
    red = lambda p: p[0] > 150 and p[1] < 120

    def cell(x0, y0):
        return bytes(sum(1 << (7 - x) for x in range(8) if red(im.getpixel((x0 + x, y0 + y))))
                     for y in range(8)).hex()

    # Runes may sit a few pixels off the text grid: look around the expected cell.
    def find(table, x0, y0, wide):
        for dy in (0, -1, 1, -2, 2, -3, 3, -4, 4):
            for dx in (0, -1, 1, -2, 2, -3, 3, -4, 4):
                k = cell(x0 + dx, y0 + dy) + (cell(x0 + dx + 8, y0 + dy) if wide else "")
                if k in table:
                    return table[k]
        return None

    e = find(w["espruar"], 64, 48, True)
    d = find(w["dethek"], 64, 72, False)
    runs = []
    for y in range(100, 112):
        n = 0
        for x in range(8, 313):
            if x < 312 and red(im.getpixel((x, y))):
                n += 1
            elif n:
                runs.append(n)
                n = 0
    longest = max(runs) if runs else 0
    short = sum(1 for r in runs if r <= 2)
    path = "dots" if longest < 5 else ("ticks" if short else "dashes")
    log("espruar %s dethek %s path %s" % (e, d, path))
    if e is None or d is None:
        log("unknown rune cells", cell(64, 48), cell(72, 48), cell(64, 72))
        return None
    word = w["words"][(e + d + w["paths"][path] + 35) % 36]
    for _ in range(4):   # the menu key that opened the question is already in the box
        key("backspace")
    for ch in word:
        key(ch)
    key("enter")
    return word


if __name__ == "__main__":
    for a in sys.argv[1:]:
        if a.startswith("wait="):
            time.sleep(float(a[5:]))
        elif a.startswith("grab="):
            grab(a[5:])
        elif a == "solve":
            print("answered", solve_wheel())
        else:
            key(a)

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

DISPLAY = os.environ.get("DISPLAY", ":96")
d = X.XOpenDisplay(DISPLAY.encode())
if not d:
    sys.exit("cannot open display " + DISPLAY)
# No window manager: keys go to the window under the pointer, so park it over DOSBox.
XT.XTestFakeMotionEvent(d, -1, 400, 300, 0)
X.XFlush(d)

NAMES = {"enter": "Return", "esc": "Escape", "up": "Up", "down": "Down", "left": "Left",
         "right": "Right", " ": "space", "space": "space", "shift": "Shift_L",
         "ctrl": "Control_L", "alt": "Alt_L", "f5": "F5", "f6": "F6", "f7": "F7", "f8": "F8", "backspace": "BackSpace", "home": "Home", "end": "End",
         "pgup": "Prior", "pgdn": "Next", "f11": "F11", "f12": "F12",
         "kp7": "KP_Home", "kp9": "KP_Prior", "kp1": "KP_End", "kp3": "KP_Next", "kp8": "KP_Up", "kp2": "KP_Down", "kp4": "KP_Left", "kp6": "KP_Right"}   # Home / End pick the previous / next character


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
# Loading a game asks the code-wheel question. The lab's answer is kept outside the repo:
# wheel_solver.py and wheel.json, beside this file in the lab and in the git-ignored .lab
# folder (chat 38; Jeremy, before the repo goes public).

class _XImage(ctypes.Structure):
    _fields_ = [("width", ctypes.c_int), ("height", ctypes.c_int), ("xoffset", ctypes.c_int),
                ("format", ctypes.c_int), ("data", ctypes.c_void_p), ("byte_order", ctypes.c_int),
                ("bitmap_unit", ctypes.c_int), ("bitmap_bit_order", ctypes.c_int),
                ("bitmap_pad", ctypes.c_int), ("depth", ctypes.c_int), ("bytes_per_line", ctypes.c_int),
                ("bits_per_pixel", ctypes.c_int)]


def _xgrab(w=800, h=600):
    """The root window straight from the X server (much faster than an ffmpeg run)."""
    from PIL import Image
    X.XDefaultRootWindow.restype = ctypes.c_ulong
    X.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    X.XGetImage.restype = ctypes.POINTER(_XImage)
    X.XGetImage.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint,
                            ctypes.c_uint, ctypes.c_ulong, ctypes.c_int]
    X.XDestroyImage = getattr(X, "XDestroyImage", None)
    img = X.XGetImage(d, X.XDefaultRootWindow(d), 0, 0, w, h, 0xFFFFFFFF, 2)   # ZPixmap
    xi = img.contents
    buf = ctypes.string_at(xi.data, xi.bytes_per_line * h)
    im = Image.frombuffer("RGB", (w, h), buf, "raw", "BGRX", xi.bytes_per_line, 1)
    im = im.copy()
    X.XFree.argtypes = [ctypes.c_void_p]
    X.XFree(xi.data)
    X.XFree(ctypes.cast(img, ctypes.c_void_p))
    return im


def screen320():
    """The DOS screen (320x200) from the virtual display."""
    from PIL import Image
    if os.environ.get("GRAB_SIZE", "800x600") == "800x600":
        return _xgrab().crop((80, 100, 720, 500)).resize((320, 200), Image.NEAREST)
    tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_q.png")   # not /tmp: a
    grab(tmp)                                     # stale file there may belong to another user
    im = Image.open(tmp).convert("RGB")
    return im.crop((80, 100, 720, 500)).resize((320, 200), Image.NEAREST)


def solve_wheel(log=print, tries=5):
    """Answers the code-wheel question with the lab's wheel_solver.py (not in the repo)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        import wheel_solver
    except ImportError:
        log("no wheel_solver.py beside keys.py: it is kept in the lab and the git-ignored .lab folder, not in the repo")
        return None
    return wheel_solver.solve(log, tries)


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

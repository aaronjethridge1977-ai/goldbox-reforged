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
# No window manager: keys go to the window under the pointer, so park it over DOSBox.
XT.XTestFakeMotionEvent(d, -1, 400, 300, 0)
X.XFlush(d)

NAMES = {"enter": "Return", "esc": "Escape", "up": "Up", "down": "Down", "left": "Left",
         "right": "Right", " ": "space", "space": "space", "shift": "Shift_L",
         "ctrl": "Control_L", "f5": "F5"}


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
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "x11grab", "-video_size", "800x600",
                    "-i", DISPLAY, "-frames:v", "1", path], check=True)


if __name__ == "__main__":
    for a in sys.argv[1:]:
        if a.startswith("wait="):
            time.sleep(float(a[5:]))
        elif a.startswith("grab="):
            grab(a[5:])
        else:
            key(a)

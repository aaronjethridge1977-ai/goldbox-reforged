"""mt.py <steps>: keys (lab keys.py names), click=x,y (left), rclick=x,y, dclick=x,y, mclick=x,y (middle),
wheelup=x,y, wheeldown=x,y, wait=s, grab=png. DISPLAY must be set (:95)."""
import ctypes, sys, time
sys.path.insert(0, "/home/aaron/gbr/lab")
import keys
keys.NAMES.update({"f2": "F2", "f3": "F3"})
XT, d, X = keys.XT, keys.d, keys.X
XT.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]

def btn(b, x, y, n=1):
    XT.XTestFakeMotionEvent(d, -1, x, y, 0); X.XFlush(d); time.sleep(0.15)
    for _ in range(n):
        XT.XTestFakeButtonEvent(d, b, 1, 0); X.XFlush(d); time.sleep(0.05)
        XT.XTestFakeButtonEvent(d, b, 0, 0); X.XFlush(d); time.sleep(0.08)
    time.sleep(0.4)

for s in sys.argv[1:]:
    if "=" in s and not s.startswith("wait="):
        k, v = s.split("=", 1)
        if k == "grab":
            keys.grab(v); continue
        x, y = map(int, v.split(","))
        b = {"click": 1, "dclick": 1, "mclick": 2, "rclick": 3, "wheelup": 4, "wheeldown": 5}[k]
        btn(b, x, y, 2 if k == "dclick" else 1)
    elif s.startswith("wait="):
        time.sleep(float(s[5:]))
    else:
        keys.key(s); time.sleep(0.5)

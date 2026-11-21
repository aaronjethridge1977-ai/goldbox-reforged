"""The original Pool of Radiance in DOSBox Staging, driven by program (Player lane).

A session is one DOSBox on its own virtual display (default :97; the main lane uses :99). Unlike the lab's
pl.py it only ever stops its own processes (pids kept in $OP_LAB/run/), so it can run beside the main lane.

Memory is read through /proc/<pid>/mem (ptrace_scope must be 0): START.EXE's NextRand code is found in
DOSBox's emulated memory (as the lab's seed.py does), which gives the program image, its PSP and data segment.

  orig.py start | stop | status
  orig.py boot <save letter>     title -> load -> code wheel -> the save
"""
import os, re, struct, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.environ.get("OP_LAB", os.path.expanduser("~/gbr/player_lab"))
DISPLAY = os.environ.get("OP_DISPLAY", ":97")
os.environ["DISPLAY"] = DISPLAY
RUN = os.path.join(LAB, "run")
GAME = os.path.join(LAB, "root", "POOLRAD")
DOSBOX = os.path.join(LAB, "dosbox-staging-linux-x86_64-0.83.0-7b400", "dosbox")
sys.path.insert(0, LAB)            # the lab's font.json, wheel.json and keys.py (read-only use)

CODE = bytes.fromhex("a128448b1e2a448bc82ef7264512")   # START.EXE NextRand
CODE_OFF = 0xC18F                  # its place in the unpacked image
DS_SEG = 0xC7C                     # the data segment, image-relative


# ---- processes -------------------------------------------------------------------------------------------

def _pidfile(name):
    return os.path.join(RUN, name + ".pid")


def _alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def pid(name="dosbox"):
    try:
        p = int(open(_pidfile(name)).read())
    except (OSError, ValueError):
        return None
    return p if _alive(p) else None


def conf():
    """por.conf with the lab's paths (the original's settings: S3, normal core, fixed 15000 cycles)."""
    src = open(os.path.join(LAB, "por.conf")).read().replace("/home/claude/lab", LAB)
    if os.environ.get("OP_CYCLES"):     # Player 36: the speed test (cpu_cycles = N or max for this run only)
        src = re.sub(r"(?m)^cpu_cycles\s*=.*$", "cpu_cycles = " + os.environ["OP_CYCLES"], src)
    path = os.path.join(RUN, "op.conf")
    open(path, "w").write(src)
    return path


def start():
    stop()
    os.makedirs(RUN, exist_ok=True)
    n = DISPLAY.lstrip(":")
    for f in ("/tmp/.X%s-lock" % n, "/tmp/.X11-unix/X%s" % n):
        if os.path.exists(f) and not pid("xvfb"):
            os.remove(f)
    x = subprocess.Popen(["Xvfb", DISPLAY, "-screen", "0", "800x600x24"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    open(_pidfile("xvfb"), "w").write(str(x.pid))
    for _ in range(50):
        if os.path.exists("/tmp/.X11-unix/X%s" % n):
            break
        time.sleep(0.1)
    env = dict(os.environ, DISPLAY=DISPLAY, SDL_AUDIODRIVER="dummy")
    d = subprocess.Popen([DOSBOX, "-conf", conf()], start_new_session=True, env=env, cwd=RUN,
                         stdout=open(os.path.join(RUN, "dosbox.log"), "w"), stderr=subprocess.STDOUT,
                         stdin=subprocess.DEVNULL)
    open(_pidfile("dosbox"), "w").write(str(d.pid))
    return d.pid


def stop():
    for name in ("dosbox", "xvfb"):
        p = pid(name)
        if p:
            try:
                os.kill(p, 9)
            except OSError:
                pass
        try:
            os.remove(_pidfile(name))
        except OSError:
            pass
    time.sleep(0.3)


# ---- memory ----------------------------------------------------------------------------------------------

class Mem:
    """The running original's memory. Addresses: lin(linear guest address), ds(offset), far(seg, off)."""

    def __init__(self, p=None):
        self.p = p or pid()
        if not self.p:
            raise SystemExit("no DOSBox running in this lab")
        self.m = open("/proc/%d/mem" % self.p, "r+b", 0)
        self.img = self._find()
        hdr = self.read_host(self.img - 0x110, 16)            # the program's MCB
        self.psp_seg = struct.unpack_from("<H", hdr, 1)[0]
        self.load_seg = self.psp_seg + 0x10
        self.base = self.img - self.load_seg * 16              # host address of guest linear 0
        self.ds_seg = self.load_seg + DS_SEG

    def _find(self):
        for l in open("/proc/%d/maps" % self.p).read().splitlines():
            a, perm = l.split()[:2]
            if "rw" not in perm:
                continue
            lo, hi = (int(v, 16) for v in a.split("-"))
            if hi - lo < 0x100000 or hi - lo > 0x40000000:
                continue
            try:
                self.m.seek(lo)
                buf = self.m.read(hi - lo)
            except OSError:
                continue
            i = buf.find(CODE)
            if i >= 0:
                return lo + i - CODE_OFF
        raise RuntimeError("START.EXE's code not found in DOSBox's memory (not loaded yet?)")

    def read_host(self, a, n):
        self.m.seek(a)
        return self.m.read(n)

    def lin(self, a, n=1):
        return self.read_host(self.base + a, n)

    def wlin(self, a, data):
        self.m.seek(self.base + a)
        self.m.write(data)

    def ds(self, off, n=1):
        return self.lin(self.ds_seg * 16 + off, n)

    def wds(self, off, data):
        self.wlin(self.ds_seg * 16 + off, data)

    def far(self, seg, off, n=1):
        return self.lin(seg * 16 + off, n)

    def u8(self, off):
        return self.ds(off)[0]

    def u16(self, off):
        return struct.unpack("<H", self.ds(off, 2))[0]

    def farptr(self, off):
        o, s = struct.unpack("<HH", self.ds(off, 4))
        return s, o

    def ecl(self, a, n=1):
        """ECL memory 0x4900-0x4CFF (words in the far buffer [DS:0x49D2]; the low byte is the value)."""
        s, o = self.farptr(0x49D2)
        raw = self.far(s, (o + (a - 0x4900) * 2) & 0xFFFF, 2 * n)
        return bytes(raw[0::2])

    def seed(self):
        return struct.unpack("<I", self.ds(0x4428, 4))[0]

    def set_seed(self, v):
        self.wds(0x4428, struct.pack("<I", v))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "start":
        print("dosbox pid", start())
    elif cmd == "stop":
        stop()
    elif cmd == "status":
        print("dosbox", pid(), "xvfb", pid("xvfb"))

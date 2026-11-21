"""Player 42: replay a Player run's keys in the original (Guide 9's videos: p41g1, p41d4 at a human pace).

  replay.py <run log> <seed hex> <out log> [speed]

The save is in slot I already (q.sh's copy). Boots it, sets the game's message speed (DS:0x49E2, x 225 ms a message;
no dice) and the run's seed, then sends every `KEY #n <key>` of the log through game.press (which waits for the
original's own key wait; OP_KEYDELAY=<s> sleeps before each key), with the tool's CONTROL space and MAGIC alt+m armed
at the same places (the next fight poll after the key before them). Before each key the seed is compared with the
log's: a mismatch is logged (DRIFT) and the replay goes on. Stops after the last key."""
import os, re, sys, time
ARGS = [os.path.abspath(a) for a in sys.argv[1:4]]
OP = os.path.expanduser("~/gbr/goldbox-reforged/.claude/worktrees/enchanted-shimmying-token/tools/original_player")
sys.path.insert(0, OP)
os.chdir(OP)
import game as G   # noqa: E402

src, seed, out = ARGS[0], int(sys.argv[2], 16), ARGS[2]
speed = int(sys.argv[4]) if len(sys.argv) > 4 else 0
f = open(out, "w")
t0 = time.monotonic()


def log(*a):
    f.write("%8.1f %s\n" % (time.monotonic() - t0, " ".join(str(x) for x in a)))
    f.flush()


ev = []
last_t = 0.0
STOPAT = int(os.environ.get("OP_STOPAT", "0"))
PROBE = {int(v) for v in os.environ.get("OP_PROBE", "").split(",") if v.strip()}
for line in open(src, encoding="latin1"):
    tm = re.match(r"\s*([\d.]+) ", line)
    m = re.match(r"\s*[\d.]+ KEY #(\d+) (\S+)\s+\|[^|]*\| seed ([0-9a-f]{8}) \|", line)
    if m:
        ev.append(("key", m.group(2), int(m.group(3), 16), int(m.group(1))))
        last_t = float(tm.group(1))
    elif " CONTROL space" in line:
        ev.append(("control", float(tm.group(1)) - last_t))
    elif " MAGIC alt+m" in line:
        ev.append(("magic",))
log("REPLAY", src, "seed %08x speed %d keys %d" % (seed, speed, sum(e[0] == "key" for e in ev)))
g = G.boot("I", log=log)
g.log = log
g.mem.wds(0x49E2, bytes([0 if any(e[0] == "control" for e in ev) else speed]))
g.mem.set_seed(seed)
drift = 0
for e in ev:
    if e[0] == "control":
        # the original took it e[1] s after the key before (timing decides how many QUICK turns the computer plays)
        dt = e[1] + float(os.environ.get("OP_CTLADJ", "0"))
        while time.monotonic() - t_key < dt:
            time.sleep(0.01)
        G._keys.key("space")
        log("CONTROL space %.2f s after the key before" % (time.monotonic() - t_key))
        time.sleep(1.0)
        g.mem.wds(0x49E2, bytes([speed]))      # the slow speed only after the Space (its timing is the fast run's)
        continue
    if e[0] == "magic":
        g.auto_magic, g.magic_sent = True, False
        continue
    _, k, want, n = e
    st = g.settled()
    if g.control_sent:
        g.take_control = False
    if g.magic_sent:
        g.auto_magic = False
    now = g.mem.seed()
    if now != want:
        drift += 1
        log("DRIFT before key #%d %s: seed %08x, the log's %08x (%s)" % (n, k, now, want, st["bottom"] if st else None))
    else:
        log("key #%d %s | %s" % (n, k, st["bottom"] if st else None))
    if n in PROBE or n - 1 in PROBE:       # the figures before the probed key and before the one after it
        import tactics
        log("PROBE before key #%d: %s" % (n, "; ".join("%d %s %d HP st %d @%d,%d" % (
            fg["n"], fg["name"][:8], fg["hp"], fg["status"], fg["x"], fg["y"]) for fg in tactics.figures(g.mem))))
        if os.environ.get("OP_PROBEMAP") and n in PROBE:
            w = tactics.walls(g.mem)
            at = {(fg["x"], fg["y"]): ("%d" % (fg["n"] % 10)) for fg in tactics.figures(g.mem)}
            for y in range(25):
                log("MAP %2d %s" % (y, "".join(at.get((x, y), "#" if (x, y) in w else ".") for x in range(50))))
    nxt = ev[ev.index(e) + 1] if ev.index(e) + 1 < len(ev) else None
    if nxt and nxt[0] == "control":
        g.mem.wds(0x49E2, bytes([0]))
    if STOPAT and n >= STOPAT:
        break
    g.press(k)
    t_key = time.monotonic()
time.sleep(3)
log("END replay: %d keys, %d drifts" % (sum(e[0] == "key" for e in ev), drift))

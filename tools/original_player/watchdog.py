"""Supervisor for unattended runs (plans/player-lane.md, "Running unattended").

  watchdog.py <plan> --save=G --seed=<hex> --run=<id> [--beat=300]

Starts player.py and watches a heartbeat: the run's log growing (a key, a goal, a dice draw logged) and DOSBox
alive. No heartbeat for --beat seconds, or the player dying without an END line: a screenshot and the log tail,
DOSBox stopped, and the run restarted from its last checkpoint (the save copied back into lab slot I, the plan
resumed after that checkpoint, the seed from the checkpoint's index line). Three restarts at one checkpoint: a
tool fault, the run stops cleanly. A run that ends (done, a loss, a stop with its reason) is not restarted.
"""
import os, subprocess, sys, time, shutil
import orig

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(orig.LAB, "logs")
SAVES = os.environ.get("OP_SAVES", os.path.join(orig.LAB, ".lab", "player", "saves"))
RESTORE_SLOT = "I"


def last_checkpoint(run):
    idx = os.path.join(SAVES, "index.txt")
    best = None
    if os.path.exists(idx):
        for line in open(idx):
            parts = [p.strip() for p in line.split(" | ")]
            if len(parts) > 6 and parts[6] == "run %s" % run:
                best = parts
    return best


def restore(cp):
    """Copies a checkpoint's save into lab slot I (SAVGAMI.DAT and its CHRDATI files)."""
    d = cp[-1]
    for f in os.listdir(d):
        src = os.path.join(d, f)
        up = f.upper()
        if up.startswith("SAVGAM"):
            dst = "SAVGAM%s.DAT" % RESTORE_SLOT
        elif up.startswith("CHRDAT"):
            dst = "CHRDAT%s%s" % (RESTORE_SLOT, up[7:])
        else:
            continue
        shutil.copy(src, os.path.join(orig.GAME, dst))
    # the save names its character files: CHRDAT<slot>n
    p = os.path.join(orig.GAME, "SAVGAM%s.DAT" % RESTORE_SLOT)
    s = bytearray(open(p, "rb").read())
    for k in range(8):
        o = 0x3209 + k * 41
        ln = s[o]
        if 0 < ln <= 12 and s[o + 1:o + 7] == b"CHRDAT":
            s[o + 7] = ord(RESTORE_SLOT)
    open(p, "wb").write(s)


def main():
    plan = sys.argv[1]
    a = dict(x[2:].split("=", 1) for x in sys.argv[2:] if x.startswith("--") and "=" in x)
    run, beat = a["run"], float(a.get("beat", 300))
    save, seed, start_after = a.get("save", "G"), a.get("seed"), None
    restarts = {}
    wlog = open(os.path.join(LOGS, "%s.watchdog.log" % run), "a")

    def w(*m):
        wlog.write("%s %s\n" % (time.strftime("%H:%M:%S"), " ".join(str(x) for x in m)))
        wlog.flush()

    while True:
        cmd = [sys.executable, os.path.join(HERE, "player.py"), "run", plan, "--save=" + save, "--run=" + run]
        if seed:
            cmd.append("--seed=" + seed)
        if start_after:
            cmd.append("--after=" + start_after)
        w("START", " ".join(cmd[2:]))
        logp = os.path.join(LOGS, "%s.log" % run)
        proc = subprocess.Popen(cmd, cwd=HERE, stdout=open(os.path.join(LOGS, "%s.out" % run), "a"),
                                stderr=subprocess.STDOUT)
        last_size, last_t = -1, time.time()
        fault = None
        while proc.poll() is None:
            time.sleep(5)
            size = os.path.getsize(logp) if os.path.exists(logp) else 0
            if size != last_size:
                last_size, last_t = size, time.time()
            elif time.time() - last_t > beat:
                fault = "no heartbeat for %d s" % beat
            if orig.pid() is None and time.time() - last_t > 30:
                fault = "DOSBox is gone"
            if fault:
                break
        tail = open(logp).read().splitlines()[-1:] if os.path.exists(logp) else []
        if not fault and tail and (" END " in tail[0] or "SUMMARY" in tail[0]):
            w("ENDED", tail[0])
            return
        if not fault:
            fault = "the player died without an END line (see %s.out)" % run
        try:
            import game
            shot = os.path.join(LOGS, "%s_fault_%d.png" % (run, int(time.time())))
            game._lab.screen().save(shot)
            w("SCREENSHOT", shot)
        except Exception as e:     # no display or DOSBox
            w("no screenshot:", e)
        if proc.poll() is None:
            proc.kill()
        orig.stop()
        w("FAULT", fault, "| log tail:", " / ".join(open(logp).read().splitlines()[-5:]) if os.path.exists(logp) else "")
        cp = last_checkpoint(run)
        key = cp[1] if cp else "start"
        restarts[key] = restarts.get(key, 0) + 1
        if restarts[key] > 3:
            w("STOP: three restarts at checkpoint", key, "(a tool fault)")
            with open(os.path.join(LOGS, "%s.summary.txt" % run), "a") as f:
                f.write("TOOL FAULT: three restarts at checkpoint %s; last: %s\n" % (key, fault))
            return
        if cp:
            restore(cp)
            save, start_after = RESTORE_SLOT, key
            seed = cp[4].split()[1]
        w("RESTART", restarts[key], "from", key, "seed", seed)


if __name__ == "__main__":
    main()

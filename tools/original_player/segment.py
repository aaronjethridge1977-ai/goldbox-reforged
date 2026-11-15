"""Segment check: one of the Player's stretches of the original replayed in ours.

  segment.py <run id> <from checkpoint> <to checkpoint> [--magic]

Ours (the lab's Godot copy, `proj` built by check_godot.sh) loads the original's <from> save (copied to lab slot
F), takes `tpseed=` the seed in its index line (the original's dice from there), then the keys the original was
sent between the two checkpoints (camp and save keys left out: they change nothing); a fight's QUICK keys become
ours' `quickall` (+ `magic` with --magic) and `fightend`. Ours saves (F2) and statediff.gd compares its state with
the original's <to> save. Prints statediff's lines and writes `logs/<run>.segment_<from>-<to>.txt`.
"""
import os, re, shutil, subprocess, sys
import orig

SAVES = os.environ.get("OP_SAVES", os.path.join(orig.LAB, ".lab", "player", "saves"))
LOGS = os.path.join(orig.LAB, "logs")
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SLOT = "F"
GKEY = {"up": "Up", "down": "Down", "left": "Left", "right": "Right", "enter": "Enter", "home": "Home",
        "end": "End", "esc": "Escape"}


def index(run, name):
    for line in open(os.path.join(SAVES, "index.txt")):
        p = [x.strip() for x in line.split(" | ")]
        if p[1] == name and p[6] == "run %s" % run:
            return p
    raise SystemExit("no checkpoint %s in run %s" % (name, run))


def keys_between(run, a, b, magic):
    """The original's keys after checkpoint a's save until checkpoint b's ENCAMP, as ours' --keys."""
    out, on, camp, fight = [], False, False, False
    for line in open(os.path.join(LOGS, "%s.log" % run)):
        if "GOAL done: checkpoint %s" % a in line:
            on = True
            continue
        if not on:
            continue
        m = re.search(r"KEY #\d+ (\S+)\s+\|.*\| (default for \w+|[^|]*)$", line)
        if not m:
            continue
        k, why = m.group(1), m.group(2)
        if "checkpoint %s: ENCAMP" % b in why:
            break
        if "ENCAMP" in why or "checkpoint" in why or "leave camp" in why or "quit to DOS" in why:
            continue
        if why.startswith("default for combat"):
            if not fight:
                out += ["quickall"] + (["magic"] if magic else []) + ["fightend"]
                fight = True
            continue
        if fight:            # the won screen and the treasure take a few frames in ours (chat 24)
            out += ["wait", "wait", "wait"]
            fight = False
        out.append(GKEY.get(k, k))
    return out


def install(cp):
    """The checkpoint's save as lab slot F (character files renamed in the save)."""
    d = cp[-1]
    for f in os.listdir(d):
        u = f.upper()
        dst = "SAVGAM%s.DAT" % SLOT if u.startswith("SAVGAM") else "CHRDAT%s%s" % (SLOT, u[7:])
        shutil.copy(os.path.join(d, f), os.path.join(orig.GAME, dst))
    p = os.path.join(orig.GAME, "SAVGAM%s.DAT" % SLOT)
    s = bytearray(open(p, "rb").read())
    for k in range(8):
        o = 0x3209 + k * 41
        if 0 < s[o] <= 12 and s[o + 1:o + 7] == b"CHRDAT":
            s[o + 7] = ord(SLOT)
    open(p, "wb").write(s)


def main():
    run, a, b = sys.argv[1:4]
    magic = "--magic" in sys.argv
    ca, cb = index(run, a), index(run, b)
    install(ca)
    seed = ca[4].split()[1]
    ks = ["load=" + SLOT, "tpseed=" + seed] + keys_between(run, a, b, magic) + ["wait", "F2"]
    cfg = os.path.join(LOGS, "%s.segment_%s-%s.cfg" % (run, a, b))
    shutil.copy(os.path.join(orig.LAB, "qs.cfg"), cfg)
    G = os.path.join(orig.LAB, "godot", "Godot_v4.7.2-stable_linux.x86_64")
    proj = os.path.join(orig.LAB, "proj")
    os.makedirs(os.path.join(proj, "tools"), exist_ok=True)
    shutil.copy(os.path.join(REPO, "tools", "statediff.gd"), os.path.join(proj, "tools"))
    tmp = os.path.join(orig.LAB, "run_seg")
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copytree(proj, tmp)
    r = subprocess.run(["timeout", "600", G, "--headless", "--path", tmp, "--", "--game-path=" + orig.GAME,
                        "--save=" + cfg, "--keys=" + ",".join(ks)], capture_output=True, text=True)
    shutil.rmtree(tmp, ignore_errors=True)
    ours_log = r.stdout + r.stderr
    orig_save = [os.path.join(cb[-1], f) for f in os.listdir(cb[-1]) if f.upper().startswith("SAVGAM")][0]
    d = subprocess.run(["timeout", "60", G, "--headless", "--path", proj, "--script", "res://tools/statediff.gd",
                        "--", "--ours=" + cfg, "--orig=" + orig_save], capture_output=True, text=True)
    diff = "\n".join(l for l in (d.stdout + d.stderr).splitlines()
                     if l.strip() and not l.startswith("Godot") and not l.lstrip().startswith("at:"))
    out = os.path.join(LOGS, "%s.segment_%s-%s.txt" % (run, a, b))
    open(out, "w").write("keys: %s\n\n--- ours ---\n%s\n--- statediff (ours vs the original's %s) ---\n%s\n" % (
        ",".join(ks), ours_log, b, diff))
    print("keys:", ",".join(ks))
    print(diff)
    print("full output:", out)


if __name__ == "__main__":
    main()

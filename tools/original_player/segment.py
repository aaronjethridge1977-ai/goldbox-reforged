"""Segment check: one of the Player's stretches of the original replayed in ours.

  segment.py <run id> <from checkpoint> <to checkpoint | end> [--magic] [--tplog] [--ours-key=<n>:<key> ...]
  segment.py <run id> begin <to> --start=<p2start save>    (Player 13) from the run's own start save and seed

<to> = end (Player 7): every key to the run's last (a run that stopped before its next checkpoint, as a loss or a
stop after the fight); no statediff then, the draws (--tplog) are the comparison.

--tplog (Player 2) prints ours' dice after every key (`tplog`: each draw with what drew it), for step 2 of the
README's triage. --ours-key (Player 5) sends ours an extra key after the segment's n-th key (1-based, counted among the
keys segment.py keeps), for a screen only ours shows, once the difference is on the board.

Ours (the lab's Godot copy, `proj` built by check_godot.sh) loads the original's <from> save (copied to lab slot
F), takes `tpseed=` the seed in its index line (the original's dice from there), then the keys the original was
sent between the two checkpoints (a checkpoint's camp and save keys left out: they change nothing; Player 13: the
heal's and memorize's camp keys kept, with waits for each REST's length); a fight's QUICK keys become
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


def keys_between(run, a, b, magic, tplog=False, extra=None):
    """The original's keys after checkpoint a's save until checkpoint b's ENCAMP, as ours' --keys.
    extra (Player 5): {n: [keys]} ours-only keys sent after the segment's n-th original key (1-based), for a screen
    only ours shows (a known difference already on the board), so the replay can go on to the next difference."""
    out, on, camp, fight, rest_min, spells = [], False, False, False, 0, 0
    extra, n = extra or {}, 0
    for line in open(os.path.join(LOGS, "%s.log" % run)):
        if "GOAL done: checkpoint %s" % a in line or (a == "begin" and line.split()[1:2] == ["RUN"]):
            on = True
            continue
        if not on:
            continue
        r = re.search(r"NOTE (?:heal )?rest .*?(\d+):(\d+):(\d+)", line)
        if r:     # Player 13: the rest's length, for ours' waits after the REST key (a day is ~1.2 s in ours)
            rest_min = int(r.group(1)) * 1440 + int(r.group(2)) * 60 + int(r.group(3))
        if " MAGIC alt+m " in line:
            # Player 15: the original's run pressed Alt-M in this fight (OP_MAGIC=1): ours' `magic` in the open fight
            out += ["magic"] + (["tplog"] if tplog else [])
            continue
        if re.search(r"NOTE fight fight \d+ ended|NOTE loss the party was destroyed", line):
            # Player 15: a fight the original played with no combat menu (all on QUICK) took no key, so nothing made
            # ours wait for its end: the CONTINUE BATTLE NO and the Enter after it reached ours mid-fight and were lost
            # (p15f6: ours then took a later Y as CONTINUE BATTLE YES). Ours' `fightend` waits for that question.
            if not fight:
                out += ["fightend"] + (["tplog"] if tplog else [])
                fight = True
            continue
        m = re.match(r"\s*-?[\d.]+ KEY #\d+ (\S+)\s+\| ", line)   # Player 3: also a negative time (below)
        if not m:
            continue
        f = line.rstrip("\n").split(" | ", 5)    # key, area and square, seed, wait, row 24, reason
        k, bottom, why = m.group(1), f[4].strip(), f[5]
        if "checkpoint %s: ENCAMP" % b in why:
            break
        # Player 13: only a checkpoint's camp keys are left out (its ENCAMP, SAVE, slot and leaving); the heal's and
        # memorize's camps change state (MAGIC CAST, MEMORIZE, REST) and are replayed.
        if why.startswith("checkpoint") or "quit to DOS" in why:
            continue
        if why.startswith("default for combat"):
            if not fight:
                out += ["quickall"] + (["magic"] if magic else []) + ["fightend"] + (["tplog"] if tplog else [])
                fight = True
            continue
        if fight:            # the won screen and the treasure take a few frames in ours (chat 24)
            out += ["wait", "wait", "wait"]
            fight = False
        if k == "m" and re.match(r"(memorize|heal): (MEMORIZE )?[A-Z][A-Z ]+$", why):
            spells += 1      # Player 14: a spell to be memorized at the next REST
        out.append(GKEY.get(k, k))
        if tplog:
            out.append("tplog")
        if not ("ENCAMP" in bottom and bottom.endswith("LOOK")):
            out += ["wait", "wait"]      # ours' menus and treasure take a few frames (chat 24)
        if rest_min and k == "r" and "REST" in why:
            out += ["wait"] * (rest_min // 5 // 12 // 10 + 4)     # 12 steps a 0.05 s tick: 0.5 s a wait
            # Player 14: ours holds each "HAS MEMORIZED" line for the game speed x 225 ms (camp_screen.gd, as
            # START.EXE 0x709:0xDBE) with the rest's clock paused: p13a1's inn REST was still running at the end.
            out += ["wait"] * (5 * spells)
            # Player 17: a rest of a day or more ends later in ours than the count above (p16d1's last day rest was
            # still running at F2: the clock 6 hours short): a wait more for every 2 hours of it
            out += ["wait"] * (rest_min // 120 if rest_min >= 1440 else 0)
            rest_min, spells = 0, 0
        n += 1
        for e in extra.get(n, []):
            out += [e] + (["tplog"] if tplog else []) + ["wait", "wait"]
    return out


def install(cp):
    """The checkpoint's save as lab slot F (character files renamed in the save)."""
    d = cp[-1]
    # Player 13: the slot's old files out first (a save with no .ITM / .SPC for a member, as the original writes since
    # main's chat 41 for ours too, would otherwise load an older save's items and spells).
    for f in os.listdir(orig.GAME):
        if f.upper() == "SAVGAM%s.DAT" % SLOT or f.upper().startswith("CHRDAT%s" % SLOT):
            os.remove(os.path.join(orig.GAME, f))
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
    tplog = "--tplog" in sys.argv
    extra = {}
    for arg in sys.argv[4:]:     # --ours-key=<n>:<key>: an ours-only key after the segment's n-th key (Player 5)
        if arg.startswith("--ours-key="):
            k, key = arg.split("=", 1)[1].split(":", 1)
            extra.setdefault(int(k), []).append(key)
    cb = None if b == "end" else index(run, b)
    if a == "begin":
        # Player 13: from the run's own start: its start save (.lab/player/saves/p2start/<name>), its SEED line.
        st = [x.split("=", 1)[1] for x in sys.argv[4:] if x.startswith("--start=")]
        if not st:
            raise SystemExit("segment.py <run> begin <to> needs --start=<p2start save name>")
        ca = [None] * 4 + ["seed ?", os.path.join(SAVES, "p2start", st[0])]
        for line in open(os.path.join(LOGS, "%s.log" % run)):
            if " SEED set " in line:
                ca[4] = "seed " + line.split("SEED set ")[1].strip()
                break
    else:
        ca = index(run, a)
    install(ca)
    seed = ca[4].split()[1]
    ks = ["load=" + SLOT, "tpseed=" + seed] + keys_between(run, a, b, magic, tplog, extra) + ["wait", "F2"]
    cfg = os.path.join(LOGS, "%s.segment_%s-%s.cfg" % (run, a, b))
    shutil.copy(os.path.join(orig.LAB, "qs.cfg"), cfg)
    G = os.path.join(orig.LAB, "godot", "Godot_v4.7.2-stable_linux.x86_64")
    proj = os.path.join(orig.LAB, "proj")
    os.makedirs(os.path.join(proj, "tools"), exist_ok=True)
    shutil.copy(os.path.join(REPO, "tools", "statediff.gd"), os.path.join(proj, "tools"))
    tmp = os.path.join(orig.LAB, "run_seg")
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copytree(proj, tmp)
    # Player 15: OP_SEG_TIMEOUT (seconds, default 600): Sokal Keep's 56-figure fight plays longer in ours
    r = subprocess.run(["timeout", os.environ.get("OP_SEG_TIMEOUT", "900"), G, "--headless", "--path", tmp, "--", "--game-path=" + orig.GAME,
                        "--save=" + cfg, "--keys=" + ",".join(ks)], capture_output=True, text=True)
    shutil.rmtree(tmp, ignore_errors=True)
    ours_log = r.stdout + r.stderr
    if cb is None:
        out = os.path.join(LOGS, "%s.segment_%s-%s.txt" % (run, a, b))
        open(out, "w").write("keys: %s\n\n--- ours ---\n%s\n" % (",".join(ks), ours_log))
        print("keys:", ",".join(ks))
        print("full output:", out)
        return
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

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
ours' `quickall` (+ `magic` with --magic) and `fightend`; an Alt-M of the original's run becomes ours' `magic`, or
`magicat=<draw>` from OP_MAGICAT=<draw>,... or the trace's MAGIC lines (Player 23; Combat Chat 25). Ours saves
(F2) and statediff.gd compares its state with the original's <to> save. Prints statediff's lines and writes `logs/<run>.segment_<from>-<to>.txt`.
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


def magic_draws(run, a):
    """Player 23: the draw from which the original's MAGIC was on, one per Alt-M in turn, for ours' magicat=.
    OP_MAGICAT=<draw>,<draw>,... (Combat Chat 25's lab key; "-" for a plain `magic`) wins; else, for a replay from the
    run's start (`begin`: the trace's draws and ours' count alike), the trace's `MAGIC 1 between draws <a> and <b>`
    lines (trace.py since Combat Chat 25) give <a> + 1, or <a> when a == b (Combat Chat 31: no draw between the two
    looks, so the Alt-M was read at a turn-opening poll with a draws done; p29d1). No such lines: plain `magic`."""
    env = os.environ.get("OP_MAGICAT")
    if env is not None:
        return [int(x) if x.strip() not in ("", "-") else None for x in env.split(",")]
    tr = os.path.join(LOGS, "%s.trace.txt" % run)
    if a != "begin" or not os.path.exists(tr):
        return []
    out = []
    for line in open(tr, errors="replace"):
        m = re.match(r"MAGIC 1 between draws (\d+) and (\d+)", line)
        if m:
            a0, b0 = int(m.group(1)), int(m.group(2))
            out.append(a0 if a0 == b0 else a0 + 1)
    return out


def control_draws(run, a):
    """Player 49 (p45i5): the draw from which the original's QUICK members were handed back (game.py's CONTROL space),
    one per CONTROL line in turn, for ours' `controlat=` (asked of Combat, 2026-11-23). OP_CONTROLAT=<draw>,... wins;
    else, from the run's start, the trace's `CONTROL between draws <a> and <b>` lines as magic_draws(). None: the
    line is left out (ours has no other way to take the Space at the right turn)."""
    env = os.environ.get("OP_CONTROLAT")
    if env is not None:
        return [int(x) if x.strip() not in ("", "-") else None for x in env.split(",")]
    tr = os.path.join(LOGS, "%s.trace.txt" % run)
    if a != "begin" or not os.path.exists(tr):
        return []
    out = []
    for line in open(tr, errors="replace"):
        m = re.match(r"CONTROL between draws (\d+) and (\d+)", line)
        if m:
            a0, b0 = int(m.group(1)), int(m.group(2))
            out.append(a0 if a0 == b0 else a0 + 1)
    return out


def seed_draws(run, limit=200000):
    """Player 51: {seed: draw} for the run's RNG from its `SEED set` value (Turbo Pascal: seed x 0x08088405 + 1)."""
    for line in open(os.path.join(LOGS, "%s.log" % run)):
        m = re.search(r" SEED set ([0-9a-fA-F]+)", line)     # hex, as the KEY lines' seed field
        if m:
            x, out = int(m.group(1), 16) & 0xFFFFFFFF, {}
            out.setdefault(x, 0)
            for i in range(1, limit + 1):
                x = (x * 0x08088405 + 1) & 0xFFFFFFFF
                out.setdefault(x, i)
            return out
    return {}


def keys_between(run, a, b, magic, tplog=False, extra=None):
    """The original's keys after checkpoint a's save until checkpoint b's ENCAMP, as ours' --keys.
    extra (Player 5): {n: [keys]} ours-only keys sent after the segment's n-th original key (1-based), for a screen
    only ours shows (a known difference already on the board), so the replay can go on to the next difference."""
    out, on, camp, fight, rest_min, spells = [], False, False, False, 0, 0
    last_t = None
    extra, n = extra or {}, 0
    magicat, magic_slot = magic_draws(run, a), 0
    controlat, n_ctl = control_draws(run, a), 0
    # Player 51 (Combat Chat 52's ask (1)): with no OP_CONTROLAT and no trace line, a CONTROL line's draw is the draw of
    # the next logged seed (a KEY line's or a NOTE's): the RNG stepped from the run's SEED (seed x 0x08088405 + 1).
    # The Space is read at a computer turn's opening poll, the member whose turn it is then takes it by hand with no
    # draw, so that seed is the opening's draw (p45i5: ELWEN's menu at 990). draws[seed] = the count.
    draws, ctl_wait, prev_bottom = None, [], ""
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
            # Player 15: the original's run pressed Alt-M in this fight (OP_MAGIC=1): ours' `magic` in the open fight.
            # Player 23 (Combat Chat 25's request): the original reads the Alt-M some computer turns late, so the
            # n-th Alt-M becomes ours' `magicat=<draw>` (MAGIC ON from the first computer turn at or after that draw)
            # when its draw is known (magic_draws(): OP_MAGICAT, or the trace's MAGIC lines); else plain `magic`.
            n_alt = sum(1 for x in out if x == "magic" or x.startswith("magicat="))
            at = magicat[n_alt] if n_alt < len(magicat) else None
            if at:
                # Player 24: ours' QUICK fight can play past the draw before a key sent here arrives (p19d1: ELWEN's
                # turn at 980 came before magicat=958 reached ours, so MAGIC was still off). Ours keeps the draw
                # (Combat.magic_at_draw, static) until a computer turn reaches it, so send it where the walk to this
                # fight began: after the previous fight's end, or at the segment's start.
                out.insert(magic_slot, "magicat=%d" % at)
                magic_slot += 1      # Player 48 (p45i5: two Alt-Ms in one battle came out as magicat=6380,911)
            else:
                out += ["magic"] + (["tplog"] if tplog else [])
            continue
        sd = re.search(r"\bseed ([0-9a-f]{8})\b", line) if ctl_wait else None
        if sd:
            if draws is None:
                draws = seed_draws(run)
            at = draws.get(int(sd.group(1), 16))
            for slot in reversed(ctl_wait):
                if at is not None:
                    out.insert(slot, "controlat=%d" % at)
                    magic_slot += 1
            ctl_wait = []
        if " CONTROL space " in line:
            # Player 49 (p45i5): the original's hand-back of the QUICK members, read at a computer turn's opening
            # poll as the Alt-M: ours' `controlat=<draw>` at the same slot as magicat= (the walk to this fight)
            if n_ctl >= len(controlat) and a == "begin":
                ctl_wait.append(magic_slot)     # Player 51: the draw from the next logged seed (above)
                n_ctl += 1
                continue
            at = controlat[n_ctl] if n_ctl < len(controlat) else None
            n_ctl += 1
            if at:
                out.insert(magic_slot, "controlat=%d" % at)
                magic_slot += 1
            continue
        if re.match(r"\s*[\d.]+ SHORTCUT win at ", line):
            # Player 34: the original's logged shortcut win (Q27 (a), plan line `shortcutwin`) as ours' lab key
            # `shortcutwin` (main chat 70: the same write in ours' open fight, once the battle has begun)
            out += ["shortcutwin"] + (["tplog"] if tplog else [])
            continue
        if re.search(r"NOTE fight fight \d+ ended|NOTE loss the party was destroyed", line):
            # Player 15: a fight the original played with no combat menu (all on QUICK) took no key, so nothing made
            # ours wait for its end: the CONTINUE BATTLE NO and the Enter after it reached ours mid-fight and were lost
            # (p15f6: ours then took a later Y as CONTINUE BATTLE YES). Ours' `fightend` waits for that question.
            if not fight:
                out += ["fightend"] + (["tplog"] if tplog else [])
                fight = True
            magic_slot = len(out)
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
        # Player 39 (Combat Chat 38's p37i1 ask (1)): a tactics fight's key replayed after two waits reached ours while
        # the spectres were still moving after LIRA's Fireball (the original's ELWEN menu came 6.4 s later) and was lost:
        # before a fight menu's key, ours waits twice the original's gap from the key before (0.5 s a wait: ours' figures
        # move at about half the DOSBox speed: p37i1's two spectre rounds took ~11 s in ours, 6.4 s in the original)
        tk = float(line.split()[0])
        if ("QUICK" in bottom.split() and "DONE" in bottom.split()) and last_t is not None and tk - last_t > 1.5:
            out += ["wait"] * int((tk - last_t) / 0.25)
        # Player 51 (p45i5's last draw, 6563): the closing text after Tyranthraxus took 28 s in the original before its
        # PRESS BUTTON key; ours' F2 came first. Before such a key after a gap of 5 s or more: twice the gap in waits
        if bottom.startswith("PRESS BUTTON") and last_t is not None and tk - last_t >= 5:
            out += ["wait"] * int((tk - last_t) / 0.25)
        last_t = tk
        # Player 41 (Combat Chat 39's answer on p37i1: ours' spectre turn still ran when DORN's "m" came, 0.5 s after the
        # key before in the original, too short for the waits above): OP_FIGHTMENU=1 puts ours' lab key `fightmenu` (waits
        # up to 60 s for a member's fight menu) before each fight menu's key; opt-in, so the match's other runs keep theirs
        # Player 51 (Combat Chat 52's ask (2)): always now (OP_FIGHTMENU=0 turns it off); and the lab key `fightaim`
        # (waits for a member's AIM) before an AIM's first key after a screen that wasn't an AIM: a begun spell going
        # off (p45i5: ELWEN's MANUAL key reached ours during a guard's turn, her Hold Person fell on herself); not
        # after a MANUAL's cursor screen (the next pick of the same spell opens at once)
        if os.environ.get("OP_FIGHTMENU") != "0" and "QUICK" in bottom.split() and "DONE" in bottom.split():
            out.append("fightmenu")
        if os.environ.get("OP_FIGHTMENU") != "0" and bottom.startswith("AIM:") \
                and not prev_bottom.startswith(("AIM:", "(USE CURSOR KEYS)")):
            out.append("fightaim")
        prev_bottom = bottom
        # Player 51 (p45i5 at draw 6467): the CONTINUE BATTLE answer came 0.4 s after the fight's last turn in the
        # original ("NOTE fight ... over", not "ended": no fightend above) and reached ours mid-turn, lost; ours'
        # `fightend` (waits for the question; at once when it's up) before each CONTINUE BATTLE key
        if bottom.startswith("CONTINUE BATTLE"):
            out.append("fightend")
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


# Player 18: ours replays the original's keys with the original's rules: its own Godot user folder (as diffcheck.sh)
# holding a settings.cfg with every QoL switch that changes play turned off. With none, they are on (the release's
# defaults): p18a1's inn REST put CEDRIC's cast CURE LIGHT WOUNDS back (REST REMEMORIZES), so the original's MEMORIZE
# keys found no free slot and the replay left the camp early.
QOL_OFF = {"rememorize": False, "fix": False, "magic_menu": False, "aim_skips_party": False, "start_memorized": False,
           "quick_bandages": False, "smart_quick": False, "smart_monsters": False}


def original_rules_env():
    xdg = os.path.join(orig.LAB, "seg_xdg")
    d = os.path.join(xdg, "godot", "app_userdata", "Gold Box Reforged")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "settings.cfg"), "w") as f:
        f.write("[qol]\n\n" + "".join("%s=%s\n" % (k, str(v).lower()) for k, v in QOL_OFF.items()))
    return dict(os.environ, XDG_DATA_HOME=xdg)


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
    # Player 35 (main chat 72, p16d1): OP_CAMPEND=1 (match/replay.txt): the original's checkpoint save is made in camp,
    # and ENCAMP runs the area's rest block (8:29's CALL 0xC018 rewrites the wall ahead): ours ENCAMPs and EXITs too
    camp = ["e", "wait", "wait", "e", "wait", "wait"] if os.environ.get("OP_CAMPEND") == "1" else []
    ks = ["load=" + SLOT, "tpseed=" + seed] + keys_between(run, a, b, magic, tplog, extra) + ["wait"] + camp + ["F2"]
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
                        "--save=" + cfg, "--keys=" + ",".join(ks)], capture_output=True, text=True, env=original_rules_env())
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

"""The Player: plays the original from a save by plan, sending a key only when the original waits for one.

  player.py run <area plan> [--save=G] [--seed=hex] [--run=<id>]   boot, load, play the plan, summary
  player.py drive <area plan> [--run=<id>]                          the same on the running DOSBox

Every key goes to the log with the game state: key number, wait site, square, area, seed, screen line.
"""
import json, os, re, shutil, sys, time
import orig, hooks
import game as G
import screens

HERE = os.path.dirname(os.path.abspath(__file__))
SAVES = os.environ.get("OP_SAVES", os.path.join(orig.LAB, ".lab", "player", "saves"))
LOGS = os.path.join(orig.LAB, "logs")
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GAME_VERSION = "GOG Pool of Radiance 1.3 (START.EXE md5 4c28d37e, GAME.OVR md5 2ac38b4b)"
DOSBOX_VERSION = "DOSBox Staging 0.83.0 (7b400), por.conf: svga_s3, core normal, cpu_cycles 15000, nosound"


class Stop(Exception):
    pass


class Player:
    def __init__(self, plan, run_id, log_path):
        self.plan = plan
        self.run = run_id
        self.logf = open(log_path, "a")
        self.g = G.Game(log=self.log)
        self.events = []          # (kind, text) for the summary
        self.t0 = time.time()
        self.goal = 0
        self.last_progress = time.time()
        self.fights = 0
        self.in_fight = False
        self.slot_sent = False
        self.shared = False
        self.same, self.last_sig = 0, None
        self.goal_key = 0
        self.prev_kind = None
        self.seen_kinds = set()
        self.saving = None        # the Checkpoint being saved
        self.snapped = set()      # snap answers done (plans.py)
        self.slot = os.environ.get("OP_SLOT", "H")   # the original's save slot for checkpoints (lab slots only)

    def save_step(self, scr):
        """Camp and save-slot screens: SAVE to the slot while a checkpoint is pending, else leave camp."""
        if scr["kind"] == "saveslot":
            self.slot_sent = True
            return self.slot.lower(), "checkpoint %s: slot %s" % (self.saving.name, self.slot)
        if self.saving is not None and not self.saving.done:
            if self.slot_sent:
                self.slot_sent = False
                self.saved()
                return "e", "checkpoint saved: leave camp"
            return "s", "checkpoint %s: SAVE" % self.saving.name
        return "e", "leave camp"

    # -- log ----------------------------------------------------------------------------------------------
    def log(self, *a):
        s = "%7.1f %s" % (time.time() - self.t0, " ".join(str(x) for x in a))
        self.logf.write(s + "\n")
        self.logf.flush()
        if os.environ.get("OP_ECHO"):
            print(s, flush=True)

    def note(self, kind, text):
        self.events.append((kind, text))
        self.log("NOTE", kind, text)

    # -- state --------------------------------------------------------------------------------------------
    def where(self):
        x, y, f = self.g.mem.ds(0x6AAD, 3)
        return x, y, "NESW"[(f // 2) & 3]

    def area(self):
        return self.g.area()

    def saved(self):
        """After the original wrote SAVGAM<slot>.DAT: copy it with its character files, add the index line."""
        cp = self.saving
        cp.done = True
        d = os.path.join(SAVES, self.run, cp.name)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(orig.GAME):
            if f.upper() == "SAVGAM%s.DAT" % self.slot or f.upper().startswith("CHRDAT%s" % self.slot):
                shutil.copy(os.path.join(orig.GAME, f), d)
        x, y, f = self.where()
        a = self.area()
        line = index_line(self, cp.name, a, x, y, f, d)
        open(os.path.join(SAVES, "index.txt"), "a").write(line + "\n")
        self.note("checkpoint", line)
        self.saving = None

    def key(self, k, why):
        st = self.g.last
        sig = (k, tuple(st["rows"].values()))
        self.same = self.same + 1 if sig == self.last_sig else 0
        self.last_sig = sig
        if self.g.nkeys - self.goal_key > 300:
            raise Stop("stuck: no goal done in 300 keys (goal: %s)" % self.plan.goals[min(self.goal, len(self.plan.goals) - 1)])
        if self.same >= 20:
            raise Stop("loop: %r sent 20 times on an unchanged screen (%s)" % (k, st["bottom"] or why))
        x, y, f = self.where()
        self.log("KEY #%d %-6s | %s:%d %d,%d %s | seed %08x | %s %s | %s | %s" % (
            self.g.nkeys + 1, k, *self.area(), x, y, f, self.g.mem.seed(), st["wait"], st["site"],
            st["bottom"], why))
        self.g.press(k)

    # -- play ---------------------------------------------------------------------------------------------
    def step(self):
        """One decision: read the screen, send at most one key. Returns False when the plan is done."""
        st = self.g.settled()
        if st is None:
            raise Stop("no input wanted for 60 s (busy)")
        scr = screens.classify(st)
        st["kind"] = scr["kind"]
        if scr["kind"] == "combat" and self.prev_kind not in ("combat",):
            if not self.in_fight:
                self.fights += 1
                self.in_fight = True
                self.note("fight", "fight %d begins at %d,%d %s (seed %08x)" % ((self.fights,) + self.where() + (self.g.mem.seed(),)))
        if scr["kind"] in ("walking", "treasure", "continue"):   # Player 2: waves fought back to back
            self.in_fight = False
            if not self.g.party_size and scr["kind"] == "walking":
                self.g.party_size = len(self.g.party())
        if scr["kind"] not in self.seen_kinds:
            self.seen_kinds.add(scr["kind"])
            shot = os.path.join(LOGS, "%s_screen_%s.png" % (self.run, scr["kind"]))
            st["im"].save(shot)
            self.log("NEW SCREEN", scr["kind"], shot)
        self.prev_kind = scr["kind"]
        if scr["kind"] == "walking":
            return self.walk(st)
        if scr["kind"] == "wiped":
            self.note("loss", "the party was destroyed at %d,%d %s" % self.where())
            raise Stop("the party was destroyed (a loss: reload from the last checkpoint)")
        k, why = self.plan.answer(scr, st, self)
        if k is None:
            raise Stop("no rule for screen %s: %s" % (scr["kind"], scr.get("text", st["bottom"])))
        for kk in (k if isinstance(k, list) else [k]):
            self.key(kk, why)
        return True

    def walk(self, st):
        goals = self.plan.goals
        while self.goal < len(goals):
            gl = goals[self.goal]
            done, k, why = gl.next(self)
            if done:
                self.log("GOAL done:", gl)
                self.goal += 1
                self.goal_key = self.g.nkeys
                self.last_progress = time.time()
                continue
            if k is None:
                return True
            self.key(k, why)
            return True
        return False


def index_line(p, event, a, x, y, f, path):
    """plans/player-lane.md: game, area, square, facing, event, story flags, party levels and HP, seed, position
    in the key list, run id."""
    m = p.g.mem
    fb = m.ecl(0x4A20, 0xE0)
    flags = " ".join("%04X=%d" % (0x4A20 + i, v) for i, v in enumerate(fb) if v)
    party = p.g.party()
    return "pool %d:%d %d,%d %s | %s | flags %s | party %s | seed %08x | key %d | run %s | %s" % (
        a[0], a[1], x, y, f, event, flags, " ".join("%s L%s %d/%d" % pm for pm in party), m.seed(), p.g.nkeys,
        p.run, path)


def run(plan_path, save, seed, run_id, boot=True, after=None):
    import plans
    os.makedirs(LOGS, exist_ok=True)
    log_path = os.path.join(LOGS, "%s.log" % run_id)
    plan = plans.load(plan_path)
    if boot:
        G.boot(save)
    p = Player(plan, run_id, log_path)
    p.log("RUN", run_id, "plan", plan_path, "save", save, "seed", "%08x" % seed if seed is not None else None,
          "after", after)
    if after:      # resumed by the watchdog from a checkpoint: its goals and the ones before it are done
        import plans
        names = [g.name for g in plan.goals if isinstance(g, plans.Checkpoint)]
        if after not in names:
            raise SystemExit("no checkpoint %r in the plan" % after)
        while not (isinstance(plan.goals[p.goal], plans.Checkpoint) and plan.goals[p.goal].name == after):
            p.goal += 1
        p.goal += 1
    p.log("VERSIONS", GAME_VERSION, "|", DOSBOX_VERSION)
    speed = int(os.environ.get("OP_SPEED", "0"))
    p.log("SPEED was %d, set %d (the game's own speed setting, DS:0x49E2 x 225 ms per message; no dice)" % (
        p.g.mem.u8(0x49E2), speed))
    p.g.mem.wds(0x49E2, bytes([speed]))
    if seed is not None:
        p.g.mem.set_seed(seed)
        p.log("SEED set %08x" % seed)
    reader = None
    if os.environ.get("OP_TRACE"):     # every dice draw with its caller (the lab's trace.py, this lab's DOSBox)
        import subprocess
        env = dict(os.environ, DISPLAY=orig.DISPLAY)
        subprocess.run([sys.executable, "trace.py", "install"], cwd=orig.LAB, env=env, check=True)
        reader = subprocess.Popen([sys.executable, "trace.py", "run", "36000"], cwd=orig.LAB, env=env,
                                  stdout=open(os.path.join(LOGS, "%s.trace.txt" % run_id), "w"),
                                  stderr=subprocess.STDOUT)
        time.sleep(1.5)
        p.log("TRACE reader started:", os.path.join(LOGS, "%s.trace.txt" % run_id))
    result = "done"
    try:
        while p.step():
            pass
    except Stop as e:
        result = "stopped: %s" % e
    except G.Timeout as e:
        result = "stopped: %s" % e
    if reader is not None:
        reader.terminate()
    if result != "done":
        try:
            shot = os.path.join(LOGS, "%s_stop.png" % run_id)
            G._lab.screen().save(shot)
            p.log("STOP SCREEN", shot)
        except Exception as e:
            p.log("no stop screen:", e)
    p.log("END", result)
    summary(p, result, plan_path, save, seed)
    return p, result


def summary(p, result, plan_path, save, seed):
    """The short numbered summary a chat reads instead of the log."""
    try:
        party = p.g.party()
        x, y, f = p.where()
        a = p.area()
        where = "%d:%d %d,%d %s" % (a + (x, y, f))
    except Exception as e:      # DOSBox gone
        party, where = [], "unknown (%s)" % e
    lines = [
        "Player run %s: %s" % (p.run, result),
        "1. Plan %s from save %s, seed %s; goals done %d of %d; ended at %s." % (
            os.path.basename(plan_path), save, "%08x" % seed if seed is not None else "as loaded", p.goal,
            len(p.plan.goals), where),
        "2. Keys sent: %d; fights: %d; time %.0f s." % (p.g.nkeys, p.fights, time.time() - p.t0),
        "3. Party: %s." % ", ".join("%s L%s %d/%d" % m for m in party),
        "4. Checkpoints: %s." % ("; ".join(t.split(" | ")[1] + " (" + t.split(" | ")[0] + ")" for k, t in p.events
                                          if k == "checkpoint") or "none"),
        "5. Screens seen: %s; polls that were not waits: %s." % (", ".join(sorted(p.seen_kinds)),
                                                                ", ".join(sorted(p.g.unknown_sites)) or "none"),
        "6. Findings / reports for Jeremy: %s." % ("; ".join(t for k, t in p.events if k in ("finding", "report"))
                                                  or "none"),
        "7. Tool faults: %s." % ("none" if result == "done" else result),
        "8. Versions: %s | %s." % (GAME_VERSION, DOSBOX_VERSION),
    ]
    path = os.path.join(LOGS, "%s.summary.txt" % p.run)
    open(path, "w").write("\n".join(lines) + "\n")
    p.log("SUMMARY", path)


if __name__ == "__main__":
    a = dict(x[2:].split("=", 1) for x in sys.argv[3:] if x.startswith("--") and "=" in x)
    rid = a.get("run", time.strftime("r%m%d-%H%M%S"))
    seed = int(a["seed"], 16) if "seed" in a else None
    p, res = run(sys.argv[2], a.get("save", "G"), seed, rid, boot=sys.argv[1] == "run", after=a.get("after"))
    print(res)

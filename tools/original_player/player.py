"""The Player: plays the original from a save by plan, sending a key only when the original waits for one.

  player.py run <area plan> [--save=G] [--seed=hex] [--run=<id>]   boot, load, play the plan, summary
  player.py drive <area plan> [--run=<id>]                          the same on the running DOSBox

Every key goes to the log with the game state: key number, wait site, square, area, seed, screen line.
"""
import json, os, re, shutil, sys, time
import orig, hooks
import game as G
import screens
import tactics as T
import plans    # Player 32: the reload rule (plans.reload_rule) from the Player's methods

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
        self.tactics = T.Tactics(self.log)     # Player 30: the tactical mode (`tactics on`)
        self.events = []          # (kind, text) for the summary
        self.t0 = time.monotonic()
        self.goal = 0
        self.last_progress = time.monotonic()
        self.fights = 0
        self.in_fight = False
        self.slot_sent = False
        self.shared = False
        self.take = {}            # Player 10: the TAKE policy's state (plans.py `_take`)
        self.same, self.last_sig = 0, None
        self.goal_key = 0
        self.prev_kind = None
        self.seen_kinds = set()
        self.saving = None        # the Checkpoint being saved
        self.snapped = set()      # snap answers done (plans.py)
        self.answer_counts = {}   # Player 19: counted answers given (plans.py `<choice>*<n>`)
        self.start_names = []     # the party's names at the first walking screen
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
        s = "%7.1f %s" % (time.monotonic() - self.t0, " ".join(str(x) for x in a))
        self.logf.write(s + "\n")
        self.logf.flush()
        if os.environ.get("OP_ECHO"):
            print(s, flush=True)

    def note(self, kind, text):
        self.events.append((kind, text))
        self.log("NOTE", kind, text)

    # -- state --------------------------------------------------------------------------------------------
    def on_band(self):
        """Player 10: on a wilderness band the view DS:0x49FA is 2-4 (6:25, 7:26, 8:27; 1 in a 3D area)."""
        return self.g.mem.u8(0x49FA) in (2, 3, 4)

    def where(self):
        x, y, f = self.g.mem.ds(0x6AAD, 3)
        if self.on_band():
            # Player 10 (lab, p1d/exit on 7:26): the band's square is ECL 0x49C3/0x49C4 (ours' OVERLAND_X/Y), x
            # counted from the band's left edge (the screen shows x + 13 on 7:26: 12,27 -> "25,27"); the 3D
            # square stays put, the facing DS:0x6AAF follows the last arrow.
            x, y = self.g.mem.ecl(0x49C3, 2)
        return x, y, "NESW"[(f // 2) & 3]

    def area(self):
        return self.g.area()

    def saved(self):
        """After the original wrote SAVGAM<slot>.DAT: copy it with its character files, add the index line."""
        cp = self.saving
        cp.done = True
        d = os.path.join(SAVES, self.run, cp.name)
        os.makedirs(d, exist_ok=True)
        # Player 3: only the character files this save wrote: an older save in the slot with a larger party leaves
        # its CHRDAT<slot>7.* behind (the original doesn't delete them), and statediff read them as party members.
        t0 = os.path.getmtime(os.path.join(orig.GAME, "SAVGAM%s.DAT" % self.slot)) - 30
        for f in os.listdir(orig.GAME):
            p = os.path.join(orig.GAME, f)
            if f.upper() == "SAVGAM%s.DAT" % self.slot or (f.upper().startswith("CHRDAT%s" % self.slot)
                                                          and os.path.getmtime(p) >= t0):
                shutil.copy(p, d)
        x, y, f = self.where()
        a = self.area()
        line = index_line(self, cp.name, a, x, y, f, d)
        open(os.path.join(SAVES, "index.txt"), "a").write(line + "\n")
        self.note("checkpoint", line)
        try:      # Player 44 (Guide 12's step 1 (a)): the party ledger beside every checkpoint
            import ledger
            open(os.path.join(d, "LEDGER.txt"), "w").write(ledger.ledger(d))
        except Exception as e:
            self.log("NOTE ledger not written: %s" % e)
        self.saving = None
        if plans.RELOAD_RULE:
            self.rule_base = plans.rule_state(self)    # Player 32: the reload rule counts from the last checkpoint

    def key(self, k, why):
        st = self.g.last
        sig = (k, tuple(st["rows"].values()))
        self.same = self.same + 1 if sig == self.last_sig else 0
        self.last_sig = sig
        # Player 18: a heal goal (heal, prepare, innwait, innheal, cure) of a badly hurt party takes rounds of casts,
        # memorizing and rests: 300 keys stopped two that were going well (p18a2, p18b5); OP_STUCK_KEYS for others.
        goal = self.plan.goals[min(self.goal, len(self.plan.goals) - 1)]
        limit = int(os.environ.get("OP_STUCK_KEYS", "300"))
        if type(goal).__name__ == "Heal":
            limit *= 4
        if self.g.nkeys - self.goal_key > limit:
            raise Stop("stuck: no goal done in %d keys (goal: %s)" % (limit, goal))
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
        if self.g.shortcut_note:       # Player 27: a shortcut win, in the summary's findings
            self.note("report", self.g.shortcut_note)
            self.g.shortcut_note = None
        if scr["kind"] == "combat" and self.prev_kind not in ("combat",):
            if not self.in_fight:
                self.fights += 1
                self.in_fight = True
                self.note("fight", "fight %d begins at %d,%d %s (seed %08x)" % ((self.fights,) + self.where() + (self.g.mem.seed(),)))
        elif scr["kind"] == "continue" and not self.in_fight and self.prev_kind != "continue":
            # Player 10: with every member already on QUICK the original shows no combat menu at all (the
            # goblins' second to fourth fights, p10f1): the fight is seen only at its CONTINUE BATTLE.
            self.fights += 1
            self.note("fight", "fight %d ended at %d,%d %s, all on QUICK (no menu seen)" % ((self.fights,) + self.where()))
        if scr["kind"] in ("walking", "treasure", "continue"):   # Player 2: waves fought back to back
            if self.in_fight and os.environ.get("OP_FIGHTDEATH") == "1":
                # Player 43 (Plan 5's (c), decision 2026-11-20 10:22: a death in the finale's guards' fight is a
                # reload, not a march into Tyranthraxus short-handed; the guards, the vote and he come in one step,
                # with no walking screen between): a member dead at a fight's end stops the run as a reload
                ms = plans.members(self.g.mem)
                # (p43f1: the record list ran on into a guard's: only the party's own)
                own = set(getattr(self, "start_names", None) or [m[0] for m in self.g.party()])
                ms = [m for m in ms if m["name"] in own]
                self.note("fight", "fight %d over: %s" % (self.fights, ", ".join(
                    "%s %d/%d%s" % (m["name"], m["hp"], m["max"], "" if m["status"] < 5 else " status %d" % m["status"])
                    for m in ms)))
                dead = [m["name"] for m in ms if m["status"] >= 6]
                try:
                    import tactics as _t
                    boss = any("TYRAN" in f["name"].upper() for f in _t.figures(self.g.mem))
                except Exception:
                    boss = False
                if dead and boss:
                    # Player 45 (p45i3: Tyranthraxus fell to ARN's blow, BRAM and ELWEN dead in his fight, and the run
                    # stopped as a reload at the CONTINUE BATTLE before the script's win, 0x4ABA = 254): the death rule is
                    # for the guards' fight (Plan 5 (c)); in his fight a death ends the run as won (Player 29's rule)
                    self.note("fight", "fight %d: %s dead in Tyranthraxus' fight: no reload (Player 29's rule)" % (
                        self.fights, ", ".join(dead)))
                    dead = []
                    self.boss_down = True      # plans.reload_rule: no reload until the script writes the win
                if dead:
                    raise Stop("RELOAD: %s dead in fight %d (a death in the fight is a reload)" % (", ".join(dead),
                                                                                                    self.fights))
            self.in_fight = False
            self.g.magic_sent = False      # Player 15: OP_MAGIC: the next fight gets its Alt-M
            if self.g.control_sent:
                self.g.control_sent = False    # Player 30: the next fight gets its Space
                self.tactics.reset()
            if scr["kind"] == "walking":
                # Player 36 (p36n1: Princess Fatima joined as the seventh and the tactics took her for an enemy): the
                # party is read again at every walking screen (no monsters in the list there), an NPC who joins counts
                # (the count from ECL cell 0x6E3E, the party size Fatima's event compares with 8; the record list
                # can run on into a fight's leftovers)
                first = not self.g.party_size
                n = self.g.mem.ecl(0x6E3E)[0]
                if first or not 1 <= n <= 8:
                    self.g.party_size = 0
                    self.g.party_size = len(self.g.party())
                if 1 <= n <= 8 and n != self.g.party_size:
                    self.log("NOTE party size %d -> %d (ECL 0x6E3E)" % (self.g.party_size, n))
                    self.g.party_size = n
                if first:
                    self.start_names = [m[0] for m in self.g.party()]   # Player 11: members lost show in the summary
        if scr["kind"] not in self.seen_kinds:
            self.seen_kinds.add(scr["kind"])
            shot = os.path.join(LOGS, "%s_screen_%s.png" % (self.run, scr["kind"]))
            st["im"].save(shot)
            self.log("NEW SCREEN", scr["kind"], shot)
        self.prev_kind = scr["kind"]
        if os.environ.get("OP_STOPAT") and scr["kind"] in os.environ["OP_STOPAT"].split(","):
            # Player 30: a probe stops at the first screen of a kind (DOSBox left running for k.py)
            raise Stop("OP_STOPAT: screen %s (%s)" % (scr["kind"], st["bottom"]))
        if scr["kind"] == "walking":
            if plans.RELOAD_RULE:
                plans.reload_rule(self)       # Player 32: Jeremy's reload rule (plans.py)
            if plans.BANDS["on"] and self.on_band():
                kw = plans.band_spokesman(self)      # Player 36: the band rule's spokesman, lit before the step
                if kw:
                    self.key(kw[0], kw[1])
                    return True
            else:
                plans.BANDS["lit_tries"] = 0
            return self.walk(st)
        if scr["kind"] == "wiped":
            self.note("loss", "the party was destroyed at %d,%d %s" % self.where())
            raise Stop("the party was destroyed (a loss: reload from the last checkpoint)")
        k, why = self.plan.answer(scr, st, self)
        if k is None and scr["kind"] == "hmenu" and self.tactics.on and getattr(self, "blank_polls", 0) < 10:
            # Player 39 (p39b1, p39b3: the throne room, a hasted member's blow, then a menu no rule took; the AIM was
            # on screen a moment later): an unanswered menu in a tactics fight is polled again (10 times, 0.3 s apart)
            self.blank_polls = getattr(self, "blank_polls", 0) + 1
            self.log("NOTE no rule for the menu %r: polled again (%d)" % (st["bottom"], self.blank_polls))
            time.sleep(0.3)
            return True
        self.blank_polls = 0
        if k is None:
            raise Stop("no rule for screen %s: %s (bottom %r)" % (scr["kind"], scr.get("text", st["bottom"]), st["bottom"]))
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
                self.last_progress = time.monotonic()
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
    # Player 11: the log's times are CLOCK_MONOTONIC seconds since this start (WSL steps the wall clock); a film
    # records its own start on the same clock (lab p11/film.sh) to line its video up with the log exactly.
    p.log("CLOCK monotonic %.3f" % p.t0)
    if after:      # resumed by the watchdog from a checkpoint: its goals and the ones before it are done
        import plans
        names = [g.name for g in plan.goals if isinstance(g, plans.Checkpoint)]
        if after not in names:
            raise SystemExit("no checkpoint %r in the plan" % after)
        while not (isinstance(plan.goals[p.goal], plans.Checkpoint) and plan.goals[p.goal].name == after):
            p.goal += 1
        # Player 17: the `sell` and `buy` visits before the checkpoint are done too (p17a3 sold again at the next shop)
        p.sell_visit, p.buy_visit = getattr(plan.goals[p.goal], "shops", (0, 0))
        p.buy_pending, p.buy_pages, p.buy_dir = None, 0, "n"
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
        "2. Keys sent: %d; fights: %d; time %.0f s." % (p.g.nkeys, p.fights, time.monotonic() - p.t0),
        "3. Party: %s%s." % (", ".join("%s L%s %d/%d" % m for m in party),
                            "; gone since the start: " + ", ".join(n for n in p.start_names
                                                                 if n not in [m[0] for m in party])
                            if party and set(p.start_names) - set(m[0] for m in party) else ""),
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

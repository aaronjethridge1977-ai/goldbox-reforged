"""Player 57: party creation in the original by keys (the training hall's CREATE NEW CHARACTER, ADD, BEGIN).

  create.py <run> <party file> [--seed=<hex>] [--begin]

A fresh DOSBox (orig.py's display and pids), the title, then for each line of the party file:
CREATE NEW CHARACTER, the race, sex, class and alignment picked by name from the lists (End = next, as the
original's lists), KEEP THIS CHARACTER? NO (a reroll) until the line's need is met, YES, the name, the portrait's
KEEP, the icon's EXIT and YES. Then ADD CHARACTER TO PARTY for each, in the file's order, and (--begin) BEGIN
ADVENTURING. Every key is logged with the seed (logs/<run>.log; the rolls of each try in the log too).

The party file, one member a line (`#` comments):
  <NAME> | <race> | <sex> | <class> | <alignment>[, <alignment>...] | <need>
need: `-` (the first roll the game offers), or tests on the shown scores joined by spaces, all to hold:
  STR>=18/01 (exceptional Strength), WIS>=16, INT>=16 ... (the sheet's numbers: the game's own adjustments in)
Alignments: the first one the game's list offers.

The Lead's creation rule (Player 57's post): reroll only until the class's prime need is met; every other score as
rolled. No memory is written (the seed is set once at the start, as every run's).
"""
import os, re, sys, time

import orig
import game
import screens

LAB = orig.LAB


def parse(path):
    out = []
    for ln in open(path):
        ln = ln.split("#", 1)[0].strip()
        if not ln:
            continue
        f = [x.strip() for x in ln.split("|")]
        name, race, sex, cls, al, need = f
        out.append({"name": name.upper(), "race": race.upper(), "sex": sex.upper(), "class": cls.upper(),
                    "align": [a.strip().upper() for a in al.split(",")], "need": need})
    return out


def scores(rows):
    """The sheet's abilities: {'STR': (18, 54), 'INT': (16, 0), ...} from rows 7-12, plus HP and AGE."""
    out = {}
    for r in range(7, 13):
        m = re.match(r"\W*(STR|INT|WIS|DEX|CON|CHA)\s+(\d+)(?:[/(](\d+)\)?)?", rows[r])   # the sheet: STR 18(87)
        if m:
            pc = m.group(3)
            out[m.group(1)] = (int(m.group(2)), 100 if pc == "00" else int(pc or 0))   # 18/00 is the top
    m = re.search(r"HP\s+(\d+)", rows[18])
    out["HP"] = (int(m.group(1)), 0) if m else (0, 0)
    m = re.search(r"AGE\s+(\d+)", rows[3])
    out["AGE"] = (int(m.group(1)), 0) if m else (0, 0)
    return out


def meets(sc, need):
    if need in ("", "-"):
        return True
    for t in need.split():
        m = re.match(r"(STR|INT|WIS|DEX|CON|CHA)>=(\d+)(?:/(\d+))?$", t)
        if not m:
            raise SystemExit("bad need %r" % t)
        v = sc.get(m.group(1), (0, 0))
        want = (int(m.group(2)), int(m.group(3) or 0))
        if v < want:
            return False
    return True


class Creator:
    def __init__(self, run):
        self.run = run
        self.logf = open(os.path.join(LAB, "logs", run + ".log"), "a")
        self.g = None

    def log(self, *a):
        s = "%s %s" % (time.strftime("%H:%M:%S"), " ".join(str(x) for x in a))
        self.logf.write(s + "\n")
        self.logf.flush()
        print(s)

    def st(self):
        st = self.g.settled()
        if st is None:
            raise game.Timeout("no input wanted")
        return st

    def key(self, k, why=""):
        self.g.press(k)
        st = self.st()
        self.log("KEY %s seed %08x | %s | %s" % (k, self.g.mem.seed(), st["bottom"][:60], why))
        return st

    def lit(self, st, r0=1, r1=23):
        """(row, text) of each list line and the white (lit) one."""
        lines, hl = [], None
        for r in range(r0, r1):
            t = st["rows"][r].strip("? \\").strip()
            if not t:
                continue
            lines.append((r, t))
            if screens._rowcol(st["im"], r) == screens.WHITE:
                hl = t
        return lines, hl

    def pick(self, st, wants, what):
        """End until a wanted line is lit, then Enter (the lists step on End; they wrap)."""
        lines, hl = self.lit(st)
        names = [t for _, t in lines]
        want = next((w for w in wants if w in names), None)
        if want is None:
            raise SystemExit("%s: none of %s offered (%s)" % (what, wants, names))
        for _ in range(len(names) + 1):
            if hl == want:
                return self.key("enter", "%s %s" % (what, want))
            st = self.key("end", "%s: to %s" % (what, want))
            _, hl = self.lit(st)
        raise SystemExit("%s: could not light %s" % (what, want))

    def menu(self, st, item):
        """The hall's menu (CHOOSE A FUNCTION): hot keys, each item's white first letter."""
        names = [t for _, t in self.lit(st)[0]]
        if item not in names:
            raise SystemExit("menu: %s not offered (%s)" % (item, names))
        return self.key(item[0].lower(), "menu " + item)

    def create(self, m):
        st = self.menu(self.st(), "CREATE NEW CHARACTER")
        st = self.pick(st, [m["race"]], "race")
        st = self.pick(st, [m["sex"]], "sex")
        st = self.pick(st, [m["class"]], "class")
        st = self.pick(st, m["align"], "alignment")
        tries = 1
        while True:
            if "KEEP THIS CHARACTER" not in st["bottom"]:
                raise SystemExit("not at KEEP THIS CHARACTER: %r" % st["bottom"])
            sc = scores(st["rows"])
            line = " ".join("%s %d%s" % (k, v[0], "/%02d" % (v[1] % 100) if v[1] else "") for k, v in sc.items())
            self.log("ROLL %s try %d: %s" % (m["name"], tries, line))
            if meets(sc, m["need"]):
                break
            st = self.key("n", "reroll (%s)" % m["need"])
            tries += 1
        self.log("KEPT %s after %d tries: %s" % (m["name"], tries, line))
        st = self.key("y", "keep")
        for ch in m["name"]:
            st = self.key("space" if ch == " " else ch.lower(), "name")
        st = self.key("enter", "name done")
        # the portrait page (HEAD BODY KEEP), the icon page (... EXIT), IS THIS ICON OK? YES
        for _ in range(6):
            b = st["bottom"]
            if "CHOOSE A FUNCTION" in b or "CHOOSE A FUNCTION" in " ".join(st["rows"].values()):
                break
            if "KEEP" in b.split() and "HEAD" in b:
                st = self.key("k", "portrait kept")
            elif "YES" in b.split() and "ICON" in b:
                st = self.key("y", "icon ok")
            elif "EXIT" in b.split():
                st = self.key("e", "icon page")
            else:
                raise SystemExit("after the name: %r" % b)
        return tries

    def add(self, names):
        for n in names:
            st = self.menu(self.st(), "ADD CHARACTER TO PARTY")
            st = self.pick(st, [n], "add")
            self.log("ADDED %s | %s" % (n, st["bottom"]))
            if "EXIT" in st["bottom"].split() and "CHOOSE A FUNCTION" not in st["bottom"]:
                st = self.key("e", "back to the menu")


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    opts = dict(x[2:].split("=", 1) if "=" in x else (x[2:], "1") for x in sys.argv[1:] if x.startswith("--"))
    run, pf = a[0], a[1]
    party = parse(pf)
    c = Creator(run)
    c.log("CREATE run %s party %s (%s)" % (run, pf, ", ".join(m["name"] for m in party)))
    if "attach" not in opts:
        orig.start()
        t = time.monotonic()
        while True:
            try:
                mem = orig.Mem()
                break
            except (RuntimeError, SystemExit):
                if time.monotonic() - t > 30:
                    raise
                time.sleep(0.05)
        import hooks
        hooks.install(mem)
    c.g = game.Game(log=c.log)
    st = c.st()
    if screens.classify(st)["kind"] == "title":
        if "seed" in opts:
            c.g.mem.set_seed(int(opts["seed"], 16))
            c.log("SEED set %s at the title" % opts["seed"])
        st = c.key("enter", "title")
    elif "seed" in opts:
        c.g.mem.set_seed(int(opts["seed"], 16))
        c.log("SEED set %s" % opts["seed"])
    total = 0
    for m in party:
        if m.get("skip"):
            continue
        total += c.create(m)
    c.add([m["name"] for m in party])
    if "begin" in opts:
        c.key("b", "BEGIN ADVENTURING")
    c.log("END created %d, %d rolls in all" % (len(party), total))


if __name__ == "__main__":
    main()

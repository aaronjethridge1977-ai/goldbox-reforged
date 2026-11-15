"""Area plans for the Player (the pilot's own small format; the dialogue answers come from main's plan files).

  area 1:18                      the area this plan plays (GEO<set>.DAX block <block> is its map)
  rules ../../tools/plans/playthrough.plan
                                 main's plan: its `answer <area> <words>|<choice>` lines for this area are used
  walk 5,8                       walk there (route on the map, from the square read in memory), round every event
  walk 12,9 through 9,11         the same, but the route may cross squares with those event numbers
  step W                         face W and step (into an event square)
  checkpoint <name>              ENCAMP, SAVE to the run's slot, index line, copy to .lab/player/saves
  exit 7:26                      walk is over when the party is in that area
  answer <words>|<choice>        this plan's own answers (before main's): the first screen whose text holds
                                 <words> gets <choice> (an item's name, or a member's name)
  default <kind> <key>           what to press on a kind of screen (screens.py) with no answer
"""
import os, re, sys
import orig

sys.path.insert(0, orig.LAB)
import route as R   # noqa: E402  (the lab's map reader)

DX = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}


class Walk:
    def __init__(self, x, y, area, through=()):
        self.x, self.y, self.area = x, y, area
        self.through = set(through)     # event numbers the route may cross (Player 2: Podol Plaza's 9s and 11s)

    def __repr__(self):
        return "walk %d,%d" % (self.x, self.y)

    def next(self, p):
        x, y, f = p.where()
        if (x, y) == (self.x, self.y):
            return True, None, ""
        a = p.area()
        if a != self.area:
            raise_stop(p, "walk: in area %d:%d, not %d:%d" % (a + self.area))
        R.NE, R.SW, R.INFO, R.DOORS = R.load(*self.area)
        avoid = set(range(1, 128)) - {R.event(x, y), R.event(self.x, self.y)} - self.through
        path = R.route((x, y), {(self.x, self.y)}, avoid)
        if path is None:
            raise_stop(p, "walk: no route from %d,%d to %d,%d" % (x, y, self.x, self.y))
        nx, ny = path[1]
        want = {(0, -1): "N", (1, 0): "E", (0, 1): "S", (-1, 0): "W"}[(nx - x, ny - y)]
        return False, turn(f, want), "walk to %d,%d via %d,%d" % (self.x, self.y, nx, ny)


def turn(f, want):
    d = ("NESW".index(want) - "NESW".index(f)) % 4
    return {0: "up", 1: "right", 2: "right", 3: "left"}[d]


class Step:
    def __init__(self, d):
        self.d = d
        self.start = None
        self.sent = None

    def __repr__(self):
        return "step %s" % self.d

    def next(self, p):
        """Done once the party has moved, or once an event has taken keys after the step (an event can put
        the party back where it stood: the tavern's LEAVE)."""
        x, y, f = p.where()
        a = p.area()
        if self.start is None:
            self.start = (x, y)
            self.area = a
        # Player 2: out of an area onto a wilderness band the 3D square (DS:0x6AAD) stays put: the area tells.
        if (x, y) != self.start or a != self.area:
            return True, None, ""
        if self.sent is not None and p.g.nkeys > self.sent:
            return True, None, ""
        k = turn(f, self.d)
        if k == "up":
            self.sent = p.g.nkeys + 1
        return False, k, "step %s from %d,%d" % (self.d, x, y)


class Exit:
    def __init__(self, area):
        self.area = area

    def __repr__(self):
        return "exit to %d:%d" % self.area

    def next(self, p):
        if p.area() == self.area:
            return True, None, ""
        raise_stop(p, "exit: still in %d:%d at the walking screen" % p.area())


class Checkpoint:
    def __init__(self, name):
        self.name = name
        self.done = False

    def __repr__(self):
        return "checkpoint %s" % self.name

    def next(self, p):
        if self.done:
            return True, None, ""
        if p.saving is None:
            p.saving = self
            return False, "e", "checkpoint %s: ENCAMP" % self.name
        return False, None, ""


def raise_stop(p, why):
    # player.py runs as __main__: its Stop is __main__.Stop, not player.Stop (Player 2: a plan's stop escaped as
    # a traceback with no summary).
    m = sys.modules.get("__main__")
    if not hasattr(m, "Stop"):
        import player as m
    raise m.Stop(why)


def area_of(s):
    a, b = s.split(":")
    return int(a), int(b)


class Plan:
    def __init__(self):
        self.area = None
        self.goals = []
        self.answers = []        # (words, choice, source)
        self.defaults = {"enter": "enter", "combat": "q", "encounter": "c", "continue": "n",
                         "treasure": "e"}

    def answer(self, scr, st, p):
        kind = scr["kind"]
        if kind == "camp" or kind == "saveslot":
            return p.save_step(scr)
        if kind == "treasure":
            if not p.shared and "SHARE" in scr["bottom"].split():
                p.shared = True
                return "s", "treasure: SHARE the coins"
            return "e", "treasure: EXIT (items left: the pilot takes coins only)"
        if kind != "treasure" and kind != "yesno":
            p.shared = False
        if kind == "yesno" and "CLAIM YOUR TREASURE" in scr["text"] + scr["bottom"]:
            return "n", "treasure left: don't go back (pilot)"
        if kind == "yesno" and "QUIT TO DOS" in scr["bottom"]:
            return "n", "never quit to DOS (asked after SAVE)"
        text = scr.get("text", "") + " " + scr.get("question", "") + " " + scr["bottom"]
        for words, choice, src in self.answers:
            if words in text:
                k = self.choose(scr, choice)
                if k:
                    return k, "%s: %s|%s" % (src, words, choice)
        if kind in self.defaults:
            return self.defaults[kind], "default for %s" % kind
        return None, ""

    def choose(self, scr, choice):
        kind = scr["kind"]
        if kind == "vmenu":
            if choice not in scr["items"] or scr["highlight"] is None:
                return None
            d = scr["items"].index(choice) - scr["highlight"]
            # the original's vertical menus: End = next item, Home = previous (lab; the arrows do nothing)
            return "enter" if d == 0 else ("end" if d > 0 else "home")
        if kind == "member":
            if choice not in scr["names"] or scr["highlight"] is None:
                return None
            d = scr["names"].index(choice) - scr["highlight"]
            return "s" if d == 0 else ("end" if d > 0 else "home")
        if kind in ("hmenu", "encounter", "yesno", "treasure", "continue"):
            if choice in scr["bottom"].split():
                return choice[0].lower()
            return None
        return None


def load(path):
    pl = Plan()
    base = os.path.dirname(os.path.abspath(path))
    main_rules = []
    for line in open(path):
        line = line.split("#")[0].strip() if not line.lstrip().startswith("answer") else re.split(r"\s#", line)[0].strip()
        if not line or line.startswith("#"):
            continue
        w = line.split(None, 1)
        cmd, rest = w[0], (w[1] if len(w) > 1 else "")
        if cmd == "area":
            pl.area = area_of(rest)
        elif cmd == "rules":
            main_rules.append(os.path.normpath(os.path.join(base, rest)))
        elif cmd == "walk":
            w = rest.split()
            x, y = (int(v) for v in w[0].split(","))
            through = [int(v) for v in w[2].split(",")] if len(w) > 2 and w[1] == "through" else []
            pl.goals.append(Walk(x, y, pl.area, through))
        elif cmd == "step":
            pl.goals.append(Step(rest.strip().upper()))
        elif cmd == "checkpoint":
            pl.goals.append(Checkpoint(rest.strip()))
        elif cmd == "exit":
            pl.goals.append(Exit(area_of(rest)))
        elif cmd == "answer":
            words, choice = rest.rsplit("|", 1)
            pl.answers.append((words.strip(), choice.strip(), os.path.basename(path)))
        elif cmd == "default":
            k, key = rest.split()
            pl.defaults[k] = key
        else:
            raise SystemExit("plan: unknown line %r" % line)
    for mr in main_rules:
        for line in open(mr):
            w = line.strip().split(None, 2)
            if len(w) == 3 and w[0] == "answer" and area_of(w[1]) == pl.area and "[" not in w[2][:1]:
                words, choice = w[2].rsplit("|", 1)
                pl.answers.append((words.strip(), choice.strip(), os.path.basename(mr)))
    return pl

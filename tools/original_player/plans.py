"""Area plans for the Player (the pilot's own small format; the dialogue answers come from main's plan files).

  area 1:18                      the area this plan plays (GEO<set>.DAX block <block> is its map)
  rules ../../tools/plans/playthrough.plan
                                 main's plan: its `answer <area> <words>|<choice>` lines for this area are used
  walk 5,8                       walk there (route on the map, from the square read in memory), round every event
  walk 12,9 through 9,11         the same, but the route may cross squares with those event numbers
  step W                         face W and step (into an event square)
  checkpoint <name>              ENCAMP, SAVE to the run's slot, index line, copy to .lab/player/saves
  exit 7:26                      walk is over when the party is in that area
  answer <words>|snap:<name>:<key>  (Player 2) the screen's picture and rows to logs/<run>_snap_<name>.*, once, then <key>
  answer <words>|seq:<name>:<k1>,<k2>,...
                                 (Player 3) once: the keys in turn, one a wait, whatever the screen, each screen's
                                 picture and rows snapped first (logs/<run>_snap_<name>_<i>.*); a key "@NAME" presses
                                 End/Home until the party menu or member list has that member lit
  keys <name> <k1>,<k2>,...     (Player 3) at the walking screen: these keys in turn whatever the screens
  alias 3:11                     (Player 3) the walks' area may also be this one (an ECL block on the same map:
                                 New Phlan's training halls)
  answer <words>|<choice>        this plan's own answers (before main's): the first screen whose text holds
                                 <words> gets <choice> (an item's name, or a member's name)
  default <kind> <key>           what to press on a kind of screen (screens.py) with no answer
"""
import os, re, sys
import orig
import loot, screens

sys.path.insert(0, orig.LAB)
import route as R   # noqa: E402  (the lab's map reader)

DX = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}


class Walk:
    def __init__(self, x, y, area, through=()):
        self.x, self.y, self.area = x, y, area
        self.through = set(through)     # event numbers the route may cross (Player 2: Podol Plaza's 9s and 11s)
        self.aliases = set()            # Player 3: other ECL blocks on this map (plan line `alias`)

    def __repr__(self):
        return "walk %d,%d" % (self.x, self.y)

    def next(self, p):
        x, y, f = p.where()
        if (x, y) == (self.x, self.y):
            return True, None, ""
        a = p.area()
        if a != self.area and a not in self.aliases:
            raise_stop(p, "walk: in area %d:%d, not %d:%d" % (a + self.area))
        if p.on_band():
            return self.band_step(p, x, y)
        R.NE, R.SW, R.INFO, R.DOORS = R.load(*self.area)
        avoid = set(range(1, 128)) - {R.event(x, y), R.event(self.x, self.y)} - self.through
        path = R.route((x, y), {(self.x, self.y)}, avoid)
        if path is None:
            raise_stop(p, "walk: no route from %d,%d to %d,%d" % (x, y, self.x, self.y))
        nx, ny = path[1]
        want = {(0, -1): "N", (1, 0): "E", (0, 1): "S", (-1, 0): "W"}[(nx - x, ny - y)]
        return False, turn(f, want), "walk to %d,%d via %d,%d" % (self.x, self.y, nx, ny)


    def band_step(self, p, x, y):
        """Player 10: on a wilderness band each arrow moves the party that way (no turning), and the original
        refuses squares it can't enter (water, a ridge) by leaving the party where it stands. No map of the band
        in the tools yet: the longer axis first, the other when a step was refused; stop when both are."""
        if getattr(self, "_last", None) == (x, y):
            self._refused.add(self._dir)
        else:
            self._refused = set()
        dx, dy = self.x - x, self.y - y
        order = [("E" if dx > 0 else "W", abs(dx)), ("S" if dy > 0 else "N", abs(dy))]
        order.sort(key=lambda t: -t[1])
        for d, n in order:
            if n and d not in self._refused:
                self._last, self._dir = (x, y), d
                return False, band_key(d), "band walk to %d,%d: %s from %d,%d" % (self.x, self.y, d, x, y)
        raise_stop(p, "band walk: stuck at %d,%d on the way to %d,%d (refused %s)" % (
            x, y, self.x, self.y, "".join(sorted(self._refused))))


def band_key(want):
    return {"N": "up", "E": "right", "S": "down", "W": "left"}[want]


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
        k = band_key(self.d) if p.on_band() else turn(f, self.d)
        if k == "up" or p.on_band():
            self.sent = p.g.nkeys + 1
        return False, k, "step %s from %d,%d" % (self.d, x, y)


class Keys:
    """Player 3: `keys <name> <k1>,<k2>,...` on the walking screen: the keys in turn whatever the screens (a seq, as the
    answer `seq:`), e.g. ENCAMP and REST until something interrupts."""
    def __init__(self, name, keys):
        self.name, self.keys, self.started = name, keys, False

    def __repr__(self):
        return "keys %s" % self.name

    def next(self, p):
        if self.started:
            return True, None, ""
        self.started = True
        p.seq, p.seq_n = (self.name, list(self.keys)), 0
        k = p.seq[1].pop(0)
        p.seq_n = 1
        return False, k, "keys %s: key 1" % self.name


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
        self.aliases = set()     # Player 3: `alias` areas
        self.defaults = {"enter": "enter", "combat": "q", "encounter": "c", "continue": "n",
                         "treasure": "e"}

    def _snap(self, p, st, name):
        base = os.path.join(orig.LAB, "logs", "%s_snap_%s" % (p.run, name))
        st["im"].save(base + ".png")
        open(base + ".txt", "w").write("\n".join("%2d %s" % (r, st["rows"][r]) for r in range(25)) + "\n")
        p.note("snap", "%s: %s.png/.txt" % (name, base))

    def _seq(self, scr, st, p):
        """Player 3: the next key of a running seq: answer (or None when it is over)."""
        name, keys = p.seq
        while keys:
            k = keys[0]
            if k.startswith("@"):
                names, hl = scr.get("names"), scr.get("highlight")
                if not names or hl is None or k[1:] not in names:
                    raise_stop(p, "seq %s: no member list with %s on screen %s" % (name, k[1:], scr["kind"]))
                d = names.index(k[1:]) - hl
                if d == 0:
                    keys.pop(0)
                    continue
                return ("end" if d > 0 else "home"), "seq %s: to %s" % (name, k[1:])
            p.seq_n += 1
            self._snap(p, st, "%s_%02d" % (name, p.seq_n))
            keys.pop(0)
            return k, "seq %s: key %d" % (name, p.seq_n)
        p.seq = None
        return None, ""

    def answer(self, scr, st, p):
        kind = scr["kind"]
        if getattr(p, "seq", None):
            k, why = self._seq(scr, st, p)
            if k:
                return k, why
        if kind == "camp" or kind == "saveslot":
            return p.save_step(scr)
        taking = self.defaults.get("treasure") == "take"
        if taking and kind == "hmenu" and scr["bottom"].split()[0] in ("TAKE:", "ITEMS:"):
            return self._take(scr, st, p)
        if kind == "treasure":
            if self.defaults.get("treasure") == "stop":     # Player 4: lab probes (`default treasure stop`)
                raise_stop(p, "treasure: stop asked by the plan")
            if not p.shared and "SHARE" in scr["bottom"].split():
                p.shared = True
                return "s", "treasure: SHARE the coins"
            pk = taking and "TAKE" in scr["bottom"].split() and not p.take.get("done") and self._pick(p)
            if pk:
                # Player 10 (lab): End / Home here select the next / previous member (DS:0x5D92) too; with no
                # coins left T goes straight to the ITEMS list (no TAKE: MONEY ITEMS EXIT menu).
                sel = loot.selected(p.g.mem)
                if sel != pk[1]:
                    return ("end" if sel is None or pk[1] > sel else "home"), "treasure: select member %d" % (pk[1] + 1)
                return "t", "treasure: TAKE (%s for member %d)" % (pk[2]["name"], pk[1] + 1)
            p.take = {}
            return "e", "treasure: EXIT" + ("" if taking else " (items left: the pilot takes coins only)")
        if kind != "treasure" and kind != "yesno":
            p.shared = False
        if kind == "yesno" and "CLAIM YOUR TREASURE" in scr["text"] + scr["bottom"]:
            return "n", "treasure left: don't go back (pilot)"
        if kind == "yesno" and "QUIT TO DOS" in scr["bottom"]:
            return "n", "never quit to DOS (asked after SAVE)"
        text = scr.get("text", "") + " " + scr.get("question", "") + " " + scr["bottom"]
        for words, choice, src in self.answers:
            if words in text and choice.startswith("seq:"):
                _, name, keys = choice.split(":", 2)
                if name in p.snapped:
                    continue
                p.snapped.add(name)
                p.seq, p.seq_n = (name, keys.split(",")), 0
                k, why = self._seq(scr, st, p)
                if k:
                    return k, "%s: %s" % (src, why)
                continue
            if words in text and choice.startswith("snap:"):
                # Player 2: snap:<name>:<key>: the screen's picture and its 25 rows to logs/<run>_snap_<name>.*,
                # once, then the key (any key name; the services sweep reads shops, temples and halls this way).
                _, name, key = choice.split(":", 2)
                if name in p.snapped:
                    continue
                p.snapped.add(name)
                base = os.path.join(orig.LAB, "logs", "%s_snap_%s" % (p.run, name))
                st["im"].save(base + ".png")
                open(base + ".txt", "w").write("\n".join("%2d %s" % (r, st["rows"][r]) for r in range(25)) + "\n")
                p.note("snap", "%s: %s.png/.txt" % (name, base))
                return key, "%s: %s|%s" % (src, words, choice)
            if words in text:
                k = self.choose(scr, choice)
                if k:
                    return k, "%s: %s|%s" % (src, words, choice)
        if kind in self.defaults:
            return self.defaults[kind], "default for %s" % kind
        return None, ""

    # -- Player 10: TAKE (`default treasure take`; loot.py) ------------------------------------------------
    def _pick(self, p):
        """(loot index, member index, item) of the first item worth taking (main's bot's rule), handed round the
        party in turn from p.take["turn"], skipping members with 16 items, at 0 HP, or already refused it."""
        t = p.take
        L, P = loot.loot(p.g.mem), loot.party(p.g.mem)
        for i, it in enumerate(L):
            if not loot.worth_taking(it):
                continue
            sig = (it["name"], it["type"], it["plus"], it["price"], it["weight"])
            for k in range(len(P)):
                j = (t.get("turn", 0) + k) % len(P)
                if P[j][2] < loot.LIMIT and P[j][3] > 0 and (sig, j) not in t.setdefault("refused", set()):
                    return i, j, it, sig
        return None

    def _take(self, scr, st, p):
        t, mem = p.take, p.g.mem
        menu = scr["bottom"].split()[0]
        if menu == "ITEMS:" and t.get("pending"):
            n, sig, j = t.pop("pending")
            if len(loot.loot(mem)) == n:
                t.setdefault("refused", set()).add((sig, j))
                p.note("take", "refused: %s to member %d (full or overloaded)" % (sig[0], j + 1))
            else:
                t["turn"] = j + 1
                p.note("take", "%s took %s (+%d, %d gp, weight %d)" % (
                    loot.party(mem)[j][1], sig[0], sig[2], sig[3], sig[4]))
        pk = self._pick(p)
        sel = loot.selected(mem)
        if pk is None:
            t["done"] = True
            return "e", "take: nothing more worth taking"
        i, j, it, sig = pk
        if menu == "TAKE:":
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "take: select member %d for %s" % (j + 1, it["name"])
            return "i", "take: ITEMS (%s for member %d)" % (it["name"], j + 1)
        if sel != j:
            return "e", "take: back to select member %d" % (j + 1)
        n = len(loot.loot(mem))
        if n > 18:
            raise_stop(p, "take: a loot list of %d items (longer than the screen: scrolling not yet seen)" % n)
        lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
        if len(lit) != 1:
            raise_stop(p, "take: no single lit item on the ITEMS list (rows %s)" % lit)
        hl = lit[0] - 4
        if hl == i:
            t["pending"] = (n, sig, j)
            return "t", "take: %s (%d gp, weight %d) for member %d" % (it["name"], it["price"], it["weight"], j + 1)
        return ("end" if i > hl else "home"), "take: light to %s (row %d)" % (it["name"], i + 4)

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
        elif cmd == "alias":
            pl.aliases.add(area_of(rest))
        elif cmd == "rules":
            main_rules.append(os.path.normpath(os.path.join(base, rest)))
        elif cmd == "walk":
            w = rest.split()
            x, y = (int(v) for v in w[0].split(","))
            through = [int(v) for v in w[2].split(",")] if len(w) > 2 and w[1] == "through" else []
            pl.goals.append(Walk(x, y, pl.area, through))
            pl.goals[-1].aliases = pl.aliases
        elif cmd == "step":
            pl.goals.append(Step(rest.strip().upper()))
        elif cmd == "checkpoint":
            pl.goals.append(Checkpoint(rest.strip()))
        elif cmd == "keys":
            name, ks = rest.split(None, 1)
            pl.goals.append(Keys(name, ks.replace(" ", "").split(",")))
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

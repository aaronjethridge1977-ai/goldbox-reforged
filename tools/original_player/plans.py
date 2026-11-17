"""Area plans for the Player (the pilot's own small format; the dialogue answers come from main's plan files).

  area 1:18                      the area this plan plays (GEO<set>.DAX block <block> is its map)
  rules ../../tools/plans/playthrough.plan
                                 main's plan: its `answer <area> <words>|<choice>` lines for this area are used
  walk 5,8                       walk there (route on the map, from the square read in memory), round every event
  walk 12,9 through 9,11         the same, but the route may cross squares with those event numbers
  walk 12,9 avoid 9,12,16        (Player 13) the route crosses every event square but those (main's bot's tour in
                                 `explore 9 12 16`: main.gd _find_path walks round only the plan's left-out events)
  step W                         face W and step (into an event square)
  checkpoint <name>              ENCAMP, SAVE to the run's slot, index line, copy to .lab/player/saves
  exit 7:26                      walk is over when the party is in that area
  answer <words>|type:<WORD>      (Player 13) once: the word's letters, then Enter (a script's typed answer)
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
  memorize <NAME> <spell>, <spell> | <NAME> ...
                                 (Player 12) the next camp's (the inn's) MAGIC MEMORIZE per member, then REST for the
                                 time the original offers, then EXIT the camp (main's bot at the inn)
  readyall                       (Player 12) main's bot's readying after a shop: every member's items READY (VIEW, ITEMS)
  heal                           (Player 13) main's bot's heal in a camp area (bot.gd _heal_if_low / _heal): if a
                                 member is below half HP or not OKAY: camp, Cure Light Wounds on the most hurt,
                                 MEMORIZE the bot's picks, REST, in rounds; then day rests until no one is hurt
  inntrip ... inntrip end         (Player 14) goals kept aside (walk, step, area, innheal lines) for main's bot's trip to
                                 the inn when a heal's rest is interrupted (bot.gd _rest_at_inn); inserted after the
                                 heal once per interruption, not while on the trip
  innheal                        (Player 14) inside `inntrip`: the heal in the inn's camp (TO REST HERE, the payer,
                                 then the camp opens before the walk sees the inn's square)
  answer <words>|@platinum       (Player 14) on a member list: the member with most platinum (main's bot pays the inn so)
  Walks also (Player 14, main.gd _tour and bot.gd): a step the square's script turns back is refused and walked round
  (a walk to an event that turned the party back is done); a fight on a walk that leaves the party hurt (bot.gd
  _hurt) is followed by a heal of anyone hurt before the walk goes on.
  default <kind> <key>           what to press on a kind of screen (screens.py) with no answer
  buy <m> <item> | <m> <item> ...
                                 (Player 12) the next shop visit's purchases, main's `shop` list without the door:
                                 member <m> (0 = the first) buys the item whose name on the list starts so (End /
                                 Home on BUY VIEW POOL select the buyer, DS:0x5D92; on the list they move the light,
                                 NEXT / PREV page); POOL before each purchase (main's bot does); EXIT when the visit's
                                 list is done. Each `buy` line is one visit.
"""
import copy, os, re, sys
import orig
import loot, screens

sys.path.insert(0, orig.LAB)
import route as R   # noqa: E402  (the lab's map reader)

DX = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}


class Walk:
    def __init__(self, x, y, area, through=(), avoid=None):
        self.x, self.y, self.area = x, y, area
        self.avoid = avoid              # Player 13: `walk x,y avoid 9,12,16`: cross every event but these
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
        # Player 14: main's bot's two rules for a walk interrupted on the way (main.gd _tour, bot.gd _auto_handle):
        # a fight that leaves the party hurt (bot.gd _hurt) stops the walk for a heal (_prepare: camp areas heal);
        # a step the square's script turns back (the party on the same square, facing elsewhere: p13b6's event 3
        # door at 13,10 after the commission) is refused for the rest of the run and walked round (_refused).
        refused = REFUSED.setdefault(tuple(self.area), set())
        t, self._tried = getattr(self, "_tried", None), None
        if t is not None and t[:2] == (x, y) and f != t[2] and (x, y, t[2]) not in refused:
            refused.add((x, y, t[2]))
            p.note("walk", "the step %s from %d,%d was turned back: refused, walked round" % (t[2], x, y))
        f0 = getattr(self, "_fights0", None)
        if f0 is None:
            self._fights0 = p.fights
        elif p.fights > f0:
            self._fights0 = p.fights
            if hurt(members(p.g.mem)):
                p.note("walk", "fight %d left the party hurt (%s): heal before going on (bot.gd _hurt, _prepare)" % (
                    p.fights, party_hp(p.g.mem)))
                p.plan.goals.insert(p.goal, Heal(force=True))
                p.goal_key = p.g.nkeys      # the stall guard counts from the heal's start (p14b1: TAKE + heal > 300)
                return False, None, ""
        if self.avoid is not None:      # Player 13: the bot's tour (main.gd _find_path): only these are walked round
            avoid = set(self.avoid) - {R.event(x, y), R.event(self.x, self.y)}
        else:
            avoid = set(range(1, 128)) - {R.event(x, y), R.event(self.x, self.y)} - self.through
        path = route_refusing((x, y), (self.x, self.y), avoid, refused)
        ev = R.event(self.x, self.y)
        if path is None and ev and any(R.event(rx + DX[d][0], ry + DX[d][1]) == ev for rx, ry, d in refused):
            # main.gd _tour: "no route" ends the tour; the bot's explore counts the event as visited (p13b6: event
            # 3's 13,10 runs the commission, then turns the party back; its 11,9 is behind it).
            p.note("walk", "no way on to %d,%d: event %d turned the party back, done as main's bot's tour" % (
                self.x, self.y, ev))
            return True, None, ""
        if path is None:
            raise_stop(p, "walk: no route from %d,%d to %d,%d" % (x, y, self.x, self.y))
        nx, ny = path[1]
        want = {(0, -1): "N", (1, 0): "E", (0, 1): "S", (-1, 0): "W"}[(nx - x, ny - y)]
        k = turn(f, want)
        if k == "up":
            self._tried = (x, y, want)
        return False, k, "walk to %d,%d via %d,%d" % (self.x, self.y, nx, ny)


REFUSED = {}    # Player 14: area -> {(x, y, dir)} steps a square's script turned back (main.gd _tour's _refused)


def route_refusing(start, goal, avoid, refused):
    """The lab's route.py BFS, with the refused steps left out."""
    from collections import deque
    q, prev = deque([start]), {start: None}
    while q:
        c = q.popleft()
        if c == goal:
            path = []
            while c:
                path.append(c)
                c = prev[c]
            return path[::-1]
        for s in range(4):
            if R.passable(c[0], c[1], s) and (c[0], c[1], "NESW"[s]) not in refused:
                n = (c[0] + R.DX[s], c[1] + R.DY[s])
                if n in prev or (n != goal and R.event(*n) in avoid):
                    continue
                prev[n] = c
                q.append(n)
    return None


def hurt(M):
    """bot.gd _hurt: a member unconscious or dying, or the standing members under 60% of their HP."""
    if any(m["status"] in (4, 5) for m in M):
        return True
    ok = [m for m in M if m["status"] == 0]
    return sum(m["hp"] for m in ok) * 5 < sum(m["max"] for m in ok) * 3


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


class ReadyAll:
    """Player 12: `readyall` on the walking screen: main's bot's _ready_all after a shop: each member in turn (End /
    Home select, DS:0x5D92), VIEW, ITEMS, READY every item showing NO (one try each; the original's refusals stay
    NO), EXIT twice. The item screens are answered in Plan.answer (p.readying)."""
    def __init__(self):
        self.j = 0

    def __repr__(self):
        return "readyall"

    def next(self, p):
        P = loot.party(p.g.mem)
        if getattr(p, "readying", None) is not None:
            if not p.ready_over:
                raise_stop(p, "readyall: back on the walking screen with member %d not done" % (self.j + 1))
            p.readying = None
            self.j += 1
        if self.j >= len(P):
            return True, None, ""
        sel = loot.selected(p.g.mem)
        if sel != self.j:
            return False, ("end" if sel is None or self.j > sel else "home"), "readyall: select %s" % P[self.j][1]
        p.readying, p.ready_tried, p.ready_over = self.j, set(), False
        return False, "v", "readyall: VIEW %s" % P[self.j][1]


class Heal:
    """Player 13: `heal` on the walking screen: main's bot's `_heal_if_low` and `_heal` (scripts/dev/bot.gd) for an
    area whose rest rule is camp. Nothing unless a member isn't OKAY or is below half HP. Then in camp: every
    memorized Cure Light Wounds cast on the most hurt (by 4 HP or more; MAGIC, CAST, the member list), the free slots
    filled with the bot's picks (MEMORIZE) and a REST for the time the original offers, round after round while the
    cures heal; then rests of min(most HP missing, 10) days until no one is hurt (REST: DAYS is Y, INC / DEC).
    An interrupted rest is fought out (the bot walks to the inn there; noted) and the heal goes on.
    The camp screens are answered in Plan._heal (p.heal holds the state)."""
    def __init__(self, force=False, inn=False):
        self.force = force      # Player 14: after a fight on a walk (bot.gd _prepare): heal anyone hurt
        self.inn = inn          # Player 14: `innheal` in an `inntrip` block: the heal in the inn's camp

    def __repr__(self):
        return "heal" + (" at the inn" if self.inn else " (after a fight)" if self.force else "")

    def next(self, p):
        h = getattr(p, "heal", None)
        if h is not None:
            if h["done"]:
                p.heal = None
                p.note("heal", "healed: %s (%d cures, %d rests, %d day rests, %d interrupted)" % (
                    party_hp(p.g.mem), h["cures"], h["rests"], h["days"], h["interrupts"]))
                return True, None, ""
            if h.get("op") and h["op"][0] == "rest" and p.fights > h["fights0"]:
                h["interrupts"] += 1
                h["op"] = None
                p.note("heal", "rest interrupted by fight %d (main's bot would walk to the inn; the Player camps"
                               " again)" % p.fights)
                if p.plan.inntrip and not getattr(p, "on_trip", False) and not self.inn:
                    # Player 14: bot.gd _heal: "an interrupted rest: a player gives up camping among the monsters
                    # and walks to the inn" (_rest_at_inn: travel to town, the inn, travel back). The plan's
                    # `inntrip` block is that trip for this area; the bot's tour back to the square is left out
                    # (the plan's next walk routes from where the trip comes back in).
                    p.heal, p.on_trip = None, True
                    p.note("heal", "rest interrupted by fight %d: the inn trip (bot.gd _rest_at_inn)" % p.fights)
                    p.plan.goals[p.goal + 1:p.goal + 1] = copy.deepcopy(p.plan.inntrip)
                    p.goal_key = p.g.nkeys
                    return True, None, ""
                if h["interrupts"] > 4:
                    raise_stop(p, "heal: rest interrupted %d times" % h["interrupts"])
                if h["phase"] == "rounds":
                    h["phase"], h["memo_any"], h["days_memo"] = "days", False, False
            return False, "e", "heal: ENCAMP"
        M = members(p.g.mem)
        if any(m["status"] == 6 or m["status"] > 6 for m in M):
            raise_stop(p, "heal: a member is dead (a loss under the death rule: reload from the last checkpoint)")
        if not (needs_rest(M) if self.force else any(m["status"] != 0 or m["hp"] * 2 < m["max"] for m in M)):
            return True, None, ""
        new_heal(p)
        return False, "e", "heal: ENCAMP"


def new_heal(p):
    p.heal = {"done": False, "phase": "rounds", "round": 0, "cured": 0, "memo_any": False, "op": None,
              "cures": 0, "rests": 0, "days": 0, "interrupts": 0, "fights0": p.fights, "days_memo": False,
              "field": None}
    p.note("heal", "low: %s" % party_hp(p.g.mem))


class TripEnd:
    """Player 14: the end of an inserted `inntrip` block."""
    def __repr__(self):
        return "inn trip over"

    def next(self, p):
        p.on_trip = False
        p.goal_key = p.g.nkeys
        return True, None, ""


# Player 13: spell ids (the record's memorized bytes 0x17-0x2B, + 0x80 while being memorized) by class and level
# (ours' SpellTable): cleric level 1 is 1-8, magic-user level 1 9-21. The bot's picks (bot.gd PICKS): level 1
# clerics Cure Light Wounds, Cure Light Wounds, Bless in turn; magic-users Sleep, Magic Missile.
CLERIC1, MU1 = range(1, 9), range(9, 22)
SPELL_NAMES = {1: "BLESS", 3: "CURE LIGHT WOUNDS", 15: "MAGIC MISSILE", 21: "SLEEP"}
PICKS1 = ((CLERIC1, 0xB2, (3, 3, 1)), (MU1, 0xB5, (21, 15)))
CLW = 3


def members(mem):
    out = []
    for i, ((s, o), name, n, hp) in enumerate(loot.party(mem)):
        r = mem.far(s, o, 0x120)
        out.append({"i": i, "name": name, "hp": r[0x11B], "max": r[0x32], "status": r[0x10C],
                    "mem": [b for b in r[0x17:0x2C] if b], "rec": r})
    return out


def party_hp(mem):
    return " ".join("%s %d/%d%s" % (m["name"], m["hp"], m["max"], "" if m["status"] == 0 else " s%d" % m["status"])
                    for m in members(mem))


def needs_rest(M):
    return any(m["status"] in (0, 4, 5) and m["hp"] < m["max"] for m in M)


def next_cure(M):
    """bot.gd _cure_in_camp: the first OKAY caster with a memorized Cure Light Wounds, on the most hurt (OKAY,
    unconscious or dying, 4 HP or more missing; the first of equals). None when no cure is due."""
    for c in M:
        if c["status"] != 0 or CLW not in c["mem"]:
            continue
        worst = None
        for m in M:
            if m["status"] in (0, 4, 5) and m["max"] - m["hp"] >= 4 and (
                    worst is None or m["max"] - m["hp"] > worst["max"] - worst["hp"]):
                worst = m
        return (c, worst) if worst else None
    return None


def picks(m):
    """bot.gd _pick_spells for level 1: the spells to queue in the member's free level-1 slots (names)."""
    if m["status"] != 0:
        return []
    out = []
    for ids, slot, order in PICKS1:
        used = sum(1 for b in m["mem"] if (b & 0x7F) in ids)
        known = [s for s in order if m["rec"][0x33 + s - 1]]     # the spell book: a byte per spell id
        if not known:
            continue
        for k in range(max(0, m["rec"][slot] - used)):
            out.append(SPELL_NAMES[known[k % len(known)]])
    return out


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
        self.buys = []           # Player 12: one list of (member, name) per shop visit
        self.memos = []          # Player 12: one list of (member, [spell names]) per camp (the inn's) visit
        self.inntrip = []        # Player 14: the `inntrip` block's goals (an interrupted rest's trip to the inn)
        self.mem = None          # Player 14: the game's memory, for `@platinum` answers
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
        self.mem = p.g.mem
        if getattr(p, "seq", None):
            k, why = self._seq(scr, st, p)
            if k:
                return k, why
        h = getattr(p, "heal", None)
        gs = self.goals
        if h is None and scr["bottom"].split()[:1] == ["CAMP:"] and p.goal + 1 < len(gs) \
                and isinstance(gs[p.goal], Walk) and isinstance(gs[p.goal + 1], Heal) and gs[p.goal + 1].inn:
            # Player 14: the inn (TO REST HERE, WHO WILL PAY) opens its camp before the walk sees its square.
            p.log("GOAL done: %s (the inn's camp)" % gs[p.goal])
            p.goal += 1
            p.goal_key = p.g.nkeys
            new_heal(p)
            h = p.heal
        if h is not None and not h["done"]:
            k = self._heal(scr, st, p, h)
            if k:
                return k
        if getattr(p, "saving", None) is None and self.memos and getattr(p, "memo_visit", 0) < len(self.memos):
            k = self._memorize(scr, st, p)
            if k:
                return k
        if kind == "camp" or kind == "saveslot":
            return p.save_step(scr)
        if getattr(p, "readying", None) is not None:
            bw = scr["bottom"].split()
            if bw[:1] == ["VIEW:ITEMS"] or (bw[:1] and bw[0].startswith("VIEW:")):
                if p.ready_over or "VIEW:ITEMS" not in bw:
                    p.ready_over = True
                    return "e", "readyall: EXIT the sheet"
                return "i", "readyall: ITEMS"
            if bw[:1] == ["READY"] and "EXIT" in bw and "VIEW:ITEMS" not in bw:
                rows = {}
                for r in range(5, 23):
                    m = re.match(r"(YES|NO)\s+(.*)", st["rows"][r].strip("?\\ "))
                    if m:
                        rows[r] = (m.group(1), m.group(2).strip())
                lit = [r for r in rows if screens._rowcol(st["im"], r) == screens.WHITE]
                todo = [r for r, (y, n) in rows.items() if y == "NO" and r not in p.ready_tried]
                if not todo:
                    p.ready_over = True
                    for r, (y, n) in sorted(rows.items()):
                        p.note("ready", "%s: %s %s" % (loot.party(p.g.mem)[p.readying][1], y, n))
                    return "e", "readyall: done, EXIT the list"
                if len(lit) != 1:
                    raise_stop(p, "readyall: no single lit item (rows %s)" % lit)
                if lit[0] == todo[0]:
                    p.ready_tried.add(todo[0])
                    return "r", "readyall: READY %s" % rows[todo[0]][1]
                return ("end" if todo[0] > lit[0] else "home"), "readyall: light to %s" % rows[todo[0]][1]
        if self.buys and getattr(p, "buy_visit", 0) < len(self.buys):
            bw = scr["bottom"].split()
            if kind == "yesno" and "SHOW YOU OUR WARES" in scr.get("text", ""):
                return "y", "shop: YES (purchases planned)"
            if kind == "hmenu" and (bw[:2] == ["BUY", "VIEW"] or bw[:2] == ["ITEMS:", "BUY"]):
                return self._buy(scr, st, p)
            # The pool's coins back to the last buyer (ours' POOL gives every coin to the buyer): TAKE, each coin
            # type in turn, its whole amount typed.
            if " ".join(bw[:4]) == "SELECT TYPE OF COIN":
                m = re.match(r"\s*([A-Z]+)\s+(\d+)", st["rows"][2].strip("?\\ "))
                if not m:
                    return "e", "shop: pool empty"
                p.coin_amt = m.group(2)
                return "enter", "shop: TAKE %s %s" % (m.group(2), m.group(1))
            if bw[:2] == ["HOW", "MUCH"]:
                typed = st["bottom"].split("?", 1)[1].strip() if "?" in st["bottom"] else ""
                amt = getattr(p, "coin_amt", "")
                if typed == amt:
                    return "enter", "shop: amount typed"
                return amt[len(typed)], "shop: amount %s" % amt
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
            if words in text and choice.startswith("type:"):
                # Player 13: `answer <words>|type:OHLO`: the word typed once, then Enter (the bot types the word the
                # script compares with: the Rope Guild booth's OHLO).
                word = choice[5:]
                if ("type", words) in p.snapped:
                    continue
                p.snapped.add(("type", words))
                return [c.lower() for c in word] + ["enter"], "%s: typed %s" % (src, word)
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
            t["start"], t["dir"] = 0, "n"
            return "i", "take: ITEMS (%s for member %d)" % (it["name"], j + 1)
        if sel != j:
            return "e", "take: back to select member %d" % (j + 1)
        L = loot.loot(mem)
        n = len(L)
        # Player 13: a list longer than the screen shows 19 rows a page (ITEMS: TAKE NEXT [PREV] EXIT; lab p13b2/b3: a
        # 37-item pile's second page shows its last 19). The window is found from the rows' names (the tracked start
        # first: piles repeat their names), not assumed.
        bw = scr["bottom"].split()
        rows = [re.sub(r"^\d+ ", "", st["rows"][4 + j].strip("?\\ *")) for j in range(19)]
        k = len([r for r in rows if r])
        starts = [s0 for s0 in range(0, max(1, n - k + 1)) if self._loot_rows_match(rows[:k], L[s0:s0 + k])]
        s0 = t.get("start", 0)
        if s0 not in starts:
            if not starts:
                p.log("TAKE rows %s | loot %s" % (rows[:k], [x["name"] for x in L]))
                raise_stop(p, "take: the ITEMS rows match no window of the %d-item loot" % n)
            s0 = starts[0] if t.get("dir", "n") == "p" or len(starts) == 1 else starts[-1]
        t["start"] = s0
        if not s0 <= i < s0 + k:
            if i >= s0 + k and "NEXT" in bw:
                t["start"], t["dir"] = s0 + k, "n"
                return "n", "take: NEXT page for %s (item %d)" % (it["name"], i + 1)
            if i < s0 and "PREV" in bw:
                t["start"], t["dir"] = max(0, s0 - 19), "p"
                return "p", "take: PREV page for %s (item %d)" % (it["name"], i + 1)
            raise_stop(p, "take: item %d not in rows %d-%d and no way there (%s)" % (i + 1, s0 + 1, s0 + k, scr["bottom"]))
        lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
        if len(lit) != 1:
            raise_stop(p, "take: no single lit item on the ITEMS list (rows %s)" % lit)
        hl = lit[0] - 4 + s0
        if hl == i:
            t["pending"] = (n, sig, j)
            return "t", "take: %s (%d gp, weight %d) for member %d" % (it["name"], it["price"], it["weight"], j + 1)
        return ("end" if i > hl else "home"), "take: light to %s (row %d)" % (it["name"], i + 4)

    @staticmethod
    def _loot_rows_match(rows, items):
        names = [re.sub(r"^\d+ ", "", it["name"].upper()) for it in items]
        return len(rows) == len(names) and all(r.startswith(nm[:len(r)]) or nm.startswith(r) for r, nm in zip(rows, names))

    # -- Player 12: BUY (`buy` lines; the shop's list is the loot pointer DS:0x6810, the buyer DS:0x5D92) ----
    def _buy(self, scr, st, p):
        mem = p.g.mem
        if not hasattr(p, "buy_visit"):
            p.buy_visit, p.buy_pending, p.buy_pages, p.buy_dir = 0, None, 0, "n"
        left = self.buys[p.buy_visit]
        menu = scr["bottom"].split()[0]
        P = loot.party(mem)
        if p.buy_pending:
            j, n, name = p.buy_pending
            p.buy_pending = None
            if P[j][2] > n:
                left.pop(0)
                p.buy_pages, p.buy_dir = 0, "n"
                p.note("buy", "%s bought %s" % (P[j][1], name))
            else:
                raise_stop(p, "buy: %s not bought by %s (no gold, or a full or overloaded pack)" % (name, P[j][1]))
        if not left:
            if menu == "ITEMS:":
                return "e", "buy: the visit's list done, back to the menu"
            if "TAKE" in scr["bottom"].split():
                sel = loot.selected(mem)
                return "t", "buy: TAKE the pool's coins (%s)" % (P[sel][1] if sel is not None else "?")
            p.buy_visit += 1
            return "e", "buy: visit %d done, EXIT the shop" % p.buy_visit
        j, name = left[0]
        sel = loot.selected(mem)
        if menu == "BUY":
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "buy: select %s for %s" % (P[j][1], name)
            if not getattr(p, "buy_pooled", False):
                p.buy_pooled = True      # main's bot: shop._pool() before every purchase
                return "p", "buy: POOL (main's bot pools before each purchase)"
            p.buy_pooled = False
            return "b", "buy: BUY (%s for %s)" % (name, P[j][1])
        if sel != j:
            return "e", "buy: back to select %s" % P[j][1]
        want = name.upper()
        rows = {r: st["rows"][r].strip("?\\ ") for r in range(4, 23)}
        hit = [r for r, t in rows.items() if t.startswith(want)]
        lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
        if hit:
            if len(lit) != 1:
                raise_stop(p, "buy: no single lit item on the shop's list (rows %s)" % lit)
            if lit[0] == hit[0]:
                p.buy_pending = (j, P[j][2], name)
                return "b", "buy: %s for %s" % (rows[hit[0]], P[j][1])
            return ("end" if hit[0] > lit[0] else "home"), "buy: light to %s (row %d)" % (name, hit[0])
        bw = scr["bottom"].split()
        p.buy_pages = getattr(p, "buy_pages", 0) + 1
        if p.buy_pages > 12:
            raise_stop(p, "buy: %s not on the shop's list" % name)
        d = getattr(p, "buy_dir", "n")
        if d == "n" and "NEXT" not in bw:
            d = "p"
        elif d == "p" and "PREV" not in bw:
            d = "n"
        p.buy_dir = d
        return d, "buy: page for %s" % name

    # -- Player 12: MEMORIZE and REST in camp (`memorize` lines: main's bot's _pick_spells at the inn) ------------
    def _memorize(self, scr, st, p):
        if not hasattr(p, "memo_visit"):
            p.memo_visit, p.memo_done_cur, p.memo_rested, p.memo_pages, p.memo_dir = 0, False, False, 0, "n"
        left = self.memos[p.memo_visit]
        bw = scr["bottom"].split()
        P = loot.party(p.g.mem)
        sel = loot.selected(p.g.mem)
        names = [m[1] for m in P]
        for i, (who, sp) in enumerate(left):
            if isinstance(who, str):
                if who not in names:
                    raise_stop(p, "memorize: no member %s" % who)
                left[i] = (names.index(who), sp)
        if bw[:1] == ["CAMP:"]:
            if left:
                j = left[0][0]
                if sel != j:
                    return ("end" if sel is None or j > sel else "home"), "memorize: select %s" % P[j][1]
                return "m", "memorize: MAGIC (%s)" % P[j][1]
            if not p.memo_rested:
                p.memo_rested = True
                return "r", "memorize: REST"
            p.memo_visit += 1
            p.memo_rested = False
            return "e", "memorize: done, leave camp"
        if bw[:2] == ["CAST", "MEMORIZE"]:
            if p.memo_done_cur or not left:
                p.memo_done_cur = False
                return "e", "memorize: EXIT MAGIC"
            return "m", "memorize: MEMORIZE (%s)" % P[left[0][0]][1]
        if bw == ["EXIT"] and "TO BE MEMORIZED" in st["rows"][1]:
            return "e", "memorize: the list to be memorized shown, EXIT"
        if scr["kind"] == "yesno" and "MEMORIZE THESE SPELLS" in scr["bottom"]:
            left.pop(0)
            p.memo_done_cur = True
            return "y", "memorize: YES"
        if bw[:2] == ["CHOOSE", "SPELL:"]:
            spells = left[0][1] if left else []
            if not spells:
                return "e", "memorize: the member's list done, EXIT"
            want = spells[0].upper()
            rows = {r: st["rows"][r].strip("?\\ *") for r in range(5, 18)}
            hit = [r for r, t in rows.items() if t == want]
            lit = [r for r in range(5, 18) if screens._rowcol(st["im"], r) == screens.WHITE]
            if hit:
                if len(lit) != 1:
                    raise_stop(p, "memorize: no single lit spell (rows %s)" % lit)
                if lit[0] == hit[0]:
                    spells.pop(0)
                    p.memo_pages, p.memo_dir = 0, "n"
                    p.note("memorize", "%s: %s" % (P[left[0][0]][1], want))
                    return "m", "memorize: %s" % want
                return ("end" if hit[0] > lit[0] else "home"), "memorize: light to %s" % want
            p.memo_pages += 1
            if p.memo_pages > 8:
                raise_stop(p, "memorize: %s not in %s's book" % (want, P[left[0][0]][1]))
            d = p.memo_dir
            if d == "n" and "NEXT" not in bw:
                d = "p"
            elif d == "p" and "PREV" not in bw:
                d = "n"
            p.memo_dir = d
            return d, "memorize: page for %s" % want
        if bw[:1] == ["REST"] and "DAYS" in bw:
            if not getattr(p, "memo_rest_sent", False):
                p.memo_rest_sent = True
                p.note("rest", "rest at the inn: %s" % st["rows"][17].strip("?\\ "))
                return "r", "memorize: REST for the time offered"
            p.memo_rest_sent = False
            return "e", "memorize: rest over, EXIT"
        return None

    # -- Player 13: the heal in camp (`heal` goal; bot.gd _heal) --------------------------------------------------
    def _heal_op(self, p, h):
        """The next thing to do from the CAMP menu: ("cast", caster, target) | ("memorize", member, [names]) |
        ("rest", minutes or None for the time offered) | ("leave",)."""
        M = members(p.g.mem)
        op = h["op"]
        if op and op[0] == "rest":
            h["op"], h["memo_last"] = None, None
            if h["phase"] == "rounds":
                h["round"] += 1
                h["cured"], h["memo_any"] = 0, False
                if h["round"] >= 12:
                    h["phase"] = "days"
            elif op[1] is not None:
                h["days"] += 1
        if not needs_rest(M):
            return ("leave",)
        if h["phase"] == "rounds":
            c = next_cure(M)
            if c:
                h["cured"] += 1
                return ("cast", c[0]["i"], c[1]["i"])
            if not needs_rest(M):
                return ("leave",)
            if h["cured"] == 0 and h["round"] > 0:
                h["phase"] = "days"
            else:
                for m in M:
                    pk = picks(m)
                    if pk:
                        return self._memo_op(p, h, m, pk)
                if h["memo_any"]:
                    return ("rest", None)
                h["phase"] = "days"
        # days: the bot's picks and a rest to memorize them first, then rests of min(need, 10) days
        if not h["days_memo"]:
            for m in M:
                pk = picks(m)
                if pk:
                    return self._memo_op(p, h, m, pk)
            h["days_memo"] = True
            if h["memo_any"]:
                return ("rest", None)
        if h["days"] >= 60:
            p.note("heal", "60 day rests and still hurt: %s" % party_hp(p.g.mem))
            return ("leave",)
        need = max(m["max"] - m["hp"] for m in M if m["status"] in (0, 4, 5))
        return ("rest", min(need, 10) * 24 * 60)

    def _memo_op(self, p, h, m, pk):
        if h.get("memo_last") == (m["i"], tuple(pk)):
            raise_stop(p, "heal: %s's free slots still free after MEMORIZE (%s)" % (m["name"], pk))
        h["memo_last"], h["memo_any"] = (m["i"], tuple(pk)), True
        return ("memorize", m["i"], list(pk))

    def _heal(self, scr, st, p, h):
        bw = scr["bottom"].split()
        mem = p.g.mem
        sel = loot.selected(mem)
        P = loot.party(mem)
        row1 = st["rows"][1]
        if bw[:1] == ["CAMP:"]:
            if h["op"] is None or h["op"][0] == "rest" and h.get("rest_sent"):
                h["rest_sent"] = False
                h["op"] = self._heal_op(p, h)
                h["sub"] = None
                p.log("HEAL op %s (phase %s, round %d)" % (h["op"], h["phase"], h["round"]))
            op = h["op"]
            if op[0] == "leave":
                h["done"] = True
                return "e", "heal: done, leave camp"
            if op[0] == "rest":
                h["fights0"], h["field"] = p.fights, None
                return "r", "heal: REST"
            j = op[1]
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "heal: select %s" % P[j][1]
            if h.get("sub") == "over":      # the cast / memorize finished: next op
                h["op"] = None
                return self._heal(scr, st, p, h)
            return "m", "heal: MAGIC (%s)" % P[j][1]
        op = h["op"]
        if op is None:
            return None
        if bw[:2] == ["CAST", "MEMORIZE"]:
            if h.get("sub") == "over":
                return "e", "heal: EXIT MAGIC"
            return ("c", "heal: CAST") if op[0] == "cast" else ("m", "heal: MEMORIZE")
        if bw[:2] == ["CHOOSE", "SPELL:"] and "CAST" in bw and op[0] == "cast":
            if h.get("sub") == "over":
                return "e", "heal: EXIT the spells in memory"
            rows = {r: st["rows"][r].strip("?\\ *") for r in range(5, 18)}
            hit = [r for r, t in rows.items() if t == "CURE LIGHT WOUNDS"]
            lit = [r for r in range(5, 18) if screens._rowcol(st["im"], r) == screens.WHITE]
            if not hit:
                raise_stop(p, "heal: no CURE LIGHT WOUNDS in %s's memory" % P[op[1]][1])
            if len(lit) != 1:
                raise_stop(p, "heal: no single lit spell (rows %s)" % lit)
            if lit[0] in hit:
                return "c", "heal: CAST CURE LIGHT WOUNDS (%s)" % P[op[1]][1]
            return ("end" if hit[0] > lit[0] else "home"), "heal: light to CURE LIGHT WOUNDS"
        if "CAST SPELL ON WHOM" in scr["bottom"] and op[0] == "cast":
            t = op[2]
            hl = scr.get("highlight")
            if hl is None:
                raise_stop(p, "heal: no member lit on CAST SPELL ON WHOM")
            if hl != t:
                return ("end" if t > hl else "home"), "heal: target %s" % P[t][1]
            h["sub"] = "over"
            h["cures"] += 1
            p.note("heal", "%s casts Cure Light Wounds on %s (%d/%d)" % (
                P[op[1]][1], P[t][1], P[t][3], members(mem)[t]["max"]))
            return "s", "heal: SELECT %s" % P[t][1]
        if op[0] == "memorize":
            spells = op[2]
            if bw[:2] == ["CHOOSE", "SPELL:"] and "MEMORIZE" in bw:
                if not spells or h.get("sub") == "over":
                    return "e", "heal: the member's list done, EXIT"
                want = spells[0]
                rows = {r: st["rows"][r].strip("?\\ *") for r in range(5, 18)}
                hit = [r for r, t in rows.items() if t == want]
                lit = [r for r in range(5, 18) if screens._rowcol(st["im"], r) == screens.WHITE]
                if not hit:
                    if "NEXT" in bw and h.get("mpages", 0) < 8:
                        h["mpages"] = h.get("mpages", 0) + 1
                        return "n", "heal: page for %s" % want
                    raise_stop(p, "heal: %s not in %s's book" % (want, P[op[1]][1]))
                if len(lit) != 1:
                    raise_stop(p, "heal: no single lit spell (rows %s)" % lit)
                if lit[0] == hit[0]:
                    spells.pop(0)
                    h["mpages"] = 0
                    p.note("heal", "%s memorizes %s" % (P[op[1]][1], want))
                    return "m", "heal: MEMORIZE %s" % want
                return ("end" if hit[0] > lit[0] else "home"), "heal: light to %s" % want
            if bw == ["EXIT"] and "TO BE MEMORIZED" in row1:
                return "e", "heal: the list to be memorized shown, EXIT"
            if scr["kind"] == "yesno" and "MEMORIZE THESE SPELLS" in scr["bottom"]:
                h["sub"] = "over"
                return "y", "heal: YES"
        if bw[:1] == ["REST"] and "DAYS" in bw and op[0] == "rest":
            if h.get("rest_sent"):
                return "e", "heal: rest over, EXIT"
            m = re.search(r"REST TIME:\s*(\d+):(\d+):(\d+)", st["rows"][17])
            if not m:
                raise_stop(p, "heal: no REST TIME on row 17")
            have = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
            if op[1] is not None:
                want = (op[1] // 1440, op[1] // 60 % 24, op[1] % 60)
                for f, key in enumerate("yhm"):
                    if have[f] != want[f]:
                        if h["field"] != f:
                            h["field"] = f
                            return key, "heal: rest field %s" % ("DAYS", "HOURS", "MINS")[f]
                        return ("i" if want[f] > have[f] else "d"), "heal: rest %02d:%02d:%02d to %02d:%02d:%02d" % (
                            have + want)
            if have == (0, 0, 0):
                h["rest_sent"] = True
                return "e", "heal: nothing to rest for, EXIT"
            h["rest_sent"] = True
            h["rests"] += 1
            p.note("heal", "rest %02d:%02d:%02d (%s)" % (have + ("offered" if op[1] is None else "days",)))
            return "r", "heal: REST %02d:%02d:%02d" % have
        return None

    def choose(self, scr, choice):
        kind = scr["kind"]
        if kind == "vmenu":
            if choice not in scr["items"] or scr["highlight"] is None:
                return None
            d = scr["items"].index(choice) - scr["highlight"]
            # the original's vertical menus: End = next item, Home = previous (lab; the arrows do nothing)
            return "enter" if d == 0 else ("end" if d > 0 else "home")
        if kind == "member" and choice == "@platinum" and self.mem is not None:
            # Player 14: main's bot pays the inn with the member who has most platinum (record 0x90)
            M = members(self.mem)
            best = max(M, key=lambda m: m["rec"][0x90] | m["rec"][0x91] << 8)
            choice = best["name"]
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
            avoid = [int(v) for v in w[2].split(",") if v] if len(w) > 2 and w[1] == "avoid" else None
            pl.goals.append(Walk(x, y, pl.area, through, avoid))
            pl.goals[-1].aliases = pl.aliases
        elif cmd == "step":
            pl.goals.append(Step(rest.strip().upper()))
        elif cmd == "checkpoint":
            pl.goals.append(Checkpoint(rest.strip()))
        elif cmd == "inntrip":
            # Player 14: `inntrip` ... `inntrip end`: goals kept aside for an interrupted rest (bot.gd _rest_at_inn)
            if rest.strip() == "end":
                pl.goals, pl.inntrip = trip_outer, pl.goals + [TripEnd()]
                pl.area = trip_area
            else:
                trip_outer, trip_area, pl.goals = pl.goals, pl.area, []
        elif cmd == "innheal":
            pl.goals.append(Heal(force=True, inn=True))
        elif cmd == "keys":
            name, ks = rest.split(None, 1)
            pl.goals.append(Keys(name, ks.replace(" ", "").split(",")))
        elif cmd == "memorize":
            pl.memos.append([])
            for b in rest.split("|"):
                if b.strip():
                    who, sp = b.strip().split(None, 1)
                    pl.memos[-1].append((who, [x.strip() for x in sp.split(",") if x.strip()]))
        elif cmd == "heal":
            pl.goals.append(Heal())
        elif cmd == "readyall":
            pl.goals.append(ReadyAll())
        elif cmd == "exit":
            pl.goals.append(Exit(area_of(rest)))
        elif cmd == "answer":
            words, choice = rest.rsplit("|", 1)
            pl.answers.append((words.strip(), choice.strip(), os.path.basename(path)))
        elif cmd == "buy":
            pl.buys.append([(int(b.split(None, 1)[0]), b.split(None, 1)[1].strip()) for b in rest.split("|") if b.strip()])
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

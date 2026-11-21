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
  answer <words>|<choice>*<n>    (Player 19) given at most n times, then the next answer for <words> applies (main's
                                 bot answers a question with a LEAVE in it three times, then LEAVEs: "asked too often",
                                 4:2's chained man: FREE*3, then LEAVE)
  shortcutwin <area> <x,y> [n]   (Player 27, Q27 (a)) a step: the next fight (Player 29: next n) that starts there
                                 is won by the logged shortcut (main's bot's): every monster's HP 0 and status dead at
                                 the fight's first poll (game.py _shortcut_win), logged SHORTCUT and in the summary
  picks <NAME> <spell>, ...      (Player 30) `prepare` / `heal` memorize these first for the member (known spells, in
                                 order, while their level has a free slot), then the bot's picks in the rest
  focus <KIND>,...|none          (Player 36) a step: tactics' blows, arrows, MOVEs and Stinking Cloud go to these kinds
                                 first (the helpless of them first): the throne room's TROLL
  bands on|off                   (Player 36) a step: Guide 3's band rule on 6:25/7:26/8:27 (BANDS: the best Charisma lit,
                                 PARLAY the cheap kinds with the area's manner, FLEE or fight the rich ones, WAIT)
  advance <NAME>,...|none        (Player 35) a step: who MOVEs toward the enemy when nothing is in reach (OP_ADVANCE)
  learn <spell>, ...             (Player 35) a magic-user's new spell at training: these first, then LEARN_ORDER
  drop <NAME> <words>*<n>, ...   (Player 35) several drops in one VIEW (`<words> +0`: a plain one, matched on the plus)
  coins <FROM> <COIN> <n>|<TO>   (Player 38) the money TRADE (VIEW, TRADE, TRADE TO?, the coin, the amount)
  buypurse on|off                (Player 38) a purchase paid from the buyer's own purse (no POOL first)
  tactics on|off                 (Player 30) a step: from here the casters get orders by hand in fights (tactics.py:
                                 Prayer, Bless, Hold Person on the mages, Stinking Cloud, Magic Missile, Sleep), the
                                 rest go on QUICK; game.py presses Space at each fight's first poll to take the party back
  answerfrom <words>|<choice>    (Player 16) a step of the plan: from here on this answer comes before the others
                                 (Kuto's Well: CLIMB DOWN is NO while events are left, then YES)
  map 7:26                       (Player 16) the following walks' map when it isn't the area's own GEO block (`map`
                                 alone: back to the area's)
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
  prepare                        (Player 15) main's bot's `_prepare` before each event (explore): the bot's picks in
                                 every free slot (spells cast since), a REST to memorize them, and the heal of anyone
                                 hurt (as `heal` after a fight); nothing when no slot is free and no one is hurt
  cure                           (Player 16) main's bot's `_prepare` where the plan's rest rule is the inn (Kuto's
                                 Well before Norris): camp, the memorized cures on the most hurt, no MEMORIZE or REST
  templecure CURE DISEASE        (Player 25) at a temple's HEAL VIEW POOL APPRAISE EXIT: that service for each member
                                 who needs it (bot.gd _temple_cures; the original asks CAST CURE ANYWAY otherwise: NO)
  nocast [off]                   (Player 25) the following goals' heals cast nothing (an anti-magic area: 8:16's
                                 castle): `cure` does nothing, `heal` / `prepare` / a walk's stop rest only
  norest [off]                   (Player 16) the following walks' stop after a fight that leaves the party hurt is
                                 that `cure`, not a `prepare`
  bumps <n> [look]               (Player 16) the following walks try a step that leaves the party where it stands n
                                 times before refusing it (3 unless said); `look`: with a LOOK before each new try
                                 (a secret door: the square's script finds it for a searching party)
  campday <n>                    (Player 19) main's bot's: n day rests in camp whatever comes (the nomads' kobolds come
                                 while the party rests), an interrupted day counted, the cures on anyone hurt first;
                                 (Player 20) over when a fight's script moves the party to another area (the
                                 nomads' reward, then NEW_ECL 26 onto the band)
  search on|off                  (Player 21) main's bot's: SEARCH mode toggled on the walking screen (S), the plan
                                 keeping the state (the library's stacks give their books only to a searching party)
  revisit <event> <n>            (Player 21) main's bot's: n times onto the event's nearest square (off it first),
                                 crossing every event (the library's stacks: a book a visit)
  innwait                        (Player 15) `innheal`, then from hour 14 a rest till midnight (bot.gd _wait_for_day:
                                 New Phlan locks its shops, City Hall and halls from hour 14)
  restuntil <hour>               (Player 26) main's bot's: camp and rest (hour - now) mod 24 hours (Stojanow Gate's
                                 trader drives up only before 14:00); an interruption is fought out, not rested again
  innheal                        (Player 14) inside `inntrip`: the heal in the inn's camp (TO REST HERE, the payer,
                                 then the camp opens before the walk sees the inn's square)
  answer <words>|@platinum       (Player 14) on a member list: the member with most platinum (main's bot pays the inn so)
  Walks also (Player 14, main.gd _tour and bot.gd): a step the square's script turns back is refused and walked round
  (a walk to an event that turned the party back is done); a fight on a walk that leaves the party hurt (bot.gd
  _hurt) is followed by a heal of anyone hurt before the walk goes on.
  default <kind> <key>           what to press on a kind of screen (screens.py) with no answer
  sell gems [share] [gear]       (Player 15; gear: Player 27, the bot's spare gear after the gems) the next shop visit: every member's gems and jewellery APPRAISEd and
                                 SOLD (main's bot sells them before training), then EXIT (or the visit's `buy`);
                                 `share`: then everyone's coins POOLed and SHAREd (to fund every trainee)
  buy <m> <item> | <m> <item> ...
                                 (Player 12) the next shop visit's purchases, main's `shop` list without the door:
                                 member <m> (0 = the first) buys the item whose name on the list starts so (End /
                                 Home on BUY VIEW POOL select the buyer, DS:0x5D92; on the list they move the light,
                                 NEXT / PREV page); POOL before each purchase (main's bot does); EXIT when the visit's
                                 list is done. Each `buy` line is one visit (Player 17: a `sell gems` visit takes one
                                 too: an empty `buy` line for it; a purchase refused is noted and skipped).
"""
import copy, os, re, struct, sys
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
        # Player 16: `map 7:26`: the walk's map when it isn't the area's own (Kuto's catacombs: ECL 8:29 on GEO7's 26)
        geo = getattr(self, "geo", None) or self.area
        R.NE, R.SW, R.INFO, R.DOORS = R.load(*geo)
        # Player 14: main's bot's two rules for a walk interrupted on the way (main.gd _tour, bot.gd _auto_handle):
        # a fight that leaves the party hurt (bot.gd _hurt) stops the walk for a heal (_prepare: camp areas heal);
        # a step the square's script turns back (the party on the same square, facing elsewhere: p13b6's event 3
        # door at 13,10 after the commission) is refused for the rest of the run and walked round (_refused).
        refused = REFUSED.setdefault(tuple(geo), set())
        t, self._tried = getattr(self, "_tried", None), None
        if t is not None and t[:2] == (x, y) and f != t[2] and (x, y, t[2]) not in refused:
            refused.add((x, y, t[2]))
            p.note("walk", "the step %s from %d,%d was turned back: refused, walked round" % (t[2], x, y))
        elif t is not None and t[:2] == (x, y) and (x, y, t[2]) not in refused:
            # Player 16: a square that puts the party back on the square it came from, still facing it (the temple
            # of Tyr's 11,3 after DO YOU SEEK HEALING NO: p15h3 stepped on it again and again). The third time
            # running (one lost key is no refusal) the step is refused like a turn-back. `bumps <n>`: n times
            # (Kuto's catacombs: a secret door's square rolls to find it at every bump; p16c1 gave up after two).
            again, n = getattr(self, "_back", None) or (None, 0)
            n = n + 1 if again == t else 1
            self._back = (t, n)
            if n >= getattr(self, "bumps", 3):
                refused.add(t)
                self._back = None
                p.note("walk", "the step %s from %d,%d put the party back %d times: refused, walked round" % (
                    t[2], x, y, n))
            elif getattr(self, "look", False):
                # `bumps <n> look`: LOOK searches the square (its script runs as for a SEARCHing party: main.gd
                # _search_again does it by SEARCH and a step off and on), then the step is tried again
                return False, "l", "walk: LOOK at %d,%d %s (a secret door? try %d)" % (x, y, t[2], n)
        elif t is not None:
            b = getattr(self, "_back", None)
            if b and (x, y) != b[0][:2]:
                p.note("walk", "the step %s from %d,%d went through at try %d" % (b[0][2], b[0][0], b[0][1], b[1] + 1))
            self._back = None
        f0 = getattr(self, "_fights0", None)
        if f0 is None:
            self._fights0 = p.fights
        elif p.fights > f0:
            self._fights0 = p.fights
            if any(m["status"] >= 6 for m in members(p.g.mem)) and not game_won(p):
                # Player 25: a member dead after a walk's fight (p25h2: BRAM in a band fight in 6:25, the rest
                # standing well, so no heal came to see it): a loss under the death rule
                raise_stop(p, "walk: a member is dead after fight %d (a loss under the death rule: reload from the"
                              " last checkpoint)" % p.fights)
            if hurt(members(p.g.mem)):
                p.note("walk", "fight %d left the party hurt (%s): prepare before going on (bot.gd _hurt, _prepare)" % (
                    p.fights, party_hp(p.g.mem)))
                hg = Heal(force=True, cure=True) if getattr(self, "norest", False) else Heal(force=True, prep=True)
                hg.nocast = getattr(self, "nocast", False)
                p.plan.goals.insert(p.goal, hg)
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
    # (Player 18: back in Walk; Player 14's route_refusing and hurt had landed above it, so band_step was
    # a function nested in hurt and the band's walks failed: p18b1)


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


# Player 21: main's bot's order of want for a magic-user's new spell at training (bot.gd LEARN_ORDER, by name)
LEARN_ORDER = ["KNOCK", "MAGIC MISSILE", "SLEEP", "STINKING CLOUD", "INVISIBILITY", "MIRROR IMAGE", "FIREBALL", "HASTE",
               "LIGHTNING BOLT", "HOLD PERSON", "DISPEL MAGIC", "SLOW"]
LEARN_FIRST = []     # Player 35: a plan's `learn <spell>, <spell>` goes before LEARN_ORDER (Stojanow Plan 1: Fireball)


class Search:
    """Player 21: `search on|off`, main's bot's (bot.gd "search"): SEARCH mode (steps take 10 minutes; the library's
    stacks give their books only to a searching party). The walking screen's SEARCH key toggles it; the plan keeps
    the state (`p.searching`), so a line that asks for the mode already on sends nothing."""
    def __init__(self, on):
        self.on, self.sent = on, False

    def __repr__(self):
        return "search %s" % ("on" if self.on else "off")

    def next(self, p):
        if self.sent or bool(getattr(p, "searching", False)) == self.on:
            return True, None, ""
        self.sent = True
        p.searching = self.on
        return False, "s", "search %s: SEARCH" % ("on" if self.on else "off")


class Revisit:
    """Player 21: `revisit <event> <n>`, main's bot's (bot.gd "revisit"): n times, onto the event's nearest square
    again (off it first when the party stands on it), playing whatever it gives (the library's stacks: a book a
    visit). The walk on crosses every event (main.gd _tour with no left-out events)."""
    def __init__(self, ev, n, area):
        self.ev, self.left, self.area = ev, n, area
        self.walk = self.step = self.target = None

    def __repr__(self):
        return "revisit %d (%d left)" % (self.ev, self.left)

    def next(self, p):
        if self.step is not None:
            done, k, why = self.step.next(p)
            if not done:
                return False, k, "revisit %d: %s" % (self.ev, why)
            self.step = None
        if self.walk is not None:
            done, k, why = self.walk.next(p)
            if not done:
                return False, k, why
            self.walk = None
            self.left -= 1
            p.note("walk", "revisit %d: visit done, %d left" % (self.ev, self.left))
        if self.left <= 0:
            return True, None, ""
        x, y, f = p.where()
        geo = getattr(self, "geo", None) or self.area
        R.NE, R.SW, R.INFO, R.DOORS = R.load(*geo)
        if self.target is None:
            # the nearest square from where the party stands (bot.gd: chosen before the step off)
            squares = R.squares(self.ev)
            if not squares:
                raise_stop(p, "revisit: no square of event %d on map %d:%d" % ((self.ev,) + tuple(geo)))
            best = None
            for sq in squares:
                path = R.route((x, y), {sq}, set())
                if path and (best is None or len(path) < len(best)):
                    best = path
            if best is None:
                raise_stop(p, "revisit: no way to event %d from %d,%d" % (self.ev, x, y))
            self.target = best[-1]
            if self.target == (x, y):
                # bot.gd _step_off: the first neighbour one step away (N, E, S, W), whatever its event
                for s_, d in enumerate("NESW"):
                    if R.passable(x, y, s_):
                        self.step = Step(d)
                        p.note("walk", "revisit %d: off %d,%d %s first" % (self.ev, x, y, d))
                        return self.next(p)
                raise_stop(p, "revisit: no way off %d,%d" % (x, y))
        tx, ty = self.target
        self.target = None
        self.walk = Walk(tx, ty, self.area, (), [])
        for a in ("aliases", "geo", "norest", "bumps", "look", "nocast"):
            setattr(self.walk, a, getattr(self, a, None) if a != "aliases" else getattr(self, a, set()))
        self.walk.bumps = getattr(self, "bumps", None) or 3
        p.note("walk", "revisit %d: to %d,%d" % (self.ev, tx, ty))
        return self.next(p)


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


class ReadyItems(ReadyAll):
    """Player 32: `ready <NAME> -<words>, +<words>, ...` on the walking screen: VIEW, ITEMS for that member, then READY
    toggles the listed items in order (- unready, + ready; the first row whose name holds the words; the list shows an
    unidentified item without its plus): the graveyard's BRAM -FLAIL, -SHIELD, +TWO-HANDED SWORD (the council's +3 vs
    undead, cluebook). Same screens as readyall (Plan.answer, p.ready_spec)."""
    def __init__(self, who, spec):
        ReadyAll.__init__(self)
        self.who, self.spec = who.upper(), spec

    def __repr__(self):
        return "ready %s %s" % (self.who, self.spec)

    def next(self, p):
        P = loot.party(p.g.mem)
        if getattr(p, "readying", None) is not None:
            if not p.ready_over:
                raise_stop(p, "ready: back on the walking screen with %s not done" % self.who)
            p.readying, p.ready_spec = None, None
            # the step's own answers go with it (a stale CHOOSE SPELL: CAST would answer later camps)
            p.plan.answers[:] = [a for a in p.plan.answers if a[2] not in ("use", "trade", "drop")]
            return True, None, ""
        js = [i for i, m in enumerate(P) if m[1].upper() == self.who]
        if not js:
            p.note("ready", "%s not in the party: skipped" % self.who)
            return True, None, ""
        self.j = js[0]
        sel = loot.selected(p.g.mem)
        if sel != self.j:
            return False, ("end" if sel is None or self.j > sel else "home"), "ready: select %s" % self.who
        p.readying, p.ready_tried, p.ready_over = self.j, set(), False
        p.ready_spec = list(self.spec)
        for want, words in self.spec:
            if isinstance(want, str) and want.startswith("T:"):   # Player 32: TRADE WITH WHOM? the receiver
                p.plan.answers.insert(0, ("TRADE WITH WHOM", want[2:], "trade"))
            elif want == "D":                                     # DROP IT? YES (ours' sheet: NO lit)
                p.plan.answers.insert(0, ("DROP IT", "YES", "drop"))
            elif isinstance(want, str) and want.startswith("U:"):  # a scroll: its lit spell CAST, then ON WHOM
                p.plan.answers.insert(0, ("SPELL ON WHOM", want[2:], "use"))
                p.plan.answers.insert(0, ("CHOOSE SPELL:", "CAST", "use"))
        return False, "v", "ready: VIEW %s" % self.who


COIN_WORDS = ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM", "GEMS", "JEWELRY"]   # record 0x88 + 2 x index


class CoinTrade:
    """Player 38: `coins <FROM> <COIN> <n>|<TO>` on the walking screen (the audit's movement rule: the light members'
    platinum to the strong fighters): select FROM, VIEW, TRADE (the view menu's money TRADE), TRADE TO? the receiver,
    SELECT TYPE OF COIN the coin lit (the view page lists the coins held from row 7, the chosen one white), HOW MUCH
    typed, Enter; again until n have moved (the giver's record, 0x88 + 2 x coin, read after each round: a field that
    takes fewer digits, or a refusal, shows there), then EXIT, EXIT, EXIT. The original's TRADE leaves both members'
    load words as they were (GAME.OVR 0x250D5); VIEW's entry works them out again (0x2165C): `ready <NAME>` with no
    items is a VIEW. The screens are answered in Plan.answer (p.cointrade)."""
    def __init__(self, who, coin, n, to):
        self.who, self.coin, self.n, self.to = who.upper(), COIN_WORDS.index(coin.upper()), n, to.upper()

    def __repr__(self):
        return "coins %s %s %d|%s" % (self.who, COIN_WORDS[self.coin], self.n, self.to)

    def next(self, p):
        ct = getattr(p, "cointrade", None)
        if ct is not None:
            if not ct["over"]:
                raise_stop(p, "coins: back on the walking screen with %s's trade not done" % self.who)
            p.cointrade = None
            p.note("coins", "%s gave %s %d %s (%s)" % (self.who, self.to, ct["moved"], COIN_WORDS[self.coin],
                                                       "all asked" if ct["moved"] >= self.n else "short"))
            return True, None, ""
        P = loot.party(p.g.mem)
        js = [i for i, m in enumerate(P) if m[1].upper() == self.who]
        if not js or self.to not in [m[1].upper() for m in P]:
            p.note("coins", "%s or %s not in the party: skipped" % (self.who, self.to))
            return True, None, ""
        sel = loot.selected(p.g.mem)
        if sel != js[0]:
            return False, ("end" if sel is None or js[0] > sel else "home"), "coins: select %s" % self.who
        p.cointrade = {"j": js[0], "coin": self.coin, "n": self.n, "to": self.to, "moved": 0, "over": False,
                       "before": None, "typed": None, "same": 0, "still": 0}
        return False, "v", "coins: VIEW %s" % self.who


def held_coins(mem, j, coin):
    return struct.unpack_from("<H", members(mem)[j]["rec"], 0x88 + 2 * coin)[0]


class Heal:
    """Player 13:`heal` on the walking screen: main's bot's `_heal_if_low` and `_heal` (scripts/dev/bot.gd) for an
    area whose rest rule is camp. Nothing unless a member isn't OKAY or is below half HP. Then in camp: every
    memorized Cure Light Wounds cast on the most hurt (by 4 HP or more; MAGIC, CAST, the member list), the free slots
    filled with the bot's picks (MEMORIZE) and a REST for the time the original offers, round after round while the
    cures heal; then rests of min(most HP missing, 10) days until no one is hurt (REST: DAYS is Y, INC / DEC).
    An interrupted rest is fought out (the bot walks to the inn there; noted) and the heal goes on.
    The camp screens are answered in Plan._heal (p.heal holds the state)."""
    def __init__(self, force=False, inn=False, prep=False, wait=False, cure=False, until=None):
        self.until = until      # Player 26: `restuntil <hour>` (bot.gd "restuntil"): rest in camp till that hour
        self.cure = cure        # Player 16: `cure` (bot.gd _prepare where the plan's rest rule is the inn: Kuto's
                                # Well before Norris): camp, the memorized cures on the most hurt, no MEMORIZE, no REST
        self.wait = wait        # Player 15: `innwait` (bot.gd _wait_for_day): from hour 14 rest till the doors open
        self.force = force      # Player 14: after a fight on a walk (bot.gd _prepare): heal anyone hurt
        self.inn = inn          # Player 14: `innheal` in an `inntrip` block: the heal in the inn's camp
        self.prep = prep        # Player 15: `prepare` (bot.gd _prepare): also memorize into free slots

    def __repr__(self):
        if self.until is not None:
            return "restuntil %d" % self.until
        return ("cure" if self.cure else "prepare" if self.prep else "heal") + (" at the inn" if self.inn else
                                                       " (after a fight)" if self.force and not self.prep else "")

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
                if any(m["status"] >= 6 for m in members(p.g.mem)):
                    # Player 25: the fight that interrupted the rest killed a member (p25j5: BRAM at 6:25 3,31)
                    raise_stop(p, "heal: a member is dead after fight %d (a loss under the death rule: reload from"
                                  " the last checkpoint)" % p.fights)
                h["op"], h["memo_last"] = None, None     # Player 15: the rest's spells may be lost: MEMORIZE again
                if h.get("campday"):
                    # Player 19: `campday`: the interruption is what the camp waits for (the nomads' kobolds); the
                    # bot's loop counts the day whatever came (bot.gd "campday")
                    h["days"] += 1
                    p.note("heal", "campday: day %d of %d interrupted by fight %d" % (h["days"], h["campday"], p.fights))
                    if h.get("area0") and p.area() != h["area0"]:
                        # Player 20: the camp's script moved the party on (the nomads: the shaman's reward, then
                        # NEW_ECL 26 onto the band, ECL 7:17 0xA1FC): the camp days are over
                        p.note("heal", "campday: the script moved the party to %d:%d" % p.area())
                        p.heal = None
                        return True, None, ""
                    return False, "e", "campday: ENCAMP"
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
                # Player 19: OP_REST_INTERRUPTS (default 5) interruptions before the stop (4:2 after event 2: every
                # rest interrupted, each fight won: p19a8)
                if h["interrupts"] >= int(os.environ.get("OP_REST_INTERRUPTS", "5")):
                    raise_stop(p, "heal: rest interrupted %d times" % h["interrupts"])
                if h["phase"] == "rounds":
                    h["phase"], h["memo_any"], h["days_memo"] = "days", False, False
            return False, "e", "heal: ENCAMP"
        M = members(p.g.mem)
        if any(m["status"] == 6 or m["status"] > 6 for m in M):
            raise_stop(p, "heal: a member is dead (a loss under the death rule: reload from the last checkpoint)")
        if self.cure and (next_cure(M) is None or getattr(self, "nocast", False)):
            return True, None, ""
        spent = self.prep and any(picks(m, M) for m in M)
        # Player 15: at the inn the camp is already open (TO REST HERE): always go through the heal, which memorizes
        # (bot.gd _rest_at_inn rests there) and leaves the camp
        hrs = (self.until - p.g.mem.ecl(0x49C9)[0]) % 24 if self.until is not None else 0
        if not self.inn and not spent and not hrs and not (needs_rest(M) if self.force else
                              any(m["status"] != 0 or m["hp"] * 2 < m["max"] for m in M)):
            return True, None, ""
        new_heal(p)
        p.heal["prep"] = self.prep
        p.heal["wait"] = self.wait
        p.heal["nocast"] = getattr(self, "nocast", False)
        p.heal["cure"] = self.cure
        p.heal["until"] = self.until
        return False, "e", "heal: ENCAMP"


class CampDay(Heal):
    """Player 19: `campday <n>` (main's bot's: camp here n days whatever comes, fighting each interruption: the
    nomads' camp, where the kobolds attack while the party rests). Each day a 1-day REST; an interrupted one counts."""
    def __init__(self, n):
        super().__init__(force=True)
        self.n = n

    def __repr__(self):
        return "campday %d" % self.n

    def next(self, p):
        if getattr(p, "heal", None) is None:
            new_heal(p)
            p.heal.update(campday=self.n, phase="days", days_memo=True, area0=p.area())
            return False, "e", "campday: ENCAMP"
        return Heal.next(self, p)


class CampCast(Heal):
    """Player 33: `campcast <CASTER> <SPELL>[|<TARGET>]` (the cluebook's pre-buff, Jeremy's note for the graveyard's
    9,1: camp on the square before a known fight and cast Bless, Prayer, Protection from Evil): ENCAMP, select the
    caster, MAGIC, CAST, the spell lit, CAST, and CAST SPELL ON WHOM the target (the caster when none is given; Bless
    and Prayer ask nobody), then leave the camp. No rest. A spell not in memory stops the run (a plan error)."""
    def __init__(self, caster, spell, target=None):
        super().__init__(force=True)
        self.caster, self.spell, self.target = caster.upper(), spell.upper(), (target or "").upper() or None

    def __repr__(self):
        return "campcast %s %s%s" % (self.caster, self.spell, "|" + self.target if self.target else "")

    def next(self, p):
        if getattr(p, "heal", None) is None:
            new_heal(p)
            p.heal.update(casts=[(self.caster, self.spell, self.target)])
            return False, "e", "campcast: ENCAMP"
        return Heal.next(self, p)


class CampScribe(Heal):
    """Player 37: `scribe <NAME> <spell>, <spell>` (Jeremy's magic-item rule: copy unknown magic-user scroll spells;
    stuck-fights.md section 4: LIRA copies Haste from the Kovel scroll): ENCAMP, select the member, MAGIC, SCRIBE
    (the member's own scrolls: "SPELLS ON SCROLLS"), each spell lit and SCRIBE (marked "*"), EXIT, the "SPELLS TO BE
    SCRIBED" list checked against the plan's, EXIT, "SCRIBE THESE SPELLS?" YES, then REST for the time offered (the
    copying is done while resting, 15 minutes a level, after any memorizing: camp_screen.gd's rules) and the spell
    book read from the record (0x33 + id - 1). A spell not on the member's scrolls, refused ("YOU CAN NOT SCRIBE THAT
    SPELL.": a level the member has no slot for) or not in the book after the rest stops the run."""
    def __init__(self, who, spells):
        super().__init__(force=True)
        self.who, self.spells = who.upper(), [x.strip().upper() for x in spells if x.strip()]

    def __repr__(self):
        return "scribe %s %s" % (self.who, ", ".join(self.spells))

    def next(self, p):
        if getattr(p, "heal", None) is None:
            new_heal(p)
            p.heal.update(scribes=[(self.who, list(self.spells))], scribe_check=(self.who, list(self.spells)))
            return False, "e", "scribe: ENCAMP"
        h = p.heal
        if h["done"] and h.get("scribe_check"):
            who, want = h.pop("scribe_check")
            m = next((m for m in members(p.g.mem) if m["name"] == who), None)
            miss = [w for w in want if not (m and MU_IDS.get(w) and m["rec"][0x33 + MU_IDS[w] - 1])]
            if miss:
                raise_stop(p, "scribe: %s not in %s's book after the rest" % (", ".join(miss), who))
            p.note("scribe", "%s's book now has %s" % (who, ", ".join(want)))
        return Heal.next(self, p)


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
# Player 27: all three levels, as bot.gd PICKS (Player 15 to 26 copied level 1 only: the original's casters went
# into every fight from Sokal Keep on with their level-2 and level-3 slots empty; README "Player 27"). Ids by
# class and level: cleric 1-8, 22-28, 36-44; magic-user 9-21, 29-35, 45-55.
CLERIC1, MU1 = range(1, 9), range(9, 22)
SPELL_NAMES = {1: "BLESS", 3: "CURE LIGHT WOUNDS", 6: "PROTECTION FROM EVIL", 15: "MAGIC MISSILE", 18: "READ MAGIC", 21: "SLEEP", 23: "HOLD PERSON",
               26: "SLOW POISON", 31: "KNOCK", 32: "MIRROR IMAGE", 34: "STINKING CLOUD", 42: "PRAYER",
               47: "FIREBALL", 48: "HASTE", 51: "LIGHTNING BOLT"}
# Player 37: the magic-user spells by name (START.EXE's table, 41 bytes a name), for SCRIBE's book check
MU_IDS = {"BURNING HANDS": 9, "CHARM PERSON": 10, "DETECT MAGIC": 11, "ENLARGE": 12, "REDUCE": 13, "FRIENDS": 14,
          "MAGIC MISSILE": 15, "PROTECTION FROM EVIL": 16, "PROTECTION FROM GOOD": 17, "READ MAGIC": 18, "SHIELD": 19,
          "SHOCKING GRASP": 20, "SLEEP": 21, "DETECT INVISIBILITY": 29, "INVISIBILITY": 30, "KNOCK": 31,
          "MIRROR IMAGE": 32, "RAY OF ENFEEBLEMENT": 33, "STINKING CLOUD": 34, "STRENGTH": 35, "BLINK": 45,
          "DISPEL MAGIC": 46, "FIREBALL": 47, "HASTE": 48, "HOLD PERSON": 49, "INVISIBILITY, 10' RADIUS": 50,
          "LIGHTNING BOLT": 51, "PROTECTION FROM EVIL, 10' RADIUS": 52, "PROTECTION FROM GOOD, 10' RADIUS": 53,
          "PROTECTION FROM NORMAL MISSILES": 54, "SLOW": 55}
PICKS1 = ((CLERIC1, 0xB2, (3, 3, 1)), (MU1, 0xB5, (21, 15)))
PICKS = ((range(1, 9), 0xB2, (3, 3, 1)), (range(22, 29), 0xB3, (23,)), (range(36, 45), 0xB4, (42,)),
         (range(9, 22), 0xB5, (21, 15)), (range(29, 36), 0xB6, (31, 34, 32)), (range(45, 56), 0xB7, (47, 48, 51)))
SLOW_POISON = 26
CLW = 3


def members(mem):
    out = []
    for i, ((s, o), name, n, hp) in enumerate(loot.party(mem)):
        r = mem.far(s, o, 0x120)
        out.append({"i": i, "name": name, "hp": r[0x11B], "max": r[0x32], "status": r[0x10C],
                    "mem": [b for b in r[0x17:0x2C] if b], "rec": r})
    return out


# Player 32: Jeremy's reload rule (board, Queues, 2026-11-20 00:40): reload on a wipe, a death, a level drain, a
# permanent ability loss, a key item lost or petrification (unless a temple cures it at a price the party can pay).
# OP_RELOAD=1 (q.sh / tries): at every walking screen the party is compared with the last checkpoint's (or the run's
# start); a breach stops the run with "RELOAD: ...", and the lab's reload loop goes on from the run's last checkpoint.
# Read from the record (ai-business-ideas research/pool-of-radiance-formats.md): abilities 0x10-0x15, class levels
# 0x96-0x9D, levels drained 0x74, status 0x10C (6 dead, 7 stoned, 8 gone). Not in the tool yet: the key items, a
# temple's cure (death and stone are always a reload here), a Restoration scroll used at once on a drain (logged).
RELOAD_RULE = os.environ.get("OP_RELOAD") == "1"


def rule_state(p):
    out = {}
    for m in members(p.g.mem):
        r = m["rec"]
        out[m["name"]] = {"abil": list(r[0x10:0x16]), "lev": sum(r[0x96:0x9E]), "drained": r[0x74],
                          "status": m["status"]}
    return out


def reload_rule(p):
    now = rule_state(p)
    base = getattr(p, "rule_base", None)
    if base is None:
        p.rule_base = now
        p.note("rule", "reload rule on: %s" % "; ".join("%s L%d %s" % (n, s["lev"], "/".join(map(str, s["abil"])))
                                                         for n, s in now.items()))
        return
    if game_won(p):
        return
    why = []
    for n, b in base.items():
        s = now.get(n)
        if s is None:
            why.append("%s gone from the party" % n)
            continue
        if s["status"] >= 6:
            why.append("%s %s" % (n, {6: "dead", 7: "stoned", 8: "gone"}.get(s["status"], "status %d" % s["status"])))
        if s["drained"] > b["drained"] or s["lev"] < b["lev"]:
            why.append("%s drained (levels %d -> %d)" % (n, b["lev"], s["lev"]))
        # CON, INT, WIS, DEX, CHA; STR (0x10) left out: a Strength spell's end brings it back down
        lost = [k for k, i in (("INT", 1), ("WIS", 2), ("DEX", 3), ("CON", 4), ("CHA", 5)) if s["abil"][i] < b["abil"][i]]
        if lost:
            why.append("%s lost %s" % (n, "/".join(lost)))
        if s["lev"] > b["lev"]:
            b["lev"] = s["lev"]          # trained since: the new levels are the ones to keep
            b["abil"] = s["abil"]
    if why and RESTORER and not getattr(p, "restoring", False) and all(" drained (" in w for w in why):
        # Player 32 (Jeremy: a drain with a Restoration scroll in the packs = use it at once and go on): one
        # Restoration a level drained, read by RESTORER (a cleric) from a clerical scroll (seen, p32s4: the scroll
        # readied with both hands free, USE, CHOOSE SPELL: CAST, CAST SPELL ON WHOM, SELECT)
        lost = []
        for n, b in base.items():
            s = now.get(n)
            if s is not None and s["lev"] < b["lev"]:
                lost += [n] * (b["lev"] - s["lev"])
        have = restorations(p)
        if lost and len(lost) <= have and RESTORER in now and now[RESTORER]["status"] == 0:
            p.note("rule", "drained %s: %d Restoration(s) of %d from the scroll, by %s" % (
                ", ".join(lost), len(lost), have, RESTORER))
            gs = [ReadyItems(RESTORER, [(False, RESTORER_WEAPON), (False, "SHIELD"), (True, RESTORER_SCROLL)])]
            for n in lost:
                # Player 37: a used-up scroll is gone: ready the next before each USE (a no-op while one is readied:
                # both hands are taken)
                gs += [ReadyItems(RESTORER, [(True, RESTORER_SCROLL)]), ReadyItems(RESTORER, [("U:" + n, RESTORER_SCROLL)])]
            gs += [ReadyItems(RESTORER, [(False, RESTORER_SCROLL), (True, RESTORER_WEAPON), (True, "SHIELD")]),
                   RestoreDone()]
            p.plan.goals[p.goal:p.goal] = gs
            p.restoring = True
            return
    if why and getattr(p, "restoring", False) and all(" drained (" in w for w in why):
        return                           # the Restorations under way
    if why:
        p.note("loss", "the reload rule: " + "; ".join(why))
        raise_stop(p, "RELOAD: %s (Jeremy's reload rule: reload from the last checkpoint)" % "; ".join(why))


RESTORER = os.environ.get("OP_RESTORER", "")            # Player 32: the cleric who reads the Restoration scroll
RESTORER_WEAPON = os.environ.get("OP_RESTORER_WEAPON", "MACE +2")
# Player 37: the words of the restorer's Restoration scrolls (ELWEN also carries a cleric scroll of three other spells)
RESTORER_SCROLL = os.environ.get("OP_RESTORER_SCROLL", "CLERICAL SCROLL").upper()


def restorations(p):
    """Restoration spells (56) on clerical scrolls (item bytes 60, 61) in the party's packs."""
    k = 0
    for (s_, o), _name, _n, _hp in loot.party(p.g.mem):
        r = p.g.mem.far(s_, o, 0x120)
        io, iseg = struct.unpack_from("<HH", r, loot.ITEMS_AT)
        for _a, it in loot.chain(p.g.mem, iseg, io):
            if "SCROLL" in loot.item(it)["name"].upper():
                k += (it[60] == 56) + (it[61] == 56)
    return k


class RestoreDone:
    """Player 32: the Restorations done: the rule checks the party again from here."""
    def __repr__(self):
        return "restore done"

    def next(self, p):
        p.restoring = False
        p.note("rule", "restored: %s" % "; ".join("%s L%d" % (n, s_["lev"]) for n, s_ in rule_state(p).items()))
        return True, None, ""


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


# Player 36: Guide 3's wilderness bands step (Jeremy 17:26; docs/strategy/poolrad.md section 3, "The wilderness bands").
# `bands on|off` (a step): on a band (6:25, 7:26, 8:27) the member with the best Charisma is lit before each step
# (Home/End on the walking screen, DS:0x5D92); at the encounter menu: the cheap humanoid kinds PARLAY with the area's
# manner (or FLEE when the party's slowest has the kind's movement and PARLAY isn't sure); the rich kinds and the beasts
# are fought when the party is rested (HP and memorized spells at 3/4 of the most seen), else FLEE when movement
# allows; the party surprised them: WAIT; nomads, merchants and centaurs: PARLAY. Movement: record 0x11C (cached).
BANDS = {"on": False, "lit_tries": 0, "spells_max": {}}
BAND_CHEAP = {"KOBOLDS": 6, "LIZARD MEN": 6, "SOLDIERS": 6, "GNOLLS": 9, "BANDITS": 9, "BUCCANEERS": 9,
              "THIEVES": 12}
BAND_TALKERS = ("NOMADS", "MERCHANTS", "CENTAURS")
BAND_MOVE = {"DRIDERS": 12, "TROLLS": 12, "MINOTAURS": 12, "TIGERS": 12, "MANTISES": 12, "GIANT MANTIS": 12,
             "ANKHEGS": 12, "ANHKHEG": 12, "BOARS": 15, "WILD BOARS": 15, "DISPLACER BEASTS": 15, "GIANT LIZARDS": 15,
             "SNAKES": 15, "STIRGES": 18, "HIPPOGRIFFS": 18, "THRI-KREEN": 18, "WYVERNS": 24, "PHASE SPIDERS": 31,
             "QUICKLINGS": 99}
BAND_MANNER = {6: ("NICE", 50), 7: ("ABUSIVE", 60), 8: ("ABUSIVE", 30)}    # area 6:25, 7:26, 8:27: the manner's value


def cha_bonus(c):
    return 0 if c < 4 else 5 * (c - 3) if c < 8 else 25 if c < 13 else {13: 30, 14: 35, 15: 40, 16: 50, 17: 55}.get(c, 60)


def band_party(p):
    M = [m for m in members(p.g.mem) if m["status"] < 6]
    for m in M:
        BANDS["spells_max"][m["name"]] = max(BANDS["spells_max"].get(m["name"], 0), len(m["mem"]))
    return M


def band_spokesman(p):
    """The walking screen on a band: the key that lights the best Charisma, or None."""
    M = band_party(p)
    if not M:
        return None
    best = max(M, key=lambda m: m["rec"][0x15])
    sel = loot.selected(p.g.mem)
    if sel == best["i"]:
        BANDS["lit_tries"] = 0          # (p36t3: the light goes back to the first member after a fight)
        return None
    if sel is None or BANDS["lit_tries"] >= 8:
        return None
    BANDS["lit_tries"] += 1
    return ("end" if best["i"] > sel else "home"), "bands: light %s (CHA %d) before the next step" % (
        best["name"], best["rec"][0x15])


def band_choice(scr, p):
    """The encounter menu on a band: (choice word, why)."""
    text = scr.get("text", "")
    items = scr["bottom"].split()
    M = band_party(p)
    slow = min((m["rec"][0x11C] for m in M), default=0)
    # (p36t1: "YOU SURPRISE A GROUP OF WILD BOARS."; 8:29's "YOU HAVE SURPRISED A PARTY OF KOBOLDS"; "YOU SPOT A GROUP OF ...")
    # (p36t3: "YOU ARE SURPRISED BY A GROUP OF THRI- KREENS.": the reader splits the hyphen)
    text = text.replace("- ", "-")
    m = re.search(r"(?:SPOT|SURPRISED?(?: BY)?|ENCOUNTER(?:ED)?) (?:A |AN )?(?:GROUP|PARTY|BAND) OF ([A-Z' -]+)", text)
    kind = m.group(1).strip() if m else ""
    sel = loot.selected(p.g.mem)
    lit = next((x for x in M if x["i"] == sel), None)
    cha = lit["rec"][0x15] if lit else 0
    manner, val = BAND_MANNER.get(p.area()[0], ("ABUSIVE", 30))
    sure = val + 1 + cha_bonus(cha) >= 100
    BANDS["manner"] = manner
    rested = all(x["hp"] * 4 >= x["max"] * 3 for x in M) and \
        sum(len(x["mem"]) for x in M) * 4 >= sum(BANDS["spells_max"].get(x["name"], 0) for x in M) * 3
    why = "bands: %s [%s] (slowest move %d, lit %s CHA %d, %s %s, rested %s)" % (
        kind or "?", " ".join(text.split())[:70], slow, lit["name"] if lit else "?", cha, manner, "sure" if sure else "not sure", rested)
    if re.search(r"YOU (?:HAVE )?SURPRISED? (?!BY)", text) and "WAIT" in items:
        return "WAIT", why + ": the party surprised them, WAIT"
    if any(t in kind for t in BAND_TALKERS) and "PARLAY" in items:
        return "PARLAY", why + ": they greet and leave"
    cheap = next((v for k, v in BAND_CHEAP.items() if k in kind), None)
    if cheap is not None:
        if "FLEE" in items and slow >= cheap and not sure:
            return "FLEE", why + ": cheap, PARLAY not sure, FLEE (movement %d >= %d)" % (slow, cheap)
        if "PARLAY" in items:
            return "PARLAY", why + ": cheap, PARLAY"
        if "FLEE" in items and slow >= cheap:
            return "FLEE", why + ": cheap, FLEE"
        return "COMBAT", why + ": cheap, no PARLAY or FLEE"
    mv = next((v for k, v in BAND_MOVE.items() if k in kind), 12)
    if rested:
        return "COMBAT", why + ": rich kind, rested: fight"
    if "FLEE" in items and slow >= mv:
        return "FLEE", why + ": rich kind, not rested, FLEE (movement %d >= %d)" % (slow, mv)
    return "COMBAT", why + ": rich kind, not rested, FLEE can't get away"


PICK_OVERRIDE = {}    # Player 30: `picks <NAME> <spell>, ...`: these first, in order, into the member's free slots


def picks(m, M=None):
    """bot.gd _pick_spells: the spells to queue in the member's free slots of levels 1-3 (names), cleric levels
    first; with the party M, one Slow Poison kept in the party (Chat 31's rule: the first free level-2 cleric slot
    of a member who knows it, when nobody has one memorized or queued). Player 30: a plan's `picks` line for the
    member goes first (known spells only, while their level has a free slot); the bot's picks fill the rest."""
    if m["status"] != 0:
        return []
    out = []
    over = PICK_OVERRIDE.get(m.get("name"))
    if over:
        ids_of = {v: k for k, v in SPELL_NAMES.items()}
        free = {slot: max(0, m["rec"][slot] - sum(1 for b in m["mem"] if (b & 0x7F) in ids)) for ids, slot, _ in PICKS}
        for name in over:
            sid = ids_of.get(name)
            slot = next((sl for ids, sl, _ in PICKS if sid in ids), None)
            if sid and slot and free.get(slot, 0) > 0 and m["rec"][0x33 + sid - 1]:
                out.append(name)
                free[slot] -= 1
        m = dict(m, mem=list(m["mem"]) + [ids_of[n] for n in out])
    slow = M is None or any(SLOW_POISON in [b & 0x7F for b in o["mem"]] for o in M)
    for ids, slot, order in PICKS:
        n = max(0, m["rec"][slot] - sum(1 for b in m["mem"] if (b & 0x7F) in ids))
        if not slow and slot == 0xB3 and n > 0 and m["rec"][0x33 + SLOW_POISON - 1]:
            out.append(SPELL_NAMES[SLOW_POISON])
            slow, n = True, n - 1
        known = [s for s in order if m["rec"][0x33 + s - 1]]     # the spell book: a byte per spell id
        if not known:
            continue
        for k in range(n):
            out.append(SPELL_NAMES[known[k % len(known)]])
    return out


class Advance:
    """Player 35: `advance <NAME>,<NAME>|none`: from here, the members who MOVE toward the enemy when nothing is in reach
    (tactics.ADVANCE; Jeremy's line rule); `none`: everyone holds (Sokal's doorway)."""
    def __init__(self, names):
        self.names = [] if names.strip().lower() == "none" else [n.strip().upper() for n in names.split(",") if n.strip()]

    def __repr__(self):
        return "advance %s" % (",".join(self.names) or "none")

    def next(self, p):
        import tactics
        tactics.ADVANCE[:] = self.names
        p.note("tactics", "advance: %s" % (",".join(self.names) or "none"))
        return True, None, ""


class Exit:
    def __init__(self, area):
        self.area = area

    def __repr__(self):
        return "exit to %d:%d" % self.area

    def next(self, p):
        if p.area() == self.area:
            return True, None, ""
        raise_stop(p, "exit: still in %d:%d at the walking screen" % p.area())


class AnswerFrom:
    """Player 16: `answerfrom <words>|<choice>`: from this point of the plan on, this answer comes before the
    others (Kuto's Well: DO YOU WANT TO CLIMB DOWN is NO while events are left, as main's bot, then YES)."""
    def __init__(self, words, choice, src):
        self.a = (words, choice, src)

    def __repr__(self):
        return "answerfrom %s|%s" % self.a[:2]

    def next(self, p):
        p.plan.answers.insert(0, self.a)
        return True, None, ""


# Player 27: main's bot's spare gear (bot.gd's town "sell": "sold spare gear"): an item nobody has readied, not a
# keeper (loot.worth_taking's magic and quest words), not the member's missile kit (ammunition; the best launcher or
# thrown weapon the member can use), priced 2 or more. The ITEMS file: 16 bytes a type (slot +0, class flags +13,
# flags +14: 0x08 launcher, 0x10 thrown; ours' item_types.gd); a member's class flags at record +0xB0.
_ITEM_TYPES = None


def _item_types():
    global _ITEM_TYPES
    if _ITEM_TYPES is None:
        d = open(os.path.join(orig.GAME, "ITEMS"), "rb").read()
        _ITEM_TYPES = [d[i:i + 16] for i in range(2, len(d) - 15, 16)]
    return _ITEM_TYPES


def _keeper(it):
    up = it["name"].upper()
    return it["plus"] != 0 or "+" in up or it["type"] in loot.QUEST_ITEM_TYPES or any(w in up for w in loot.LOOT_WORDS)


def spare_gear(rec, items):
    """bot.gd's spare gear of one member: [index in the item list] to sell. items: [(item dict, readied byte)]."""
    T = _item_types()

    def missile(it):
        t = T[it["type"]] if it["type"] < len(T) else bytes(16)
        return t[0] == 0 and rec[0xB0] & t[13] and t[14] & 0x18

    def kit(i, it):
        if it["type"] in (28, 73):
            return True
        if not missile(it):
            return False
        for k, (o, _) in enumerate(items):
            if k != i and missile(o) and (o["plus"] > it["plus"] or o["plus"] == it["plus"] and (
                    o["price"] > it["price"] or o["price"] == it["price"] and k < i)):
                return False
        return True
    return [i for i, (it, rd) in enumerate(items) if not rd and not _keeper(it) and not kit(i, it) and it["price"] >= 2]


def game_won(p):
    """Player 29: main's plan's `won 4ABA 254` (Chat 33): Tyranthraxus fallen (5:7 0xA815 writes 254 to 0x4ABA); a
    member who died in that fight ends the run as won, not a reload (the death rule is for fights the run goes on from)."""
    try:
        return p.g.mem.ecl(0x4ABA, 1)[0] == 254
    except Exception:
        return False


class ShortcutWin:
    """Player 27: `shortcutwin <area> <x,y>` (Q27 (a)): arms the logged shortcut win for the next fight that starts
    with the party on that square (game.py _shortcut_win: the monsters' HP 0 at its first poll)."""
    def __init__(self, area, xy, n=1):
        self.area, self.xy, self.n = area, xy, n

    def __repr__(self):
        return "shortcutwin %d:%d %d,%d" % (self.area + self.xy) + (" %d" % self.n if self.n > 1 else "")

    def next(self, p):
        p.g.shortcut = (self.area, self.xy)
        p.g.shortcut_more = self.n - 1     # Player 29: the next n fights there
        p.note("shortcut", "armed: the next fight at %d:%d %d,%d is won by shortcut (logged)" % (self.area + self.xy))
        return True, None, ""


class TacticsStep:
    """Player 30: `tactics on|off`: the tactical mode (tactics.py) from here on."""
    def __init__(self, on):
        self.on = on

    def __repr__(self):
        return "tactics %s" % ("on" if self.on else "off")

    def next(self, p):
        p.tactics.on = self.on
        p.g.take_control = self.on
        p.note("tactics", "tactical mode %s" % ("on" if self.on else "off"))
        return True, None, ""


class Focus:
    """Player 36: `focus <kind>,...|none`: tactics.FOCUS from here (the throne room's trolls first)."""
    def __init__(self, kinds):
        self.kinds = [] if kinds.strip().lower() == "none" else [k.strip().upper() for k in kinds.split(",") if k.strip()]

    def __repr__(self):
        return "focus %s" % (",".join(self.kinds) or "none")

    def next(self, p):
        import tactics
        tactics.FOCUS[:] = self.kinds
        p.note("tactics", "focus: %s" % (",".join(self.kinds) or "none"))
        return True, None, ""


class ScrollsStep:
    """Player 37: `scrolls <MEMBER> <spell>, <spell>|none`: tactics.SCROLLS for that member from here (a spell per
    readied scroll the member should USE in fights, each once)."""
    def __init__(self, rest):
        who, _, sp = rest.strip().partition(" ")
        self.who = who.replace("_", " ").upper()
        self.spells = [] if sp.strip().lower() == "none" else [x.strip().upper() for x in sp.split(",") if x.strip()]

    def __repr__(self):
        return "scrolls %s %s" % (self.who, ", ".join(self.spells) or "none")

    def next(self, p):
        import tactics
        tactics.SCROLLS[self.who] = list(self.spells)
        p.note("tactics", "scrolls: %s %s" % (self.who, ", ".join(self.spells) or "none"))
        return True, None, ""


class BandsStep:
    """Player 36: `bands on|off`: Guide 3's band rule (BANDS) from here on."""
    def __init__(self, on):
        self.on = on

    def __repr__(self):
        return "bands %s" % ("on" if self.on else "off")

    def next(self, p):
        BANDS["on"] = self.on
        p.note("bands", "band rule %s" % ("on" if self.on else "off"))
        return True, None, ""


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
            if any(m["status"] >= 6 for m in members(p.g.mem)) and not game_won(p):
                # Player 25: never a checkpoint with a member dead or gone (p25l3's s26g6: BRAM and DORN drained
                # away by 4:10's wight in a fight on a walk's last step, which no walk saw)
                raise_stop(p, "checkpoint %s: a member is dead or gone (a loss under the death rule: reload from the"
                              " last checkpoint)" % self.name)
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
        self.pooltakes = []      # Player 38: per shop visit, [(member, n or None for the rest, coin)] (`pooltake`)
        self.buy_purse = False   # Player 38: `buypurse on`: no POOL before a purchase (the buyer's own purse pays and
                                 # comes back in platinum and gold: the playbook's coin change)
        self.sells = []          # Player 15: `sell gems`: one per shop visit
        self.memos = []          # Player 12: one list of (member, [spell names]) per camp (the inn's) visit
        self.temple_cures = []   # Player 25: `templecure <service>` (bot.gd _temple_cures)
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
        rows = st["rows"]
        if scr.get("bottom", "").startswith("CHOOSE SPELL:") and "LEARN" in scr.get("bottom", ""):
            # Player 21: a magic-user's training asks for the new spell (<NAME>'S SPELLS TO CHOOSE FROM, ELWEN at p21b3,
            # LIRA at p21b4; the title's font isn't the reader's, so the bottom line tells): main's bot's choice,
            # bot.gd LEARN_ORDER (the first of its list on offer, else the first offered); End / Home move the
            # light (the original's vertical lists), LEARN takes it. The seq goes on after.
            items = [(r, rows[r].strip("? ").strip()) for r in range(1, 23)]
            items = [(r, t) for r, t in items if t and not re.match(r"\d+(ST|ND|RD|TH) LEVEL", t)]
            if not items:
                raise_stop(p, "seq %s: a spell list with no spells" % name)
            names = [t for _, t in items]
            # Player 35 (p35e1: FIREBALL was on the list's next page, INVISIBILITY taken): a plan's `learn` spell not on
            # this page: NEXT, up to four pages, before the bot's order
            if LEARN_FIRST and not any(s in names for s in LEARN_FIRST) and "NEXT" in scr.get("bottom", "").split() \
                    and getattr(p, "learn_pages", 0) < 4:
                p.learn_pages = getattr(p, "learn_pages", 0) + 1
                return "n", "seq %s: NEXT page for %s" % (name, ", ".join(LEARN_FIRST))
            p.learn_pages = 0
            want = next((s for s in LEARN_FIRST + LEARN_ORDER if s in names), names[0])
            lit = [i for i, (r, _) in enumerate(items) if screens._rowcol(st["im"], r) == screens.WHITE]
            if not lit:
                raise_stop(p, "seq %s: no spell lit on the spell list" % name)
            d = names.index(want) - lit[0]
            if d == 0:
                return "l", "seq %s: LEARN %s (main's bot's LEARN_ORDER)" % (name, want)
            return ("end" if d > 0 else "home"), "seq %s: to %s" % (name, want)
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
        if p.tactics.on:     # Player 30: the tactical mode's screens (a member's menu, CAST's list, AIM)
            k = p.tactics.answer(scr, st, p)
            if k:
                return k
        if getattr(p, "seq", None):
            k, why = self._seq(scr, st, p)
            if k:
                return k, why
        h = getattr(p, "heal", None)
        gs = self.goals
        if h is None and scr["bottom"].split()[:1] == ["CAMP:"] and p.goal + 1 < len(gs) \
                and isinstance(gs[p.goal], Walk) and isinstance(gs[p.goal + 1], Heal) and gs[p.goal + 1].inn:
            # Player 14: the inn (TO REST HERE, WHO WILL PAY) opens its camp before the walk sees its square.
            if any(m["status"] >= 6 for m in members(p.g.mem)):
                raise_stop(p, "heal: a member is dead (a loss under the death rule: reload from the last checkpoint)")
            p.log("GOAL done: %s (the inn's camp)" % gs[p.goal])
            p.goal += 1
            p.goal_key = p.g.nkeys
            new_heal(p)
            p.heal["prep"], p.heal["wait"] = gs[p.goal].prep, gs[p.goal].wait     # Player 15
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
        ct = getattr(p, "cointrade", None)
        if ct is not None and not ct["over"]:
            k = self._cointrade(scr, st, p, ct)
            if k:
                return k
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
                spec = getattr(p, "ready_spec", None)
                if spec is not None:      # Player 32: `ready`: the listed toggles only, in order
                    todo = []
                    # an unidentified item shows without its plus (p32b12: MACE for the Mace +2): the rows follow
                    # the member's item list (record +0xC8), so "<words> +<n>" is matched on the record's plus
                    try:
                        (ms, mo) = loot.party(p.g.mem)[p.readying][0]
                        mr = p.g.mem.far(ms, mo, 0x120)
                        io, iseg = struct.unpack_from("<HH", mr, loot.ITEMS_AT)
                        pluses = [loot.item(it)["plus"] for _a, it in loot.chain(p.g.mem, iseg, io)]
                    except Exception:
                        pluses = []
                    order = sorted(rows)

                    def holds(r, n, words):
                        m = re.match(r"(.*?)\s*\+(\d+)$", words)
                        if not m:
                            return words in n.upper()
                        i = order.index(r)
                        return m.group(1) in n.upper() and i < len(pluses) and pluses[i] == int(m.group(2))
                    while spec and not todo:
                        want, words = spec[0]
                        if isinstance(want, str):     # ("T:<TO>" / "D", words): TRADE / DROP the first NO row
                            hit = [r for r, (y, n) in sorted(rows.items()) if holds(r, n, words)
                                   and (y == "NO" or want.startswith("U:"))]
                            if want.startswith("U:"):
                                # Player 37: USE the readied one first (a scroll must be readied; p37: CEDRIC's
                                # one-spell Restoration first, the two-spell ones from the chest after it)
                                hit = [r for r in hit if rows[r][0] == "YES"] + [r for r in hit if rows[r][0] != "YES"]
                            if not hit:
                                p.note("ready", "nothing to %s for %s" % ("drop" if want == "D" else "trade", words))
                                spec.pop(0)
                                continue
                            if len(lit) == 1 and lit[0] == hit[0]:
                                spec.pop(0)
                                if want == "D":
                                    return "d", "drop: DROP %s" % rows[hit[0]][1]
                                if want.startswith("U:"):
                                    return "u", "use: USE %s" % rows[hit[0]][1]
                                return "t", "trade: TRADE %s" % rows[hit[0]][1]
                            if len(lit) != 1:
                                raise_stop(p, "trade: no single lit item (rows %s)" % lit)
                            return ("end" if hit[0] > lit[0] else "home"), "trade: light to %s" % rows[hit[0]][1]
                        hit = [r for r, (y, n) in sorted(rows.items()) if holds(r, n, words)
                               and (y == "YES") != want and (r, want) not in p.ready_tried]
                        if hit:
                            todo = [hit[0]]
                            if lit and lit[0] == hit[0]:
                                p.ready_tried.add((hit[0], want))
                                spec.pop(0)
                        else:
                            p.note("ready", "%s: nothing to %s for %s" % (
                                loot.party(p.g.mem)[p.readying][1], "ready" if want else "unready", words))
                            spec.pop(0)
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
        if self.temple_cures:
            r = self._templecure(scr, st, p)
            if r:
                return r
        if self.sells and getattr(p, "sell_visit", 0) < len(self.sells):
            r = self._sell(scr, st, p)
            if r:
                return r
        if self.buys and getattr(p, "buy_visit", 0) < len(self.buys):
            bw = scr["bottom"].split()
            if kind == "yesno" and "SHOW YOU OUR WARES" in scr.get("text", ""):
                return "y", "shop: YES (purchases planned)"
            if kind == "hmenu" and (bw[:2] == ["BUY", "VIEW"] or bw[:2] == ["ITEMS:", "BUY"]):
                return self._buy(scr, st, p)
            # The pool's coins back to the last buyer (ours' POOL gives every coin to the buyer): TAKE, each coin
            # type in turn, its whole amount typed.
            pt = getattr(p, "ptake_cur", None)
            if " ".join(bw[:4]) == "SELECT TYPE OF COIN" and pt is not None and pt[1] is not None:
                # Player 38: `pooltake`: this member takes n of one coin kind from the pool (999 a round)
                name, n, coin, j = pt[:4]
                now = held_coins(p.g.mem, j, coin)
                if pt[4] is not None:
                    moved = now - pt[4]
                    pt[5] += moved
                    pt[4] = None
                    p.note("pooltake", "%s took %d %s (%d of %d)" % (name, moved, COIN_WORDS[coin], pt[5], n))
                    if moved <= 0:
                        pt[6] += 1
                rows, lit = [], None
                for r in range(1, 12):
                    m = re.search(r"\b(%s)\s+(\d+)" % "|".join(COIN_WORDS), st["rows"][r])
                    if m:
                        if screens._rowcol(st["im"], r, 0, 30 * 8) == screens.WHITE:
                            lit = len(rows)
                        rows.append((m.group(1), int(m.group(2))))
                kinds = [k for k, _v in rows]
                if pt[5] >= n or COIN_WORDS[coin] not in kinds or pt[6] >= 2:
                    pt[7] = True
                    return "e", "pooltake: %s done (%d %s)" % (name, pt[5], COIN_WORDS[coin])
                if lit is None:
                    raise_stop(p, "pooltake: no coin lit on the pool's list (%s)" % rows)
                d = kinds.index(COIN_WORDS[coin]) - lit
                if d:
                    return ("end" if d > 0 else "home"), "pooltake: light %s" % COIN_WORDS[coin]
                pt[4] = now
                p.coin_amt = str(min(n - pt[5], rows[kinds.index(COIN_WORDS[coin])][1], 999))
                return "enter", "pooltake: %s takes %s %s" % (name, p.coin_amt, COIN_WORDS[coin])
            if " ".join(bw[:4]) == "SELECT TYPE OF COIN":
                m = re.match(r"\s*([A-Z]+)\s+(\d+)", st["rows"][2].strip("?\\ "))
                if not m:
                    return "e", "shop: pool empty"
                # Player 17: the amount field takes three digits (p17a4: 1036 platinum typed as 103, then stuck):
                # 999 at most a round, the next round takes the rest
                p.coin_amt = str(min(int(m.group(2)), 999))
                if getattr(p, "coin_last", None) == m.group(2):
                    # Player 17: the TAKE left the pool as it was (more than the member can carry): EXIT, then SHARE
                    p.take_refused, p.coin_last = True, None
                    return "e", "shop: the TAKE was refused (%s %s left), EXIT" % (m.group(2), m.group(1))
                p.coin_last = m.group(2)
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
        bw0 = scr["bottom"].split()
        if BANDS["on"] and kind == "hmenu" and "ABUSIVE" in bw0 and "NICE" in bw0 and BANDS.get("manner") \
                and p.on_band():
            # Player 39 (p39f2: the lizard men's PARLAY at 7:26 answered NICE by the plan's `answer SLY|NICE`, meant
            # for another screen): the band rule's manner comes before the plan's answers
            return self.choose(scr, BANDS["manner"]), "bands: PARLAY %s" % BANDS["manner"]
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
                limit = None
                m = re.match(r"(.*)\*(\d+)$", choice)
                if m:
                    # Player 19: a counted answer (`<choice>*<n>`): skipped once given n times
                    choice, limit = m.group(1), int(m.group(2))
                    if p.answer_counts.get((words, choice), 0) >= limit:
                        continue
                k = self.choose(scr, choice)
                if k:
                    if limit is not None and k not in ("end", "home"):     # the key that answers, not a move
                        p.answer_counts[(words, choice)] = p.answer_counts.get((words, choice), 0) + 1
                        return k, "%s: %s|%s (%d of %d)" % (src, words, choice, p.answer_counts[(words, choice)], limit)
                    return k, "%s: %s|%s" % (src, words, choice)
        if BANDS["on"] and p.on_band():
            if kind == "encounter":
                choice, why = band_choice(scr, p)
                k = self.choose(scr, choice)
                if k:
                    return k, why
            bw = scr["bottom"].split()
            if kind == "hmenu" and "ABUSIVE" in bw and "NICE" in bw and BANDS.get("manner"):
                return self.choose(scr, BANDS["manner"]), "bands: PARLAY %s" % BANDS["manner"]
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
                # Player 29: a member who refused an item (overloaded) refuses any as heavy or heavier: skip
                # them (p28j1: a 40-item smithy pile offered each heavy item to six overloaded members).
                heavy = min([s[4] for s, m in t.setdefault("refused", set()) if m == j] or [1 << 30])
                if P[j][2] < loot.LIMIT and P[j][3] > 0 and (sig, j) not in t["refused"] and it["weight"] < heavy:
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

    # -- Player 15: `sell gems`: main's bot's shop visit (bot.gd: "appraised and sold gems and jewellery"): every
    # member with gems or jewellery (record 0x92 / 0x94, money[5] / money[6]) in party order: APPRAISE, GEMS or
    # JEWELRY, SELL each, until none is left; then the shop's EXIT (or the visit's `buy` line goes on) -----------
    def _templecure(self, scr, st, p):
        """Player 25: `templecure <service>` (bot.gd _temple_cures: Stone to Flesh, Cure Disease, Neutralize Poison
        for whoever needs them): at a temple's HEAL VIEW POOL APPRAISE EXIT, each member in turn selected (End /
        Home), HEAL, the service lit on the list (rows 4-12; End / Home), HEAL; the original asks CAST CURE ANYWAY
        for a member who doesn't need it (NO) and PAY FOR CURE for one who does (YES; the member's own coins); then
        EXIT the list. The plan's answer EXITs the temple after the last member."""
        bw = scr["bottom"].split()
        b = " ".join(bw)
        if scr["kind"] == "walking":
            p.tc = None
            return None
        mem = p.g.mem
        P = loot.party(mem)
        tc = getattr(p, "tc", None)
        if b.startswith("HEAL VIEW POOL"):
            if tc is None:
                tc = p.tc = {"todo": [(j, c) for j in range(len(P)) for c in self.temple_cures], "cur": None}
            if tc["cur"] is not None:
                tc["todo"].pop(0)
                tc["cur"], tc["asked"] = None, None
            if not tc["todo"]:
                return None
            j, c = tc["todo"][0]
            sel = loot.selected(mem)
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "templecure: select %s" % P[j][1]
            tc["cur"] = (j, c)
            return "h", "templecure: HEAL for %s" % P[j][1]
        if tc is None or tc.get("cur") is None:
            return None
        j, c = tc["cur"]
        if bw[:2] == ["HEAL", "EXIT"]:
            if tc.get("asked") == (j, c):
                return "e", "templecure: %s done, back to the menu" % P[j][1]
            rows = st["rows"]
            names = {r: str(rows[r]).strip("?\\ ").strip() for r in range(4, 14)}
            target = [r for r, n in names.items() if n.startswith(c)]
            lit = [r for r, n in names.items() if n and screens._rowcol(st["im"], r) == screens.WHITE]
            if not target:
                raise_stop(p, "templecure: no %s on the list (%s)" % (c, [n for n in names.values() if n]))
            if len(lit) == 1 and lit[0] != target[0]:
                return ("end" if target[0] > lit[0] else "home"), "templecure: light to %s" % c
            tc["asked"] = (j, c)
            return "h", "templecure: HEAL %s for %s" % (c, P[j][1])
        if "ANYWAY" in b:
            p.note("temple", "%s: %s not needed" % (P[j][1], c))
            return "n", "templecure: %s doesn't need %s (CAST CURE ANYWAY: NO)" % (P[j][1], c)
        if "PAY FOR CURE" in b:
            p.note("temple", "%s: %s bought" % (P[j][1], c))
            return "y", "templecure: PAY for %s's %s" % (P[j][1], c)
        return None

    def _sell(self, scr, st, p):
        mem = p.g.mem
        bw = scr["bottom"].split()
        P = loot.party(mem)

        def held(j):
            r = mem.far(P[j][0][0], P[j][0][1], 0x120)
            return struct.unpack_from("<H", r, 0x92)[0], struct.unpack_from("<H", r, 0x94)[0]
        if scr["kind"] == "yesno" and "SHOW YOU OUR WARES" in scr.get("text", ""):
            return "y", "sell: YES (gems to sell)"
        val = [str(r) for r in (st["rows"].values() if isinstance(st["rows"], dict) else st["rows"]) if "VALUED AT" in str(r)]
        if bw[:2] == ["SELL", "KEEP"] or val and ("SELL" in bw or "SELL" in str(st["rows"][24])):
            # the original: "THE GEM IS VALUED AT 500 GP." and row 24 "YOU CAN : SELL" (ours: SELL KEEP)
            return "s", "sell: SELL (%s)" % (val[0].strip("?\\ ") if val else "")
        sel = loot.selected(mem)
        if bw[:1] == ["APPRAISE"] or "GEMS" in bw and "JEWELRY" in bw:     # the original drops a word when none left
            g, jw = held(sel) if sel is not None else (0, 0)
            if g:
                return "g", "sell: GEMS (%s has %d)" % (P[sel][1], g)
            if jw:
                return "j", "sell: JEWELRY (%s has %d)" % (P[sel][1], jw)
            return "e", "sell: %s's gems and jewellery sold" % P[sel][1]
        gear = "gear" in self.sells[getattr(p, "sell_visit", 0)]
        if gear and not any(sum(held(j)) for j in range(len(P))):
            r = self._sell_gear(scr, st, p, P, sel, bw)
            if r:
                return r
        if scr["kind"] == "hmenu" and bw[:2] == ["BUY", "VIEW"]:
            todo = [j for j in range(len(P)) if sum(held(j))]
            if not todo and "share" in self.sells[getattr(p, "sell_visit", 0)] and not getattr(p, "sell_shared", False):
                # `sell gems share`: everyone's coins to the pile (POOL with each member selected), then SHARE: the
                # Player's way to fund every trainee (main's bot moves coins to the trainee itself, bot.gd _fund)
                pooled = getattr(p, "sell_pooled", set())
                p.sell_pooled = pooled
                left = [j for j in range(len(P)) if j not in pooled]
                if left:
                    j = left[0]
                    if sel != j:
                        return ("end" if sel is None or j > sel else "home"), "sell: select %s to POOL" % P[j][1]
                    pooled.add(j)
                    return "p", "sell: POOL (%s)" % P[j][1]
                p.sell_shared = True
                return "s", "sell: SHARE the pile"
            if not todo:
                p.note("sell", "gems and jewellery sold: %s" % " ".join(
                    "%s %d" % (P[j][1], struct.unpack_from("<H", mem.far(P[j][0][0], P[j][0][1], 0x120), 0x88 + 8)[0])
                    for j in range(len(P))))
                p.sell_visit = getattr(p, "sell_visit", 0) + 1
                p.sell_shared, p.sell_pooled, p.gear_tries = False, set(), {}
                if self.buys and getattr(p, "buy_visit", 0) < len(self.buys):
                    if not self.buys[p.buy_visit if hasattr(p, "buy_visit") else 0]:
                        # Player 17: an empty `buy` line is this visit's (the sale's): nothing bought, EXIT
                        p.buy_visit = getattr(p, "buy_visit", 0) + 1
                        return "e", "sell: done, the visit's `buy` is empty, EXIT the shop"
                    return None
                return "e", "sell: done, EXIT the shop"
            j = todo[0]
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "sell: select %s" % P[j][1]
            return "a", "sell: APPRAISE (%s: %d gems, %d jewellery)" % ((P[j][1],) + held(j))
        return None

    def _sell_gear(self, scr, st, p, P, sel, bw):
        """Player 27: `sell gems share gear`: after the gems, each member's spare gear (spare_gear) sold at the shop:
        the member selected, VIEW, ITEMS, the item lit (End / Home), SELL, YES ("IS IT A DEAL?"); the light stays on
        the next row. An item offered twice and still there is left (the shop wouldn't take it). None when done."""
        mem = p.g.mem
        tries = getattr(p, "gear_tries", None)
        if tries is None:
            tries = p.gear_tries = {}

        def todo(j):
            (s_, o_), r = P[j][0], mem.far(P[j][0][0], P[j][0][1], 0x120)
            io, iseg = struct.unpack_from("<HH", r, loot.ITEMS_AT)
            items = [(loot.item(x), x[52]) for _, x in loot.chain(mem, iseg, io)]
            idx = [i for i in spare_gear(r, items) if tries.get((j, len(items), i, items[i][0]["name"]), 0) < 2]
            return idx, items
        b = " ".join(bw)
        if "IS IT A DEAL" in b:
            got = " ".join(str(st["rows"][r]).strip("?\\ ") for r in (21, 22))
            p.note("sell", "%s: %s" % (P[sel][1] if sel is not None else "?", got))
            return "y", "sell gear: YES (%s)" % got
        if scr["kind"] == "hmenu" and bw[:2] == ["BUY", "VIEW"]:
            left = [j for j in range(len(P)) if todo(j)[0]]
            if not left:
                return None
            j = left[0]
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "sell gear: select %s" % P[j][1]
            return "v", "sell gear: VIEW (%s)" % P[j][1]
        if bw[:1] == ["VIEW:ITEMS"]:
            return ("i", "sell gear: ITEMS (%s)" % P[sel][1]) if sel is not None and todo(sel)[0] else \
                ("e", "sell gear: %s done, EXIT the sheet" % (P[sel][1] if sel is not None else "?"))
        if "SELL" in bw and "ITEMS" in str(st["rows"][1]):
            idx, items = todo(sel)
            if not idx:
                return "e", "sell gear: %s's list done, EXIT" % P[sel][1]
            i = idx[0]
            target = 5 + i
            lit = [r for r in range(5, 21) if screens._rowcol(st["im"], r) == screens.WHITE]
            if len(lit) != 1:
                raise_stop(p, "sell gear: no single lit item (rows %s)" % lit)
            if lit[0] != target:
                return ("end" if target > lit[0] else "home"), "sell gear: light to %s" % items[i][0]["name"]
            k = (sel, len(items), i, items[i][0]["name"])
            tries[k] = tries.get(k, 0) + 1
            return "s", "sell gear: SELL %s" % items[i][0]["name"]
        return None

    # -- Player 12: BUY (`buy` lines; the shop's list is the loot pointer DS:0x6810, the buyer DS:0x5D92) ----
    def _cointrade(self, scr, st, p, ct):
        """Player 38: the money TRADE's screens (CoinTrade)."""
        bw = scr["bottom"].split()
        b = scr["bottom"]
        name = COIN_WORDS[ct["coin"]]
        now = held_coins(p.g.mem, ct["j"], ct["coin"])
        if ct["before"] is not None and not b.startswith("HOW MUCH"):
            moved = ct["before"] - now
            ct["moved"] += moved
            ct["before"] = None
            if moved <= 0:
                ct["still"] += 1
                p.note("coins", "the TRADE of %s moved nothing (the receiver's load word at his most?)" % name)
            else:
                p.note("coins", "%d %s moved (%d of %d)" % (moved, name, ct["moved"], ct["n"]))
        done = ct["moved"] >= ct["n"] or now == 0 or ct["still"] >= 2
        if bw[:1] and bw[0].startswith("VIEW:"):
            if done:
                ct["over"] = True
                return "e", "coins: EXIT the sheet"
            if "TRADE" not in bw:
                raise_stop(p, "coins: no TRADE on the view menu (%s)" % b)
            return "t", "coins: TRADE (money)"
        if scr["kind"] == "member" and "TRADE TO" in scr.get("question", ""):
            if done:
                return "e", "coins: EXIT TRADE TO?"
            names = [x.upper() for x in scr["names"]]
            if ct["to"] not in names or scr["highlight"] is None:
                raise_stop(p, "coins: %s not on TRADE TO? (%s)" % (ct["to"], names))
            d = names.index(ct["to"]) - scr["highlight"]
            return ("s" if d == 0 else "end" if d > 0 else "home"), "coins: TRADE TO? %s" % ct["to"]
        if " ".join(bw[:4]) == "SELECT TYPE OF COIN":
            if done:
                return "e", "coins: EXIT the coin choice"
            rows, lit = [], None
            for r in range(5, 15):
                m = re.search(r"\b(%s)\s+(\d+)" % "|".join(COIN_WORDS), st["rows"][r])
                if m:
                    if screens._rowcol(st["im"], r, 8 * 8, 30 * 8) == screens.WHITE:
                        lit = len(rows)
                    rows.append(m.group(1))
            if name not in rows:
                raise_stop(p, "coins: no %s on the coin choice (%s)" % (name, rows))
            if lit is None:
                raise_stop(p, "coins: no coin lit (%s)" % rows)
            d = rows.index(name) - lit
            if d:
                return ("end" if d > 0 else "home"), "coins: light %s (row %d)" % (name, lit)
            ct["before"], ct["typed"], ct["same"] = now, None, 0
            ct["amt"] = str(min(ct["n"] - ct["moved"], now))
            return "enter", "coins: %s chosen (%d held)" % (name, now)
        if b.startswith("HOW MUCH") and ct["before"] is not None:
            typed = b.split("?", 1)[1].strip() if "?" in b else ""
            amt = ct["amt"]
            if typed == ct["typed"]:
                ct["same"] += 1
            ct["typed"] = typed
            if typed == amt or len(typed) >= len(amt) or ct["same"] >= 4:
                if typed != amt:
                    p.note("coins", "the amount field took %r of %s" % (typed, amt))
                return "enter", "coins: %s typed" % (typed or "nothing")
            return amt[len(typed)], "coins: amount %s" % amt
        return None

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
                # Player 17: main's bot logs the refusal (c34d: "buy Brass Mirror for ARN: OVERLOADED.") and goes on
                left.pop(0)
                p.buy_pages, p.buy_dir = 0, "n"
                p.note("buy", "%s not bought by %s (no gold, or a full or overloaded pack): skipped, as main's bot"
                       % (name, P[j][1]))
        if not left:
            if menu == "ITEMS:":
                return "e", "buy: the visit's list done, back to the menu"
            pts = self.pooltakes[p.buy_visit] if p.buy_visit < len(self.pooltakes) else []
            sel = loot.selected(mem)
            pt = getattr(p, "ptake_cur", None)
            if pt is not None and pt[7]:
                pts.pop(0)
                p.ptake_cur = pt = None
            if pts and "TAKE" in scr["bottom"].split():
                who, n, coin = pts[0]
                js = [i for i, m in enumerate(P) if m[1].upper() == who]
                if not js:
                    raise_stop(p, "pooltake: %s not in the party" % who)
                if sel != js[0]:
                    return ("end" if sel is None or js[0] > sel else "home"), "pooltake: select %s" % who
                p.ptake_cur = [who, n, coin, js[0], None, 0, 0, False]
                if n is None:
                    pts.pop(0)          # the rest: the shop's TAKE of every coin kind, as the buy step's own
                    p.ptake_cur = None
                return "t", "pooltake: TAKE for %s" % who
            if "TAKE" in scr["bottom"].split() and not getattr(p, "take_refused", False):
                sel = loot.selected(mem)
                return "t", "buy: TAKE the pool's coins (%s)" % (P[sel][1] if sel is not None else "?")
            if "SHARE" in scr["bottom"].split() and "TAKE" in scr["bottom"].split() and not getattr(p, "buy_shared", 0):
                # Player 17: the buyer can't carry the pool (p17a5: LIRA, 1036 platinum): SHARE it instead, once
                p.buy_shared = 1
                return "s", "buy: the TAKE refused, SHARE the pool's coins"
            p.take_refused, p.buy_shared, p.coin_last = False, 0, None
            p.buy_visit += 1
            return "e", "buy: visit %d done, EXIT the shop" % p.buy_visit
        j, name = left[0]
        sel = loot.selected(mem)
        if menu == "BUY":
            if sel != j:
                return ("end" if sel is None or j > sel else "home"), "buy: select %s for %s" % (P[j][1], name)
            if not getattr(p, "buy_pooled", False) and not self.buy_purse:
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
        if (bw == ["EXIT"] or bw[-1:] == ["EXIT"] and set(bw) <= {"NEXT", "PREV", "EXIT"}) and "TO BE MEMORIZED" in st["rows"][1]:
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
            rows = {r: st["rows"][r].strip("?\\ *") for r in range(4, 23)}
            hit = [r for r, t in rows.items() if t == want]
            lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
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
        if h.get("nocast"):
            # Player 25: `nocast` (8:16's anti-magic shell: the original casts nothing there): no cures, rests only
            def next_cure(M):
                return None
        else:
            next_cure = globals()["next_cure"]
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
        if h.get("campday"):
            # Player 19: `campday <n>` (bot.gd): n day rests in camp whatever comes, the cures on anyone hurt first
            if h["days"] >= h["campday"]:
                return ("leave",)
            c = next_cure(M) if needs_rest(M) else None
            if c:
                h["cured"] += 1
                return ("cast", c[0]["i"], c[1]["i"])
            return ("rest", 24 * 60)
        if h.get("scribes") is not None:
            # Player 37: `scribe`: mark the plan's spells, one REST for the time offered, then leave
            if h["scribes"]:
                who, spells = h["scribes"].pop(0)
                byname = {m["name"]: m["i"] for m in M}
                if who not in byname:
                    raise_stop(p, "scribe: no %s in the party" % who)
                h["scribe_want"] = list(spells)
                return ("scribe", byname[who], list(spells))
            # (p37b1: an 11-hour rest copied one scroll's three spells, Blink, Ray of Enfeeblement, Slow; the other
            # marks waited: rest again for the time offered while a marked spell is missing from the book, 6 at most)
            who, want = h.get("scribe_check") or ("", [])
            m = next((m for m in M if m["name"] == who), None)
            miss = [w for w in want if not (m and MU_IDS.get(w) and m["rec"][0x33 + MU_IDS[w] - 1])]
            if miss and h.get("scribe_rests", 0) < 6:
                h["scribe_rests"] = h.get("scribe_rests", 0) + 1
                if h["scribe_rests"] > 1:
                    p.note("scribe", "%s still to copy: %s; rest again" % (who, ", ".join(miss)))
                return ("rest", None)
            return ("leave",)
        if h.get("casts") is not None:
            # Player 33: `campcast`: the plan's casts in turn, then leave
            if not h["casts"]:
                return ("leave",)
            who, spell, tgt = h["casts"].pop(0)
            byname = {m["name"]: m["i"] for m in M}
            if who not in byname or (tgt and tgt not in byname):
                raise_stop(p, "campcast: no %s in the party" % (who if who not in byname else tgt))
            return ("cast", byname[who], byname[tgt or who], spell, tgt is not None)
        if h.get("cure"):
            c = next_cure(M)
            if c:
                h["cured"] += 1
                return ("cast", c[0]["i"], c[1]["i"])
            return ("leave",)
        if h.get("wait") and not h.get("waited") and not needs_rest(M):
            # Player 15: bot.gd _wait_for_day: New Phlan locks its shop, City Hall and halls from hour 14
            # (0x49C9); the bot rests (24 - hour) hours in the inn's camp (to midnight, when they open)
            hour = p.g.mem.ecl(0x49C9)[0]
            h["waited"] = True
            if hour >= 14:
                p.note("heal", "waiting in the inn's camp for the doors to open: %02d:00" % hour)
                return ("rest", (24 - hour) * 60)
        if h.get("until") is not None and not h.get("waited"):
            # Player 26: bot.gd "restuntil <hour>": one rest of (hour - now) mod 24 hours (Stojanow Gate's trader
            # drives up only before 14:00, ECL 2:9 0xADAA); an interruption is fought out and the rest not taken again
            h["waited"] = True
            hrs = (h["until"] - p.g.mem.ecl(0x49C9)[0]) % 24
            if hrs:
                p.note("heal", "resting until %02d:00 (%d hours)" % (h["until"], hrs))
                return ("rest", hrs * 60)
        if not needs_rest(M):
            if h.get("prep") and not h.get("prep_done"):
                # Player 15: bot.gd _prepare: _pick_spells fills the free slots, _memorize rests for them
                for m in M:
                    pk = picks(m, M)
                    if pk:
                        return self._memo_op(p, h, m, pk)
                h["prep_done"] = True
                if h["memo_any"]:
                    return ("rest", None)
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
                    pk = picks(m, M)
                    if pk:
                        return self._memo_op(p, h, m, pk)
                if h["memo_any"]:
                    return ("rest", None)
                h["phase"] = "days"
        # days: the bot's picks and a rest to memorize them first, then rests of min(need, 10) days
        if not h["days_memo"]:
            for m in M:
                pk = picks(m, M)
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
            if op[0] == "scribe":
                # (a member with no scrolls: nothing happens, the menu stays: Player 37)
                h["scribe_tries"] = h.get("scribe_tries", 0) + 1
                if h["scribe_tries"] > 3:
                    raise_stop(p, "scribe: SCRIBE opened no list for %s (no scrolls?)" % P[op[1]][1])
                return "s", "heal: SCRIBE"
            return ("c", "heal: CAST") if op[0] == "cast" else ("m", "heal: MEMORIZE")
        if bw[:2] == ["CHOOSE", "SPELL:"] and "CAST" in bw and op[0] == "cast":
            if h.get("sub") == "over":
                return "e", "heal: EXIT the spells in memory"
            spell = op[3] if len(op) > 3 else "CURE LIGHT WOUNDS"     # Player 33: `campcast`'s spell
            rows = {r: st["rows"][r].strip("?\\ *") for r in range(4, 23)}
            hit = [r for r, t in rows.items() if t == spell]
            lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
            if not hit:
                raise_stop(p, "heal: no %s in %s's memory" % (spell, P[op[1]][1]))
            if len(lit) != 1:
                raise_stop(p, "heal: no single lit spell (rows %s)" % lit)
            if lit[0] in hit:
                if len(op) > 3 and spell in ("BLESS", "PRAYER", "KNOCK", "READ MAGIC", "DETECT MAGIC", "HASTE"):
                    # (Bless and Prayer take the party, no CAST SPELL ON WHOM: the cast is over; Player 35: Knock
                    # cast in camp to free its slot for Stinking Cloud, the plan's `answer LOSE IT|YES`)
                    h["sub"] = "over"
                    p.note("heal", "%s casts %s in camp" % (P[op[1]][1], spell))
                return "c", "heal: CAST %s (%s)" % (spell, P[op[1]][1])
            return ("end" if hit[0] > lit[0] else "home"), "heal: light to %s" % spell
        if op[0] == "cast" and len(op) > 3 and scr["kind"] == "yesno" and "LOSE IT" in scr["bottom"]:
            # Player 37: a combat-only spell cast in camp: "IS A COMBAT-ONLY SPELL... LOSE IT?" YES frees its slot
            # (LIRA's Sleep for Read Magic, before SCRIBE)
            h["sub"] = "over"
            p.note("heal", "%s loses %s (its slot freed)" % (P[op[1]][1], op[3]))
            return "y", "heal: LOSE IT? YES"
        if "CAST SPELL ON WHOM" in scr["bottom"] and op[0] == "cast":
            t = op[2]
            hl = scr.get("highlight")
            if hl is None:
                raise_stop(p, "heal: no member lit on CAST SPELL ON WHOM")
            if hl != t:
                return ("end" if t > hl else "home"), "heal: target %s" % P[t][1]
            h["sub"] = "over"
            h["cures"] += 1
            p.note("heal", "%s casts %s on %s (%d/%d)" % (
                P[op[1]][1], op[3].title() if len(op) > 3 else "Cure Light Wounds", P[t][1], P[t][3],
                members(mem)[t]["max"]))
            return "s", "heal: SELECT %s" % P[t][1]
        if op[0] == "scribe":
            spells = op[2]
            if bw[:2] == ["CHOOSE", "SPELL:"] and "SCRIBE" in bw:
                h["scribe_tries"] = 0
                if not spells or h.get("sub") == "over":
                    return "e", "heal: the scroll spells marked, EXIT"
                want = spells[0]
                rows = {r: st["rows"][r].strip("?\\ *") for r in range(4, 23)}
                hit = [r for r, t in rows.items() if t == want]
                lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
                if not hit:
                    d = h.get("mdir", "n")
                    if d == "n" and "NEXT" not in bw:
                        d = "p"
                    elif d == "p" and "PREV" not in bw:
                        d = "n"
                    h["mdir"] = d
                    if ("NEXT" in bw or "PREV" in bw) and h.get("mpages", 0) < 8:
                        h["mpages"] = h.get("mpages", 0) + 1
                        return d, "heal: page for %s" % want
                    raise_stop(p, "scribe: %s not on %s's scrolls (rows %s)" % (
                        want, P[op[1]][1], [t for t in rows.values() if t]))
                if len(lit) != 1:
                    raise_stop(p, "scribe: no single lit spell (rows %s)" % lit)
                # Player 38 (Combat Chat 38's ask: p37b2's 6 Ends where ours' list needs 3): each key's lit row
                p.log("SCRIBE list (%s): lit row %d %r, want %s at row %d; rows %s" % (
                    " ".join(bw), lit[0], rows.get(lit[0]), want, hit[0],
                    ", ".join("%d %s" % (r, t) for r, t in sorted(rows.items()) if t)))
                if lit[0] == hit[0]:
                    if st["rows"][hit[0]].lstrip("?\\ ").startswith("*"):
                        spells.pop(0)       # (already marked: the next one)
                        return self._heal(scr, st, p, h)
                    spells.pop(0)
                    h["mpages"], h["mdir"] = 0, "n"
                    p.note("scribe", "%s marks %s" % (P[op[1]][1], want))
                    return "s", "heal: SCRIBE %s" % want
                return ("end" if hit[0] > lit[0] else "home"), "heal: light to %s" % want
            if (bw == ["EXIT"] or bw[-1:] == ["EXIT"] and set(bw) <= {"NEXT", "PREV", "EXIT"}) and "TO BE SCRIBED" in row1:
                shown = [st["rows"][r].strip("?\\ *") for r in range(4, 23)]
                miss = [w for w in h.get("scribe_want", []) if w not in shown]
                if miss:
                    raise_stop(p, "scribe: %s refused (SPELLS TO BE SCRIBED: %s)" % (
                        ", ".join(miss), [t for t in shown if t]))
                return "e", "heal: the list to be scribed shown, EXIT"
            if scr["kind"] == "yesno" and "SCRIBE THESE SPELLS" in scr["bottom"]:
                h["sub"] = "over"
                return "y", "heal: YES"
            if bw[:2] == ["CHOOSE", "SPELL:"] or "SCRIBE" in scr["bottom"]:
                return None
        if op[0] == "memorize":
            spells = op[2]
            if bw[:2] == ["CHOOSE", "SPELL:"] and "MEMORIZE" in bw:
                if not spells or h.get("sub") == "over":
                    return "e", "heal: the member's list done, EXIT"
                want = spells[0]
                rows = {r: st["rows"][r].strip("?\\ *") for r in range(4, 23)}
                hit = [r for r, t in rows.items() if t == want]
                lit = [r for r in range(4, 23) if screens._rowcol(st["im"], r) == screens.WHITE]
                if not hit:
                    # Player 22: NEXT, and PREV from the last page (p22a4: ELWEN's MAGIC MISSILE is on the page
                    # before SLEEP's), as the `memorize` goal pages
                    d = h.get("mdir", "n")
                    if d == "n" and "NEXT" not in bw:
                        d = "p"
                    elif d == "p" and "PREV" not in bw:
                        d = "n"
                    h["mdir"] = d
                    if ("NEXT" in bw or "PREV" in bw) and h.get("mpages", 0) < 8:
                        h["mpages"] = h.get("mpages", 0) + 1
                        return d, "heal: page for %s" % want
                    raise_stop(p, "heal: %s not in %s's book" % (want, P[op[1]][1]))
                if len(lit) != 1:
                    raise_stop(p, "heal: no single lit spell (rows %s)" % lit)
                if lit[0] == hit[0]:
                    spells.pop(0)
                    h["mpages"], h["mdir"] = 0, "n"
                    p.note("heal", "%s memorizes %s" % (P[op[1]][1], want))
                    return "m", "heal: MEMORIZE %s" % want
                return ("end" if hit[0] > lit[0] else "home"), "heal: light to %s" % want
            if (bw == ["EXIT"] or bw[-1:] == ["EXIT"] and set(bw) <= {"NEXT", "PREV", "EXIT"}) and "TO BE MEMORIZED" in row1:
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
            if choice not in scr["items"]:
                # Player 18: one word of a single item will do, as an hmenu's (Podol's PLAZA AHEAD IS CROWDED: the
                # plan's DISGUISE, the item DISGUISE PARTY AS MONSTERS.)
                hits = [i for i in scr["items"] if choice in re.findall(r"[A-Z0-9']+", i)]
                if len(hits) == 1:
                    choice = hits[0]
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
    mark = 0
    for line in open(path):
        # Player 25: `nocast` tags the goals made while it holds (their heals cast nothing)
        for g in pl.goals[mark:]:
            g.nocast = getattr(pl, "nocast", False)
        mark = len(pl.goals)
        line = line.split("#")[0].strip() if not line.lstrip().startswith("answer") else re.split(r"\s#", line)[0].strip()
        if not line or line.startswith("#"):
            continue
        w = line.split(None, 1)
        cmd, rest = w[0], (w[1] if len(w) > 1 else "")
        if cmd == "area":
            pl.area = area_of(rest)
        elif cmd == "alias":
            pl.aliases.add(area_of(rest))
        elif cmd == "map":
            pl.geo = area_of(rest) if ":" in rest else None
        elif cmd == "rules":
            main_rules.append(os.path.normpath(os.path.join(base, rest)))
        elif cmd == "walk":
            w = rest.split()
            x, y = (int(v) for v in w[0].split(","))
            through = [int(v) for v in w[2].split(",")] if len(w) > 2 and w[1] == "through" else []
            avoid = [int(v) for v in w[2].split(",") if v] if len(w) > 2 and w[1] == "avoid" else None
            pl.goals.append(Walk(x, y, pl.area, through, avoid))
            pl.goals[-1].aliases = pl.aliases
            pl.goals[-1].geo = getattr(pl, "geo", None)
            pl.goals[-1].norest = getattr(pl, "norest", False)
            pl.goals[-1].bumps = getattr(pl, "bumps", 3)
            pl.goals[-1].look = getattr(pl, "look", False)
        elif cmd == "step":
            pl.goals.append(Step(rest.strip().upper()))
        elif cmd == "checkpoint":
            pl.goals.append(Checkpoint(rest.strip()))
            # Player 17: the shop visits planned before it, for a run resumed after it (player.py --after)
            pl.goals[-1].shops = (len(pl.sells), len(pl.buys))
        elif cmd == "inntrip":
            # Player 14: `inntrip` ... `inntrip end`: goals kept aside for an interrupted rest (bot.gd _rest_at_inn)
            if rest.strip() == "end":
                pl.goals, pl.inntrip = trip_outer, pl.goals + [TripEnd()]
                pl.area = trip_area
            else:
                trip_outer, trip_area, pl.goals = pl.goals, pl.area, []
        elif cmd == "innwait":
            pl.goals.append(Heal(force=True, inn=True, prep=True, wait=True))
        elif cmd == "restuntil":
            pl.goals.append(Heal(force=True, until=int(rest.split()[0])))
        elif cmd == "innheal":
            pl.goals.append(Heal(force=True, inn=True, prep=True))
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
        elif cmd == "cure":
            pl.goals.append(Heal(force=True, cure=True))
        elif cmd == "scribe":     # Player 37: `scribe <NAME> <spell>, <spell>`
            who, _, sp = rest.strip().partition(" ")
            pl.goals.append(CampScribe(who.replace("_", " "), sp.split(",")))
        elif cmd == "campcast":   # Player 33: `campcast <CASTER> <SPELL>[|<TARGET>]`
            who, _, sp = rest.strip().partition(" ")
            sp, _, to = sp.partition("|")
            pl.goals.append(CampCast(who, sp.strip(), to.strip()))
        elif cmd == "bumps":
            pl.bumps, pl.look = int(rest.split()[0]), "look" in rest.split()
        elif cmd == "norest":
            pl.norest = rest.strip() != "off"
        elif cmd == "nocast":
            pl.nocast = rest.strip() != "off"
        elif cmd == "templecure":
            pl.temple_cures.append(rest.strip().upper())
        elif cmd == "prepare":
            pl.goals.append(Heal(force=True, prep=True))
        elif cmd == "campday":
            pl.goals.append(CampDay(int(rest.strip())))
        elif cmd == "search":
            pl.goals.append(Search(rest.strip() == "on"))
        elif cmd == "revisit":
            ev, n = (int(v) for v in rest.split())
            pl.goals.append(Revisit(ev, n, pl.area))
            for a in ("aliases", "geo", "norest", "bumps", "look", "nocast"):
                setattr(pl.goals[-1], a, getattr(pl, a, None) if a != "aliases" else pl.aliases)
        elif cmd == "ready":      # Player 32: `ready <NAME> -<words>, +<words>`
            who, _, sp = rest.strip().partition(" ")
            who = who.replace("_", " ")     # Player 36: PRINCESS_FATIMA (a name with a space)
            pl.goals.append(ReadyItems(who, [(x.strip()[0] == "+", x.strip()[1:].strip().upper())
                                             for x in sp.split(",") if x.strip()[:1] in "+-" and x.strip()]))
        elif cmd == "trade":      # Player 32: `trade <FROM> <item words>|<TO>` (the item unreadied first)
            who, _, sp = rest.strip().partition(" ")
            words, to = sp.rsplit("|", 1)
            who, to = who.replace("_", " "), to.replace("_", " ")
            pl.goals.append(ReadyItems(who, [("T:" + to.strip().upper(), words.strip().upper())]))
        elif cmd == "use":        # Player 32: `use <NAME> <item words>|<TARGET>` (a scroll's lit spell on TARGET)
            who, _, sp = rest.strip().partition(" ")
            words, to = sp.rsplit("|", 1)
            pl.goals.append(ReadyItems(who, [("U:" + to.strip().upper(), words.strip().upper())]))
        elif cmd == "drop":       # Player 32: `drop <NAME> <item words>` (a spare, unreadied item: gone for good)
            # Player 35: several at once, `drop <NAME> <words>*<n>, <words>` (the Stojanow audit: movement 3 -> 9+;
            # "<words> +0" keeps a magic item that shows unidentified without its plus)
            who, _, words = rest.strip().partition(" ")
            spec = []
            for w in words.split(","):
                w, _, n = w.strip().partition("*")
                spec += [("D", w.strip().upper())] * (int(n) if n.strip() else 1)
            pl.goals.append(ReadyItems(who, spec))
        elif cmd == "readyall":
            pl.goals.append(ReadyAll())
        elif cmd == "exit":
            pl.goals.append(Exit(area_of(rest)))
        elif cmd == "answer":
            words, choice = rest.rsplit("|", 1)
            pl.answers.append((words.strip(), choice.strip(), os.path.basename(path)))
        elif cmd == "shortcutwin":
            w2 = rest.split()
            pl.goals.append(ShortcutWin(area_of(w2[0]), tuple(int(v) for v in w2[1].split(",")),
                                        int(w2[2]) if len(w2) > 2 else 1))
        elif cmd == "advance":    # Player 35: `advance <NAME>,<NAME>|none`
            pl.goals.append(Advance(rest))
        elif cmd == "learn":      # Player 35: `learn <spell>, <spell>`: a magic-user's new spell at training
            LEARN_FIRST[:0] = [x.strip().upper() for x in rest.split(",") if x.strip()]
        elif cmd == "picks":      # Player 30: `picks <NAME> <spell>, <spell>`
            who, _, sp = rest.strip().partition(" ")
            PICK_OVERRIDE[who.strip()] = [x.strip().upper() for x in sp.split(",") if x.strip()]
        elif cmd == "tactics":
            pl.goals.append(TacticsStep(rest.strip() == "on"))
        elif cmd == "focus":      # Player 36: `focus TROLL,...|none` (tactics.FOCUS)
            pl.goals.append(Focus(rest))
        elif cmd == "scrolls":    # Player 37: `scrolls <MEMBER> <spell>, ...|none` (tactics.SCROLLS)
            pl.goals.append(ScrollsStep(rest))
        elif cmd == "bands":      # Player 36: `bands on|off`
            pl.goals.append(BandsStep(rest.strip() == "on"))
        elif cmd == "answerfrom":
            words, choice = rest.rsplit("|", 1)
            pl.goals.append(AnswerFrom(words.strip(), choice.strip(), os.path.basename(path)))
        elif cmd == "sell":
            # Player 15: `sell gems`: the next shop visit appraises and sells every gem and piece of jewellery
            pl.sells.append(rest.strip())
        elif cmd == "pooltake":   # Player 38: `pooltake <NAME> <n> <COIN>, ..., <NAME> rest` (the buy line's visit)
            spec = []
            for x in rest.split(","):
                w = x.split()
                spec.append((w[0].replace("_", " ").upper(), None if w[1] == "rest" else int(w[1]),
                             COIN_WORDS.index(w[2].upper()) if len(w) > 2 else 4))
            while len(pl.pooltakes) < len(pl.buys) - 1:
                pl.pooltakes.append([])
            pl.pooltakes.append(spec)
        elif cmd == "buypurse":   # Player 38: `buypurse on|off`
            pl.buy_purse = rest.strip() == "on"
        elif cmd == "coins":      # Player 38: `coins <FROM> <COIN> <n>|<TO>` (the money TRADE)
            who, _, sp = rest.strip().partition(" ")
            words, to = sp.rsplit("|", 1)
            coin, n = words.split()
            pl.goals.append(CoinTrade(who.replace("_", " "), coin, int(n), to.strip().replace("_", " ")))
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
    for g in pl.goals[mark:]:
        g.nocast = getattr(pl, "nocast", False)
    return pl

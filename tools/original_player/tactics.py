"""Player 30: the tactical mode (Jeremy's standing goal: beat the shortcut fights for real). Instead of QUICK for
everyone, the tool gives the casters their orders by hand, guided by docs/playbook.md: Prayer and Bless before
contact, Hold Person on the enemy magic-users (persons; not on large creatures), Stinking Cloud on bunched enemies away
from the party, Magic Missile on the magic-users, Sleep on low-level persons; anyone with nothing worth casting goes
on QUICK (and stays QUICK for the fight). Player 31 (the Lead's advice): anyone with nothing to cast attacks by hand
instead (helpless enemies first: a blow slays them), or GUARDs when nothing is in reach (README "Player 31").

Plan line `tactics on` / `tactics off` (a step). While on, game.py presses Space at the fight's first poll (the
original hands every QUICK party member back to the player: GAME.OVR 0xBC26, as ours' combat_screen.gd), then each
member's menu comes here.

The original's screens (seen in DOSBox, Player 30, the Stojanow wall from `s28p`):
  menu      MOVE VIEW AIM USE CAST QUICK DONE (CAST only for a caster with spells left; row 1 the member's name)
  CAST      "<NAME>'S SPELLS IN MEMORY": rows of spell names under "1ST LEVEL" ... headers, the lit one white, the rest
            green; it opens on the last; Home moves the light up one, End down one; bottom CHOOSE SPELL: CAST EXIT
  AIM       SPELL:<name> on row 23, AIM:NEXT PREV MANUAL [TARGET] CENTER EXIT; it opens on the caster; NEXT steps
            through the aim list, DS:0x671A (count) and 0x671B (3 bytes an entry: the fight's figure number 1-based,
            distance in half squares, direction), the aimed entry is DS:0xBEFD - 1; TARGET only where the spell may go
  figures   the fight's figure n (1-based) is the record at the far pointer DS:0x65B9 + 4n (name +0, HP +0x11B, status
            +0x10C); its cell is DS:0x5F2B + 4(n - 1) (x, y); the party comes first
"""
import os, re, struct

MAGES = ("MU", "MAGE", "MAGIC-USER", "MAGIC USER", "WIZARD", "SHAMAN", "CLERIC", "PRIEST")
LARGE = ("ETTIN", "GIANT", "OGRE", "TROLL", "DRAGON", "HILL GIANT", "FIRE GIANT", "BASILISK", "BULETTE", "OWLBEAR",
         "WYVERN", "TYRANTHRAXUS", "SCORPION", "SPIDER", "BEETLE", "WOLF", "WORG", "UNDEAD", "SKELETON", "ZOMBIE",
         "GHOUL", "WIGHT", "SPECTRE", "MUMMY", "VAMPIRE", "ELEMENTAL", "BEAR", "LIZARD", "RAT", "BAT")


def _name(r):
    return r[1:1 + min(r[0], 15)].decode("latin1")


def figures(mem):
    """The fight's figures: [{n, name, hp, status, x, y}] (n 1-based, as the aim list)."""
    out = []
    pos = mem.ds(0x5F2B, 4 * 64)
    for n in range(1, 64):
        off, seg = struct.unpack("<HH", mem.ds(0x65B9 + 4 * n, 4))
        if not seg:
            if n > 1 and not out:
                continue
            break
        r = mem.far(seg, off, 0x120)
        # Player 41 (p41c10: Podol's crowd in four waves): records left from an earlier wave, with an empty name or
        # NULs in it ("UARD\0\0", 111 HP), stood among the party as enemies, so nobody went for the four goblins at
        # the map's edge (everyone guarded "in reach of" them): skipped (the numbers of the others stay)
        nm = _name(r)
        if not nm.strip() or any(ord(c) < 32 for c in nm):
            continue
        out.append({"n": n, "name": nm, "hp": r[0x11B], "status": r[0x10C],
                    "x": pos[4 * (n - 1)], "y": pos[4 * (n - 1) + 1], "fx": effects(mem, r),
                    "cl": r[0x96], "mu": r[0x9B],
                    "fp": max(1, min(4, r[0x6C] & 7)),
                    "max": r[0x32], "memo": bytes(r[0x17:0x2C])})   # Player 35: the footprint (record +0x6C, ours' combat.gd)   # Player 33: cleric and magic-user levels (record +0x96, +0x9B)
    return out


def effects(mem, r):
    """Player 31: a record's standing effects (types): the far pointer at +0x7F, 9-byte entries (type, minutes u16,
    power, ?, next far pointer at +5) (ai-business-ideas research/pool-of-radiance-formats.md; README "Player 31")."""
    out = []
    off, seg = struct.unpack("<HH", r[0x7F:0x83])
    while seg and len(out) < 24:
        a = mem.far(seg, off, 9)
        out.append(a[0])
        off, seg = struct.unpack("<HH", a[5:9])
    return out


# the effects that leave a figure helpless (any blow slays it; it strikes nobody): snake charm, paralysis (Hold
# Person), sleep, helpless (Stinking Cloud) (DS:0x286C; ours' combat_spells.gd HELD)
HELPLESS = (0x33, 0x34, 0x35, 0x1F)


def helpless(f):
    return f["hp"] > 0 and f["status"] == 0 and any(e in HELPLESS for e in f.get("fx", ()))


def aim_list(mem):
    n = mem.u8(0x671A)
    return [mem.u8(0x671B + 3 * i) for i in range(n)], mem.u8(0xBEFD) - 1


def _up(f):
    return f["hp"] > 0 and f["status"] == 0


# Player 35: a figure's cells from its corner by footprint (ours' combat.gd FOOTPRINT: 1 one cell, 2 two down, 3 two
# across, 4 a 2x2 block); distance is between the closest pair of cells (p35c2: DORN stopped 2 from an ettin's corner,
# out of reach)
FOOTPRINT = {1: ((0, 0),), 2: ((0, 0), (0, 1)), 3: ((0, 0), (1, 0)), 4: ((0, 0), (1, 0), (0, 1), (1, 1))}


def cells(f):
    return [(f["x"] + dx, f["y"] + dy) for dx, dy in FOOTPRINT.get(f.get("fp", 1), ((0, 0),))]


def _dist(a, b):
    return min(max(abs(p[0] - q[0]), abs(p[1] - q[1])) for p in cells(a) for q in cells(b))


def _is_mage(f):
    w = f["name"].upper().split()
    return any(m in w for m in MAGES) or any(m in f["name"].upper() for m in ("MAGIC", "MAGE"))


def _is_leader(f):
    """Player 35: an orc leader, a captain, a level-n fighter (the Sokal army's leaders, Stojanow's aides)."""
    u = f["name"].upper()
    return any(w in u for w in ("LEADER", "CAPTAIN", "CHIEF", "LVL", "LEVEL", "SERGEANT", "KING"))


def _sleepable(f):
    """Player 40: a figure Sleep can take (4 hit dice or fewer): no level over 4 in its name ("8TH LVL FIGHTER"),
    no more than 36 HP at full."""
    m = re.search(r"(\d+)(?:ST|ND|RD|TH) L", f["name"].upper())
    # Player 41 (p41d5: LIRA's three Sleeps at Tyranthraxus, 80 HP, 2x2): a foe's record has no "max" (0 passed), so
    # its HP now counts too, and a figure over one square is no small creature
    return not (m and int(m.group(1)) > 4) and max(f.get("max", 0), f["hp"]) <= 36 and f.get("fp", 1) == 1


def _is_large(f):
    return any(m in f["name"].upper() for m in LARGE)


UNDEAD = ("SKELETON", "ZOMBIE", "GHOUL", "GHAST", "WIGHT", "WRAITH", "SPECTRE", "MUMMY", "VAMPIRE", "SHADOW",
          "GHOST", "LICH", "UNDEAD")


def _is_undead(f):
    return any(m in f["name"].upper() for m in UNDEAD)


DRAINERS = ("WIGHT", "WRAITH", "SPECTRE", "VAMPIRE")
WEAPON_WORDS = ("SWORD", "MACE", "FLAIL", "AXE", "HAMMER", "SPEAR", "DAGGER", "STAFF", "SCIMITAR", "MORNING STAR",
                "HALBERD", "TRIDENT", "CLUB", "PICK", "LANCE")


def _magic_weapon(mem, member):
    """Player 32: a readied weapon with a plus (the member's item list at record +0xC8, loot.py)."""
    import loot
    for (s, o), name, _n, _hp in loot.party(mem):
        if name == member:
            r = mem.far(s, o, 0x120)
            io, iseg = struct.unpack_from("<HH", r, loot.ITEMS_AT)
            for _a, it in loot.chain(mem, iseg, io):
                i = loot.item(it)
                if it[52] and i["plus"] > 0 and any(w in i["name"].upper() for w in WEAPON_WORDS):
                    return True
            return False
    return True


def _ranged(mem, member):
    """Player 35: a readied bow (or crossbow, sling) with its missiles readied: the member can shoot past melee reach."""
    import loot
    for (s, o), name, _n, _hp in loot.party(mem):
        if name == member:
            r = mem.far(s, o, 0x120)
            io, iseg = struct.unpack_from("<HH", r, loot.ITEMS_AT)
            names = [loot.item(it)["name"].upper() for _a, it in loot.chain(mem, iseg, io) if it[52]]
            bow = any(("BOW" in n and "ARROW" not in n) or "SLING" in n for n in names)
            return bow and any(w in n for n in names for w in loot.MISSILE_WORDS)
    return False


# Player 35 (Jeremy's line rule, 2026-11-20 13:19, playbook): the fighters GUARD only when no enemy can be reached;
# otherwise they MOVE toward the enemy (the members named in OP_ADVANCE; the casters stay back). The original's MOVE:
# "MOVE/ATTACK, MOVE LEFT = n", the arrows and Home / PgUp / End / PgDn step (a step into an enemy attacks it), Esc
# back to the menu (ours' combat_screen.gd, from the lab).
ADVANCE = [n.strip().upper() for n in os.environ.get("OP_ADVANCE", "ARN,BRAM,DORN").split(",") if n.strip()]
DIRS = (("up", 0, -1), ("pgup", 1, -1), ("right", 1, 0), ("pgdn", 1, 1), ("down", 0, 1), ("end", -1, 1),
        ("left", -1, 0), ("home", -1, -1))


# Player 33: a camp's Bless (effect 1) or Prayer (49, on its caster) still standing (ours' combat_spells.gd
# EFFECT_BLESS, EFFECT_PRAYER) is not cast again
STANDING = {"BLESS": 1, "PRAYER": 49, "HASTE": 39}
# Player 39 (the Lead's answer, 2026-11-21: the throne room with Haste): HASTE first of all while no member is hasted,
# once a fight, aimed at the party member with the most `advance` fighters within 2 squares (the spell takes up to
# the caster's level of figures within 2 of its point: ours' combat_spells.gd); never at an enemy
ONCE = ("PRAYER", "BLESS", "HASTE")


# Player 36: the kobold throne room's Plan 1 (Gold Box Guide 2): `focus TROLL[,...]|none` (plans.py): every blow, arrow and
# MOVE goes to these kinds first (the helpless of them first), Stinking Cloud at the bunch with most of them
FOCUS = []
# Player 37: `scrolls <MEMBER> <spell>, ...`: spells to cast from that member's readied scrolls in fights (USE), one a
# turn while a target is worth it (the Kovel Fireball scrolls for the graveyard's spectres)
SCROLLS = {}


def _focus(f):
    return any(w in f["name"].upper() for w in FOCUS)


# Player 38 (p38e1: the throne room's four trolls all killed, then two rose again at their own squares and beat the
# last three members; the guide: "stand on a fallen troll's square"): with OP_HOLDDOWN on (default), a fighter in
# `advance` walks onto a fallen focus figure's square nobody holds, and once there stays (no MOVE off it)
HOLDDOWN = os.environ.get("OP_HOLDDOWN", "1") != "0"
# Player 40: OP_MOVETEST=<key> (a hand check: which key ends a MOVE with the member where he stepped): see _fight
MOVETEST = os.environ.get("OP_MOVETEST", "")
# Player 41: OP_GOTO="x,y;x,y" (see _fight)
GOTO = [tuple(int(v) for v in q.split(",")) for q in os.environ.get("OP_GOTO", "").split(";") if q.strip()]
# Player 40 (p40t1: a troll rose on the corner 26,10 of a fallen troll whose second cell 26,11 ARN held): OP_HOLDCORNER=1
# holds the fallen figure's corner square only
HOLDCORNER = os.environ.get("OP_HOLDCORNER", "0") == "1"

# Player 38 (p38e3: the throne room's second wave began with the party at 49 HP; the tool answered CONTINUE BATTLE NO;
# the book: "between waves, Continue Combat for a round or two to heal"): when the last enemy falls, CONTINUE BATTLE
# YES while a member up is hurt by 4 or more and a member up has Cure Light Wounds in memory (OP_CONTINUE rounds at
# most, default 6); in those rounds the clerics cast it on the most hurt, the dying are bandaged
CLW = 3                       # the cleric spell id (record 0x17-0x2B, the memorized list)
CONTINUE = int(os.environ.get("OP_CONTINUE", "6"))


def _hurt(party):
    return [f for f in party if _up(f) and f.get("max", 0) - f["hp"] >= 4]


def _fallen_focus(figs, party_n):
    return [f for f in figs if f["n"] > party_n and _focus(f) and not _up(f)]


def _is_drainer(f):
    return any(m in f["name"].upper() for m in DRAINERS)


class Tactics:
    def __init__(self, log):
        self.log = log
        self.on = False
        # Player 30: v2 (p30a3 lost with Prayer / Bless first: begun spells are lost to a hit before they go off):
        # the enemy's numbers first, the party's bonuses after
        # Player 33 (docs/playbook.md "Spell sheet", Combat Chat 33's spell lab, seen in the original): Hold Person
        # holds persons 95% (a held figure dies to one blow) and goes before Magic Missile (level/2 missiles, none at
        # level 1); Slow has no save and halves the attacks of the caster's level in figures nearest the aim point
        # Player 35 (Stojanow Plan 1: LIRA's Fireball at magic-user 5): Fireball first, on the biggest bunch
        self.priority = ("FIREBALL", "STINKING CLOUD", "HOLD PERSON", "SLOW", "PRAYER", "MAGIC MISSILE", "BLESS",
                         "SLEEP")
        self.horde = ("SLEEP", "FIREBALL", "STINKING CLOUD", "HOLD PERSON", "PRAYER", "SLOW", "BLESS", "MAGIC MISSILE")
        if os.environ.get("OP_TACTICS") == "horde":
            # Player 30: a horde of small figures (the kobold king): the area spells first
            self.priority = self.horde
        # Player 31: the Lead's advice: members with nothing to cast attack by hand (helpless enemies first);
        # OP_MELEE=0 keeps Player 30's QUICK
        self.melee = os.environ.get("OP_MELEE", "1") != "0"
        self.spells = {}         # member -> the spells seen in their CAST list (kept across fights; refreshed at each look)
        self.reset()

    def reset(self):
        """A new fight."""
        self.cast = {}           # spell -> times ordered this fight (Prayer, Bless once)
        self.held = set()        # figures given Hold Person (not tried again)
        self.slept = {}          # Player 35: figure -> Sleeps aimed at it this fight
        self.slowed = set()      # Player 33: figures inside a Slow's reach (not aimed at again)
        self.order = None        # [member, spell, pages turned] while CAST's list is up
        self.scan = None         # aim: entries with TARGET seen
        self.refused = set()     # (member, spell) refused this turn (not in the list, nowhere to aim)
        self.unreach = {}        # Player 34: (member, spell) -> the member's turns left to skip it (nowhere to aim)
        self.last_member = None
        self.party_n = 0
        self.reach = {}          # member -> this turn's attack: "none" (nothing in reach), "done", "hit"
        self.idle = {}           # member -> turns in a row with nothing in reach
        self.guard = None        # the member whose DONE asked for GUARD
        self.bandage = None      # Player 34: the member whose DONE asked for BANDAGE
        self.turned = set()      # Player 32: members who tried TURN this fight
        self.move = None         # Player 35: the member walking toward an enemy (MOVE): {member, goal, tries}
        self.moved = set()       # Player 35: members who have walked this turn (one MOVE a turn)
        self.fx_logged = False
        self.fidle = {}          # Player 36: walks to the focus figure this fight, per member
        self.use = None          # Player 37: a scroll USE under way: {member, spell, tried rows}
        self.use_off = set()     # Player 37: members whose readied scrolls have none of their spells left (this fight)
        self.holding = set()     # Player 38: members standing on a fallen focus figure's square (OP_HOLDDOWN)

    # -- reading -------------------------------------------------------------------------------------------
    def _sides(self, p):
        figs = figures(p.g.mem)
        names = [m[0] for m in p.g.party()]
        self.party_n = len(names)
        party = [f for f in figs if f["n"] <= self.party_n]
        foes = [f for f in figs if f["n"] > self.party_n and _up(f)]
        return figs, party, foes

    # -- the menu: choose the member's order ----------------------------------------------------------------
    def choose(self, member, p):
        """The spell this member should cast now, or None (QUICK)."""
        figs, party, foes = self._sides(p)
        me = next((f for f in party if f["name"] == member), None)
        if me is not None and not foes and CLW in me.get("memo", b"") and _hurt(party) \
                and (member, "CURE LIGHT WOUNDS") not in self.refused:
            return "CURE LIGHT WOUNDS"     # Player 38: the continued battle between waves (CONTINUE BATTLE: YES)
        if me is None or not foes:
            return None
        known = self.spells.get(member)       # the spells seen in this member's CAST list (None: not looked yet)
        contact = any(_dist(a, f) <= 1 for a in party if _up(a) for f in foes)
        prio = self.priority
        if sum(1 for f in foes if not _is_large(f)) >= 10:
            prio = self.horde     # Player 33 (p33f1: the band's 29 kobolds, Sleep last, CEDRIC dead): a horde
        if FOCUS and any(_focus(f) and not helpless(f) for f in foes):
            # Player 36 (the throne room's Plan 1): Stinking Cloud on the focus kind first while one stands unhurt
            # Player 37 (p37n2: LIRA's Fireball came on her third turn, after two clouds): Fireball before the cloud
            prio = ("FIREBALL", "STINKING CLOUD") + tuple(s for s in prio if s not in ("FIREBALL", "STINKING CLOUD"))
        prio = ("HASTE",) + tuple(s for s in prio if s != "HASTE")
        for spell in prio:
            if (member, spell) in self.refused or (known is not None and spell not in known):
                continue
            if spell in ONCE and self.cast.get(spell):
                continue           # once a fight
            if spell in STANDING and any(STANDING[spell] in f.get("fx", ()) for f in party if _up(f)):
                continue           # Player 33 (p33c1: Bless cast again after the camp's): already on the party
            if spell == "BLESS" and contact:
                continue           # before contact
            if spell == "MAGIC MISSILE" and me.get("mu", 2) < 2:
                continue           # Player 33 (spell sheet): at magic-user level 1 it fires no missile
            if spell in ("PRAYER", "BLESS") or self.targets(spell, me, party, foes):
                return spell
        return None

    def _haste_points(self, party):
        """Player 39: party figures to aim Haste at, the one with most advance fighters (then members) within 2 first."""
        up = [f for f in party if _up(f)]
        fighters = [f for f in up if f["name"].upper() in ADVANCE]
        if not fighters:
            return []
        best = []
        for f in up:
            k = sum(1 for g in fighters if _dist(f, g) <= 2)
            m = sum(1 for g in up if _dist(f, g) <= 2)
            if k:
                best.append((-k, -m, f["n"]))
        return [b[-1] for b in sorted(best)]

    def targets(self, spell, me, party, foes):
        """Figures to aim at, best first ([] none worth it; None: on the caster)."""
        if spell in ("PRAYER", "BLESS"):
            return None
        if spell == "HASTE":
            return self._haste_points(party)
        if spell == "CURE LIGHT WOUNDS":   # Player 38: the most hurt members first (touch: the scan finds who is near)
            return [f["n"] for f in sorted(_hurt(party), key=lambda f: f["hp"] - f["max"])]
        mages = sorted([f for f in foes if _is_mage(f)], key=lambda f: f["hp"])
        # Player 41 (p41d5: four Hold Persons at Tyranthraxus, a 2x2 figure): a figure over one square is no person
        persons = [f for f in foes if not _is_large(f) and f.get("fp", 1) == 1]
        if spell in ("HOLD PERSON", "STINKING CLOUD", "SLEEP"):
            # Player 32 (p32a1: Sleep thrown at 4:10's skeletons): the undead take no Sleep, Hold or poison cloud
            foes = [f for f in foes if not _is_undead(f)]
            mages = [f for f in mages if not _is_undead(f)]
            persons = [f for f in persons if not _is_undead(f)]
        if spell == "HOLD PERSON":     # the mages first, then other persons (not large creatures)
            return [f["n"] for f in mages if f["n"] not in self.held] + \
                [f["n"] for f in persons if f["n"] not in self.held and not _is_mage(f)]
        if spell == "FIREBALL":        # Player 35: the biggest bunch (2 or more), no party member within 2 of it
            best = []
            for f in foes:
                if any(_up(a) and _dist(a, f) <= 2 for a in party) or (me and _dist(me, f) > 9):
                    continue
                k = sum(1 for g in foes if _dist(g, f) <= 1)
                # Player 37: two foes or fewer, a focus kind among them (the graveyard's spectres): one is enough
                need = 1 if len(foes) <= 2 and any(_focus(g) for g in foes) else 2
                if k >= need:
                    best.append((-k, f["n"]))
            return [n for _, n in sorted(best)]
        if spell == "STINKING CLOUD":  # the biggest bunch with no party member in its area
            # Player 41 (Guide 6's request): the cloud is 2x2, the aimed square and the squares right, below and
            # below-right (seen, Combat Chat 34), not a 3x3 around it: with a troll beside a member the 3x3 never
            # found a free aim (p38-p39: kobold bunches only)
            best = []
            for f in foes:
                area = {(f["x"] + dx, f["y"] + dy) for dx in (0, 1) for dy in (0, 1)}
                if any(_up(a) and area & set(cells(a)) for a in party) or (me and _dist(me, f) > 6):
                    continue
                inside = [g for g in foes if area & set(cells(g))]
                k = len(inside)
                kf = sum(1 for g in inside if _focus(g) and not helpless(g))
                if k >= 2 or kf:
                    best.append((-kf, -k, f["n"]))
            return [b[-1] for b in sorted(best)]
        if spell == "SLOW":            # Player 33 (spell sheet): no save; the strongest not slowed yet, so its
            # reach (the caster's level in figures nearest the aim point) takes the big hitters
            return [f["n"] for f in sorted(foes, key=lambda f: (not _is_large(f), -f["hp"])) if f["n"] not in self.slowed]
        if spell == "MAGIC MISSILE":   # the mages (weakest first), the drainers (Player 32), then the weakest
            dr = [f["n"] for f in sorted(foes, key=lambda f: f["hp"]) if _is_drainer(f) and not _is_mage(f)]
            return [f["n"] for f in mages] + dr + [f["n"] for f in sorted(foes, key=lambda f: f["hp"])
                                                    if not _is_mage(f) and f["n"] not in dr]
        if spell == "SLEEP":           # (Player 30, the horde) the biggest bunch of small figures, as Stinking Cloud;
            best = []                  # else any person (the wall's aides)
            # Player 40 (p40c1: LIRA's and ELWEN's Sleeps at the finale's 8th-level guards, the horde order's first):
            # Sleep takes nothing above 4 hit dice: a level in the name over 4, or over 36 HP at full (4d8+4)
            persons = [f for f in persons if _sleepable(f)]
            for f in persons:
                if any(_up(a) and _dist(a, f) <= 1 for a in party) or (me and _dist(me, f) > 6) \
                        or self.slept.get(f["n"], 0) >= 2:
                    continue
                k = sum(1 for g in persons if _dist(g, f) <= 1)
                best.append((-k, f["n"]))
            # Player 35 (p35c3: four Sleeps at one aide, none took): a lone figure at most twice a fight
            return [n for _, n in sorted(best)] or [f["n"] for f in persons if not _is_mage(f)
                                                    and self.slept.get(f["n"], 0) < 2]
        return [f["n"] for f in sorted(foes, key=lambda f: _dist(me, f))]

    def answer(self, scr, st, p):
        """One key for a tactical screen, or None (the plan's other rules go on)."""
        b = st["bottom"]
        if b.startswith("CONTINUE BATTLE"):
            try:
                figs, party, foes = self._sides(p)
            except Exception:
                party, foes = [], [1]
            n = getattr(self, "continued", 0)
            dying = any(f["status"] == 5 for f in party)
            cures = any(_up(f) and CLW in f.get("memo", b"") for f in party)
            if not foes and n < CONTINUE and (dying or (cures and _hurt(party))):
                self.continued = n + 1
                self.log("TACTICS CONTINUE BATTLE YES (%d): %s" % (self.continued, ", ".join(
                    "%s %d/%d" % (f["name"], f["hp"], f.get("max", 0)) for f in party)))
                return "y", "tactics: CONTINUE BATTLE YES (round %d: cures and bandages)" % self.continued
            self.continued = 0
            return "n", "tactics: CONTINUE BATTLE NO"
        if b.startswith("ABORT SPELL?"):
            # the original after an aim's EXIT (seen, p30b1): a spell with nowhere to go is given up
            self.scan = None
            return "y", "tactics: ABORT SPELL? YES (no target in reach)"
        if self.use and b.split()[:1] == ["READY"] and "USE" in b.split():
            return self._use_items(st, p)
        if b.startswith("CHOOSE SPELL:") and self.use and not self.order:
            # (the scroll's page after _spell_list found no such spell on it: EXIT back to the items)
            return "e", "tactics: not on this scroll: EXIT"
        if b.startswith("CHOOSE SPELL:") and self.order:
            return self._spell_list(st, p)
        if b.startswith("AIM:") and not self.order and getattr(self, "shot", None) and "SPELL:" not in st["rows"][23]:
            # Player 35 (p35d3: a bow shoots twice a round): AIM comes back for the second arrow
            self.order, self.far, self.scan = [self.shot, "ATTACK", 0], True, None
            self.shot = None
            self.log("TACTICS %s's second shot" % self.order[0])
        if b.startswith("AIM:") and not self.order and not getattr(self, "blow", None) and not getattr(self, "shot", None) \
                and not getattr(self, "scroll_aim", None) and "SPELL:" not in st["rows"][23]:
            # Player 39 (p39b3: an AIM with no order after DORN's blow; the tool stopped): the attacker is the aim
            # list's first figure (the caster's / attacker's own entry): his blow
            try:
                lst, _ = aim_list(p.g.mem)
                me = next((f for f in figures(p.g.mem) if lst and f["n"] == lst[0]), None)
                if me and me["n"] <= self.party_n:
                    self.blow = me["name"]
            except Exception as e:
                self.log("TACTICS an AIM with no order, unreadable: %s" % e)
        if b.startswith("AIM:") and not self.order and getattr(self, "blow", None) and "SPELL:" not in st["rows"][23]:
            # Player 39 (p39b1: hasted ELWEN's AIM came back after her blow and the tool stopped): a hasted member's
            # second blow, as the bow's second shot
            self.order, self.far, self.scan = [self.blow, "ATTACK", 0], False, None
            self.blow = None
            self.log("TACTICS %s's second blow" % self.order[0])
        if b.startswith("AIM:") and self.order and self.order[1] == "ATTACK":
            if getattr(self, "far", False):
                return self._aim_shoot(st, p)
            return self._aim_attack(st, p)
        if b.startswith("AIM:") and (self.order or "SPELL:" in st["rows"][23] or getattr(self, "scroll_aim", None)):
            return self._aim(st, p)
        if b.startswith("ATTACK ALLY"):
            self.log("TACTICS ATTACK ALLY? NO")
            return "n", "tactics: ATTACK ALLY: NO"
        if getattr(self, "mt", None) and ("MOVE LEFT" in b or "MOVE/ATTACK" in b):
            return self._move_test(st, p)
        if self.move and ("MOVE LEFT" in b or "MOVE/ATTACK" in b):
            return self._move_step(st, p)
        if b.startswith("MOVE/ATTACK"):
            # Player 35 (p35c2: a MOVE screen the tool didn't open, after LIRA's DONE with a bow): back to the menu
            self.log("TACTICS a MOVE screen not asked for: Esc")
            return "esc", "tactics: MOVE not asked for: Esc"
        if self.bandage and "BANDAGE" in b.split() and ("DELAY" in b.split()):
            # Player 34: DONE's menu ([GUARD] DELAY QUIT [BANDAGE] SPEED EXIT; BANDAGE only with someone dying: the
            # original's, as ours' combat_screen.gd): BANDAGE takes the first dying member
            self.log("TACTICS %s bandages %s" % (self.bandage, self.dying_name))
            self.bandage = None
            return "b", "tactics: BANDAGE"
        if self.bandage and "DELAY" in b.split():
            self.log("TACTICS %s: no BANDAGE in DONE's menu (%s)" % (self.bandage, b))
            self.bandage = None
            return "e", "tactics: no BANDAGE: EXIT"
        if b.startswith("GUARD DELAY") and self.guard:
            self.log("TACTICS %s guards" % self.guard)
            self.guard = None
            return "g", "tactics: GUARD"
        if self.guard and b.startswith("DELAY"):
            # Player 35: no GUARD with a missile weapon (ours' combat_screen.gd, from the lab): DELAY
            self.log("TACTICS %s delays (no GUARD with a bow)" % self.guard)
            self.guard = None
            return "d", "tactics: DELAY"
        if scr["kind"] != "combat":
            return None
        member = scr.get("member", "")
        self.order = None
        self.scan = None
        self.shot = None
        self.blow = None
        self.scroll_aim = None
        try:
            figs, party, foes = self._sides(p)
            self.log("TACTICS state at %s's menu: party %d up %d HP; enemies %d up %d HP (%s)" % (
                member, sum(1 for f in party if _up(f)), sum(f["hp"] for f in party),
                len(foes), sum(f["hp"] for f in foes),
                ", ".join("%d:%s %d @%d,%d/%d" % (f["n"], f["name"][:6], f["hp"], f["x"], f["y"], f["fp"])
                          for f in foes)))
            me = next((f for f in party if f["name"] == member), None)
            if me:
                self.log("TACTICS %s at %d,%d/%d" % (member, me["x"], me["y"], me["fp"]))
            if self.cast.get("HASTE"):
                # Player 39: who carries Haste (effect 39) since it was cast
                self.log("TACTICS hasted: %s" % (", ".join(f["name"] for f in party if 39 in f.get("fx", ())) or "none"))
            if not getattr(self, "fx_logged", False):
                # Player 33: the party's standing effects at the fight's first menu (a camp's Bless, Prayer...)
                self.fx_logged = True
                self.log("TACTICS party effects: %s" % "; ".join(
                    "%s %s" % (f["name"], ",".join("%d" % e for e in f.get("fx", ())) or "-") for f in party))
        except Exception as e:
            self.log("TACTICS state unreadable: %s" % e)
        if member != self.last_member:
            # Player 34 (p34e1-e5: ELWEN and CEDRIC began an unreachable Hold Person every turn, then ABORT): a spell
            # with nowhere to aim stays refused for the member's next two turns, not only this one
            self.refused = {r for r in self.refused if r[0] != member or self.unreach.get(r, 0) > 0}
            for r in [r for r in self.unreach if r[0] == member]:
                self.unreach[r] -= 1
            self.reach.pop(member, None)
            self.moved.discard(member)
            self.move = None            # Player 35: a MOVE that ended the turn (a blow struck by a step)
            self.last_member = member
        items = b.split()
        if "DONE" in items:
            # Player 34 (p34e1, p34e2: CEDRIC knocked down in Stojanow's west tower bled to death while the fight went
            # on another minute; docs/playbook.md "The dying": bandage the dying at once): a party member dying
            # (status 5) -> this member's turn is DONE, BANDAGE
            try:
                dying = [f for f in self._sides(p)[1] if f["status"] == 5]
            except Exception:
                dying = []
            if dying:
                self.bandage, self.dying_name = member, dying[0]["name"]
                return "d", "tactics: %s will bandage %s: DONE" % (member, dying[0]["name"])
        if "TURN" in items and member not in self.turned:
            # Player 32 (Jeremy, 2026-11-20 01:10): whenever undead are on the field, the clerics turn first (once a
            # fight each)
            try:
                undead = [f for f in self._sides(p)[2] if _is_undead(f)]
            except Exception:
                undead = []
            if undead:
                self.turned.add(member)
                self.log("TACTICS %s turns undead (%s)" % (member, ", ".join(f["name"] for f in undead[:6])))
                return "t", "tactics: %s TURNs undead" % member
        self.use = None
        left = SCROLLS.get(member.upper())
        if "CAST" in items and left:
            # Player 39: a memorized Haste goes before the readied scroll's spell (round 1, the Lead's answer)
            o = self.choose(member, p)
            if o == "HASTE":
                self.order = [member, o, 0]
                self.scan = None
                return "c", "tactics: %s casts %s (before the scroll)" % (member, o)
        if left and "USE" in items and member not in self.use_off and (member, left[0]) not in self.refused:
            try:
                figs, party, foes = self._sides(p)
                me = next((f for f in party if f["name"] == member), None)
                t = self.targets(left[0], me, party, foes) if me else []
            except Exception as e:
                self.log("TACTICS scroll targets unreadable: %s" % e)
                t = []
            if t:
                self.use = {"member": member, "spell": left[0], "tried": set(), "row": None}
                self.log("TACTICS %s uses a scroll: %s (targets %s)" % (member, left[0], t[:4]))
                return "u", "tactics: %s USEs a scroll (%s)" % (member, left[0])
        if "CAST" in items:
            o = self.choose(member, p)
            if o:
                self.order = [member, o, 0]
                self.scan = None
                return "c", "tactics: %s casts %s" % (member, o)
        if self.melee and "AIM" in items:
            return self._fight(member, items, p)
        return "q", "tactics: %s on QUICK (%s)" % (member, "no spell worth casting" if "CAST" in items else "no CAST")

    def _fight(self, member, items, p):
        """Player 31 (the Lead's advice): a member with nothing to cast attacks by hand: AIM, the aim list scanned for
        the figures TARGET may take (in reach), then the best: a helpless one first (a blow slays it), then the enemy
        magic-users, then the weakest. Nothing in reach: DONE (hold the line, let them come) while an enemy is within
        6 squares, else QUICK (the fight's other figures out of sight: the computer walks to them)."""
        if MOVETEST and not getattr(self, "mt_done", False) and "MOVE" in items:
            # Player 40 (Guide 6's question: does a member stay on a fallen troll's square?): OP_MOVETEST=<key>: the
            # first member with MOVE steps once to a free square, then presses <key>; the logs show where he stands
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
            taken = {c for f in figs if f is not me and (_up(f) or f["n"] <= self.party_n) for c in cells(f)}
            free = [(min([_dist({"x": me["x"] + dx, "y": me["y"] + dy}, f) for f in foes] or [99]), k, dx, dy)
                    for k, dx, dy in DIRS if (me["x"] + dx, me["y"] + dy) not in taken] if me else []
            if free:
                d, k, dx, dy = max(free)
                self.mt = {"member": member, "step": k, "phase": 0, "from": (me["x"], me["y"]),
                           "to": (me["x"] + dx, me["y"] + dy)}
                self.mt_done = True
                self.log("TACTICS MOVETEST %s at %d,%d: MOVE, %s to %d,%d, then %s" % (
                    member, me["x"], me["y"], k, me["x"] + dx, me["y"] + dy, MOVETEST))
                return "m", "tactics: MOVETEST: %s MOVE" % member
        if GOTO and "MOVE" in items and member not in self.moved:
            # Player 41 (Guide 8's Plan 3: the finale's doorway gap and Tyranthraxus by the flight): OP_GOTO="x,y;..."
            # every member with MOVE walks (once a round, no blow on the way) to the nearest free square of the list
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
            taken = {c for f in figs if f is not me and (_up(f) or f["n"] <= self.party_n) for c in cells(f)}
            free = [q for q in GOTO if q not in taken]
            if me is not None and (me["x"], me["y"]) not in GOTO and free:
                q = min(free, key=lambda q: max(abs(q[0] - me["x"]), abs(q[1] - me["y"])))
                self.moved.add(member)
                self.move = {"member": member, "goal": 0, "tries": 0, "blocked": set(), "last": None,
                             "square": q, "cells": [q], "flee": True}
                self.log("TACTICS %s GOTO %d,%d from %d,%d" % (member, q[0], q[1], me["x"], me["y"]))
                return "m", "tactics: %s MOVEs to %d,%d (OP_GOTO)" % (member, q[0], q[1])
        if FOCUS and HOLDDOWN and member.upper() in ADVANCE:
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
            fallen = _fallen_focus(figs, self.party_n)
            held = {(f["x"], f["y"]) for f in party if _up(f) and f is not me}
            # (p38e3: BRAM went round a large troll's corner 25,12 between 26,12 and its second cell 25,13: any of
            # the fallen figure's cells will do)
            fcells = {c for f in fallen for c in (cells(f) if not HOLDCORNER else [(f["x"], f["y"])])}
            if me is not None and fallen:
                if (me["x"], me["y"]) in fcells:
                    self.holding = getattr(self, "holding", set()) | {member}
                elif "MOVE" in items and member not in self.moved and not any(_dist(me, f) <= 1 for f in foes
                                                                              if _focus(f)):
                    free = [f for f in fallen if not held & set(cells(f))]
                    goal = min(free, key=lambda f: _dist(me, f)) if free else None
                    if goal is not None and _dist(me, goal) <= 8:
                        self.moved.add(member)
                        self.move = {"member": member, "goal": goal["n"], "tries": 0, "blocked": set(), "last": None,
                                     "square": (goal["x"], goal["y"]),
                                     "cells": cells(goal) if not HOLDCORNER else [(goal["x"], goal["y"])]}
                        self.log("TACTICS %s walks onto fallen figure %d %s's square %d,%d (%d squares)" % (
                            member, goal["n"], goal["name"], goal["x"], goal["y"], _dist(me, goal)))
                        return "m", "tactics: %s MOVEs onto fallen figure %d's square" % (member, goal["n"])
            if me is not None and member in getattr(self, "holding", set()) and (me["x"], me["y"]) not in fcells:
                self.holding.discard(member)
        if member in getattr(self, "holding", set()):
            self.moved.add(member)       # Player 38: on a fallen troll's square: strike what is in reach, no MOVE off
        if FOCUS and member.upper() in ADVANCE and "MOVE" in items and member not in self.moved:
            # Player 36 (p36n2: BRAM struck kobolds next to him for ten minutes with a troll two squares off): a fighter
            # in `advance` with a focus figure within 4 squares and none next to him walks to it, past the small fry
            # (kobolds hit AC -1 only on a 20), and attacks it by stepping in; 6 such walks a fight at most
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
            fl = [f for f in foes if _focus(f)]
            if me is not None and fl and not any(_dist(me, f) <= 1 for f in fl):
                goal = min(fl, key=lambda f: (not helpless(f), _dist(me, f)))
                fi = getattr(self, "fidle", {})
                self.fidle = fi
                if _dist(me, goal) <= 4 and fi.get(member, 0) < 6:
                    fi[member] = fi.get(member, 0) + 1
                    self.moved.add(member)
                    self.move = {"member": member, "goal": goal["n"], "tries": 0, "blocked": set(), "last": None,
                                 "focus": True}
                    self.log("TACTICS %s walks to figure %d %s (%d squares, the focus)" % (
                        member, goal["n"], goal["name"], _dist(me, goal)))
                    return "m", "tactics: %s MOVEs to figure %d (the focus)" % (member, goal["n"])
        if self.reach.get(member) == "none":
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
            goal = min(foes, key=lambda f: (not _focus(f), not helpless(f), _dist(me, f))) if me is not None and foes else None
            # Player 37 (p37g1: both clerics' TURN sent the spectres 21 squares off and the party guarded while the
            # camp's Haste ran out; turned undead flee and don't fight back): a focus figure is walked to at any
            # distance, for up to 30 turns
            far_ok = goal is not None and _focus(goal)
            if member.upper() in ADVANCE and "MOVE" in items and goal is not None and member not in self.moved \
                    and (_dist(me, goal) <= 8 or far_ok) and self.idle.get(member, 0) < (30 if far_ok else 8):
                # Player 35: the line rule: walk toward the nearest enemy (a helpless one first), then attack; not
                # past 8 squares nor after 8 turns without a blow (p35g2: two zombies 21 squares off behind walls,
                # the greedy steps went round in circles): then GUARD, then QUICK (the computer finds the way)
                self.idle[member] = self.idle.get(member, 0) + 1
                self.moved.add(member)
                self.move = {"member": member, "goal": goal["n"], "tries": 0, "blocked": set(), "last": None}
                self.log("TACTICS %s moves toward figure %d %s (%d squares)" % (member, goal["n"], goal["name"],
                                                                                 _dist(me, goal)))
                return "m", "tactics: %s MOVEs toward figure %d" % (member, goal["n"])
            self.idle[member] = self.idle.get(member, 0) + 1
            self.reach[member] = "done"
            # (p31b2: DORN went QUICK in round 1 with the ettins 7 squares off, and QUICK stays for the fight)
            if self.idle[member] <= 8 and "DONE" in items:
                # DONE opens GUARD DELAY QUIT SPEED EXIT (seen, p31b1): GUARD, the figure strikes the first enemy
                # that steps next to it
                self.guard = member
                return "d", "tactics: %s guards (nothing in reach): DONE" % member
            return "q", "tactics: %s on QUICK (nothing in reach for %d turns)" % (member, self.idle[member])
        figs, party, foes = self._sides(p)
        me = next((f for f in party if f["name"] == member), None)
        try:
            far = _ranged(p.g.mem, member)
        except Exception as e:
            self.log("TACTICS bow unreadable: %s" % e)
            far = False
        if me is not None and not far and not any(_dist(me, f) <= 2 for f in foes):
            # (p31b1: a 16-key scan found nothing; an enemy's cell is its corner, so a large one 2 away may touch)
            self.reach[member] = "none"
            return self._fight(member, items, p)
        # (Player 32, p32b3: zombies two squares off but never TARGETable kept the count at 0 for 1400 s: it is reset
        # only by a blow, in _aim_attack)
        self.order = [member, "ATTACK", 0]
        self.scan = None
        self.far = far
        return "a", "tactics: %s %s: AIM" % (member, "shoots" if far else "attacks by hand")

    def _use_items(self, st, p):
        """Player 37: the items page after USE (READY USE DROP ... EXIT; rows "YES <item>" for the readied): light the
        next readied scroll not tried this turn and USE it (its page: CHOOSE SPELL: CAST EXIT, then _spell_list);
        none left: EXIT, and the member gives up scrolls for this fight."""
        u = self.use
        rows = {}
        for r in range(5, 23):
            m = re.match(r"(YES|NO)\s+(.*)", st["rows"][r].strip("?\\ "))
            if m:
                rows[r] = (m.group(1), m.group(2).strip().upper())
        if u["row"] is not None:
            u["tried"].add(u["row"])
            u["row"] = None
        cand = [r for r, (y, n) in sorted(rows.items()) if y == "YES" and "SCROLL" in n and r not in u["tried"]]
        lit = [r for r in rows if _white(st["im"], r)]
        if not cand:
            self.log("TACTICS %s: no readied scroll with %s left (rows %s)" % (u["member"], u["spell"],
                                                                             sorted(rows.values())))
            self.use_off.add(u["member"])
            self.use = None
            return "e", "tactics: no scroll with the spell: EXIT"
        if len(lit) == 1 and lit[0] == cand[0]:
            u["row"] = cand[0]
            self.order = [u["member"], u["spell"], 0]
            return "u", "tactics: USE %s" % rows[cand[0]][1]
        if len(lit) != 1:
            self.use_off.add(u["member"])
            self.use = None
            return "e", "tactics: the items page has no single lit row: EXIT"
        return ("end" if cand[0] > lit[0] else "home"), "tactics: light to %s" % rows[cand[0]][1]

    def _move_test(self, st, p):
        """Player 40: OP_MOVETEST's step, then its key; the member's square logged before the key."""
        mt = self.mt
        figs, party, foes = self._sides(p)
        me = next((f for f in party if f["name"] == mt["member"]), None)
        pos = (me["x"], me["y"]) if me else None
        if mt["phase"] == 0:
            mt["phase"] = 1
            return mt["step"], "tactics: MOVETEST: %s steps %s" % (mt["member"], mt["step"])
        self.log("TACTICS MOVETEST %s stands at %s before %s (bottom %r)" % (mt["member"], pos, MOVETEST, st["bottom"]))
        self.mt = None
        self.mt_after = mt["member"]
        return MOVETEST, "tactics: MOVETEST: %s" % MOVETEST

    def _move_step(self, st, p):
        """Player 35: one MOVE key toward the goal figure. In the original's MOVE/ATTACK a step into an enemy attacks
        it, so next to an enemy's corner cell (the goal's, or any enemy's: walking off would give it a free blow) the
        step goes into it: the attack. Otherwise the free step that most shortens the distance to the goal's corner
        (no cell another standing figure holds, nor a direction that left the figure where it was). Stuck, or 16 keys:
        Enter, back to the menu. Player 40 (Guide 6's question, seen in DOSBox p40m1/p40m2): **Esc undoes the walk** (the
        figure back where MOVE began, as ours' combat_screen.gd, GAME.OVR 0xA2D2); Enter keeps it. Every OP_HOLDDOWN
        stand of Players 38-39 ended in Esc, so nobody ever stood on a fallen troll. (p35c3: stopping "in reach" by the record's footprint and AIMing found nothing.)"""
        mv = self.move
        figs, party, foes = self._sides(p)
        me = next((f for f in party if f["name"] == mv["member"]), None)
        goal = next((f for f in foes if f["n"] == mv["goal"]), None)
        if mv.get("square"):
            # Player 38: onto a fallen focus figure's square (OP_HOLDDOWN): past the others, then stop there
            goal = {"n": mv["goal"], "x": mv["square"][0], "y": mv["square"][1], "name": "fallen", "hp": 0}
            if me is not None and (me["x"], me["y"]) in mv.get("cells", [mv["square"]]):
                self.holding.add(mv["member"])
                self.log("TACTICS %s stands on fallen figure %d's square %d,%d" % (mv["member"], mv["goal"],
                                                                                  me["x"], me["y"]))
                self.move = None
                return "enter", "tactics: move: on the fallen figure's square: Enter (keeps the walk)"
        mv["tries"] += 1
        if me is None or not foes:
            self.move = None
            return "enter", "tactics: move: no goal left: Enter"
        pos = (me["x"], me["y"])
        if mv["last"] and mv["last"][0] == pos:
            mv["blocked"].add((pos, mv["last"][1]))
        if mv.get("struck"):
            self.move = None
            return "enter", "tactics: move: the blow was struck: Enter (Esc would undo the walk)"
        # Player 41: next to any of a figure's cells (a troll's second cell too), not only its corner
        adj = [f for f in foes if _dist({"x": pos[0], "y": pos[1]}, f) <= 1]
        if ((mv.get("focus") or mv.get("square")) and goal is not None and not any(f["n"] == goal["n"] for f in adj)
                and not mv.get("nofree")) or mv.get("flee"):
            adj = []         # Player 36: walking to the focus figure: past the others (a blow on them only if stuck)
        if adj:
            # the goal if it is next to us, else a helpless one, else the weakest
            f = next((f for f in adj if goal is not None and f["n"] == goal["n"]), None) or \
                min(adj, key=lambda f: (not _focus(f), not helpless(f), f["hp"]))
            # Player 37 (p37n1: StopIteration: the figure's corner on the mover's own cell, a large one): a step into
            # any of its cells next to us; none: walk on
            k = next((k for k, dx, dy in DIRS if (pos[0] + dx, pos[1] + dy) in cells(f)), None)
            if k is not None and (pos, k) not in mv["blocked"]:
                mv["last"] = (pos, k)
                mv["struck"] = True
                self.reach[mv["member"]], self.idle[mv["member"]] = "hit", 0
                self.log("TACTICS %s attacks figure %d %s (%d HP) by MOVE" % (mv["member"], f["n"], f["name"], f["hp"]))
                return k, "tactics: %s steps %s into figure %d: the attack" % (mv["member"], k, f["n"])
        if goal is None or mv["tries"] > 16:
            self.log("TACTICS %s stops at %d,%d" % (mv["member"], pos[0], pos[1]))
            self.move = None
            return "enter", "tactics: move over: Enter"
        # (p35j2: a step onto a fallen member's square asked ATTACK ALLY: every member's square is taken)
        taken = {c for f in figs if (_up(f) or f["n"] <= self.party_n) and f is not me for c in cells(f)}
        # Player 41 (Guide 8's Plan 2 additions, p39b4 98 of 115 steps, p39c2: ARN 27,13 / 27,14 / 27,13 ... with his
        # troll two squares off): a sideways step (no nearer) was allowed every time, so the walk went back and forth.
        # Now the distance is to the goal's nearest cell (its footprint), no step goes back onto a cell this MOVE has
        # stood on, and two sideways steps at most: then the fighter stands.
        gcells = cells(goal) if "fp" in goal else [(goal["x"], goal["y"])]
        dist = lambda q: min(max(abs(q[0] - c[0]), abs(q[1] - c[1])) for c in gcells)
        seen = mv.setdefault("visited", set())
        seen.add(pos)
        here = dist(pos)
        best = None
        for k, dx, dy in DIRS:
            q = (pos[0] + dx, pos[1] + dy)
            if q in taken or (pos, k) in mv["blocked"] or q in seen:
                continue
            d = dist(q)
            if best is None or d < best[0]:
                best = (d, k, q)
        if best is not None and best[0] == here:
            mv["side"] = mv.get("side", 0) + 1
            if mv["side"] > 2:
                best = (here + 1,) + best[1:]
        if (best is None or best[0] > here) and (mv.get("focus") or mv.get("square")) and not mv.get("nofree") \
                and not mv.get("flee"):
            mv["nofree"] = True      # Player 36: no free step toward the focus: strike what is next to us instead
            return self._move_step(st, p)
        if best is None or best[0] > here:
            self.log("TACTICS %s can't step nearer figure %d at %d,%d" % (mv["member"], goal["n"], pos[0], pos[1]))
            self.move = None
            return "enter", "tactics: move: no step nearer: Enter"
        mv["last"] = (pos, best[1])
        return best[1], "tactics: %s steps %s to %d,%d (figure %d at %d,%d)" % (
            mv["member"], best[1], best[2][0], best[2][1], goal["n"], goal["x"], goal["y"])

    def _aim_attack(self, st, p):
        """Player 31: the aim list is sorted by distance (half squares: 2-3 is RANGE 1, in a melee weapon's reach; seen,
        p31a2), so only its first entries can be TARGETed: pick the best of the enemies there and step NEXT straight to
        it (p31c1: a scan of all 55 entries took ~28 s a turn). A weapon's aim doesn't set DS:0xBEFD (p31c2), so the
        place is counted: the aim opens on the member's own entry 0 and NEXT steps one entry on (seen, p31a2)."""
        mem = p.g.mem
        n_ent = mem.u8(0x671A)
        ent = [(mem.u8(0x671B + 3 * i), mem.u8(0x671C + 3 * i)) for i in range(n_ent)]
        figs, party, foes = self._sides(p)
        member = self.order[0]
        can = "TARGET" in st["bottom"].split()
        if self.scan is None or self.scan.get("spell") != (member, "ATTACK"):
            byn = {f["n"]: f for f in foes}
            far = getattr(self, "far", False)
            cand = [(i, byn[n]) for i, (n, d) in enumerate(ent) if n in byn and (d <= 3 or far)]
            try:
                plain = not _magic_weapon(mem, member)
            except Exception as e:
                self.log("TACTICS weapon unreadable: %s" % e)
                plain = False
            if plain:
                # Player 32 (p32b8: CEDRIC's plain mace on a wight, 23 HP for five rounds): the drainers take harm
                # only from magic (or silver) weapons
                cand = [c for c in cand if not _is_drainer(c[1])]
            # Player 32: the level drainers next after the helpless (4:10's wights drained three in p32a4)
            if far:
                # Player 35 (Plan 1s, Gold Box Guide 2): a bow shoots the leaders and magic-users first, never a
                # helpless one out of reach (the fighters take those with a blow), then the weakest
                cand = [c for c in cand if not helpless(c[1]) or ent[c[0]][1] <= 3]
                cand.sort(key=lambda c: (not _focus(c[1]), not _is_mage(c[1]), not _is_leader(c[1]), c[1]["hp"]))
            else:
                cand.sort(key=lambda c: (not _focus(c[1]), not helpless(c[1]), not _is_drainer(c[1]), not _is_mage(c[1]),
                                         c[1]["hp"]))
            self.scan = {"spell": (member, "ATTACK"), "cand": cand, "steps": 0, "pos": 0}
        sc = self.scan
        sc["steps"] += 1
        at = sc["pos"]
        if not sc["cand"] or sc["steps"] > n_ent + 12:
            self.order = None
            self.reach[member] = "none"
            return "e", "tactics: %s: no enemy in reach: EXIT" % member
        i, f = sc["cand"][0]
        if at == i:
            if not can:
                sc["cand"].pop(0)
                return self._aim_attack_next(st, p)
            why = "helpless" if helpless(f) else ("a drainer" if _is_drainer(f) else (
                "a mage" if _is_mage(f) else "the weakest"))
            self.log("TACTICS %s attacks figure %d %s (%d HP, %s)" % (member, f["n"], f["name"], f["hp"], why))
            self.order = None
            self.reach[member] = "hit"
            self.idle[member] = 0
            if not getattr(self, "far", False):
                self.blow = member      # Player 39: AIM back at once = a second blow (Haste)
            return "t", "tactics: %s attacks figure %d (%s)" % (member, f["n"], why)
        sc["pos"] = (at + 1) % max(n_ent, 1)
        return "n", "tactics: to figure %d (aim entry %d, at %d)" % (f["n"], i, at)

    def _aim_shoot(self, st, p):
        """Player 35: a bow's aim (p35c2: with a missile weapon the aim list's count at DS:0x671A doesn't follow NEXT,
        and DS:0xBEFD isn't set): the right panel's name and HITPOINTS tell the figure aimed at. One round of NEXT
        notes every enemy TARGET takes (by name and HP), then NEXT to the best: magic-users, leaders, the weakest;
        a helpless one last (a fighter's blow takes it)."""
        figs, party, foes = self._sides(p)
        member = self.order[0]
        can = "TARGET" in st["bottom"].split()
        name = st["rows"][1].strip("? ").strip()
        hp = st["rows"][3].strip("? ").split()
        hp = int(hp[-1]) if hp and hp[-1].isdigit() else None
        cur = next((f for f in foes if f["name"] == name and f["hp"] == hp), None)
        sig = (cur["name"], cur["hp"]) if cur else None
        sc = self.scan
        if sc is None or sc.get("spell") != (member, "SHOOT"):
            sc = self.scan = {"spell": (member, "SHOOT"), "ok": {}, "steps": 0, "goal": None,
                              "n": max(p.g.mem.u8(0x671A), len(figs))}
        sc["steps"] += 1
        if sc["steps"] > 3 * sc["n"] + 10:
            self.order, self.reach[member] = None, "none"
            return "e", "tactics: %s: the shot's aim gave up: EXIT" % member
        if sc["goal"] is None:
            if cur is not None and can:
                sc["ok"][sig] = cur
            if sc["steps"] <= sc["n"]:
                return "n", "tactics: %s's shot, scan %d of %d (at %s)" % (member, sc["steps"], sc["n"], sig)
            ok = sorted(sc["ok"].values(), key=lambda f: (helpless(f), not _is_mage(f), not _is_leader(f), f["hp"]))
            if not ok:
                self.order, self.reach[member] = None, "none"
                return "e", "tactics: %s: nothing to shoot: EXIT" % member
            sc["goal"] = (ok[0]["name"], ok[0]["hp"])
        if sig == sc["goal"] and can:
            self.log("TACTICS %s shoots figure %d %s (%d HP)" % (member, cur["n"], cur["name"], cur["hp"]))
            self.shot = member
            self.order, self.reach[member], self.idle[member] = None, "hit", 0
            return "t", "tactics: %s shoots figure %d" % (member, cur["n"])
        return "n", "tactics: %s's shot: to %s (at %s)" % (member, sc["goal"], sig)

    def _aim_attack_next(self, st, p):
        sc = self.scan
        if not sc["cand"]:
            self.order = None
            self.reach[self.scan["spell"][0]] = "none"
            return "e", "tactics: no enemy TARGET takes: EXIT"
        sc["pos"] = (sc["pos"] + 1) % max(p.g.mem.u8(0x671A), 1)
        return "n", "tactics: to figure %d (the last one out of reach)" % sc["cand"][0][1]["n"]

    def _spell_list(self, st, p):
        member, spell = self.order[0], self.order[1]
        rows, im = st["rows"], st["im"]
        items = []
        for r in range(3, 23):
            t = rows[r].strip("? ").strip()
            if t and not t.endswith(" LEVEL"):
                items.append((r, t))
        names = [t for _, t in items]
        if self.order[2] == 0:
            self.seen_names = set()
        self.seen_names |= set(names)
        lit = [i for i, (r, _) in enumerate(items) if _white(im, r)]
        if spell not in names or not lit:
            if "NEXT" in st["bottom"].split() and self.order[2] < 4:
                self.order[2] += 1
                return "n", "tactics: %s's spells, next page" % member
            if self.use:
                # Player 37: this scroll lacks the spell: back to the items page, the next readied scroll
                self.order = None
                return "e", "tactics: no %s on this scroll (%s): EXIT" % (spell, ", ".join(sorted(self.seen_names)))
            self.spells[member] = set(self.seen_names)
            self.refused.add((member, spell))
            self.order = None
            return "e", "tactics: %s has no %s in memory (%s): EXIT" % (member, spell, ", ".join(sorted(self.seen_names)))
        here = [i for i, t in enumerate(names) if t == spell]
        tgt = min(here, key=lambda i: abs(i - lit[0]))
        d = tgt - lit[0]
        if d == 0:
            self.cast[spell] = self.cast.get(spell, 0) + 1     # Prayer, Bless: once (begun now, aimed when it goes off)
            if self.use:
                left = SCROLLS.get(member.upper(), [])
                if spell in left:
                    left.remove(spell)
                self.log("TACTICS %s casts %s from a scroll (left: %s)" % (member, spell, left))
                self.use = None
                # (p37h1: an item's aim shows no "SPELL:" on row 23: the spell is kept for _aim)
                self.scroll_aim = spell
            self.log("TACTICS %s begins %s" % (member, spell))
            self.order = None
            return "c", "tactics: CAST %s" % spell
        return ("end" if d > 0 else "home"), "tactics: to %s" % spell

    def _aim(self, st, p):
        """The aim of a spell going off (now, or a begun one at a later turn: the caster is the aim list's first).
        Scan the list once (NEXT) for the figures TARGET may take, then go to the best and take it; a spell that picks
        several figures (Hold Person: 3, the magic-user's 4) keeps the aim up: the next best, distinct."""
        lst, at = aim_list(p.g.mem)
        self._mem = p.g.mem
        spell = st["rows"][23].strip("? ").strip()
        spell = spell.split(":", 1)[1].strip() if ":" in spell else spell
        if not spell and getattr(self, "scroll_aim", None):
            spell = self.scroll_aim         # Player 37: a scroll's aim (no SPELL: line)
        figs, party, foes = self._sides(p)
        can = "TARGET" in st["bottom"].split()
        cur = self._aimed(st, lst, at, figs)
        caster = lst[0] if lst else None
        me = next((f for f in figs if f["n"] == caster), None)
        member = me["name"] if me else "?"
        if self.scan is None or self.scan.get("spell") != (caster, spell):
            t = self.targets(spell, me, party, foes) if me else []
            if t is None:      # on the caster (Prayer, Bless): the aim opens on the caster; else a party member
                t = [caster] + [f["n"] for f in party if f["n"] != caster]
            near = [f["n"] for f in sorted(foes, key=lambda f: _dist(me, f))] if me else [f["n"] for f in foes]
            if spell not in ("PRAYER", "BLESS", "HASTE"):
                # (Hold Person too: its picks must be distinct, the original keeps the aim up on a figure picked
                # again, p30h1; so the persons first, then anyone in reach)
                t = t + [n for n in near if n not in t]
            self.scan = {"spell": (caster, spell), "ok": set(), "steps": 0, "goal": None, "picked": set(),
                         "targets": t, "scan0": 0}
        sc = self.scan
        sc["steps"] += 1
        # Player 41 (p41a2-a5: Hold Person took 8-12 picks; the entry read at the last pick's place changed at each pick,
        # 9, then 11, 12 ... 19): OP_AIMDEBUG=1 logs the raw aim list, its index and the held enemies at every step
        # p41x1 (OP_AIMDEBUG): DS:0xBEFD stayed 21, out of the 19-entry list, through the whole aim, so _aimed fell back
        # to the panel's name and HP, and twelve unhurt 8TH LVL FIGHTERs all match: it named the first guard not yet
        # picked. NEXT follows the list in order from the caster (entry 0; steps 1-6 and 8 showed the party members at
        # entries 0-5 and 7) and the aim is back on the caster after each pick, so the NEXTs since then name the entry;
        # the list wraps where the panel shows the caster again
        r = sc["steps"] - sc["scan0"]
        if lst and not (0 <= at < len(lst)) and r >= 1:
            name = st["rows"][1].strip("? ").strip()
            pmn = [f["n"] for f in figs if f["n"] <= self.party_n and f["name"] == name]
            if sc.get("k") is None and r > 1 and pmn == [lst[0]]:
                sc["k"] = r - 1
            guess = lst[(r - 1) % (sc.get("k") or len(lst))]
            if pmn and pmn[0] != guess:
                if not sc.get("lost"):
                    sc["lost"] = True
                    self.log("TACTICS aim count lost: the panel shows %d, the count %d" % (pmn[0], guess))
            elif not sc.get("lost"):
                cur = guess
        if os.environ.get("OP_AIMDEBUG"):
            self.log("AIMDEBUG step %d at %d cur %s lst %s held %s" % (sc["steps"], at, cur, lst, sorted(
                f["n"] for f in foes if helpless(f))))
        # Player 35 (Gold Box Guide 2's diagnosis, Jeremy 13:26): the original puts the aim back on the caster after
        # each pick, so the scan starts again from there (scan0: the step of the last pick); before, only the figures
        # seen before the first pick were `ok`, and Hold Person's other two picks were thrown away
        if sc["steps"] - sc["scan0"] > 3 * max(len(lst), 4) + 10:
            p.note("tactics", "%s: %s aim gave up (%d keys)" % (member, spell, sc["steps"]))
            return "e", "tactics: %s %s: the aim gave up: EXIT" % (member, spell)
        if sc["goal"] is None:
            if cur is not None and can:
                sc["ok"].add(cur)
            if cur is not None and cur == next((t for t in sc["targets"] if t not in sc["picked"]), None) and can:
                return self._take(member, spell, cur)
            if sc["steps"] - sc["scan0"] <= len(lst):
                return "n", "tactics: aim scan (%d of %d; at %s)" % (sc["steps"] - sc["scan0"], len(lst), cur)
            ok = [t for t in sc["targets"] if t in sc["ok"] and t not in sc["picked"]]
            if spell == "HOLD PERSON" and not sc["picked"]:
                # (p31b2: picks spent on ettins, which Hold Person never holds: the first pick must be a person)
                persons = {f["n"] for f in foes if not _is_large(f)}
                ok = [t for t in ok if t in persons]
            if not ok and sc["picked"]:
                # Player 35: picks taken and nobody else in reach: EXIT ends the aim with what is picked
                p.note("tactics", "%s: %s: no more targets after %d picks" % (member, spell, len(sc["picked"])))
                return "e", "tactics: %s %s: no more targets: EXIT" % (member, spell)
            if not ok:
                p.note("tactics", "%s: %s can reach none of its targets" % (member, spell))
                self.refused.add((member, spell))
                self.unreach[(member, spell)] = 2
                return "e", "tactics: %s %s: no target in reach: EXIT" % (member, spell)
            sc["goal"] = ok[0]
        if cur == sc["goal"] and can:
            return self._take(member, spell, cur)
        return "n", "tactics: to figure %d (at %s)" % (sc["goal"], cur)

    def _aimed(self, st, lst, at, figs):
        """The figure aimed at: the aim list's entry DS:0xBEFD - 1; when that is out of the list (p30b2, p30c1: a
        begun spell's aim at a later turn) the right panel's name and HITPOINTS, if one figure only matches."""
        name = st["rows"][1].strip("? ").strip()
        # Player 39 (p39a1: LIRA's begun Haste at her next turn: the aim index stayed on figure 40 through all 53 NEXTs
        # and no party member was ever seen): a party member's name on the panel is unique, so it comes first
        pm = [f["n"] for f in figs if f["n"] <= self.party_n and f["name"] == name]
        if len(pm) == 1:
            return pm[0]
        if 0 <= at < len(lst):
            return lst[at]
        hp = st["rows"][3].strip("? ").split()
        hp = int(hp[-1]) if hp and hp[-1].isdigit() else None
        m = [f["n"] for f in figs if f["name"] == name and (hp is None or f["hp"] == hp)]
        if len(m) == 1:
            return m[0]
        live = [n for n in m if n not in (self.scan or {}).get("picked", set())]
        return live[0] if live else None

    def _take(self, member, spell, target):
        sc = self.scan
        sc["picked"].add(target)
        sc["goal"] = None
        sc["scan0"], sc["ok"] = sc["steps"], set()      # Player 35: the aim is back on the caster: scan again
        if spell == "HOLD PERSON":
            self.held.add(target)
        if spell == "SLEEP":
            self.slept[target] = self.slept.get(target, 0) + 1
        if spell == "SLOW":
            try:
                figs = {f["n"]: f for f in figures(self._mem)}
                me, t = figs.get(self.scan["spell"][0]), figs.get(target)
                k = max(me["mu"], 1) if me else 1
                foes = sorted((f for f in figs.values() if f["n"] > self.party_n and _up(f)), key=lambda f: _dist(t, f))
                self.slowed |= {f["n"] for f in foes[:k]}
            except Exception:
                self.slowed.add(target)
        self.log("TACTICS %s's %s at figure %d" % (member, spell, target))
        self.order = None
        return "t", "tactics: %s %s at figure %d" % (member, spell, target)


def _white(im, r):
    for x in range(8, 312):
        for y in range(r * 8, r * 8 + 8):
            if im.getpixel((x, y)) == (255, 255, 255):
                return True
    return False

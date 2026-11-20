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
import os, struct

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
        out.append({"n": n, "name": _name(r), "hp": r[0x11B], "status": r[0x10C],
                    "x": pos[4 * (n - 1)], "y": pos[4 * (n - 1) + 1], "fx": effects(mem, r),
                    "cl": r[0x96], "mu": r[0x9B]})   # Player 33: cleric and magic-user levels (record +0x96, +0x9B)
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


def _dist(a, b):
    return max(abs(a["x"] - b["x"]), abs(a["y"] - b["y"]))


def _is_mage(f):
    w = f["name"].upper().split()
    return any(m in w for m in MAGES) or any(m in f["name"].upper() for m in ("MAGIC", "MAGE"))


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


# Player 33: a camp's Bless (effect 1) or Prayer (49, on its caster) still standing (ours' combat_spells.gd
# EFFECT_BLESS, EFFECT_PRAYER) is not cast again
STANDING = {"BLESS": 1, "PRAYER": 49}


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
        self.priority = ("STINKING CLOUD", "HOLD PERSON", "SLOW", "PRAYER", "MAGIC MISSILE", "BLESS", "SLEEP")
        if os.environ.get("OP_TACTICS") == "horde":
            # Player 30: a horde of small figures (the kobold king): the area spells first
            self.priority = ("SLEEP", "STINKING CLOUD", "HOLD PERSON", "PRAYER", "SLOW", "BLESS", "MAGIC MISSILE")
        # Player 31: the Lead's advice: members with nothing to cast attack by hand (helpless enemies first);
        # OP_MELEE=0 keeps Player 30's QUICK
        self.melee = os.environ.get("OP_MELEE", "1") != "0"
        self.spells = {}         # member -> the spells seen in their CAST list (kept across fights; refreshed at each look)
        self.reset()

    def reset(self):
        """A new fight."""
        self.cast = {}           # spell -> times ordered this fight (Prayer, Bless once)
        self.held = set()        # figures given Hold Person (not tried again)
        self.slowed = set()      # Player 33: figures inside a Slow's reach (not aimed at again)
        self.order = None        # [member, spell, pages turned] while CAST's list is up
        self.scan = None         # aim: entries with TARGET seen
        self.refused = set()     # (member, spell) refused this turn (not in the list, nowhere to aim)
        self.last_member = None
        self.party_n = 0
        self.reach = {}          # member -> this turn's attack: "none" (nothing in reach), "done", "hit"
        self.idle = {}           # member -> turns in a row with nothing in reach
        self.guard = None        # the member whose DONE asked for GUARD
        self.turned = set()      # Player 32: members who tried TURN this fight
        self.fx_logged = False

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
        if me is None or not foes:
            return None
        known = self.spells.get(member)       # the spells seen in this member's CAST list (None: not looked yet)
        contact = any(_dist(a, f) <= 1 for a in party if _up(a) for f in foes)
        for spell in self.priority:
            if (member, spell) in self.refused or (known is not None and spell not in known):
                continue
            if spell in ("PRAYER", "BLESS") and self.cast.get(spell):
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

    def targets(self, spell, me, party, foes):
        """Figures to aim at, best first ([] none worth it; None: on the caster)."""
        if spell in ("PRAYER", "BLESS"):
            return None
        mages = sorted([f for f in foes if _is_mage(f)], key=lambda f: f["hp"])
        persons = [f for f in foes if not _is_large(f)]
        if spell in ("HOLD PERSON", "STINKING CLOUD", "SLEEP"):
            # Player 32 (p32a1: Sleep thrown at 4:10's skeletons): the undead take no Sleep, Hold or poison cloud
            foes = [f for f in foes if not _is_undead(f)]
            mages = [f for f in mages if not _is_undead(f)]
            persons = [f for f in persons if not _is_undead(f)]
        if spell == "HOLD PERSON":     # the mages first, then other persons (not large creatures)
            return [f["n"] for f in mages if f["n"] not in self.held] + \
                [f["n"] for f in persons if f["n"] not in self.held and not _is_mage(f)]
        if spell == "STINKING CLOUD":  # the biggest bunch with no party member in its area (radius 1)
            best = []
            for f in foes:
                if any(_up(a) and _dist(a, f) <= 1 for a in party) or (me and _dist(me, f) > 6):
                    continue
                k = sum(1 for g in foes if _dist(g, f) <= 1)
                if k >= 2:
                    best.append((-k, f["n"]))
            return [n for _, n in sorted(best)]
        if spell == "SLOW":            # Player 33 (spell sheet): no save; the strongest not slowed yet, so its
            # reach (the caster's level in figures nearest the aim point) takes the big hitters
            return [f["n"] for f in sorted(foes, key=lambda f: (not _is_large(f), -f["hp"])) if f["n"] not in self.slowed]
        if spell == "MAGIC MISSILE":   # the mages (weakest first), the drainers (Player 32), then the weakest
            dr = [f["n"] for f in sorted(foes, key=lambda f: f["hp"]) if _is_drainer(f) and not _is_mage(f)]
            return [f["n"] for f in mages] + dr + [f["n"] for f in sorted(foes, key=lambda f: f["hp"])
                                                    if not _is_mage(f) and f["n"] not in dr]
        if spell == "SLEEP":           # (Player 30, the horde) the biggest bunch of small figures, as Stinking Cloud;
            best = []                  # else any person (the wall's aides)
            for f in persons:
                if any(_up(a) and _dist(a, f) <= 1 for a in party) or (me and _dist(me, f) > 6):
                    continue
                k = sum(1 for g in persons if _dist(g, f) <= 1)
                best.append((-k, f["n"]))
            return [n for _, n in sorted(best)] or [f["n"] for f in persons if not _is_mage(f)]
        return [f["n"] for f in sorted(foes, key=lambda f: _dist(me, f))]

    def answer(self, scr, st, p):
        """One key for a tactical screen, or None (the plan's other rules go on)."""
        b = st["bottom"]
        if b.startswith("ABORT SPELL?"):
            # the original after an aim's EXIT (seen, p30b1): a spell with nowhere to go is given up
            self.scan = None
            return "y", "tactics: ABORT SPELL? YES (no target in reach)"
        if b.startswith("CHOOSE SPELL:") and self.order:
            return self._spell_list(st, p)
        if b.startswith("AIM:") and self.order and self.order[1] == "ATTACK":
            return self._aim_attack(st, p)
        if b.startswith("AIM:") and (self.order or "SPELL:" in st["rows"][23]):
            return self._aim(st, p)
        if b.startswith("GUARD DELAY") and self.guard:
            self.log("TACTICS %s guards" % self.guard)
            self.guard = None
            return "g", "tactics: GUARD"
        if scr["kind"] != "combat":
            return None
        member = scr.get("member", "")
        self.order = None
        self.scan = None
        try:
            figs, party, foes = self._sides(p)
            self.log("TACTICS state at %s's menu: party %d up %d HP; enemies %d up %d HP (%s)" % (
                member, sum(1 for f in party if _up(f)), sum(f["hp"] for f in party),
                len(foes), sum(f["hp"] for f in foes),
                ", ".join("%d:%s %d" % (f["n"], f["name"][:6], f["hp"]) for f in foes)))
            if not getattr(self, "fx_logged", False):
                # Player 33: the party's standing effects at the fight's first menu (a camp's Bless, Prayer...)
                self.fx_logged = True
                self.log("TACTICS party effects: %s" % "; ".join(
                    "%s %s" % (f["name"], ",".join("%d" % e for e in f.get("fx", ())) or "-") for f in party))
        except Exception as e:
            self.log("TACTICS state unreadable: %s" % e)
        if member != self.last_member:
            self.refused = {r for r in self.refused if r[0] != member}
            self.reach.pop(member, None)
            self.last_member = member
        items = b.split()
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
        if self.reach.get(member) == "none":
            figs, party, foes = self._sides(p)
            me = next((f for f in party if f["name"] == member), None)
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
        if me is not None and not any(_dist(me, f) <= 2 for f in foes):
            # (p31b1: a 16-key scan found nothing; an enemy's cell is its corner, so a large one 2 away may touch)
            self.reach[member] = "none"
            return self._fight(member, items, p)
        # (Player 32, p32b3: zombies two squares off but never TARGETable kept the count at 0 for 1400 s: it is reset
        # only by a blow, in _aim_attack)
        self.order = [member, "ATTACK", 0]
        self.scan = None
        return "a", "tactics: %s attacks by hand: AIM" % member

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
            cand = [(i, byn[n]) for i, (n, d) in enumerate(ent) if n in byn and d <= 3]
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
            cand.sort(key=lambda c: (not helpless(c[1]), not _is_drainer(c[1]), not _is_mage(c[1]), c[1]["hp"]))
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
            return "t", "tactics: %s attacks figure %d (%s)" % (member, f["n"], why)
        sc["pos"] = (at + 1) % max(n_ent, 1)
        return "n", "tactics: to figure %d (aim entry %d, at %d)" % (f["n"], i, at)

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
            self.spells[member] = set(self.seen_names)
            self.refused.add((member, spell))
            self.order = None
            return "e", "tactics: %s has no %s in memory (%s): EXIT" % (member, spell, ", ".join(sorted(self.seen_names)))
        here = [i for i, t in enumerate(names) if t == spell]
        tgt = min(here, key=lambda i: abs(i - lit[0]))
        d = tgt - lit[0]
        if d == 0:
            self.cast[spell] = self.cast.get(spell, 0) + 1     # Prayer, Bless: once (begun now, aimed when it goes off)
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
            if spell not in ("PRAYER", "BLESS"):
                # (Hold Person too: its picks must be distinct, the original keeps the aim up on a figure picked
                # again, p30h1; so the persons first, then anyone in reach)
                t = t + [n for n in near if n not in t]
            self.scan = {"spell": (caster, spell), "ok": set(), "steps": 0, "goal": None, "picked": set(),
                         "targets": t}
        sc = self.scan
        sc["steps"] += 1
        if sc["steps"] > 6 * max(len(lst), 4) + 10:
            p.note("tactics", "%s: %s aim gave up (%d keys)" % (member, spell, sc["steps"]))
            return "e", "tactics: %s %s: the aim gave up: EXIT" % (member, spell)
        if sc["goal"] is None:
            if cur is not None and can:
                sc["ok"].add(cur)
            if cur is not None and cur == next((t for t in sc["targets"] if t not in sc["picked"]), None) and can:
                return self._take(member, spell, cur)
            if sc["steps"] <= len(lst):
                return "n", "tactics: aim scan (%d of %d; at %s)" % (sc["steps"], len(lst), cur)
            ok = [t for t in sc["targets"] if t in sc["ok"] and t not in sc["picked"]]
            if spell == "HOLD PERSON" and not sc["picked"]:
                # (p31b2: picks spent on ettins, which Hold Person never holds: the first pick must be a person)
                persons = {f["n"] for f in foes if not _is_large(f)}
                ok = [t for t in ok if t in persons]
            if not ok:
                p.note("tactics", "%s: %s can reach none of its targets" % (member, spell))
                return "e", "tactics: %s %s: no target in reach: EXIT" % (member, spell)
            sc["goal"] = ok[0]
        if cur == sc["goal"] and can:
            return self._take(member, spell, cur)
        return "n", "tactics: to figure %d (at %s)" % (sc["goal"], cur)

    def _aimed(self, st, lst, at, figs):
        """The figure aimed at: the aim list's entry DS:0xBEFD - 1; when that is out of the list (p30b2, p30c1: a
        begun spell's aim at a later turn) the right panel's name and HITPOINTS, if one figure only matches."""
        if 0 <= at < len(lst):
            return lst[at]
        name = st["rows"][1].strip("? ").strip()
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
        if spell == "HOLD PERSON":
            self.held.add(target)
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

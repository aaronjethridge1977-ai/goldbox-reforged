"""Player 46 (Gold Box Guide 12's step 2, the field read): a fight's field as text, for the Player chat to choose
round 1, contact and every aimed spell (docs/strategy/player-capability.md; tactics.py `keyturns`).

  render(figs, party_n, walls=(), clouds=(), title="")     the text (figs: tactics.figures())
  python3 field.py <snapshot.json>                         the text again from a key turn's snapshot (offline)

The read: a map of the field around the figures (x across, y down, the original's cells: tactics.py), the party as
the digits of their figure numbers, the foes as letters (capital standing, small helpless, '+' fallen), '#' walls,
'~' this fight's Stinking Cloud cells; a table of every figure (cells, HP, effects by name, who it touches); for each
caster the eight rays from his cell (the figures on each, nearest first, to 12 squares: a bolt's line); the Stinking
Cloud aims (2x2: the aimed cell, right, below, below-right) catching most standing foes and none of ours, and the
Fireball points (the foe with most foes within 1 of it, no member within 3: the tool's own Fireball rule).
"""
import json, sys

# effect types seen in fights (tactics.py HELPLESS, STANDING; ours' combat_spells.gd)
# (others shown as fx<type>)
FX = {0x01: "Bless", 0x31: "Prayer", 0x27: "Haste", 0x33: "snake charm", 0x34: "held", 0x35: "asleep",
      0x1F: "helpless (cloud)"}
HELPLESS = (0x33, 0x34, 0x35, 0x1F)
STATUS = {0: "", 4: "unconscious", 5: "dying", 6: "dead"}     # record +0x10C (others shown as status <n>)
FOOTPRINT = {1: ((0, 0),), 2: ((0, 0), (0, 1)), 3: ((0, 0), (1, 0)), 4: ((0, 0), (1, 0), (0, 1), (1, 1))}
DIRS8 = (("N", 0, -1), ("NE", 1, -1), ("E", 1, 0), ("SE", 1, 1), ("S", 0, 1), ("SW", -1, 1), ("W", -1, 0), ("NW", -1, -1))


def cells(f):
    return [(f["x"] + dx, f["y"] + dy) for dx, dy in FOOTPRINT.get(f.get("fp", 1), ((0, 0),))]


def dist(a, b):
    return min(max(abs(p[0] - q[0]), abs(p[1] - q[1])) for p in cells(a) for q in cells(b))


def up(f):
    return f["hp"] > 0 and f["status"] == 0


def helpless(f):
    return up(f) and any(e in HELPLESS for e in f.get("fx", ()))


def keys(figs, party_n):
    """figure n -> its map letter: the party their number's digit, the foes a-z then A-Z by number."""
    out, i = {}, 0
    letters = "abcdefghijklmnopqrstuvwxyz"
    for f in figs:
        if f["n"] <= party_n:
            out[f["n"]] = str(f["n"] % 10)
        else:
            out[f["n"]] = letters[i % 26] + ("" if i < 26 else str(i // 26))
            i += 1
    return out


def render(figs, party_n, walls=(), clouds=(), title="", spells=None):
    walls, clouds = set(map(tuple, walls)), set(map(tuple, clouds))
    k = keys(figs, party_n)
    party = [f for f in figs if f["n"] <= party_n]
    foes = [f for f in figs if f["n"] > party_n]
    standing = [f for f in foes if up(f)]
    lines = [title] if title else []
    xs = [c[0] for f in figs for c in cells(f)] or [0]
    ys = [c[1] for f in figs for c in cells(f)] or [0]
    x0, x1 = max(0, min(xs) - 3), min(49, max(xs) + 3)
    y0, y1 = max(0, min(ys) - 2), min(24, max(ys) + 2)
    at = {}
    for f in sorted(figs, key=lambda f: up(f)):       # the standing drawn over the fallen
        ch = k[f["n"]][0]
        if f["n"] > party_n:
            ch = ch if helpless(f) else (ch.upper() if up(f) else "+")
        elif not up(f):
            ch = "_"
        for c in cells(f):
            at[c] = ch
    lines.append("     " + "".join(str(x // 10) if x % 10 == 0 or x == x0 else " " for x in range(x0, x1 + 1)))
    lines.append("     " + "".join(str(x % 10) for x in range(x0, x1 + 1)))
    for y in range(y0, y1 + 1):
        row = "".join(at.get((x, y), "#" if (x, y) in walls else ("~" if (x, y) in clouds else "."))
                      for x in range(x0, x1 + 1))
        lines.append("%4d %s" % (y, row))
    lines.append("(party: figure digits, '_' down; foes: capital standing, small helpless, '+' fallen; '#' wall, "
                 "'~' cloud)")
    lines.append("")
    lines.append("key  n  name             cell     HP      state / effects                  touching")
    for f in figs:
        if f["n"] > party_n and not up(f) and f["hp"] <= 0:
            continue
        side = party if f["n"] > party_n else standing
        touch = [k[g["n"]] for g in side if (up(g) or g["n"] > party_n) and dist(f, g) <= 1]
        fx = [FX.get(e, "fx%d" % e) for e in f.get("fx", ())]
        state = ", ".join([s for s in [STATUS.get(f["status"], "status %d" % f["status"])] if s] + fx) or "-"
        c = "%d,%d" % (f["x"], f["y"]) + ("" if f.get("fp", 1) == 1 else "/%d" % f["fp"])
        lines.append("%-4s %-2d %-16s %-8s %3d/%-3s %-32s %s" % (
            k[f["n"]], f["n"], f["name"][:16], c, f["hp"], f.get("max", "?"), state[:32], " ".join(touch) or "-"))
    if spells:
        lines.append("")
        lines.append("spells in memory (range in squares; a spell is aimed at a cell within it):")
        for f in party:
            sp = spells.get(f["n"]) or spells.get(str(f["n"]))
            if sp:
                lines.append("  %s %s: %s" % (k[f["n"]], f["name"], sp))
    fallen = [f for f in foes if not up(f)]
    if fallen:
        lines.append("fallen foes: %d (%s)" % (len(fallen), ", ".join(sorted({f["name"] for f in fallen}))))
    lines.append("")
    occ = {}
    for f in figs:
        if up(f) or f["n"] <= party_n:
            for c in cells(f):
                occ[c] = f
    casters = [f for f in party if up(f) and (f.get("cl") or f.get("mu"))]
    if casters:
        lines.append("rays from each caster (8 directions, to 12 squares, the figures on each, nearest first; '#' a wall):")
        for f in casters:
            out = []
            for d, dx, dy in DIRS8:
                seen, x, y = [], f["x"], f["y"]
                for _ in range(12):
                    x, y = x + dx, y + dy
                    if not (0 <= x < 50 and 0 <= y < 25):
                        break
                    if (x, y) in walls:
                        seen.append("#")
                        break
                    g = occ.get((x, y))
                    if g is not None and g is not f and (not seen or seen[-1] != k[g["n"]]):
                        seen.append(k[g["n"]] if g["n"] <= party_n or not helpless(g) else k[g["n"]].lower())
                if any(s not in ("#",) for s in seen):
                    mark = " (ours on it)" if any(s.isdigit() for s in seen) else ""
                    out.append("%s %s%s" % (d, "".join(seen), mark))
            lines.append("  %s (%d,%d): %s" % (f["name"], f["x"], f["y"], "; ".join(out) or "none"))
        lines.append("")
    ours = {c for f in party if up(f) for c in cells(f)}
    best = []
    for x in range(0, 49):
        for y in range(0, 24):
            area = {(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)}
            if area & ours or area & walls or area & clouds:
                continue
            inside = [g for g in standing if area & set(cells(g)) and not helpless(g)]
            if len(inside) >= 2:
                best.append((-len(inside), x, y, inside))
    if best:
        lines.append("Stinking Cloud aims (2x2 from the cell; most standing foes, none of ours, no cloud there):")
        for n, x, y, inside in sorted(best, key=lambda b: (b[0], b[1], b[2]))[:6]:
            lines.append("  %d,%d: %d (%s)" % (x, y, -n, " ".join(k[g["n"]] for g in inside)))
    fb = []
    for f in standing:
        near = min((dist(a, f) for a in party if up(a)), default=99)
        if near <= 3:
            continue
        n = [g for g in standing if dist(g, f) <= 1]
        if len(n) >= 2:
            fb.append((-len(n), near, f, n))
    if fb:
        lines.append("Fireball points (a foe with most foes within 1 of it; nearest member over 3 squares off):")
        for n, near, f, inside in sorted(fb, key=lambda b: (b[0], -b[1]))[:5]:
            lines.append("  %s at %d,%d: %d (%s), nearest member %d" % (k[f["n"]], f["x"], f["y"], -n,
                                                                    " ".join(k[g["n"]] for g in inside), near))
    lines.append("")
    return "\n".join(lines)


ORDER_HELP = """orders: one line per member (members not named: the tool's rules), # starts a comment:
  <MEMBER> cast <SPELL> [at x,y [x,y ...]]   a spell from memory; aimed by MANUAL at the cells, in turn (Hold Person's picks)
  <MEMBER> use <ITEM WORD> [at x,y] [swap=<word>]   an item (wand, Javelin, Necklace, potion)
  <MEMBER> move x,y      walk there (no blow on the way; the rest of the turn by the rules)
  <MEMBER> attack x,y    walk to the figure on that cell and strike it
  <MEMBER> guard | quick | rules
  go                     no orders: the rules for everyone"""


def parse_orders(text):
    """{MEMBER: {"do": cast|use|move|attack|guard|quick|rules, "what": .., "cells": [(x, y)], "swap": ..}}"""
    out = {}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or line.lower() == "go":
            continue
        w = line.split()
        verbs = ("cast", "use", "move", "attack", "guard", "quick", "rules")
        i = next((j for j, x in enumerate(w) if x.lower() in verbs), None)
        if i is None or i == 0:
            raise ValueError("no member or no order in %r" % line)
        member, verb, rest = " ".join(w[:i]).upper(), w[i].lower(), w[i + 1:]
        opt = {x.split("=", 1)[0].lower(): x.split("=", 1)[1] for x in rest if "=" in x}
        rest = [x for x in rest if "=" not in x]
        cs = []
        if "at" in [x.lower() for x in rest]:
            j = [x.lower() for x in rest].index("at")
            cs = [tuple(int(v) for v in c.split(",")) for c in rest[j + 1:]]
            rest = rest[:j]
        elif verb in ("move", "attack"):
            cs = [tuple(int(v) for v in c.split(",")) for c in rest]
            rest = []
        if verb in ("move", "attack") and len(cs) != 1:
            raise ValueError("%s needs one cell x,y: %r" % (verb, line))
        if verb in ("cast", "use") and not rest:
            raise ValueError("%s needs a spell or item: %r" % (verb, line))
        out[member] = {"do": verb, "what": " ".join(rest).replace("_", " ").upper(), "cells": cs,
                       "swap": opt.get("swap", "").replace("_", " ").upper()}
    return out


if __name__ == "__main__":
    s = json.load(open(sys.argv[1]))
    print(render(s["figs"], s["party_n"], s.get("walls", ()), s.get("clouds", ()), s.get("title", ""), s.get("spells")))

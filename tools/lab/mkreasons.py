#!/usr/bin/env python3
"""mkreasons.py < missctx.sh output: a first draft of an area's reasons table (chat 18) for
docs/coverage-areas.md. Missed branches are grouped by misswhy.py's guess (a flag's values, a roll,
the party, another area, a fight, a menu, unreached code) into rows "| where | what it needs |".
The "what it needs" column is a draft: check each against the listing before it goes in the doc.
"""
import re
import sys

DRAFT = {
    "unreached": "neither side ran: the code above it was never reached",
    "roll": "a roll (RANDOM in this area) that didn't come out that way",
    "counter": "a counter at another value (visits, tries)",
    "clock": "another hour or day",
    "fight": "a fight's result other than won (lost ends the game; fled is a flee job's)",
    "party": "another party (a member's stats, class, size or strength)",
    "menu": "a menu answer not given",
    "menu (the choice not taken)": "the reaction no choice gave in the runs' rolls",
    "outside": "a byte nothing in this area writes: another area's flag, or the engine",
    "surprise": "a surprise roll (3: both sides surprised)",
    "facing": "arriving or turning a particular way",
    "wall ahead": "a wall ahead on that square from that side",
    "square": "another square's bits",
    "searching": "SEARCH on (or off) at that moment",
}

rows = {}
order = []
for line in sys.stdin:
    line = line.rstrip()
    m = re.match(r'^(.*?)\s*(?<![\[0-9A-F])([0-9A-F]{4}) ([A-Z_]+) (.*?)\s{2,}', line + "  ")
    if not m:
        continue
    guess, off, op, rest = m.group(1).strip(), m.group(2), m.group(3), m.group(4).strip()
    if op.startswith("IF_") or op in ("ON_GOTO", "ON_GOSUB"):
        what = rest.replace("-> ", "→ ")
    else:
        what = rest
    # the first named byte in the guess decides the group
    key = guess
    g = re.match(r'\[([0-9A-F]{4})\] (\S+(?: \S+)?)', guess)
    if g:
        kind = g.group(2)
        if kind.startswith("flag"):
            key = "flag %s %s" % (g.group(1), kind[5:])
        elif kind in ("outside", "counter", "roll", "party", "clock", "fight", "surprise", "facing", "wall ahead",
                      "square", "searching"):
            key = kind if kind != "outside" else "outside %s" % g.group(1)
        else:
            key = "%s %s" % (g.group(1), kind)
    if key not in rows:
        rows[key] = []
        order.append(key)
    item = "0x%s %s %s" % (off, op, what)
    rows[key].append(item)


def need(key):
    if key.startswith("flag "):
        _, addr, vals = key.split(" ", 2)
        return "0x%s at another value (this area writes %s)" % (addr, vals or "it")
    if key.startswith("outside "):
        return "0x%s: nothing in this area writes it (another area's flag, or the engine)" % key.split()[1]
    return DRAFT.get(key, key or "(no guess)")


print("| where | what it needs |")
print("|---|---|")
for k in order:
    items = rows[k]
    # merge outcomes of one instruction: "0x9A10 IF_EQ → T", "0x9A10 IF_EQ → F" -> "0x9A10 → T, F"
    merged = {}
    for it in items:
        mm = re.match(r'(0x[0-9A-F]{4}) (\S+)(?: → (.*)| choice \d+ (.*))?', it)
        if mm:
            o = mm.group(1)
            out = mm.group(3) or mm.group(4) or ""
            merged.setdefault(o, []).append(out)
    where = "; ".join("%s → %s" % (o, ", ".join(x for x in v if x)) if any(v) else o for o, v in merged.items())
    print("| %s | %s |" % (where, need(k)))

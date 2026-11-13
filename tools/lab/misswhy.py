#!/usr/bin/env python3
"""misswhy.py <listing from tools/ecl.py dis> < missctx.sh output: a first guess at why each missed
branch was missed, from what the test reads and what in the area writes it (chat 16).

The guesses are a start for the reasons docs/coverage-areas.md gives, not the reasons:
  unreached   neither outcome ran: the instruction itself was never reached (look above it)
  roll        the tested value comes from RANDOM in this area
  counter     it is counted up (ADD/SUBTRACT): a number of visits or tries
  clock       the game clock (0x49C6-0x49CA): an hour or a day
  fight       a fight's result (0x6DC7), or an ON_GOTO right after COMBAT
  party       the character window (0x6B00-0x6DBF), party size or strength: another party
  menu        a menu's answer (MENU_*, ENCOUNTER_MENU, INPUT_*)
  flag        a flag byte written with constants here: the listed values
  outside     nothing in this area writes it: another area, or the engine
"""
import re
import sys

dis = open(sys.argv[1]).read().splitlines()
ins = []
for line in dis:
    m = re.match(r'^([0-9A-F]{4})\s+(\S+)\s*(.*)$', line)
    if m:
        ins.append((m.group(1), m.group(2), m.group(3)))
idx = {o: i for i, (o, _, _) in enumerate(ins)}
DEST = {"WRITE_MEM": 1, "ADD": 2, "SUBTRACT": 2, "MULTIPLY": 2, "DIVIDE": 2, "AND": 2, "OR": 2,
        "RANDOM": 1, "RANDOM0": 1, "COPY_MEM": 2, "PARTY_STRENGTH": 0, "MENU_HORIZONTAL": 0,
        "INPUT_NUMBER": 1, "INPUT_STRING": 1, "ENCOUNTER_MENU": 3, "WRITE_MEM_BASE_OFF": 1}


def args(text):
    # Strings may hold commas; keep them whole.
    return [a.strip() for a in re.findall(r'"[^"]*"|[^,]+', text)]


writers = {}
for o, op, a in ins:
    k = DEST.get(op)
    al = args(a)
    if k is not None and k < len(al) and al[k].startswith("["):
        writers.setdefault(al[k], []).append((o, op, al))


def kind(addr, near):
    x = int(addr.strip("[]"), 16)
    if 0x49C6 <= x <= 0x49CA:
        return "clock"
    if x == 0x6DC7:
        return "fight"
    if 0x6B00 <= x <= 0x6DBF or x in (0x6E3E, 0x6DCF):
        return "party"
    w = writers.get(addr, [])
    if not w:
        return "outside"
    ops = {op for _, op, _ in w}
    if ops & {"RANDOM", "RANDOM0"}:
        return "roll"
    if ops & {"MENU_HORIZONTAL", "INPUT_NUMBER", "INPUT_STRING", "ENCOUNTER_MENU"}:
        return "menu"
    if ops & {"ADD", "SUBTRACT"}:
        return "counter"
    if ops == {"WRITE_MEM"}:
        vals = sorted({al[0] for _, _, al in w})
        if any(v.startswith("[") for v in vals):
            return "copy of " + "/".join(v for v in vals if v.startswith("["))
        return "flag " + "/".join(vals[:6])
    return "+".join(sorted(ops)).lower()


lines = [l.rstrip("\n") for l in sys.stdin if l.strip()]
offs = {}
for l in lines:
    offs.setdefault(l.split()[0], []).append(l)
for l in lines:
    off = l.split()[0]
    i = idx.get(off)
    hint = ""
    if i is not None:
        op = ins[i][1]
        if op.startswith("IF_") and len(offs[off]) >= 2:
            hint = "unreached"
        elif op.startswith("IF_") and i > 0 and ins[i - 1][1] in ("COMPARE", "COMPARE_AND"):
            ks = []
            for a in args(ins[i - 1][2]):
                if re.fullmatch(r'\[[0-9A-F]{4}\]', a):
                    ks.append("%s %s" % (a, kind(a, i)))
            hint = "; ".join(ks)
        elif op in ("ON_GOTO", "ON_GOSUB"):
            back = [ins[j][1] for j in range(max(0, i - 3), i)]
            a0 = args(ins[i][2])[0] if ins[i][2] else ""
            menus = [ins[j] for j in range(max(0, i - 3), i) if ins[j][1].startswith("MENU") or ins[j][1] == "ENCOUNTER_MENU"]
            if "COMBAT" in back:
                hint = "fight"
            elif any(args(m[2])[3 if m[1] == "ENCOUNTER_MENU" else 0] == a0 for m in menus if args(m[2])):
                hint = "menu (the choice not taken)"
            elif a0.startswith("["):
                hint = "%s %s" % (a0, kind(a0, i))
        elif op == "ENCOUNTER_MENU" or op.startswith("MENU"):
            hint = "menu"
    print("%-12s %s" % (hint[:60], l))

#!/usr/bin/env python3
"""chaintests.py <listing from tools/ecl.py dis> <offset hex> [T|F|<n>] [writers.json]: the chain of tests on
a shortest way from one of the block's entry points (on move, on search, ...) to the instruction at <offset>,
and to the outcome asked for (an IF's T or F, an ON_GOTO's n). Decided 2026-11-14: directed coverage is
semi-automatic; this prints what a variant has to set, and writers.py's index says who writes each byte.

ECL flow: IF_xx runs the next instruction when the test holds and skips it when not; GOTO, GOSUB (and back),
ON_GOTO / ON_GOSUB (each target, or on past the table), EXIT / RETURN / NEW_ECL end a way. Each test on the
way is printed with what it must give, the instruction before it (COMPARE, AND...), and, for each memory byte
in that instruction, its writers (this block's first, then other blocks' from the index).
"""
import json
import re
import sys
from collections import deque

ENTRY_NAMES = ["on move", "on search", "on rest interrupted", "on rest", "on init"]


def load(path):
    ins = []
    for line in open(path):
        m = re.match(r'^([0-9A-F]{4})\s+(\S+)\s*(.*)$', line.rstrip("\n"))
        if m:
            ins.append((int(m.group(1), 16), m.group(2), m.group(3)))
    return ins


def targets(text):
    return [int(t, 16) for t in re.findall(r'\[([0-9A-F]{4})\]', text)]


def graph(ins):
    at = {o: i for i, (o, _, _) in enumerate(ins)}
    succ = {}      # offset -> [(next offset, label)]
    for i, (o, op, a) in enumerate(ins):
        nxt = ins[i + 1][0] if i + 1 < len(ins) else None
        nxt2 = ins[i + 2][0] if i + 2 < len(ins) else None
        e = []
        if op.startswith("IF_"):
            if nxt is not None:
                e.append((nxt, "T"))
            if nxt2 is not None:
                e.append((nxt2, "F"))
        elif op == "GOTO":
            e = [(t, "") for t in targets(a)[:1]]
        elif op == "GOSUB":
            e = [(t, "call") for t in targets(a)[:1]] + ([(nxt, "back")] if nxt is not None else [])
        elif op in ("ON_GOTO", "ON_GOSUB"):
            ts = targets(a)[1:] if a.startswith("[") else targets(a)
            e = [(t, str(k)) for k, t in enumerate(ts)]
            if nxt is not None:
                e.append((nxt, "out" if op == "ON_GOTO" else "back"))
        elif op in ("EXIT", "RETURN", "NEW_ECL"):
            e = []
        elif nxt is not None:
            e = [(nxt, "")]
        succ[o] = [(t, l) for t, l in e if t in at]
    return at, succ


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    ins = load(argv[1])
    goal = int(argv[2], 16)
    want = argv[3] if len(argv) > 3 and argv[3] not in ("-",) else ""
    widx = json.load(open(argv[4])) if len(argv) > 4 else {}
    at, succ = graph(ins)
    entries = {}
    for k, name in enumerate(ENTRY_NAMES):
        if k < len(ins) and ins[k][1] == "GOTO" and targets(ins[k][2]):
            entries[targets(ins[k][2])[0]] = name
    # Shortest way from any entry (breadth first).
    prev = {}
    q = deque()
    for e in entries:
        prev[e] = None
        q.append(e)
    while q:
        o = q.popleft()
        if o == goal:
            break
        for t, l in succ.get(o, []):
            if t not in prev:
                prev[t] = (o, l)
                q.append(t)
    if goal not in prev:
        print("no way from an entry point to %04X (reached only from another block, or a decoder gap)" % goal)
        return 0
    way = []
    o = goal
    while prev[o] is not None:
        p, l = prev[o]
        way.append((p, l))
        o = p
    way.reverse()
    start = o
    print("%04X from %s:" % (goal, entries[start]))
    writers_here = {}
    for o2, op, a in ins:
        for d in re.findall(r'\[([0-9A-F]{4})\]', a)[-1:]:
            if op in ("WRITE_MEM", "ADD", "SUBTRACT", "AND", "OR", "RANDOM", "RANDOM0", "COPY_MEM", "MULTIPLY",
                      "DIVIDE", "WRITE_MEM_BASE_OFF", "MENU_HORIZONTAL", "INPUT_STRING", "INPUT_NUMBER"):
                writers_here.setdefault(d, []).append("%04X %s %s" % (o2, op, a[:40]))
    steps = way + ([(goal, want)] if want else [])
    shown = set()
    for p, l in steps:
        i = at[p]
        op = ins[i][1]
        if not (op.startswith("IF_") or op in ("ON_GOTO", "ON_GOSUB")) or l in ("call", "back", ""):
            if op in ("GOSUB",) and l == "call":
                print("  %04X GOSUB into %s" % (p, ins[i][2]))
            continue
        test = ins[i - 1] if op.startswith("IF_") and i > 0 else ins[i]
        need = {"T": "holds", "F": "fails"}.get(l, "-> %s" % l)
        print("  %04X %-8s %-5s  after %04X %s %s" % (p, op, need, test[0], test[1], test[2][:60]))
        mem = re.findall(r'\[([0-9A-F]{4})\]', test[2])
        if test[1] in ("ON_GOTO", "ON_GOSUB", "GOSUB"):
            mem = mem[:1] if test[1] != "GOSUB" else []
        for d in mem:
            if d in shown:
                continue
            shown.add(d)
            here = writers_here.get(d, [])
            # Other blocks' writers matter for the shared memory (flags 0x4A00-0x4AFF, 0x4900-0x49FF);
            # the scratch bytes (0x6E7x...) are each block's own.
            other = [w for w in widx.get(d, []) if not (len(argv) > 5 and w.startswith(argv[5] + " "))] \
                if (0x4900 <= int(d, 16) < 0x4A00 or 0x4A20 <= int(d, 16) < 0x4B00) else []
            print("        [%s] here: %s" % (d, "; ".join(here[:4]) + (" ..." if len(here) > 4 else "") if here else "none"))
            if other:
                print("        [%s] elsewhere: %s" % (d, "; ".join(other[:5]) + (" ... (%d)" % len(other) if len(other) > 5 else "")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

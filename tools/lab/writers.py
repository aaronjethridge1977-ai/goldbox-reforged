#!/usr/bin/env python3
"""writers.py <game folder> <out.json>: the writers index (decided 2026-11-14, kept permanently): for every
memory byte any script of ECL1-8 writes, each writing instruction as "set:block OFFSET OP args". An indexed
write (WRITE_MEM_BASE_OFF v, [base], [index]) is listed under its base with "+index". The engine's own writes
into the flag range (GAME.OVR, research/pool-of-radiance-formats.md "Who writes the story flags") are added
under "engine". chaintests.py prints from it.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ECL = os.environ.get("ECL_PY", os.path.join(HERE, "..", "ecl.py"))
DEST = {"WRITE_MEM": -1, "ADD": -1, "SUBTRACT": -1, "MULTIPLY": -1, "DIVIDE": -1, "AND": -1, "OR": -1,
        "RANDOM": -1, "RANDOM0": 0, "COPY_MEM": -1, "WRITE_MEM_BASE_OFF": 1, "MENU_HORIZONTAL": 0,
        "MENU_VERTICAL": 0, "INPUT_STRING": -1, "INPUT_NUMBER": -1, "ENCOUNTER_MENU": 3, "PARLAY": -1,
        "PARTY_STRENGTH": 0, "SPELL": -1, "WHO": -1}
ENGINE = {"4AFA": ["engine GAME.OVR 0x1FE9C saving: word DS:0x6AB2"],
          "4AFB": ["engine GAME.OVR 0x1FE9C saving: word DS:0x6AB6"],
          "4AFC": ["engine GAME.OVR 0x1FE9C saving: word DS:0x6ABA"],
          "4AFD": ["engine GAME.OVR 0x1FEC2 saving: word DS:0x6AB4"],
          "4AFE": ["engine GAME.OVR 0x1FEC2 saving: word DS:0x6AB8"],
          "4AFF": ["engine GAME.OVR 0x1FEC2 saving: word DS:0x6ABC", "engine GAME.OVR 0x2CFAD = 0 (code wheel)"]}


def args(text):
    return [a.strip() for a in re.findall(r'"[^"]*"|[^,]+', text)]


def main(argv):
    game, out = argv[1], argv[2]
    idx = {}
    for s in range(1, 9):
        path = os.path.join(game, "ECL%d.DAX" % s)
        lst = subprocess.run([sys.executable, ECL, "list", path], capture_output=True, text=True).stdout
        for m in re.finditer(r'^block\s+(\d+)', lst, re.M):
            b = int(m.group(1))
            dis = subprocess.run([sys.executable, ECL, "dis", path, str(b)], capture_output=True, text=True).stdout
            for line in dis.splitlines():
                mm = re.match(r'^([0-9A-F]{4})\s+(\S+)\s*(.*)$', line)
                if not mm or mm.group(2) not in DEST:
                    continue
                op, al = mm.group(2), args(mm.group(3))
                k = DEST[op]
                if not al or abs(k) > len(al):
                    continue
                d = al[k]
                if not re.fullmatch(r'\[[0-9A-F]{4}\]', d):
                    continue
                note = "%d:%d %s %s %s" % (s, b, mm.group(1), op, mm.group(3)[:50])
                if op == "WRITE_MEM_BASE_OFF":
                    note += " (+index)"
                idx.setdefault(d.strip("[]"), []).append(note)
    for k, v in ENGINE.items():
        idx.setdefault(k, []).extend(v)
    json.dump(idx, open(out, "w"), indent=0, sort_keys=True)
    print("%d bytes written by some instruction" % len(idx))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

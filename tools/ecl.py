#!/usr/bin/env python3
"""Developer tool: disassemble Gold Box ECL event scripts (Pool of Radiance).

Usage:
    python3 tools/ecl.py list <ECLn.DAX>              # blocks, coverage, map and wall-set loads
    python3 tools/ecl.py dis  <ECLn.DAX> <block id>   # full listing, following control flow

Same rules as scripts/formats/ecl_script.gd; format notes in the ai-business-ideas repo
(research/pool-of-radiance-formats.md).
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dax import read_dax  # noqa: E402

BASE = 0x9900
ENTRY_NAMES = ["on move", "on search", "on rest", "on rest interrupted", "on init"]
# opcode: (name, operand count, index of the operand giving the extra-operand count)
OPS = {
    0x00: ("EXIT", 0, -1), 0x01: ("GOTO", 1, -1), 0x02: ("GOSUB", 1, -1), 0x03: ("COMPARE", 2, -1),
    0x04: ("ADD", 3, -1), 0x05: ("SUBTRACT", 3, -1), 0x06: ("DIVIDE", 3, -1), 0x07: ("MULTIPLY", 3, -1),
    0x08: ("RANDOM", 2, -1), 0x09: ("WRITE_MEM", 2, -1), 0x0A: ("LOAD_CHAR", 1, -1),
    0x0B: ("LOAD_MON", 3, -1), 0x0C: ("SPRITE_START", 3, -1), 0x0D: ("SPRITE_ADVANCE", 0, -1),
    0x0E: ("PICTURE", 1, -1), 0x0F: ("INPUT_NUMBER", 2, -1), 0x10: ("INPUT_STRING", 2, -1),
    0x11: ("PRINT", 1, -1), 0x12: ("PRINT_CLEAR", 1, -1), 0x13: ("RETURN", 0, -1),
    0x14: ("COMPARE_AND", 4, -1), 0x15: ("MENU_VERTICAL", 3, 2),
    0x16: ("IF_EQ", 0, -1), 0x17: ("IF_NE", 0, -1), 0x18: ("IF_LT", 0, -1), 0x19: ("IF_GT", 0, -1),
    0x1A: ("IF_LE", 0, -1), 0x1B: ("IF_GE", 0, -1), 0x1C: ("CLEAR_MON", 0, -1),
    0x1D: ("PARTY_STRENGTH", 1, -1), 0x1E: ("PARTY_CHECK", 6, -1), 0x1F: ("UNUSED_1F", 0, -1),
    0x20: ("NEW_ECL", 1, -1), 0x21: ("LOAD_AREA_MAP", 3, -1), 0x22: ("PARTY_SKILL_CHECK", 2, -1),
    0x23: ("SURPRISE", 4, -1), 0x24: ("COMBAT", 0, -1), 0x25: ("ON_GOTO", 2, 1), 0x26: ("ON_GOSUB", 2, 1),
    0x27: ("TREASURE", 8, -1), 0x28: ("ROB", 3, -1), 0x29: ("ENCOUNTER_MENU", 14, -1),
    0x2A: ("COPY_MEM", 3, -1), 0x2B: ("MENU_HORIZONTAL", 2, 1), 0x2C: ("PARLAY", 6, -1),
    0x2D: ("CALL", 1, -1), 0x2E: ("DAMAGE", 5, -1), 0x2F: ("AND", 3, -1), 0x30: ("OR", 3, -1),
    0x31: ("SPRITE_OFF", 0, -1), 0x32: ("FIND_ITEM", 1, -1), 0x33: ("PRINT_RETURN", 0, -1),
    0x34: ("CLOCK", 1, -1), 0x35: ("WRITE_MEM_BASE_OFF", 3, -1), 0x36: ("NPC_ADD", 2, -1),
    0x37: ("LOAD_AREA_DECO", 3, -1), 0x38: ("PROGRAM", 1, -1), 0x39: ("WHO", 1, -1),
    0x3A: ("DELAY", 0, -1), 0x3B: ("SPELL", 3, -1), 0x3C: ("PRINT_RUNES", 1, -1),
    0x3D: ("CLEAR_BOX", 0, -1), 0x3E: ("NPC_REMOVE", 0, -1), 0x3F: ("HAS_EFFECT", 1, -1),
    0x40: ("DESTROY_ITEM", 1, -1), 0x41: ("GIVE_EXP", 2, -1), 0x42: ("UNUSED_42", 0, -1),
    0x43: ("SOUND", 1, -1), 0x44: ("UNKNOWN_44", 0, -1), 0x45: ("RANDOM0", 2, -1),
    0x46: ("FOR_START", 2, -1), 0x47: ("FOR_REPEAT", 0, -1), 0x48: ("UNKNOWN_48", 1, -1),
    0x49: ("UNKNOWN_49", 6, -1), 0x4A: ("UNKNOWN_4A", 0, -1), 0x4B: ("UNKNOWN_4B", 1, -1),
    0x4C: ("PICTURE2", 2, -1),
}
STOPS = {"EXIT", "RETURN", "GOTO", "NEW_ECL", "UNUSED_1F"}  # ON_GOTO falls through past its list


def text(packed: bytes) -> str:
    out = ""
    for i in range(0, len(packed), 3):
        group = packed[i:i + 3]
        n = int.from_bytes(group + bytes(3 - len(group)), "big")
        for k in range(4 if len(group) == 3 else len(group)):
            v = (n >> (18 - 6 * k)) & 63
            if v:
                out += chr(v + 0x40) if v < 0x20 else chr(v)
    return out


def operand(code, q):
    t = code[q]
    if t == 0x00:
        return (t, code[q + 1]), q + 2
    if t == 0x04:
        return (t, struct.unpack_from("<i", code, q + 1)[0]), q + 5
    if t in (0x01, 0x02, 0x03, 0x05, 0x81):
        return (t, struct.unpack_from("<H", code, q + 1)[0]), q + 3
    if t == 0x80:
        n = code[q + 1]
        return (t, text(code[q + 2:q + 2 + n])), q + 2 + n
    raise ValueError(f"unknown operand type {t:02X} at {q + BASE:04X}")


def instruction(code, p):
    op = code[p]
    if op not in OPS:
        raise ValueError(f"unknown opcode {op:02X} at {p + BASE:04X}")
    name, count, extra = OPS[op]
    q, args = p + 1, []
    for _ in range(count):
        a, q = operand(code, q)
        args.append(a)
    if extra >= 0:
        for _ in range(args[extra][1]):
            a, q = operand(code, q)
            args.append(a)
    return name, args, q


def code_of(block):
    return block[2:] if struct.unpack_from("<H", block, 0)[0] == 5000 else block


def follow(code):
    found, errors, work = {}, [], []
    p = 0
    for _ in ENTRY_NAMES:
        name, args, q = instruction(code, p)
        found[p] = (name, args, q)
        if name == "GOTO":
            work.append(args[0][1] - BASE)
        p = q
    while work:
        p = work.pop()
        while 0 <= p < len(code) and p not in found:
            try:
                name, args, q = instruction(code, p)
            except ValueError as e:
                errors.append(str(e))
                break
            found[p] = (name, args, q)
            if name in ("GOTO", "GOSUB"):
                work.append(args[0][1] - BASE)
            elif name in ("ON_GOTO", "ON_GOSUB"):
                work.extend(a[1] - BASE for a in args[2:])
            if name.startswith("IF_"):
                try:
                    work.append(instruction(code, q)[2])
                except ValueError as e:
                    errors.append(str(e))
            if name in STOPS:
                break
            p = q
    return found, errors


def show(a):
    t, v = a
    if t in (0x00, 0x04):
        return str(v)
    if t == 0x80:
        return f'"{v}"'
    return f"[{v:04X}]"


def main(argv):
    if len(argv) < 3 or argv[1] not in ("list", "dis"):
        print(__doc__)
        return 1
    blocks = read_dax(argv[2])
    if argv[1] == "list":
        for bid, block in blocks.items():
            code = code_of(block)
            found, errors = follow(code)
            covered = sum(q - p for p, (_, _, q) in found.items())
            loads = [f"{n} {','.join(show(a) for a in args)}" for p, (n, args, _) in sorted(found.items())
                     if n in ("LOAD_AREA_MAP", "LOAD_AREA_DECO")]
            print(f"block {bid:3}  {covered}/{len(code)} bytes  {len(errors)} errors  " + "; ".join(loads))
        return 0
    code = code_of(blocks[int(argv[3])])
    found, errors = follow(code)
    entries = {found[i * 4][1][0][1] - BASE: n for i, n in enumerate(ENTRY_NAMES) if i * 4 in found}
    for p in sorted(found):
        if p in entries:
            print(f"; --- {entries[p]} ---")
        name, args, _ = found[p]
        print(f"{p + BASE:04X}  {name:18} {', '.join(show(a) for a in args)}")
    for e in errors:
        print("; error:", e)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

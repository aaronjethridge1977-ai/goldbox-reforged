"""probe.py (Combat Chat 11, lab only): a look inside the original's to-hit routine (GAME.OVR 0x2BBA1)
for one attack, without a debugger. Called by trace.py at its holds when HOLDPROBE=1 (HOLD=<d20 draw>,<next draw>):

  first hold (the game waits in the dice stub before the d20): two far jumps are written over the routine's
  code in guest RAM (found by its bytes), each to a small stub in the interrupt table's user vectors
  (0000:03C0, checked zero first) that copies values to 0000:04F0 and runs the overwritten instructions:
    at 0x2BBE2 (after category 0xA on the attacker): DS:0x6822 -> 04F0
    at 0x2BC34 (the hit test): DS:0x6822 (signed) -> 04F2, BX (the AC passed) -> 04F4, CX (side bonus) -> 04F6,
    DX (attacker 0x110) -> 04F8, a pass count -> 04FA
  second hold: prints them and puts the code back.
"""
import struct

OVR_FILE = "game/GAME.OVR"
A1, A2 = 0x2BBE2, 0x2BC34       # patch points (file offsets)
STUB, DATA = 0x3C0, 0x4F0
_state = {}


def _find(mem, base, sig):
    mem.seek(base)
    ram = mem.read(0xA0000)
    hits = []
    i = ram.find(sig)
    while i >= 0:
        hits.append(i); i = ram.find(sig, i + 1)
    return hits


def step(r, base):
    import seed as sd
    p = sd.pid()
    mem = open(f"/proc/{p}/mem", "r+b", 0)
    ovr = open(OVR_FILE, "rb").read()
    if not _state:
        sig = ovr[0x2BBBF:0x2BC4D]
        hits = _find(mem, base, sig)
        print("PROBE routine copies in RAM at %s" % [hex(h) for h in hits], flush=True)
        if len(hits) != 1:
            print("PROBE not unique: no patch", flush=True); _state["off"] = True; return
        lin = hits[0] - 0x2BBBF           # linear address of file offset 0 of this run of bytes
        mem.seek(base + STUB); z = mem.read(0x40); mem.seek(base + DATA); zd = mem.read(16)
        if any(z) or any(zd):
            print("PROBE scratch not free: %s %s" % (z.hex(), zd.hex()), flush=True); _state["off"] = True; return
        l1, l2 = lin + A1, lin + A2
        seg = 0x3C                        # stub segment: CS:0 = linear 0x3C0; data at CS:0x130
        unit = lin + 0x2AEEA              # the unit's start (ovr.units()): its CS, IP = offset in the unit
        if unit & 0xF:
            print("PROBE unit not on a paragraph (%x): no patch" % unit, flush=True); _state["off"] = True; return
        def far(l):                       # the routine's own CS:IP for linear l (near calls stay right)
            return struct.pack("<HH", l - unit, unit >> 4)
        s1 = (bytes.fromhex("a02268") + bytes.fromhex("2ea23001")          # mov al,[6822]; mov cs:[130],al
              + ovr[A1:A1 + 6] + b"\xea" + far(l1 + 6))                       # mov al,10; push ax; push [bp+a]; jmp back
        o2 = len(s1)
        s2 = (bytes.fromhex("a02268 98") + bytes.fromhex("2ea33201")      # mov al,[6822]; cbw; mov cs:[132],ax
              + bytes.fromhex("2e891e3401 2e890e3601 2e89163801")          # bx, cx, dx
              + bytes.fromhex("2eff063a01")                                # inc word cs:[13a]
              + bytes.fromhex("03c2") + b"\xea" + far(l2 + 6))              # add ax,dx; jmp back to 0x2BC3A
        assert ovr[A2:A2 + 6] == bytes.fromhex("a02268 98 03c2"), ovr[A2:A2 + 6].hex()
        assert len(s1) + len(s2) <= 0x40
        mem.seek(base + STUB); mem.write(s1 + s2)
        _state.update(l1=l1, l2=l2, o1=ovr[A1:A1 + 6], o2=ovr[A2:A2 + 6])
        mem.seek(base + l1); mem.write(b"\xea" + struct.pack("<HH", 0, seg) + b"\x90")
        mem.seek(base + l2); mem.write(b"\xea" + struct.pack("<HH", o2, seg) + b"\x90")
        print("PROBE installed at linear %x / %x" % (l1, l2), flush=True)
    elif not _state.get("off"):
        mem.seek(base + DATA); d = mem.read(12)
        a, raw, ac, side, x110, n = d[0], *struct.unpack_from("<hHhHH", d, 2)
        print("PROBE after cat 0xA: 0x6822=%d | hit test: 0x6822=%d AC=%d side=%d 0x110=%d sum=%d passes=%d"
              % (a, raw, ac, side, x110, raw + x110 + side, n), flush=True)
        mem.seek(base + _state["l1"]); mem.write(_state["o1"])
        mem.seek(base + _state["l2"]); mem.write(_state["o2"])
        print("PROBE code restored", flush=True)

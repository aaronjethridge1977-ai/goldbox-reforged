"""Logs every Random(n) call the original makes, with its caller, by patching START.EXE's
Random (0AF8:11C0) in DOSBox's memory (lab only, nothing on disk changes).

The routine's `xor ax,ax / mov bx,sp / mov bx,ss:[bx+4]` (0AF8:11C3, 8 bytes, right after the
call to NextRand) becomes a far jump to a stub in the PSP's unused FCB / command-tail area
(PSP:005C). The stub keeps a call counter (PSP:00BA), bumped after each entry is written, and a
ring of 8 entries (PSP:00BE, 8 bytes each: roll_dice's caller IP and CS (every call comes
through GAME.OVR's roll_dice, 0x2BCCD), n, the new seed's high word), does the overwritten
instructions and jumps back to 0AF8:11CB.

No draw is lost (2026-11-14): while a reader runs (flag PSP:00B8 set), the stub waits before
writing an entry until the reader has taken all but 7 (the reader's count, PSP:00BC), so the
game simply pauses until the poller catches up. With no reader the flag is 0 and the stub
never waits. Before, a ring of 8 read by polling lost 2-13% of the draws (LOST lines) and
could pair one draw's size with another's seed.

trace.py install           patch (once per DOSBox run)
trace.py run <secs> [keys] poll the ring and print every call: count, CS:IP, n, result
"""
import sys, struct, time, seed as sd, tp

STUB_OFF = 0x5C
FLAG = 0xB8       # 1 while a reader runs: the stub waits for it
COUNTER = 0xBA
ACK = 0xBC        # the reader's count: entries up to it have been read
RING = 0xBE


def where():
    p = sd.pid()
    img = sd.find(p)
    mcb = open(f"/proc/{p}/mem", "rb", 0)
    mcb.seek(img - 0x110)
    psp_seg = struct.unpack_from("<H", mcb.read(16), 1)[0]
    return p, img, psp_seg, psp_seg + 0x10


def stub(load_seg):
    rnd_seg = load_seg + 0x0AF8
    w = lambda v: struct.pack("<H", v).hex()
    spin = bytes.fromhex("A1" + w(COUNTER) + "2B06" + w(ACK) + "3D0700")   # ax = count - ack; cmp 7
    spin += bytes([0x73, (-(len(spin) + 2)) & 0xFF])                         # jae spin (ring full)
    code = bytes.fromhex(
        "1E 53 50 56"            # push ds, bx, ax, si
        "8CC8 8ED8"              # mov ax,cs / mov ds,ax
        "803E" + w(FLAG) + "00"  # cmp byte [flag],0
        ) + bytes([0x74, len(spin)]) + spin + bytes.fromhex(   # je past the wait
        "A1" + w(COUNTER) + "40"  # ax = count + 1
        "89C6 83E607 D1E6 D1E6 D1E6 81C6" + w(RING) +   # si = (ax & 7) * 8 + ring
        "895406"                 # [si+6] = dx (new seed, high word)
        "89E3"                   # mov bx,sp
        "368B4714 8904"          # [si]   = roll_dice's caller IP (ss:[sp+12] at entry)
        "368B4716 894402"        # [si+2] = roll_dice's caller CS
        "368B470C 894404"        # [si+4] = n
        "FF06" + w(COUNTER) +    # inc word [count], once the entry is written
        "5E 58 5B 1F"            # pop si, ax, bx, ds
        "33C0 89E3 368B5F04"     # the overwritten: xor ax,ax / mov bx,sp / mov bx,ss:[bx+4]
        "EA CB11") + struct.pack("<H", rnd_seg)   # jmp far 0AF8:11CB
    assert STUB_OFF + len(code) <= FLAG, hex(STUB_OFF + len(code))
    return code


def install():
    p, img, psp_seg, load_seg = where()
    with open(f"/proc/{p}/mem", "r+b", 0) as m:
        m.seek(img + 0xC143)
        cur = m.read(8)
        if cur[0] == 0xEA:
            print("already installed"); return
        assert cur == bytes.fromhex("33c08bdc368b5f04"), cur.hex()
        psp = img - 0x100
        m.seek(psp + STUB_OFF); m.write(stub(load_seg))
        m.seek(psp + FLAG); m.write(bytes(RING + 64 - FLAG))
        m.seek(img + 0xC143)
        m.write(bytes([0xEA]) + struct.pack("<HH", STUB_OFF, psp_seg) + bytes.fromhex("909090"))
    print("installed: PSP %04x, program %04x" % (psp_seg, load_seg))


class Reader:
    """Takes the stub's entries. With the flag set the stub never overwrites an entry the
    reader hasn't acknowledged, so nothing is lost and no entry is read half-written."""
    def __init__(self):
        self.p, img, self.psp_seg, self.load_seg = where()
        self.psp = img - 0x100
        self.m = open(f"/proc/{self.p}/mem", "r+b", 0)
        self.count = self._raw()[0]
        self.seed = None

    def _raw(self):
        self.m.seek(self.psp + COUNTER)
        b = self.m.read(RING + 64 - COUNTER)
        return struct.unpack_from("<H", b, 0)[0], b[RING - COUNTER:]

    def start(self):
        self.m.seek(self.psp + ACK); self.m.write(struct.pack("<H", self.count))
        self.m.seek(self.psp + FLAG); self.m.write(b"\x01")

    def stop(self):
        try:
            self.m.seek(self.psp + FLAG); self.m.write(b"\x00")
        except OSError:
            pass

    def new(self):
        """New calls since the last look: [(count, ip, cs, n, seed_hi)]; None for a lost one
        (only possible with the flag off, or if the seed check fails)."""
        c, ring = self._raw()
        out = []
        while self.count != c:
            self.count = (self.count + 1) & 0xFFFF
            if (c - self.count) & 0xFFFF >= 7:
                out.append(None)          # overwritten before we saw it (no reader flag)
                if self.seed is not None:
                    self.seed = tp.nxt(self.seed)
                continue
            i = (self.count & 7) * 8
            ip, cs, n, hi = struct.unpack_from("<4H", ring, i)
            if self.seed is not None:
                self.seed = tp.nxt(self.seed)
                if self.seed >> 16 != hi:
                    out.append(None); continue
            out.append((self.count, ip, cs, n, hi))
        self.m.seek(self.psp + ACK); self.m.write(struct.pack("<H", self.count))
        return out


if __name__ == "__main__":
    if sys.argv[1] == "install":
        install()
    elif sys.argv[1] == "run":
        import keys
        r = Reader(); secs = float(sys.argv[2]); t0 = time.time()
        import signal, atexit
        atexit.register(r.stop)
        signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
        signal.signal(signal.SIGINT, lambda *a: sys.exit(0))
        r.m.seek(sd.addr(r.p)); r.seed = int.from_bytes(r.m.read(4), "little")
        ovr = open("game/GAME.OVR", "rb").read(); exe = open("re/start.img", "rb").read()
        base = r.psp + 0x100 - r.load_seg * 16      # host address of guest linear 0
        known = {}
        def locate(cs, ip):
            k = (cs, ip)
            if k not in known:
                r.m.seek(base + cs * 16 + ip - 16); code = r.m.read(32)
                import re as _re
                pat = b""
                i = 0
                while i < len(code):
                    if code[i] == 0x9A and i + 4 < len(code):     # far call: its segment is patched at load
                        pat += _re.escape(code[i:i + 3]) + b"..";  i += 5
                    else:
                        pat += _re.escape(code[i:i + 1]); i += 1
                rx = _re.compile(pat, _re.S)
                hits = [("OVR", m_.start() + 16) for m_ in rx.finditer(ovr)][:2]
                if not hits:
                    hits = [("EXE", m_.start() + 16) for m_ in rx.finditer(exe)][:2]
                if not hits:      # other load-time fixups: the code after the call alone
                    tail = _re.compile(_re.escape(code[16:28]), _re.S)
                    hits = [("OVR", m_.start()) for m_ in tail.finditer(ovr)][:2] or \
                        [("EXE", m_.start()) for m_ in tail.finditer(exe)][:2]
                known[k] = ",".join("%s:%05x" % h for h in hits[:2]) or "?"
            return known[k]
        r.start()
        for k in sys.argv[3:]:
            keys.key(k)
        pos_addr = r.psp + 0x100 + (0xC7C) * 16 + 0x5F2B     # DS:5F2B, 4 bytes a combatant: x, y
        last_pos = None
        while time.time() - t0 < secs:
            r.m.seek(pos_addr); pb = r.m.read(4 * 16)
            for e in r.new():
                if e is None:
                    print("LOST"); continue
                c, ip, cs, n, hi = e
                where = locate(cs, ip)
                extra = ""
                if where.startswith("OVR:160db") or where.startswith("OVR:0b95d"):
                    r.m.seek(r.psp + 0x100 + 0xC7C * 16 + 0x6DE4); lst = r.m.read(12)
                    r.m.seek(r.psp + 0x100 + 0xC7C * 16 + 0x6718); near = r.m.read(3 * 12)
                    extra = "  list=%s near=%s" % (list(lst), [tuple(near[3 * i:3 * i + 3]) for i in range(1, near[2] + 1)] if near[2] < 12 else "?")
                print("%5d %04x:%04x %-11s n=%-4d -> %d%s" % (c, cs, ip, where, n, (hi % n) if n else 0, extra), flush=True)
            cells = [(pb[4 * k], pb[4 * k + 1]) for k in range(16)]
            if cells != last_pos:
                if last_pos is not None:
                    moved = ["%d:%d,%d" % (k, x, y) for k, (x, y) in enumerate(cells) if last_pos[k] != (x, y)]
                    print("POS " + " ".join(moved), flush=True)
                last_pos = cells

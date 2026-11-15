"""Key-wait hooks in the running original (memory only; nothing on disk changes).

The original reads every key through one routine in START.EXE, GetKey (seg 0x899:0x59, image 0x89E9): it calls
Turbo Pascal's CRT ReadKey (0xA40:0x30F), which waits in the BIOS until a key comes. Polls go through CRT
KeyPressed (0xA40:0x2FD). Three patches, each a far jump to a stub in the unused interrupt vectors C0-EF
(linear 0x300-0x3BF, all zero in DOSBox):

  GetKey entry (0x899:0x59)      enter count += 1, the caller's far return address
  after ReadKey (0x899:0x65)     leave count += 1, the key
  KeyPressed entry (0xA40:0x2FD) poll count += 1, the poll's caller

So the original **waits for a key exactly when enter != leave**, and the caller says which routine is
asking (a menu, a text box's Enter, a yes/no, the walking screen...): see README.md's table.
"""
import struct

SEG = 0x30                       # linear 0x300
ENTER, LEAVE, CALLER, KEY, POLLS, PCALLER = 0x00, 0x02, 0x04, 0x08, 0x0A, 0x0C
CODE = 0x10

GETKEY = (0x899, 0x59, bytes.fromhex("5589e581ec0201"))       # push bp / mov bp,sp / sub sp,0x102
AFTER = (0x899, 0x65, bytes.fromhex("8846fe807efe13"))        # mov [bp-2],al / cmp byte [bp-2],0x13
KEYPRESSED = (0xA40, 0x2FD, bytes.fromhex("803e018500"))      # cmp byte [0x8501],0


def _jmp(off, seg):
    return b"\xEA" + struct.pack("<HH", off, seg)


def _stubs(load):
    """Returns [(stub offset, code)] and the patches [(linear, bytes)]."""
    out, patches = [], []
    off = CODE
    # 1. GetKey's entry: count, caller (ss:[sp] IP, ss:[sp+2] CS at entry; 3 words pushed here)
    s, o, orig = GETKEY
    c = bytes.fromhex("1E 53 50 B830008ED8 FF06" + "%02x00" % ENTER +
                      "89E3 368B4706 A3" + "%02x00" % CALLER + " 368B4708 A3" + "%02x00" % (CALLER + 2) +
                      "58 5B 1F") + orig + _jmp(o + len(orig), load + s)
    out.append((off, c))
    patches.append(((load + s) * 16 + o, _jmp(off, SEG) + b"\x90" * (len(orig) - 5)))
    off += len(c)
    # 2. after ReadKey: count, key in al
    s, o, orig = AFTER
    c = bytes.fromhex("1E 50 B830008ED8 58 50 A2" + "%02x00" % KEY + " FF06" + "%02x00" % LEAVE +
                      "58 1F") + orig + _jmp(o + len(orig), load + s)
    out.append((off, c))
    patches.append(((load + s) * 16 + o, _jmp(off, SEG) + b"\x90" * (len(orig) - 5)))
    off += len(c)
    # 3. KeyPressed: count, caller
    s, o, orig = KEYPRESSED
    c = bytes.fromhex("1E 53 50 B830008ED8 FF06" + "%02x00" % POLLS +
                      "89E3 368B4706 A3" + "%02x00" % PCALLER + " 368B4708 A3" + "%02x00" % (PCALLER + 2) +
                      "58 5B 1F") + orig + _jmp(o + len(orig), load + s)
    out.append((off, c))
    patches.append(((load + s) * 16 + o, _jmp(off, SEG) + b"\x90" * (len(orig) - 5)))
    off += len(c)
    assert off <= 0xC0, hex(off)
    return out, patches


def installed(mem):
    s, o, orig = GETKEY
    return mem.lin((mem.load_seg + s) * 16 + o, 1) == b"\xEA"


def install(mem):
    if installed(mem):
        return False
    for s, o, orig in (GETKEY, AFTER, KEYPRESSED):
        cur = mem.lin((mem.load_seg + s) * 16 + o, len(orig))
        assert cur == orig, "unexpected code at %x:%x: %s" % (s, o, cur.hex())
    assert mem.lin(0x300, 0xC0) == bytes(0xC0), "vectors C0-EF in use"
    stubs, patches = _stubs(mem.load_seg)
    for off, code in stubs:
        mem.wlin(SEG * 16 + off, code)
    for a, b in patches:
        mem.wlin(a, b)
    return True


class Keys:
    """The hook's counters."""

    def __init__(self, mem):
        self.mem = mem

    def read(self):
        b = self.mem.lin(SEG * 16, 0x10)
        enter, leave, cip, ccs = struct.unpack_from("<4H", b, 0)
        key = b[KEY]
        polls, pip, pcs = struct.unpack_from("<3H", b, POLLS)
        return {"enter": enter, "leave": leave, "waiting": enter != leave, "caller": (ccs, cip),
                "key": key, "polls": polls, "pcaller": (pcs, pip)}


class Locator:
    """Caller (cs, ip) -> 'EXE:<image offset>' or 'OVR:<GAME.OVR file offset>' of the return address.
    Overlay code moves (the overlay buffer), so it is found by its bytes, far calls' segments wildcarded."""

    def __init__(self, mem, game_dir, img_path):
        import os
        self.mem = mem
        self.ovr = open(os.path.join(game_dir, "GAME.OVR"), "rb").read()
        self.exe = open(img_path, "rb").read()
        self.known = {}

    def __call__(self, cs, ip):
        import re
        if (cs, ip) == (0, 0):
            return "-"
        k = (cs, ip)
        if k in self.known:
            return self.known[k]
        rel = (cs - self.mem.load_seg) * 16 + ip
        if 0 <= rel < len(self.exe) and cs - self.mem.load_seg < 0x1000 and \
                self.mem.lin(cs * 16 + ip - 16, 32)[:5] == self.exe[rel - 16:rel - 11]:
            r = "EXE:%05x" % rel
        else:
            code = self.mem.lin(cs * 16 + ip - 16, 32)
            pat, i = b"", 0
            while i < len(code):
                if code[i] == 0x9A and i + 4 < len(code):
                    pat += re.escape(code[i:i + 3]) + b".."
                    i += 5
                else:
                    pat += re.escape(code[i:i + 1])
                    i += 1
            hits = [m.start() + 16 for m in re.compile(pat, re.S).finditer(self.ovr)]
            r = ("OVR:%05x" % hits[0]) if len(hits) == 1 else ("OVR?%s" % ",".join("%05x" % h for h in hits[:3]))
        self.known[k] = r
        return r

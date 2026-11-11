#!/usr/bin/env python3
"""Read Pool of Radiance's program code: GAME.OVR routines with far calls resolved.

    ovr.py dis <file offset hex> [bytes]   disassemble (ndisasm), stop at the first retf
    ovr.py handler <effect type hex>        the effect type's handler (DS:0x682C table)
    ovr.py stub <seg hex> <entry hex>       where a far call seg:entry lands in GAME.OVR
    ovr.py cats                             the effect dispatcher's lists (0x2B1E4)

Far calls `call seg:off` go through a stub segment of the unpacked START.EXE (image offset
seg x 16: CD 3F, 00 00, dword file offset of the unit in GAME.OVR, ...; entries from +0x20,
5 bytes each: CD 3F, u16 routine offset, 0). Expects the lab's game copy in ./game.
Format notes: research/pool-of-radiance-formats.md (ai-business-ideas).
"""
import os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
GAME = os.environ.get("POOLRAD", os.path.join(os.getcwd(), "game"))
OVR = open(os.path.join(GAME, "GAME.OVR"), "rb").read()
_img = None


def image():
    global _img
    if _img is None:
        import unexepack
        _img = unexepack.unpack(open(os.path.join(GAME, "START.EXE"), "rb").read())
    return _img


def stub(seg, off):
    img = image()
    s = seg * 16
    if img[s:s + 2] != b"\xcd\x3f":
        return None
    unit = struct.unpack_from("<I", img, s + 4)[0]
    if img[s + off:s + off + 2] != b"\xcd\x3f":
        return None
    return unit + struct.unpack_from("<H", img, s + off + 2)[0]


def handler_table():
    p, m = 0x11E00, {}
    while OVR[p] == 0xB8 and OVR[p + 3] == 0xBA:
        ax = struct.unpack_from("<H", OVR, p + 1)[0]
        seg = struct.unpack_from("<H", OVR, p + 4)[0]
        addr = struct.unpack_from("<H", OVR, p + 7)[0]
        m[(addr - 0x6828) // 4] = stub(seg, ax)
        p += 13
    return m


_units = None


def units():
    """(file offset, size) of every overlaid unit, from the stub segments."""
    global _units
    if _units is None:
        img, _units = image(), []
        for s in range(0, len(img) - 16, 16):
            if img[s:s + 4] == b"\xcd\x3f\x00\x00":
                fo, size = struct.unpack_from("<IH", img, s + 4)
                if 0 < fo < len(OVR):
                    _units.append((fo, size))
        _units.sort()
    return _units


def unit_of(addr):
    for fo, size in units():
        if fo <= addr < fo + size:
            return fo
    return None


def pstring(addr):
    n = OVR[addr]
    return OVR[addr + 1:addr + 1 + n].decode("ascii", "replace")


def dis(start, size=600, stop=True):
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(OVR[start:start + size])
    out = subprocess.run(["ndisasm", "-b16", "-o", str(start), f.name], capture_output=True, text=True).stdout
    os.unlink(f.name)
    lines = []
    for l in out.splitlines():
        m = re.search(r"call (0x[0-9a-f]+):(0x[0-9a-f]+)", l)
        if m:
            t = stub(int(m.group(1), 16), int(m.group(2), 16))
            if t is not None:
                l += f"    ; -> {t:#x}"
        m = re.search(r"mov di,(0x[0-9a-f]+)$", l)
        base = unit_of(start)
        if m and base is not None:
            t = base + int(m.group(1), 16)
            if t < len(OVR) and 0 < OVR[t] < 60 and all(32 <= c < 127 for c in OVR[t + 1:t + 1 + OVR[t]]):
                l += f'    ; "{pstring(t)}"'
        lines.append(l)
        if stop and "retf" in l:
            break
    return "\n".join(lines)


def cats():
    out = dis(0x2B1E4, 2100, stop=False)
    res, cur, last = {}, None, None
    for l in out.splitlines():
        ins = l.split(None, 2)[-1].strip()
        if ins.startswith("cmp al,"):
            cur = int(ins.split(",")[1], 16)
            res.setdefault(cur, [])
        elif ins.startswith("mov al,"):
            last = int(ins.split(",")[1], 16)
        elif ins.startswith("call 0xb04a") and cur is not None:
            res[cur].append(last)
        elif "retf" in ins:
            break
    return res


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "dis":
        print(dis(int(a[1], 16), int(a[2]) if len(a) > 2 else 600))
    elif a[0] == "handler":
        t = handler_table()[int(a[1], 16)]
        print(f"handler {t:#x}")
        print(dis(t))
    elif a[0] == "stub":
        print(hex(stub(int(a[1], 16), int(a[2], 16))))
    elif a[0] == "cats":
        for k, v in cats().items():
            print(k, " ".join(f"{x:#x}" for x in v))

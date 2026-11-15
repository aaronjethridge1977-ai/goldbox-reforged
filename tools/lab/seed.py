"""Read or set the original's random seed (Turbo Pascal RandSeed, DS:0x4428) inside the
running DOSBox process, by finding START.EXE's NextRand code in the emulated memory.
seed.py            prints the seed
seed.py set <hex>  writes it"""
import sys, re, struct, subprocess
CODE = bytes.fromhex("a128448b1e2a448bc82ef7264512")   # NextRand: mov ax,[4428] mov bx,[442A] ...
CODE_OFF = 0xC18F          # its place in the unpacked START.EXE image
DS_SEG = 0xC7C             # the program's data segment, image-relative (System init, 0AF8:0000)
SEED = 0x4428
def pid():
    # The DOSBox process itself, not a shell that started it (pl.py's `sh -c ... dosbox -conf`
    # comes first in pgrep's list; Combat Chat 3).
    found = subprocess.check_output(["pgrep", "-f", "dosbox.*-conf"]).split()
    for p in found:
        try:
            if open("/proc/%s/comm" % p.decode()).read().strip() == "dosbox":
                return int(p)
        except OSError:
            pass
    return int(found[0])
def find(p):
    maps = open(f"/proc/{p}/maps").read().splitlines()
    mem = open(f"/proc/{p}/mem", "rb", 0)
    for l in maps:
        a, perm = l.split()[0], l.split()[1]
        if "rw" not in perm: continue
        lo, hi = (int(x, 16) for x in a.split("-"))
        if hi - lo < 0x100000 or hi - lo > 0x40000000: continue
        try:
            mem.seek(lo); buf = mem.read(hi - lo)
        except OSError:
            continue
        i = buf.find(CODE)
        if i >= 0:
            return lo + i - CODE_OFF
    raise SystemExit("START.EXE's code not found in DOSBox's memory")
def addr(p):
    return find(p) + DS_SEG * 16 + SEED
if __name__ == "__main__":
    p = pid(); a = addr(p)
    if len(sys.argv) > 2 and sys.argv[1] == "set":
        with open(f"/proc/{p}/mem", "r+b", 0) as m:
            m.seek(a); m.write(struct.pack("<I", int(sys.argv[2], 16)))
    with open(f"/proc/{p}/mem", "rb", 0) as m:
        m.seek(a); print("%08x" % struct.unpack("<I", m.read(4))[0])

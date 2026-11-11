"""Unpack an EXEPACK program (same algorithm as scripts/formats/exepack.gd): unexepack.py IN OUT"""
import struct, sys
def unpack(exe):
    u16 = lambda o: struct.unpack_from("<H", exe, o)[0]
    start = u16(8) * 16; cs = u16(0x16); eh = start + cs * 16
    dest_len = u16(eh + 12)
    skip = u16(eh + 14) if exe[eh+16:eh+18] == b"RB" else 1
    out_len = dest_len * 16
    buf = bytearray(exe[start:eh]); buf += bytes(max(0, out_len - len(buf)))
    s = (eh - start) - (skip - 1) * 16 - 1
    while s > 0 and buf[s] == 0xFF: s -= 1
    o = out_len - 1
    while s >= 2:
        op = buf[s]; count = (buf[s-1] << 8) | buf[s-2]; s -= 3
        if op & 0xFE == 0xB0:
            f = buf[s]; s -= 1
            for i in range(count): buf[o] = f; o -= 1
        elif op & 0xFE == 0xB2:
            for i in range(count): buf[o] = buf[s]; o -= 1; s -= 1
        else: raise SystemExit("bad op")
        if op & 1: break
    return bytes(buf[:out_len])
if __name__ == "__main__":
    open(sys.argv[2], "wb").write(unpack(open(sys.argv[1], "rb").read()))

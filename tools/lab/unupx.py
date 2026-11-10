"""Unpack the compressed image of a UPX-packed Windows program (method 8, NRV2E).

Usage: python3 unupx.py packed.exe out.bin
Writes the decompressed section data (the program's code, data and resources as loaded),
enough to find embedded pictures and tables. It does not rebuild a runnable program.
The NRV2E format is public (UCL / UPX documentation).
"""
import struct
import sys


def nrv2e_d32(src, start, ulen):
    out = bytearray()
    pos = start
    bits = 0
    count = 0
    last_offset = 1

    def bit():
        nonlocal bits, count, pos
        if count == 0:
            bits = struct.unpack_from("<I", src, pos)[0]
            pos += 4
            count = 32
        count -= 1
        return (bits >> count) & 1

    while True:
        while bit():
            out.append(src[pos])
            pos += 1
        offset = 1
        while True:
            offset = offset * 2 + bit()
            if bit():
                break
            offset = (offset - 1) * 2 + bit()
        if offset == 2:
            offset = last_offset
            length = bit()
        else:
            offset = ((offset - 3) * 256 + src[pos]) & 0xFFFFFFFF
            pos += 1
            if offset == 0xFFFFFFFF:
                break
            length = (offset ^ 0xFFFFFFFF) & 1
            offset = (offset >> 1) + 1
            last_offset = offset
        if length:
            length = 1 + bit()
        elif bit():
            length = 3 + bit()
        else:
            length += 1
            while True:
                length = length * 2 + bit()
                if bit():
                    break
            length += 3
        if offset > 0x500:
            length += 1
        p = len(out) - offset
        for i in range(length + 1):
            out.append(out[p + i])
        if len(out) >= ulen:
            break
    return bytes(out)


if __name__ == "__main__":
    data = open(sys.argv[1], "rb").read()
    i = data.find(b"UPX!")
    _ver, _fmt, method, _lvl, _ua, _ca, ulen, clen = struct.unpack_from("<BBBBIIII", data, i + 4)
    if method != 8:
        sys.exit("unsupported UPX method %d" % method)
    # The compressed stream starts the UPX1 section (file offset 0x400 for these programs).
    out = nrv2e_d32(data, 0x400, ulen)
    open(sys.argv[2], "wb").write(out)
    print("unpacked %d bytes" % len(out))

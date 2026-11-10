"""Reads DAX containers (header of 9-byte entries, RLE-packed blocks). Used by route.py."""
import struct, sys
def read_dax(path):
    d = open(path,'rb').read()
    hlen = struct.unpack_from('<H', d, 0)[0]
    base = 2 + hlen
    out = {}
    for i in range(0, hlen, 9):
        rid, off, raw, comp = struct.unpack_from('<BiHH', d, 2+i)
        out[rid] = rle(d[base+off: base+off+comp], raw)
    return out
def rle(src, raw):
    o = bytearray(); i = 0
    while i < len(src) and len(o) < raw:
        n = src[i] if src[i] < 128 else src[i]-256
        i += 1
        if n >= 0:
            o += src[i:i+n+1]; i += n+1
        else:
            o += bytes([src[i]]) * (-n); i += 1
    return bytes(o)
EGA = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
       (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]

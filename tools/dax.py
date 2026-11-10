#!/usr/bin/env python3
"""Developer tool: inspect Gold Box .DAX files outside Godot.

Usage:
    python3 tools/dax.py list  <file.DAX>            # blocks, sizes, picture headers
    python3 tools/dax.py png   <file.DAX> <id> <out>  # write an EGA picture block as PNG (needs Pillow)
    python3 tools/dax.py check <POOLRAD folder>       # verify every block decompresses to its stated size

Format notes live in the ai-business-ideas repo: research/pool-of-radiance-formats.md.
"""
import struct
import sys
from pathlib import Path

EGA = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), (170, 0, 0), (170, 0, 170), (170, 85, 0),
       (170, 170, 170), (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255), (255, 85, 85),
       (255, 85, 255), (255, 255, 85), (255, 255, 255)]


def rle(src: bytes) -> bytes:
    """n >= 0: copy next n+1 bytes; n < 0: repeat next byte -n times."""
    out = bytearray()
    i = 0
    while i < len(src):
        n = src[i] - 256 if src[i] >= 128 else src[i]
        i += 1
        if n >= 0:
            out += src[i:i + n + 1]
            i += n + 1
        else:
            out += bytes([src[i]]) * -n
            i += 1
    return bytes(out)


def directory(path):
    data = Path(path).read_bytes()
    header_len = struct.unpack_from('<H', data, 0)[0]
    base = 2 + header_len
    for i in range(0, header_len, 9):
        block_id, offset, raw, comp = struct.unpack_from('<BiHH', data, 2 + i)
        yield block_id, raw, comp, data[base + offset: base + offset + comp]


def read_dax(path):
    return {block_id: rle(packed) for block_id, _raw, _comp, packed in directory(path)}


def picture_header(block: bytes):
    if len(block) < 17:
        return None
    h, w8, x, y = struct.unpack_from('<HHHH', block, 0)
    n = block[8]
    if h and w8 and n and len(block) == 17 + n * h * w8 * 4:
        return {'width': w8 * 8, 'height': h, 'x': x, 'y': y, 'frames': n}
    return None


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    cmd = argv[1]
    if cmd == 'list':
        for block_id, raw, comp, packed in directory(argv[2]):
            pic = picture_header(rle(packed))
            print(f'id {block_id:3}  raw {raw:6}  packed {comp:6}  {pic or ""}')
    elif cmd == 'png':
        from PIL import Image
        block = read_dax(argv[2])[int(argv[3])]
        pic = picture_header(block)
        if not pic:
            print('not an EGA picture block')
            return 1
        w, h, n = pic['width'], pic['height'], pic['frames']
        img = Image.new('RGB', (w * n, h))
        frame = w * h // 2
        for f in range(n):
            px = block[17 + f * frame: 17 + (f + 1) * frame]
            part = Image.new('RGB', (w, h))
            part.putdata([EGA[(b >> s) & 15] for b in px for s in (4, 0)])
            img.paste(part, (f * w, 0))
        img.save(argv[4])
    elif cmd == 'check':
        bad = total = 0
        for f in sorted(Path(argv[2]).glob('*.DAX')):
            for _id, raw, _comp, packed in directory(f):
                total += 1
                bad += len(rle(packed)) != raw
        print(f'{total} blocks, {bad} size mismatches')
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

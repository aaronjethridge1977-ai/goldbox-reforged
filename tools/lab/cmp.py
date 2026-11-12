import sys
from PIL import Image, ImageChops
# cmp.py orig.png ours.png: diff bbox and the differing 8x8 cells (row,col)
a=Image.open(sys.argv[1]).convert('RGB'); b=Image.open(sys.argv[2]).convert('RGB')
d=ImageChops.difference(a,b); bb=d.getbbox(); print('bbox',bb)
if bb:
    cells=set()
    for y in range(200):
        for x in range(320):
            if d.getpixel((x,y))!=(0,0,0): cells.add((y//8,x//8))
    rows={}
    for r,c in sorted(cells): rows.setdefault(r,[]).append(c)
    for r in sorted(rows): print(' row',r,'cols',rows[r])

"""Routes on a decoded area map (walls and doors from GEO2.DAX block 20, the Slums, for now):
BFS from a square to an event's squares, avoiding other events, and the arrow keys to walk it.
Needs dax.py from the ideas research tools (DAX reader) on the path."""
import dax, os, sys
from collections import deque
P=os.environ.get("POOLRAD", os.path.expanduser("~/mnt/goldbox-reforged/Pool of Radiance/POOLRAD/"))
def load(f,b):
    d=dax.read_dax(P+'GEO%d.DAX'%f)[b]
    return d[2:258], d[258:514], d[514:770], d[770:1026]
NE,SW,INFO,DOORS=load(2,20)
DX=[0,1,0,-1]; DY=[-1,0,1,0]
def wall(x,y,s): i=y*16+x; return [NE[i]>>4, NE[i]&15, SW[i]>>4, SW[i]&15][s]
def door(x,y,s): return (DOORS[y*16+x]>>(2*s))&3
def event(x,y): return INFO[y*16+x]&127
def passable(x,y,s):
    nx,ny=x+DX[s],y+DY[s]
    if not(0<=nx<16 and 0<=ny<16): return False
    if wall(x,y,s)==0: return True
    return door(x,y,s)!=0
def squares(ev): return [(x,y) for y in range(16) for x in range(16) if event(x,y)==ev]
def route(start, goal_set, avoid_events):
    q=deque([start]); prev={start:None}
    while q:
        c=q.popleft()
        if c in goal_set: 
            path=[]
            while c: path.append(c); c=prev[c]
            return path[::-1]
        for s in range(4):
            if passable(c[0],c[1],s):
                n=(c[0]+DX[s],c[1]+DY[s])
                if n in prev: continue
                if n not in goal_set and event(*n) in avoid_events: continue
                prev[n]=c; q.append(n)
    return None
def keys(path, facing):
    out=[]
    for a,b in zip(path,path[1:]):
        s=[i for i in range(4) if (a[0]+DX[i],a[1]+DY[i])==b][0]
        diff=(s-facing)%4
        out+={0:[],1:['right'],2:['right','right'],3:['left']}[diff]
        out.append('up'); facing=s
    return out, facing
if __name__=='__main__':
    for ev in [3,7,11,15,1]:
        sq=set(squares(ev))
        avoid=set(range(1,22))-{ev}
        p=route((15,4), sq, avoid)
        print('event',ev,'squares',sorted(sq)[:6],'route',p, keys(p,3)[0] if p else None)

import sys, route as R
def exits(geo, block):
    R.NE,R.SW,R.INFO,R.DOORS=R.load(geo,block)
    out=[]
    for y in range(16):
        for x in range(16):
            for s in range(4):
                nx,ny=x+R.DX[s],y+R.DY[s]
                if 0<=nx<16 and 0<=ny<16: continue
                if R.wall(x,y,s)==0 or R.door(x,y,s)!=0: out.append((x,y,"NESW"[s]))
    return out
if __name__=='__main__':
    print(exits(int(sys.argv[1]),int(sys.argv[2])))

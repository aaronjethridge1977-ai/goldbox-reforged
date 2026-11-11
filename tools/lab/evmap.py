"""Print an area's event numbers on its 16x16 grid: python3 evmap.py <geo> <block>"""
import sys, route as R
R.NE, R.SW, R.INFO, R.DOORS = R.load(int(sys.argv[1]), int(sys.argv[2]))
print("    " + "".join("%3d" % x for x in range(16)))
for y in range(16):
    print("%3d " % y + "".join("%3s" % (R.event(x, y) or ".") for x in range(16)))

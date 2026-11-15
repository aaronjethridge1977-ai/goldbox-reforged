"""Lab: find state bytes. memdiff.py snap <name> | memdiff.py find <expr over snapshots a,b,...>
A snapshot is DS (64 KB) plus the ECL buffer; e.g.  find "a==14 and b==13 and c==13" ."""
import sys, pickle, os
import orig

D = os.path.join(orig.RUN, "snaps")
os.makedirs(D, exist_ok=True)
m = orig.Mem()
if sys.argv[1] == "snap":
    ds = m.ds(0, 0x10000)
    pickle.dump(ds, open(os.path.join(D, sys.argv[2]), "wb"))
    print("snap", sys.argv[2])
elif sys.argv[1] == "find":
    names = sys.argv[3].split(",")
    snaps = [pickle.load(open(os.path.join(D, n), "rb")) for n in names]
    expr = compile(sys.argv[2], "expr", "eval")
    hits = []
    for i in range(0x10000):
        env = {n: s[i] for n, s in zip(names, snaps)}
        if eval(expr, {}, env):
            hits.append(i)
    print(len(hits), " ".join("%04x:%s" % (i, "/".join(str(s[i]) for s in snaps)) for i in hits[:60]))

"""./run.sh --py dump.py <steps>: key names, wait=s, solve (the code wheel, with the lab's wheel_solver.py), grab=file.png, and
'dump', which prints every text row of the original's screen (read with its own font)."""
import sys, time, lab, keys
for a in sys.argv[1:]:
    if a.startswith("wait="): time.sleep(float(a[5:]))
    elif a == "solve": keys.solve_wheel(print)
    elif a == "dump":
        im = lab.screen(); print("-----")
        for r in range(25):
            t = lab.text(im, r)
            if t.strip("?\\ "): print("%2d|%s" % (r, t))
    elif a.startswith("grab="): lab.screen().save(a[5:])
    else: keys.key(a)

"""Lab exploration: boot fresh (hook installed before the title), then press keys and show each wait.
  explore.py [--attach] <keys...>   ('solve' answers the code wheel; 'wait=s'; 'show')"""
import sys, time
import orig, hooks

attach = "--attach" in sys.argv
args = [a for a in sys.argv[1:] if a != "--attach"]
if not attach:
    orig.start()
    t = time.time()
    while True:
        try:
            m = orig.Mem()
            break
        except (RuntimeError, SystemExit):
            time.sleep(0.05)
    hooks.install(m)
    print("hook at %.2fs" % (time.time() - t))
import game  # noqa: E402

g = game.Game(log=print)


def show(tag):
    s = g.state()
    print("==", tag, s["wait"], s["site"], list(g.mem.ds(0x6AAD, 3)), "|", s["bottom"])
    for r, tx in s["rows"].items():
        if tx.strip("?\\ ") and r < 24:
            print("   %2d %s" % (r, tx))


show("start")
for k in args:
    if k == "solve":
        import keys
        g.until_waiting()
        print("wheel", keys.solve_wheel(print))
        time.sleep(0.5)
        continue
    if k.startswith("wait="):
        time.sleep(float(k[5:]))
        continue
    if k == "show":
        show("show")
        continue
    g.press(k)
    time.sleep(0.3)
    g.until_waiting()
    show(k)

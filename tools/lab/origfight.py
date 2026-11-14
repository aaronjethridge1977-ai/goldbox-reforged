"""Plays the open fight in the original on QUICK for everyone, logging each screen change:
the right panel's text and row 24, and how many random numbers were drawn since the last line
(the seed's steps, tp.steps). origfight.py <seconds> [out.txt]"""
import sys, time, hashlib, lab, keys, tp, seed as sd
secs = float(sys.argv[1]); out = open(sys.argv[2] if len(sys.argv) > 2 else "/dev/stdout", "w")
p = sd.pid(); a = sd.addr(p); mem = open(f"/proc/{p}/mem", "rb", 0)
def rs():
    mem.seek(a); return int.from_bytes(mem.read(4), "little")
start = rs(); last_s = start; total = 0; last_txt = None; t0 = time.time(); lastq = 0
out.write("start seed %08x\n" % start)
keys.key("enter")
seen_fight = False
while time.time() - t0 < secs:
    im = lab.screen(); s = rs()
    rows = [lab.text(im, r) for r in range(25)]
    panel = " / ".join(r[23:39].strip("? ").strip() for r in rows[1:24] if r[23:39].strip("? ").strip())
    txt = panel + " | " + rows[24].strip()
    if txt != last_txt or s != last_s:
        n = tp.steps(last_s, s, 200000); total += n or 0
        out.write("%6.2f +%-3s =%-4d %s\n" % (time.time() - t0, n, total, txt)); out.flush()
        last_txt = txt; last_s = s
    if "QUICK" in rows[24] and time.time() - lastq > 1.5:
        keys.key("q"); lastq = time.time()
    if "QUICK" in rows[24] or "MOVE/ATTACK" in rows[24]:
        seen_fight = True
    if seen_fight and ("PRESS <ENTER>" in rows[24] or "CONTINUE" in rows[24]):
        break

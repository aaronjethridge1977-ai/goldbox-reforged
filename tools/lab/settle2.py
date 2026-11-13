"""Answer the original's prompts until the AREA menu is back (or the time runs out):
python3 settle.py <seconds>. Quick-fights, says no to CONTINUE BATTLE, leaves treasure."""
import os, sys, time
os.environ.setdefault("DISPLAY", ":99")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab, keys
end = time.time() + float(sys.argv[1] if len(sys.argv) > 1 else 600)
last = None
seen = set()
while time.time() < end:
    s = lab.status(); b = s["bottom"]
    if b != last:
        print(time.strftime("%H:%M:%S"), "|", b, "|", lab.text(s["im"], 17).strip("? "), flush=True)
        last = b
    rows = [lab.text(s["im"], r).strip("? ") for r in range(25)]
    t = " / ".join(r for r in rows if r.strip())
    if ("EXPERIENCE" in t or "RECEIVE" in t) and t not in seen:
        seen.add(t)
        print("   SCREEN:", t, flush=True)
    if b.startswith("AREA"):
        print("settled"); break
    if b.startswith("COMBAT WAIT FLEE"):
        keys.key("f")
    elif b.startswith("VIEW TAKE POOL"):
        keys.key("e")
    elif b == "YES NO" and "TREASURE" in lab.text(s["im"], 19):
        keys.key("n")
    elif b.startswith("CONTINUE BATTLE"):
        keys.key("n")
    elif "PRESS" in b:
        keys.key("enter")
    elif "QUICK" in b:
        keys.key("q")
    time.sleep(2)

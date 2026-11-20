"""Player 33: the Stage 1 match (the Lead's Methods 8 item, Jeremy 2026-11-20 07:03): every recording of the
original's full run replayed in ours, one scoreboard.

  match.py manifest            hash every recording (match/recordings.txt) into match/manifest.txt: a recording is
                               frozen once listed; a changed file is an error, a re-recording a new line (new run id)
  match.py verify              check the lab's files against the manifest (exit 1 on any change)
  match.py run [run ...]       replay each recording in ours (segment.py <run> begin <checkpoint> --start=<save>
                               --tplog), line the draws up (the lab's cmpdraws.py) and keep both under LAB/match/;
                               then the scoreboard. One Godot at a time (the lab's rule); about 5 min a recording.
  match.py score [--md FILE]   the scoreboard from the kept outputs (no replay): X of N identical, by segment, and for
                               the rest the first differing roll and the state there, each labelled
  match.py baseline            write match/baseline.txt: the recordings identical now
  match.py gate [--run]        exit 1 if a recording identical in the baseline parts now (the release gate; --run
                               replays the baseline's recordings on this checkout first: the build script's form)

A recording is identical when its draws agree up to its checkpoint (cmpdraws "draws: identical", or the first
difference at N with ours' count N - 1: the trace goes on past the checkpoint) and statediff, ours' save against the
original's at the checkpoint, has no difference left after match/known.txt's `ignore` lines (the wall-set slot cells).
Every other difference is labelled from match/known.txt (`label <run> <game|replay tool|known shortcut> <note>`);
unlabelled ones are **game** (only game counts against us).
"""
import hashlib, os, re, subprocess, sys
import orig

HERE = os.path.dirname(os.path.abspath(__file__))
M = os.path.join(HERE, "match")
LAB = orig.LAB
SAVES = os.path.join(LAB, ".lab", "player", "saves")
LOGS = os.path.join(LAB, "logs")
OUT = os.path.join(LAB, "match")


def recordings():
    out = []
    for l in open(os.path.join(M, "recordings.txt")):
        l = l.split("#", 1)[0].split()
        if len(l) >= 4:
            out.append({"seg": int(l[0]), "run": l[1], "start": l[2], "cp": l[3], "flags": l[4:]})
    return out


def known():
    ign, lab = [], {}
    p = os.path.join(M, "known.txt")
    for l in open(p) if os.path.exists(p) else []:
        l = l.rstrip("\n")
        if l.startswith("ignore "):
            ign.append(re.compile(l[7:].strip()))
        elif l.startswith("label "):
            _, run, rest = l.split(" ", 2)
            for k in ("known shortcut", "replay tool", "game"):
                if rest.startswith(k):
                    lab[run] = (k, rest[len(k):].strip(" :-"))
    return ign, lab


def sha(path):
    if os.path.isdir(path):
        h = hashlib.sha256()
        for f in sorted(os.listdir(path)):
            h.update(f.encode() + b"=" + sha(os.path.join(path, f)).encode() + b";")
        return h.hexdigest()[:16]
    if not os.path.exists(path):
        return "-"
    return hashlib.sha256(open(path, "rb").read()).hexdigest()[:16]


def files(r):
    """The recording: the original's log and trace, the start save, the checkpoint's save."""
    cpdir = os.path.join(SAVES, r["run"], r["cp"])
    return [("log", os.path.join(LOGS, r["run"] + ".log")), ("trace", os.path.join(LOGS, r["run"] + ".trace.txt")),
            ("start", os.path.join(SAVES, "p2start", r["start"])), ("checkpoint", cpdir)]


def manifest():
    old = {}
    p = os.path.join(M, "manifest.txt")
    if os.path.exists(p):
        for l in open(p):
            if not l.startswith("#") and l.strip():
                old[l.split()[0]] = l.rstrip("\n")
    lines = ["# run | segment | start -> checkpoint | sha256[:16] of log, trace, start save, checkpoint save"
             " (match.py manifest; a recording already here is kept as it was: frozen)"]
    for r in recordings():
        if r["run"] in old:
            lines.append(old[r["run"]])
            continue
        hs = " ".join("%s=%s" % (k, sha(f)) for k, f in files(r))
        lines.append("%s | %d | %s -> %s | %s" % (r["run"], r["seg"], r["start"], r["cp"], hs))
    open(p, "w").write("\n".join(lines) + "\n")
    print("%d recordings in %s" % (len(lines) - 1, p))


def verify(quiet=False):
    bad = []
    man = {}
    for l in open(os.path.join(M, "manifest.txt")):
        if not l.startswith("#") and l.strip():
            man[l.split()[0]] = dict(x.split("=") for x in l.rsplit("|", 1)[1].split())
    for r in recordings():
        want = man.get(r["run"])
        if want is None:
            bad.append("%s: not in the manifest (match.py manifest)" % r["run"])
            continue
        for k, f in files(r):
            if sha(f) != want[k]:
                bad.append("%s: %s changed (%s)" % (r["run"], k, f))
    if not quiet:
        print("\n".join(bad) or "manifest: every recording as frozen")
    return bad


def replay(r):
    os.makedirs(OUT, exist_ok=True)
    seg = os.path.join(OUT, r["run"] + ".seg.txt")
    env = dict(os.environ, OP_SEG_TIMEOUT=os.environ.get("OP_SEG_TIMEOUT", "3200"))
    with open(seg, "w") as f:
        subprocess.run([sys.executable, os.path.join(HERE, "segment.py"), r["run"], "begin", r["cp"],
                        "--start=" + r["start"], "--tplog"], stdout=f, stderr=subprocess.STDOUT, cwd=HERE, env=env)
    cmp_ = os.path.join(OUT, r["run"] + ".cmpdraws.txt")
    tr = os.path.join(LOGS, r["run"] + ".trace.txt")
    ours = os.path.join(LOGS, "%s.segment_begin-%s.txt" % (r["run"], r["cp"]))
    with open(cmp_, "w") as f:
        if os.path.exists(tr):
            subprocess.run([sys.executable, os.path.join(LAB, "cmpdraws.py"), tr, ours], stdout=f,
                           stderr=subprocess.STDOUT)
        else:
            f.write("no trace: draws unchecked\n")


def result(r, ign, lab):
    """(state, text): state identical | differs | missing."""
    cmp_ = os.path.join(OUT, r["run"] + ".cmpdraws.txt")
    ours = os.path.join(LOGS, "%s.segment_begin-%s.txt" % (r["run"], r["cp"]))
    if not os.path.exists(cmp_) or not os.path.exists(ours):
        return "missing", "not replayed yet"
    c = open(cmp_, errors="replace").read()
    if not os.path.exists(os.path.join(LOGS, r["run"] + ".trace.txt")):
        c = "no trace: draws unchecked\n"      # (the early runs: statediff is the comparison)
    o = open(ours, errors="replace").read()
    sd = o.split("--- statediff", 1)[1].splitlines()[1:] if "--- statediff" in o else ["(no statediff: ours stopped?)"]
    sd = [l for l in sd if l.strip() and not re.match(r"\d+ differences?$", l.strip())
          and not any(p.search(l) for p in ign)]
    m = re.search(r"original: (\d+) draws.*ours: (\d+)", c)
    first = re.search(r"first difference at draw (\d+)", c)
    draws_ok = "draws: identical" in c or "no trace" in c or (
        first and m and int(m.group(2)) == int(first.group(1)) - 1)
    if draws_ok and not sd:
        return "identical", "draws %s; statediff 0" % ("unchecked (no trace)" if "no trace" in c else
                                                         "identical to the checkpoint")
    why = []
    if not draws_ok and first:
        n = int(first.group(1))
        roll = re.search(r"^\s*>\s*%d\s+(.*)$" % n, c, re.M)
        why.append("draw %d of %s: %s" % (n, m.group(1) if m else "?",
                                          re.sub(r"\s+", " ", roll.group(1)).strip() if roll else "?"))
        st = state_at(o, n)
        if st:
            why.append("state: " + st)
    if sd:
        why.append("statediff %d: %s" % (len(sd), "; ".join(s.strip() for s in sd[:3])))
    k, note = lab.get(r["run"], ("game", ""))
    return "differs", "[%s%s] %s" % (k, ": " + note if note else "", " | ".join(why))


def state_at(o, n):
    """Ours' state line (key, square, time, mode, screen text) last printed before draw n."""
    last = None
    for l in o.splitlines():
        d = re.match(r"\s*#(\d+) ", l)
        if d and int(d.group(1)) >= n:
            break
        if re.match(r"^\S+\s+(wild )?\d+,\d+ [NESW] \d\d:\d\d ", l):
            last = l
    if not last:
        return None
    parts = [p.strip() for p in last.split("|")]
    return re.sub(r"\s+", " ", parts[0])[:60] + (" | " + parts[-1][:90] if len(parts) > 2 and parts[-1] else "")


def score(md=None):
    ign, lab = known()
    rs = recordings()
    res = [(r, ) + result(r, ign, lab) for r in rs]
    done = [x for x in res if x[1] != "missing"]
    ident = [x for x in done if x[1] == "identical"]
    game = [x for x in done if x[1] == "differs" and x[2].startswith("[game")]
    lines = ["# The Stage 1 match (match.py score)", "",
             "**%d of %d recordings identical** (%d replayed, %d not yet); differences: %d game, %d replay tool, %d"
             " known shortcut; the frozen files: %s." % (
                 len(ident), len(rs), len(done), len(rs) - len(done), len(game),
                 sum(1 for x in done if x[2].startswith("[replay tool")),
                 sum(1 for x in done if x[2].startswith("[known shortcut")),
                 "as frozen" if not verify(quiet=True) else "CHANGED (match.py verify)"), "",
             "| Segment | Identical | Recordings |", "|---|---|---|"]
    for s in sorted(set(r["seg"] for r in rs)):
        xs = [x for x in res if x[0]["seg"] == s]
        lines.append("| %d | %d of %d | %s |" % (s, sum(1 for x in xs if x[1] == "identical"), len(xs),
                     ", ".join(x[0]["run"] + ("" if x[1] == "identical" else " (%s)" % (
                         "not yet" if x[1] == "missing" else x[2][1:x[2].index("]")].split(":")[0])) for x in xs)))
    lines += ["", "## The rest: first differing roll and the state there", ""]
    for r, st, txt in res:
        if st == "differs":
            lines.append("- **%s** (segment %d, `%s` -> `%s`): %s" % (r["run"], r["seg"], r["start"], r["cp"], txt))
    text = "\n".join(lines) + "\n"
    if md:
        open(md, "w").write(text)
    print(text)
    return res


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "score"
    if cmd == "manifest":
        manifest()
    elif cmd == "verify":
        sys.exit(1 if verify() else 0)
    elif cmd == "run":
        bad = verify()
        if bad:
            sys.exit("recordings changed since the manifest: re-record as new runs, don't replay changed files")
        want = set(sys.argv[2:])
        for r in recordings():
            if not want or r["run"] in want:
                print("replaying %s (segment %d)" % (r["run"], r["seg"]), flush=True)
                replay(r)
        score()
    elif cmd == "score":
        md = sys.argv[sys.argv.index("--md") + 1] if "--md" in sys.argv else None
        score(md)
    elif cmd == "baseline":
        res = score()
        open(os.path.join(M, "baseline.txt"), "w").write(
            "# recordings identical at %s (match.py baseline)\n" % os.popen("date -Iseconds").read().strip() +
            "".join(x[0]["run"] + "\n" for x in res if x[1] == "identical"))
    elif cmd == "gate":
        base = [l.strip() for l in open(os.path.join(M, "baseline.txt")) if l.strip() and not l.startswith("#")]
        if "--run" in sys.argv:
            # the build script's form: replay the baseline's recordings on this checkout first (about 5 min each)
            if verify():
                sys.exit("recordings changed since the manifest")
            for r in recordings():
                if r["run"] in base:
                    replay(r)
        ign, lab = known()
        rs = {r["run"]: r for r in recordings()}
        broke = [(b, result(rs[b], ign, lab)) for b in base if b in rs]
        broke = [(b, x) for b, x in broke if x[0] != "identical"]
        for b, x in broke:
            print("PARTS NOW: %s: %s" % (b, x[1]))
        print("MATCH GATE %s: %d of %d baseline recordings still identical" % (
            "FAILED" if broke else "OK", len(base) - len(broke), len(base)))
        sys.exit(1 if broke else 0)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

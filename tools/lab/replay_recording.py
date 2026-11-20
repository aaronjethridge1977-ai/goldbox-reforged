#!/usr/bin/env python3
"""replay_recording.py <file.gbrrec> <out dir>: a RECORD MY GAME session (scripts/game/game_recorder.gd) made into
ours' lab replay (main chat 70).

Writes <out dir>/start/ (the starting save's files: the original's slot files, or quick.cfg), <out dir>/settings.cfg
(the player's [qol] switches, for the replay's own Godot user folder: XDG_DATA_HOME=<x>, the file at
<x>/godot/app_userdata/Gold Box Reforged/settings.cfg) and <out dir>/keys (ours' --keys: seed=<n>, the load, then
every key; a gap of more than 2 s between keys adds `wait`s, one per 0.5 s, up to 20). Prints the build the session
was recorded with: replay it on that version's commit. Then, e.g.:

  cp <out>/start/* <game copy>/ ; godot --headless --path <proj> -- --game-path=<game copy> --save=<out>/start/quick.cfg \
      "--keys=$(cat <out>/keys)"

A slot session loads with load=<letter>; a quick-save session with F3 (--save= its quick.cfg); a new game's keys start
at the start menu. Keys with Alt are written as `alt+<key>` (the lab's own keys take `magic` for Alt-M in a fight).
"""
import base64, json, os, sys

NAMES = {"Enter": "Enter", "Escape": "Escape", "Up": "Up", "Down": "Down", "Left": "Left", "Right": "Right",
         "Home": "Home", "End": "End", "PageUp": "pgup", "PageDown": "pgdn", "Space": "Space"}


def main():
    src, out = sys.argv[1], sys.argv[2]
    lines = [json.loads(l) for l in open(src) if l.strip()]
    head, keys = lines[0], lines[1:]
    os.makedirs(os.path.join(out, "start"), exist_ok=True)
    for name, b64 in head.get("files", {}).items():
        with open(os.path.join(out, "start", name), "wb") as f:
            f.write(base64.b64decode(b64))
    with open(os.path.join(out, "settings.cfg"), "w") as f:
        f.write("[qol]\n\n" + "".join("%s=%s\n" % (k, json.dumps(v)) for k, v in head.get("qol", {}).items()))
    ks = ["seed=%d" % head["seed"]]
    if head["start"] == "slot":
        ks.append("load=" + head["letter"])
    elif head["start"] == "quick":
        ks.append("F3")
    last = 0
    for k in keys:
        gap = k["t"] - last
        last = k["t"]
        if gap > 2000:
            ks += ["wait"] * min(20, gap // 500)
        name = NAMES.get(k["k"], k["k"].lower() if len(k["k"]) == 1 else k["k"])
        if "alt" in k.get("m", ""):
            name = "alt+" + name
        ks.append(name)
    with open(os.path.join(out, "keys"), "w") as f:
        f.write(",".join(ks))
    print("build %s, recorded %s, seed %d, start %s %s: %d keys -> %s" % (
        head.get("build"), head.get("date"), head["seed"], head["start"], head.get("letter", ""), len(keys), out))


if __name__ == "__main__":
    main()

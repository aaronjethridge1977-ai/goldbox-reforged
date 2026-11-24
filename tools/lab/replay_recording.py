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

ORIGINAL'S BUGS (main chat 74): a --keys= run plays the original's bugs unless GBR_ORIGINAL_BUGS=0; the session's own
switch is in settings.cfg (off by default), so run the replay with the GBR_ORIGINAL_BUGS=<n> this script prints.

A slot session loads with load=<letter>; a quick-save session with F3 (--save= its quick.cfg); a new game's keys start
at the start menu. Keys with Alt are written as `alt+<key>` (main.gd's replay sets Alt on the key: Alt-M in a fight).
The mouse (main chat 73): a click a screen made into keys is in the file as those keys; a click no screen took as keys
(PRESS ENTER, a message any key ends) is a line {"c": button} and becomes `click` (left) or `click<n>`.
A held key's repeats (main chat 128) are lines with "e": 1: here plain keys (the walking screen acts on each);
the timed replay (timed=, treplay.sh) sends them as repeats, which the screens that ignore repeats ignore.
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
    # The replay must not record itself (main chat 72): with record_game on, its load starts a new session and
    # reseeds every generator from a fresh seed, so the replay's dice part from the session's (a camp scroll's d8).
    qol = dict(head.get("qol", {}), record_game=False)
    with open(os.path.join(out, "settings.cfg"), "w") as f:
        f.write("[qol]\n\n" + "".join("%s=%s\n" % (k, json.dumps(v)) for k, v in qol.items()))
    ks = ["seed=%d" % head["seed"]]
    if head["start"] == "slot":
        # The script memory before the load (main chat 73): the replay starts from a quick save, and a slot load keeps
        # the memory outside the save's image. A file older than chat 73 has neither field: a fresh start assumed.
        if head.get("vm_fresh", True):
            ks.append("vm=fresh")
        else:
            vm = os.path.abspath(os.path.join(out, "vm.cfg"))
            with open(vm, "w") as f:
                f.write('[vm]\n\nmem="%s"\nsize=%d\nhi=%s\n' % (head["vm_mem"], head["vm_size"], json.dumps(head["vm_hi"])))
            ks.append("vm=" + vm)
        ks.append("load=" + head["letter"])
    elif head["start"] == "quick":
        ks.append("F3")
    last = 0
    for k in keys:
        gap = k["t"] - last
        last = k["t"]
        if gap > 2000:
            ks += ["wait"] * min(20, gap // 500)
        if "c" in k:
            ks.append("click" if k["c"] == 1 else "click%d" % k["c"])
            continue
        name = NAMES.get(k["k"], k["k"].lower() if len(k["k"]) == 1 else k["k"])
        if "alt" in k.get("m", ""):
            name = "alt+" + name
        ks.append(name)
    with open(os.path.join(out, "keys"), "w") as f:
        f.write(",".join(ks))
    bugs = 1 if qol.get("original_bugs", False) else 0
    print("build %s, recorded %s, seed %d, start %s %s: %d keys -> %s; replay with GBR_ORIGINAL_BUGS=%d" % (
        head.get("build"), head.get("date"), head["seed"], head["start"], head.get("letter", ""), len(keys), out, bugs))


if __name__ == "__main__":
    main()

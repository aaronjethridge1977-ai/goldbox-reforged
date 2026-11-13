"""Union of coverage files (bot runs side by side): merge_cov.py <out> <in>..."""
import json, sys
out = {}
for f in sys.argv[2:]:
    for k, b in json.load(open(f))["blocks"].items():
        e = out.setdefault(k, {})
        for t, v in b.items():
            e.setdefault(t, set()).update(v)
json.dump({"blocks": {k: {t: sorted(v, key=str) for t, v in e.items()} for k, e in out.items()}}, open(sys.argv[1], "w"))

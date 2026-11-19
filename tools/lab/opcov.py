# opcov.py <cov dir> <listing dir>: which checks run each ECL opcode (chat 64).
# cov/<n>.json from diffcheck run with --coverage=; listings data/c62/ecl_ECL<f>_<b>.txt (addr = 0x9900 + offset).
import json, os, re, sys, collections
cov, lst = sys.argv[1], sys.argv[2]
ops = {}      # (blockkey, addr) -> op
allops = collections.Counter(); sites = collections.defaultdict(list)
for fn in os.listdir(lst):
	m = re.match(r'ecl_ECL(\d+)_(\d+)\.txt$', fn)
	if not m: continue
	key = '%s:%s' % m.groups()
	for line in open(os.path.join(lst, fn)):
		p = line.split()
		if len(p) >= 2 and re.fullmatch(r'[0-9A-F]{4}', p[0]):
			ops[(key, int(p[0], 16))] = p[1]; allops[p[1]] += 1; sites[p[1]].append('%s %s' % (key, p[0]))
by = collections.defaultdict(set); where = collections.defaultdict(set); unknown = collections.Counter()
for fn in os.listdir(cov):
	n = int(fn.split('.')[0]); d = json.load(open(os.path.join(cov, fn)))
	for key, b in d['blocks'].items():
		for o in b['ins']:
			op = ops.get((key, 0x9900 + int(o)))
			if op is None: unknown[key] += 1; continue
			by[op].add(n); where[op].add('%s %04X' % (key, 0x9900 + int(o)))
for op in sorted(allops):
	c = sorted(by.get(op, ()))
	print('%-20s %5d sites  %3d run  checks: %s' % (op, allops[op], len(where.get(op, ())), ' '.join(map(str, c)) if c else 'NONE  e.g. ' + ', '.join(sites[op][:4])))
if unknown: print('offsets not in the listings:', dict(unknown))

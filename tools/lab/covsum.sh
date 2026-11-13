#!/bin/bash
# covsum.sh [files]: each coverage run's own area (data/cov_<area>.json): played instructions,
# branches, choices, flag writes, and the critical counts (ways in/out, set fights, quest flags).
cd /home/claude/lab
for f in ${@:-data/cov_*.json}; do
	a=$(basename $f .json | sed 's/cov_//; s/-small//; s/-/:/')
	./covreport.sh $(readlink -f $f) --areas=$a --critical=$a 2>&1 | sed -n '/== played/,/Overall/p' \
		| python3 -c "
import re,sys
t=sys.stdin.read(); p=re.findall(r'(\d+)/(\d+)\s+(\d+)%',t.split('critical')[0])
c=re.search(r'critical: (.*)',t)
print('%-6s %s | %s' % ('$a', '  '.join('%3s%%' % x[2] for x in p[:4]), c.group(1) if c else ''))"
done

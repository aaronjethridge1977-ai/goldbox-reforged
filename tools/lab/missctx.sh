#!/bin/bash
# missctx.sh <set-block e.g. 5-4> [cov file]: each missed branch of the area with the two
# instructions before it (from tools/ecl.py dis), for working out the reasons, with misswhy.py's
# first guess in front (chat 16).
L=/home/claude/lab; a=$1; s=${a%-*}; b=${a#*-}; f=${2:-$L/data/cov_$a.json}
python3 /home/claude/goldbox-reforged/tools/ecl.py dis $L/game/ECL$s.DAX $b > /tmp/dis_$a.txt
$L/covreport.sh $(readlink -f $f) --areas=$s:$b --missed=$s:$b 2>&1 | sed -n '/== played$/,/Overall/p' | grep "missed" | python3 -c "
import sys,re
lines=open('/tmp/dis_$a.txt').read().splitlines()
idx={l[:4]:i for i,l in enumerate(lines) if re.match(r'^[0-9A-F]{4} ',l)}
for m in sys.stdin:
    m=m.strip(); off=m.split()[1]
    i=idx.get(off)
    ctx=' | '.join(re.sub(r'\s+',' ',lines[j][6:])[:70] for j in range(max(0,i-2),i) if not lines[j].startswith(';')) if i is not None else ''
    print('%-46s  %s' % (m.replace('missed ',''), ctx))
" | python3 $L/misswhy.py /tmp/dis_$a.txt | if [ -n "$CHAIN" ]; then
	# Chat 18 (decided 2026-11-14): CHAIN=1 adds, under each missed branch, the chain of tests from an entry
	# point to it, with the writers of each byte (data/writers.json, made by writers.py).
	[ -f $L/data/writers.json ] || python3 $L/writers.py $L/game $L/data/writers.json > /dev/null
	while IFS= read -r line; do
		echo "$line"
		off=$(echo "$line" | grep -o -E '(^| )[0-9A-F]{4} (IF_|ON_|MENU|ENCOUNTER|PARLAY)' | head -1 | awk '{print $1}')
		out=$(echo "$line" | grep -o -E -- '-> [0-9TF]+' | head -1 | awk '{print $2}')
		[ -n "$off" ] && python3 $L/chaintests.py /tmp/dis_$a.txt $off ${out:--} $L/data/writers.json ${a/-/:} | sed 's/^/      /'
	done
else cat; fi

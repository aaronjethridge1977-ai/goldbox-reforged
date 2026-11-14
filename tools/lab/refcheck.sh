#!/bin/bash
# refcheck.sh [source dir] [tag]: the reference-area check (decided 2026-11-14): 3:11 and 5:5, each from the
# merged coverage without that area, with the given source (default the repo); prints their covsum lines.
# Compare with data/refcheck_base.txt: neither may drop after a change to the bot.
L=/home/claude/lab; S=${1:-/home/claude/goldbox-reforged}; T=${2:-now}; cd $L; mkdir -p data/ref
for a in 3-11 5-5; do
	k=${a/-/:}
	python3 -c "
import json,sys
for src,dst in [('data/coverage.json','data/ref/cov_$a.json'),('data/branches.json','data/ref/br_$a.json')]:
    d=json.load(open(src)); d['blocks'].pop('$k',None); json.dump(d,open(dst,'w'))"
	BOT_SRC=$S BOT_ID=ref$a$T BOT_COVERAGE=$L/data/ref/cov_$a.json BOT_BRANCHES=$L/data/ref/br_$a.json ./bot.sh cover_$a.plan > data/ref/$a$T.log 2>&1 &
done
wait
for a in 3-11 5-5; do ./covsum.sh data/ref/cov_$a.json; grep -a "==== COVER .* done" data/ref/$a$T.log | grep -o "\[[0-9]*s\]"; done

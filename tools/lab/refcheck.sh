#!/bin/bash
# refcheck.sh [source dir] [tag]: the reference-area check (decided 2026-11-14): 3:11 and 5:5, each from the
# merged coverage without that area, with the given source (default the repo); prints their covsum lines.
# Compare with data/refcheck_base.txt: neither may drop after a change to the bot.
# Chat 21: each area replays the baseline's dice seed from data/refcheck_seeds.txt ("3-11 064f8f05"), so two
# checks differ only by the code (a fresh seed moved 3:11 between 83% and 88% on the same code). NEWSEED=1: a fresh
# seed, logged (re-taking the baseline: write its seeds to that file).
L=/home/claude/lab; S=${1:-/home/claude/goldbox-reforged}; T=${2:-now}; cd $L; mkdir -p data/ref
for a in 3-11 5-5; do
	k=${a/-/:}
	python3 -c "
import json,sys
for src,dst in [('data/coverage.json','data/ref/cov_$a.json'),('data/branches.json','data/ref/br_$a.json')]:
    d=json.load(open(src)); d['blocks'].pop('$k',None); json.dump(d,open(dst,'w'))"
	sd=$(awk -v a=$a '$1 == a {print $2}' data/refcheck_seeds.txt 2>/dev/null); [ -n "$NEWSEED" ] && sd=
	COVER_SEED=$sd BOT_SRC=$S BOT_ID=ref$a$T BOT_COVERAGE=$L/data/ref/cov_$a.json BOT_BRANCHES=$L/data/ref/br_$a.json ./bot.sh cover_$a.plan > data/ref/$a$T.log 2>&1 &
done
wait
for a in 3-11 5-5; do ./covsum.sh data/ref/cov_$a.json; grep -a -o "run seed [0-9a-f]*\|==== COVER .* done.*\[[0-9]*s\]" data/ref/$a$T.log | grep -o "run seed [0-9a-f]*\|\[[0-9]*s\]$" | tr '\n' ' '; echo; done

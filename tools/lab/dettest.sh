#!/bin/bash
# dettest.sh <tag> <n> [source]: chat 19's determinism check. n copies of 2:15 -all (cover_2-15-det.plan,
# a fixed seed) at once, each from the same coverage files (data/det/base_*), logs data/det/<tag>_<i>.log;
# then each walk is compared with the first (timestamps and the watchdog dropped). BOT_FPS= to drop --fixed-fps.
L=/home/claude/lab; T=$1; N=$2; S=${3:-/home/claude/goldbox-reforged}; cd $L; mkdir -p data/det
[ -f data/det/base_cov.json ] || cp data/cov_2-15.json data/det/base_cov.json
[ -f data/det/base_br.json ] || cp data/br_2-15.json data/det/base_br.json
for i in $(seq 1 $N); do
	cp data/det/base_cov.json data/det/cov_$T$i.json; cp data/det/base_br.json data/det/br_$T$i.json
	BOT_SRC=$S BOT_ID=det$T$i BOT_RESUME=$L/data/det/resume_$T$i.txt BOT_COVERAGE=$L/data/det/cov_$T$i.json \
		BOT_BRANCHES=$L/data/det/br_$T$i.json ./bot.sh cover_2-15-det.plan > data/det/$T$i.log 2>&1 &
done
wait
norm() { grep -av "\[watch\]" "$1" | sed -E 's/\[[0-9]+s\]//g; s/>> \[[0-9]+s\]/>>/' ; }
norm data/det/${T}1.log > data/det/${T}1.n
for i in $(seq 1 $N); do
	norm data/det/$T$i.log > data/det/$T$i.n
	echo "$T$i: $(wc -l < data/det/$T$i.n) lines, $(diff data/det/${T}1.n data/det/$T$i.n | grep -c '^[<>]') differ; $(grep -a '==== COVER .*done' data/det/$T$i.log | tail -1 | cut -c1-160)"
done

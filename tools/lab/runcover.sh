#!/bin/bash
# runcover.sh <area as 5-3> [suffix]: a coverage run of one area into its own coverage files
# (data/cov_<area>.json, started from the merged data/coverage.json), log data/cover_<area><suffix>.log
# PLAN=cover_5-4-alarm.plan runs a variant plan into the same files.
L=/home/claude/lab; a=$1; cd $L
[ -f data/cov_$a.json ] || cp data/coverage.json data/cov_$a.json
[ -f data/br_$a.json ] || cp data/branches.json data/br_$a.json
BOT_ID=$a$2 BOT_TIMEOUT=${BOT_TIMEOUT:-6000} BOT_COVERAGE=$L/data/cov_$a.json BOT_BRANCHES=$L/data/br_$a.json ./bot.sh ${PLAN:-cover_$a.plan} > data/cover_$a$2.log 2>&1

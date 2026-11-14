#!/bin/bash
# hand_2-9-toll.sh: chat 21's keyed replay of 2:9's toll (0xAB64-0xAC4B and the payment routine 0x9956-0x9B66),
# which the bot's rich checkpoint parties never reach: the toll paid by the first member, paid from several
# members (the first has no coins: 0x99C2 -> F, 0x99D8), and no one able to pay ("YOU DON'T HAVE ENOUGH MONEY!",
# 0x99F1). Lab save H from J (never J): the party at 7,12 facing north, the gate unfought with the wagon bought,
# as differential check 4. Coverage goes to data/cov_2-9_hand.json; merge it with
#   merge_cov.py data/cov_2-9.json data/cov_2-9.json data/cov_2-9_hand.json
L=/home/claude/lab; cd $L
Q=$(mktemp --suffix=.cfg); cp data/diff_2-9_ours.cfg $Q     # any quick save: --keys needs one to start from
for poor in "" "1" "1 2 3 4 5 6"; do
	python3 mksave.py J H 2 9 7 12 N 4A77=96 4A64=0 4A78=0 4AB9=0 >/dev/null
	python3 - $poor <<'EOF'
import sys, struct
for n in sys.argv[1:]:
	p = "game/CHRDATH%s.SAV" % n; d = bytearray(open(p, "rb").read())
	struct.pack_into("<5H", d, 0x88, 0, 0, 0, 0, 0); open(p, "wb").write(d)
EOF
	echo "== members without coins: ${poor:-none}"
	GTIME=60 ./ours.sh --save=$Q --keys='load=H,Up,Up,Y,Enter,Enter,Enter' --coverage=$L/data/cov_2-9_hand.json 2>&1 | grep -a '^Y '
done
rm -f $Q

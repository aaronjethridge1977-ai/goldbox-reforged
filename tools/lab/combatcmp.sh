#!/bin/bash
# The original's combat captures (cap/c, save E: the Slums orcs at 13,1) against ours with the
# same keys. The first actor is random in both; these held when Thrender acted first.
cd /home/claude/lab
run() { o=$1; shift; ./ours.sh --save=$PWD/quicksave.cfg "--keys=$1,screen=/tmp/ours_$(basename $o)" 2>/dev/null | grep -q "THRENDER" ; printf "%-16s " $(basename $o); python3 cmp.py $o /tmp/ours_$(basename $o) 2>/dev/null | head -${LINES_SHOWN:-4} | tr '\n' ' '; echo; }
B=combatseed=2,load=E,up,up,enter,wait
run cap/c/c0.png $B
run cap/c/move.png $B,m
run cap/c/back.png $B,m,esc
run cap/c/view.png $B,m,esc,v
run cap/c/items.png $B,m,esc,v,i
run cap/c/view_back.png $B,m,esc,v,i,e
run cap/c/after_view.png $B,m,esc,v,i,e,e
run cap/c/aim0.png $B,m,esc,v,i,e,e,a
run cap/c/aim1.png $B,m,esc,v,i,e,e,a,n
run cap/c/manual.png $B,m,esc,v,i,e,e,a,n,m
run cap/c/use.png $B,m,esc,v,i,e,e,a,n,m,e,e,u
run cap/c/after_use.png $B,m,esc,v,i,e,e,a,n,m,e,e,u,e
run cap/c/done.png $B,m,esc,v,i,e,e,a,n,m,e,e,u,e,d
run cap/c/g1.png $B,d,g

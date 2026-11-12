#!/bin/bash
# Each case: <original capture> <keys for ours>; screen is taken after the keys.
cd /home/claude/lab
run() { o=$1; shift; ./ours.sh --save=$PWD/quicksave.cfg "--keys=$1,screen=/tmp/ours_$(basename $o)" >/dev/null 2>&1; printf "%-22s " $(basename $o); python3 cmp.py $o /tmp/ours_$(basename $o) | head -${LINES_SHOWN:-4} | tr '\n' ' '; echo; }
run cap/v/view0.png load=J,v
run cap/v/view1.png load=J,end,v
run cap/v/view2.png load=J,end,end,v
run cap/v/view3.png load=J,end,end,end,v
run cap/v/view4.png load=J,end,end,end,end,v
run cap/v/view5.png load=J,end,end,end,end,end,v
run cap/v/items1.png load=J,end,v,i
run cap/v/it_u1.png load=J,end,v,i,r,u
run cap/v/it_t1.png load=J,end,v,i,r,t
run cap/v/it_t2.png load=J,end,v,i,r,t,end
run cap/v/it_t3.png load=J,end,v,i,r,t,end,enter
run cap/v/it_d1.png load=J,end,v,i,r,t,end,enter,r,d
run cap/v/spells1.png load=J,end,v,s
run cap/v/back.png load=J,end,v,i,r,t,end,enter,r,d,n,r,u,e
run cap/v/ct1.png load=J,end,v,i,r,t,end,enter,r,d,n,r,u,e,s,e,t
run cap/v/ct2.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter
run cap/v/ct3.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter,end,enter
run cap/v/ct4.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter,end,enter,1,0,enter
run cap/v/i_view.png load=I,v
run cap/v/i_items.png load=I,v,i
run cap/v/spells_i.png load=I,end,v,s
run cap/v/camp_view.png load=F,e,v
run cap/v/cd1.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter,end,enter,1,0,enter,e,e,d
run cap/v/cd2.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter,end,enter,1,0,enter,e,e,d,end,enter
run cap/v/cd3.png load=J,end,v,i,r,t,end,enter,e,s,e,t,end,enter,end,enter,1,0,enter,e,e,d,end,enter,5,enter
run cap/v/hall_view.png load=H,up,up,y,v
run cap/v/shop_view.png load=G,up,up,y,v
run cap/v/shop_items.png load=G,up,up,y,v,i
run cap/v/shop_sell.png load=G,up,up,y,v,i,r,s
run cap/v/shop_sold.png load=G,up,up,y,v,i,r,s,y
run cap/v/shop_id.png load=G,up,up,y,v,i,r,s,y,i

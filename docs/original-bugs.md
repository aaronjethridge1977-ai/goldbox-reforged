# The original's bugs

Jeremy, 2026-11-20 07:40 (through the Lead): the original's bugs become fixes by default, with a SETTINGS switch
**ORIGINAL'S BUGS** to play them as the original does. Main builds the list and the flag; the screens are the combat
lane's when main asks. Every lane adds each original bug it reproduces here: what the original does, what the rules
say, where in the code, how it was seen, and what ours does now.

| # | Bug | The original | The rule | Code | Seen | Ours now |
|---|-----|--------------|----------|------|------|----------|
| 1 | Magic Missile at caster level 1 | No missile, no damage: (level / 2) missiles of d4+1, rounded down (one at levels 2-3, two at 4-5, ...) | One missile at levels 1-2, one more every two levels | GAME.OVR 0x28451: (L/2)d4 + L/2, L from START.EXE 0xBA:0x26C2 | Combat Chat 33's spell lab: 11 casts by BAKSHI (magic-user 1), no damage die drawn, matched draw for draw by ours (regress `orig_A_c33_mm_kob`); main's cold-open capture (chat 38) | As the original (no flag yet) |

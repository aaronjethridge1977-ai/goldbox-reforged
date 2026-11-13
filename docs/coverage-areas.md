# Script coverage by area (M6)

Coverage runs one area at a time, as decided on 2026-11-13. Each run starts from a main-line checkpoint
(the story flags a player would have there), with the party at the area's expected level. It walks every
part of every map the area's script runs on and comes in by every way the area graph knows. Each event
square is entered and then left in all four directions, entered again, and entered once more with SEARCH
on. Every fight is won at once by shortcut ([cover-fights.md](cover-fights.md) lists them for the combat
suite). Every menu choice not yet taken is played for real from a snapshot of the step that led to it. See
`tools/lab/README.md`, "Chat 14 additions".

**Done** means 90% of reachable instructions, 85% of reachable branch outcomes, 100% of the story-critical
instructions (ways in and out, set fights, quest flags 0x4A20-0x4AFF), and every path left listed with its
reason. "Reachable" leaves out what no game state can take. The report works out part of that by itself:
encounter outcomes that no choice can give, and ADVANCE where the monsters stand at distance 0.

## Where each area stands (chat 14, all runs merged)

Played percentages; the figure in brackets is where the area stood before chat 14. Critical = ways in/out ·
set fights · quest flags.

| area | instructions | branches | critical | done? | what holds it back |
|---|---|---|---|---|---|
| 5:5 Valjevo inner castle | 94 (18) | 87 (16) | 7/7 · 7/7 · 15/15 | **yes** | done (see below) |
| 1:24 Temple of Bane quarter | 88 (50) | 79 (40) | 4/5 · 10/11 · 14/16 | no |  |
| 6:28 Zhentil outpost | 88 (76) | 87 (67) | 4/5 · 8/9 · 3/5 | no |  |
| 2:20 Slums | 87 (70) | 71 (58) | 4/4 · 20/20 · 20/21 | no |  |
| 8:16 ruined castle | 87 (58) | 73 (48) | 4/4 · 5/7 · 14/18 | no | travel found no way in (teleported) |
| 7:22 Yarash's pyramid, outside | 85 (79) | 85 (78) | 4/4 · 1/1 · 6/10 | no |  |
| 8:29 Kuto's Well | 84 (78) | 74 (68) | 6/8 · 6/7 · 15/17 | no |  |
| 4:21 Sokal Keep | 83 (70) | 73 (60) | 4/4 · 3/4 · 7/9 | no |  |
| 1:18 Podol Plaza | 82 (50) | 72 (47) | 6/6 · 6/7 · 17/24 | no |  |
| 5:7 Valjevo tower | 82 (37) | 73 (27) | 4/4 · 5/5 · 13/15 | no |  |
| 8:13 kobold caves | 82 (64) | 79 (56) | 3/3 · 14/15 · 17/19 | no |  |
| 7:23 Yarash's pyramid, inside | 81 (73) | 76 (64) | 4/4 · 3/5 · 16/21 | no |  |
| 2:15 Mendor's library | 80 (63) | 67 (52) | 3/3 · 7/7 · 19/25 | no |  |
| 3:8 City Hall | 80 (74) | 79 (75) | 2/2 · 3/3 · 23/34 | no | the clerk's rewards need finished quests (another state) |
| 4:10 Valhingen graveyard | 80 (62) | 68 (50) | 2/2 · 15/18 · 34/48 | no |  |
| 6:19 Diogenes's cave mouth | 80 (38) | 85 (40) | 1/2 · – · 2/3 | no | the kobolds' silver bottle (another state) |
| 4:2 Cadorna textile house | 79 (52) | 71 (46) | 5/5 · 11/12 · 14/17 | no |  |
| 5:3 Valjevo outer castle | 78 (50) | 70 (43) | 7/7 · 10/11 · 20/23 | no |  |
| 5:6 Valjevo, temple side | 78 (71) | 64 (55) | 3/3 · 6/6 · 15/21 | no |  |
| 7:17 nomads' camp | 78 (66) | 68 (56) | 3/3 · 5/6 · 14/20 | no |  |
| 3:14 Kovel Mansion | 76 (60) | 73 (58) | 5/5 · 7/14 · 13/21 | no | set fights behind doors |
| 3:0 New Phlan | 70 (55) | 59 (47) | 9/12 · 5/8 · 9/9 | no | the town's many parts; the temple guards' loop |
| 6:1 Buccaneers' base | 67 (58) | 62 (52) | 3/3 · 12/15 · 5/7 | no | the guarded door's SHOW PASS loop |
| 2:9 Stojanow Gate | 64 (59) | 60 (51) | 3/4 · 3/7 · 16/24 | no | the bugbears' warning loop |
| 5:4 Valjevo, north side | 59 (59) | 50 (50) | 5/7 · 5/6 · 13/24 | no | arrives in a walled-off part; its ways in from 5:3 didn't go through |
| 3:11 training halls, arena | 51 (45) | 41 (38) | 2/3 · 0/2 · 0/1 | no | its rooms open off New Phlan's map; only 9,0 leads in |
| 6:25, 7:26, 8:27 wilderness bands | (58, 74, 66) | | | not run | the coverage walker is for dungeon maps |

Overall, all runs merged: played 61% → **77%** of instructions and 52% → **69%** of reachable branches (choices 22% → 64%, flag writes 61% → 78%); with the choices not taken tried in the shadow copy as well, 81% and 72%.

## 5:5, Valjevo's inner castle: done

94% of instructions (401 of 425) and 87% of reachable branch outcomes (129 of 148; 7 are dead). Every
story-critical instruction has run: 7 ways in or out, 7 set fights, 15 quest flags. Four runs did it: the
full party twice, then a one-member party playing every choice. The false Tyranthraxus only collapses before
a party whose strength plus the leader's charisma bonus is under 85 (0xA9DA).

**Dead: no state can take them** (left out of the counts): 0x9DC0, 0x9FA2, 0x9FF9, 0xAC22 and 0xA9AE
outcome 0. Those encounters have no "monsters leave" reaction. 0x9FA2 and 0x9FF9 outcome 3: their PARLAY
reaction is a fight. 0xA98A ADVANCE: the false Tyranthraxus's menu stands at distance 0. Also 0x9C93 → T
(0x4A67 bit 7): the step script clears that bit on every move (0x9A80), so the teleport square never finds it
set. The report doesn't yet work this one out by itself.

**Another party or another moment:**

| where | what it needs |
|---|---|
| 0x9924 → T | a ranger in the party (harder to surprise) |
| 0x994F → T | both sides surprised (a SURPRISE roll of 3) |
| 0x9977 → T | the alarm set at hour 23 and checked at hour 0 |
| 0x9D0A → T, 0xAC46 → T | a fight that ends other than won (fled, lost): fights are won by shortcut here; the combat suite tests the rest |
| 0x9FA2 → 2, 0x9FF9 → 2, 0x9DC0 → 2, 0xAC22 → 2 | FLEE succeeding: a party faster than these monsters |
| 0xA295 → 1 | COMBAT against the fleeing mage: a party faster than him (else "THE MONSTERS FLEE") |
| 0xA074 → T | event 22 from the inside, facing east, with the alarm ringing |
| 0xA085 → T | coming back to the gate after forcing it (a job forces it but doesn't come back) |
| 0xA093 → T, 0xA4A0 → T | having stolen from Lord Bane (5:6's flag 0x4A6A) |
| 0xA4AE → T | the giants' tower with the alarm already off and flag 0x4A65 bit 0 |
| 0xAA8E → T, 0xAACC → T/F, 0xAB99 → F | the shared YES/NO subroutine (0x9A1D, 0x9A0E): NO from these callers. The harness now gives each caller its own job (from chat 14's last commit), so the next run takes them |

## Other areas

Not yet gone through branch by branch. The table's last column gives what was seen in the logs.

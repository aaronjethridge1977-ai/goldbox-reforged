# Script coverage by area (M6)

Coverage runs one area at a time, as decided on 2026-11-13. Each run starts from a main-line checkpoint
(the story flags a player would have there), with the party at the area's expected level. It walks every
part of every map the area's script runs on and comes in by every way the area graph knows. Each event
square is entered and then left in all four directions, entered again three times (the dice rerolled), and
searched four times in a row. Every fight is won at once by shortcut ([cover-fights.md](cover-fights.md) lists
them for the combat suite), and each set fight is also replayed once with the party fleeing. Every menu choice
not yet taken is played for real from a snapshot of the step that led to it, and a choice that switches the
area's flags opens a state that is walked again. Variant runs replay every choice (`-all`), walk each event
from the arrival (`-fresh`), start from other checkpoints or set a flag a player can have (logged shortcuts).
See `tools/lab/README.md`, "Chat 14 additions" and "Chat 15 additions".

**Done** means 90% of reachable instructions, 85% of reachable branch outcomes, 100% of the story-critical
instructions (ways in and out, set fights, quest flags 0x4A20-0x4AFF), and every path left listed with its
reason. "Reachable" leaves out what no game state can take. The report works out part of that by itself:
encounter outcomes that no choice can give (also when other instructions or a subroutine that leaves the
menu's variable alone sit between the menu and its ON_GOTO), ADVANCE where the monsters stand at distance 0,
and tests of flag bits that no script ever sets.

## Where each area stands (chat 15, all runs merged)

Played percentages; the figure in brackets is chat 14's (the bands: the merged runs before any band walk).
Critical = ways in/out · set fights · quest flags. Branch percentages are against chat 15's (smaller)
reachable counts.

| area | instructions | branches | critical |
|---|---|---|---|
| 5:4 Valjevo, north side | 96 (59) | 91 (50) | 7/7 · 6/6 · 24/24 |
| 5:5 Valjevo inner castle | 95 (94) | 91 (87) | 7/7 · 7/7 · 15/15 |
| 8:16 ruined castle | 93 (87) | 81 (73) | 4/4 · 6/7 · 16/18 |
| 4:21 Sokal Keep | 92 (83) | 84 (73) | 4/4 · 4/4 · 9/9 |
| 8:29 Kuto's Well | 89 (84) | 80 (74) | 7/8 · 6/7 · 17/17 |
| 7:23 Yarash's pyramid, inside | 88 (81) | 85 (76) | 4/4 · 3/5 · 18/21 |
| 6:28 Zhentil outpost | 88 (88) | 87 (87) | 4/5 · 8/9 · 3/5 |
| 2:20 Slums | 88 (87) | 76 (71) | 4/4 · 20/20 · 20/21 |
| 1:24 Temple of Bane quarter | 88 (88) | 79 (79) | 4/5 · 10/11 · 14/16 |
| 7:22 Yarash's pyramid, outside | 87 (85) | 86 (85) | 4/4 · 1/1 · 6/10 |
| 7:17 nomads' camp | 87 (78) | 79 (68) | 3/3 · 5/6 · 15/20 |
| 5:7 Valjevo tower | 87 (82) | 81 (73) | 4/4 · 5/5 · 13/15 |
| 4:10 Valhingen graveyard | 87 (80) | 75 (68) | 2/2 · 16/18 · 38/48 |
| 3:14 Kovel Mansion | 86 (76) | 81 (73) | 5/5 · 13/14 · 20/21 |
| 2:15 Mendor's library | 86 (80) | 76 (67) | 3/3 · 7/7 · 22/25 |
| 8:13 kobold caves | 85 (82) | 83 (79) | 3/3 · 14/15 · 17/19 |
| 4:2 Cadorna textile house | 85 (79) | 80 (71) | 5/5 · 11/12 · 14/17 |
| 3:11 training halls, arena | 85 (51) | 79 (41) | 2/3 · 2/2 · 1/1 |
| 3:0 New Phlan | 85 (70) | 76 (59) | 12/12 · 7/8 · 9/9 |
| 1:18 Podol Plaza | 85 (82) | 79 (72) | 6/6 · 6/7 · 17/24 |
| 5:6 Valjevo, temple side | 81 (78) | 72 (64) | 3/3 · 6/6 · 19/21 |
| 6:19 Diogenes's cave mouth | 80 (80) | 85 (85) | 1/2 · 0/0 · 2/3 |
| 5:3 Valjevo outer castle | 80 (78) | 74 (70) | 7/7 · 10/11 · 20/23 |
| 3:8 City Hall | 80 (80) | 79 (79) | 2/2 · 3/3 · 23/34 |
| 7:26 wilderness band, middle | 77 (75) | 66 (61) | 18/18 · 1/7 · 6/6 |
| 6:1 Buccaneers' base | 75 (67) | 71 (62) | 3/3 · 13/15 · 5/7 |
| 8:27 wilderness band, east | 70 (66) | 61 (52) | 10/10 · 5/12 · 6/6 |
| 6:25 wilderness band, west | 67 (58) | 62 (47) | 11/11 · 3/13 · 5/5 |
| 2:9 Stojanow Gate | 67 (64) | 65 (60) | 3/4 · 3/7 · 17/24 |

Overall, all runs merged: played 77% → **84%** of instructions and 69% → **77%** of reachable branches (choices 64% → 78%, flag writes 78% → 84%); with the choices not taken tried in the shadow copy as well, 86% and 80%. Not rerun in chat 15 (the queue was stopped to save state): 6:28, 1:24, 3:8, 6:19.

**Done:** 5:4 and 5:5. Close: 4:21 (branches 84%), 8:16 (two critical left), 7:23, 6:28.

## 5:4, Valjevo's north side: done

96% of instructions (520 of 537) and 91% of reachable branch outcomes (170 of 186; 11 dead). Every
story-critical instruction has run: 7 ways in or out, 6 set fights, 24 quest flags. Chat 14's runs all
landed in the strip south of the buildings, which has no events; ways in by part (chat 15) reach the yard
and the buildings from 5:3's map 5 (11,0 and 12,0). Four runs did the rest: the plain run, the alarm
variant (checkpoint "valjevo4"), the late variant ("valjevo6", shrines desecrated: the patrols cry
"blasphemers") and the disguise variant: 5:6's disguise worn (0x4A65 bit 0, set by shortcut as a player who
said YES has it), Cadorna's fate unsettled (0x4ABE), each event walked to from the arrival, so the alarm one
fight raises doesn't hide the fighter at the barracks door.

**Another party or another moment:**

| where | what it needs |
|---|---|
| 0x994F → T | both sides surprised (a SURPRISE roll of 3) |
| 0x9977 → T | the alarm set at hour 23 and checked at hour 0 |
| 0x9B73 → T | the area's init with map 4 already up: a game saved in 5:4 and loaded (the runs start from our checkpoints) |
| 0x9B9E → T | a fight that ends neither won nor fled: lost, which ends the game |
| 0x9D1F, 0x9D90, 0xA032, 0xA289, 0xA36B, 0xA62E, 0xABCF, 0xAC29 → 2 | FLEE at the encounter menu succeeding: a party faster than the patrol, the giants or the officers (fled fights are covered by the flee jobs; these are the menu's own FLEE) |
| 0xA255 PARLAY | the giants' menu at distance 0 (they come at distance 2: ADVANCE or a fight first) |
| 0xA2F7 → T | the giants' pigsty again after their PARLAY gave the passwords (0x4A67 bit 6) |
| 0xAA20 → T | TALK TO THE OVERSEER a second time in the same visit |
| 0xAAFD → T | the scribes' building after 17:00 |
| 0xAE9C → T | the third report found a second time (the reports are a roll of 10 on SEARCH) |

## 5:5, Valjevo's inner castle: done

95% of instructions and 91% of reachable branch outcomes. Chat 15's rerun with the one-member party gave the
shared YES/NO subroutine's callers their own jobs: 0xAA8E, 0xAACC and 0xAB99 are taken, and so is 0xAC46 (the
fled side, from a flee job). 0x9C93 and 0xA9AE outcome 0 are now worked out as dead by the report. What is
left is chat 14's list without those: a ranger in the party (0x9924), both sides surprised (0x994F), the alarm
across midnight (0x9977), a fight lost (0x9D0A), FLEE succeeding at the menu (0x9DC0, 0x9FA2, 0xAC22 → 2), COMBAT
against the fleeing mage (0xA295 → 1), event 22 from the inside facing east with the alarm on (0xA074), coming
back to the gate after forcing it (0xA085), having stolen from Lord Bane (0xA093, 0xA4A0), the giants' tower with
the alarm off and the disguise on (0xA4AE).

## 3:11, training halls and arena

85% / 79% (from 51 / 41). All set fights and quest flags have run (the city watch fought, from a rest job).
Left: the watch fight fled (0xA094 → T: the party ran, NEW_ECL 0 at 0xA140, the critical way out; the next run
with flee jobs on rests should take it), an event above 18 while the halls' script is loaded (0x9976: no such
square next to the halls), the area's init after a rest (0x9A2C), the training halls entered again while 0x4A09
still counts (0x9B5C, 0x9B89, 0x9F90, 0x9FBE), the duel and the hire question asked a second time (0x9C00,
0x9CB8), a duelist who is an NPC (0x9C86), the hireling rolls (0x9D1A-0x9D5C: rolls of 250), more than seven
hires (0x9CF5) and a party of eight (0xA0D3).

## What holds the rest back

- **2:9 Stojanow Gate (67 / 65):** the bugbears push the party back from the wall on every approach
  (TAKE THE PUNCH, the plan's answer), and the tower stairs move the party within map 9, so the tower rooms were
  never an arrival. Chat 15's last change (a step into another part of the same map is a new arrival) is in
  the code; 2:9 needs a run with it. The payment routine at 0x9956-0x9B66 needs other purses (coin mixes) and
  members' status.
- **6:1 Buccaneers' base (75 / 71):** the captain's pass (item 91) is checked at 0xABBD and no script gives it
  (treasure, if anywhere); the merchant and the boy (0x9F20, 0xA225) come only in the "heir" quest's state.
- **The bands (6:25, 7:26, 8:27):** every square walked, every way out 100%; set fights 3/13, 1/7, 5/12: the
  lizard men's village and similar sites are maps the band's script loads (now walked as maps, not yet run), and
  several sites test the day and hour.
- **3:0 New Phlan (85 / 75):** much better with the mid- and late-story variants and rerolls; the proclamations
  and boats follow story counters (0x4AC1, 0x4AC4), the gambling wheel and pickpocket are rolls.

## 5:5 in chat 14 (for the record)

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

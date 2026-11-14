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

Chat 16 changed the method in four ways (`tools/lab/README.md`, "Chat 16 additions"): runs are about 30 times
faster (headless Godot slept 6.9 ms a frame); every square of every event is visited, from every open side, and
LOOK is used facing each way; each part is saved and loaded once (the "game loaded here" branches); flee jobs
flee their own fight, and fights a rest brings get theirs. The report also works out the values each flag byte
can hold (0x4A00-0x4A1F per visit), so tests no value can pass are dead. Two engine bugs came out of it, both
checked against the original: the wall ahead (0xC04E) after a step, and the per-visit flags on loading a save.

## Where each area stands (chat 16, all runs merged)

Played percentages; chat 15's in brackets. Critical = ways in/out · set fights · quest flags. **Done** = meets the
numbers and the critical count, every remaining path listed below with its reason.

| area | instructions | branches | critical | |
|---|---|---|---|---|
| 6:28 Zhentil outpost | 97 (88) | 97 (87) | 5/5 · 9/9 · 5/5 | done |
| 5:4 Valjevo, north side | 96 (96) | 91 (91) | 7/7 · 6/6 · 24/24 | done |
| 8:16 ruined castle | 96 (93) | 88 (81) | 4/4 · 7/7 · 18/18 | done |
| 5:5 Valjevo inner castle | 95 (95) | 91 (91) | 7/7 · 7/7 · 15/15 | done |
| 8:29 Kuto's Well | 95 (89) | 86 (80) | 8/8 · 7/7 · 17/17 | done |
| 4:21 Sokal Keep | 94 (92) | 92 (84) | 4/4 · 4/4 · 9/9 | done |
| 1:24 Temple of Bane quarter | 94 (88) | 88 (79) | 4/5 · 11/11 · 15/16 |  |
| 2:15 Mendor's library | 93 (86) | 85 (76) | 3/3 · 7/7 · 24/25 |  |
| 7:22 Yarash's pyramid, outside | 92 (87) | 91 (86) | 4/4 · 1/1 · 7/10 |  |
| 3:11 training halls, arena | 92 (85) | 88 (79) | 3/3 · 2/2 · 1/1 | done |
| 7:17 nomads' camp | 90 (87) | 86 (79) | 3/3 · 5/6 · 16/20 |  |
| 7:23 Yarash's pyramid, inside | 89 (88) | 86 (85) | 4/4 · 3/5 · 18/21 |  |
| 2:20 Slums | 89 (88) | 78 (76) | 4/4 · 20/20 · 20/21 |  |
| 7:26 wilderness band, middle | 89 (77) | 78 (66) | 18/18 · 5/7 · 6/6 |  |
| 5:7 Valjevo tower | 88 (87) | 83 (81) | 4/4 · 5/5 · 13/15 |  |
| 4:10 Valhingen graveyard | 88 (87) | 78 (75) | 2/2 · 16/18 · 38/48 |  |
| 3:14 Kovel Mansion | 87 (86) | 82 (81) | 5/5 · 14/14 · 21/21 |  |
| 1:18 Podol Plaza | 87 (85) | 81 (79) | 6/6 · 6/7 · 20/24 |  |
| 3:0 New Phlan | 87 (85) | 79 (76) | 12/12 · 7/8 · 9/9 |  |
| 4:2 Cadorna textile house | 86 (85) | 84 (80) | 5/5 · 11/12 · 15/17 |  |
| 8:13 kobold caves | 86 (85) | 84 (83) | 3/3 · 14/15 · 17/19 |  |
| 6:1 Buccaneers' base | 85 (75) | 86 (71) | 3/3 · 14/15 · 5/7 |  |
| 5:6 Valjevo, temple side | 83 (81) | 73 (72) | 3/3 · 6/6 · 19/21 |  |
| 3:8 City Hall | 81 (80) | 82 (79) | 2/2 · 3/3 · 23/34 |  |
| 5:3 Valjevo outer castle | 81 (80) | 77 (74) | 7/7 · 10/11 · 21/23 |  |
| 6:19 Diogenes's cave mouth | 80 (80) | 85 (85) | 1/2 · 0/0 · 2/3 |  |
| 8:27 wilderness band, east | 71 (70) | 61 (61) | 10/10 · 5/12 · 6/6 |  |
| 2:9 Stojanow Gate | 69 (67) | 70 (65) | 3/4 · 3/7 · 17/24 |  |
| 6:25 wilderness band, west | 69 (67) | 64 (62) | 11/11 · 3/13 · 5/5 |  |

Overall, all runs merged: played 84% → **87%** of instructions and 77% → **82%** of reachable branches (choices
82%, flag writes 88%); with the choices not taken tried in the shadow copy as well, 89% and 84%.

**Done:** 5:4, 5:5, 6:28, 8:16, 4:21, 8:29, 3:11 (7 of 29). Close: 2:15 (one quest flag), 1:24 (a way out, a
quest flag), 7:22 (quest flags 7/10), 7:17, 7:23.

## 6:28, the Zhentil outpost: done

97% of instructions and 97% of reachable branch outcomes; every story-critical instruction has run (5 ways in or
out, 9 set fights, 5 quest flags). Chat 16's runs did it: the guided tour no longer cut short (the bot's
`_settle` limit), every square of every event from every side, flee jobs that flee their own fight (the
guard waves, then the commandant), and a game saved and loaded in the outpost (0xB6CD).

| where | what it needs |
|---|---|
| 0xA1D3 → T | the dwarf's men (event 5) after the commandant is dead (0x4A5A) but before they were met (0x4A0F): every run met them first |
| 0xA391 → T | the escape fight at the front gate fled: the run met it only inside another job, so no flee job was queued for it |
| 0xAB36 → T | the commandant's talk about New Phlan a second time in the same visit (0x4A19, cleared on entry) |
| 0xB636 → F | a rest while 0x4A0E is set (the escort or the alarm): no run rested in that state |

## 8:16, the ruined castle: done

96% of instructions and 88% of reachable branch outcomes; every story-critical instruction has run (4 ways in or
out, 7 set fights, 18 quest flags). The last two came from a variant (`cover_8-16-killed.plan`): the castle
counts the lizard men the party kills (0x4A5D, after each fight), and from 40 leaving sets 0x4AB5 = 254
(0x9CCF); the count was set to 60 by logged shortcut, as a player who fought through the castle has it.

| where | what it needs |
|---|---|
| 0x9966 → F, 0xABF6 → T | an event not in the 13-entry square table (0x9935): only those events call it, so in practice dead |
| 0x99AC → F | the second kill count (0x4A5F) at 10 or more; the variant set only 0x4A5D |
| 0x99C7 → T, 0x9DA0 → T, 0xA804 → F, 0xA85E → F | the fights made smaller by high kill counts (0x9971 takes 50 off 0x4A5D, 10 off 0x4A5E): the sizes the tables give were never undercut that far |
| 0x9A1A → T | the kills added from a fight capped by 0x6DC8 (not worked out yet) |
| 0x9CC3 → T, 0xA361 → F | 0x4AB5 = 255, written only outside this area (the lizard king's quest finished elsewhere) |
| 0x9CFF → 0 | the search table's case 0: no square searches to it |
| 0xA31B → F | a champion other than the first member at the WHO menu: the bot always picks the first |
| 0xA517, 0xA619, 0xA90F ADVANCE | not offered: the figure stands at distance 0 when the menu comes (the menus show PARLAY) |
| 0xA535, 0xA65A, 0xA947 → 2 | FLEE succeeding at the lizard men's menus: a party faster than they are |

## 4:21, Sokal Keep: done

93% of instructions and 89% of reachable branch outcomes; every story-critical instruction has run (4 ways in or
out, 4 set fights, 9 quest flags). The chat 16 rules worked out seven more outcomes as dead: the stable's, the
fungus room's and the smithy's "if the visit flag is over 1, reset it" (nothing writes more than 1), the
elf's skeleton tested for 255 (0x4A25: no script writes it).

| where | what it needs |
|---|---|
| 0x99D7 → T, 0x99E6 → 18, 19 | events 18 and 19, or a number above 20: no square of map 21 has them (it has 1-17 and 20) |
| 0x9A90 → T | the boat's arrival script with 0x4A02 already set: a game saved on the landing and loaded |
| 0x9AD9 → F | 0x6DD3 (the rest interruption chance) unequal to 0x49FF after the boat; no script writes 0x49FF (engine state, not yet identified) |
| 0x9D92 → T | the patrol counter (0x4A03) over 5: it stops at 4 (no patrol comes from 4 on, and only patrols count it up); a defensive clamp |
| 0x9DC4 → F, 0x9DFC → 0, 1 | a second undead patrol in the same visit after the password was given (0x4A19, cleared on entry; the patrol is a roll of RANDOM 5) |
| 0x9E8C → T, 0x9E99 → F | the patrol's PARLAY after Ferran was freed (0x4A26 = 255: then the word is SAMOSUD) |
| 0x9EAD → F | the right word typed at the patrol: before chat 16 the bot typed the first word in the script, SAMOSUD, where SHESTNI was asked |
| 0xA076 → T | the frogs' counter (0x4A0E) over 2: it is reset at 2 and counted only below that; a defensive clamp |
| 0xA726 → T | the empty hall (event 19): no square has it |
| 0xAA00 → T | the pale form's square again after it was laid to rest (0x4A13 = 255) in the same visit |
| 0xAA99 → T | a second IF_EQ on the same COMPARE as 0xAA94, reached only when that one failed: dead |
| 0xAED8 → 3, 5, 6 | the shared fight routine's table entries 3, 5 and 6 (each only ends the event; 0x6E79 counts monster groups up from the caller's start): which callers could reach them is not worked out yet |

## 8:29, Kuto's Well: done

95% of instructions and 86% of reachable branch outcomes; every story-critical instruction has run (8 ways in or
out, 7 set fights, 17 quest flags). The last way in (0x9C6A: the init loading the well's bottom, map 32) came
from chat 16's engine fix: a loaded game keeps its per-visit flags for the init (checked in the original), and
the walks now save and load at each part. Grouped, as the list is long; not every one is worked out yet:

| where | what it needs |
|---|---|
| 0x9991 → T, 0xA098, 0xA129, 0xA150 → T | facing tests on a step (0xC04D): arriving or turning a particular way on squares the walk didn't come at from that side |
| 0xA12E → F, 0xA155 → F | a second IF on the same COMPARE, reached only when the first failed: dead |
| 0x9B6F → F, 0x9B9D, 0xA45B → 3 | the ambush roll: SEARCH off at that square (0x6DCA) and the surprise outcome 3 (both sides surprised) |
| 0x9BB9 → T, 0x9BFE → T, 0x9C1C → T | the rest entry on squares with no event or with the square bits 16 / 1 (0xC04F): rests were taken only at each part's arrival |
| 0x9C06 → T, 0xA090 → T | 0x4A24 = 255, the well's kobold chief dealt with (written in another area) |
| 0x9C31 → T | a rest interrupted at the well's bottom (0x4A10 = 1) |
| 0xA52D → 0, 2, 3; 0xA58E, 0xA5F1, 0xA654 → 2 | the kobolds' menus: they leave, FLEE succeeds (a party faster than kobolds), PARLAY |
| 0xA6F7 ADVANCE | not offered: the sickly kobolds stand at distance 0 when the menu comes |
| 0xAC89 → F, 0xAC94 | a fight that ends neither won nor fled (lost ends the game) |
| 0xAC9C → F, 0xACF5 → T, 0xAD91 → F, 0xAE3F → F | the kobolds' numbers against the party's strength (PARTY_STRENGTH) and the parley roll with charisma (0x6DCF): another party |

## 3:11, the training halls and the arena: done

92% of instructions and 88% of reachable branch outcomes; every story-critical instruction has run (3 ways in or
out, 2 set fights, 1 quest flag). The last way out came in chat 16: the city watch's fight, met from a rest,
fled (0xA094 → the halls' NEW_ECL 0), once menus and fights a rest brings could queue their own jobs.

| where | what it needs |
|---|---|
| 0x9976 → T | an event above 18 while the halls' script is loaded: no such square |
| 0x9A2C → T | the area's init with 0x6DD3 = 255 (written only outside the halls) |
| 0x9C00 → T | the duel asked a second time in the same visit (0x4A01, cleared on entry) |
| 0x9C86 → F | a duelist who is an NPC |
| 0x9CB8 → T | the hire question a second time in the same visit (0x4A08) |
| 0x9CF5 → T | more than seven hirelings hired (0x4A10 counts them) |
| 0x9D3B → T, 0x9D5C → T | the hireling rolls of 170 and 240 or more (RANDOM 250) |
| 0xA09F → F | 0x4A03 clear here: dead in practice, the one call (0xA080) comes right after 0xA07A sets it to 1 |
| 0xA0D3 → F | a party of eight (hirelings) |

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


## What holds the rest back

- **2:9 Stojanow Gate (67 / 65):** the bugbears push the party back from the wall on every approach
  (TAKE THE PUNCH, the plan's answer), and the tower stairs move the party within map 9, so the tower rooms were
  never an arrival. Chat 15's last change (a step into another part of the same map is a new arrival) is in
  the code; 2:9 needs a run with it. The payment routine at 0x9956-0x9B66 needs other purses (coin mixes) and
  members' status.
- **6:1 Buccaneers' base (85 / 86, was 75 / 71):** chat 16 solved both of chat 15's puzzles. The captain's pass
  (item 91) is sold by the seedy man (BUY PASS, then a treasure screen the bot used to leave, as the pass has no
  price); the boy and the merchant (0x9F20, 0xA225) come to a party arriving at the slave pen facing it, which
  our engine never saw (the wall-ahead bug). Left: set fights 14/15, quest flags 5/7.
- **The bands (6:25 69 / 64, 7:26 89 / 78, 8:27 71 / 61):** chat 16's runs replay every choice ("all"); 6:25's
  caves are a map the band loads behind "SMALL DARK CAVE" (a random site), and entering lands next to "LEAVE
  CAVE / STAY IN"; a job that leaves the party in a part no walk has been in is now walked (in the code, not yet
  seen to work). Chat 15's note: every square walked, every way out 100%; set fights 3/13, 1/7, 5/12: the
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

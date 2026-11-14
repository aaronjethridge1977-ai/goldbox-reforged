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

Chat 17 ("Chat 17 additions" in the README) made runs about 6 times faster again (no drawing in lab runs; the
bot's quiet window counted in game time) and resumable after the workspace's restarts, so every area could be
rerun twice with the method below. New in the walks: each event square is also come onto the first time with
SEARCH on; encounter and PARLAY choices are replayed with the dice rerolled; ADVANCE from each distance is a job,
so jobs reach PARLAY; a choice is replayed when the area's flags differ; a job takes one more step its way after
its menu; fights with allies get an "ally attacked" job; areas that read the hour are walked again 12 hours on;
the walk's own flag changes open states; an area that sends every party out is come into again after a flag
change. The report learned the values the game itself writes (0x6DC7, the fight's result, is only ever 0, 0x80 or
0x81 in GAME.OVR), AND-mask tests and COMPARE_AND pairs that never match, and leaves an instruction only a dead
IF reaches out of the critical counts. Variants (logged shortcuts, each a state a player can have): 6:19 pledged
and carrying the silver bottle, 6:1 with the captain's pass, 4:10 with the bottle, 2:9 fleeing the gate's
bugbears, 1:18 with the plaza's count at 9, 3:8 with the reports City Hall answers. One engine difference came
out and was fixed after a check in the original: ATTACK ALLY: YES NO.

## Where each area stands (chat 17, all runs merged)

Played percentages; chat 16's in brackets. Critical = ways in/out · set fights · quest flags. **Done** = meets the
numbers and the critical count, every remaining path listed below with its reason.

| area | instructions | branches | critical | |
|---|---|---|---|---|
| 5:4 Valjevo, north side | 98 (96) | 94 (91) | 7/7 · 6/6 · 24/24 | done |
| 6:28 Zhentil outpost | 97 (97) | 97 (97) | 5/5 · 9/9 · 5/5 | done |
| 7:22 Yarash's pyramid, outside | 96 (92) | 95 (91) | 4/4 · 1/1 · 10/10 | done |
| 2:15 Mendor's library | 96 (93) | 90 (85) | 3/3 · 7/7 · 25/25 | done |
| 8:16 ruined castle | 96 (96) | 88 (88) | 4/4 · 7/7 · 18/18 | done |
| 6:1 Buccaneers' base | 95 (85) | 94 (86) | 3/3 · 15/15 · 6/7 |  |
| 5:5 Valjevo inner castle | 95 (95) | 91 (91) | 7/7 · 7/7 · 15/15 | done |
| 1:24 Temple of Bane quarter | 95 (94) | 89 (88) | 5/5 · 11/11 · 15/15 | done |
| 8:29 Kuto's Well | 95 (95) | 86 (86) | 8/8 · 7/7 · 17/17 | done |
| 4:21 Sokal Keep | 94 (94) | 92 (92) | 4/4 · 4/4 · 9/9 | done |
| 6:19 Diogenes's cave mouth | 93 (80) | 100 (85) | 2/2 · 0/0 · 3/3 | done |
| 3:11 training halls, arena | 93 (92) | 89 (88) | 3/3 · 2/2 · 1/1 | done |
| 4:2 Cadorna textile house | 93 (86) | 89 (84) | 5/5 · 11/12 · 16/17 |  |
| 3:14 Kovel Mansion | 92 (87) | 88 (82) | 5/5 · 14/14 · 21/21 | done |
| 7:17 nomads' camp | 90 (90) | 87 (86) | 3/3 · 5/6 · 18/20 |  |
| 3:0 New Phlan | 90 (87) | 82 (79) | 12/12 · 8/8 · 9/9 |  |
| 7:23 Yarash's pyramid, inside | 89 (89) | 88 (86) | 4/4 · 3/5 · 18/21 |  |
| 1:18 Podol Plaza | 89 (87) | 85 (81) | 6/6 · 6/7 · 20/24 |  |
| 2:20 Slums | 89 (89) | 78 (78) | 4/4 · 20/20 · 20/21 |  |
| 7:26 wilderness band, middle | 89 (89) | 78 (78) | 18/18 · 5/7 · 6/6 |  |
| 5:6 Valjevo, temple side | 88 (83) | 84 (73) | 3/3 · 6/6 · 21/21 |  |
| 5:7 Valjevo tower | 88 (88) | 84 (83) | 4/4 · 5/5 · 13/15 |  |
| 4:10 Valhingen graveyard | 88 (88) | 79 (78) | 2/2 · 16/18 · 39/48 |  |
| 8:13 kobold caves | 86 (86) | 85 (84) | 3/3 · 14/15 · 17/19 |  |
| 5:3 Valjevo outer castle | 85 (81) | 81 (77) | 7/7 · 10/11 · 23/23 |  |
| 3:8 City Hall | 84 (81) | 84 (82) | 2/2 · 3/3 · 28/34 |  |
| 8:27 wilderness band, east | 84 (71) | 73 (61) | 10/10 · 8/12 · 6/6 |  |
| 6:25 wilderness band, west | 76 (69) | 71 (64) | 11/11 · 6/13 · 5/5 |  |
| 2:9 Stojanow Gate | 69 (69) | 70 (70) | 3/4 · 3/7 · 17/24 |  |

Overall, all runs merged: played 87% → **90%** of instructions and 82% → **85%** of reachable branches; with the
choices not taken tried in the shadow copy as well, 91% and 86%.

**Done:** 6:28, 5:4, 8:16, 5:5, 8:29, 4:21, 3:11, and in chat 17 1:24, 2:15, 6:19, 7:22, 3:14 (12 of 29).

## 1:24, the Temple of Bane quarter: done (chat 17)

95% of instructions and 89% of reachable branch outcomes; every story-critical instruction has run (5 ways in or
out, 11 set fights, 15 quest flags). Chat 17's `-all` run, resumed across a restart, took the last way out. The
last quest flag, 0xB092 (0x4A2A = 1 after the encounter routine's fight), needs the fight's result 0x6DC7 to be 1,
and the original never writes 1 there (GAME.OVR: 0, 0x80, 0x81 only), so the report now counts it as dead.

| where | what it needs |
|---|---|
| 0x9A10 → T, 0x9A17 → F, 0x9A21 → F | the encounter routine entered with 0x4A2A already 1 and the party carrying item 74 or not: one visit's order |
| 0x9B4D → 0, 2; 0x9B5C → 0; 0xA77B → 0, 4, 5, 6 | the table rolls that pick which group of the temple's guards comes (RANDOM, then AND): not all came up |
| 0x9E86 → T, 0xA25D → T, 0xAC54 → F, 0xB56F → T | other rolls (a search find, the parley sum against the party's size) |
| 0xAA5E → T | 0x4A2D with bits 1-3 set and 0x4ABD clear (0x4ABD = 254, written in another area) |
| 0xAC63 → T | a member whose 0x6BB8 (control) is under 128 at that check: an NPC-only party |
| 0xADAD → 3, 0xAF95 / 0xAFA7 | the surprise roll 3 (both sides surprised) and its four reactions |
| 0xAE14 → 2, 0xAEE6 → 0, 0xB025 → 1-3, 0xAFE7 | the encounter routine's menus when both sides are surprised (0xAFE7 only then) |
| 0xAEFE → T, 0xAF90 → T | the same routine with 0x4A0E = 1 (the alarm): reached only in fights a job met with the alarm off |
| 0xB64C → T | 0x4AA8 below 254 at the temple's end: the run's checkpoint has it at 254 |

## 4:2, the Cadorna textile house: done (chat 18)

95% of instructions and 91% of reachable branch outcomes; every story-critical instruction has run (5 ways in or
out, 12 set fights, 17 quest flags). The last fight and flag (0xAF05, 0xAF0C: Restal's offer to duplicate the seal)
came from chat 18's WHO jobs: Restal is met only by a member who survives the climb down the thieves' well
(RANDOM 99 against the climber's climb-walls skill, 0x6BAB), and the bot had always sent the first member. The
`-seal` variant (City Hall's commission 0x4A97 = 255, the sealed chest taken 0x4AC8 = 1) then gets the offer.

| where | what it needs |
|---|---|
| 0x996D → 2 | leaving the map facing south (0x6DD5): no run left that way (not checked whether the south edge is open) |
| 0x99B6 → 9, 10, 11 | the search table's events 9-11: no square of map 2 has them (their entries are EXIT) |
| 0x9A63 → T | the house's counter 0x4AE4 at 9 with 0x4A75 clear when that check runs |
| 0xA535 → F | a party of eight: no room for Skullcrusher |
| 0xAAD7 → T, 0xAC85 → F | a member who is not well (0x6C00 not 1): Skullcrusher hurt, or an unwell climber picked |
| 0xAD05 → T, 0xAD3C | a falling climber carrying item 27 (feather falling: "YOU FLOAT DOWN THE WELL") |
| 0xAA17 → T | FLEE succeeding at the hobgoblins' menu (outcome 2): a party faster than they are |
| 0xAA8F → F | the shared hobgoblin fight with a caller code (0x6E82) other than 2, 5 or 8: not worked out |
| 0xAE61 → T | City Hall's commission not given (0x4A97, written in 3:8): the main line's checkpoint has it |
| 0xAE77 → T | 0x4AB8 = 255, written only outside this area |
| 0xAE82 → T | Restal's room a second time in the same visit (0x4A17, cleared on entry) |

## 2:15, Mendor's library: done (chat 17)

96% of instructions and 90% of reachable branch outcomes; every story-critical instruction has run (3 ways in or
out, 7 set fights, 25 quest flags). The last flag (0xAE6E: the kobolds who plead for mercy tell what they know)
came from chat 17's ADVANCE chain: ADVANCE from distance 2 and 1 are jobs of their own, so a job reaches distance 0
and PARLAY.

| where | what it needs |
|---|---|
| 0x9AC1 → T, 0xA3E7 → 3 | the surprise rolls 2 and 3 (the party surprised; both sides) |
| 0x9E26 → 3 | the random book table's fourth entry (a roll) |
| 0xA003, 0xA0B4, 0xA10E, 0xA281, 0xA320, 0xA3B2 → F | the books' flags 0x4AAA-0x4AAF at 255 (the book handed in, written in New Phlan's City Hall): another moment of the story |
| 0xA0C2 → T | the books-found counter 0x4A30 at 5 or more |
| 0xA439 ADVANCE, 0xA469 → 0, 3 | the snake's menu: it comes at the distance in 0x6DC0 (0 here: PARLAY shown), and outcomes 0 and 3 (it leaves; PARLAY) are rolls |
| 0xA921 → T | a party of eight |
| 0xABA6 → F | the illuminators' carrels with their table byte clear: the step script sets it on the way in (not worked out) |
| 0xAD7F → 0, 2 | the kobolds' menu: they leave, or FLEE succeeds (a party faster than kobolds) |

## 6:19, Diogenes's cave mouth: done (chat 17)

93% of instructions and every reachable branch outcome; every story-critical instruction has run (2 ways in or
out, 3 quest flags). It took a variant (`cover_6-19-bottle.plan`): the party pledged to Diogenes (0x4A87 bit 0, by
shortcut, as a player who chose PLEDGE has it) and carrying the kobolds' silver bottle (item 82, by the new
`shortcut item`). His thanks set 0x4A87 bit 1 and send the party out; chat 17's rule for areas that send every
party out comes in again by the same way, and finds the cave empty (0x996E, the second way out). The report now
works out 0x9927 → F as dead (0x4A87 AND 128 compared with 1). The instructions not run are the dead side's.

## 7:22, Yarash's pyramid, outside: done (chat 17)

96% of instructions and 95% of reachable branch outcomes; every story-critical instruction has run (4 ways in or
out, 1 set fight, 10 quest flags). The rocks room (event 14) needed two chat 17 rules: a party that doesn't search
the first time it comes is flashed away to 7:23 and the square is done after that, so each event square is now
also come onto the first time with SEARCH on ("A STRANGE TINGLE", then GO BACK / MOVE ON / THROW A ROCK); and a
choice is played again when the area's flags differ, so a second THROW A ROCK toggles 0x4A4D bit 0 back (0xA139).

| where | what it needs |
|---|---|
| 0x9CB4 → T | 0x4A4B bit 7 set (written only by another area's script) |
| 0x9D47 → 0 | the priest's menu (distance in 0x6DC0, 1) giving outcome 0: a reaction no choice gave in the runs' rolls |
| 0xA1F9 → 3 | both sides surprised (a SURPRISE roll of 3) |
| 0xA342 → 0 | the flying monsters' menu with its own variable 0x6E7B as the distance: outcome 0 needs their roll to come out 0 |
| 0xA35A → T | that encounter's ADVANCE side met on a row under 8 (the encounter comes on rows 8 and up in the runs) |

## 3:14, Kovel Mansion: done (chat 17)

92% of instructions and 88% of reachable branch outcomes; every story-critical instruction has run (5 ways in or
out, 14 set fights, 21 quest flags). Chat 17's two rounds of every-choice runs (rerolled encounter jobs, walk
states, the 12-hour walk) did it. Not every one of these is worked out:

| where | what it needs |
|---|---|
| 0x993C → 3 | the facing table's fourth case (arriving facing west on that square) |
| 0x99FA → F, 0x9A2C → T; 0x9A05, 0x9DD3, 0x9DDE, 0x9DE9 | 0x4A06 set, and 0x4AEA-0x4AEC at 1: written only outside this area; the code behind them is unreached |
| 0x9B53 → T, 0xAAC8 → T, 0xAAD3 → F | the mansion's alarm count 0x4A45 at 21 or more (with the roll added) |
| 0x9CC3 → T | a room's visit byte (0x4A08 + room) at 1 when that check runs |
| 0x9ED9 → T | a member with spell 31 (0x6E7D not 255 after the SPELL check): another party |
| 0xA36B → T | 0x4AED = 1 (written only outside this area) |
| 0xA534 → T, 0xA639 → T | bits 1 and 2 of 0x4A46 already set at those rooms |
| 0xA53D, 0xA642, 0xA729 → 2; 0xA80B → 1, 2 | the visit state 0x4A13 at 1 or 2 when those rooms are entered (the order the walk took them) |
| 0xAB49 → T, 0xAB58 → F | the treasure room's counter and roll |
| 0xB3CB → T | a PARTY_CHECK that comes out nonzero: another party |

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


## What holds the rest back (chat 17)

- **2:9 Stojanow Gate (69 / 70):** the gate's bugbears ask THROW DOWN YOUR WEAPONS until the party fights (FLEE
  only brings the question back); the fight raises the alarm, the towers' defenders come out and are marked dealt
  with (0x4A77 |= 12, 0xA60E), so the tower rooms (the mage, the fighter: 0xA1D8, 0xA2F9) are always empty after.
  Finding them manned needs a party that pays its way past the gate (the payment routine 0x9956-0x9B66, other
  purses); `cover_2-9-fresh` is still to run with chat 17's code.
- **The bands (6:25 76 / 71, 7:26 89 / 78, 8:27 84 / 73):** the caves and most sites are random rolls (about one
  step in 20 rolls an encounter, 0xA0B3), so each run meets different ones; runs are merged. The caves'
  map (GEO6 block 25) was checked in the original: the entrance at 15,3 is a dead end facing out there too, and
  from 0,9 the party walks north, as in ours. The walks had stopped at the entrance because the four searches
  in a row asked the passage question four times and the repeated-question rule answered LEAVE CAVE (fixed).
- **3:8 City Hall (84 / 84, quest flags 28/34):** the clerk's and the council's answers follow reports set in
  other areas (Podol Plaza cleared 0x4AE7 = 254, the textile house 0x4AE6 = 254, Cadorna's seal 0x4AC8 = 128, the
  Bivant rescue 0x4AA9 = 128). The `-story` variant sets them as those areas' scripts do and rests until morning
  (City Hall locks at 14:00, 3:0's 0x9920); it raised the flags from 23 to 28.
- **1:18 Podol Plaza (89 / 85):** the plaza's count 0x4A34 reaches 9 only after many fights (0xB248 then tells
  City Hall); the robed orc's meeting (0xB0BE) waits for an hour. The `-count` variant and the 12-hour walk.
- **4:10 Valhingen graveyard (88 / 79):** the paladin's wraith (0xA28C) comes only while 0x4AF4 is 9 or less, and
  the walk's earlier fights count it past that; the `-fresh` variant walks to each event from the arrival. The
  "over 249, set 249" writes (0xA616, 0xA814, 0xAB31, 0xB29C, 0xB2B2, 0xB2C8) are clamps on kill counters.
- **6:1 (95 / 94):** the last flag, 0x993D (0x4AA9 = 254), is written when the party leaves the map
  (0x6DD5) after buying the boy (0x4AA9 = 1).
- **7:17 (90 / 87):** the kobold war's third stage (0xB121, the headman's DESTROY THE KOBOLDS) comes after two
  fights in a row at the same square; walk states (chat 17) should reach it.

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

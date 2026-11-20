# Gold Box playbook

Started by Player 28 (2026-11-19, the Lead's note from Jeremy) from the Player lane's READMEs (Players 1-28, `tools/original_player/README.md`) and the Stojanow report. One line a tactic; add a line when a run shows one, with its run and tag.

General tactics for the Gold Box engine, learnt by the Player lane playing DOS Pool of Radiance in DOSBox. Each line
gives the source and a tag: *seen in the original* (seen in DOSBox runs) or *read in the code* (GAME.OVR, START.EXE or
ECL disassembly). Pool-specific routes are in `docs/strategy/poolrad.md`.

## Party and preparation

- Fill every spell level before a hard fight, not just level 1. Until Player 27 the tool memorized only level-1 spells, so its casters fought from Sokal Keep onwards with level-2 and level-3 slots empty (Player 27, Stojanow REPORT; *seen in the original*).
- Camp and memorize before each event. Without it the party reached a 30-figure fight with its Sleep spells used up and lost (Player 15, p15c1/p15c2; *seen in the original*).
- Keep one Slow Poison in the party, in the first free cleric level-2 slot (Player 27, main's bot's picks; *read in the code*).
- Train as soon as a member qualifies. At TRAIN the game cuts experience to "the level after next, less 1", so experience above that is lost (Player 3; *seen in the original*).
- A multi-class member trains the hall's class when that class is ready, even if a slower class is not (Player 3; *seen in the original*).
- The training fee comes out of the member's gold coins, and change is given in gold, not platinum (Player 3; *seen in the original*).
- Sell gems and jewellery (APPRAISE, then SELL; a shop's APPRAISE also offers KEEP, which takes a jewel off the coin count: main chat 66), then POOL and SHARE so that each trainee has the fee (Player 15, main chat 66; *seen in the original*).
- To sell an item, unready it first: SELL (under VIEW, ITEMS in a shop) does nothing to a readied item, with no message. The price comes in the largest coins (7 gp paid as 1 platinum and 2 gold) (main chat 65, check 101; *seen in the original*).
- The party fell behind main's bot in levels. One possible cause is a trainee without 1000 gold of their own (Player 21; unconfirmed, *seen in the original*).
- Town shops, City Hall and the training halls lock from hour 14. Rest at the inn until midnight first (Player 15, p15d1; *seen in the original*).
- Hit points gained at training come from the game's dice: one roll of the hit die, split across classes, plus the CON bonus (Player 3; *read in the code*).
- A magic-user's new-spell page opens on the last spell in the list, not the first. Check which spell is lit before LEARN (Player 3; *seen in the original*).
- Camp CAST's spell list also opens on the last spell; End wraps to the first. Check which spell is lit before CAST (main chat 65, check 102; *seen in the original*).

## Spells

- QUICK members cast spells only with MAGIC ON. Press Alt-M in every fight, because the game turns it off at each fight's start (Player 15; *read in the code*, GAME.OVR 0xE457, and *seen in the original*).
- Hold Person does not affect large creatures. QUICK casters still aimed it at ettins and wasted it (Player 27, p27a1; *seen in the original*).
- Sleep does not affect monsters with many hit dice (ettins) or a level-6 magic-user. At the Stojanow Gate it only worked on the level-3 aides (Stojanow REPORT; *seen in the original*).
- QUICK casters often swing instead of casting. They never cast Prayer or Stinking Cloud in three tries, and clerics kept Bless unused. For key spells, cast by hand (Stojanow REPORT; *seen in the original*; casting by hand untried).
- Enemy magic-users' Magic Missile never misses and finishes hurt members. Kill the mages first, for example with Hold Person on them (they are persons) (Stojanow REPORT; *seen in the original*; the advice is untried).
- Inside an anti-magic shell, CAST in camp does nothing. Heal by resting there; it took 54 days to bring a member up from 0 HP (Player 25, 8:16; *seen in the original*).
- With nobody knowing Knock, try PICK and then BASH. After a failed PICK and BASH, a door offers only KNOCK on later bumps (Player 17, Player 21; *seen in the original*).
- A creature's spell can cover itself. The game rolls magic resistance for each target after its save (Player 6; *read in the code*, GAME.OVR 0x115BF).
- Prayer works only near its caster. It goes on the caster alone; party members within 6 squares in sight get +1 to hit and on saves, and enemies within the same 6 squares get -1. Cast it from the middle of the line, not from the back (Combat Chat 31; *read in the code*, GAME.OVR 0x2B04A, and matched draw for draw in the original's finale guards fight, p29d1).

## In combat

- Death rule: a win with a member dead counts as a loss, so reload. Several "wins" in the original were losses by this rule (Players 7, 8, 13; *seen in the original*).
- 0 HP with status 4 (UNCONSCIOUS) is not a death; status 6 (DEAD) is (Player 8, correction to Player 7; *seen in the original*).
- Reload with another seed. The same seed and the same keys can replay the same dice and the same loss (Player 14, p14b3/p14b4; *seen in the original*).
- QUICK fighters guard when no enemy is in reach, so the first round can be lost while monsters close in (Stojanow REPORT; *seen in the original*).
- Monster morale 255 means the monsters never run (Stojanow REPORT, MON2CHA.DAX; *read in the code*).
- Monster hit points can be fixed, the record's own value with no roll, so every try faces the same total (Stojanow REPORT; *seen in the original*).
- A fallen NPC (DIRTEN) is dropped after the fight and his items go into the treasure, where the party can take them back (Player 11; *seen in the original*).
- Tyranthraxus's fear affects every enemy: levels 0-3 are paralysed and levels 4-5 weakened, whether they save or not (Player 5; *read in the code*, GAME.OVR 0x10705).
- Spectres and wights drain levels and can leave a member "DEAD FOREVER". Two of c32a's losses were this (Player 7, Player 22; *seen in the original*).
- A mummy's disease stops all healing until CURE DISEASE at a temple. It killed a member during day rests (Player 25; *seen in the original*).
- Only a readied mirror turns a basilisk's gaze back, and it needs a free hand. READY refused it to members whose hands were full (Player 17; *read in the code*, GAME.OVR 0x10908, and *seen in the original*).

## Resting and camping

- The game rolls d100 against the area's chance every 5 minutes of rest (Player 3; *read in the code*, GAME.OVR 0x24BC9).
- While an alarm holds (Valjevo), patrols interrupt camps and wander at 17% a step. Camps there were interrupted three times and wiped the party. Use memorized cures and rest at the inn (Player 3, Player 27; *seen in the original*).
- In some places the only safe rest is the inn: Sokal Keep's 15,1, 4:2, the pyramid's 7:22, the wilderness bands. Camps there were interrupted 4-5 times and members died (Players 15, 19, 25; *seen in the original*).
- When a rest is interrupted, go to the inn instead of camping again (Player 14, p14b3; *seen in the original*).
- Rest time to memorize is 4 hours plus 15 minutes for each spell of the member with the most to learn (Player 15; *seen in the original*).
- A second visit to New Phlan's inn does nothing until the party steps off its square and back (Player 12; *read in the code*, ECL 0x4A07).
- In a script's camp (the nomads), each rest can bring the next wave (Player 20; *read in the code*).

## Encounters and parley

- FLEE at "THEY RUSH TOWARD YOU" does not avoid the fight. Five FLEEs out of five went straight into it (Player 26, Stojanow REPORT; *seen in the original*).
- A reaction roll can give COMBAT WAIT FLEE ADVANCE where a friendlier roll gives PARLAY, so the same encounter can come with or without a parley (Player 24, Player 7; *seen in the original*).
- A menu whose default is COMBAT can kill a friendly NPC (the trader). Choose PARLAY to deal with him (Player 26, p26b5; *seen in the original*).
- Against a ransom demand, SURRENDER loses coins and items but keeps the rescue. ATTACK, if won, captures the fort (Player 25, ECL 6:1; *read in the code*).
- For traps, AVOID TRAP keeps the party safe but leaves the loot. AVOID followed by EXAMINE rolls the trap again; once it went off (Player 22; *seen in the original*).
- To find a trap, the game rolls RANDOM 99 against the party's best value, not the average (Player 22, ECL 3:14; *read in the code*).
- For locks, PICK once with the best thief, then BREAK or BASH. At a locked door every member rolls a d100 to pick (Player 22, Player 14; *seen in the original*).
- Some fights can be held off by answering LEAVE and taken on later at a higher level (Players 15, 23; *seen in the original*).

## Movement and scripts

- A secret door may not be found by walking into it; a bump just runs the square's script again. LOOK found it at once (Player 16; *seen in the original*).
- On a secret-door square each member rolls to find it, 1 in 5 (2 in 5 for elves and half-elves). SEARCH raises the chance (Player 25, ECL 7:22; *read in the code*).
- SEARCH on also finds trap doors with loot. Each member rolls against the search value (Player 21, ECL 1:24; *read in the code*).
- If a square's script turns the party back, don't keep stepping. Each try rolls the area's encounters, and one party fought on until it was destroyed (Player 14, p13b6; *seen in the original*).
- A question can appear as a vertical menu drawn over the walking menu; it is easy to miss (Player 28; *seen in the original*).
- Some questions are asked only when the party bumps from a square while facing that way, not when it steps onto the square (Player 28, ECL 5:3 on-move; *read in the code*).
- On a wilderness band each arrow moves the party one square without turning; a square it can't enter leaves it where it is (Player 10; *seen in the original*).
- Walking onto a square whose script moves the party ends in another area. Step onto boats and exits deliberately (Players 15, 22; *seen in the original*).

## Shops and gear

- Sell spare gear on every town trip. Sixteen items each gave encumbrance 4085 and MOVEMENT 3 in fights, and loot had to be left behind (Player 27; *seen in the original*).
- A member can hold 16 items at most. A 17th item, or one over the load, is refused with no message (Player 10; *seen in the original*).
- The selected member is the one who takes loot; End and Home change who that is, and the highlight on screen doesn't show it (Player 10; *read in the code*, DS:0x5D92).
- Coins POOLed in a shop stay in the shop. Leaving asks whether to go back for the money (Player 12; *seen in the original*).
- Temple prices are the same at every temple, for example CURE DISEASE 1000, RAISE DEAD 5500, REMOVE CURSE 3500 (Player 3; *seen in the original*).
- NEUTRALIZE POISON is charged even for a member who doesn't need it; CURE DISEASE asks first (Player 25; *seen in the original*).
- The first item list in a shop can open one item down, with the highlight kept from an earlier menu (Player 2; *seen in the original*).

## Added by Player 28

- A step script's vertical menu can be drawn over the walking menu, whose row stays on screen (Valjevo's gate): read the text box, not only the bottom row (Player 28, p27k3's stop screen; *seen in the original*).
- Valjevo's gate (5:3 12,7/12,8) asks for the password on a bump W from the square, not on the step onto it: the on-move script runs before a step, with the square stood on and the new facing (Player 28, p28a1 probe; *seen in the original*, ECL 5:3 0x9A80 *read in the code*).
- While an alarm holds in Valjevo (0x4A64), each step off a "safe" square (info bit 64) may draw a patrol; resting on a bit-64 square draws none (ECL 5:4 0x9AB5, 0x9B32; *read in the code*, not tried).
- Valjevo's barracks giants (5:4 9,1) parley when no alarm holds: HAUGHTY or SLY gives the passwords and no fight (ECL 5:4 0xA38D; *read in the code*, not tried). A won fight there instead stops the four giants of 5,2 (0x4A66 bit 16).
- Reading Valjevo's records (5:4 14,9) during an alarm draws a patrol half the time; answer NO on later visits, as main's bot (Player 28, p28c3; *seen in the original*).

## Added by Player 29

- A fight that follows another with no camp between (Tyranthraxus after his guards' treasure and the vote) is fought with the first fight's damage and without its loot readied: judge the pair together, not the first alone (Player 29, p29b2; *seen in the original*).
- A take loop over a big pile: a member who refuses an item for weight refuses anything heavier, so skip them for those (Player 29, p28j1; *seen in the original*).
- Map squares can carry flag bits that a "walk round every event" route treats as events (Valjevo's 32/64 bits): name the real events to avoid instead (Player 29, p29b1; *read in the code*, GEO5 blocks 3-5).

## Added by Player 30

- Space during a QUICK member's turn hands every QUICK party member back to the player; the menu returns at each one's next turn (Player 30, p30a1; *seen in the original*).
- A spell is begun at CAST and goes off at the caster's later turn, aimed then; a caster hit in between loses it. Hold Person and Prayer begun in melee never went off at the Stojanow wall; cast them before contact (Player 30, p30d1/d3/e1; *seen in the original*).
- Stinking Cloud on bunched ettins makes them helpless, and a helpless ettin dies to one blow: two slain in p30d2. QUICK fighters don't always turn on the helpless ones (Player 30, p30d2/e2; *seen in the original*).
- In a fight's CAST list Home moves the light up and End down; it opens on the last spell, and long lists page with NEXT (Player 30; *seen in the original*).
- A cleric's Hold Person takes three picks; EXIT from a spell's aim asks ABORT SPELL? (Player 30; *seen in the original*).

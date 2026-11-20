# Pool of Radiance strategy

The original's full run as the Player lane played it, segment by segment along main's bot's route (c34d's
checkpoints). Party: ARN (F), BRAM (F), CEDRIC (C), ELWEN (C/F/MU), LIRA (F/MU), DORN (F/T); DIRTEN (NPC) in the
early fights. Levels are given where the README states them. General tactics are in `docs/playbook.md`.

## Route by segment

| Seg | From -> to | Area | What happens | Party level at the end |
|---|---|---|---|---|
| 1 | start -> `shopped` | New Phlan 3:0 | The shop, `readyall`, the inn, memorize. | 1 |
| 2 | `shopped` -> `slums` | Slums 2:20 | The bot's events; heal after each. One stretch on the southern streets (6,14) destroyed one party. An inn trip. | 1 |
| 3 | `slums` -> `slums2` | 2:20, New Phlan | Tour; town trip (sell gems, pool, share, the halls); back to 15,12. | ARN 2, BRAM 2, CEDRIC 2, DORN 1/2 |
| 4 | `slums2` -> `sokal0` | 3:0, Sokal Keep 4:21 | Ohlo (GIVE the potion), the harbor master, the boat from the pier's end. | as above (CEDRIC 2; the bot's 3) |
| 5 | `sokal0` -> `s5b` | Sokal Keep 4:21 | All events except 9, 11 and 12 (left for later). Event 1: TALK, NICE. Pale form: PARLAY. | |
| 6a | `s5b` -> `s6t` | 3:0 | Boat back; the temple of Tyr (HEALING YES, EXIT); inn; clerk; sale; halls. | ARN 3, BRAM 3, CEDRIC 3 |
| 5r | `s6t` -> `sokal` | 4:21 | The deferred event 9, then 7,6 and 7,10 (word `LUX`; TELL). | 3 |
| 6b | `sokal` -> `s6k` (`kuto`) | Kuto's Well 8:29 | CLIMB DOWN NO, NAILED SHUT YES; catacombs (LOOK for the secret door at 5,8 N); Norris the Gray: FIGHT. | ARN 37 HP, BRAM 34, CEDRIC 25 |
| 7 | `kuto` -> `slums3` | 2:20 | Tour; the trolls and ogres at 0,14 (event 20) last. | ARN, BRAM, CEDRIC 3; ELWEN 1/1/1; LIRA 1/1; DORN 1/2 |
| 8 | `slums3` -> `library` | 3:0, Library 2:15 | Training; Brass Mirrors (only LIRA could ready one); 20 library events; the mad man and the basilisk: COMBAT. | ELWEN, LIRA, DORN +1 |
| 9 | `library` -> `podol` | 3:0, Podol 1:18 | City Hall clerk: from 4,5 step **east**, not north. Rewards and Cadorna's Textile commission; Podol: DISGUISE, the auction, the buccaneer duel (ARN). | ARN, BRAM, CEDRIC 4; ELWEN 2/2/1; LIRA 3/1; DORN 3/2 |
| 10 | `podol` -> `textile` | Textile House 4:2 | Five trips by band and boat; the graveyard commission (Two-Handed Sword +1 for BRAM). In 4:2 use cures only and rest at the inn. Chained man: FREE x3, then LEAVE. | |
| 11 | `textile` -> `nomads` | Nomad camp 7:17 | Feast, lodging, `campday 4` (STAY, kobold waves, DESTROY), the shaman's reward; two town trips. | |
| 12 | `nomads` -> `bane` | 1:24 (map 1:31) | Two trips: goblin slaves KILL; hay beds SEARCH. The trap door at 10,9 needs a find roll. | |
| 13 | `bane` -> `library2` | 2:15 | Training (ELWEN, LIRA, DORN to 5000 XP); the library again with `search on` and revisits. Nobody knows Knock: PICK, then BASH. | MUs still low |
| 14 | `library2` -> `kovel` | Kovel Mansion 3:14 | Four trips. Spectre on the way out drains ARN to 2. Traps: AVOID. Locks: PICK once, then BREAK. | ARN 2 |
| 15 | `kovel` -> `band3` | 3:0, band 8:27 | Town trip, then the step east off 15,20. | ARN 3 |
| 16 | `band3` -> `kobold_caves` | Kobold caves 8:13 | Five trips. The throne room (event 9, 4,3) is walked round; events 24, 10 and 20 are behind it. | |
| 17 | `kobold_caves` -> `kobold_king` | 8:13 | **Deferred**: the throne room lost five of five (see below). | ELWEN MU 4 |
| 18 | `kobold_king` -> `band1` | 3:0, band 6:25 | Town; 7:26 2,20, then step W onto 6:25. | |
| 19 | `band1` -> `pyramid1` | band 7:26, pyramid 7:22/7:23 | Round the poisoned river's west side to the rowboat at 6,14; ENTER; the rocks flash into 7:23. | |
| 20 | `pyramid1` -> `s20m` -> `pyramid2` | 7:23, 7:22 | Lizard men at 3,13 (fought); password NOKNOK; fountain MOVE QUICKLY AWAY; the mage at 4,1; dial on BLUE; RECOVER (river clean). | ARN 3, 32 HP |
| 21 | `pyramid2` -> `pyramid3` | 7:22 | MOVE ON at the rocks without throwing; the priest: COMBAT. Use cures only in 7:22. | |
| 22 | `pyramid3` -> `lizard` | 7:23, Ruined castle 8:16 | River reward; anti-magic shell in 8:16 (heal by rests); giant lizards, lizard men. | all trained; ARN 46 HP |
| 23 | `lizard` -> `buccaneers0` | 8:27, 6:25, 6:1 | The clerk opens the Buccaneers' base (Bivant); displacer beasts FLEE. | |
| 24 | `buccaneers0` -> `heir` | Buccaneers' base 6:1 | PUNCH MERCHANT, RELEASE ANIMALS, the pen gate (PICK, BASH), GET HIM. | |
| 25 | `heir` -> `zhentil` | 6:1, 6:25, Zhentil keep 6:28 | The heir's escape (waves; the captain: SURRENDER); Cadorna's packet; envoys YES; the dinner. 6:28: no camp. | |
| 26 | `zhentil` -> `graveyard` | Valhingen Graveyard 4:10 | Urslingen; nine trips; CURE DISEASE at Tyr after the mummies; the tower door (15,6): LEAVE. | ARN drained to 21 HP max |
| 27 | `graveyard` -> `mopup1` | 2:20, 4:2, 7:26, 7:17 | Town (training), mop-up walk, two band fights. | ARN 3, ELWEN 5, LIRA 3/3, DORN 3/4 |
| 28 | `mopup1` -> `stojanow` | Stojanow Gate 2:9 | `restuntil 8`, the trader (PARLAY, the wagon for 250), the toll, 16 bugbears at 7,10; then **the wall fight at 7,6** (see below), taken by `shortcutwin`. | ARN 3, BRAM 5, CEDRIC 6, ELWEN 5/4/4, LIRA 3/3, DORN 3/4 (at `s28b`) |
| 29 | `stojanow` -> `mopup2` | 3:0 | Sell spare gear (50 items); the gate's reward; Urslingen; halls. | ARN 4, ELWEN 5/5/4, LIRA 4/3, DORN 4/4 |
| 30 | `mopup2` -> `valjevo3` | Valjevo Castle 5:3 -> 5:5 | Giants arming at 7,14 (8 hill giants won); training trip; RELEASE the prisoner; at 12,7 facing W bump W: password, GIVE, `RHODIA`. Camps at 12,12 were wiped: use cures only. | ARN 5, BRAM 6, LIRA 4/4, DORN 4/5 (at `s30t`) |
| 31 | `valjevo3` -> `valjevo4` (open) | 3:0, Valjevo 5:4 | Town trip (`s31t`), 5:4 by 5:3 12,0 N (`s31in`): the scribes and officers at 14,12 (won), the records at 14,9 (YES once, a patrol; NO later), KILL THE OVERSEER at 14,5, the armory 14,2 (`s31c`); a town trip (`s31e`); the fire giants at 9,1 lost 11 of 12 (see below). | as `s31t`: ARN 5, BRAM 6, CEDRIC 6, ELWEN 5/5/4, LIRA 4/4, DORN 4/5 |
| 32 | `valjevo4` -> `valjevo5` | Valjevo 5:4 -> 5:5 -> 5:3 | Under the Lead's (a): 9,1 and the west of 5:4 deferred; out by 12,15 S, the gate (bump W, GIVE, `RHODIA`), 5:5 8,0, back to 5:3 13,7 (p28i3). | as `s31e` |
| 33 | `valjevo5` -> `valjevo6` | 3:0, Valjevo 5:6 | Town trip (`s33t`); 5:6 by 2:9 4,0 N: the smithy 0,14 (a smith and three fire giants, won on QUICK; a 40-item pile), the laundry 12,13 (NICE, the disguise YES, TIE), Bane's temple 1,2 (LEAVE: the fight, won), the altar 1,0 (NO, NO) (p29a2). | ARN 5, BRAM 6, CEDRIC 6, ELWEN 5/5/4, LIRA 4/4, DORN 4/5 |
| 34 | `valjevo6` -> `valjevo7` (**the end**) | 3:0, 5:5, Valjevo Castle 5:7 | Town trip (`s34t`); 5:3 by 5:6 15,12 E, the gate into 5:5 11,7; 5:5's maps 5 -> 4 -> 3 (4,0 N, 0,11 W, 15,10 11,10 11,14 12,14 12,15; walks need explicit `avoid` lists: the 32/64 bits count as events), the stairs E from 13,15 to 5:7 5,7 (GO DOWN: NO), LOOK (the secret door N), 5,6 N up (YES), 4,4 4,5 4,6 3,6, S down (YES): the hall at 3,8. The guards and Tyranthraxus by logged shortcut (see below); 0x4ABA = 254, the party at 3:0 0,4 (p29f2). | ARN 5, BRAM 6, CEDRIC 6, ELWEN 5/5/5, LIRA 4/4, DORN 4/5 |

## Hard fights

- **Stojanow Gate, 2:9 7,6** ("A GROUP OF MONSTERS IS WAITING ON THE OTHER SIDE OF THE WALL", ECL 0xB081). Six ettins (10 HD, 50 HP each, AC 3, THAC0 10, two attacks 2d8 and 3d6, move 12), two level-6 MUs (23 HP, Magic Missile 3d4+3 that never misses, Mirror Image) and two fighter-3 aides (18 HP). 382 HP in total against the party's ~205 at levels 3-6.
  - Player 26: 6 of 6 lost (p26d2 with COMBAT; p26e1-e5 with FLEE, which still starts the fight).
  - Player 27: 3 of 3 lost with every slot filled (`s28p`). QUICK threw Hold Person at the ettins and Sleep at the ettins, and never cast Prayer or Stinking Cloud.
  - Nine tries, nine wipes. The best damage was 70 of 382, and the party lasted 4-6 rounds.
  - The whole party moved only 3 (16 items each).
  - Main's bot (7 members, ARN 6) also lost twice in ours. The bot's table expects level 7 here.
  - Earlier parties from c27a, c32a and c34d were destroyed there too (Players 3, 7, 9).
  - Player 31, the Lead's advice by hand (fighters AIM the helpless first, else GUARD; casters as Player 30): 5 more lost
    (p31b2-b6), best 122 of 382 HP. One ettin starts next to the party (p31a1: at 27,10 beside BRAM at 28,11), so
    there is no "cast before contact" here; the casters stand in the line and lose their begun Stinking Clouds
    to hits; the party lasts about three rounds. More levels first (*seen in the original*).
  - The gate was passed by `shortcutwin` (Player 27, p27c2).
  - The report suggests (untried): more levels first; cast by hand (Stinking Cloud while the ettins are bunched, Prayer and Bless before contact, Hold Person on the mages); sell gear; position the line.
  - Player 30, the tactical mode (casts by hand, fighters on QUICK): 8 of 8 lost (p30a3-p30e3, from `s28p` and from `s28b` with three Stinking Clouds memorized). Best p30d2: 139 of 382 HP dealt, two ettins slain while helpless in a Stinking Cloud. Hold Person and Prayer begun in melee never went off (*seen in the original*).
- **Sokal Keep event 9, 4:21 7,4** ("A LARGE FORCE OF ORCS AND HOBGOBLINS", 56 figures).
  - Level 2: 10 tries, 8 wipes and 2 wins, each with a member dead (Player 15). The early tries ran with MAGIC OFF.
  - Deferred to level 3. Player 15: 6 tries, 1 win with nobody dead. Player 16: p16a1 lost a member, p16a2 won deathless. At level 3 in all: 8 tries, 2 deathless wins.
  - The fights were also short of level-2 spells (the `prepare` gap; Player 27).
  - In ours, c34d's bot won it with its own `smartquick` and CEDRIC at level 3.
  - Events 11 and 12 can only be reached across event 9's squares.
- **Sokal Keep rest fights, 4:21 15,1**: four interruptions in five rests (undead), and four camps ended with a death (Player 15). The plan dropped the camp.
- **Sokal Keep huge scorpions, 4:21 2,11** [39 x2]: won 4 of 4, 3 with nobody dead (Player 9).
- **Kobold king's throne room, 8:13 4,3 (event 9)**.
  - Three fights in a row with no camp between: the horde (LOAD_MON 31 x4, 0 x35, 1 x11), the ballista (120 x5, 0 x45, 1 x8), then the envoys.
  - Player 23: 5 of 5 lost in the first fight, the horde (56 figures; 16-23 still standing at the wipe). Party at the door: ARN 32, BRAM 52, CEDRIC 30, ELWEN 28, LIRA 22, DORN 29 HP.
  - Player 30: every earlier try reached the door with the casters' spells spent on the way (four fights). A camp at the door draws KOBOLDS APPEAR AND BOMBARD YOU WITH ROCKS (p30g1). From the inn with MAGIC OFF on the way, the casters keep their spells: p30h3 by hand (Sleep and Stinking Cloud picks) still lost, 37 of 56 standing (*seen in the original*).
  - Earlier: destroyed on every seed from c24f (Player 2), c32a (Player 7) and c34d (Player 9). Main's bot wiped there seven times.
  - Deferred with events 20 and 11. The level-2 spell gap applied here too.
  - Retry with the fixed tool (Player 28: spare gear sold, levels 1-3 memorized at the inn: CEDRIC Hold Person x4, Prayer x2,
    Slow Poison; ELWEN Hold Person x4, Knock; from `s17a` again, `plans/p28_c34d_17r_kobold_retry.plan`): **5 of 5 destroyed**
    in the horde (p28g1, p28h1-h4; 23-31 of 56 figures standing at the last count). The conclusion stands.
  - Player 31, by hand with the Lead's advice (from the inn, MAGIC OFF on the way, every magic-user's level 1 on Sleep,
    fighters AIMing at the helpless first): **5 of 5 lost** (p31c1, c3, c4, c6, c7; best c7, 22 of 56 standing). The
    horde holds four TROLLs (36 HP, untouched by Sleep); Sleep and blows at sleeping kobolds clear 15-35 kobolds, then
    the trolls finish the party. The trip in costs HP too (123-193 of ~197 at the door) (*seen in the original*).
- **Valjevo, 5:4 9,1** [56 x4].
  - Won 2 of 2 from c33b's save, one with nobody dead (Player 8).
  - Player 28 (the original's 6 members, 260 HP; the bot's 7 had 318): four FIRE GIANTS (the bot's log), **1 deathless win in 12**
    (p28e3; 8 losses with deaths, 3 wipes) from `s31e`. With no alarm the giants parley (ECL 5:4 0xA38D: HAUGHTY or SLY gives
    the passwords; untried); a won fight sets 0x4A66 bit 16, which keeps the four giants of 5,2 (event 1) away.
- **Valjevo patrol, 5:4** [75 x1, 55 x5], giants led by a human fighter. It comes on a camp while the alarm holds. Won 3 of 4 seeds (Player 3).
- **Valjevo camps, 5:3 12,12**: p27g4 and p27h1 were wiped by camps interrupted three times. Inside 5:3 use cures only.
- **Finale guards, 5:7 3,8** [85 x12]: party destroyed on every seed (Players 2, 3, 7, 9).
  - Player 29 (the full run's party, 263 HP, levels 4-6, from `s34h` at full HP, levels 1-3 memorized, MAGIC ON): **1 win in 5**
    (p29b2 won and was left with 5 standing, 141 HP; p29d1-d4 destroyed in under a minute). The 12 guards (8th-level
    fighters, 75-87 HP) carry 12 Rings of Protection +3, Plate Mail +2 and Two-Handed Swords +2, but the vote and Tyranthraxus
    come straight after the treasure: there is no camp to ready them. Main's bot lost it twice and took it by shortcut.
- **Tyranthraxus alone, 5:7** [66 x1].
  - From c27a: won 2 of 2 (Player 3).
  - From c32a: won 2 of 4, every win with deaths (Player 7), which is a loss by the death rule.
  - His fear paralyses or weakens low-level members; he breathes electricity (80 damage to ELWEN in ours).
  - Player 29 (after the guards by shortcut, the party at full 263 HP, all ATTACK votes): **0 of 7** (p29b2 after the won guards, p29f1 (the re-arm missed),
    p29e1-e5: destroyed in about 18 s each). Taken by `shortcutwin 5:7 3,8 2` (p29f2): the game won by shortcut. Main's bot
    (7 members, levels 6-7) beat him for real with one death.
- **4:2 3,11** [28 x1, 7 x3, 6 x12] (GRISHNAK). Won 3 of 4, every win with deaths; lost seed 0badf00d (Player 8).
- **Slums 2:20 0,14** [8 x2, 31 x4]. From c33b: won 2 of 2, both with deaths (Player 8). Trolls and ogres (event 20) in segment 7: won with nobody dead (p16e2, the second try).
- **2:20 southern streets, 6,14**: a 20-figure encounter destroyed p14b3 and p14b4 at level 1; p14b5 lost ELWEN. A 25-figure fight there killed a member (p15c3).
- **Slums event 9, 2:20 3,3** (30 figures): lost twice without `prepare` (Player 15).
- **Stojanow 2:9 7,6 from earlier saves** (the two magic-users and ettins, [24 x2, 53 x2, 71 x6]): destroyed on every seed (Players 3, 7, 9). It is the same fight as the gate above.
- **Spectres, 4:10 9,1** [17 x2]. Won 4 of 4, two with nobody dead (Player 7, corrected by Player 8). Drained members count as dead.
- **Norris the Gray, Kuto's catacombs**: p16c1 met him early (LIRA dead); p16c3 lost three; p16d1 won deathless from `s6pre12` at the first try.
- **The mage and his guards, 7:23 4,1** (13 figures): p24b5 destroyed, p24b6 won (ARN 3/32 HP).
- **Pyramid room fights, 7:22**: p25c5 destroyed at 12,15 (rests interrupted after the fight); p25d2 destroyed at 11,13 (three fighters, COMBAT).
- **Wilderness bands**: a 51-figure encounter at 7:26 5,21 (p25a3 destroyed); a band fight at 7:26 12,27 (p25l2 destroyed); 6:25 band fights killed BRAM twice (p25h2, p25j5).
- **Graveyard trip 6, 4:10 9,11** ("YOU SURPRISE A FIGURE AS IT SUMMONS A WIGHT", with mummies): p25l3, p25l4 and p25n1 lost a member. p25m1 won, but the mummies' disease stopped healing. p25o1 won, then bought CURE DISEASE.
- **Podol Plaza goblin hordes, 1:18** and **the run for the gate, 6:1 7,2** [100 x4, 99 x30]: both won in the original (Player 2). Not hard for that party.

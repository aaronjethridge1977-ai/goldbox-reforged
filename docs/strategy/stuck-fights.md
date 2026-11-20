# Stuck fights (Pool of Radiance, the original)

Kept by the Player lane (the Lead's note, Jeremy's decision 2026-11-20 12:44) for Gold Box Guide 2, Jeremy's
stuck-fights chat. One section per fight that has reached five losses in a row under the reload rule. Text only.
**Each fight's logs, plans and the original's saves are copied to `D:\ai_projects\goldbox-reforged\.lab\stuck\<fight>\`**
(`/mnt/d/ai_projects/goldbox-reforged/.lab/stuck/<fight>/`; git-ignored; a README.txt in each names every file):
`sokal9`, `stojanow`, `kobold_king`, `graveyard_spectres`. The Player lab's own copies: `~/gbr/player_lab`, saves
`.lab/player/saves/p2start/<name>/`, logs `logs/<run>.log`.

"Loss" here is the reload rule's: a wipe, or a won fight with a member dead (a death is reloaded, not raised).
The party is always the same six (ARN, BRAM fighters; CEDRIC cleric; ELWEN cleric/fighter/magic-user; LIRA
fighter/magic-user; DORN fighter/thief), driven by the Player's tool (`tools/original_player/`): `tactics on` gives
the casters their orders by hand (Sleep, Hold Person, Stinking Cloud, Prayer, Bless, Magic Missile), the others
attack an adjacent enemy by hand or GUARD; the tool has **no step to move members into a formation** and archers
shoot only what is adjacent.

**Party audit (seen in every save below):** magic gear carried but not readied: ARN's Bracers +4 at `s9door`
(readied later), LIRA's Chain Mail +1 and Cloak +2 (plain Chain Mail readied), spare Ring Mail +1 and Chain Mail
in packs. Worth an audit before each fight here (playbook top: the party audit).

## 1. Sokal Keep, event 9 (4:21 7,4 / 8,5): the army

Files: `D:\ai_projects\goldbox-reforged\.lab\stuck\sokal9\`.

- **Enemy:** 50 figures: 31 orcs, 4 orc leaders, 15 hobgoblins (*code*, poolrad.md section 3); the room 7-8,2-5,
  doors on its south row (7,5 W, 8,5 E) and north row (7,2 W, 8,2 E). The party enters at 8,5 from 9,5 (facing W).
- **Party** (`p34a1_s9door`, Player 34; trained at `s6t`): ARN F3 37 HP AC -1 (Broad Sword +1, Banded Mail, Shield);
  BRAM F3 34 HP AC -1 (Flail +1); CEDRIC C3 25 HP AC -1 (Mace); ELWEN C1/F1/MU1 9 HP AC 0 (Mace); LIRA F1/MU1 9 HP
  AC 1 (Broad Sword +1, Short Bow carried); DORN F1/T2 15 HP AC 4 (Mace +2). Memorized: ELWEN Sleep, LIRA Sleep,
  CEDRIC Hold Person and Bless (plan `picks`), the bot's picks in the rest; Bless cast in camp at 9,5 just before.
- **Tries, Player 34** (plan lab `p34/sokal9.plan`, `OP_TACTICS=horde`; each from `p34a1_s9door`):
  - p34a1 (34010001): a tool stop at 548 s (the tool's 300-key limit) mid-fight, 5 up with 102 HP, 37 enemies left.
    Not counted.
  - p34b1 (34020001): **lost**: down to 6 enemies (29 HP), but BRAM, CEDRIC, LIRA, DORN dead; ARN and ELWEN standing.
  - p34b2 (34020002): **party destroyed** at 762 s (at 604 s 1 up against 32).
  - p34b3 (34020003): **won with CEDRIC dead** (1 enemy left at 5 HP at the last menu; 2 up).
  - p34b4 (34020004): **party destroyed** at 423 s, 45 enemies still up.
  - p34b5 (34020005): **party destroyed** at 390 s, 43 up.
  - Who fell to what: the log keeps no blow-by-blow text; the HP lines show the party losing 40-80 HP in the first
    three rounds before contact, which fits the archers.
- **Earlier:** at level 2, 10 tries, 8 wipes, 2 wins with a death (Player 15, p15f4-f15); at level 3, 8 tries, 2
  deathless wins (Players 15-16; p16a2 won it deathless on QUICK, from the east door too).
- **Read (Player 34):** tactics and tool more than level. The fight's map puts the party in the open at the door
  with enemies on several sides (`logs/p34b5_screen_combat.png`), not a short line with secure flanks; the tool can't
  form a line or hold it (MOVE by hand), and doesn't shoot the orc leaders first. The two level-1 Sleeps took few
  (sleeping figures listed in the enemy count; 1-2 kills by blows each). ELWEN and LIRA at 9 HP fall to two arrows.
- **Suggestions so far:** the cluebook's southern door, a short line, Sleep and Hold Person on the archers and the
  front rank, the archers out of arrows after ~4 rounds (*book*); fighters on Guard at the doorway, leaders shot first
  (*players*, Demetrios1453). Asked of the Lead (board, Player 34): options below.
- **Options (Player 34):** (a) a tool step to form a line at the fight's start (MOVE members by hand into the
  doorway: the fighters in front, the casters behind) and archers aiming at ORC LEADERs, then five more tries;
  (b) the north door (7,2 / 8,2 via room 20) for a different map; (c) leave it at level 3 (p16a2's deathless win
  stands) and come back at level 4. Recommendation: (a), it is the tactic the sources name.

- **Analysis (Gold Box Guide 2, 2026-11-20; plan waiting on Jeremy):** (1) **Hold Person took one figure a cast:**
  `tactics.py` `_aim` takes its first pick and throws the other two away (board request; same in the throne room).
  (2) **The audit:** owed ARN F4, BRAM F4, DORN F2; ARN's Bracers AC 6 not worn (they beat DORN's leather: AC 4 -> 2;
  over Banded Mail they do nothing); a spare Shield in BRAM's pack while LIRA has none; BRAM's MU scroll (Stinking
  Cloud) unread. (3) **The experience:** per class x classes, every member had earned 3,800-4,600 (ELWEN 1383 x 3 =
  4149, LIRA 1916 x 2 = 3832, DORN 2082 x 2 = 4164, the rest 4583): the gap in levels is the multi-class split, not lost
  experience. ELWEN's C2 is 354 away, LIRA's F2 170. (4) Only 2 Sleeps (MU1 each). (5) **Ruled out:** Ferran Martinez
  first would cancel the army (0x4A26 empties the hall), but his rooms are only reachable across the army's squares
  (7-8,4-5; GEO4 block 21). (6) **Jeremy's line rule** (playbook Inbox): GUARD only when no enemy can be reached;
  otherwise the fighters close and form a line of four, or three with the fourth covering the corner.

## 2. Stojanow Gate (2:9): the wall fight (7,6) and the towers

Files: `D:\ai_projects\goldbox-reforged\.lab\stuck\stojanow\`.

- **Enemy (the wall, event 13 at 7,6 / 8,6):** six ettins (50 HP, AC 3, THAC0 10, 2d8 + 3d6), two level-6 magic-users
  (Magic Missile 3d4+3, Mirror Image), two fighter-3 aides: ~382 HP (*code*, poolrad.md). The two tower rooms (stairs
  at 4,5 and 11,5, a step S, GO UPSTAIRS YES) hold the level-6 mage and the 6th-level fighter; they are manned only
  until the gate's bugbears (7,10) are fought, which marks both towers beaten (ECL 2:9 0xA60E; main's coverage notes,
  `tools/plans/cover_2-9-climb.plan`).
- **Earlier tries (all lost):** p26d2 (COMBAT) and p26e1-e5 (FLEE: the fight comes anyway), Player 26 from `s28b`
  (ARN F3 drained, LIRA F3/MU3, DORN F3/T4 drained); p27v1/v2 (videos for Jeremy, `.lab/for-jeremy/stojanow/`); Player
  30's tactical mode 8 of 8 from `s28p` / `s28b` (p30a3-p30e3: best 139 of 382 HP dealt). Taken by `shortcutwin` in the
  first full run (p27c2).
- **Player 34, the redo** (party undrained: ARN F6 65 HP AC -1, BRAM F6 60 AC 0 with the Two-Handed Sword +1/+3,
  CEDRIC C6 42, ELWEN C5/F4/MU4 37, LIRA F5/MU4 39 AC -2, DORN F5/T6 46 AC 4; from `p33f3_mopup1`): the first half to
  `s28p` in one try (p34c1: the wagon, the toll, the bugbears; nobody dead). From `s28p` the walk to the towers crossed
  7,6 and set off the wall on QUICK (p34d1, destroyed in 53 s; a plan error, not counted). The cluebook's way
  (towers first) needs `s28g` (after the toll, before the bugbears): **p34e1, the west tower's room: won, CEDRIC dead**
  (reload). **The west tower's room** (the 5th-level fighter, his aides, three ettins: 188 HP against the party's 289),
from `p34c1_s28g`, seeds 34050001-05, campcast Prayer before the stairs: **5 of 5 lost** under the reload rule:
  - p34e1: won, CEDRIC dead (fell at ~170 s and bled to death while the fight went on: the tool never bandaged).
  - p34e2: won, CEDRIC dead (the same).
  - p34e3: party destroyed at 193 s (2 up with 58 HP against the last aide, then wiped; BANDAGE was on offer).
  - p34e4: party destroyed at 217 s (4 enemies left; LIRA bandaged ARN: the bandage step from here).
  - p34e5: won, CEDRIC dead.
- **Read (Player 34):** the tool, then tactics. Two tool faults found and fixed after these tries: the dying were never
  bandaged (`tactics.py` now DONE, BANDAGE), and ELWEN and CEDRIC began an unreachable Hold Person every turn (the
  refusal was forgotten when another member acted; now skipped for two turns): the two clerics lost most turns.
  CEDRIC (42 HP, AC -1) falls first every time: in reach of an ettin (2d8 + 3d6). The Magic Missiles all went at the
  5th-level fighter. A rerun with the fixed tool is the first thing to try (asked of the Lead).
- **Read:** the wall fight is both towers' ettins at once (the cluebook: "forcing both gates"); beating the tower rooms
  one at a time before the bugbears is the intended way, untried until Player 34.

## 3. The kobold king's throne room (8:13 4,3, event 9)

Files: `D:\ai_projects\goldbox-reforged\.lab\stuck\kobold_king\`.

- **Enemy:** three fights in a row with no camp: the horde (LOAD_MON 31 x4, 0 x35, 1 x11: 50 figures, four of them
  TROLLs, 36 HP, which Sleep doesn't take), then the ballista (120 x5, 0 x45, 1 x8), then the envoys (ECL, Player 23).
- **Party** (`p23a3_s17door`): ARN F3 (drained 1) 32 HP AC -1; BRAM F5 52/54 AC -2 (Flail +1; the Two-Handed Sword +1/+3
  carried, not readied); CEDRIC C5 30/33; ELWEN C4/F3/MU3 28; LIRA F3/MU3 22 AC 1; DORN F3/T4 29/32 AC 4.
- **Tries:** Player 23 p23a3-p23a7 (seeds 23230003-07, QUICK): destroyed every time in the horde fight (16-23 still
  standing). Player 30 p30h1-h3 by hand from the inn (MAGIC OFF on the way): h3 lost (37 of 56 standing). Player 31
  p31c1, c3, c4, c6, c7 by hand (`p31/king3.plan`, Sleep in every MU level-1 slot): 5 of 5 lost, 18-34 of 56 slain;
  the trolls finish the party. A camp at the door draws KOBOLDS ... BOMBARD YOU WITH ROCKS (p30g1). Ours loses the
  same fight draw for draw to 16203 (p23a4).
- **Read (Players 23, 31):** level: the party was at F3-5 with a drained ARN; the four trolls. Asked the Lead (more
  levels first). Every new try is reported on the board (Jeremy).
- **Analysis (Gold Box Guide 2, 2026-11-20 13:12; from ECL8 block 13, MON8CHA, the saves and logs above):**
  - **The enemy:** wave 1: 4 TROLL (36 HP, AC 4, THAC0 13, two attacks, move 12, morale 255), 35 KOBOLD (3 HP, AC 7,
    THAC0 21), 11 KOBOLD LEADER (4 HP, THAC0 19). Then (0xA15C) a ballista volley (DAMAGE) and wave 2: 5 WILD BOAR
    (18 HP, AC 7, move 15), 45 kobolds, 8 leaders. Wave 3 (0xA272): 2 trolls, 2 boars, 8 kobolds, 2 ENVOY (F6/MU6,
    45 HP, AC 2). The king's quarters (7,2) later: 3 trolls, 3 boars, 20 kobolds, 4 leaders. *code*
  - **Hit chances against the party** (ACs at `s17door`): BRAM -2, ARN -1, CEDRIC -1, ELWEN 0, LIRA 1, DORN 4. A troll
    hits 30-45% (DORN 60%); kobolds only on a 20 (DORN 20%, leaders 25%). The trolls do the killing. *code*
  - **Why lost:** (1) the trolls were left standing: at each wipe they had 25-36 HP each (p31c7: 27, 25, 36, 36); the
    blows went to "the weakest" (kobolds). (2) Spells unused: p31c7 cast 2 of its 10 Sleeps, 0 of 4 Stinking Clouds,
    and 6 Hold Persons that "can reach none of its targets" (trolls aren't persons). (3) The audit failed (guide
    section 4): **7 class levels owed at `s17a`** (ARN F4; ELWEN C4, F4, MU4; LIRA F4, MU4; DORN F4; Player 23 trained
    ELWEN's C4; Player 31's training visits didn't raise ARN's, LIRA's or DORN's HP); BRAM's Two-Handed Sword +1 +3 vs
    undead carried, Flail readied; LIRA's cloak (effect 0x59: Cloak of Displacement) unreadied; a magic-user scroll
    (Shocking Grasp, **Stinking Cloud**, Detect Magic) unread in BRAM's pack; arrows readied with no bow; movement 3
    for all six at `s17door` (dozens of junk bows and mail; Player 31 sold junk first, its movement unknown).
    (4) **Princess Fatima never met:** her cell (event 0xA720, a side room west of the throne) offers to join (YES):
    PRINCESS FATIMA, F4, 33 HP, AC 10, move 12. *code*
  - **Players:** one won with two Fireballs (a scroll and a wand), Fatima in the party, entering so only one flank was
    open *players* ([Demetrios1453, ENWorld](https://www.enworld.org/goto/post?id=9305676)); "save at least one
    fireball for each of the first two waves" *players*
    ([GameBanshee](https://gamebanshee.com/poolofradiance/walkthrough/koboldcave.php)). This party has no Fireball
    (scrolls at 3:14 and 4:2: Jeremy, 13:07: try without first).
  - **Not in the plan (Jeremy, 13:07):** SURRENDER after a fled wave keeps the waves won (0x4A8D) and leads to the
    prison and Fatima, at the cost of ROB 1, 25 (coins and each item 25%), everything the second time. *code*
- **Plan 1 (Jeremy approved 2026-11-20 13:10; Gold Box Guide 2):**
  - **Before (the audit):** train every owed level and **check each on the character sheet** before leaving town;
    BRAM readies the Two-Handed Sword (shield off: AC -1); LIRA readies the cloak; the Stinking Cloud scroll to LIRA or
    ELWEN; LIRA, ELWEN and DORN each keep a long bow and arrows readied (DORN is the back rank: AC 4); junk sold and
    coins spent down to **movement 6+ for all**; inn: magic-users' level 1 all Sleep, level 2 all Stinking Cloud;
    CEDRIC Bless, Prayer and cures, no Hold Person. Trip in with MAGIC OFF (Players 30-31); **free Fatima (YES)**
    before the throne and give her a spare Chain Mail and Shield. Save at the door.
  - **Wave 1:** round 1, before anyone is engaged: CEDRIC Bless (it begins casting and goes off on his next turn; a hit
    spoils it); LIRA and ELWEN Stinking Cloud on the trolls, the party outside the 2x2 (about half the trolls fail:
    helpless d4+1 rounds). Fighters (BRAM, ARN, Fatima, ELWEN) on the trolls only, the helpless ones first, three on one,
    and **stand on a fallen troll's square** (*book*: it can't rise). Bows at the trolls. Sleep only on kobold clumps
    that reach the casters, aimed two squares off. Kobolds last.
  - **Waves 2-3:** the remaining Sleeps and Clouds at the boars and the envoys (casters: Stinking Cloud, not Sleep);
    cures between hits on whoever is lowest. A death or wipe: reload (the reload rule).
  - **The tool** (Player): the plan needs melee targets by type (trolls first, the helpless first), bows at range,
    and a step onto a fallen troll's square; where the tool can't, say so on the board.
  - **Results:** (the Player's lines here)

## 4. Valhingen Graveyard: the two spectres (4:10 9,1)

Files: `D:\ai_projects\goldbox-reforged\.lab\stuck\graveyard_spectres\`.

- **Enemy:** two spectres (drain 2 levels a hit; magic weapons only).
- **Party** (`p33c1_s26g7c`, trained): ARN F6 65 AC -1; BRAM F6 60 AC 0, Two-Handed Sword +1 (+3 vs undead) readied;
  CEDRIC C6 42 (Mace +2); ELWEN C5/F4/MU4 37 (Long Sword +1); LIRA F5/MU4 39 AC -2 (Broad Sword +1); DORN F5/T6 46 AC 4
  (Long Sword +1). Camp casts before: CEDRIC's Bless (all six), Prayer, Protection from Evil on BRAM.
- **Tries, Player 33:** p33c1 ARN drained 6->4, BRAM dead; p33c2 ELWEN drained; p33c3 DORN drained (ELWEN turned:
  nothing turned); p33c4 ARN dead, BRAM drained; p33c5 DORN drained. Player 32: 18 tries without BRAM's sword readied.
  The original offered no TURN in p33c1 (the computer had already turned under QUICK, Combat Chat 34).
- **Read:** level and gear: only BRAM's sword is better than +1; every hit drains. Left out by the five-losses rule,
  with 8,2 behind it (the knight's tomb: Potion of Healing, Wand of Lightning Bolt, 2 Restoration). Jeremy has the
  saves (`.lab/for-jeremy/graveyard/`).
- **Analysis and Plan 1 (Gold Box Guide 2, Jeremy agreed 2026-11-20 14:40):** poolrad.md section 3, "Valhingen
  Graveyard". In short: the pair is optional (the knight's tomb only) but **worth taking** (8 Restorations, Plate Mail
  +2, Long Sword +2, Ring of Fire Resistance); not before the audit: at `s26g7c` levels owed (ELWEN F5 and MU5, LIRA
  MU5, DORN T7), everyone at movement 3, ARN's Bracers worn over Banded Mail (no effect: DORN's instead), one
  Restoration left (a 2-level hit needs a whole scroll). Then camp on 10,1 (Haste on the fighters, Prayer, Bless), step
  in, Fireball and bows +1 in round 1, focus one spectre. Simulated: about 2 in 3 fights without a drain, 98% with one
  at most; bring 2+ Restoration scrolls so a hit costs a scroll, not a reload. Leave the vampire's last fight until
  after (his death stops the tomb's event too).
  - **Results:** (the Player's lines here)

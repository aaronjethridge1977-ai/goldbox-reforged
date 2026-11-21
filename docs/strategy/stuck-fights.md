# Stuck fights (Pool of Radiance, the original)

Kept by the Player lane (the Lead's note, Jeremy's decision 2026-11-20 12:44) for Gold Box Guide 2, Jeremy's
stuck-fights chat. One section per fight that has reached five losses in a row under the reload rule. Text only.
**Each fight's logs, plans and the original's saves are copied to `D:\ai_projects\goldbox-reforged\.lab\stuck\<fight>\`**
(`/mnt/d/ai_projects/goldbox-reforged/.lab/stuck/<fight>/`; git-ignored; a README.txt in each names every file):
`sokal9`, `stojanow`, `kobold_king`, `graveyard_spectres`, `finale_guards`. The Player lab's own copies: `~/gbr/player_lab`, saves
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
  (2) **The audit:** owed DORN F2 (ARN and BRAM are 3418 from F4; corrected 15:10); ARN's Bracers AC 6 not worn (they beat DORN's leather: AC 4 -> 2;
  over Banded Mail they do nothing); a spare Shield in BRAM's pack while LIRA has none; BRAM's MU scroll (Stinking
  Cloud) unread. (3) **The experience:** per class x classes, every member had earned 3,800-4,600 (ELWEN 1383 x 3 =
  4149, LIRA 1916 x 2 = 3832, DORN 2082 x 2 = 4164, the rest 4583): the gap in levels is the multi-class split, not lost
  experience. ELWEN's C2 is 354 away, LIRA's F2 170. (4) Only 2 Sleeps (MU1 each). (5) **Ruled out:** Ferran Martinez
  first would cancel the army (0x4A26 empties the hall), but his rooms are only reachable across the army's squares
  (7-8,4-5; GEO4 block 21). (6) **Jeremy's line rule** (playbook Inbox): GUARD only when no enemy can be reached;
  otherwise the fighters close and form a line of four, or three with the fourth covering the corner.
- **Plan 1 (Jeremy approved 2026-11-20 15:01; Gold Box Guide 2):**
  - **Tool first:** the Hold Person fix (all three picks) and the line step (board requests).
  - **A detour, then train:** Kuto's Well (won deathless at level 3, p16d1) and mop-up fights until ELWEN reaches
    C2 (354 to earn) and LIRA F2 (170); then train every owed level (DORN F2, ELWEN C2, LIRA F2),
    each checked on the character sheet. The audit table (playbook section 4) before stepping in.
  - **Gear:** ARN's Bracers AC 6 to DORN (AC 4 -> 2, he stands in the line); BRAM's spare Shield to LIRA; identify
    LIRA's two Short Bows (the Slums' +1s?) and ready a bow for LIRA and ELWEN behind the line; movement 6+ for all.
    BRAM's Stinking Cloud scroll waits for magic-user 3 (a 2nd-level spell).
  - **Spells:** both magic-users Sleep; CEDRIC Hold Person in every 2nd-level slot (3), Bless and cures at 1st;
    Bless cast in camp at 9,5, then step W.
  - **In the fight:** round 1, ARN, BRAM, CEDRIC and DORN close into a short line of four in the doorway (or three
    and one covering the corner; GUARD only when no enemy can be reached); ELWEN and LIRA behind it Sleep the
    thickest clump coming at the line (aimed two squares off); CEDRIC's Hold Person on the orc leaders, then the
    archers in reach. Fighters: the helpless first (one blow), then the leaders. Back rank: bows at leaders and
    archers (the archers run dry after about 4 rounds, *book*).
  - **Stop rule:** 2 losses in the first 3 tries: more levels first, then come back.
  - **The detour's loot (Jeremy, Gold Box Guide 3, 17:09):** at Kuto's Well, the hag's rug (7,14, behind the nailed
    door; a lizardman and 4 giant lizards guard it): **Bracers AC 4 to LIRA** (instead of her chain mail; with BRAM's
    spare Shield), **Banded Mail +1 to DORN** (in place of ARN's Bracers AC 6); the Quarter Staff +1 to a caster.
    Norris: poolrad.md section 3, "Kuto's Well".
  - **Results (Player 35, 2026-11-20; plans `p35/sokal_p1.plan` -> `sokal_v3.plan` in the lab; files to D:
    `.lab/stuck/sokal9/p35/`):**
    - **The audit at the inn** (`p35f1_s9a`, from Player 34's `p15h6_s6t`): ELWEN and LIRA moved 3 (spare Chain Mail;
      LIRA's Chain Mail +1 unworn): now 9 and 12; DORN's Bracers AC 6 (AC 2); ELWEN's Shield +1; LIRA's Short Bow +1 with
      BRAM's 20 Arrows +1. Hold Person x3 picked for CEDRIC's slots.
    - **The detour, first plan** (Player 16's Kuto's Well route: cures only, no rest in the well): p35f1 (35060001) and
      p35f2 (35060002) **party destroyed by Norris's band** at 1,5 and 1,10 (the band comes on the way to 10,3 before the
      plan's rest; at `s6well` / `s6pre12` DORN is unconscious and no spells are left). Read: tool (plan): the old route
      relied on the bot's QUICK; rest in the well first.
    - **Straight to the door** (the Lead's "try at level 3"): p35g1, p35g2 tool stops (the rests at 8,14 and 9,5 drew
      undead five times; the fighters wandered after zombies behind walls: MOVE now only within 8 squares). No army try.
    - **The detour, v2** (rests in the well, cures only at its bottom): **the hag's rug:** after FORCE IT at 7,14, LOOK:
      "BENEATH A RUG YOU FIND A COMPARTMENT CONTAINING ARMS AND ARMOR." YES: Banded Mail +1, Bracers AC 4, Quarter Staff +1
      (p35j6: `s9rug`; walking on without LOOK gives nothing, as Player 16's run). p35j1: five rests at 7,13 interrupted
      (tool stop); p35j2: a MOVE onto a fallen member's square asked ATTACK ALLY (fixed).
    - **v3** (`p35/sokal_v3.plan` from `p2start/p35j6_s9rug`): the rug's gear (Bracers AC 4 to LIRA: AC 0 with her bow;
      Chain Mail +1 to ELWEN: AC -2; Banded Mail +1 to DORN: AC -1; ARN's 18 Arrows to LIRA; `s9gear`), **Norris's band
      won** at 1,10 (p35k1, `s6norris`), the town's halls: **ELWEN C2, LIRA F2, DORN F2** (p35k5, `s9t`; two tool stops on
      the way: CLIMB DOWN answered YES at the well's top, a shop's "CAN I SHOW YOU OUR WARES?").
    - **p35k5 (seed 35090005), Plan 1's first try at the army: WON, nobody dead** (`s9won`, 4:21 8,5; BRAM and CEDRIC
      unconscious at the end, bandaged by DORN and LIRA). Bless from camp at 9,5 (five undead fights during that rest,
      all won), step W; the fighters held the doorway (`advance none`), ELWEN's and LIRA's Sleeps on the thickest clumps,
      blows on the weakest; 50 figures (277 HP) against 142 HP. Read: **the audit, the levels and the rug's armour**
      (the same fight was 5 of 5 lost by Player 34 at movement 3 with ELWEN and LIRA at 9 HP). **Sokal's army: done
      without a shortcut.** Saves `p2start/` of p35k5's `s9t`, `s9door`, and `p35k5/s9won`.

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
- **Analysis (Gold Box Guide 2, 2026-11-20; ECL2 block 9, MON2CHA):** (1) **Each tower room opens with the guards
  unaware** ("THEY SEEM UNAWARE OF YOU"; attacking sets 0x6DCB = 2: the monsters are surprised) and starts an alarm of
  about an hour (0x9BE2). (2) **The wall fight (0xA3FC) comes only while an alarm rings, and only with the towers not
  yet beaten** (0x4A77 bits 4 and 8); winning it marks both beaten (0xA60E). The earlier runs fought the gate's
  bugbears first (alarm, both towers manned), so crossing 7,6 brought both towers' ettins at once. Both towers taken
  separately: the wall is empty. (3) The patrol inside (a 6th-level fighter, 5 hill giants; 0x9E73) parleys: HARASH, or
  TYRANTHRAXUS as the authority, passes. (4) Then the gate's 16 bugbears (0xA79B). (5) **The west tower:** 5TH LVL MU
  (20 HP, AC 9), an aide (F3, 18 HP), 3 ETTIN (50 HP, AC 3, THAC0 10): about 8,200 experience, 1,370 a member, enough
  for LIRA's MU5 (452 to earn at `s28g`). The east: a LEVEL 6 MU (23 HP; Mirror Image, Fireball), an aide, 3 ettins.
  (6) **Why lost:** movement 3 for five of six (the fighters stood on GUARD 10-13 times a try: nobody in reach); no
  Stinking Cloud cast (four memorizable; bunched ettins in a cloud died to single blows, p30d2); CEDRIC in ettin reach;
  the tool faults Player 34 fixed (bandaging; repeated unplaceable Hold Persons). No level owed (corrected count).
- **Plan 1 (Jeremy approved 2026-11-20 15:16; Gold Box Guide 2):**
  1. **The audit at `s28g`:** drop the junk so everyone moves 6+; the Bracers to DORN (AC 4 -> 2); BRAM's spare Shield
     +1 to CEDRIC; LIRA's spare Chain Mail +1 to ELWEN; a bow readied for LIRA; magic-users Stinking Cloud x2 at 2nd
     level, Sleep and Magic Missile at 1st; CEDRIC Hold Person and cures.
  2. **The west tower:** camp at the stairs (Bless, Prayer), GO UPSTAIRS, attack while they're unaware. Surprise round:
     LIRA and ELWEN Stinking Cloud on the bunched ettins (the party outside the 2x2); CEDRIC Hold Person on the
     magic-user and the aide. Fighters close on the helpless ettins (one blow each; the line rule); CEDRIC in the back
     rank; the dying bandaged at once.
  3. **Rest out the alarm in the tower** (*book*), then **town: train LIRA to MU5** (Fireball; Jeremy, 15:16).
  4. **The east tower** the same way, Hold Person on its magic-user first; LIRA's Fireball on the ettins and the mage.
  5. The patrol: PARLAY, HARASH / TYRANTHRAXUS. The 16 bugbears: Sleep, clouds, the line.
  6. Stop rule: 2 losses in the first 3 tries, levels first.
  - **Results (Player 35, 2026-11-20; plans and saves in the lab's `p35/`, files to D: `.lab/stuck/stojanow/p35/`):**
    - **The audit** (p35a1-a3, from `p34c1_s28g`): **movement was 3 for five of six** (ARN load 4500 against 3000
      allowed: seven spare Long Bows each, spare Chain Mail, platinum). Dropped the plain spares: movement ARN, BRAM,
      CEDRIC 9 (Banded Mail), ELWEN, LIRA, DORN 12. Bracers to DORN (AC 4 -> 2), Shield +1 to CEDRIC (AC -1 -> -2),
      Chain Mail +1 to ELWEN, LIRA's Short Bow +1 readied (the Brass Mirror unreadied: a bow takes both hands). Knock x2
      cast away in camp (LOSE IT? YES), Stinking Cloud x2 memorized for LIRA and ELWEN (`s35b`). *Seen:* TRADE to a
      member holding 16 items fails silently (p35a1: drop first). *Seen:* the original swapped LIRA's bow back to her
      sword once her readied arrows ran out (the spare stack stays unreadied).
    - **p35b1 (seed 35020001), the west tower room: won, nobody dead** (CEDRIC unconscious, healed); the whole party on
      QUICK (a plan slip left `tactics on` before the resume point): over in about two rounds. Read: **the audit** (the
      same room was 5 of 5 lost at movement 3, p34e1-e5). Rested a day in the room (`s35w`).
    - **The east tower's garrison comes to the party** at 4,5 on the way down (the level-6 magic-user, an aide, three
      ettins; "THEY ADVANCE"). p35c3 (35030003): **party destroyed** (tool: Stinking Cloud never placed, Hold Person
      out of reach, four Sleeps at one aide, fighters stopping a square short of the ettins; all fixed after). p35c4
      (35030004): **won, nobody dead** (BRAM unconscious; the fighters' MOVE-attacks, LIRA's arrows at the mage) (`s35d`).
    - **No way out before the gate:** from inside the wall (8,5) the only road out is the gate's bugbears (7,10), so
      step 3's town trip (LIRA's MU5, owed since the west tower: 22,606 of 22,501) comes after the bugbears.
    - **The patrol doesn't parley here:** a 6th-level fighter and five hill giants at 5,5, "THEY ADVANCE, WEAPONS
      READY", menu COMBAT WAIT FLEE ADVANCE (no PARLAY). p35d3 (35040003; the first two runs of it were cut short by
      the Player's timeout and a tool stop, LIRA's second arrow): **won the patrol, then the 16 bugbears** (they came
      out to 8,7), nobody dead (BRAM unconscious): **`s35g`, the gate taken: Stojanow's stuck fights are through.**
      Then the old plan's closing explore walk (6,10, 2,12, 4,14, 4,5) under the gate's alarm: a second patrol at 7,5
      won, **a third at 5,5: party destroyed** (CEDRIC last; reload). Read: tactics: don't wander while the alarm
      rings (patrols at 17% a step, poolrad.md); from `s35g` the party goes straight out of the gate to town.
    - **Town (segment 29, Player 27's route; the clerk's reward):** p35e1 trained LIRA MU5 and ELWEN F5 but the tool
      took INVISIBILITY (Fireball on the list's next page: a tool fault, reloaded); **p35e2: LIRA learns FIREBALL,
      `mopup2` reached** (3:0 4,12). **Stojanow: done without a shortcut**, 3 losses in 9 counted tries (p35c3 tool,
      the third patrol on the explore walk). Saves: `p2start/p35d3_s35g`, `p2start/p35e2_mopup2`.

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
    section 4): no level owed at the door (ELWEN's C4 was the only one at `s17a`, trained by Player 23; corrected 15:10,
    an earlier count read the fighter table a level off), but LIRA and DORN are 672 from fighter 4, ARN 867; BRAM's Two-Handed Sword +1 +3 vs
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
  - **Before (the audit):** anyone who qualifies trains (none at the door; a fight or two puts LIRA, DORN and ARN at
    fighter 4), each level checked on the character sheet;
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
  - **Results (Player 36, 2026-11-20): 5 of 5 lost** (p36n1-n5, `p36/king4.plan` from Player 31's `p31c7_s17door`, the
    inn's picks; OP_MAGIC=0, tactics on, `focus TROLL`, `advance ARN,BRAM,PRINCESS FATIMA`). **Done:** BRAM's Two-Handed
    Sword readied, LIRA's cloak and Short Bow +1, **Fatima freed and in the party** (event 14 at 1,3, by the west passage;
    Chain Mail +1 and Long Sword +1 readied, she fought as the seventh). Not done: training (nobody qualifies at the door),
    movement 6+ (CEDRIC and LIRA 3: the weight is coins, which no step drops), the Stinking Cloud scroll (LIRA and ELWEN
    had the spell memorized). Each try: n1 1087 s, 18 of 50 slain, the trolls at 36/36/12/36; n2 875 s, troll HP
    36/36/17 (one down); n3 1116 s, 9 blows on trolls; n4 617 s, trolls 9/36/4/26; **n5 945 s, two trolls down, 36 of 50
    slain, one member left.** **Why:** (1) **Stinking Cloud was never cast**: from round 1 a troll stands next to a party
    member (troll 10 starts beside ELWEN at 30,12) and the tool keeps the cloud's 2x2 off the party; (2) the trolls stand
    behind the kobolds: blows reached them only after n3's new rule (a fighter in `advance` walks to a troll within 4
    squares past the kobolds): 8-10 troll blows a try before, 9-13 after; (3) at F3-5 a troll's 36 HP and regeneration
    outlast the few blows that land; the party's level-1 slots went to two Sleeps and Magic Missiles. **The tool now
    does** melee and bows by type (`focus`), the walk to a troll, Stinking Cloud at the bunch with most trolls (when
    legal); **it can't**: stand on a fallen troll's square on purpose, or cast the cloud with the party inside it.
- **Plan 1 with LIRA's Fireball (Player 37, 2026-11-21; the Lead's answer: later in the chain).** From the graveyard's
  `p37k1_s37tombinn` (F6/C6, multis 5/5/4; ELWEN in the knight's Plate Mail +2: the party then moves 3): `p37/king5.plan`
  to `king7.plan`. **The way in costs the fight before it starts:** 8:27 6,16's LARGE cave mouth is 30 kobolds straight
  into combat at every entry from 8:27; inside, 10,9 / 14,10 is a pair of 95 and 119 HP; **no camp in 8:13** before the
  throne room is beaten (its rest script: interrupted at once while 0x4A8D = 0, unless 0x4AC7 = 255 and 0x4A8E = 0;
  0x4A8E is 2 in this chain); **Fatima leaves the party at the caves' exit** (p37r1), so a heal trip goes before her.
  **Try 1 (p37n2) lost**, from a door at ARN 7/65, CEDRIC 0/42, DORN 31/46: the party destroyed, three trolls left at
  25-36 HP; LIRA's Fireball came on her third turn, after two clouds (now Fireball first). p37u1 healed at the inn and
  came back to the door with ARN, CEDRIC and ELWEN at 0 HP: stopped by hand as the throne fight began, not counted.
  To the Lead (board): a fit party at the door (the SMALL cave? spells kept for the way?), or later.
- **The Lead's way in, then five tries from a fit door (Player 38, 2026-11-21): 5 of 5 lost.** First the audit's
  movement rule: every member carried ~1170 platinum and up to 2560 gold, four at their most (the shop refused them a
  purchase, the money TRADE moved nothing to them); New Phlan's shop: POOL, one purchase regroups the pool into
  platinum, each member TAKEs a set amount: the party moves 9+ (`p38a2_s38audit`, `p38/move.plan`). **(a) The SMALL
  cave** (p38b1, `p38/king8.plan`) enters 8:13 at 6,15 (the LARGE one at 10,15), but 8:27 6,16's 30 kobolds come on
  the square before the cave menu either way, and 10,9's band on the way in: the door with ELWEN at 0 HP, LIRA's
  Fireball spent on 1:18's goblins (not a try). **(b) MAGIC OFF** (OP_MAGIC=0, tactics off): the 30 kobolds cost 26 HP
  (p38c1); with tactics on inside, three plain kobold bands (7,12, 10,9, 5,6) took every spell; **tactics off to the
  door** (p38d1, `p38/king10.plan`): **the door fit** (`p38d1_s38door10`: 289/297 HP, Fatima 33/33, every spell, LIRA's
  Fireball scroll). `p38/king10f.plan`: Fatima armed, LIRA's scroll readied, `focus TROLL`, `advance ARN,BRAM,PRINCESS
  FATIMA`, `scrolls LIRA FIREBALL`. **p38e1**: all four trolls and all but two kobolds killed, then **two killed trolls
  rose again at their squares** (figures 8 and 10, 18 and 24 HP) and beat the last three. **p38e2**: lost, the four
  trolls back at 36 HP at the end. New tactics (`OP_HOLDDOWN`: a fighter in `advance` walks onto a fallen troll's
  square, any of its cells, and stays): **p38e3 cleared the first wave** (BRAM on a fallen troll), then the original
  asked **CONTINUE BATTLE: YES NO** (the tool said NO: the book's "Continue Combat to heal") and wave 2 (4 boars, 45
  kobolds) began with 4 up at 49 HP: lost. New: CONTINUE BATTLE YES while hurt and a cure is in memory
  (`OP_CONTINUE`), cures on the most hurt. **p38e4** lost in wave 1 (313 HP to 111 in 100 s once the trolls closed);
  **p38e5** lost in wave 1 (two trolls left at 27 and 15). Each try spent LIRA's Fireball and scroll, both clouds and
  Hold Persons; the trolls close in about 3 rounds and do the killing. To the Lead (board).
- **Player 39 (2026-11-21), the Lead's (a) Haste: 5 of 5 lost; stopped for the Lead and Jeremy.** 8:13 allows no camp,
  so LIRA swapped Fireball for Haste at New Phlan (`campcast LIRA FIREBALL`, `picks LIRA HASTE`, `prepare`:
  `p39a1_s39haste`), then king10's trip (QUICK, MAGIC OFF) to a fit door (`p39a1_s39door`: 7 up, 273 HP;
  `p39/king11.plan`). New tactics: HASTE first in round 1 (it goes off a turn later), aimed at the member with most
  `advance` fighters within 2; it takes 5 figures within 2 of the point, so 1-2 casters always shared it. Counted tries:
  **p39a1** (the aim never found a party member: Haste aborted; LIRA's scroll not readied: a plain BROAD SWORD taken on
  the trip filled her hands; lost in wave 1, 26 enemies left); **p39b2** (hasted ARN, BRAM, CEDRIC, ELWEN, LIRA; scroll
  Fireball on the kobolds, the trolls already in contact; lost in wave 1, 23 left); **p39b4** (BRAM, ELWEN, LIRA, DORN,
  Fatima; down to 6 enemies, then the killed trolls stood again at 36 HP; lost); **p39c1** (ARN, BRAM, ELWEN, LIRA,
  DORN; lost, 24 left); **p39c2** (the same five; **three trolls down and 9 enemies left with 6 up at 141 HP**, then two
  trolls rose again at full HP and beat the last two). Not counted: p39a2 (stopped by hand for the scroll fix), p39b1 and
  p39b3 (tool stops at a hasted member's second blow: fixed). No try cleared wave 1 (Player 38's e3 did, without Haste).
  What beats every try: the trolls' rising (at full HP, at or beside their squares) once the fighters are spread
  over the kobolds. To the Lead (board): Jeremy and the stuck-fights guide chat.
- **Read (Gold Box Guide 6, 2026-11-21, from Players 38-39's original-side logs and ECL8 block 13):**
  - **The hold-down never held.** In every try with `OP_HOLDDOWN` the figure that "stands on" a fallen troll's square
    is back on another square after the move's Esc (its next menu): **32 of 32** (p38e3 17, p39c2 10, p39b4 3, p38e5
    1, p39a1 1); p39c2's troll 10 rose at 30,12, the square BRAM "held" ten times. p38e3 cleared wave 1 by luck of the
    3d6 rounds, not by holding. Either the original won't let a figure end its move there or the tool's step is wrong:
    to check by hand in DOSBox (requests to the Player and Combat). Ours lets a figure stand on a fallen troll
    (`occupant()` skips downed figures). *seen*
  - **Only fire or acid keeps a troll down:** the killing blow's kind decides (0x11434: no 3d6 rounds after fire or
    acid). In this party: LIRA's Fireball (slot or scroll) and **Burning Hands** (LIRA scribed it, p37b2; ELWEN
    learned it): fire, the caster's level in damage. Lightning (the wands) doesn't count. *code*
  - **The cluebook's "rest in the wyvern cave":** 8:13's rest and wandering-kobold scripts let the party be while it
    came in by the LARGE cave (0x4AC7 = 255) **and the wyvern lives** (0x4A8E = 0; the rubble slope at 8:13 wakes it).
    In this chain the wyvern is dead (2): no camp. *code*

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
  +2, Long Sword +2, Ring of Fire Resistance); not before the audit: at `s26g7c` no level owed (corrected 15:10), but
  LIRA is 1295 from MU5 (Fireball, Haste); everyone at movement 3, ARN's Bracers worn over Banded Mail (no effect: DORN's instead), one
  Restoration left (a 2-level hit needs a whole scroll). Then camp on 10,1 (Haste on the fighters, Prayer, Bless), step
  in, Fireball and bows +1 in round 1, focus one spectre. Haste and Fireball need LIRA at MU5 (earn it first) or the
  Kovel scrolls if a magic-user 4 can cast them (Combat). Simulated: with them about 2 in 3 fights without a drain,
  98% with one at most; with Prayer only, about 1 in 4; bring 2+ Restoration scrolls so a hit costs a scroll, not a reload. Leave the vampire's last fight until
  after (his death stops the tomb's event too).
  - **Plan 1, revised (Gold Box Guide 3 with Jeremy, 2026-11-20 17:09):** start from the current chain (`p35e2_mopup2`):
    at `p33f3_mopup1` the vampire, 9,1 and the tomb are all untouched (0x4A41, 0x4A18, 0x4AF8 = 0). **LIRA SCRIBEs Haste**
    from the Kovel scroll (the game's only Haste) and memorizes it in her one 3rd-level slot; ELWEN takes Haste at MU5.
    Take the Wand of Lightning Bolt (zombie room, 9,15) and **four or more Restoration scrolls**; camp on 10,1: Haste,
    Prayer, Bless; round 1 the wand (**3 charges**, Guide 4) down a long open line, never at a wall near the party (the bolt bounces back: Combat Chat 36), the bows, every fighter on one spectre. **Expect 1-2 drains and pay
    each with a scroll at once** (redone simulation: 2 at most in 77-94% of fights, 4 at most in 99%; drain-free only
    13-29%). Details: poolrad.md section 3.
  - **Results (Player 37, 2026-11-21): won at the second try, no drain.** In this chain the Wand of Lightning Bolt
    is gone: the zombie room's pile (4A88 = 255) was left by segment 26's EXIT (p25l2's plan had no `default
    treasure take`), with its two Restorations. Instead: the Kovel scroll cabinet fetched (3:14 3,13, event 12:
    DISARM by DORN; p37a1), LIRA SCRIBEs Haste and eight more after Read Magic (the scrolls are unidentified until
    read; the original copies one scroll's spells a rest: 11, 9 and 7.5 hours; p37b2); the marble chest with SEARCH
    on (7,6, event 5: a giant skeleton first; four scrolls of two Restorations; p37d1); LIRA's Fireball slot lost
    for Haste, one Fireball scroll readied in both hands (a scroll takes two: her Broad Sword put away); ELWEN reads
    the Restorations (CEDRIC can't carry them). Camp on 10,1: Haste, Bless, Prayer, Protection from Evil on BRAM.
    **p37g1 lost** (both clerics' TURN sent the spectres 21 squares off; the party guarded until the Haste ran out;
    ARN drained to nothing, BRAM, ELWEN and LIRA two levels each). **p37i1 won** (`p37i1_s37spectres`): TURN again,
    LIRA's scroll Fireball at one, the advance fighters walked to the fleeing pair (`advance` now walks to a focus
    figure at any distance) and ARN killed both; nobody hurt. (p37h1: a tool stop at the scroll's aim, not a try.)
  - **Read (Gold Box Guide 6, 2026-11-21): done; no Plan 2.** The lesson for the guide: the clerics' TURN does move
    the spectres (both fled 21 squares), so after TURN the fighters chase while Haste lasts; guarding loses the Haste
    (p37g1). Next on this branch: the knight's tomb (8,2), then the vampire's last fight. *seen*

## 5. The finale's guards (5:7 3,8: "TWO GUARDS MOVE TO BAR YOUR PATH")

Files: `D:\ai_projects\goldbox-reforged\.lab\stuck\finale_guards\`.

- **Enemy:** 12 8TH LVL FIGHTERs (87 HP each, 1,044 in all), then Tyranthraxus at once (poolrad.md section 3, "The
  finale"). The menu offers COMBAT WAIT FLEE PARLAY. The fight opens with the guards in a 5-wide block (rows 13-14,
  x 24-30) touching the party's front row (row 12; the back row is 11): **every member of the order's first four is
  in contact from round 1.**
- **Party** (the no-shortcut chain, Player 40: `p38a2_s38audit`, then `p40/finale1.plan`: Valjevo's 5:3-5:6 left out,
  since no member is near a level and the barracks giants' experience changes nothing): ARN F6 65 HP AC -3, BRAM F6 60
  AC -2 (ARN's spare Ring +2), CEDRIC C6 42 AC -2 (DORN's Ring +3), ELWEN C5/F5/MU4 41 AC -5, LIRA F5/MU5 43 AC -2,
  DORN F5/T6 46 AC 2, **Genheeris** (joins at 2,5, reached only through 2,6: a small fight there; "IN FACT I WILL JOIN
  YOU. IS IT A DEAL?" YES; magic-user 7, 22 HP, AC 9; the computer runs him). Memorized at 3,6 (`s40hall`): CEDRIC
  4 Hold Person, 3 Prayer, 3 Bless; ELWEN 5 Hold Person, 2 Stinking Cloud, 2 Prayer, 3 Sleep; LIRA 2 Stinking Cloud,
  Fireball, 3 Sleep. On the way (p40a1): 5:3's event 14 (12,12) and 12,10 fought on QUICK, then a 5:5 fight at 9,9
  killed BRAM (reloaded from `s40g`, the gate).
- **Tries (all from `p40c1_s40hall`, tactics on): 5 of 5 lost.** **p40c1** (LIRA's and ELWEN's Sleeps at the guards,
  the horde order's first spell: a tactics fault, fixed: Sleep skips figures over level 4 or 36 HP; all 12 left);
  **p40d1** (CEDRIC's Hold Person spoilt by a blow, three clouds at one edge figure; 11 left); **p40d2** (Hold Person
  went off three times, a Fireball, four clouds; 10 left at 593 HP); **p40d3** (5 left, 292 HP; the party 5 up, 99
  HP); **p40d4** (4 left, 219 HP; ARN last). (p40c2, p40d5: stopped by hand, not counted.)
- **Read:** the casters stand in the front row and their spells are spoilt by blows; the held guards don't fall fast
  enough. **The party order sets the start:** ALTER ORDER (camp: SELECT a member, Home/End move it in PLACE, PLACE)
  puts the order's first four in front; `p40/finale2.plan` puts ARN, BRAM, DORN, LIRA forward and CEDRIC, ELWEN behind
  (p40e0, stopped in round 1: CEDRIC at 26,11, the back row). Not yet tried in a counted fight. To the Lead (board).

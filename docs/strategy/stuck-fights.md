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
  Also (merged from poolrad.md's parked notes, Jeremy, Gold Box Guide 8): the early tries ran with MAGIC OFF and
  without level-2 spells (the `prepare` gap, Player 27); in ours, c34d's bot won it with its `smartquick`, CEDRIC C3.
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
  Also (merged from poolrad.md's parked notes, Jeremy, Gold Box Guide 8): Player 31 by hand with the Lead's advice, 5
  more lost (p31b2-b6, best 122 of 382 HP): an ettin starts beside the party (p31a1: 27,10 by BRAM at 28,11), so no
  casting before contact; Player 27 on QUICK threw Hold Person and Sleep at the ettins, never Prayer or Stinking
  Cloud; main's bot lost twice in ours (its table expects level 7); the parties of Players 3, 7 and 9 were destroyed.
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
  Also (merged from poolrad.md's parked notes, Jeremy, Gold Box Guide 8): Player 28 from `s17a` with Hold Person
  picks (CEDRIC x4, ELWEN x4): 5 of 5 destroyed in the horde, 23-31 of 56 standing; the parties from c24f, c32a and
  c34d (Players 2, 7, 9) destroyed on every seed; main's bot wiped seven times. The trip in costs HP: 123-193 of ~197
  at the door (Player 31).
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
    **Answered (Player 40, DOSBox, 2026-11-21; read by Gold Box Guide 7): the tool's step was wrong, the hold-down
    works.** A MOVE ended with Esc is undone (the figure back where MOVE began, MOVE offered again: p40m1); Enter keeps
    the walk (p40m2); the tool's `OP_HOLDDOWN` ended every stand with Esc (now Enter). On the Slums' trolls (2:20 0,14,
    p40t1-t3): **a fallen troll rises at full HP on its corner (top-left) square, unless a standing member is on that
    square**; a member on its second cell doesn't stop it (p40t1: risen with ARN on 26,11); BRAM on troll 9's corner
    27,11 from 55 s kept it down to the fight's end (p40t3, 115 s); troll 12 rose on its corner 26,10 once ARN,
    standing there, had fallen. Ours: whether only the corner counts is with Combat (board). *seen*
  - **Only fire or acid keeps a troll down, and only as the killing blow** (GAME.OVR read by Guide 6): going down
    (0x11434) tests the last damage's kind (DS:0x6819: 0x01 fire, 0x10 acid) and otherwise sets the 3d6-round rise
    (0x66); a weapon blow sets the kind to 0 (0x12A08); the regeneration start on any damage (0x1146F) ignores the
    kind, so fire earlier in the fight changes nothing. A risen troll comes back at full HP (*seen*: p39c2's troll 10
    at 36). Lightning (the wands) doesn't count. *code*
  - **Burning Hands in Pool** (START.EXE's table, id 9): one adjacent figure (area code 4, one pick, as Magic
    Missile), no save, the caster's level in fire damage: LIRA (magic-user 5) 5. Only LIRA has it in her book
    (scribed, p37b2); ELWEN's book has neither it nor Shocking Grasp. *code*
  - **The door (`p39a1_s39door`)**: AC ARN -3, BRAM 0, CEDRIC -2, ELWEN -5, LIRA -2, DORN 2, Fatima 3; HP 273 of 330
    (DORN 26/46, CEDRIC 28/42); every spell kept **but all 7 Cure Light Wounds spent on the way**; 9 Hold Persons
    memorized (no use on trolls); LIRA: Haste, 2 Stinking Cloud, 3 Sleep, Read Magic. *seen* (the save)
  - **A troll's round** (MON8CHA 31): THAC0 13, two claws 1d4+4 and a bite 2d6 (up to 28, 20 on average if all
    hit). Each attack hits ELWEN 15%, ARN 25%, CEDRIC and LIRA 30%, BRAM 40%, DORN 50%, Fatima 55% (Prayer:
    5% less each); about 3, 5, 6, 8, 10 and 11 HP a troll-round. Kobolds (1d4) hit AC -1 or better only on a 20,
    DORN 10%, Fatima 15%; leaders (1d6) DORN 20%, Fatima 25%. *code*
  - **The other waves** (ECL8 block 13, MON8CHA): the ballista: 7 bolts at random members, 2d6 each (0xA1A4);
    wave 2: 5 WILD BOAR (18 HP, AC 7, THAC0 15, 3d4, move 15, fight on 1d4+1 rounds when dropped), 45 kobolds, 8 leaders; wave 3: 2 trolls, 2 boars, 8 kobolds and **2 ENVOY** (fighter 6 / magic-user 6,
    45 HP, AC 2, 1d8+2; memorized: Magic Missile x2, Sleep x2, Stinking Cloud, Mirror Image, **Fireball**). *code*
  - **Why Stinking Cloud missed the trolls** (Players 36-39): it was cast every try from Player 38 on, but at kobold
    bunches: the tool keeps the party out of a 3x3 around the aim, while the cloud is 2x2 (the aimed square and the
    squares right, below and below-right: *seen*, Combat Chat 34). With a troll beside a member from round 1 no 3x3
    point was free. A 2x2 aimed past the trolls catches them without the party: a tool fix (request to the Player).
    About half the trolls fail (13 of 23 in the spell lab): helpless d4+1 rounds, one blow drops one (it still rises
    unless fire finishes it). *seen*
  - **The cluebook's "rest in the wyvern cave":** 8:13's rest and wandering-kobold scripts let the party be while it
    came in by the LARGE cave (0x4AC7 = 255) **and the wyvern lives** (0x4A8E = 0; the rubble slope at 8:13 wakes it).
    In this chain the wyvern is dead (2): no camp. *code* **When it died:** segment 16 (p22c2, the party at level 3:
    `s16b` at 8:13 10,15 is the last save with it alive, 0x4A8E = 0; `s16c` has 1); every save since has 2. Players
    38-39 also came in by the SMALL cave (0x4AC7 = 0), which rules the camp out too. *seen* (the Player's save index)
  - **Fire the party carries** (`p39a1_s39door`'s item files): LIRA's one Fireball scroll; Fireball and Burning Hands
    in her book (one 3rd-level slot: Fireball or Haste). No wand, no necklace, no other Fireball scroll. Also carried:
    9 Restoration scrolls (ELWEN 6, LIRA 2, CEDRIC 1 with one spell), Cure Light Wounds x2 (ARN), Prayer / Remove Curse / Animate
    Dead (LIRA), Stinking Cloud and Detect Magic, Blink (ELWEN), a Potion of Healing (ELWEN), a Potion of Giant
    Strength (CEDRIC). *seen*
  - **Level caps** (START.EXE's experience tables; the halls' race checks, playbook section 1): cleric 6 (27,501),
    magic-user 6 (40,001), fighter 8 (125,001; elf 7 at STR 18), thief 9 (110,001); half-elf cleric 5. At the door:
    ARN F6 59,741 and BRAM F6 57,523 (F7 at 70,001); CEDRIC C6 **capped**; ELWEN C5 **capped** / F5 / MU4 at 22,291
    (MU5 at 22,501: 210 short); LIRA F5 / MU5 at 31,238 (F6 35,001; **MU6 40,001: a second 3rd-level slot, so
    Haste and Fireball both**; her fighter cap 7); DORN F5 / T6 at 31,238 (F6 35,001, T7 42,501). *code* + *seen*
- **Plan 2 (Jeremy approved 2026-11-21 08:16; Gold Box Guide 6):**
  - **Levels first:** train until **LIRA is magic-user 6** (40,001: Haste and Fireball both memorized) and **ARN and
    BRAM fighter 7** (70,001); the graveyard branch next (the knight's tomb, then the vampire's last fight), the
    wilderness and the no-shortcut chain for the rest. Clerics are capped (CEDRIC 6, ELWEN 5): their share is lost.
  - **ELWEN learns Fireball at magic-user 5** (210 XP away): she picks it at the training hall's LEARN WHICH SPELL?
    (Jeremy, 08:20: being able to cast it matters more in the long run than one scroll), so **LIRA keeps her Fireball
    scroll**. Scribing uses a scroll up (Combat Chat 38): only if Fireball isn't offered at the hall, and then from a
    scroll the check below finds, not LIRA's.
  - **Fire to finish trolls:** every Fireball (LIRA's, ELWEN's, scrolls) at bunched wounded trolls, so the killing
    blow is fire; Burning Hands (LIRA, 5, one adjacent figure) only on a troll at 5 HP or less.
  - **The Player checks first** whether the other Fireball scrolls (1:24 Temple of Bane, 4:2 Grishnak's temple) and
    the Necklace of Missiles (5:6 behind the altar) can still be taken in this chain, and takes them.
  - **The tool before the next tries:** Stinking Cloud aimed as 2x2 at the trolls with the party outside; the 7 Cure
    Light Wounds kept for the fight (no cures on the way in); Hold Person only for wave 3's two envoys (persons;
    trolls aren't), the other 2nd-level slots to Stinking Cloud or cures.
  - **The hold-down is back** (Player 40's check, above; Guide 7): a troll dropped by a blow gets a standing member on
    its **corner (top-left) square**, the MOVE ended with Enter; a fighter whose troll is held stays put. It holds only
    while that member stands, so fire stays first, and a held troll is the next Fireball's or Burning Hands' target.
  - No wyvern-alive replay (the wyvern died in segment 16, Jeremy agreed); no SURRENDER.
- **Read (Gold Box Guide 8, 2026-11-21; the battlefield, ECL8 block 13, GEO8 block 13, the Players' logs, players' guides):**
  - **Every wave starts at distance 0** (wave 1 SPRITE_START 0,0,0 at 0xA0F8; waves 2-3 SPRITE_START n,1,n then
    SPRITE_ADVANCE): the monsters' anchor is the party's own square, so the wave is in contact from round 1. *code*
  - **Three squares start the fight: 4,3, 5,3 and 6,3** (event 9 on the throne row; 0xA01B turns the party north on
    each). Every try started on 4,3 (from the door 4,4). Our battlefield and placement code (`battlefield.gd`,
    `placement.gd`, run on GEO8 block 13, troll footprint 2) gives at 4,3 the trolls the original shows at the start
    of p39c2 (25,12 24,12 30,12 23,12). **At 6,3 the party's right side is the east wall**, all four trolls start
    together on the left (23-26, rows 11-13), the kobolds ahead and left, and the back corner (28-29,14) is reached
    only around the left; at 4,3 and 5,3 one troll starts on the right (30,12) and both flanks are open. Party
    slots (facing N): 1 27,13, 2 28,13, 3 26,13, 4 29,13, 5 28,14, 6 29,14, 7 27,14. *code* (not yet seen at 6,3)
    One documented win entered "so only one flank was open" *players* (Demetrios1453, ENWorld, Part 35).
  - **The ballista is script damage, not a figure:** 7 bolts at random members, 2d6 each, between waves 1 and 2
    (0xA1A4; again on FIGHT after a flight, 0xA363). Its emplacements are sealed map cells (event 23, "A RUINED
    BALLISTA LIES HERE": 7-9,3, 3,4, 3,5, 4,1, 6,1): it can't be reached or attacked. *code* Players: everyone at
    20+ HP before wave 1 ends *players* ([hitchhikerprod](https://walkthroughs.hitchhikerprod.com/pool-of-radiance/));
    heal in a continued fight after wave 2, not wave 1: the trolls may rise *players*
    ([GameBanshee](https://gamebanshee.com/poolofradiance/walkthrough/koboldcave.php)).
  - **The drunk kobold's escort was never taken:** every plan answered SLIP PAST at 12,9. WAKE IT, YES: he walks the
    party to the throne room past the traps (0xB119, the tables at 0xB537/0xB550/0xB569: "TAPS THE WALL"), which
    skips 10,9's net trap with its 20 kobolds and 11,9's spikes. It sets only 0x4A08 (a message): the fight is the
    same. *code* + *players* (the crippled kobold's hint; hitchhikerprod)
  - **Tool fault: fighters' walks go back and forth.** In the throne tries most combat steps returned to the cell
    two steps before: p39b4 98 of 115, p39c2 62 of 80, p39b2 30 of 35, p38e3 35 of 74, p36n5 40 of 47 (p39c2: ARN's
    whole move 27,13 / 27,14 / 27,13 ..., his troll two squares off; MOVE LEFT fell each step). The `advance` fighters
    seldom reached the trolls, and a step away from an adjacent kobold may draw its free blow. *seen* (the logs)
  - **Low ceilings** (merged from poolrad.md's parked cluebook notes, Jeremy, 09:02): the cluebook says the caves'
    low ceilings cut movement, AC and damage; a walkthrough puts it only on fights against nothing but kobolds and
    kobold leaders (THAC0 2 worse, damage cut) *players* (ssjlee9, GameFAQs): the bands on the way in, not the throne
    waves (trolls, boars). Not checked in the code.
- **Plan 2 additions (Jeremy, Gold Box Guide 8, 2026-11-21 08:59):**
  - **Start the fight on 6,3:** from the door walk 4,4 -> 5,4 -> 6,4, then north onto 6,3 (5,3 and 4,3 start it too:
    don't step on them). The best ACs in the left front slots 1, 3 and 7 (27,13 / 26,13 / 27,14), the casters in
    slots 5-6 (28,14 / 29,14), set with camp ALTER, ORDER. **First one DOSBox check of the start at 6,3** (a
    screenshot and the figures' cells, compared with the Read above), then the tries.
  - **The trip in by the escort:** at 12,9 WAKE IT, then YES (FOLLOW).
  - **The tool's walk fixed before any counted try** (no back-and-forth steps; a fighter walks to its troll or
    stands).
  - **CONTINUE BATTLE after wave 1: NO**, unless every troll was finished by fire or is held down; heal in a
    continued fight after wave 2 instead. Before wave 1 ends, cures so everyone has 20+ HP (the ballista).
  - **Checked (Player 41, p41s1, DOSBox, from `p39a1_s39door`: E, E, N onto 6,3; the order as it was):** the
    trolls start at 25,12, 24,12, 23,12 and 26,11 (footprint 2), **all on the left, none on the right**; the party
    against the east wall (DORN 29,14 first to act); the kobolds ahead and left (rows 5-12, x 17-28). As the Read
    above expects. Screen and log `.lab/stuck/kobold_king/p41/`. *seen* **The walk fix is in** (tactics.py
    `_move_step`: no step back onto a cell of the same MOVE, two sideways steps at most, distances by footprint).
  - **Plan 2 under way (Player 41, from `p38a2_s38audit`, no shortcut):** **4:2's Grishnak temple** (never visited
    in this chain) won (p41b1): its Fireball scroll (Fireball, Detect Invisibility, Reduce; ARN carries it) and a
    second MU scroll (Blink, Burning Hands, Mirror Image; LIRA), the Cursed Necklace (carried, not readied), potions
    (`s41back`). **1:24 with SEARCH on** (the chain's party had missed the trap door, 0x4A2E 48 -> 60): the bodies'
    jewelry (14,5) and the trap door (12,6): a clerical scroll, a potion, **a Ring +3** (p41c11, `s41bane`); no
    Fireball scroll on the way (Bane's other hidden squares unsearched). On the way two 7:26 band losses (p41c2
    displacer beasts on QUICK, a plan fault; p41c4 13 driders: the party moves 3, no FLEE) and one stopped Podol crowd.
    **ELWEN trained to magic-user 5 and learnt FIREBALL** (p41t1, `s41trained`, 3:0 the inn). 5:6's Necklace of
    Missiles is still behind the altar (on the finale's way). **Left: the levels** (ARN 61,361 and BRAM 58,560 of
    70,001; LIRA 31,974 of 40,001): the vampire (4:10, 0x4A41 = 0, never fought), then the bands.
  - **The vampire (Player 42, `p42/vamp.plan` from `s41trained`, ECL4 block 10):** 15,0's stairs (event 27, YES) put
    the party in the lair at 14,0 (event 28): **the vampire (43 HP) and three wolves**, Bless and Prayer in camp
    first. p42v13 **lost**: the vampire fell in round 3 with nobody hurt, then with one 6-HP wolf left four members
    went from full HP to dying within one round and the party was destroyed (cause not identified; LIRA's Stinking
    Cloud lay beside them). **p42v14 won** (no drain). The trove (14,0 again with SEARCH on): ARN took the **Wand of
    Magic Missiles**; the 3 healing potions and the cleric scrolls were refused (every member but ELWEN at the weight
    limit: about 8,300 pp and 6,200 gp carried, movement 3). The coffin (12,4, entered from 12,3; sanctified): the
    weakened vampire, 15 HP, one blow (p42v37): **0x4A41 = 255, no drain**, +5,017 XP each (`s42vinn`). Left: ARN
    3,623, BRAM 6,424, LIRA 5,748. ARN now wields the knight's Long Sword +2 (from LIRA's pack).
  - **The levels after the vampire (Player 42):** the party was at movement 3 again (the coins): Player 38's audit
    (`p42/audit.plan`: one shop purchase regroups the pooled purse into platinum; `pooltake`): movement 9, DORN 12
    (`s42moved`). Then the 7:26 bands with `bands on` (`p42/bands4.plan`: one trip out, rounds between 15,20 and
    12,27 with a checkpoint after every walk and rest, `prepare` there, the boat home; stirges on QUICK): about
    5,000 XP a member in ~5 hours of trips; **driders surprised the party 5 times and destroyed it in their first
    round** (no FLEE when surprised; once won with 2 of 6 standing); the party-surprised driders were let go by the
    rule's WAIT (guide question on the board). Sokal Keep's army (Guide 10's (c)) is already beaten in this chain
    (0x4AD7 = 255). **At `p2start/p42k1_s42d108` (7:26 12,27): ARN 72,442 (fighter 7 due), BRAM 69,641 (360
    short), LIRA 37,008 (2,993 short).**
  - **Read (Gold Box Guide 10, 2026-11-21 15:40; p39c2's video, contact sheets in `.lab/stuck/kobold_king/p42/sheets/`):**
    (1) **our own clouds sit on our members** (26:15-26:55, 32:00-32:55: CEDRIC STARTS TO COUGH, CHOKES AND GAGS
    FROM NAUSEA: the cleric loses his turns), and the clouds mostly land on 3-HP kobolds beside the trolls (p42v13's
    vampire loss, four members dying in one round with LIRA's cloud beside them, may be the same); (2) **the aim scans
    eat minutes** (110 aim keys in a row; 40:00-40:55 one Hold Person scanning kobolds, members and trolls, landing on
    kobolds already (HELPLESS)); (3) **a fighter guards beside a troll while a caster dies** (44:00-45:30: BRAM, 35 HP,
    aims at range 0-1, backs out and GUARDs, round after round, while two trolls take ELWEN from 30 to 4). *seen*
    (4) Known: the old start in contact with the trolls and ~40 kobolds (Plan 2's 6,3 fixes it); the original's look
    panel shows (HELPLESS) under a sleeping kobold (26:45).
  - **Plan 2 additions from the video (Jeremy approved 2026-11-21 15:46; Gold Box Guide 10):** (a) **no member inside a
    Stinking Cloud or any area spell** (every fight, as Plan 5's finale); (b) **aim by MANUAL** to the cell wanted, no
    NEXT/PREV scans (as Plan 5); (c) **a fighter with an enemy in reach attacks it**: no GUARD.
  - **The levels (Jeremy, 2026-11-21 15:46, answering Player 42's 15:20 question): (c) Sokal Keep's army** (section
    1, lost at level 3; the party is 5-6 now with two Fireballs and the wand): one set fight with its XP, and a stuck
    fight to win anyway. Back to (a), the 7:26 bands with reloads, if it is lost twice.

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
- **Earlier** (merged from poolrad.md's parked notes, Jeremy, Gold Box Guide 8): the parties of Players 2, 3, 7 and 9
  destroyed on every seed. **Player 29: 1 win in 5** (the full run's party, 263 HP, levels 4-6, from `s34h` at full HP,
  levels 1-3 memorized, MAGIC ON): p29b2 won with 5 standing at 141 HP; p29d1-d4 destroyed in under a minute. The
  guards carry 12 Rings of Protection +3, Plate Mail +2 and Two-Handed Swords +2, but the vote and Tyranthraxus come
  straight after the treasure: no camp to ready them. Main's bot lost it twice in ours and took it by shortcut.
- **Tries (all from `p40c1_s40hall`, tactics on): 5 of 5 lost.** **p40c1** (LIRA's and ELWEN's Sleeps at the guards,
  the horde order's first spell: a tactics fault, fixed: Sleep skips figures over level 4 or 36 HP; all 12 left);
  **p40d1** (CEDRIC's Hold Person spoilt by a blow, three clouds at one edge figure; 11 left); **p40d2** (Hold Person
  went off three times, a Fireball, four clouds; 10 left at 593 HP); **p40d3** (5 left, 292 HP; the party 5 up, 99
  HP); **p40d4** (4 left, 219 HP; ARN last). (p40c2, p40d5: stopped by hand, not counted.)
- **Read:** the casters stand in the front row and their spells are spoilt by blows; the held guards don't fall fast
  enough. **The party order sets the start:** ALTER ORDER (camp: SELECT a member, Home/End move it in PLACE, PLACE)
  puts the order's first four in front; `p40/finale2.plan` puts ARN, BRAM, DORN, LIRA forward and CEDRIC, ELWEN behind
  (p40e0, stopped in round 1: CEDRIC at 26,11, the back row). Not yet tried in a counted fight. To the Lead (board).
- **Tries with `finale2.plan` and the MOVE fix (Player 41, the Lead's (a), seeds 41010001-05): 5 of 5 lost.** p41a1
  (6 guards left, 317 HP), p41a2 (8 left), **p41a3 (3 left, 206 HP: 9 of 12 down, the best yet)**, p41a4 (5 left),
  p41a5 (5 left). Files `.lab/stuck/finale_guards/p41/`.
- **A tool fault spoilt the Hold Persons (found in p41a2, fixed after the five):** in a spell's aim the original
  doesn't set DS:0xBEFD (the aimed entry), so the tool named the figure under the aim from the right panel's name and
  HP, and twelve unhurt 8TH LVL FIGHTERs all match: it guessed the first guard not yet picked. Each TARGET after the
  first went to the same guard again (the original keeps the aim up on a figure picked again), so a Hold Person took
  8-12 "picks", held one guard at most, and ended by EXIT (p41a2: CEDRIC 100 s on one cast). Now the tool counts the
  NEXTs along the aim list (NEXT follows the list from the caster, back on the caster after each pick; p41x1's raw
  dump): **p41x2: picks 8, 9, 10, then the aim closed by itself (Hold Person takes three)**. Player 40's tries were
  partly hit too (their quick picks were the same guess). So none of the ten tries had three-target Hold Persons.
  *seen*
- **Read (Player 41):** with the order changed the party lasts longer and the guards fall 3-9; the collapse comes
  late (party 6 up at 161 HP with 6 guards left in p41a1, destroyed in 40 s more). The fight hasn't been tried with
  working Hold Persons (4 casts x 3 guards from CEDRIC, 5 from ELWEN). To the Lead (board): five more with the fix,
  or the stuck-fights guide chat as decided.
- **Tyranthraxus, earlier** (merged from poolrad.md's parked notes, Jeremy, Gold Box Guide 8): won 2 of 2 from c27a
  (Player 3); from c32a 2 of 4, every win with deaths (Player 7: a loss by the death rule); his fear paralyses or
  weakens low-level members, his breath did 80 to ELWEN in ours. **Player 29: 0 of 7** after the guards (full 263 HP,
  all ATTACK votes; p29b2 after the won guards, p29f1, p29e1-e5: destroyed in about 18 s each); taken by `shortcutwin
  5:7 3,8 2` (p29f2). Main's bot (7 members, levels 6-7) beat him with one death.
- **Read (Gold Box Guide 8, 2026-11-21; ECL5 block 7, GEO5 block 7, the Players' logs, players' guides):**
  - **One square starts it:** event 8 lies only on 3,8, entered from the door at 3,7 (facing S). The guards come at
    distance 0 (ENCOUNTER_MENU 16,0,...: maximum 0), in contact from round 1; every reaction is 0 (COMBAT, WAIT and
    PARLAY fight; FLEE gets away only with the slowest at movement 9: back to 3,6). *code* Our placement code on
    GEO5 block 7 puts the party on rows 11-12 (front row 12) and the guards on rows 13-14, as p41a3's opening cells
    (guards 23-31). *code* + *seen*
  - **A doorway behind the party:** the wall behind row 11 has a 2-cell gap at 24-25,10 (the door from 3,7); north of
    it an open room (rows 6-9, x 22-32). Slots 5-6 (26,11 / 25,11) stand at its mouth. Every try fought in the open
    (the guards walked round the east end: p41a3 29,12 and 29,11, behind the line). Through the gap the guards come
    two at a time against four of ours. *code* (not yet seen) Players: Hold Person and Stinking Cloud over Fireball
    *players* ([GameBanshee](https://www.gamebanshee.com/poolofradiance/walkthrough/upperandlowerlevels.php)); a
    cloud blocks a choke point, the enemy won't walk into one *players* ([easydamus](https://www.easydamus.com/PoR.pdf)).
    The speedrun guide's "they won't even move" is not so here (p41a3).
  - **Tyranthraxus can wait:** the guards' win sets 0x4A6D bit 4 (0xA620) before his speech; a flight from his fight
    (0x6DC7 = 129, 0xA803) puts the party at 3,6 facing N (0xA5EA); on 3,8 again bit 4 skips the guards (0xA558) and
    his speech, the vote and his fight follow (0xA629). So: win the guards, take the pile, run from him, camp, then
    come back to him alone. *code* (not yet seen: can the party reach the field's edge ahead of him?)
  - **Unconfirmed:** a speedrunner says Stinking Cloud works on him (coughing: AC -4 to 4) *players*
    ([speedrun.com](https://www.speedrun.com/pool_of_radiance/forums/h2u0g)); ours has him resisting every spell
    (the original's bug #7).
- **Plan 3 (Jeremy approved 2026-11-21 09:23; Gold Box Guide 8):**
  - **The guards at the doorway:** **first one DOSBox check** (from `p40c1_s40hall`: the gap 24-25,10 open in the
    original's field, the party can step through it in round 1, and the guards follow through it). Then: round 1 the
    back row (slots 5-7) goes through the gap first, then the front four (each takes one free blow stepping out of
    contact); the best-AC fighters hold the gap's north side, the casters behind them; Hold Person (three picks, the
    aim fix) and Stinking Cloud on what comes into or bunches at the gap; a cloud may block it (the enemy won't walk
    in). Prayer and Bless as before.
  - **Tyranthraxus by the flight:** after the guards, TAKE the pile; in his fight everyone runs for the field's edge
    (north through the gap). Back at 3,6: camp, READY the 12 Rings of Protection +3 and the Two-Handed Swords +2,
    rest, memorize, cast the buffs at 3,7, step onto 3,8: his speech, the vote (all ATTACK), the fight alone. **First
    one try of the flight** (does the party get away; a member left behind: reload). No shortcut: the game's own script.
  - **Stinking Cloud on Tyranthraxus:** one cast in that try (does he cough; his AC after).
- **The fair tries (Player 41, the Lead's (a) again, 10:06-10:33; the aim fix in; seeds 41040001-05): the guards won
  3 of 5** (p41d2, d4, d5: party 5-6 up at 143-169 HP; d1 lost with 7 left, d3 with 5). Working Hold Persons (three
  guards a cast) made the difference. **Then Tyranthraxus, at once (the vote ATTACK, no camp): 0 of 3.** p41d4: 
  TYRANITHRAXUS (80 HP, 2x2) and a second 2x2 figure of 239 HP, the party (5 up, 167 HP) destroyed in ~20 s; p41d5:
  him alone, the party 6 up at 179 HP, destroyed in 107 s with him at 71: tactics spent the turns on Sleep x3 and
  Hold Person x4 at him (a tool fault, fixed after: no Sleep or Hold Person on a figure over one square, and a foe's
  HP counts for Sleep's 36); p41d2: down to LIRA at 29 HP, then the original dropped to DOS (`p41d2_stop.png`; after
  the tool's CONTROL space at OVR:0bb90: the game's or the tool's, not known). Files `.lab/stuck/finale_guards/p41/`.
  **Stopped there (the Lead's rule).** These tries ran before Plan 3 (above) was read; Plan 3's doorway and
  flight answer what they show (the guards won in the open 3 of 5; Tyranthraxus at once is the wall).
- **Plan 3 (1) checked (Player 41, p41g1, DOSBox, from `p40c1_s40hall`, `OP_GOTO` north of the gap; a check, stopped
  in round 3):** **the gap 24-25,10 is open** and the cells north of row 11 at x 27-28 are wall (DORN's steps refused);
  BRAM went 26,12, 25,11, 24,10, 24,9 (through by round 2), ARN 27,12 to 25,9 by round 3 (movement 3: about a square
  a round); **the guards follow** (19 at 24,11, 15 at 24,12 by round 3). **The cost: the party fell from 313 to 151 HP
  in three rounds** (each step out of contact draws free blows; only the non-casters walked, the casters cast). Files
  `.lab/stuck/finale_guards/p41/p41g1.*`. *seen* For the guide: the open-field tries already won the guards 3 of 5
  with working Hold Persons (above); the doorway costs about half the party's HP to reach.

- **Read (Gold Box Guide 9, 2026-11-21; p41g1's log, every figure's cell from memory):** the 313-to-151 above is
  **not** the cost of walking. At ARN's first turn the party stood ELWEN 25,10 (in the gap), CEDRIC 26,11, LIRA
  25,12, BRAM 26,12, ARN 27,12, DORN 28,12 (the seventh unlogged, 25,11 likely), the guards on 25-30,13 and 24,
  26-28, 30-31,14: **five guards (25-29,13) in contact with LIRA, BRAM, ARN and DORN from round 1**. Most of the loss
  is those five meleeing every round, walk or no walk. Free blows: one clear case, BRAM's two steps (242 to 211).
  The walk was wrong too: `OP_GOTO` pressed into walls (DORN three keys, two into 27-28,10, the tool's log puts
  him on a wall cell; he ended where he began, then stepped back to 28,12), ARN twice "no step nearer": turns lost.
  **To check:** LIRA's Fireball at the guard on 28,14, two squares from DORN and ARN (297 to 255 across it): did it
  catch our front row? *seen* (log only; the video below decides)
- **Plan 4 (Jeremy approved 2026-11-21 12:29; Gold Box Guide 9; replaces Plan 3's doorway, keeps its flight):**
  - **No doorway, nobody walks in round 1.** Round 1: **Stinking Cloud** first (magic-user 2: at once; the 2x2 on
    front-row guards with no member in it; a failed save is helpless d4+1 rounds), then **Hold Person** (cleric 3
    picks, magic-user 4; goes off at the caster's next turn, so cast it where the casters aren't in contact: ELWEN,
    CEDRIC). Fighters attack the guards in contact; a helpless or held one first (one blow slays it).
  - **Then step back from the held ones** (a held or helpless guard strikes no free blow): the held front row stands
    between the party and the guards on row 14, who must walk round the ends. Finish the held by melee when beside
    them, by missiles (bows, darts) when not: **first one check whether a missile slays a held figure as a blow does**.
  - **No Fireball near our own line** until the check above says how far it reaches.
  - **Tyranthraxus by the flight**, as Plan 3: TAKE the pile, run from him, camp at 3,6, READY the rings and swords,
    rest, buffs, then him alone; one Stinking Cloud on him. Every try reported for Jeremy.
- **Videos (Jeremy, 2026-11-21 12:29):** every fight lost five times gets a video of one lost try, from the fight's
  start (DOSBox, lossless, `.lab/stuck/<fight>/`, never a repo). For this fight: **p41g1 and p41d4 replayed** from
  their saves and seeds. **At a human pace (Jeremy, 12:32):** a person must be able to follow it: each combat message and move on screen long enough to read (about 2 s or more), the menus at about a key a second; if the run goes faster, slow the video afterwards.
- **Read (Gold Box Guide 9, 13:49; p41d4's video, the Tyranthraxus part, `.lab/stuck/finale_guards/p41/p41d4_video_dosbox.mkv` from 25:40):**
  he speaks as **THE DRAGON** ("indeed mighty warriors ... no hope of your success"; join him and command the armies);
  every vote ATTACK. **The party came in already broken from the guards: DORN 0 HP, LIRA 0, BRAM 12** (ARN 50, CEDRIC
  42, ELWEN 41, GENHEERIS 22). Round 1: ELWEN "weakened by fear"; ARN and BRAM attack him and miss (AC -4); CEDRIC
  wastes the turn on Hold Person at him (the tool fault since fixed). **Then his breath: lightning, 80 points each,
  the same as his 80 HP: ARN killed, ELWEN killed (seconds apart: one bolt along the line, it seems), then BRAM 80.**
  So the party dies to three breaths, not to blows. *seen* Open: does his breath's damage follow his current HP (the
  AD&D dragon rule: hurt him first and it shrinks) and how often he breathes: one reading of GAME.OVR (Combat); the
  nameless 239-HP 2x2 figure did not show on screen in the video's part. This video too starts ~130 s late.
- **Jeremy's notes on p41g1/p41d4 (2026-11-21 13:50; Gold Box Guide 9): "This fight is extremely easy with the
  current setup."** *Jeremy*
  - **Plan 5 (his way; replaces Plan 4's round-1 detail, the flight for Tyranthraxus kept):** the clerics Hold
    Person everyone (they carry enough casts for all twelve: three guards a cast); the magic-users Stinking Cloud
    the ones not held; the fighters fight the ones not helpless while the others kill the helpless. A fallback would
    be easy but is probably unnecessary.
  - **The tool's faults he saw:** the Fireball aimed so it burnt our own (aim so no ally is in it); LIRA cast in
    contact (step back first, or don't cast there); aiming by NEXT/PREV scans (use MANUAL and go straight to the
    cell wanted); the second Stinking Cloud overlapped the first (place it beside, covering two more cells);
    CEDRIC's book (three Blesses, two Cure Light Wounds): **spell loadouts to be discussed thoroughly with Jeremy.**
  - Jeremy will play the fight himself from `p40c1_s40hall` to show how.
- **Results (Jeremy, by hand in ours, 0.1.7-test2, slot H = `p40c1_s40hall`, 2026-11-21 14:06-14:48): won at the fifth try**
  with Plan 5 (holds and clouds); four earlier tries ended in two crashes and two stops. Recordings
  `.lab/stuck/finale_guards/jeremy/` (`..._won` the win). His read: an easy fight with all the Hold Persons, held back by
  ours' faults (no (HELPLESS) on the look panel, so held guards were re-held; holds seeming to last about a round;
  Stinking Cloud's effects outside its 2x2; Fireball crashes; board request 14:33) and by the party: **overloaded, and no
  ranged weapons** (DORN's quarrels with no crossbow, only LIRA's bow). *Jeremy*
- **Videos and checks (Player 42, Guide 9's request):** **p41g1 and p41d4 replayed exactly** from `p40c1_s40hall`
  and their seeds (`p42/replay.py`: the log's keys sent at the original's own key waits, the tool's Space at the
  fight's start sent as many seconds after COMBAT as in the run, since it decides how many turns the computer plays;
  the seed checked before every key: **0 drifts** in 325 and 851 keys), at a human pace (messages at the game's speed
  9, about 2 s; a key a second): `.lab/stuck/finale_guards/p41/p41g1_video_dosbox.mkv` (10 min) and
  `p41d4_video_dosbox.mkv` (30 min), with their replay logs. **A missile slays a held or sleeping figure as a blow
  does** (GAME.OVR 0x13C01 tests the helpless target first for missiles too; Combat Chat 25 saw a nomad's arrow slay
  a sleeping kobold, p19e6 draw 21571): *code* + *seen*. **`OP_GOTO` and every MOVE walk now skip the field's
  impassable cells** (the combat map at DS:0x6716, ground ids' move cost at DS:0x2744; Combat's trace.py).
- **The Fireball check (Player 42, the p41g1 replay read at LIRA's Fireball, key #106):** aimed at the guard on
  27,15, it took **15 HP each from ARN (27,12) and BRAM (26,12)**, three rows off; DORN (28,11), CEDRIC (26,11) and
  Genheeris (27,11) were untouched, and of the guards all but 29,12 were hit (15, or 7 on a save): about a circle of
  radius 3 (dx² + dy² <= 10) around the aimed square. *seen* The tool's old rule (no member within 2) was too small:
  now no member within 3 of the aimed figure, in every fight.
- **Plan 4's tries (Player 42, `p42/finale4.plan` from `p40c1_s40hall`, `OP_PLAN4=1 OP_FLIGHT=TYRAN`, seeds
  42050001-07):** round 1 went as written (ELWEN's and LIRA's Stinking Clouds, then CEDRIC's Hold Persons three at a
  time; nobody walked while in contact). **The guards: 1 of the 5 counted tries won** (p42f1: 4 of 7 up, 111 HP;
  f2, f3, f5, f6 lost with 4, 5, 8 and 2 guards left); **two more wins outside the count**: p42f4 (all 7 up, 272 HP;
  a tool stop after) and p42f7 (5 up, 164 HP). So 3 of 7 in all, as the open field's 3 of 5 (Player 41). **The flight
  from Tyranthraxus fails at movement 3** (this save's party carries ~6,400 gold besides its platinum: everyone moves
  3): from their cells the edge is 5-12 steps, 2-4 rounds, and he kills them on the way: p42f1 destroyed; p42f7 only
  LIRA got off the field (the others fell, so the party was lost); p42f4 BRAM, two steps from the edge, stepped off
  in round 1 and the original asked **FLEE: YES NO** (the tool now answers YES). The script puts a fled party on 3,6
  (ECL5 block 7, 0xA803: 0x6DC7 = 129) with the guards kept beaten (0x4A6D bit 4). *seen* + *code* Files
  `.lab/stuck/finale_guards/p42/`. **For the guide:** the flight wants movement 9+: at the guards' pile POOL the
  money and TAKE back platinum only (a shop regroups gold into platinum, a pile doesn't), or reach the hall from the
  Plan 2 chain, which moves 9 since its audit (`s42moved`).
- **Read (Gold Box Guide 10, 2026-11-21 15:20; p42f1-f7's logs in `.lab/stuck/finale_guards/p42/`):** **(1) By the
  reload rule (decision 2026-11-20 10:22: a death means a reload) only p42f4 won the guards** (all 7 up); f1 and f7
  went on to Tyranthraxus with three members dead. **(2) The holds decide it:** f1 and f7 had holds on the guards in
  contact (8, 9, 10) in round 1 and f4 had them by round 2; f2, f3 and f5 held nobody until rounds 2-3 (25-75 HP gone
  by then), and in f6 CEDRIC's first holds went to the far guards 17 and 18 ("no more targets after 2 picks") while
  the guards in contact stayed free. **(3) Clouds overlapped:** ELWEN and LIRA both aimed at the same guard in one
  round (f1 and f5: figure 10), LIRA twice at figure 8 (f6). (2) and (3) are what Plan 5 changes. **(4) The flight:**
  movement 3 (the gold, Player 42 above), and the guards' pile then added weight: the take rule gave GENHEERIS
  Plate Mail +2 (450) twice and Two-Handed Swords +2 (90) just before the fight where speed counts; some members also
  spent turns attacking him instead of walking on (logged "flees: N steps", then "attacks figure 8"): the Player
  to explain. **(5) The original's FLEE: YES NO** at the field's edge seen for the first time (p42f4_stop.png, BRAM 15
  HP): Combat has built it from the code without having seen it.
- **Plan 5 additions (Jeremy approved 2026-11-21 15:22; Gold Box Guide 10), with Plan 5 as written (13:50):** (a)
  answer FLEE: YES NO with YES (Player 42 has done this); (b) **at the guards' pile, before Tyranthraxus, take only
  weightless items (the rings)**; the heavy loot (and the gold) after he is beaten: Player 42's POOL the money and TAKE
  back platinum only fits this; the party must move 9+ for the flight; (c) **a death in the guards' fight is a
  reload**: don't go on into Tyranthraxus short-handed.
- **The throne room's video (Jeremy's rule, five losses):** p39c2 (Player 39's Haste try from `p39a1_s39door`, seed
  39030002, lost) replayed exactly (1177 keys, 0 drifts) at the same human pace:
  `.lab/stuck/kobold_king/p42/p39c2_video_dosbox.mkv` (about 48 min) with its replay log.
- **Read (Gold Box Guide 11, 2026-11-21 19:15): Jeremy beat the game from slot H (`p40c1_s40hall`) in ours,
  0.1.7-test3, ORIGINAL'S BUGS off** (recording `.lab/stuck/finale_guards/jeremy/2026-11-21-182145_finale.gbrrec`, his
  log `godot.log` of that session). **His way (Jeremy):** keep Genheeris far enough back to bolt the guards' whole front
  line with the wand every round; hold and nauseate the rest with Hold Person and Stinking Cloud. *Jeremy*
  - **The guards: won in 9 rounds, nobody dead.** Round 1 LIRA's cloud, CEDRIC's holds (2), the wand (4 guards);
    round 2 LIRA's Fireball on 10 guards and none of ours; all 12 down by round 7 (the helpless slain); rounds 8-9 he
    answered CONTINUE BATTLE YES and healed in the fight (the original's own prompt once no enemy stands: GAME.OVR
    0xA163). Nothing in it rests on a fixed original bug (the guards have no magic resistance): **the method carries
    to the original**; only the dice and the Fireball's placement need a run. *seen* + *code*
  - **Tyranthraxus: won in 4 rounds, BRAM and DORN killed by the round-1 breath (80 each, saves failed), ELWEN down
    by the round-4 breath (40, saved), CEDRIC by blows.** He took 92: **38 from blows** (4 hits in 14 swings) and
    **54 from the wand** (10, 11, 11, 22, the last the kill). **In the original he resists every spell and effect**
    (bug #7: 15 - 5 x (11 - 3) wraps to 231 in a byte: every d100 resists; GAME.OVR 0x11570), so the wand's bolts do
    nothing there; ours (bugs off) gives him 40% against a wand's level 6, and all four got through (about 13%).
    Without the wand he ends round 4 at 42 of 80 with a breath left: **this half would not have worked in the
    original.** *code*
  - **For the Player (Jeremy, 19:12): the Player must be able to beat the original.** Judge every finale plan by the
    original's rule: **Tyranthraxus by blows alone**; no wand, cloud or hold counted on him.
  - **His numbers (MON5CHA 66, read in the game's data):** the record says AC 0 (rear 2), 80 HP, THAC0 5, **DEX 19**;
    the record worked out as a fight does (PartyMember.recalculate, run on every monster at the fight's load) adds
    DEX 19's -4: **AC -4 in play** (rear 2), as the original's look panel showed in p41d4's video and the speedrunner's
    "AC -4 to 4". **Coughing makes it 4** (rear 2 + 2, GAME.OVR 0xF71D) for the round the cough lasts; a "STARTS TO
    COUGH" with no "IS COUGHING" after it is a cough he resisted (ours prints the words before his resistance roll),
    so AC -4 still. Effects 0x18 (sees invisible), 0x4F (a hit burns 2d10 more: the "TAKES n FROM FIRE" after each of
    his hits), 0x51 (fear at the fight's start: levels 0-3 paralysed, 4-5 Curse, -1 to hit), 0x58 (the breath), 0x59
    (**the first attack roll against him each fight misses**), 0x6A (magic resistance). He made three attacks a round
    in ours (rounds 2, 3); poolrad.md says two: to Combat. *code* + *seen*
  - **Jeremy's swings against the odds** (12 after the free miss; Prayer +1 from round 1, ELWEN's Curse -1): round 1
    ARN (AC -4) 0/1; round 2 (coughing from round 1's end, AC 4 if it lasted) 1/4; round 3 (his cough resisted: AC -4)
    0/4; round 4 (coughing: AC 4) 3/3. **4 of 12 fits AC -4 with coughs in rounds 2 and 4** (expected 4.3 to 5.9);
    at AC 0 throughout it would be 5.5, at AC 2 6.7, at AC 4 7.8 (4 or fewer: 29%, 10%, 2%). Needs at AC -4 with
    Prayer: ARN 14, LIRA 16, ELWEN 17, CEDRIC 18; at AC 4: 6, 8, 9, 10. **In the original (bug #7) he resists every
    cough: AC -4 all fight.** *code*
  - **The breath, plainly (ours' reading of GAME.OVR 0x2A0F1):** always 80 (his maximum HP, not what he has left:
    hurting him first doesn't weaken it); a save vs breath halves it to 40; round 1 always, then on a 50% roll each
    round, three breaths a fight at most; the bolt starts beside him and runs on in a line, hitting each figure in its
    path (BRAM and DORN in round 1). Nothing the party can get resists electricity; Prayer and the magic-user's
    Shield add 1 to the save. Whether the original's breath uses his maximum or current HP is the desk's P87 (c).
    *code*
  - **The party in slot H** (Guide 11's item read: every record's bytes, the hidden name words shown): most magic
    unidentified; BRAM with no shield on the Flail +1 while the Two-Handed Sword +1 +3 vs Undead sat in his pack; DORN's
    Quarrels +2 readied with no crossbow and Bracers AC 6 over Ring Mail +1 (AC 6 both: whether the original counts
    bracers over armour is a check); the Potion of Giant Strength on CEDRIC and the Potion of Healing unused (ELWEN);
    LIRA's Short Bow +1 not readied and a clerical scroll (Prayer, Remove Curse, Animate Dead) she can't use; about
    800 coins of dead weight (ARN's Leather +1, CEDRIC's Long Sword +1, ELWEN's spare Chain Mail +1 and Shield, LIRA's
    second Broad Sword). Valjevo's 5:3-5:6 were left out (Player 40): 5:6's altar (2 Long Swords +3, Mace +3, the
    Necklace of Missiles) never taken. *code*
- **Plan 5 additions (2), Jeremy approved 2026-11-21 19:34 (Gold Box Guide 11):** **Haste, Prayer and Bless in the
  guards' CONTINUE BATTLE rounds** (once no guard stands: the original's prompt, GAME.OVR 0xA163; his fight follows
  with no time passing, effects keep their rounds): LIRA memorizes Haste for it (her book has it; it doubles attacks,
  GAME.OVR 0xF8A6). Against AC -4 by blows alone the party's slot-H blows come to about 16 a round with Prayer
  (ARN and BRAM hit 35%, the rest 15-25%): about 5 rounds for his 80, so Haste is the plan's core, the gear trip
  (the board) its second half. *code*
- **One chain to the end (Jeremy, 2026-11-21 19:50; Gold Box Guide 11):** the game is finished in **the Plan 2 chain**
  (Players 41-43, from `p38a2_s38audit`): its gear and levels, the throne room (section 3), then Valjevo by Player
  40's route with 5:6's altar, 5:3's Flame Tongue and 5:4's swords, then this fight with Plan 5's additions. Slot H's
  gear trip (board 19:38) is paused; `p40c1_s40hall` stays as a fallback. *Jeremy*
- **Plan 5's tries (Player 43, 2026-11-21 19:20-20:20; `p43/finale5.plan` from `p40c1_s40hall`, `OP_PLAN5=1
  OP_MANUAL=1 OP_FLIGHT=TYRAN OP_FIGHTDEATH=1`, seeds 43100001-06; logs in `.lab/stuck/finale_guards/p43/`):**
  the tool now aims every spell by MANUAL (M, the cursor keys straight to the target's square, the panel checked,
  TARGET: Fireball in 6 keys where the scans took 20-110), Holds Person first for a cleric (three a cast, the guards in
  contact first, none helpless), clouds never overlap, the fighters strike the standing guards and the others the
  helpless, a caster next to a standing guard steps back before a next-turn spell, the pile gives only weightless
  items (twelve **Rings +3**, weight 0), and a death in the guards' fight stops the try as a reload.
  - **The guards: won 5 of 6 fights, 4 by the reload rule** (Plan 4: 1 of 5). p43f1 won but DORN died (a reload);
    p43f2 won (DORN and GENHEERIS unconscious at 0 HP); p43f3 won after ~7.5 minutes with five of seven at 0 HP
    (stopped by hand at the pile: it ran before the POOL step, not counted); **p43f4 won with all seven standing**
    (241 HP); p43f5 lost (the party destroyed; holds went out three a cast but the 8th-level guards saved often);
    p43f6 won (DORN and GENHEERIS at 0 HP). *seen*
  - **Tyranthraxus: the flight failed in all three tries that reached him.** p43f2 at movement 3 (the coins): only
    LIRA got off, the others fell (he was at 58 of 80 HP). Then, at the pile, **one POOL with ARN selected put every
    member's coins on the pile but the NPC's** (GENHEERIS's 15 gp needed his own POOL: ours' coin_pile.gd also leaves
    NPCs out; no difference) and the coins stayed there (no use after the finale: Plan 5's (b)): **movement 12**.
    p43f4: LIRA, ARN and CEDRIC got off; BRAM, ELWEN and GENHEERIS fell; DORN stepped off at 40,24 and answered
    FLEE YES but still stood on the field at his next turn and was lost (unexplained). p43f6: **his first turn
    dropped BRAM and CEDRIC before anyone moved**, ARN fell on his way, only LIRA got off. The members start 11-13
    squares from the edge, two turns at movement 12, and he acts first. *seen*
  - **Five losses in a row** (f1, f2, f4, f5, f6): video of p43f4 (exact replay, human pace) in
    `.lab/stuck/finale_guards/p43/`; the question to the Lead is on the board.
  - Also seen: after a MANUAL pick the original goes back to the AIM menu with the aim on the caster (Hold Person's
    three picks each start from the caster); MANUAL's EXIT goes back to the AIM menu; TARGET shows in MANUAL only
    in the spell's range (Cure Light Wounds: one square). *seen*
- **The Plan 2 chain's potions and best items (Player 43, Guide 11's trace of 19:15 / 19:51 (1); the full table in the
  Player lab `p43/trace.md`, copy `.lab/stuck/finale_guards/p43/plan2_chain_trace.md`):** 30 runs, 599 saves from
  `p38a2_s38audit` to `p43b2_s43d75`: **nothing was drunk, read, zapped, sold or dropped.** Potions: CEDRIC's Giant
  Strength and ELWEN's Healing from the start, DORN's Healing (4:2 3,11), BRAM's Extra Healing (1:24 12,6): all four
  still carried. **Restoration: 17 on 9 scrolls** (ELWEN 12, LIRA 4, CEDRIC 1), none read. **Left at the vampire's
  trove** (4:10 14,0, p42v21, everyone "full or overloaded"): 3 Potions of Healing and the Restoration x2 scrolls (and,
  by the gear map, a Shield +1). Picked up: the Wand of Magic Missiles (ARN, a fighter: not readied), a Ring of Feather
  Falling (CEDRIC, not worn), the Cursed Necklace (ARN). **Carried, never worn:** ARN's second Ring of Protection +2,
  DORN's Ring of Fire Resistance. **Never had:** the Gauntlets of Ogre Power, the Flame Tongue, the Necklace of
  Missiles, the Wands of Lightning Bolt and Paralyzation, Bracers AC 2-4, Rings of Protection +1 / +3, Long Swords +3 /
  +4 / +5, Mace +3, Hammer +3, Two-Handed Sword +2, Plate Mail +1 / +3, Shield +2, Leather +4, Sling of Seeking +2,
  the Javelin of Lightning, the Potion of Speed. The chain passed 4:2 and 4:10 without the Gauntlets' squares (4:2
  12,14 / 1,3), the Wand of Lightning Bolt's (4:10 9,15) or the Hammer's and Sling's (4:10 15,8). *seen* (the saves)

# The Player's strategies and capability (Gold Box)

Gold Box Guide 12 with Jeremy, 2026-11-21 20:21-21:10. What the Player should do in every Gold Box game, what it can
do now, and how it gets more capable. Approved by Jeremy (decided: ai-business-ideas `ideas/game-modernizer.md`,
2026-11-21 21:05). The tactics themselves stay in `docs/playbook.md`; this file is the list and the plan.

## 1. The goal (Jeremy, 20:48: "make sure that we don't drift from our real goal")

The Player is a **reference-maker**: it plays the original so that its runs become differential checks along the
whole path, and plays later games before ours supports them (decisions 2026-11-15 Methods 4; 2026-11-20 06:40 and
07:06). **Skill is the means, not the goal:** a fight won only by a shortcut gives no reference for that fight, and the
hard fights are where rule differences hide; at about five losses and a guide session per hard fight, Curse, Silver
Blades and Pools would each cost many guide evenings.

**Why it plays badly now:** the tool chooses each member's action from a fixed priority list (tactics.py `choose()`),
with no picture of what the fight or the game needs; each loss was fixed with a switch for that one fight
(`OP_HOLDDOWN`, `OP_GOTO`, `OP_PLAN4`, `OP_FLIGHT`, `OP_QUICKKINDS`). The rules don't generalise, and the guides kept
the pattern going by writing the next rule after each loss.

## 2. The strategies (all approved by Jeremy, 20:29-20:38)

"Now" is what the Player can do on 2026-11-21 (tactics.py, plans.py, the README).

**In a fight**

| # | Strategy | Now |
|---|---|---|
| 1 | The audit enforced before a hard fight: best gear readied, a working missile weapon with ammunition per fighter, potions and scrolls with their users, movement 9+ | partly (printed, not enforced) |
| 2 | Identify magic items when found | no |
| 3 | A spell-list review for each hard fight | partly (`picks` by hand) |
| 4 | Long buffs in camp just before the trigger | partly (`campcast` by hand) |
| 5 | **Loot:** the take rule stands (some loot must be taken); before a fight where speed or weight decides it, the last battle above all, carry only what wins it and collect the rest after (*Jeremy*, 20:29); never refuse healing potions for weight | partly (Plan 5 only) |
| 6 | Choose the start square and the marching order (a wall on a flank, casters behind) | partly (guides choose) |
| 7 | A field read before round 1: contact, lines for a bolt or Fireball, the back row, each member's round-1 action and why | no |
| 8 | **Targets by threat: every disabler on the enemies in contact first**, then casters, then the far ones | no (`targets()`: casters, then list order) |
| 9 | Disable, then kill the helpless | yes |
| 10 | Area spells: none of ours inside; Fireball 4+ squares off; clouds side by side, not stacked | partly (no stacking check) |
| 11 | Aim by MANUAL | partly (`OP_MANUAL`; Player 43's guards 5 of 6 with it) |
| 12 | Line attacks: a wand, bolt or Javelin down the enemy's line from far back | no |
| 13 | Know immunities (undead, large, Tyranthraxus resists everything in the original) | partly |
| 14 | Disablers in round 1 | partly (`OP_PLAN4`) |
| 15 | Short buffs at the pivotal moment; Haste, Prayer, Bless in CONTINUE BATTLE rounds | partly |
| 16 | **Casters in melee (*Jeremy*, 20:38):** magic-users stay out of melee; clerics may begin spells in melee, a calculated risk (a hit spoils a begun spell; their AC should be good); no caster steps back to cast (a free blow) | partly |
| 17 | A line of four; a fighter with an enemy in reach attacks, never GUARDs; no free blows | partly |
| 18 | Use the ground: chokepoints, walls on a flank, archers out of reach | no |
| 19 | Stand on fallen trolls | yes |
| 20 | The reload rule; reload and change something | yes |
| 21 | Flee early, at movement 9+, leaving no bodies | partly (`OP_FLIGHT`) |
| 22 | Judge back-to-back fights together | partly (finale only) |

**Across the game**

| # | Strategy | Now |
|---|---|---|
| G1 | Choose the order of areas: take what the party can win, leave what's too hard, come back | no (plans set the route) |
| G2 | Keep levels ahead of the next stretch; train at once | partly |
| G3 | Collect the gear the game offers (search where the clues point) | partly (`search`, `revisit`) |
| G4 | Identify, ready and hand out gear to the right member | no |
| G5 | Use consumables when they matter | no (USE in fights handles scrolls only) |
| G6 | Weight and money: platinum, sell junk every town trip, the fee in hand | partly (`pooltake`, after the fact) |
| G7 | Rest and heal: the healing loop; the inn where camps fail | yes |
| G8 | Encounter choices: parley, WAIT, LEAVE, flee a band it can't beat | partly |
| G9 | Saves before risk | yes |
| G10 | A running party ledger: what we carry and from where, levels owed, unused magic, what's still out there | no |

## 3. Spells and consumables: the loadout review (Jeremy, 20:48-21:05)

**How it works now:** spells come from a plan's `picks` line (written by hand for one fight), the rest from the bot's
fixed fill (plans.py `PICKS`: cleric 1 Cure Light Wounds, Cure Light Wounds, Bless; 2 Hold Person; 3 Prayer;
magic-user 1 Sleep, Magic Missile; 2 Knock, Stinking Cloud, Mirror Image; 3 Fireball, Haste, Lightning Bolt; one Slow
Poison in the party). Scrolls are read in a fight only when the chosen spell is on a readied scroll; Restoration only
by the reload rule. **Potions, wands, javelins and the Necklace are never used.** Nothing asks what lies ahead.

**The loadout review:** before each stretch and each hard fight, the Player chat writes from the ledger and the
strategy file's list of what lies ahead: each member's spells; each scroll, potion and wand, who carries it and the
round it is used; what to sell or leave. **It thinks long term: nothing is spent that a later fight needs** (*Jeremy*,
21:05). A guide checks it for hard fights.

**Restoration scrolls** (*Jeremy*, 20:56): kept while a level drainer lies ahead; after the last one, sold. (Pool:
poolrad.md names no drainer after the graveyard; to be confirmed from the monster data, board.)

**The worked example: Pool's finale, as Jeremy would have gone in** (*Jeremy*, 20:56-21:01): cleric level 1 all Cure
Light Wounds; magic-user level 1 Charm Person; Stinking Cloud and Hold Person (both good); magic-user level 3 a Haste
per caster (for Tyranthraxus), the rest Fireball or Lightning Bolt (the guards); cleric level 3 all Prayer. The Potion
of Giant Strength on the best fighter for Tyranthraxus (by blows alone); the Potion of Speed (5:3); the Necklace of
Missiles and the Javelin of Lightning on the guards; healing potions with the front line. **The Player's first review
of the finale is measured against this.**

## 4. How the Player gets more capable (Jeremy, 20:48-21:05)

Three layers, cheapest first:
1. **The Player chat decides what needs judgement:** the game-level plan (G1, G4, G5, G10) and each hard fight's key
   turns (round 1, contact, any aimed spell) from a text field read; the tool carries them out.
2. **Try plans in ours first:** candidate plans played in ours from the Player's save, headless, many seeds, ORIGINAL'S
   BUGS on; the best one played in the original (search, not learning; only as good as ours' match in that fight, so
   every result is checked in the original). **Starts now on the Plan 2 chain's fights**, ahead of the arena.
3. **Rules only for routine turns:** tactics.py small and general (1, 8, 10 everywhere). No new per-fight switches.

**The order of work:** (1) preparation: the ledger, the enforced audit, the loadout review, USE of potions, wands,
javelins and the Necklace, the Restoration sale; (2) the field read and the chat's key turns; (3) try in ours; (4)
learning from Jeremy's play (board 2026-11-21 19:22, the Coach chat) alongside. Requests: the board, 2026-11-21 21:10.

**The measure:** the same fights from the same saves and seeds, before and after: losses before a win, HP lost, rounds,
guide sessions per hard fight (the fight rating when built). Baselines: the throne room 5 of 5 lost (Player 39, with
Haste); the finale's guards 1 of 7 by the reload rule (p42f1-f7), then 5 of 6 under Plan 5 with MANUAL (Player 43);
Tyranthraxus's flight 0 of 3 (Player 43).

## 5. The first two loadout reviews, read (Gold Box Guide 13, 2026-11-22 08:48-09:00)

Read: Player 44's throne room review and Player 45's finale review (lab `p44/reviews/throne.md`,
`p45/reviews/finale.md`; unchanged through Player 47), against the ledgers `s44loadout`, `s44door`, `s45ready`.

**Right:** the throne room kept the finale's items (Speed, the Necklace, the Javelin): the long-term rule applied;
two Fireballs a caster and the scroll Fireballs on the trolls, Prayer round 1 (won, p44g2). The finale matched
Jeremy's loadout on almost every line (clerics all Cure Light Wounds, Hold Person, Prayer; LIRA's Haste for him;
Giant Strength on BRAM, Speed on ARN; the Necklace and the Javelin on the guards; healing potions with the front line;
the guards' Rings +3 for saves), and said plainly that no Charm Person is in either book.

**Missed:** (1) **weight:** at the throne room's door (`s44door`) BRAM and CEDRIC moved 3 and DORN 6 (the trip's
loot); the review, written at the inn when all moved 12/9, assumed 9. (2) **unspent before the last fight:** ELWEN's
Fireball, Stinking Cloud and Hold Person scrolls, LIRA's Prayer scroll, CEDRIC's two Cure Light Wounds, ARN's Wand
of Magic Missiles (33). (3) LIRA's second level-3 spell Hold Person, not Fireball or Lightning Bolt (argued; p47k4
lost the guards to Hold Person saves). (4) Written once from the ledger of the fight before and never re-checked.
**What it says about the method:** the review is written once, at the inn, from a summary of the ledger; it doesn't
walk the ledger line by line and isn't checked again at the door, where things go wrong. The ledger's "over" and
"movement" sometimes disagree (`s45ready` BRAM 412 over, 12/9): to be checked.

**Decided (Jeremy, 09:00):**
1. **The review's method:** checked again **at the fight's door** against that day's ledger (the stop sits there);
   **every consumable in the ledger gets a line** (user and round, the fight it is kept for, or sold), the tool
   flagging any left out; **everything may be spent before the last fight, but no bad tactical choice just to use
   something up** (*Jeremy*); **movement 9 or more at the door**: coins and loot left or dropped before it.
2. **Restoration scrolls sold at the first Phlan visit after Valhingen Graveyard (4:10) is cleared** (drainers load
   only in 2:15, 4:2 and 4:10: main chat 98).
3. **The chat's key turns in stuck-list fights only.** The orders that won the guards (Player 47: clouds on the foes
   touching the fighters, no overlap; Hold Person on those in contact; a blow from each member on a held or clouded
   foe beside him) become the general rules; then `OP_PLAN5` is retired and the rules alone are measured against the
   chat on the same saves and seeds.
4. **Tyranthraxus' first breath** (2 of 5 tries lost before a menu of ours): **spread the party in the CONTINUE
   BATTLE rounds** before he comes; tried in ours first (main, step 3), then in the original. **Superseded
   2026-11-23:** the CONTINUE rounds' places don't carry (his fight forms from the party order), and main's breath
   order lost the guards' fight in the original (Player 50: game 0 of 5): keep Player 49's order (Jeremy, Q36). "Casters
   never strike him" is a guideline: ELWEN and LIRA strike him (Jeremy, Q34; Player 49: game 4 of 5).
5. **The throne room's escort: closed** (won from 6,3 without it).
6. **The measure adds:** deaths in wins, minutes of the Player chat per try, consumables left unspent.

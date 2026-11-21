# Gold Box Players' Guide

Tactics for SSI's Gold Box games, in the order you meet them as you play. Pool of Radiance's route, hard fights and
treasure are in `docs/strategy/poolrad.md`. Rewritten by Gold Box Guide 1 (2026-11-20) with Jeremy, section by
section. New lessons go in the Inbox at the end; the Lead folds them in daily.

## 0. How to read this guide

- **Tags** at the end of each line: *seen* (seen in the original game, DOSBox runs); *code* (read in the original's code:
  GAME.OVR, START.EXE, ECL scripts); *book* (the game's manual, reference card, cluebook or Adventurer's Journal,
  paraphrased); *players* (human players online, with links); *Jeremy* (a human player's experience, applied as a rule).
- **unconfirmed** marks a line nobody has checked yet. Each one is listed on the board as a request.
- **Brackets** after the tag say where the line was learnt (run, save, code address). They're for the lanes; players
  can skip them.
- **(Pool)** marks a rule read from Pool's own data. Later Gold Box games may change it: check each game.
- **Two rules above all:** audit the party before every hard fight (section 4), and reload on anything a human would
  reload for (section 6). *Jeremy*

## 1. Making the party

**Shape**
- **Six characters.** Count story NPCs as a bonus when they join, not as part of the plan. *Jeremy* The game allows up
  to 2 NPCs beyond the six. *book* (Manual)
- **Build for the game at hand;** before importing a party into the next game, check that game's race and level limits.
  Carrying one party through the whole series is not the goal; importing a finished party is a feature to test. *Jeremy*
  (2026-11-20)
- **Roles to cover within the six:** about four members who can fight in the line, two cleric casters, two magic-user
  casters, two bows and a thief. Multi-classes let one member fill two roles. Give one member exceptional Strength.
  *book* (Cluebook)
- Consider two clerics: they share the healing, and both can turn undead. *Jeremy*
- Don't inflate starting stats. Encounter sizes scale with how strong the party looks, so inflated stats bring bigger
  fights without the HP, spells or items to match. *book* (Cluebook)
- Check the game's training caps before choosing classes. Where the caps are low, multi-class demi-humans give up almost
  nothing. (Pool) Fighter 8, thief 9, cleric 6, magic-user 6. *book* (Manual)
  (Silver Blades) Every human class 15, thieves 18 in every race; the demi-human limits are Curse's (below). *book*
  (Silver Blades Journal p.47; strategy/silver-blades.md section 1)
- (Silver Blades) **New characters start at level 8** (magic-users 9, thieves 10); a demi-human whose limit is lower
  starts at its limit and never trains. A new party arrives about as strong as an imported one. *book* (Silver Blades
  Journal p.5)
- (Pool) Four classes only: cleric, fighter, magic-user, thief; no paladins or rangers, and no dual-classing (both come
  with Curse of the Azure Bonds). *book* (Pool Manual) + *players* ([GameBanshee, Curse party creation](https://www.gamebanshee.com/curseoftheazurebonds/walkthrough/partycreation.php))

**Races**
- **Choose classes first, then the races that make them work.** Pick the classes the party needs, then for each member
  the race that allows that class or multi-class. *Jeremy*
- **Demi-humans have level limits by race and class; humans have none.** For a party carried through the series these
  limits are the main thing to weigh. *Jeremy* (Pool) Dwarf fighter 9; elf fighter 7, magic-user 11; gnome fighter 6;
  half-elf fighter 8, magic-user 8; halfling fighter 6; thieves unlimited in every race. *book* (Pool Manual p.5)
  (Pool) **The training hall enforces them** (no table: compare-and-branch code), fighters only plus the half-elf
  cleric, by Strength 18+ / 17 / 16 or less: dwarf 9/8/7, elf 7/6/5, gnome 6/5/5, half-elf 8/7/6 (cleric 5), halfling
  6/5/4; magic-user limits aren't checked (the halls stop at 6 anyway). A capped class just isn't offered. Under the
  halls' caps (fighter 8, thief 9, cleric and magic-user 6) only the elf, gnome and halfling fighter limits (and a
  low-Strength dwarf's or half-elf's) are within reach. Ours does the same (LevelDrain.race_capped). *code* (Pool
  GAME.OVR 0x1C3F7-0x1C501; main chats 71-72)
  (Curse) Also enforced at the hall, by prime requisite 18+ / 17 / 16 or less: dwarf fighter 9/8/7; elf fighter 7/6/5,
  magic-user 11/10/9; gnome fighter 6/5/5; half-elf cleric 5, fighter and ranger 8/7/6, magic-user 8/7/6; halfling
  fighter 6/5/4; thieves, humans and half-orcs only by the XP table's top (thief 12, human cleric 10, fighter 12,
  paladin and ranger 11, magic-user 11). A capped class isn't offered ("Not Enough Experience" if nothing else can
  train). *code* + *book* (Curse GAME.OVR 0x24DDE-0x24F5B; Manual p.23; main chat 72)
  (Silver Blades) The printed limits are Curse's for every demi-human; only the top changes: humans 15 in every class,
  thieves 18. Whether its hall enforces them as printed: **unconfirmed** (request). *book* (Silver Blades Journal p.47)
- (Pool) Who may multi-class: dwarf, gnome and halfling fighter/thief; elf F/MU, F/T, MU/T, F/MU/T; half-elf as the elf
  and also with cleric. Humans are single-class. *book* (Pool Manual p.5)
- **Elves throw off Sleep and charm 90% of the time, half-elves 30%.** An elf or half-elf rolls that d100 for every
  effect put on it, but only Sleep and charm can be thrown off. *code* (START.EXE 0x2C540; effects 0x6B elf, 0x7C
  half-elf; SpecialAffects.blocks; Combat Chats 33-34) + *seen* for the half-elf (Combat Chat 33)
- Elves and half-elves find secret doors 2 in 5 instead of 1 in 5. *code* (ECL 7:22; Player 25)
- (Curse) The same multi-classes, plus the half-elf ranger and cleric/ranger; **humans dual-class** instead ("Human
  Change Class" at a hall: the old class stops, the new starts at level 1, both classes' abilities once the new level
  passes the old); **paladins** (human, lawful good, Cha 17+) and **rangers** (human or half-elf, good) are new.
  *book* (Curse Manual pp.4-8, 23; strategy/curse.md section 1)
- (Silver Blades) Curse's races, classes and multi-classes unchanged. The 10% XP bonus needs **16** in the prime
  requisite (paladins Strength and Wisdom, rangers Strength, Intelligence and Wisdom); Curse's manual said 15. *book*
  (Silver Blades Journal pp.3-4)
- **unconfirmed** (tabletop rules; requests to the lanes): dwarves and halflings get save bonuses from Constitution.

**Each member's job**
- **Fighters** hold the front line. They wear the best AC or carry the most damage, whichever the coming fight needs,
  and re-equip when the need changes (section 4). *Jeremy* (Pool) Only fighters, and multi-classes with a fighter
  class, can shoot bows. *code* (ITEMS class mask; Combat Chat 32)
- **Clerics** are good front-line fighters. Keep their AC low with the best armour and shield they can use. They manage
  the party's HP and can't do that dead. *Jeremy*
  - (Pool) No cutting weapons (swords, arrows) and no missile weapon at all. *book* (Manual) + *code* (ITEMS; main chat
    70) + *players* ([C64-Wiki](https://c64-wiki.com/wiki/Pool_of_Radiance))
  - From Curse on: a staff sling from the rear when necessary, for instance when badly wounded. *book* (Curse reference
    card) + *Jeremy*
- **The thief:** (Pool) make it a fighter/thief, because a pure thief can't use bows (only the sling). *Jeremy* + *code*
  + *players* ([GOG forum](https://gog.com/forum/forgotten_realms_collection/shifting_class_equippables_between_games_porpod/page1))
  - It fights from the back with a bow, steps into melee only when that's safe or needed (or it is clearly stronger
    than the enemies there), and backstabs with a fighter (section 5). *Jeremy*
  - From Curse on, pure thieves use short bows. *book* (Curse reference card) + *players* (GOG forum, above)
- **Magic-users** are necessary but limited: their few spells are saved for the fights that need them. *Jeremy*
  - Early on, Sleep in any fight that could turn tricky. Aim it to catch as many enemies as possible, and two squares
    off so it misses the party: it sleeps everything in its 3x3, the caster too. *Jeremy* + *seen* (spell lab, Combat
    Chat 33)
  - Out of melee except in an emergency or to finish a sleeping or held enemy, whom one blow slays. *Jeremy*
  - Darts for rounds with no spell worth casting; don't spend them in fights that don't matter. *Jeremy*
  - (Pool) Weapons: dagger, staff and **darts** (the manual omits darts). ITEMS gives the dart (type 9) the
    magic-user's class bit (1; class bits 93: magic-user, thief, fighter, paladin), and the original's own saves show
    DARKSTAR, a pure magic-user, with darts readied, the stack going from 11 to 8. *seen* + *code* (main chat 71: the
    Player lab's saves of the original; ITEMS) + *book* (Manual) DARKSTAR (magic-user 1) unreadied and READIED his 8
    Darts again in the original's camp. *seen* (check 71, main chat 73)
- **Before importing into Curse:** items stay behind (money becomes 300 platinum each); give every demi-human fighter
  18 Strength (two fighter levels in Curse); a human's 17 in a second class's prime requisite keeps a later dual-class
  open; have at least one woman (Hap's Swanmays). *book* + *players* (strategy/curse.md section 1)
- **Before importing into Silver Blades:** it takes characters from Curse only (Pool's come through Curse); items and
  money stay behind, the party arrives with nothing and the town gives it gear. Humans have room to grow (15; thieves
  18); demi-humans keep Curse's limits, and new characters start at 8, so a demi-human already at its limit gains
  nothing by import. *book* + *players* (strategy/silver-blades.md section 1)
- **Before importing:** (Pool) fighter/thieves can be dwarf, gnome, halfling, elf or half-elf, and their fighter caps
  differ (dwarf 9, half-elf 8, elf 7, gnome and halfling 6). *book* (Pool Manual) Players report the racial limits still
  hold in Pools of Darkness while humans go far higher, which makes demi-humans weak there. *players*
  ([GameBanshee](https://gamebanshee.com/poolsofdarkness/walkthrough/gameplaynotes.php),
  [GOG forum](https://gog.com/forum/forgotten_realms_collection/pool_of_radiance_lvl_draining)) Pools of Darkness's
  human cap (40 or 18; the sources disagree): **unconfirmed**.

**Example party for Pool** (Jeremy, 2026-11-20)

| # | Character | Line | Bow | Spells | Notes |
|---|---|---|---|---|---|
| 1 | Human fighter, exceptional Strength | yes | yes | | the anchor |
| 2 | Dwarf fighter/thief | yes | yes | | the thief; fighter cap 9 |
| 3 | Human cleric | yes | | cleric | |
| 4 | Human cleric | yes | | cleric | |
| 5 | Elf fighter/magic-user | yes | yes | magic-user | fighter cap 7, magic-user 11 |
| 6 | Human magic-user | | | magic-user | |

Five in the line, three bows, two clerics, two magic-users and a thief. A party that leans on multi-classed demi-humans
(half-elf cleric/fighters, elf fighter/magic-users) is stronger early in Pool but stops early (a half-elf cleric at 5:
*players*, [GameBanshee](https://www.gamebanshee.com/poolofradiance/races.php); *code*, the hall's check, main chat 72).

## 2. Gear

**Hands and readying**
- Each member holds two things in hand: sword plus shield plus bow doesn't work. *book* (Manual)
- A bow takes both hands: it can't be readied while a sword or shield is readied, and with the bow readied neither can.
  Unready both first (camp: VIEW, ITEMS); no message says why it's refused. *seen* (main chat 67, check 114)
- Ready the arrows as well as the bow. When joining stacks of arrows (JOIN), highlight the readied stack first: the
  joined stack keeps the highlighted stack's readied flag. *seen* (main chat 67, check 116)
- **Re-equip on the battlefield when the fight changes:** VIEW, ITEMS, READY works in combat; TRADE doesn't. *book*
  (Pool Manual) **READY (or unready) in a fight is free:** it leaves the member's turn as it was, so a member can switch
  from bow to sword (or back) and still attack; USE of an item does end the turn. *code* (GAME.OVR 0x222DF: READY
  0x2250A sets no turn flag, USE 0x22AC4 does; Combat Chat 35)
- When the readied arrows run out the original puts the sword back: ready the spare stack. A bow needs both hands
  (unready a Brass Mirror too). *seen* (Player 35)
- (Pool) **Bracers AC 6 are body armour that weighs nothing:** the game counts only the best body armour readied, so worn
  over Banded Mail (AC 4) they do nothing; they beat leather (AC 8) and no armour. Give them to the thief: DORN in
  leather, shield and DEX 17 goes from AC 4 to AC 2, and his thief skills don't suffer. *code* (ITEMS type 77, armour
  value AC 10 plus the item's 4) + *seen* (ARN AC -1 with them readied over Banded Mail, Player 33's graveyard save)
- **Choose weapons by expected damage:** the damage it deals and the chance to hit with it, together. *Jeremy*
- **Use a magic weapon when it's better, or when the enemy needs one.** *Jeremy*
- Fighters swap between their best-AC set and their most-damage set to suit the coming fight (section 4). *Jeremy*

**Who uses what** (Pool; *code*, ITEMS class mask, START.EXE DS:0x5D6, Combat Chat 32; a multi-class may use what any
of its classes may)

| Weapon | Shots a round | Range (squares) | Who |
|---|---|---|---|
| Bows | 2 | 16-22 | fighters only |
| Light crossbow (quarrels) | 1 | 19 | fighters only |
| Sling | 1 | 21 | fighters and thieves |
| Darts | 3 | 6 | fighters, thieves, magic-users (*seen*, main chat 71; the manual says dagger or staff only) |

Clerics have no missile weapon in Pool; from Curse on, clerics use staff slings and thieves short bows (section 1).

**What to keep** (the take rule; *Jeremy*, 2026-11-20)
- Take magic items, gems and jewellery, coins worth their weight, and anything else worth at least 100 GP. Leave the
  junk; never carry it back to town.
- Keep the arrows, quarrels and darts found in treasure; buy ammunition only when you run out. Darts are the exception:
  scarce as loot, so buy plenty for the magic-users on every town trip (section 9).
- Never sell Restoration scrolls.
- Keep gems and jewellery as items rather than cash: they weigh far less than coins. *book* (Manual)
- Monsters' ordinary weapons and armour don't appear as loot; leftover missiles are stacked. *book* (Manual)

**Weight and movement**
- **Keep everyone as mobile as possible: movement 6 is the floor.** *Jeremy* Weight slows a member: sixteen items each
  meant movement 3 in fights, and loot had to be left behind; so sell spare gear on every town trip (section 9). *seen*
  (Player 27)
- **The take rule's loot piles up** (seven spare Long Bows a fighter, spare Chain Mail, platinum) until five of six move
  3: drop the plain spares before a hard fight. Stojanow's west tower room was lost 5 of 5 at movement 3 and won at
  once at 9-12. *seen* (Player 35, p34e1-e5, p35b1) (Pool) The allowance at STR 18/100 is 3000 coins' weight: over by
  more than 1024 is movement 3, 768 is 6, 512 is 9. *code* (START.EXE 0xF40; ours party_member.gd)
- A member carries 16 items at most. A 17th item, or one over the weight limit, is refused with no message. *seen*
  (Player 10) TRADE to a member holding 16 items fails silently: drop first. *seen* (Player 35)

**Ammunition**
- Save magic ammunition (Arrows +1 and the like) for very hard fights; a magic bow can be used any time. *Jeremy*
- (Pool) **A shot is magic when the bow is magic:** the game checks the readied bow; a magic arrow counts only when it is
  the last of its stack. So a Bow +1 lets an archer hurt wights and spectres. *code* (combat.gd `_spend_shot`, the
  original's rule as ours reproduces it; not yet seen against a magic-only enemy)

**Magic items and scrolls**

**The magic-item rule** (*Jeremy*, 2026-11-20, Gold Box Guide 2)
1. **Use before selling.** A magic item that beats what a member has readied goes to that member and is readied; the
   audit table (section 4) lists anything carried and not readied.
2. **Sell only what nobody can use better,** and keep a magic weapon (melee or bow) for every member who fights: some
   enemies are hurt only by magic weapons. A weapon with a plus beats the same weapon without; a plain weapon can still
   beat a small magic one by its dice (a plain Two-Handed Sword d10 against a Dagger +1 d4+1) where magic isn't needed.
3. **Identify before selling.** Readying an item and comparing the stats shows who should have it; it is identified
   (a shop, 200 gp) before any sale.
4. **Wands, scrolls and potions are reserved for named fights** (the game's strategy file names the fight for each);
   charges left after their fight go to other hard fights, never to an easy one.
5. **Restoration scrolls** are never sold, and are spent on the drain that can't be reloaded around.
6. **Movement 6 or better for everyone, always:** junk goes first; magic items stay unless rule 2 sells them.
7. **Cursed items** are marked and never readied outside a lab.
8. **Magic-user scrolls:** copy each spell the magic-users don't know into the spellbook first; we want every spell
   in the game. Then keep or reserve the scroll by rule 4.

- Unidentified magic items show without their plus in the item list: identify them before a hard fight (section 4).
  *seen* (Player 32)
- To read a clerical scroll: VIEW, ITEMS, READY it (both hands free: weapon and shield off), then USE, CAST, and pick
  the target. USE does nothing on a scroll that isn't readied. *seen* (Player 32, p32s1-s4)
- Clerics cast from cleric scrolls with no preparation; magic-users need Read Magic first. *book* (Manual) A scroll is
  held in both hands, so a fighter-mage puts the weapon away to read one in a fight. *seen* (Player 37)
- (Pool) **USE casts any scroll's spell** for a cleric or magic-user, with no level test (a level-1 magic-user can read
  a Fireball scroll). *code* (GAME.OVR 0x22AC4; Combat Chat 35) **A scroll's spell goes off at caster level 6, whoever
  reads it;** potions and other item spells (Speed, Giant Strength, Healing...) at level 12. So a low-level
  magic-user gets a level-6 buff or Fireball (6d6) from a scroll, a higher one no more. *seen* + *code* (Combat Chat 38,
  p37i1's spectres, draws 744-749; main chats 79-80, checks 179-187; START.EXE 0xBA:0x26C2) (Combat Chat 35's "at the
  reader's own level" was wrong.)
- (Pool) **SCRIBE** (copying a magic-user scroll into the book):
  - copies only a spell of a level the magic-user already has slots for ("YOU CAN NOT SCRIBE THAT SPELL": a level-1
    magic-user can't copy Stinking Cloud). *code* (GAME.OVR 0x1838D; Combat Chat 35)
  - takes only a scroll already identified (read): Read Magic does it, and so does a shop's ID; an unread scroll lists
    nothing. *seen* (main chats 76-77, checks 159-168; Player 37)
  - costs rest time (4:15 for one 1st-level spell; Pool's nine spells took 11, 9 and 7.5 hours) and leaves the scroll's
    other spells on it; a one-spell scroll is used up. *seen* (main chat 76; Player 37, p37b2)
  - **one scroll a rest:** once a copy uses a scroll up, nothing more is copied until the next REST (the time offered
    still counts every marked spell), so plan one rest per scroll the marks will empty. *seen* + *code* (Player 37's
    p37b2, three rests for nine spells on five scrolls; Combat Chat 38, GAME.OVR 0x247B3)
- **A potion is drunk only from a free hand:** USE does nothing until it is READIED, and with weapon and shield readied
  READY refuses it, with no message: unready the shield first. USE then drinks it without a message. (Pool) Healing
  heals 2d4+2; Giant Strength gives STR 21/00 for (d4 x 10) + 40 minutes; Neutralize Poison drunk by a member who
  isn't poisoned heals 1d4+8. *seen* (main chats 73, 77, 80; checks 137, 164-168, 188)
- (Pool) **Cloak of Displacement:** the first attack roll above 1 against its wearer in each fight misses, once a
  fight; the rest of the fight it does nothing. *code* (effect 0x59, GAME.OVR 0x110EB; Combat Chat 35) + *seen* (on
  Tyranthraxus, Player 6's draw 860)
- (Pool) **Rings of Protection:** two can be worn but only the better plus counts for AC, and magic body armour (+1 or
  better) cancels a ring's AC (its saving-throw plus still counts). *code* (START.EXE 0xE22; Combat Chat 36)
- Only a readied mirror turns a basilisk's gaze back, and it needs a free hand: READY refuses it when the hands are full.
  *code* (GAME.OVR 0x10908) + *seen* (Player 17)

**Undead**
- **Some undead need a magic weapon and some don't;** skeletons and zombies, for example, fall to plain weapons.
  *Jeremy* Where they do need one, give every front-liner a magic weapon before the fight, trading them round the party.
  In Pool, wights need one: a plain mace left a wight untouched for five rounds. *seen* (Player 32, p32b8)
- (Pool) **Which undead need what:** wights are hurt only by magic or silver weapons; wraiths take full damage from
  magic weapons, half from silver, none from others; a mummy takes half damage from magic weapons; monsters flagged
  0x77 are hurt only by magic weapons. Any plus counts: no "+2 or better" rule appears in the code. *code* (Combat Chat
  34; special_affects.gd, GAME.OVR category 5) Later games: **unconfirmed** (request to Combat).

## 3. Spells

**Memorizing**
- Fill every spell level before a hard fight, not just level 1: a party that fought with its level-2 and level-3 slots
  empty lost fights it could have won. *seen* (Player 27, Stojanow report)
- Camp and memorize before each event: a party that reached a 30-figure fight with its Sleep spells used up lost.
  *seen* (Player 15, p15c1/p15c2)
- Rest time to memorize: 4 hours plus 15 minutes for each spell, counted for the member with the most to learn. *seen*
  (Player 15) (The manual says 15 minutes per spell level: plan by the *seen* figure.) An interrupted rest keeps only
  the spells already finished, in the order picked. *book* (Manual)
- Keep one Slow Poison memorized in the party, in a cleric's first free level-2 slot. *code* (Player 27)
- The magic-user's LEARN page and camp CAST's spell list open on the *last* spell; End wraps to the first. Check which
  spell is lit before choosing. *seen* (Player 3; main chat 65, check 102)
- Spells cast in camp last into the next fight while their time runs (Bless, Prayer, Protection from Evil). *seen*
  (Player 33, p33c3) At low level that is minutes (section 4's buffs).
- **Rest before you break camp:** spells picked under MEMORIZE are learnt only by resting in that same camp; leave camp
  (or save and load) first and the picks are gone. *seen* (main chat 83, checks 218-224)
- Two Blesses (or two of any spell) on one member are two records. *seen* (main chat 83)

**What the game gives the casters** (Pool; *code*: START.EXE class tables, read 2026-11-20)

**A spell's level needs a caster level** (*Jeremy*, 2026-11-20, Gold Box Guide 2; *code*: the slot tables below)

| Spell level | Cleric level | Magic-user level | Examples |
|---|---|---|---|
| 1st | 1 | 1 | Bless, Cure Light Wounds; Sleep, Magic Missile, Shield |
| 2nd | 3 | 3 | Hold Person (cleric), Spiritual Hammer; Stinking Cloud, Mirror Image |
| 3rd | 5 | 5 | Prayer, Dispel Magic; Fireball, Lightning Bolt, Haste, Slow, Hold Person (magic-user) |
| 4th+ | 7 | 7 | beyond Pool's caps (cleric 6, magic-user 6): Curse of the Azure Bonds on |

(Silver Blades) Higher spell levels: cleric 6th at level 11 (only with Wisdom 17+); magic-user 6th at 12 (Intelligence
12+) and 7th at 14 (Intelligence 14+); rangers' druid 2nd at 12. *book* (Silver Blades Journal pp.55-57)

A multi-class casts by its level in that class: a fighter 5 / magic-user 4 has second-level spells, not Fireball.
(Pool) A scroll's spell above the magic-user's level can be cast from the scroll (at level 6) but not copied into the
book (section 2). *code* + *seen* (Combat Chats 35, 38)

| Level | Cleric (before Wisdom) | Cleric, Wisdom 17-18 | Magic-user |
|---|---|---|---|
| 1 | 1 | 3 | 1 |
| 2 | 2 | 4 | 2 |
| 3 | 2/1 | 4/3 | 2/1 |
| 4 | 3/2 | 5/4 | 3/2 |
| 5 | 3/3/1 | 5/5/2 | 4/2/1 |
| 6 (cap) | 3/3/2 | 5/5/3 | 4/2/2 |

- (Pool) **Wisdom's bonus spells hold at every level:** 13 and 14 each add a first-level spell, 15 and 16 each a
  second-level, 17 a third-level, each once the cleric has that level's spells; Wisdom 18 adds no more than 17. The
  original's own records: CEDRIC (WIS 18) at levels 1-6 has 3, 4, 4/3, 5/4, 5/5/2, 5/5/3; DIRTEN (WIS 16) at 4-6 has
  5/4, 5/5/1, 5/5/2. *seen* (main chat 71: record bytes 0xB2-0xB4 in the Player lab's saves) + *code* (our engine,
  party_member.gd) Intelligence adds no spells.
- Clerics know every cleric spell. A magic-user's book starts with 4 first-level spells and gains one a level, plus
  what is copied from scrolls, so its picks matter. *book* (Manual)

**Casting in a fight**
- **Some spells go off at once; the rest go off at the caster's next turn, aimed then, and a hit in between spoils
  them.** *Jeremy* + *code* (START.EXE spell table, byte 12)
  - At once: every first-level magic-user spell but Read Magic, every second-level magic-user spell, Blink, Detect
    Magic, Slow Poison.
  - Next turn: every other cleric spell (Cure Light Wounds, Bless, Hold Person, Prayer...) and the third-level
    magic-user spells (Fireball, Lightning Bolt, Haste, Slow, Hold Person...). Cast these before the lines meet: Hold
    Person and Prayer begun in melee never went off. *seen* (Player 30, p30d1/d3/e1)
  - The rule: a spell whose casting time (byte 12) is 3 or more rounds' worth BEGINS CASTING and goes off at the
    caster's next turn; under 3 it goes off at once. Bless (10) and Cure Blindness (10) wait; Hold Person (5) waits
    one. *code* (Combat Chat 34; GAME.OVR 0x14C0F)
- A caster wounded before a begun spell goes off LOSES A SPELL but keeps it in memory. *seen* (Combat Chat 33) + *code*
  (Combat Chat 34) (Pool's original takes the copy from the attacker's memory instead, if it has one: START.EXE
  0xBA:0x148B.) It loses the spell but not the turn: at its next turn it still has its full movement and attacks, so a
  spoiled cleric can still walk up and fight. *seen* (Combat Chat 37, Player 35's p35i6; GAME.OVR 0x14CFE)
- A caster hit recently can't choose CAST: guard casters with fighters. *book* (Manual)
- In a fight's CAST list Home moves the highlight up and End down; it opens on the last spell, and long lists page with
  NEXT. EXIT from a spell's aim asks ABORT SPELL? *seen* (Player 30)
- Magic resistance is rolled for each target after its save; a creature's spell can catch the creature itself. *code*
  (GAME.OVR 0x115BF; Player 6)
- In an anti-magic area, CAST does nothing, even in camp: heal there by resting. *seen* (Player 25; Pool's place is in
  poolrad.md)

**Computer-run casters (QUICK)**
- **QUICK members cast only with MAGIC ON: press Alt-M in every fight,** because the game turns it off at each fight's
  start. *code* (GAME.OVR 0xE457) + *seen* (Player 15)
- QUICK casters often swing instead of casting: they never cast Prayer or Stinking Cloud in three tries, and the clerics
  left Bless unused. **Cast key spells by hand.** *seen* (Stojanow report)
- The computer never aims an area spell where it would catch its own side, so once the lines meet QUICK casters seldom
  cast Sleep, Stinking Cloud or Fireball. *book* (Manual, Cluebook) + *seen* (Combat Chat 33)
- QUICK still throws Hold Person and Sleep at monsters they can't affect (ettins). *seen* (Player 27, p27a1)
- QUICK suits weak hordes, not boss fights; QUICK members always use readied magic items and shoot readied bows when no
  enemy is adjacent. *book* (Manual, Cluebook)
- The computer's choice: each turn it tries spells by priority: 7 Sleep, Stinking Cloud, the cleric's Hold Person,
  Fireball, Lightning Bolt; 6 Magic Missile, Charm Person, the magic-user's Hold Person, Prayer; 5 Slow, the cleric's
  Dispel Magic; down to 1 Protection from Evil. *code* (START.EXE spell table byte 13; Combat Chat 33)
- A pure magic-user run by the computer (an enemy mage, or a member on QUICK) never walks towards a foe: with nothing
  to cast or use in range it stands on guard, so a lone enemy mage stays where the fight put him. *code* + *seen*
  (Combat Chat 38, GAME.OVR 0xB44E; Player 36's p36e1, YARASH in 7:23 stood all fight twice)

**Prefer restraint to damage**
- One blow kills a sleeping or held enemy, so Sleep, Hold Person and Stinking Cloud usually beat damage spells. *book*
  (Cluebook)
- **Among the cleric spells, healing comes first.** A member knocked out loses the fight's experience (section 6), and
  too big an experience gap between members can sink a run. *Jeremy*

**The spells** (Pool; *seen* in Combat's spell lab, Combat Chats 33-34, unless marked; "level" is the caster's level in
the spell's class)

- **Sleep** (magic-user 1; at once; no save). *Jeremy:* the spell to cut the enemy down at low levels; it can take out
  the Slums' ogres. It sleeps 4d4 hit dice of creatures (about 10 a cast; kobolds and orcs cost 1 each), so everything in
  the 3x3 sleeps, **the caster too**: aim it two squares off (a lone caster aiming at the next square put the party to
  sleep and it was destroyed). Not big monsters (ettins) or a level-6 magic-user (*seen*, Stojanow); short range (*book*).
  An ogre goes down now and then, a troll or a spectre never: on the Slums' ogres and trolls (2:20 0,14), 10 casts
  (4d4 = 7-13) put 2 ogres to sleep and no troll. *seen* (Combat Chat 34; each fight matched ours draw for draw)
- **Stinking Cloud** (magic-user 2; at once; range 3). *Jeremy:* very good for taking out casters and making fights
  easier.
  - **The cloud is 2x2:** the aimed square and the squares right, below and below-right. With enemies to your right or
    below, aim one square past the nearest so you stay outside.
  - A **failed** save vs poison: helpless d4+1 rounds, its turn lost at once. A **made** save only "starts to cough":
    for a round no spell or item and AC 2 worse, but **not helpless**, whatever the manual says. *code* (GAME.OVR
    0xF6C0) + *Jeremy*
  - **The cloud stays for the caster's level in rounds**; anyone in it saves again each round. **The computer never
    walks into it**, so a cloud across a corridor holds monsters back. *seen* (Combat Chat 34)
  - Kobolds resist 25% of the time; orcs need about 13-16. Bunched ettins in a cloud died to single blows. *seen*
    (Player 30, p30d2)
  - On ogres and trolls it works about half the time (23 saves, 13 failed, 10 made); spectres ignore it. *seen*
    (Combat Chat 34, the spell lab on 2:20 0,14)
- **Hold Person** (cleric 2, next turn, 3 picks; magic-user 3, next turn, 4 picks; save vs spell; man-sized only).
  *Jeremy:* great for taking out annoying enemies with poorer saves. The cleric's lasts 4 + 1/level rounds, the
  magic-user's 2/level. A held figure is slain by any blow and loses its guard and any spell it was casting. Use it on
  enemy casters (they are persons). **By hand:** after each TARGET the aim starts again on the caster, so press NEXT to
  the next figure; a figure picked twice costs no pick; EXIT uses up a pick; when the picks run out the spell goes off on
  those taken. *seen* (Combat Chat 34) It never held trolls (7 casts) or spectres (8): they aren't persons. *seen*
  (Combat Chat 34)
- **Magic Missile** (magic-user 1; at once). *Jeremy:* the first-level spell once Sleep no longer serves. Never misses
  (no roll, no save), ignores most resistances (good on undead), interrupts enemy casting; Shield cancels it. *book*
  **In the original Pool a level-1 magic-user's does nothing** (level / 2 missiles, rounded down: *code*, GAME.OVR
  0x28451; an original bug: ours fixes it unless SETTINGS ORIGINAL'S BUGS is on). Enemy mages' Magic Missiles finish
  wounded members: kill the mages first. *seen* (Stojanow report)
- **Charm Person** (magic-user 1; at once). *Jeremy:* can turn the tide in some battles.
- **Fireball** (magic-user 3; next turn). *Jeremy:* loosens up large groups, best on many low-HP enemies. The caster's
  level in d6, half on a save; 7x7 indoors (radius 3), radius 2 outdoors; a caster aiming within 3 squares burns
  himself.
- **Lightning Bolt** (magic-user 3; next turn). *Jeremy:* great if you can get it bouncing round right; it depends on the
  map. It bounces off walls: mind your own party. *book* From the aim square it runs 8 squares' worth (a diagonal step
  costs 1.5); each wall turns it back along its line, and the first bounce costs 4 squares more when the caster stands
  within 4 squares of that wall; every figure on its path (party and caster too) saves for half. **Aim it along a long
  open line, not at a near wall with friends or the caster between.** *seen* + *code* (Combat Chat 36: BAKSHI,
  magic-user 4, hit by his own bolt in the kobold caves; GAME.OVR 0x29973)
- **Slow** (magic-user 3; next turn; no save). *Jeremy:* useful against enemies with several attacks. As many figures
  as the caster's level, nearest the aim point first; 3 + 1/level rounds; halves movement and attacks (a one-attack
  monster strikes every other round); on a hasted figure it only ends the Haste.
- **Haste** (magic-user 3; next turn). *Jeremy:* turns your fighters into killing machines. The caster's level in
  allies; 3 + 1/level rounds; doubles movement and attacks; each target ages a year; on a slowed figure it only ends the
  Slow. A hasted caster still casts one spell a turn (a cast ends the turn): Haste the fighters. *code* (Gold Box Guide 2)
  **Don't recast it on a hasted member:** with the old one's time all left it adds a record and nothing else; with less
  left, the old one goes and the member ages another year. *seen* (main chat 84, checks 235-238) (Pool) Cast in camp
  it reaches the first members in party order (as many as the caster's level): put the fighters first (poolrad.md
  section 4).
- **Friends** (magic-user 1; camp): +2d4 Charisma (at most 25) for 1 minute a level: cast it just before a talk. A
  second Friends of equal length raises Charisma again; a longer one gives back the first one's starting Charisma.
  *seen* (main chats 81, 83)
- **Bless** (cleric 1; next turn, a long delay). *Jeremy:* can be used well, but he rarely does: try it. +1 to hit for 6
  rounds, only for members not yet in melee. *book* + *seen*
- **Prayer** (cleric 3; next turn). Within 6 squares of the caster, the party +1 to hit and on saves and enemies -1, 1
  round a level: cast it from the middle of the line, not the back. *code* (GAME.OVR 0x2B04A) + *seen* (p29d1)
- **Protection from Evil** (cleric 1, next turn; magic-user 1, at once). +2 on saves against evil attackers (its -2 to
  be hit is overwritten before the roll); it **doesn't stop level drain**. *book* + *code* (Combat Chat 32, GAME.OVR
  0x10FFF)
- **Enlarge** (magic-user 1; at once; camp or fight) on a fighter, before or during a fight. *Jeremy* + *code* (spell
  table) **Strength** (magic-user 2) is camp only. *code*
- **Silence 15'** stops enemy casters. *book* **Slow Poison** keeps a poisoned member alive until a temple (section 6).
  *book*
- **Animate Dead** (cleric 3; a fight spell). Each dead figure (not already undead) in its area, up to a number set by
  the spell's power, gets up on the caster's side ("is animated") at full hit points, as undead (TURN works on it),
  with no memorized spells, movement 6, attack level 0; brought to 0 again it dies for good. Works on monsters and on
  fallen members alike. Not yet in ours (docs/coverage.md, spell 36). *code* (main chat 71: GAME.OVR 0x29087,
  0x2C753) Cast in camp it raises the first dead members in party order, up to the caster's level; elves and
  half-elves rise too. *seen* (main chat 84, checks 235-238)

The rest of Pool's list, with suggested uses (Jeremy, 2026-11-20: "a good starting point"; to be tried in play or the
arena):
- Cleric: **Cure Light Wounds** (the healing priority); **Detect Magic** (at once; which loot is magic: part of the
  audit); **Resist Fire** / **Resist Cold** (before a known fire or cold fight: fire giants, breath, enemy Fireballs; the
  cluebook suggests Resist Fire for the finale); **Spiritual Hammer** (a magic weapon for the cleric, for enemies plain
  weapons can't hurt); **Dispel Magic** (ends enemy effects, frees our held or charmed); **Find Traps** (camp);
  **Cure Blindness**, **Cure Disease** (camp only), **Remove Curse** (save the temple's 1000, 1000, 3500); **Snake
  Charm** (snakes only); **Curse**, **Cause Light Wounds**, **Cause Blindness**, **Cause Disease**, **Bestow Curse**,
  **Protection from Good** (rarely worth a slot); **Animate Dead** (above: raises the fallen, enemies or ours, to fight for the party);
  **Restoration** is in the table at cleric level 7, beyond Pool's cap: scrolls only.
- Magic-user: **Shield** (at once; stops Magic Missile, better AC: for a mage facing mages); **Mirror Image** (at once;
  keeps the mage alive against enemy spells; (Pool) **not against blows**: an image takes only a spell aimed at its owner,
  never a weapon or a touch, unlike the tabletop rule: the original's bug #14 (docs/original-bugs.md; fixed in ours unless
  ORIGINAL'S BUGS is on) *code* (GAME.OVR 0xF61B) + *seen* (2:9's two magic-users, Combat
  Chats 6-7, matched to the fight's end); so no help against drainers); **Ray of Enfeeblement** (cuts a big melee enemy's damage: ogres, giants); **Read Magic** (camp;
  for scrolls); **Knock** (camp; locks); **Friends** (camp; Charisma for a parley); **Protection from Normal Missiles**
  (archer-heavy fights); **Protection from Evil 10'** (the party version); **Blink**, **Invisibility**,
  **Invisibility 10'**, **Detect Invisibility**, **Reduce**, **Burning Hands**, **Shocking Grasp** (touch spells: poor
  for a mage who stays out of melee); **Dispel Magic**.

**Turning undead**
- **TURN every time undead appear, once per cleric per fight, in round 1, before casting or fighting.** *Jeremy*
  TURN with no undead on the field says NOTHING HAPPENS and spends the cleric's TURN for the fight. A level-5 cleric
  turned both of 4:10's spectres. *seen* (Combat Chat 34)
- QUICK clerics (and paladins from level 3) turn by themselves once a fight, at their first turn with undead in sight,
  so taking control of one after its first turn leaves no TURN on the menu. *code* (GAME.OVR 0xADC3) + *seen* (the
  graveyard, Combat Chat 5; Combat Chat 34)
- The lowest cleric level that can turn: wights 1, wraiths 3, mummies 4, spectres 5, vampires 6; a level-6 cleric
  destroys skeletons and zombies outright. *book* (Journal, Cluebook)
- (Pool) The d20 needed: a wight 20 / 19 / 16 / 10 / 7 / 4 at cleric levels 1-6; a spectre can't be turned below level
  5, then 20 / 16 / 13 / 10 at 5-8: against spectres, fight with magic weapons. *code* (Combat Chat 32)

**Example spell lists (party A; Jeremy, 2026-11-20: a starting point)**

Clerics (Wisdom 17-18; CLW = Cure Light Wounds, PfE = Protection from Evil; levels 1 / 2 / 3 split by "/"):

| Level | Healer (human cleric 1) | Battle cleric (human cleric 2) |
|---|---|---|
| 1 | CLW x2, PfE | CLW x2, PfE |
| 2 | CLW x3, PfE | CLW x2, PfE x2 |
| 3 | CLW x3, PfE / Hold x1, Slow Poison, Spiritual Hammer | CLW x3, PfE / Hold x3 |
| 4 | CLW x4, PfE / Hold x2, Slow Poison, Sp. Hammer | CLW x3, PfE x2 / Hold x3, Sp. Hammer |
| 5 | CLW x4, PfE / Hold x2, Slow Poison, Sp. Hammer, Resist Fire* / Prayer, Dispel Magic | CLW x3, PfE x2 / Hold x3, Sp. Hammer x2 / Prayer x2 |
| 6 | as 5 / as 5 / Prayer, Dispel Magic, Cure Blindness* | as 5 / as 5 / Prayer x2, Dispel Magic |

\* swapped in for known fights (Resist Fire: fire giants, the finale; Cure Blindness and Cure Disease after the mummies).
Bless, if wanted, takes a PfE slot.

Human magic-user: book Sleep, Magic Missile, Shield, Charm Person; then Stinking Cloud (3), Mirror Image (4), Fireball
(5), Lightning Bolt (6).

| Level | Memorized |
|---|---|
| 1 | Sleep |
| 2 | Sleep x2 |
| 3 | Sleep x2 / Stinking Cloud |
| 4 | Sleep, Magic Missile, Charm / Stinking Cloud x2 |
| 5 | MM x2, Sleep, Charm / Stinking Cloud x2 / Fireball |
| 6 | MM x2, Charm, Shield / Stinking Cloud, Mirror Image / Fireball, Lightning Bolt |

Elf fighter/magic-user (its magic-user level trails): book Sleep, Enlarge, Charm Person, Magic Missile; then Stinking
Cloud (3), Ray of Enfeeblement (4), Haste (5), Slow (6).

| Level | Memorized |
|---|---|
| 1 | Sleep |
| 2 | Sleep, Enlarge |
| 3 | Sleep, Charm / Stinking Cloud |
| 4 | Sleep, Enlarge, Charm / Stinking Cloud, Ray of Enfeeblement |
| 5 | Charm, Enlarge, MM, Shield / Stinking Cloud x2 / Haste |
| 6 | as 5 / as 5 / Haste, Slow |

Scrolls (Kovel, Bane's temple) add Hold Person, Haste, Slow and Fireball copies: adjust the books when they're found.

## 4. Before a fight

**The party audit: before every hard fight** (*Jeremy*, 2026-11-20; ai-business-ideas ideas/game-modernizer.md). A hard
fight: a scripted battle, a boss, a known killer, or anything the game's strategy file flags.

1. **Levels:** the party is at the level this stretch needs (the method below; poolrad.md gives Pool's), and everyone
   who qualifies has trained.
2. **Gear:** each member's best weapon and armour readied; fighters in the AC set or the damage set, whichever this
   fight needs (section 2).
3. **Magic weapons:** where the enemy needs them (some undead), every front-liner has one, traded round the party.
4. **Spells:** every slot at every level full, with spells that suit this fight (Resist Fire for fire, Slow for
   multi-attackers...).
5. **Items:** magic items identified and readied; wands and potions with the members who will use them.
6. **Weight:** junk sold; movement 6 or better for everyone (section 2).
7. **Health:** everyone at full HP; no poison, disease or drain left untreated.
8. **A save** just before the trigger, so that a loss costs minutes, not an hour. *Jeremy* + *book* (Curse reference
   card: "go back to your last saved game")

**The audit table** (*Jeremy*, 2026-11-20, Gold Box Guide 2): printed before every hard fight (the Player's tool at each
checkpoint before one), one row per member: levels; experience per class and the total earned (per class x classes);
**levels owed now**; the next level and the experience still to earn for it; HP; AC; THAC0; movement; magic items
carried but not readied. Then the party's totals: HP, the disablers (Sleeps; Hold Person casts and picks; Stinking
Clouds), cures, Restoration scrolls, the reserved items for this fight, and the members at AC 0 or better. **Flags:**
any level owed; a level within 500 experience of a member (a short detour may be worth it); gear not readied; anyone
below movement 6; undead ahead without magic weapons for the fighters or Restoration scrolls in the packs. Example:
docs/strategy/stuck-fights.md (Sokal Keep: DORN owed fighter 2, ELWEN and LIRA within 354 and 170 of a level;
Stojanow: LIRA 452 from magic-user 5, i.e. Fireball).

**A failed audit** means fixing it first: earn levels on mop-up fights and train, then plan the tactics by hand. Cheats
(save edits, auto-level, teleports) are a last resort. *Jeremy*

**Is the party's level right?** (the method; *Jeremy*, 2026-11-20) Three signals, cheapest first:
1. **Players' reports:** the levels human players had when they took the stretch (*players*, with links, in the game's
   strategy file).
2. **A fight rating from the game's data:** for each hard fight, the expected rounds the party needs to kill the enemy
   against the expected rounds the enemy needs to drop the party, at the party's real stats. Well above 1: ready; below
   1: earn levels first. (To be built after Stage 1; board request.)
3. **Results:** under the audit, two losses in three tries means under-levelled.

**Train as soon as anyone qualifies.** If the funds are short, go and get them (treasure, mop-up fights), then come
back. *Jeremy* Training cuts experience to "the level after next, less 1", so experience above that is lost: a
multi-class left long untrained lost experience, and one party carried four untrained levels into the graveyard's
spectres. *seen* (Player 3; Player 33)

**Buffs: long ones in camp, short ones at the pivotal moment** (*Jeremy* + *code*: START.EXE spell table, bytes 4-5; a
round is a minute; "a level" is the caster's level)
- In camp just before the trigger, the long buffs: Strength (60 rounds a level), Enlarge, Resist Fire, Resist Cold,
  Protection from Normal Missiles (10 a level), Shield (5 a level), Protection from Evil (cleric 3 a level; magic-user
  and the 10' radius version 2 a level), Mirror Image (2 a level). Spells cast in camp carry into the fight while their
  time runs. *seen* (Player 33, p33c3) **At low level they last minutes:** a 1st-level cleric's Protection from Evil 3
  minutes, a 1st-level magic-user's Shield 5 and Enlarge 10, and a 10-minute REST ends them: cast them right before
  the fight, not at the last camp. Enlarge on a member already at 18/00 raises nothing. *seen* (main chat 78, checks
  173-175)
- In the fight, at the pivotal moment (the turn before the lines meet, the round the boss closes): Bless (6 rounds),
  Prayer (1 a level), Haste (3 + 1 a level), Spiritual Hammer (1 a level).
- The cluebook and Curse's card say to cast everything (Bless, Prayer, Protection from Evil, Enlarge, Invisibility 10',
  Haste) in camp on the square before the trigger, then step in. *book* The durations above say which of those last.

**Before any fight**
- **Press Alt-M (MAGIC ON)** at the start of every fight if anyone is on QUICK (section 3). *code* + *seen*
- **Marching order:** four in front to protect the back, one shooting from the back, the magic-user held in reserve
  (section 5). *Jeremy* Archers in the back: a missile can't be fired with an enemy adjacent. *book* (Manual)
- **Judge back-to-back fights together:** a fight that follows another with no camp between is fought with the first
  fight's damage and without its loot readied. *seen* (Player 29, p29b2: Tyranthraxus after his guards)

**The game isn't a straight line.** Knock out what you can, move forward, and come back to what's too hard. *Jeremy*
Answering LEAVE puts some fights off to be taken later at a higher level. *seen* (Players 15, 23)

## 5. In a fight

**The line**
- **Four in front to protect the back; one shooting from the back; the magic-user held in reserve.** *Jeremy*
- **Fighters GUARD only when no enemy can be reached;** otherwise they move toward the enemy and form a line of four,
  or three with the fourth covering the corner. *Jeremy* (Gold Box Guide 2, 2026-11-20 13:19)
- Outnumbered: hold a short line at a doorway or corridor, focus on one target at a time, keep a reserve to fill gaps.
  Spread out against breath weapons and area spells. *book* (Cluebook)
- Keep archers and dart-throwers out of reach: a missile can't be fired with an enemy adjacent. *book* (Manual)

**Never give the enemy free attacks** (*Jeremy*)
- Stepping away from or past an adjacent enemy gives it a free blow at your back: never walk weak or wounded members
  past enemies. *book* (Manual)
- The enemy gets that blow only if its turn this round is still to come, or it hasn't struck yet, or you step past its
  front: step away just after it has acted. *code* (GAME.OVR 0x132F8; Combat Chat 34)

**Attacking**
- **Gang up:** the first two attackers strike a defender's front; the third and later strike its rear, at a much worse
  AC. Put three or four on the dangerous enemy. *book* (Manual)
- **Kill the casters first:** enemy mages' Magic Missiles finish wounded members; Hold Person or Stinking Cloud them
  (section 3). *seen* (Stojanow report)
- **Finish the helpless before they can act.** A sleeping or held enemy dies to any one blow, so you can keep killing
  the others until just before it wakes, then finish it. *Jeremy* + *book* + *seen* (Player 30) How long they stay
  helpless: Sleep 5 rounds a caster level; Hold Person 4 + 1 a level (cleric) or 2 a level (magic-user); Stinking
  Cloud's nausea d4+1 rounds. *code* (START.EXE spell table; GAME.OVR 0xF6C0)
- **Backstab** (section 1): a fighter attacks first, then the thief attacks from the square directly opposite (Delay
  until the monster has moved). Damage x2 at thief levels 1-4, x3 at 5-8. *book* (Manual, Cluebook)
- A melee AIM offers only figures next to you, and the aim list runs nearest first. *seen* (Player 31, p31a2/p31b1)

**Missiles**
- Bows shoot twice a round; extra shots go to the first target, then to another if it dies. *book* (Manual)
- Shooting into a melee costs nothing and never hits a friend. Beyond a third of the weapon's range the target's AC
  counts 2 better, beyond two thirds 5. With an enemy adjacent only axes and spears (which also strike in melee) can be
  thrown. *code* (Combat Chat 32) + *seen* (side chat 2)

**Turns**
- Initiative is Dexterity plus a random number: high-Dex members act first. *book* (Manual)
- Take the free round when you surprise the enemy; Guard receives a charge; Delay lets slow casters or healers act
  after the melee settles. *book* (Manual)
- DONE in a fight opens GUARD DELAY QUIT SPEED EXIT. *seen* (Player 31)
- QUICK fighters guard when no enemy is in reach, so the first round can be lost while monsters close in. *seen*
  (Stojanow report)
- Space during a QUICK member's turn hands every QUICK member back to you; each gets its menu at its next turn. *seen*
  (Player 30, p30a1)

**Healing in the fight**
- Keep members conscious: a member down at the fight's end gets none of its experience (section 6), and too big a gap
  sinks a run (section 3). Bandage the dying (section 6). *Jeremy*

**Undead and drainers**
- TURN first (section 3). Wights, wraiths, spectres and vampires drain levels, and a drained member can end "DEAD
  FOREVER". *book* (Cluebook) + *seen* (Players 7, 22) Protection from Evil doesn't stop it. *code* Bring magic
  weapons where they're needed (section 2); a spectre can't be turned below cleric level 5 (section 3).

**Enemies**
- Some monsters never run (morale 255). *code* (MON2CHA.DAX; Stojanow report)
- Some fights' monsters have fixed hit points, so every try faces the same total. *seen* (Stojanow report)
- **Killed trolls rise again** on their own square unless a figure stands on it (any of the troll's cells): a fighter
  stands on each fallen troll. *seen* (Player 38, p38e1/p38e3, Pool's kobold throne room)
- A tiger rakes (two more 2d4) only when both front claws hit in one attack; the bite doesn't count. *code* (Combat
  Chat 37, GAME.OVR 0x13EED / 0x161CD)

**Between waves**
- (Pool) The original asks CONTINUE BATTLE: YES NO; YES plays rounds with no enemy up, for cures and bandages before
  the next wave (the book's "Continue Combat to heal"). *seen* (Player 38, p38e1/p38e3)

**Fleeing**
- Fleeing the map works only for a member whose movement is at least the fastest enemy's: unready heavy armour to raise
  it, and retreat early. *book* (Manual, Cluebook)
- If the whole party flees, every unconscious or dead member is lost for good. Never flee and leave bodies: bandage the
  dying, or reload. *book* (Manual)

## 6. After a fight

**Win, lose or reload** (*Jeremy*, 2026-11-20: "a human would load the game")
- **Reload** on a wipe, a member dead, a level drained, a permanent ability loss, a key item lost, petrification, or
  anything that would cost a human player about an hour with no obvious gain, **unless** a temple cures it at a price
  the party can pay and reach.
- **A death means a reload**, even though Raise Dead (5500 GP) is affordable: a human would rather replay the fight than
  pay and lose Constitution. Raise Dead only when reloading would cost an hour or more. *Jeremy* (2026-11-20) (Pool)
  Raise Dead costs 1 Constitution and, at CON 14 and up, the hit points that came from the old Constitution bonus.
  *code* (Combat Chat 34; main chat 26's lab) + *seen* (RHIANNON CON 14 -> 13, up at 1 HP; check 111, main chats
  66/73)
- **A win with a member dead counts as a loss.** Several "wins" in the original were losses by this rule. *seen*
  (Players 7, 8, 13)
- **Unconscious is not dead:** 0 HP with status UNCONSCIOUS (4) heals; DEAD (6) is dead. *seen* (Player 8)
- **Reload and change something** (a different seed, a different plan): the same seed and the same keys can replay the
  same dice and the same loss. *seen* (Player 14, p14b3/p14b4)
- Unsure whether a human would reload? Ask Jeremy (Players: through the Lead). *Jeremy*

**Experience**
- (Pool) **No experience for the downed:** a fight's experience is divided among the members still standing and given
  only to them, so an unconscious or dying member at the fight's end gets none. *code* (Combat Chat 34; GAME.OVR
  0x58A0, 0x58D3) + *seen* (main chat 73, check 141's gnolls: DIRTEN unconscious at 23435 before and after)
- (Pool) A single-class member with a high prime requisite gets 10% more (93 -> 102); a multi-class member's share is
  split between the classes. *seen* (main chat 73, check 141)

**The dying**
- Bandage the dying at once; heal anyone unconscious before the last enemy falls if you can (section 5). *book* (Manual)
  + *Jeremy*

**Level drain**
- **Never accepted:** reload, unless a Restoration scroll is in the packs: then use it at once (a second drain before
  restoring can break the character). *Jeremy*
- **Temples don't restore levels:** Pool's temples sell no Restoration, so a drained level comes back only from a scroll.
  *code* (GAME.OVR 0x4819-0x4EEB; Combat Chat 32)
- Each Restoration gives back one level, but to the class whose next level costs least, not the drained one, and the
  average HP drained: a multi-class drained twice can come back with a level moved to another class. *seen* (Combat
  Chats 5, 32)
- Check gear after a drain and a Restoration: a sword came back unreadied. *seen* (Player 33)

**Poison, disease, petrification**
- Slow Poison keeps a poisoned member alive until a temple. *book* A member *killed* by poison stays dead after the
  temple's Neutralize Poison (it only removes the poison): cast Slow Poison first (back to 1 HP, standing), then
  neutralize. *code* (GAME.OVR 0x4CC9; main chat 68)
- A mummy's touch brings disease, which stops all healing (it killed a member during day rests): cure it at once, by
  the cleric's Cure Disease (camp) or the temple. *book* (Journal) + *seen* (Player 25) + *code* (spell table)
- Petrification: the temple's Stone to Flesh. *code*

**Taking the loot** (what to keep: section 2)
- The selected member is the one who takes loot; End and Home change who that is, and the highlight on screen doesn't
  show it. *code* (DS:0x5D92; Player 10)
- A member who refuses an item for weight refuses anything heavier: skip them for those. *seen* (Player 29, p28j1)
- A fallen NPC is dropped after the fight and his items go into the treasure, where you can take them back. *seen*
  (Player 11)

## 7. Resting and camping

**How rest works**
- While the party rests, the game rolls d100 against the area's encounter chance every 5 minutes. *code* (GAME.OVR
  0x24BC9; Player 3)
- An interrupted rest keeps only the spells already memorized (section 3). *book* Resting heals only 1 HP a day: real
  healing is spells and temples. *book* (Manual, Cluebook)

**The healing loop** (*Jeremy*, 2026-11-20)
1. After a fight, cast the Cure Light Wounds you have.
2. Rest to memorize more and cast them.
3. Repeat until everyone is full, then memorize the fighting spells.
In ours, SETTINGS REST REMEMORIZES saves the menu steps.
(Silver Blades) FIX does the loop in one command, but with Cure Light Wounds only, and heals no diseased member until
Cure Disease is cast (Curse's cluebook: FIX casts all cure spells). Which spells it uses: **unconfirmed** (request).
*book* (Silver Blades Manual p.8)

**Where to rest**
- **When a rest is interrupted, go to the inn instead of camping again.** *seen* (Player 14, p14b3)
- **Some places are only safe to rest at the inn:** camps there were interrupted 4-5 times and members died. *seen*
  (Players 15, 19, 25; Pool's list is in poolrad.md)
- **While an alarm holds,** patrols come to camps and wander more: use memorized cures and rest at the inn. *seen*
  (Players 3, 27; Pool's Valjevo)
- **In a scripted camp** (an ally's camp, a siege), each rest can bring the next wave. *code* (Player 20; Pool's nomads)

**The inn**
- An inn charges once per stay; resting there is cheaper than temple cures. *book* (Manual, Cluebook)
- (Pool) A second visit to New Phlan's inn does nothing until the party steps off its square and back. *code* (ECL
  0x4A07; Player 12)

## 8. Exploring

**Encounters and parley**
- **FLEE at "THEY RUSH TOWARD YOU" doesn't avoid the fight:** five FLEEs out of five went straight into it. *seen*
  (Player 26, Stojanow report)
- **The same encounter can come with or without a parley:** a reaction roll can give COMBAT WAIT FLEE ADVANCE where a
  friendlier roll gives PARLAY. *seen* (Players 7, 24)
- (Pool) **A wilderness band the party surprises** ("YOU SURPRISE A GROUP OF ...") leaves at once on WAIT, with no
  fight and no further menu. *seen* (Player 36, p36t2 on 6:25: wild boars twice, centaurs once)
- **Watch the default:** a menu whose default is COMBAT can kill a friendly NPC (a trader); choose PARLAY to deal with
  him. *seen* (Player 26, p26b5)
- **How to parley:** Abusive with nasty intelligent groups, Nice with neutral ones; let a high-Charisma member speak.
  *book* (Cluebook)
- **SURRENDER isn't always the end:** against a ransom demand it costs coins and items but keeps the rescue. *code*
  (Player 25; Pool's example in poolrad.md)
- Some fights can be put off with LEAVE (section 4).

**Traps**
- **If the loot is worth the risk, clear the trap;** otherwise AVOID TRAP, which keeps the party safe but leaves the
  loot. *Jeremy* + *seen* (Player 22) AVOID followed by EXAMINE rolls the trap again; once it went off. *seen*
  (Player 22)
- Finding a trap rolls against the party's *best* value, not the average: the best finder counts. *code* (ECL 3:14;
  Player 22) The cleric's Find Traps (camp) before a known trapped area (section 3).

**Locks**
- **PICK once with the best thief, then BREAK or BASH.** At a locked door every member rolls a d100 to pick. *seen*
  (Players 14, 22)
- **With nobody knowing Knock:** PICK, then BASH. After a failed PICK and BASH, a door offers only KNOCK on later
  bumps: have Knock memorized before coming back. *seen* (Players 17, 21)

**Secret doors and hidden treasure**
- **Search where you know things are:** the game gives human players clues (the text, the Journal, the cluebook).
  *Jeremy* Pool's known places: poolrad.md's gear map.
- A secret door may not be found by walking into it (a bump just runs the square's script again): **LOOK** found it at
  once. *seen* (Player 16)
- On a secret-door square each member rolls to find it, 1 in 5 (2 in 5 for elves and half-elves); **SEARCH** raises
  the chance and also finds trap doors with loot. *code* (ECL 7:22, 1:24; Players 21, 25)

**Scripted squares**
- **If a square's script turns the party back, don't keep stepping:** each try rolls the area's encounters, and one
  party fought on until it was destroyed. *seen* (Player 14, p13b6)
- **Read the text box, not only the bottom row:** a question can appear as a vertical menu drawn over the walking menu.
  *seen* (Player 28)
- **Some questions come only on a bump** (stepping from the square while facing a way), not on stepping onto it: on a
  square that should ask something, bump each way. *code* + *seen* (Player 28; Pool's example: Valjevo's gate)
- **Exits and boats move the party:** step onto them deliberately. *seen* (Players 15, 22)
- **On a wilderness band** each arrow moves the party one square without turning; a square it can't enter leaves it
  where it is. *seen* (Player 10)

## 9. Town

**Training**
- Train as soon as anyone qualifies (section 4); **clerics train first:** their extra healing makes earning the next
  fees easier. *Jeremy*
- **Training costs 1000 GP worth of the trainee's own coins** (any coins, platinum included), and only conscious
  members train. *code* (party_member.gd, the original's "TRAINING COSTS 1000 GP." and "WE ONLY TRAIN CONSCIOUS
  PEOPLE") + *Jeremy* Before training, sell what's needed (APPRAISE, then SELL; APPRAISE also offers KEEP, which takes a
  jewel off the coin count), POOL the party's money, then SHARE (or TAKE by hand: SHARE can strand money, below) so that each trainee holds the fee. *seen* (Player 15;
  main chat 66)
- The fee comes out of the member's coins. Change was seen given in gold, not platinum (Player 3), and in silver (main
  labs, chats 8 and 10): *seen*; which coins and when: **unconfirmed** (request).
- (Silver Blades) **Training is free,** and so is the temple's healing; identifying an item costs 100 gp (Curse 200). A
  member with XP for two levels trains one and keeps one point short of the next; whether Pool and Curse do the same: **unconfirmed**.
  *book* (Silver Blades Manual pp.4, 10; Journal p.5)
- A multi-class trains in the hall's class when that class is ready, even if a slower class isn't. *seen* (Player 3)
- (Pool) **Hit points gained at training:** one roll of the trained class's hit die (at least two-thirds of the die at
  level 1), plus the Constitution bonus, divided by the member's number of classes, at least 1. A multi-class training
  one class gets that one roll divided by its class count. *code* (Player 3; main chat 71: GAME.OVR 0x1DBB4 / 0x1DB4C;
  ours the same, matched in check 103) The die is rolled once (no better-of-two). *seen* (the original's traces,
  checks 96 and 103, main chats 64-65)
- (Pool) The training hall's caps: fighter 8, thief 9, cleric and magic-user 6 (section 1). *book*

**Money and savings**
- **Don't oversell:** sell only what pays for this trip's training and needs. *Jeremy*
- There's no bank: keep value light. Gems and jewellery, kept unsold (APPRAISE, KEEP), are the lightest store of value;
  coins all weigh the same each, so carry platinum (1 = 5 gold) rather than gold; useful magic (potions, scrolls,
  wands) is worth keeping. Convert gems when the next training comes due. *Jeremy* + *book* (Manual)
- (Pool) **Shops change coins into platinum:** any purchase regroups the buyer's whole purse into platinum and gold (the
  part under a gold piece is lost; silver, copper and electrum too), and a sale pays in platinum and gold. So buying
  something cheap turns a member's gold into platinum, a fifth of the weight. *seen* (main labs, chats 8 and 10;
  party_member.gd `pay_gold_in_shop`, `receive_gold`)
- (Pool) **A member at his most (load = allowance + 1500) can neither buy nor be given coins by TRADE.** To lighten
  everyone at once: at a shop POOL the whole party's money, make one purchase (the pool regroups into platinum and
  gold), then each member TAKEs a set amount of platinum. *seen* (Player 38, p38a1/p38a2 at New Phlan: movement 3 to
  9+)
- **SHARE in a shop can strand money:** it may leave coins on the pile ("YOU HAVE LEFT SOME MONEY HERE"), and in the
  original (ORIGINAL'S BUGS on) it can fill every member's load with phantom jewelry so no one can TAKE the rest: TAKE
  by hand to the members with room instead. *seen* (main chat 78, checks 176-177)

**Shops**
- **Sell spare gear on every town trip** (section 2). *seen* (Player 27)
- **Unready an item before selling it:** SELL does nothing to a readied item, with no message. The price comes in the
  largest coins (7 GP as 1 platinum and 2 gold). *seen* (main chat 65, check 101)
- A seller too loaded to carry the coins gets what fits; the rest goes on the shop's pile ("OVERLOADED. MONEY WILL BE
  PUT IN POOL."). *code* (GAME.OVR 0x22E47; Combat Chat 32) (Pool) **POOL before you APPRAISE and SELL gems:** an
  overloaded member gets the gem's platinum only up to his room (the rest goes to the pool), and KEEP is offered only
  when the gem still fits (load and 16 items). *seen* + *code* (Tyr's temple, GAME.OVR 0x269D3 / 0x24E8C; main chat 74)
- **Coins POOLed in a shop stay in the shop;** leaving asks whether to go back for the money. *seen* (Player 12)
- **Buy plenty of darts for the magic-users on every trip;** other ammunition only when you run out (section 2). *Jeremy*
- The first item list in a shop can open one item down, with the highlight kept from an earlier menu: check what's lit
  before BUY or SELL. *seen* (Player 2)

**Temples** (Pool; *code*, GAME.OVR 0x4819-0x4EEB, Combat Chat 32; the same prices at every temple: *seen*, Player 3)

| Cure | GP |
|---|---|
| Cure Light Wounds | 100 |
| Cure Serious Wounds | 350 |
| Cure Critical Wounds | 600 |
| Cure Blindness | 1000 |
| Cure Disease | 1000 |
| Neutralize Poison | 1000 |
| Stone to Flesh | 2000 |
| Remove Curse | 3500 |
| Raise Dead | 5500 |

- **Never pay a temple for healing your clerics can do for free, unless death is on the line.** *Jeremy*
- No Restoration: drained levels come back only from scrolls (section 6). Neutralize Poison is charged even for a member
  who doesn't need it; Cure Disease asks first. *seen* (Player 25)

**Hours**
- (Pool) The shops, City Hall and the training halls lock from hour 14: rest at the inn until midnight first. *seen*
  (Player 15, p15d1)

---

## For the lanes

Tool and method notes behind the guide's lines; players can skip this.

- Map squares can carry flag bits that a "walk round every event" route treats as events (Valjevo's 32/64 bits): name the real events to avoid instead (Player 29, p29b1; *read in the code*, GEO5 blocks 3-5).
- **The spell lab's method** (Combat Chat 33): *Seen in the original* unless marked: controlled fights in DOSBox, lab saves with one caster (BAKSHI, a half-elf cleric 1 / fighter 1 / magic-user 1) holding 21 copies of one spell; the computer-cast fights (QUICK, MAGIC on) matched ours draw for draw (9 fights, now in regress.sh), so ours' labelled log is the original's fight; Stinking Cloud cast by hand (combat33/handcast.py). Durations are rounds; "level" is the caster's level in the spell's class. Target type so far: kobolds (the kobold caves' net trap, 20 kobolds) and the Slums orcs; large monsters and undead come next. **Since Combat Chat 34 the hand-cast fights replay in ours** (the lab key `handcast=`): seven fights, six match the original draw for draw.
- Not yet measured: large monsters (ogres, trolls), undead, and bigger samples on orcs (a bigger orc band than the Slums' four).
- **The reload rule in the Player's tools** (Player 32): `OP_RELOAD=1` (plans.py `reload_rule`, read from the record: levels 0x96-0x9D, levels drained 0x74, abilities 0x10-0x15, status 0x10C; key items and temple cures not yet), lab `p32/reload.sh` goes on from the last clean checkpoint (Player 32; *read in the code*).
- **TURN first in the Player's tactics** (Player 32): - With undead on the field, the clerics TURN first (once a fight each) before casting or fighting (Jeremy, 2026-11-20; tactics.py since Player 32; results to be added as the graveyard redo shows them).

## Inbox

Lanes append new lessons here, one line each, with the source tag (*seen* / *code* / *book* / *players* / *Jeremy*)
and where it was learnt. The Lead folds them into the sections daily and clears this list.
- A cleric can't READY a magic-user's scroll (READY does nothing, no message): hand scrolls to a member of the scroll's class before a fight. *seen* (main chat 85, DOSBox, check 243)
- READY works in a fight from USE's item list (End to the item, R, then EXIT): a Ring of Protection +2 readied there lowers AC at once (4 to 2) and the member's menu comes back with the turn unspent (*seen*: Combat Chat 38, the spell lab's ring_kob in DOSBox; Guide 4's question). (Folded into poolrad.md section 3, the finale: Gold Box Guide 6.)
- A wand's spell goes off at level 6 too: a 1st-level magic-user's Wand of Lightning Bolt does 6d6 a bolt (*seen*: Combat Chat 38, the spell lab's wand_kob in DOSBox, three bolts; adds to section 1's scroll line).
- **Correction to "killed trolls rise again ... a fighter stands on each fallen troll" (*seen*, Player 38):** in the original logs the step never held: 32 of 32 times the figure was on another square at its next menu (p38e3, p38e5, p39a1, p39b4, p39c2), and p39c2's troll rose on the "held" square. Not yet known whether the original forbids it or the tool's step is wrong (Player and Combat asked); until then, finish trolls with fire. *seen* (Gold Box Guide 6, from Players 38-39's logs)
- **Standing on a fallen troll does hold it, on its corner square** (*seen*, Player 40, DOSBox: the Slums' trolls, p40t1-t3; answers the correction above): the earlier steps failed because Esc ends a MOVE by undoing it (the figure back where MOVE began; Enter keeps the walk). A fallen troll rises at full HP on its corner (top-left) square; a member standing there kept one down 115 s to the fight's end, a member on its second cell didn't, and one rose as soon as the member on it fell.
- **The marching order is the fight's front row:** the order's first four start in contact when a fight opens on the party (5:7's guards); put the casters after the fighters with camp ALTER, ORDER before a known fight (*seen*, Player 40, p40e0).
- A Javelin of Lightning (USE in a fight) hits the aimed figure for 1d6+20 and the next figures on the line beyond it (3 squares' worth) for a flat 20 each, a save halving each: aim so the line runs on through the crowd (*seen*: Combat Chat 39, the spell lab's jav_kob in DOSBox: 24, 20, 20).
- In MOVE with MOVE LEFT = 1 (2 half-moves), only a straight step is left: a diagonal (3) ends the movement with no step and the menu comes back without MOVE (*code* GAME.OVR 0x12F0D, *seen* in Player 39's p37i1: ARN's Home).
- **Where a fight starts can be chosen:** an event often lies on several squares (a row of a room), and the battlefield is built around the square the party stands on (13 x 5 map squares); a square beside a wall closes that flank, and with a distance-0 wave (monsters anchored on the party's square) it decides where the enemy starts. Check the area map for the event's squares before a hard fight. *code* (Gold Box Guide 8: the kobold throne, 8:13 4,3 / 5,3 / 6,3)
- **Hold Person takes three different figures:** TARGET three of them and the aim closes by itself; TARGET on a figure already picked keeps the aim up and adds nothing, so among look-alikes (twelve 8TH LVL FIGHTERs) count your NEXTs from the caster to know whom you picked (*seen*, Player 41, p41x2 at 5:7's guards).
- A member on QUICK chooses his own weapon each turn and may put a magic one away for another weapon (with no enemy next to him, a missile weapon rates higher): a Two-Handed Sword +1 (+3 vs Undead) put away loses its undead bonus until READYed again, so keep fighters with such a weapon off QUICK against undead, or re-READY after the fight (*seen*: Combat Chat 40, Player 37's p37i1, BRAM on QUICK at the spectres: his effect 3 gone, GAME.OVR 0x11B35).
- MOVE into the field's edge asks FLEE: YES NO; YES gets the member away at once if no enemy can see him, else only if he is faster than the fastest enemy (a coin toss when as fast), otherwise ESCAPE IS BLOCKED and he can go on moving (*code* GAME.OVR 0xA413 / 0x13465, Combat Chat 40).
- **A Fireball aimed at an enemy beside our line burns our own:** LIRA's at the guard on 28,14 (two squares from our front row) did 15 to ARN and 15 to BRAM. Aim it where no member is within its reach, or use Stinking Cloud / Hold Person there. *seen* (p41g1's video, Gold Box Guide 9)
- **Aim by MANUAL, straight to the cell wanted**, not by NEXT/PREV scans; for area spells pick the cell so no ally is inside and so a second cloud sits beside the first, not on it (two Stinking Clouds side by side cover 8 cells, overlapped only 6). *Jeremy* (Gold Box Guide 9, p41g1's video)
- **A caster in contact steps back before casting** (a next-turn spell begun in melee is spoilt by any hit), or casts an at-once spell. *Jeremy* (Gold Box Guide 9)
- **Against many men-at-arms: the clerics Hold Person everyone (three a cast), the magic-users Stinking Cloud the rest, the fighters fight the ones still standing while the others kill the helpless** (one blow each). *Jeremy* (Gold Box Guide 9, the finale's twelve guards: "extremely easy with the current setup")
- **Hard fights get a spell-list review before them;** otherwise the example cleric lists (section "Example spell lists") stand. For the finale's twelve guards: as many Hold Persons as the slots allow. *Jeremy* (Gold Box Guide 9, 2026-11-21 14:54)

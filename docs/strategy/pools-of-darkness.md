# Pools of Darkness strategy

Pools of Darkness' party rules, route, hard fights and Pools-only rules, for players and for the guide chats that will
work on it. General tactics are in the Gold Box Players' Guide (`docs/playbook.md`); its tags (*seen*, *code*, *book*,
*players*, *Jeremy*, **unconfirmed**) apply here. Made by Gold Box Sources 3 (2026-11-21) from the game's own
documents, following ai-business-ideas `plans/game-sources-method.md`; nothing here has been seen in play yet. New
lessons go in the Inbox at the end; the Lead folds them in daily.

**Sources** (in the GOG folder `Pools of Darkness`; page numbers are the printed ones): the Rule Book (Manual, pp.1-12:
menus, Limbo and the import; it sends race and class rules to the Journal), the Data Card (six unnumbered panels, cited
as "Card panel n"; panel 6 is a list of program changes), the Cluebook (pp.1-74: synopsis, the Journal's false entries,
the magic items' places, then every area's map notes, and Dave's Challenge) and the Adventurer's Journal (pp.1-60: the
character rules, bestiary, spells, entries, and the tables as appendices, pp.47-59). The Manual, Card and Journal are
scans without text (read by OCR and as images); the Cluebook has a text layer. The copy protection is a word looked up
in the Journal: its answers stay in `.lab`, as do the Cluebook's riddle answers, code words and passwords.

## What changed since Silver Blades

*(Drafted after the sections are approved.)*

## 1. The party

**Allowed races and classes** *book* (Journal pp.1-2, 48): Silver Blades', unchanged.

| Race | Single classes | Multi-classes |
|---|---|---|
| Human | cleric, fighter, magic-user, thief, paladin, ranger; dual-class later | none |
| Half-elf | cleric, fighter, magic-user, thief, ranger | C/F, C/R, C/MU, F/MU, F/T, MU/T, C/F/MU, F/MU/T |
| Elf | fighter, magic-user, thief | F/MU, F/T, MU/T, F/MU/T |
| Dwarf, gnome, halfling | fighter, thief | F/T |

Paladin (lawful good; Str 12, Int 9, Wis 13, Cha 17 at least) and ranger (good; Str 13, Int 13, Wis 14, Con 14 at
least) as before. *book* (Journal p.3)

**Level limits across the series** (the highest level each race can reach in each class; "-" = not allowed; the band is
the class's prime requisite). Pools' row printed first, the earlier games in brackets. *book* (Pools Journal p.48;
Silver Blades Journal p.47; Curse Manual p.23) + *code* for Curse and Pool (curse.md section 1)

| Race | Fighter Str 16- / 17 / 18+ | Ranger Str 16- / 17 / 18+ | Magic-user Int 16- / 17 / 18 | Cleric | Thief | Paladin |
|---|---|---|---|---|---|---|
| Dwarf | 7 / 8 / 9 | - | - | - | **40** (SB 18, Curse 12) | - |
| Elf | 5 / 6 / 7 | - | 9 / 10 / 11 | - | **40** (18, 12) | - |
| Gnome | 5 / 5 / 6 | - | - | - | **40** (18, 12) | - |
| Half-elf | 6 / 7 / 8 | 6 / 7 / 8 | 6 / 7 / 8 | 5 | **40** (18, 12) | - |
| Halfling | 4 / 5 / 6 (Str 17 at most) | - | - | - | **40** (18, 12) | - |
| Human | **40** (15, 12) | **40** (15, 11) | **40** (15, 11) | **40** (15, 10) | **40** (18, 12) | **40** (15, 11) |

- **Every demi-human limit is the same in all four games;** only humans and thieves move. In Pool the halls stopped
  every class early (fighter 8, thief 9, cleric and magic-user 6), so few demi-human limits bit there. *book* + *code*
- **40 is the Cluebook's number** ("all characters ... should be able to advance up to level 40", p.1). The Journal's
  table only says "max" for humans and thieves, "the highest level available in Pools of Darkness" (p.48), and its XP
  tables print levels 1-18, then a fixed cost per level after 18th (pp.56-59: fighter 250,000, paladin 350,000, ranger
  325,000, cleric 225,000, magic-user 375,000, thief 220,000). Whether the hall stops at 40, and for which classes:
  **unconfirmed** (request). Players agree on 40. *players* ([GameBanshee](https://gamebanshee.com/poolsofdarkness/walkthrough/gameplaynotes.php);
  [GOG forum](https://gog.com/forum/forgotten_realms_collection/should_i_transfer_characters_goldbox_games))
- **The halfling's 6 at Str 18+** is printed here (Silver Blades printed "-"), but a halfling can't have more than 17
  Strength (Journal p.48), so it changes nothing. Pool's code also had the 6. *book*
- **Ability ranges and racial modifiers:** the same as before (dwarf Con +1, Cha -1; elf Dex +1, Con -1; halfling Dex +1,
  Str -1; a woman's Strength maximum is lower: human 18/50, dwarf 17). *book* (Journal pp.47-48)
- **The XP bonus** needs **16** in the prime requisite, as in Silver Blades. *book* (Journal p.2)
- **Spells need high scores.** Magic-users: 5th level at 9 (Int 10+), 6th at 12 (Int 12+), 7th at 14 (Int 14+), **8th at
  16 (Int 16+), 9th at 18 (Int 18+)**: Mass Charm, Mind Blank, Otto's Irresistible Dance, Power Word Blind; Meteor
  Swarm, Monster Summoning, Power Word Kill. Clerics: 6th level at 11 (Wis 17+), **7th at 16 (Wis 18+)**: Destruction,
  Energy Drain, Resurrection, Restoration. Rangers: druid 3rd level at 16. Paladins: cleric spells from 9, 4th level at
  15. *book* (Journal pp.17-24, 55-59) The Card and Cluebook both say a magic-user needs **18 Intelligence** or the most
  powerful spells are out of reach. *book* (Card panel 6; Cluebook p.1)
- **Attacks per round:** as before (fighters and paladins 3 every 2 rounds from 7, 2 from 13; rangers 3 every 2 from 8,
  2 from 15). *book* (Journal p.49)
- **Dual-classing** (humans, at a hall): as before; the old class stops, no new HP and none of its abilities until the
  new level passes the old. A dual-class magic-user can't cast in armour, **except a ranger/magic-user** (the Journal's
  wording; Silver Blades' Journal had no exception): **unconfirmed** (request). *book* (Journal p.4)

**New characters start with 1,500,001 XP** ("most single-class characters at about 14th level"). By the tables that is
paladin 12, ranger 13, fighter, cleric and magic-user 14, thief 16; a two-class character gets 750,000 in each class, a
three-class 500,000 (our arithmetic). A demi-human whose limit is lower starts at its limit: the Card's warning that
"most non-human races" start at their class maximums (panel 6). They arrive with nothing; the outfitting is in Phlan's
shops. *book* (Journal p.5; Journal pp.56-59; Card panel 6)

**Non-humans: thieves only.** The Cluebook's advice (p.1): use demi-humans only as thieves, the one class whose
advancement is unlimited for them, and give magic-users 18 Intelligence; a party with demi-humans in other classes, or a
magic-user under 18, should lower the difficulty to Novice or Squire (ALTER, LEVEL), because the game was built for a
party without those limits. Players say the same. *book* + *players* (GameBanshee, above)

**The game's parties**
- **The Journal's sample** (p.6): a human magic-user, a human paladin, a dwarf fighter/thief, a human ranger and two
  human clerics. Its reasons: mostly single-class, so it advances quickly; the paladin's protection from evil (AC 2
  better against evil foes for everyone within 10 feet); the fighter/thief's locks and traps with a fighter's armour and
  HP; the ranger's damage against giants and his spells; clerics "absolutely essential" for healing. *book*
- **The ready-made party** (Save Game A, outfitted, "at the very beginning of the game": Card panel 1; read from its six
  character files, Gold Box Sources 3): a human paladin 12 (Str 18/00, Wis 18, Cha 17), a human ranger 13 (18/50), a
  human cleric 14 (Wis 18), two human magic-users at 12 (Int 18) and 13 (Int 17, Str 18/51: perhaps a dual-classed
  fighter), and a fighter 8 / thief 13 (the race byte reads as dwarf). The magic-users' and the fighter/thief's levels
  don't match the XP tables at 1,500,001 (14; fighter 9 at most for a dwarf, thief 14): **unconfirmed**. *code*
  (CHRDATA1-6.SAV: race 0xAD, class 0xAE, levels 0x151-0x158)
- **Who is useful where** (Cluebook): a **high-level thief** steals the antidote vial in Kalistes' Temple (p.39); an
  **elf** recognizes the Watcher's haunts in Moander's heart (p.60); a member with **Strength 15** (or a Strength or
  Enlarge spell) passes the Testing Ground's first trial (p.45); the **highest Dexterity** crosses the slave pens' spike
  pit (p.37); a **strong member** forces the Descent's stuck door wide enough for a **halfling, gnome or elf** (p.35);
  high Dexterity or a thief's climbing gets over Myth Drannor's wall (p.51). **Dave's Challenge** (optional, after the
  ending, always at Champion) needs at least one magic-user, thief, cleric and fighter-type (p.73).
- **NPCs** (two at most; a conscious NPC keeps what he is given: Manual p.4): Vala (Vala vs. Vaasa; gives a silver
  shield +4), Raizel (a thief, Thorne's Cave: leads the party astray to treasure), Traned (a halfling, the Descent: her
  silver shield reflects the Manshoon sentinel's gaze), Silk (a drow, the slave pens), Storm (a dwarf ranger, the Web
  Dimension: "fight steadfastly"), Dennia or Valardis (the Web; Valardis betrays), Shal (Tower of Marcus: a fighter
  without her magic; arm her), Nacacia (Myth Drannor), and two who join to betray: Ruoln (Kimarr in disguise, Thar) and
  the disgruntled slave (the Web). *book* (Cluebook pp.17-56)

**Importing a party** *book* (Manual pp.1, 3; Card panels 2-3, 5-6) + *players*
- **From:** Secret of the Silver Blades only (Pool and Curse characters come through it). Two ways: LOAD SAVED GAME,
  WHERE FROM SECRET, takes a whole saved party (the preferred way); ADD CHARACTER TO PARTY, SECRET, takes one character
  removed from Silver Blades' party. Setup asks for Silver Blades' save path (default `SECRET\SAVE`). *book* On GOG:
  make a `SECRET` folder in the Pools of Darkness folder and copy Silver Blades' `SAVE` folder into it. *players*
  ([Gold Box wiki, transfer guide](https://goldbox.fandom.com/wiki/Gold_Box_Forgotten_Realms_GOG_Transfer_Guide?oldid=4365);
  [GOG forum](https://gog.com/forum/forgotten_realms_collection/sotsb_to_por_transfer))
- **Kept:** the characters, "most of their equipment" and their money: the first import since Pool's that keeps gear.
  *book* (Card panel 5) Players: all gear and money came across. *players*
  ([CRPG Addict](https://crpgaddict.blogspot.com/2016/09/game-230-pools-of-darkness-1991.html))
- **Lost:** **bundled scrolls** (unbundle them in Silver Blades first) and **the Vault** (give its items to the
  characters first). *book* (Card panel 6) Strength above 18/00 without a girdle comes down to 18/00, and Constitution
  from Curse's Girdle of the Dwarves goes; stat-changing items can confuse the transfer. *players* (transfer guide;
  [GOG forum](https://gog.com/forum/forgotten_realms_collection/should_i_transfer_characters_goldbox_games))
- **Levels and XP:** players report imported characters arriving one XP short of level 16. *players* (GameBanshee) The
  books don't say; what the code copies (HP, XP, spells, effects, age): **unconfirmed** (request).
- **Training at once:** the training hall is in Phlan (east side), but Phlan is torn away early in the story and only
  comes back after Marcus' Tower; players say training is out of reach for a while after the start. Train in Phlan
  before escorting Sasha. *book* (Cluebook pp.1, 13) + *players* (GOG forum, above)
- **Gear in the Pools:** most magic items are destroyed on the full passage between the Realms and an outer dimension
  (either way); store them with Elminster in Limbo first. Going from an outer dimension to Limbo and back keeps them;
  drow gear survives into the Web Dimension, and Shal's vorpal long sword survives Limbo. An imported party's Silver
  Blades gear (+5 weapons and armour; Pools' is mostly +4) is the reason to import even demi-humans: players import for
  the gear, then make new humans where needed. *book* (Manual p.10; Cluebook pp.15, 40, 56) + *players* (GameBanshee)

**What Pools of Darkness changes for a party built in Pool, Curse or Silver Blades** (flags, not a recommendation;
Jeremy, 2026-11-21: the pick comes once all four games are processed)
1. **Humans go to 40, demi-humans stay put.** A demi-human fighter, ranger, magic-user or cleric reaches its limit
   (5-11) by Curse and gains nothing in Silver Blades or Pools; the game's own books say to use non-humans only as
   thieves. A demi-human multi-class has one class still growing only if it is a thief. *book* (Journal p.48; Cluebook p.1)
2. **Magic-users need Intelligence 18** for 9th-level spells, and the books say so twice. Scores are set when the
   character is made in Pool, so this is decided there. *book* (Journal p.56; Card panel 6; Cluebook p.1)
3. **Clerics need Wisdom 18** for 7th-level spells (Resurrection, Restoration), 17 for 6th (Heal). *book* (Journal p.57)
4. **The import keeps the gear,** unlike Pool's and Curse's and Silver Blades' own: what the party carries out of Silver
   Blades is its starting kit (Silver Blades' +5 gear beats most of Pools'). Unbundle scrolls and empty the Vault first.
   *book* (Card panels 5-6) + *players*
5. **A fresh party starts at about 14** (1,500,001 XP); an imported one is reported at 15-16. A carried party's lead is
   small in levels, large in gear. *book* + *players*
6. **Dual-class at 15 in Silver Blades, cash in at 16 in Pools:** players dual-class a human at 15 late in Silver Blades
   so the old class comes back at 16, early in Pools. *players* (GOG forum, above)
7. **An elf and a dwarf still have small jobs** (the Watcher; Storm is an NPC dwarf), and a halfling, gnome or elf one
   door; none is required. A **thief** has the antidote and Dave's Challenge. *book* (Cluebook, above)
8. **Elves still can't be raised;** each raise costs a point of Constitution. *book* (Journal pp.1, 3; Manual p.5)
9. **Age:** Haste ages a character a year; humans have the shortest lives. *book* (Journal p.2)

## 2. The route

*(Next.)*

## 3. Hard fights

*(Next.)*

## 4. Pools-only rules

*(Next.)*

## 5. The magic-gear map

*(Next.)*

## 6. The Journal's false entries

*(Next.)*

## For the lanes

*(Next.)*

## Inbox

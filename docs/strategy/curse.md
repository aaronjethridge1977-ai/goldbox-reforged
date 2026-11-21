# Curse of the Azure Bonds strategy

Curse of the Azure Bonds' party rules, route, hard fights and Curse-only rules, for players and for the guide chats that
will work on it. General tactics are in the Gold Box Players' Guide (`docs/playbook.md`); its tags (*seen*, *code*,
*book*, *players*, *Jeremy*, **unconfirmed**) apply here. Made by Gold Box Sources 1 (2026-11-21) from the game's own
documents, following ai-business-ideas `plans/game-sources-method.md`; nothing here has been seen in play yet. New
lessons go in the Inbox at the end; the Lead folds them in daily.

**Sources** (in the GOG folder `Curse of the Azure Bonds`; page numbers are the printed ones): the Manual (rule book,
pp.1-29 and the Dalelands map), the Quick Reference Card (3 pages; its third page is Secret of the Silver Blades'
install sheet, filed by mistake), the Cluebook (pp.1-48) and the Adventurer's Journal (pp.1-29: entries 1-59, tavern
tales 1-62). The translation wheel (`codewheel.exe`) is copy protection: its answers stay in `.lab`.

## What changed since Pool

The input for Jeremy's comparison across the series. Party rows first (section 1 has the detail).

**Races and classes**
- **Two new classes, human only except one:** the **paladin** (human only) and the **ranger** (human, and half-elf
  as ranger or cleric/ranger). *book* (Manual pp.4-6, 23)
- **Paladin:** lawful good; at least Str 12, Int 9, Wis 13, Cha 17; protection from evil around him at all times
  (adjacent members gain it too), turns undead as a cleric two levels lower, heals 2 HP per level once a day, cures
  disease once a week (twice at 6-10, three times at 11), won't adventure with evil characters, cleric spells from
  level 9. *book* (Manual pp.6, 10; Card p.2)
- **Ranger:** good alignment; at least Str 13, Int 13, Wis 14, Con 14; extra damage against giant-class foes; at most
  three in a party; druid spells from level 8, magic-user spells from 9; two attacks every other round from level 8
  (fighters and paladins from 7). *book* (Manual pp.6, 14, 27)
- **Dual-classing (humans):** "Human Change Class" on the party menu (in a training hall). The old class stops
  advancing; the character has the new class's HP and abilities only, until the new level passes the old one, then
  both. A dual-class magic-user can't cast in readied armour. *book* (Manual pp.6-8, 13)
- **Demi-humans:** the same races and the same multi-class choices as Pool, plus the half-elf's ranger and
  cleric/ranger. Dwarves, gnomes and halflings: fighter, thief, fighter/thief only. *book* (Manual p.4)
- **New characters start with 25,000 XP** (level 5 for a single class; multi-classes split it) and 300 platinum each.
  *book* (Manual pp.5, 8) + *players* ([Wikipedia](https://en.wikipedia.org/wiki/Curse_of_the_Azure_Bonds))

**Level limits**
- **Demi-human limits: the same numbers as Pool's,** now printed by prime requisite (section 1). Humans and thieves
  are capped only by the game's top level: fighter and thief 12, paladin, ranger and magic-user 11, cleric 10.
  *book* (Manual pp.23, 26-27) The training hall enforces them as printed. *code* (playbook section 1, main chat 72)
- Pool's halls stopped at fighter 8, thief 9, cleric and magic-user 6; Curse's lets a finished Pool party train on.
  *book* (Pool Manual; Curse Manual pp.8, 23)

**Importing a Pool party** (section 1 has the detail): characters keep class, race, levels and stats; all items are
lost; money is reset to 300 platinum each. *players* + *book*, details **unconfirmed** in the code.

**Spells:** cleric levels 4-5 and magic-user levels 4-5 are new (Pool stopped at 3), and the druid's first level for
rangers. *book* (Manual pp.18-24) [to be filled in at the section 4 review]

**Items, monsters, interface:** [to be filled in at the section 2-4 reviews]

## 1. The party

**Allowed races and classes** *book* (Manual pp.4, 23)

| Race | Single classes | Multi-classes |
|---|---|---|
| Human | cleric, fighter, magic-user, thief, paladin, ranger; dual-class later | none |
| Half-elf | cleric, fighter, magic-user, thief, ranger | C/F, C/R, C/MU, F/MU, F/T, MU/T, C/F/MU, F/MU/T |
| Elf | fighter, magic-user, thief | F/MU, F/T, MU/T, F/MU/T |
| Dwarf, gnome, halfling | fighter, thief | F/T |

**Level limits, Curse beside Pool** (the highest level each race can reach in each class; "-" = not allowed; the
band is the class's prime requisite: Strength for fighters and rangers, Intelligence for magic-users). *book* (Curse
Manual p.23; Pool Manual p.5) + *code* (Curse GAME.OVR 0x24DDE-0x24F5B, Pool GAME.OVR 0x1C3F7-0x1C501; main chat 72)

| Race | Fighter Str 16- / 17 / 18+ | Ranger Str 16- / 17 / 18+ | Magic-user Int 16- / 17 / 18 | Cleric | Thief | Paladin |
|---|---|---|---|---|---|---|
| Dwarf | 7 / 8 / 9 | - | - | - | 12 | - |
| Elf | 5 / 6 / 7 | - | 9 / 10 / 11 | - | 12 | - |
| Gnome | 5 / 5 / 6 | - | - | - | 12 | - |
| Half-elf | 6 / 7 / 8 | 6 / 7 / 8 | 6 / 7 / 8 | 5 | 12 | - |
| Halfling | 4 / 5 / - (Str 17 at most) | - | - | - | 12 | - |
| Human | 12 | 11 | 11 | 10 | 12 | 11 |

- **Pool:** the same demi-human numbers, but its halls stop every class early (fighter 8, thief 9, cleric and
  magic-user 6), so in Pool only the elf, gnome and halfling fighter limits (and a low-Strength dwarf's or half-elf's)
  bite. In Curse every demi-human fighter limit and the half-elf cleric's 5 bite. *book* + *code* (playbook section 1)
- **A demi-human fighter's limit follows its Strength,** and a magic-user's its Intelligence: 18 Strength is worth two
  levels to a dwarf or elf fighter. Pool's code also gives a halfling with 18 Strength a 6; Curse's manual says a
  halfling can't have 18 (Str 17 at most, 14 for a woman). *book* (Manual p.23) + *code*
- **Ability ranges by race** (an imported character outside them is pulled back in: *players*, below): dwarf Str
  8-18/99 (woman 8-17), Con 12-19, Dex 3-17, Cha 3-16; elf Str 3-18/75 (16), Int 8-18, Dex 7-19, Con 6-18, Cha 8-18;
  gnome Str 6-18/50 (15), Int 7-18, Con 8-18; half-elf Str 3-18/90 (17), Int 4-18, Dex 6-18, Con 6-18; halfling Str 6-17
  (14), Int 6-18, Wis 3-17, Dex 8-18, Con 10-19; human 3-18/00 (18/50). *book* (Manual p.23)
- **The XP bonus** (10%) comes with a high prime requisite: the manual says 15 or more, the cluebook 16 or more (and
  both of the paladin's Strength and Wisdom, both of the ranger's Intelligence and Wisdom). **unconfirmed** which.
  *book* (Manual p.4; Cluebook p.2)

**The cluebook's parties** *book* (Cluebook p.3): two human paladins, an elf fighter/magic-user, a dwarf
fighter/thief, two human clerics (or three paladins and one cleric); or two paladins, a ranger, two magic-users (one may
be an elf) and a cleric; or two paladins, two rangers, a cleric and a magic-user (weak in spells until dual-classed).
**At least one woman:** Silk the Swanmay's help against the Drow of Hap needs a female member (Cluebook pp.3, 15).
Its dual-class advice: a paladin to magic-user at 7; with two clerics, one to magic-user at 9; a ranger to magic-user at
9, who then casts in armour from 10 (Cluebook pp.3-4). Only elves should be fighter/magic-users (p.3).

**Importing a party** *book* (Manual pp.2, 7-8; Card p.1) + *players*
- **From:** Pool of Radiance, Hillsfar, and Pool or Curse characters who went through Hillsfar (that needs both games'
  saves). Remove the characters from their Pool party first (remove, not drop), run `COPYCURS` in Curse's folder, then
  "Add character to party", from POOL. *book* (Manual pp.2, 8; Card p.1) + *players* ([GOG forum](https://www.gog.com/forum/forgotten_realms_collection/cant_seen_to_transfer_chatacters))
- **Kept:** race, class, levels, experience, ability scores (pulled into the race's range), alignment, age. *players*
  ([Gold Box wiki, transfer guide](https://goldbox.fandom.com/wiki/Gold_Box_Forgotten_Realms_GOG_Transfer_Guide?oldid=4365))
  **unconfirmed** in the code: HP, the magic-user's spell book, memorized spells, effects.
- **Lost:** every item. Money is set to 300 platinum each. The story covers it: the party wakes in Tilverton robbed of
  its gear. *players* (transfer guide) + *book* (Cluebook p.7; Journal entry 1)
- **Bug (the original's):** an imported member with 18 Strength may get the percentile value copied into his base
  Strength, which shows when a Strength effect (Enlarge, gauntlets) wears off; re-adding him from CURSE rather than
  POOL fixed it for one player. *players* ([GOG forum](https://gog.com/forum/forgotten_realms_collection/curse_of_the_azure_bonds_strength_bug))
- **Train at once:** Tilverton's hall (and its shop, temple and sage) close when the bonds force the attack on the
  king's coach; after that the only hall until the overland is the thieves' hidden one in the sewers. An imported party
  arrives with XP to spend; new characters don't. *book* (Cluebook pp.7-10)
- **Don't dual-class at the start:** the new class begins at level 1 and the towns close soon. *players*
  ([GOG forum](https://gog.com/forum/forgotten_realms_collection/pool_of_radiance_anything_i_should_not_do))
- **On to Silver Blades:** paladins, rangers and dual-classed humans can't go back to Hillsfar. *book* (Card p.1) What
  Silver Blades keeps: its own file, when it is processed.

**What Curse changes for a Pool party built to carry on** (flags, not a recommendation; Jeremy, 2026-11-21: the pick
comes once all four games are processed)
1. **Strength 18 for every demi-human fighter;** in Curse it is two fighter levels (dwarf 9 not 7, elf 7 not 5,
   half-elf 8 not 6). In Pool the halls hid it. *book* (Manual p.23)
2. **Human stats for a later dual-class:** a Pool human with 17+ in a second class's prime requisite can change class
   in Curse. Players report 15+ in the old class's prime requisite as the other condition: **unconfirmed** (section 4,
   For the lanes).
3. **Paladins and rangers don't exist in Pool** and a Pool character can't become one by import; whether a Pool human
   can dual-class into either is **unconfirmed**. A party that wants them makes them in Curse.
4. **At least one woman** (Silk, Hap). A woman's Strength maximum is lower (human 18/50, dwarf 17), which costs a
   demi-human fighter a level or two.
5. **Alignment counts:** paladins won't travel with evil members; Yulash's commander judges the party by class
   (paladins over thieves) and alignment (good over evil). *book* (Manual p.6; Cluebook pp.20-21)
6. **Gear doesn't carry:** Pool's magic items stay in Pool, so there is nothing to hoard for the sequel. *players*
7. **Elves can't be raised** (as in Pool). *book* (Manual pp.4, 9)
8. **Caps far off:** a finished Pool party (fighters 8, magic-users 6) is 1-3 levels ahead of Curse's new characters
   (level 5) and still well under Curse's caps (players: *players*,
   [CRPG Addict](https://crpgaddict.blogspot.com/2012/12/game-82-curse-of-azure-bonds-1989.html)); its multi-class
   demi-humans reach their racial limits in Curse (*players*,
   [GOG forum](https://www.gog.com/forum/forgotten_realms_collection/hitting_level_limits_in_gold_box_games/page1)).

## 2. The route

[Next review.]

## 3. Hard fights

[Next review.]

## 4. Curse-only rules

[Next review.]

## 5. The magic-gear map

Later, from the game's data, by a lane.

## 6. The Journal's false entries

[Next review.]

---

## For the lanes

[Next review.]

## Inbox

Lanes append new lessons here, one line each, with the source tag (*seen* / *code* / *book* / *players* / *Jeremy*)
and where it was learnt. The Lead folds them into the sections daily and clears this list.

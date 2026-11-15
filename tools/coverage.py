#!/usr/bin/env python3
"""Writes docs/coverage.md: every spell, usable item, script opcode and monster power in
Pool of Radiance, with where it is used and how far our engine has it.

    python3 tools/coverage.py <POOLRAD folder> > docs/coverage.md

The lists come from the player's own game files (START.EXE's spell table, the ECL scripts,
MONnSPC.DAX, the ITEM and MONnITM lists); the status of each entry is kept by hand in
STATUS below. Statuses: checked (built and compared with the original in the lab),
built (from the original's code or tables, not yet compared), partial, missing.
Nothing from the game files is written except names and counts.
"""
import glob
import os
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "lab"))
from dax import read_dax  # noqa: E402
import ecl  # noqa: E402
import unexepack  # noqa: E402

# --- Hand-kept status -------------------------------------------------------------------
# Spells by id (START.EXE table; ids 57-67 are the item and monster powers: an item's
# spell byte over 56 is reduced by 23, GAME.OVR 0x22B62).
SPELLS = {
    1: ("checked", "to-hit +1 for the caster's side not next to an enemy; memorize/rest timing checked"),
    2: ("built", "-1 to hit on the other side"),
    3: ("checked", "1d8; not on the diseased"),
    4: ("built", "touch attack, 1d8"),
    5: ("checked", "handler 5 is empty; while a member has effect 5 the item list puts \"* \" before magic items (START.EXE 0xBA:0x443; main's chat 26 lab: \" YES  * FLAIL\"); the sheet's ITEMS list shows it (Combat Chat 6)"),
    6: ("built", "-2 to be hit by evil, +2 saves"),
    7: ("built", "as Protection from Evil, against good"),
    8: ("built", "cold damage halved, +3 to the save (handler 0x0A)"),
    9: ("built", "the caster's level in fire damage"),
    10: ("partial", "fights only; lasts the fight, not after it"),
    11: ("checked", "as 5"),
    12: ("built", "STR 18/00..18/100 by caster level (0x282BD), back when it ends"),
    13: ("missing", "effect added, nothing happens"),
    14: ("missing", "effect added; CHA not raised"),
    15: ("checked", "(level / 2)d4 + level / 2, nothing at level 1 (GAME.OVR 0x28451); Shield stops it; roll for roll in regress.sh's six H fights"),
    16: ("built", ""),
    17: ("built", ""),
    18: ("missing", "effect added; nothing reads it"),
    19: ("built", "AC 4 or better against missiles, +1 saves, stops Magic Missile"),
    20: ("built", "touch, 1d8 + level"),
    21: ("built", "4d4 hit dice, weakest first; elves resist"),
    22: ("partial", "effect added; scripts test it with HAS_EFFECT"),
    23: ("built", "1-3 targets, save penalty by count"),
    24: ("built", "fire damage halved, +3 to the save (handler 0x14)"),
    25: ("partial", "a silenced caster loses the spell ('IS SILENCED'); the spell's own area and save not traced"),
    26: ("missing", "poison still kills at once (handler 0x16 delays it)"),
    27: ("partial", "holds snakes as Hold Person does; not limited to snakes"),
    28: ("missing", "no hammer appears"),
    29: ("missing", "effect added; invisible figures stay hidden"),
    30: ("built", "-4 to hit it; ends when it attacks"),
    31: ("built", "opens locked doors (KNOCK on the door menu)"),
    32: ("built", "1d4 images ('lost an image')"),
    33: ("built", "damage -25%"),
    34: ("partial", "helpless 1d4+1 rounds; the cloud doesn't linger"),
    35: ("built", "STR + 1d4 MU, 1d6 cleric/thief, 1d8 fighter (0x28F59)"),
    36: ("missing", "no undead raised"),
    37: ("built", "removes blindness (0x21)"),
    38: ("built", "-4 to hit, 4 worse AC, -4 saves (handler 0x21)"),
    39: ("checked", "cures mummy rot and disease (temples too)"),
    40: ("missing", "effect added; no disease (handler 0x22 adds 0x2B/0x2C)"),
    41: ("partial", "ends every effect in the area; no level check"),
    42: ("built", "+1 to hit and saves for the side, -1 for the other"),
    43: ("missing", "cursed items can't be freed"),
    44: ("built", "-4 to hit and saves (handler 0x24)"),
    45: ("missing", "effect added; no blinking (handler 0x25: attacks on the blinker miss)"),
    46: ("partial", "as 41"),
    47: ("built", "level d6, half on a save, radius 3 (2 outdoors)"),
    48: ("built", "doubles moves and attacks; Slow cancels it; ages the target a year once"),
    49: ("built", "1-4 targets"),
    50: ("built", "as Invisibility, on everyone near"),
    51: ("partial", "level d6; runs straight, doesn't bounce off walls"),
    52: ("built", ""),
    53: ("built", ""),
    54: ("built", "missiles without a plus are avoided (handler 0x29)"),
    55: ("built", "halves moves and attacks"),
    56: ("built", "temples only (Restoration)"),
    57: ("built", "Potion of Speed: haste 5d4 rounds unless slowed, 'IS SPEEDY'"),
    58: ("missing", "no item uses it (cures poison or heals 1d4+8)"),
    59: ("built", "Potion of Giant Strength: STR 21 for 1d4x10+40, 'IS STRONGER'"),
    60: ("partial", "Javelin of Lightning: 1d6+20 electricity, half on a save, one target (the original's line not traced)"),
    61: ("built", "Wand of Paralyzation: held 5d4 rounds, 'IS PARALYZED'"),
    62: ("built", "Potion of Healing: 2d4+2, 'IS HEALED'"),
    63: ("built", "Dust of Disappearance: the user's side invisible (0x47, -4 to hit)"),
    64: ("built", "Necklace of Missiles: Fireball's handler"),
    65: ("built", "Wand of Magic Missiles: 2d4+2 magic damage"),
    66: ("built", "Cloak of Displacement's use does nothing (handler empty)"),
    67: ("built", "Manual of Bodily Health: a day reading, 30 days training, CON + 1 (HP recount for CON 15+ not built)"),
}

# Effect types that monsters carry (MONnSPC.DAX) and readied items give.
POWERS = {
    0x00: ("built", "empty record (a vampire's)"),
    0x18: ("missing", "sees invisible (Invisibility's handler 0x19 checks it)"),
    0x25: ("missing", "blinks: attacks against it miss (Blink's effect)"),
    0x40: ("checked", "poison on a hit"), 0x41: ("built", "poison, save +4"),
    0x42: ("built", "poison, save +2"), 0x43: ("checked", "paralysis 2d8 rounds"),
    0x44: ("checked", "ghoul paralysis; elves immune"),
    0x45: ("built", "drider: paralysis 1d9+10 rounds (0x10341)"),
    0x46: ("built", "poison, save -2"),
    0x48: ("built", "hides: 95% invisible each round"),
    0x49: ("built", "tiger: both claws hit -> 'RAKES...', two more attacks of 2d4"),
    0x4C: ("built", "stirge: latches on, 1d4 a turn ('SUCKS SOME BLOOD') until it has had ~12; the victim's own restriction (0x3A) not traced"),
    0x4D: ("built", "giant mantis: 'IS HELD FAST' (STR under 19), then 3d4 each turn; the victim's own restriction (0x3A) not traced"),
    0x4F: ("built", "2d10 fire on a hit"), 0x50: ("built", "1d4 acid on a bite"),
    0x51: ("checked", "fear aura by level"), 0x52: ("built", "mummy fear"),
    0x53: ("checked", "stoning gaze, before each step or blow (0xB6FC); roll for roll (basilisk, regress.sh)"), 0x54: ("built", "charming gaze"),
    0x55: ("checked", "drains a level"), 0x56: ("checked", "drains two levels"),
    0x57: ("built", "mummy rot"), 0x58: ("checked", "lightning breath"),
    0x59: ("built", "the first attack against it misses (also the Cloak of Displacement's)"),
    0x5B: ("built", "no electricity, no Magic Missile"), 0x5D: ("built", "half fire"),
    0x5E: ("built", "half from arrows and quarrels"), 0x60: ("built", "only magic or silver"),
    0x62: ("built", "regenerates 3 HP"), 0x63: ("built", "fights on after going down"),
    0x64: ("built", "troll gets back up"), 0x65: ("built", "troll regenerates after 3 rounds"),
    0x67: ("built", "turns gaseous"),
    0x68: ("built", "thri-kreen: avoids 60% of missiles"),
    0x6A: ("missing", "magic resistance 15% (never matters against Pool's spells)"),
    0x6C: ("built", "no Sleep or Charm"), 0x6D: ("built", "no Hold"),
    0x6E: ("built", "no cold"), 0x6F: ("built", "no Hold, poison; saves vs poison"),
    0x70: ("built", "no fire"),
    0x71: ("built", "efreeti: fire one less a die"),
    0x72: ("built", "half electricity"), 0x73: ("built", "half from edged weapons"),
    0x74: ("built", "half from magic weapons"), 0x75: ("built", "holy water 1d6+1"),
    0x76: ("built", "half cold"), 0x77: ("built", "only magic weapons"),
    0x78: ("built", "avoids boulders"), 0x79: ("built", "spits acid"),
    0x7A: ("built", "oil 3d8"), 0x7B: ("built", "wraith: magic full, silver half"),
    0x7D: ("built", "undead immunities"), 0x7E: ("built", "shuns mirrors and holy symbols"),
    0x7F: ("built", "marks the gaze's target"),
}

# Readied items' powers (record byte 62 with bit 7 set: byte 61 is an effect type).
ITEM_POWERS = {
    0x03: ("built", "+2 to hit and damage against undead while readied (handler 0x03)"),
    0x26: ("built", "Gauntlets of Ogre Power: STR 18/00 while readied"),
    0x3D: ("built", "Ring of Fire Resistance: fire -2 a die, +4 saves, while readied"),
    0x52: ("built", "Long Sword +3: alignment 2 only; anyone else takes 5 and can't ready it"),
    0x59: ("built", "Cloak of Displacement: lends 0x59 (the first attack each fight misses)"),
    0xF0: ("built", "Long Sword +2: alignment 0 only; anyone else takes 15"),
    0x00: ("built", "giants throw it; 0x78 avoids it"),
}

# --- Engine features a player meets (side lane, from 2026-11-14) ---------------------------
# Hand-kept, like the tables above: (feature, status, on the main path, note). The main-path
# flag marks what every player meets on the way to the end; a main-path entry that is
# partial or missing goes in the gap list at the top of docs/coverage.md. Evidence: the lab
# checks named in each script's header and in ai-business-ideas plans/chat-log.md.
FEATURES = [
    ("Shops", "New Phlan's shops (opened by the area scripts with their own stock).", [
        ("BUY: pages, prices, the buyer's coins and change", "checked", True,
         "screens pixel for pixel (chat 11); 140 gold - 80 = 12 platinum and two more cases (chat 10)"),
        ("POOL (the party's coins to the buyer)", "built", True, "Jeremy hand-tested 2026-11-10; not compared"),
        ("VIEW -> SELL (half the price)", "checked", True, "the shop's VIEW and SELL prompts matched (chat 11)"),
        ("VIEW -> ID (200 gp)", "checked", False, "screens matched (chat 11); what ID reveals not compared"),
        ("APPRAISE gems and jewelry, SELL or KEEP", "checked", False, "values by d100 from GAME.OVR 0x26680, lab chat 8"),
        ("NOT ENOUGH MONEY.", "partial", False, "the original's words when money is short not checked"),
        ("BOUGHT (the item) on row 24", "built", False, "QoL addition (the original says nothing)"),
    ]),
    ("Temples", "New Phlan's temples of Tyr, Sune and Tempus (TEMPLE_FLAG + COMBAT).", [
        ("HEAL: the cure list and prices", "checked", True, "screens and keys (chat 10); list and prices from GAME.OVR"),
        ("Cure Light / Serious / Critical Wounds, waking the unconscious", "built", True, "1d8, 2d8+1, 3d8+3 to full HP; not on the diseased"),
        ("Raise Dead", "checked", True, "back at 1 HP, effects 0x20 and 0x37 off, CON - 1 and the max-HP cut (GAME.OVR 0x4A86; main's chat 26 lab: CON 16 -> 15, max HP 10 -> 5; the temple calls it, Combat Chat 6)"),
        ("Cure Disease (mummy rot)", "checked", False, "temples and the spell"),
        ("Stone to Flesh", "built", False, "back at 1 HP (GAME.OVR 0x4EB4)"),
        ("Cure Blindness, Neutralize Poison, Remove Curse", "partial", False,
         "listed and paid for, but the temple doesn't see these conditions on a character, so it always asks CAST CURE ANYWAY"),
        ("APPRAISE", "missing", False, "on the menu, does nothing"),
        ("The look after paying", "partial", False, "(NAME) IS CURED. shown; the screen after it not compared"),
    ]),
    ("Training halls and the party menu", "PROGRAM 0: the halls in New Phlan and the start of the game.", [
        ("TRAIN: level, hit points, THAC0, cost", "checked", True, "screens, level and THAC0 matched (chat 10); 1000 gold a level"),
        ("A magic-user's new spell after training", "partial", True, "built; the original's spell-learning page never seen"),
        ("Racial level limits", "partial", False, "open since chat 13: not checked against the original"),
        ("CREATE, MODIFY, DROP, ADD, REMOVE, VIEW, SAVE, BEGIN, EXIT", "checked", True,
         "screens matched (chat 10-11); creation from START.EXE / GAME.OVR's rules (chat 4)"),
        ("ALTER ICON and PICS (icon editor, portraits)", "checked", False, "chat 4-5"),
    ]),
    ("Inns, the arena, City Hall", "Script programs and calls around New Phlan.", [
        ("Inn: WHO WILL PAY?, one platinum, a safe rest", "built", True, "PROGRAM 9"),
        ("City Hall commissions and the clerk's rewards", "checked", True, "from the scripts; the Zhentil state comparison (chat 13)"),
        ("Arena duel (CALL 0x8000 / 0x8001), WHO", "built", False, "100 experience a level for the duelist; the duel's opponent as GAME.OVR loads it"),
        ("Hirelings and their treasure shares", "built", False, "chat 4"),
    ]),
    ("Camp", "Encamp (E): SAVE VIEW MAGIC REST ALTER EXIT.", [
        ("SAVE (the original's own format, slots A-J) and LOAD SAVED GAME", "checked", True, "our saves load in the original and back (lab saves E-I)"),
        ("REST: the timer, 1 HP a day, interruptions", "checked", True, "save J, 4 -> 5 HP after 24 hours; interruptions from the area scripts"),
        ("MEMORIZE and resting to memorize", "checked", True, "4 h 15 min for one 1st-level spell, as the lab showed"),
        ("CAST in camp (cures on a member)", "built", True, "screens drawn as the original's; CAN'T BE CAST HERE not seen"),
        ("SCRIBE (scrolls into the spell book, 15 minutes a level)", "partial", True, "built; the original's SCRIBE list never seen; whether the original needs Read Magic first not checked (spell 18 does nothing)"),
        ("DISPLAY (spell effects on each member)", "built", False, ""),
        ("Heal and memorized messages while resting", "partial", True, "drawn as the rest; not seen in the original"),
        ("ALTER: ORDER, DROP, SPEED, ICON, PICS", "checked", False, "screens matched (chat 10-11); SPEED paces fights (P16)"),
    ]),
    ("Items", "VIEW -> ITEMS and the treasure screen.", [
        ("READY, USE, TRADE, DROP, HALVE, JOIN, money TRADE / DROP", "checked", True, "30 lab captures pixel for pixel, messages included (chat 11)"),
        ("Encumbrance and movement from weight", "checked", True, "matches the cached weight in all six shipped characters"),
        ("Using items in a fight (wands, potions, scrolls)", "built", True, "items' spells as the table above; spells from items assumed instant"),
        ("Cursed items", "partial", False, "IT'S CURSED blocks unreadying; nothing frees them (Remove Curse missing)"),
        ("Treasure: results, experience, TAKE, POOL, SHARE", "checked", True, "464 XP for the Slums orcs; screens matched (chat 10)"),
        ("Treasure: load and item-count limits when taking", "checked", True, "GAME.OVR 0x23795 / 0x24CDD (main's chat 26 lab): OVERLOADED at a 17th item or above STR allowance + 1500; TAKE MONEY takes nothing when it doesn't fit; the shop's BUY checks the money first, then the load, and pays only for a taken item (0x7080); TRADE the same rule (Combat Chat 6)"),
        ("Monsters' worthless items on a d10 of 1-3", "checked", False, "roll for roll (side chat 3)"),
        ("The original's item names", "checked", True, "treasure and VIEW"),
    ]),
    ("Conditions and effects", "What can happen to a character (status byte 0x10C and the effect list).", [
        ("Dying, bandaging, unconscious, dead", "checked", True, "bleeding a point a round, CONTINUE BATTLE; roll for roll"),
        ("Fled (RUNNING) and left behind", "partial", True,
         "the party keeps members left down after a flee; what the original does with them not checked"),
        ("Poison", "partial", True, "kills at once; Slow Poison (spell 26) and the poisoned state missing"),
        ("Disease (mummy rot)", "built", False, "0x57; cured at temples"),
        ("Level drain", "checked", False, "wights, wraiths (one), spectres, vampires (two)"),
        ("Paralysis (ghouls, thri-kreen)", "checked", True, ""),
        ("Stoning (basilisk, medusa)", "built", False, "a readied mirror reflects the gaze"),
        ("Charm", "partial", False, "lasts the fight, not after it"),
        ("Blindness", "built", False, "Cause Blindness; temples can't see it (above)"),
        ("Aging (Haste)", "built", False, "a year once per Haste"),
        ("Magic resistance (Tyranthraxus 15%)", "missing", True, "the final fight; see monster power 0x6a"),
    ]),
]

# Spells the party learns early or the monsters cast often: their gaps count as main-path gaps.
MAIN_SPELLS = [5, 11, 13, 18, 26, 28, 34, 43, 51]

OPCODES_NOTE = {
    "CALL": ("checked", "0x2C4E, 0x2C51, 0xC003, 0xC009 do nothing in the original's handler 0x3A36 either (main, chat 26)"),
    "SURPRISE": ("built", ""), "PARLAY": ("built", "the script's own replies"),
    "PRINT_RUNES": ("built", ""), "PROGRAM": ("built", "0 party menu, 3 lost, 8 won, 9 inn"),
    "LOAD_AREA_MAP": ("checked", ""), "LOAD_AREA_DECO": ("checked", ""),
    "ENCOUNTER_MENU": ("checked", ""), "COMBAT": ("checked", ""), "TREASURE": ("checked", ""),
    "NEW_ECL": ("checked", ""), "ROB": ("built", ""), "DAMAGE": ("built", ""),
    "WHO": ("checked", ""), "INPUT_STRING": ("built", ""), "INPUT_NUMBER": ("built", ""),
    "CLOCK": ("checked", ""), "SPELL": ("built", ""), "NPC_ADD": ("built", ""),
    "PARTY_STRENGTH": ("built", ""), "PARTY_SKILL_CHECK": ("built", ""),
    "PARTY_CHECK": ("built", ""), "FIND_ITEM": ("built", ""),
}


def spell_table(img):
    at = img.find(b"\x05Bless")
    names = [img[at + i * 41 + 1:at + i * 41 + 1 + img[at + i * 41]].decode() for i in range(56)]
    base = at + 56 * 41
    return names, [img[base + i * 16:base + (i + 1) * 16] for i in range(67)]


def item_words(img):
    at = img.find(b"\nBattle Axe") - 21
    return [img[at + i * 21 + 1:at + i * 21 + 1 + min(img[at + i * 21], 20)].decode("ascii", "replace")
            for i in range(256)]


def main(game):
    img = unexepack.unpack(open(os.path.join(game, "START.EXE"), "rb").read())
    names, entries = spell_table(img)
    words = item_words(img)
    out = []
    w = out.append
    w("# Coverage: spells, items, script opcodes, monster powers, engine features\n")
    w("Generated by `tools/coverage.py` from the game files; statuses are kept by hand in that script.")
    w("**checked**: built and compared with the original in the lab. **built**: from the original's code"
      " or tables, not yet compared. **partial**: works in part (the note says what is missing)."
      " **missing**: not built.\n")
    w("Owner: the side lane (from 2026-11-14, Methods 3). Refresh it after a feature lands or a lab check.\n")
    w("## Gaps a player meets on the main path\n")
    w("Main-path entries below that are partial or missing (the engine-feature sections, then the spells and"
      " items the party or the monsters use most).\n")
    for sec, _, rows in FEATURES:
        for name, st, main_path, note in rows:
            if main_path and st in ("partial", "missing"):
                w(f"- **{sec}: {name}** ({st}){': ' + note if note else ''}")
    for i in MAIN_SPELLS:
        st, note = SPELLS.get(i, ("missing", ""))
        if st in ("partial", "missing"):
            w(f"- **Spell {i}, {names[i - 1]}** ({st}): {note}")
    w("- **Script CALLs** (partial): " + OPCODES_NOTE["CALL"][1])
    w("")

    # Monster spell use (monsters' memorized spells: CHA record bytes 0x21..)
    mon_spells = Counter()
    for f in glob.glob(os.path.join(game, "MON?CHA.DAX")):
        for bid, b in read_dax(f).items():
            for k in range(0x17, 0x2C):
                if k < len(b) and 0 < b[k] < 68:
                    mon_spells[b[k]] += 1
    tally = Counter(s for s, _ in SPELLS.values())
    w(f"## Spells ({tally['checked']} checked, {tally['built']} built, {tally['partial']} partial, {tally['missing']} missing)\n")
    w("Monsters: how many monster records have the spell memorized (record bytes 0x17-0x2B), i.e. what the computer casts.\n")
    w("| id | spell | class, level | monsters | status | notes |")
    w("|---|---|---|---|---|---|")
    item_names = {57: "Potion of Speed", 58: "(item spell 81)", 59: "Potion of Giant Strength",
                  60: "Javelin of Lightning", 61: "Wand of Paralyzation", 62: "Potion of Healing",
                  63: "Dust of Disappearance", 64: "Necklace of Missiles", 65: "Wand of Magic Missiles",
                  66: "Cloak of Displacement (use)", 67: "Manual of Bodily Health"}
    for i in range(1, 68):
        e = entries[i - 1]
        nm = names[i - 1] if i <= 56 else item_names.get(i, "")
        cls = ["cleric", "magic-user", "item/monster"][e[0]] if e[0] < 3 else str(e[0])
        st, note = SPELLS.get(i, ("missing", ""))
        w(f"| {i} | {nm} | {cls} {e[1]} | {mon_spells.get(i, '')} | {st} | {note} |")

    # Items with spells or powers
    items = defaultdict(lambda: [0, set()])
    for f in sorted(glob.glob(os.path.join(game, "ITEM?.DAX")) + glob.glob(os.path.join(game, "MON?ITM.DAX"))):
        for bid, b in read_dax(f).items():
            for i in range(0, len(b) - 62, 63):
                r = b[i:i + 63]
                if not (r[60] or r[61] or r[62]):
                    continue
                nm = " ".join(words[x] for x in (r[49], r[48], r[47]) if x)
                if "Scroll" in nm:
                    continue
                key = (nm, r[61], r[62])
                items[key][0] += 1
                items[key][1].add(os.path.basename(f).split(".")[0])
    w("\n## Usable and magic items\n")
    w("Scrolls (any spell above) are left out. Where: the ITEM lists (treasure) and MONnITM (carried by monsters).\n")
    w("| item | spell / power | where | status | notes |")
    w("|---|---|---|---|---|")
    for (nm, sp, fl), (n, where) in sorted(items.items()):
        if fl >= 0x80:
            st, note = ITEM_POWERS.get(sp, ("missing", ""))
            what = f"power {sp:#04x} while readied"
        else:
            sid = sp - 23 if sp > 56 else sp
            st, note = SPELLS.get(sid, ("missing", ""))
            what = f"spell {sid}" + (f" ({sp})" if sp > 56 else "")
            if "Flame Tongue" in nm:
                st, note = "missing", "+1/+2 and fire against some monsters; byte 61 = 22 (to trace)"
            if nm.startswith("Potion Extra"):
                note = "Cure Light Wounds, 3 charges"
        w(f"| {nm} | {what} | {', '.join(sorted(where))} | {st} | {note} |")

    # Opcodes
    used = Counter()
    for n in range(1, 9):
        for bid, b in read_dax(os.path.join(game, f"ECL{n}.DAX")).items():
            found, _ = ecl.follow(ecl.code_of(b))
            for name, args, q in found.values():
                used[name] += 1
    w("\n## Script opcodes\n")
    w("Uses: instructions reached by following each script's control flow. `tools/sweep.gd` runs every"
      " area's events through our VM and reports nothing unhandled (2026-11-11).\n")
    w("| opcode | uses | status | notes |")
    w("|---|---|---|---|")
    for op, (name, _, _) in sorted(ecl.OPS.items()):
        if used[name] == 0:
            continue
        st, note = OPCODES_NOTE.get(name, ("built", ""))
        w(f"| {name} | {used[name]} | {st} | {note} |")
    unused = [v[0] for v in ecl.OPS.values() if used[v[0]] == 0]
    w(f"\nNever used by Pool of Radiance's scripts: {', '.join(unused)}.")

    # Monster powers
    powers = defaultdict(set)
    for n in range(1, 9):
        p = os.path.join(game, f"MON{n}SPC.DAX")
        if not os.path.exists(p):
            continue
        cha = read_dax(os.path.join(game, f"MON{n}CHA.DAX"))
        for bid, b in read_dax(p).items():
            c = cha.get(bid, b"")
            nm = c[1:1 + c[0]].decode("ascii", "replace") if c and c[0] < 16 else "?"
            for i in range(0, len(b) - 8, 9):
                powers[b[i]].add(nm)
    w("\n## Monster powers (effect types in MONnSPC.DAX)\n")
    w("Handlers decoded from GAME.OVR's table at DS:0x682C; see `scripts/combat/special_affects.gd`.\n")
    w("| type | monsters | status | notes |")
    w("|---|---|---|---|")
    for t in sorted(powers):
        st, note = POWERS.get(t, ("missing", ""))
        w(f"| {t:#04x} | {', '.join(sorted(powers[t]))} | {st} | {note} |")
    w("\n## Engine features\n")
    w("What the engine runs itself, outside the scripts: places, camp, items, conditions. Main path: met by every"
      " player on the way to the end.\n")
    for sec, intro, rows in FEATURES:
        t = Counter(st for _, st, _, _ in rows)
        w(f"### {sec} ({', '.join(f'{t[k]} {k}' for k in ('checked', 'built', 'partial', 'missing') if t[k])})\n")
        w(intro + "\n")
        w("| feature | status | main path | notes |")
        w("|---|---|---|---|")
        for name, st, main_path, note in rows:
            w(f"| {name} | {st} | {'yes' if main_path else ''} | {note} |")
        w("")
    for label, table in (("spells", SPELLS), ("monster powers", POWERS), ("item powers", ITEM_POWERS)):
        c = Counter(s for s, _ in table.values())
        print(f"{label}: {dict(c)}", file=sys.stderr)
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1])

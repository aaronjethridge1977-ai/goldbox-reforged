#!/usr/bin/env python3
"""Player 44 (Gold Box Guide 12's step 1 (a), the party ledger): every member's level, HP, XP, coins and load (the
movement band), and every item as the game shows it: readied or not, plus, weight, charges byte, price; the
consumables (potions, scrolls, wands, javelins, necklaces) listed apart. Reads a save directory (SAVGAM?.DAT and its
CHRDAT?n.SAV / .ITM, as a checkpoint keeps them). player.py writes one beside each checkpoint (LEDGER.txt).

Usage: python3 ledger.py <save dir> [--md]

Item records (.ITM, 63 bytes each; seen on the Plan 2 chain's saves): 0-41 the name as listed (length byte, then the
YES/NO column and the name), 46 the type, 50 the plus (signed), 52 readied, 53 the name flags (0: a plain item), 55-56
the weight, 57 the count, 58-59 the price, 60 the charges / uses byte (wands: Gold Box Guide 4), 61-62 the effect.
Character records (.SAV): 0x88 seven coin words (copper, silver, electrum, gold, platinum, gems, jewellery), 0x102 the
load word, 0x10 / 0x16 STR and its percentile, 0x11B the HP (as loot.party reads it in memory)."""
import glob
import os
import struct
import sys

CONSUMABLE = ("POTION", "SCROLL", "WAND", "JAVELIN", "NECKLACE", "DUST", "OIL", "PHILTER", "ELIXIR")


_NAMES = None


def spell_name(i):
    """A spell id's name from START.EXE's table (56 names, 41 bytes each, id = index + 1; tactics.spell_range)."""
    global _NAMES
    if _NAMES is None:
        _NAMES = {}
        try:
            lab = os.environ.get("OP_LAB", "/home/aaron/gbr/player_lab")
            sys.path.insert(0, lab)
            import unexepack
            img = unexepack.unpack(open(os.path.join(lab, "game", "START.EXE"), "rb").read())
            b = img.find(b"\x05Bless")
            for k in range(56):
                o = b + 41 * k
                _NAMES[k + 1] = img[o + 1:o + 1 + img[o]].decode("latin1").upper()
        except Exception:
            pass
    return _NAMES.get(i, str(i))


def allowance(st, ex):
    # the movement audit's allowance (Player 38, p38/plan_coins.py; party_member.gd load_allowance)
    g = st if st < 18 else (18 if ex == 0 else 19 if ex <= 50 else 20 if ex <= 75 else 21 if ex <= 90 else
                            22 if ex <= 99 else 23)
    if g <= 11:
        return 0
    if g <= 13:
        return 100
    if g <= 15:
        return 200
    if g == 16:
        return 350
    if g <= 21:
        return (g - 17) * 250 + 500
    return (g - 22) * 1000 + 2000


def band(over):
    return "12/9" if over <= 512 else "6" if over <= 768 else "3" if over <= 1024 else "under 3"


_SLOTS = None


def _slot(t):
    """The item type's slot from the game's ITEMS file (record byte 0; 2 = body armour), None if unread."""
    global _SLOTS
    if _SLOTS is None:
        _SLOTS = {}
        for g in (os.environ.get("OP_GAME", ""), os.path.expanduser("~/gbr/player_lab/game")):
            f = os.path.join(g, "ITEMS")
            if g and os.path.exists(f):
                d = open(f, "rb").read()
                _SLOTS = {i: d[2 + 16 * i] for i in range((len(d) - 2) // 16)}
                break
    return _SLOTS.get(t)


def movement(base, its, over):
    """Player 48 (Guide 13's (1): the ledger's "over 412: movement 12/9" was a band, not the figure): the member's
    movement as the game works it out (party_member.gd, START.EXE 0xDF4-0xF40): the record's base (0x72); readied body
    armour over 150 coins of weight gives 9 (under 400) or 6, a magic one +3 when 9 or less; then the load over the
    allowance (a word tested signed: negative is no limit) caps it at 9 (over 0x200), 6 (0x300) or 3 (0x400)."""
    mv = base
    arm = [it for it in its if it["ready"] and _slot(it["type"]) == 2]
    if arm:
        w = arm[0]["weight"]
        if w > 150:
            mv = 9 if w < 400 else 6
        if arm[0]["plus"] != 0 and mv <= 9:
            mv += 3
    o = over & 0xFFFF
    o = 0 if o >= 0x8000 else o
    cap = 3 if o > 0x400 else 6 if o > 0x300 else 9 if o > 0x200 else mv
    return min(mv, cap)


def items(path):
    out = []
    if not os.path.exists(path):
        return out
    d = open(path, "rb").read()
    for i in range(len(d) // 63):
        r = d[i * 63:(i + 1) * 63]
        text = r[1:1 + min(r[0], 41)].decode("latin1")
        name = text[5:].strip() if text[:5].strip() in ("Yes", "No") else text.strip()
        out.append({"name": name, "type": r[46], "plus": struct.unpack_from("<b", r, 50)[0], "ready": r[52],
                    "flags": r[53], "weight": struct.unpack_from("<H", r, 55)[0], "count": r[57],
                    "price": struct.unpack_from("<H", r, 58)[0], "charges": r[60], "effect": r[61:63].hex()})
    return out


def members(save_dir):
    out = []
    for f in sorted(glob.glob(os.path.join(save_dir, "CHRDAT*.SAV"))):
        r = open(f, "rb").read()
        name = r[1:1 + r[0]].decode("latin1")
        coins = [struct.unpack_from("<H", r, 0x88 + i * 2)[0] for i in range(7)]
        load = struct.unpack_from("<H", r, 0x102)[0]
        its = items(f[:-4] + ".ITM")
        out.append({"name": name, "coins": coins, "load": load, "allow": allowance(r[0x10], r[0x16]),
                    "hp": r[0x11B] if len(r) > 0x11B else None, "items": its, "base": r[0x72]})
    return out


def ledger(save_dir, md=False):
    lines = ["# Party ledger: %s" % os.path.basename(os.path.normpath(save_dir)), ""]
    cons = []
    for m in members(save_dir):
        c = m["coins"]
        over = m["load"] - m["allow"]
        lines.append("%s: HP %s; coins cp %d sp %d ep %d gp %d pp %d, gems %d, jewellery %d; load %d, allowance %d,"
                     " over %d: movement %d" % (m["name"], m["hp"], c[0], c[1], c[2], c[3], c[4], c[5], c[6],
                                                m["load"], m["allow"], over, movement(m["base"], m["items"], over)))
        for it in m["items"]:
            tag = "%s%s" % (it["name"], " (+%d)" % it["plus"] if it["plus"] and "+" not in it["name"] else "")
            lines.append("  %s %-38s weight %4d  price %5d  charges %3d  effect %s" % (
                "R" if it["ready"] else "-", tag[:38], it["weight"], it["price"], it["charges"], it["effect"]))
            if any(w in it["name"].upper() for w in CONSUMABLE):
                what = "charges byte %d" % it["charges"]
                if "SCROLL" in it["name"].upper():
                    ids = [it["charges"]] + list(bytes.fromhex(it["effect"]))
                    what = "spells " + (", ".join(spell_name(i) for i in ids if i) or "none")
                cons.append("%s: %s%s (%s)" % (m["name"], tag, ", readied" if it["ready"] else "", what))
    lines += ["", "Consumables (potions, scrolls, wands, javelins, necklaces):"] + ["  " + x for x in cons]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    sys.stdout.write(ledger(sys.argv[1], "--md" in sys.argv))

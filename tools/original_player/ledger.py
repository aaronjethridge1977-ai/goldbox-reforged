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
                    "hp": r[0x11B] if len(r) > 0x11B else None, "items": its})
    return out


def ledger(save_dir, md=False):
    lines = ["# Party ledger: %s" % os.path.basename(os.path.normpath(save_dir)), ""]
    cons = []
    for m in members(save_dir):
        c = m["coins"]
        over = m["load"] - m["allow"]
        lines.append("%s: HP %s; coins cp %d sp %d ep %d gp %d pp %d, gems %d, jewellery %d; load %d, allowance %d,"
                     " over %d: movement %s" % (m["name"], m["hp"], c[0], c[1], c[2], c[3], c[4], c[5], c[6],
                                                m["load"], m["allow"], over, band(over)))
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

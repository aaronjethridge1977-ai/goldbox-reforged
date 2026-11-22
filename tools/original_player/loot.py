"""Player 10: the treasure's items and the party's in the running original, and the take policy (`default treasure
take` in a plan). Found in the lab (p10t2: Podol Plaza's goblins, c24f's party; README "Player 10"):

- the loot: a list of 63-byte item records from the far pointer DS:0x6810, the next record's far pointer at +42
  (0:0 ends it), in the order of the TAKE -> ITEMS screen; fields as ours' game_item.gd (type +46, plus +50,
  readied +52, weight +55, count +57, price +58; the name +0 is a display cache, without the plus: a Long Sword +1
  shows as LONG SWORD);
- a member's items: the same kind of list from the far pointer at record +0xC8;
- the selected member (who takes): the far pointer DS:0x5D92 to their record; End / Home on the TAKE menu
  (TAKE: MONEY ITEMS EXIT) select the next / previous member;
- T on the ITEMS list gives the lit item to the selected member (appended to their list), the light stays on the
  same row (the next item); End / Home move the light down / up and wrap; a 17th item is refused with the screen
  unchanged (no message seen at game speed 0).
"""
import struct

LOOT = 0x6810
SELECTED = 0x5D92
PARTY = 0x5D96
ITEMS_AT = 0xC8
LIMIT = 16
# main's bot (scripts/dev/bot.gd `_worth_taking`, `_keeper`): what a player carries off.
QUEST_ITEM_TYPES = (74, 75, 82, 91)
LOOT_WORDS = ("SCROLL", "POTION", "WAND", "RING", "NECKLACE", "BRACERS", "GAUNTLETS", "CLOAK", "DUST", "JAVELIN",
              "MANUAL", "GEM", "JEWEL", "HOLY", "MIRROR", "BOOK", "TOME", "MAP", "STAFF OF", "ROD", "KEY")


def chain(mem, s, o, maxn=60):
    """[(addr, record bytes)] of the item list from far pointer s:o."""
    out = []
    while (s, o) != (0, 0) and len(out) < maxn:
        r = mem.far(s, o, 63)
        out.append(((s, o), r))
        o, s = struct.unpack_from("<HH", r, 42)
    return out


def item(r):
    return {"name": r[1:1 + min(r[0], 41)].decode("latin1").strip(), "type": r[46],
            "plus": struct.unpack_from("<b", r, 50)[0], "weight": struct.unpack_from("<H", r, 55)[0],
            "count": r[57], "price": struct.unpack_from("<H", r, 58)[0]}


def loot(mem):
    return [item(r) for _, r in chain(mem, *mem.farptr(LOOT))]


def party(mem):
    """[(record far pointer, name, item count, hp)] in the party's order."""
    out = []
    s, o = mem.farptr(PARTY)
    while s and len(out) < 8:
        r = mem.far(s, o, 0x120)
        io, iseg = struct.unpack_from("<HH", r, ITEMS_AT)
        out.append(((s, o), r[1:1 + min(r[0], 15)].decode("latin1"), len(chain(mem, iseg, io)), r[0x11B]))
        o, s = struct.unpack_from("<HH", r, 0x104)
    return out


def selected(mem):
    s, o = mem.farptr(SELECTED)
    for i, (a, *_rest) in enumerate(party(mem)):
        if a == (s, o):
            return i
    return None


# Player 32: Jeremy's take rule (board, 2026-11-20 01:20; with the reload rule, OP_RELOAD=1): only magic items, gems
# and jewellery, coins worth their weight, missiles to USE (never bought while looted ones last), and anything else
# worth 100 gp or more; junk stays.
JEREMY = __import__("os").environ.get("OP_RELOAD") == "1"
MISSILE_WORDS = ("ARROW", "QUARREL", "DART", "BOLT", "SLING STONE")


# Player 43 (Plan 5's (b), Jeremy 15:22: before Tyranthraxus only weightless items from the guards' pile): plan step
# `lightloot on|off`; while on, only rings, gems, jewellery or items of weight 1 or less, and no SHARE of the coins
LIGHT = {"on": False}
NOSHARE = {"on": False}     # Player 44: `noshare on`: leave a pile's coins


def worth_taking(it):
    up = it["name"].upper()
    if LIGHT["on"] and not (it["weight"] <= 1 or any(w in up for w in ("RING", "GEM", "JEWEL", "NECKLACE"))):
        return False
    if it["plus"] != 0 or "+" in up or it["type"] in QUEST_ITEM_TYPES or any(w in up for w in LOOT_WORDS):
        return True
    if JEREMY:
        return any(w in up for w in MISSILE_WORDS) or (it["price"] >= 100 and it["weight"] <= 400)
    return it["price"] >= 20 and it["weight"] <= 400

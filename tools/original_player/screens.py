"""Which screen is up: the wait site (memory) plus the screen's text and colours (the game's 8x8 font).

kinds: walking, enter (a text box waiting for Enter), hmenu (items on row 24: hot keys), vmenu (items on rows
18-22, the white one highlighted: arrows and Enter), member (pick a party member: SELECT, the highlighted name in
the party list), combat (a member's turn: MOVE VIEW AIM USE QUICK DONE), encounter (COMBAT WAIT FLEE PARLAY...),
treasure (VIEW TAKE POOL ... EXIT), continue (CONTINUE BATTLE: YES NO), yesno, wheel (the code word),
title, mainmenu, camp, unknown.
"""

WHITE = (255, 255, 255)


def _rowcol(im, r, x0=8, x1=312):
    from collections import Counter
    c = Counter(im.getpixel((x, y)) for x in range(x0, x1) for y in range(r * 8, r * 8 + 8))
    c.pop((0, 0, 0), None)
    return c.most_common(1)[0][0] if c else None


def items(bottom):
    """Row 24's menu items: words in capitals separated by single spaces form one item only in
    known cases; the original separates items by one space, so split on known item names."""
    return bottom.split()


def _vmenu_items(rows, im):
    its, hl = [], None
    for r in range(18, 23):
        t = rows[r].strip("? ").strip()
        if not t:
            continue
        its.append(t)
        if _rowcol(im, r) == WHITE:
            hl = len(its) - 1
    return its, hl


def _vmenu_over_walking(rows, im):
    """Player 28: a vertical menu whose bottom row still reads the walking menu: text on row 17 (not white), and
    among rows 18-22 at least two items, exactly one of them white and the rest green."""
    if not rows[17].strip("? \\") or _rowcol(im, 17) == WHITE:
        return False
    rs = [r for r in range(18, 23) if rows[r].strip("? \\")]
    cols = [_rowcol(im, r) for r in rs]
    # Player 32 (p32d1, 4:10 9,6: a trap's text in green, then "BRAM IS HIT FOR 4 POINTS OF DAMAGE." in white): a
    # sentence is not a menu item
    if any(rows[r].strip("? \\").endswith(".") for r, c in zip(rs, cols) if c == WHITE):
        return False
    return len(cols) >= 2 and cols.count(WHITE) == 1 and all(c in (WHITE, GREEN) for c in cols)


GREEN = (85, 255, 85)


def classify(st):
    rows, im, site = st["rows"], st["im"], st["site"]
    b = rows[24].strip("? ")
    text = " ".join(rows[r].strip("? ") for r in range(17, 23) if rows[r].strip("? \\"))
    out = {"bottom": b, "text": text}
    if site == "OVR:0010f":
        out["kind"] = "title"
    elif (site == "EXE:07cc6" and "PRESS <ENTER>" not in b and not b.startswith("PRESS ANY KEY")) \
            or "HAS BEEN DESTROYED" in " ".join(rows[r] for r in range(1, 10)):
        # Player 7: 2:9's damage text before a fight ("PRESS <ENTER>/<RETURN> TO CONTINUE") also waits at EXE:07cc6
        # Player 22: so does a trap's text (Kovel's cabinet, 3:14 3,13: "PRESS ANY KEY TO CONTINUE"): an enter screen
        out["kind"] = "wiped"
    elif b.startswith("INPUT THE CODE WORD"):
        out["kind"] = "wheel"
    elif "ENCAMP" in b and b.endswith("LOOK") and _vmenu_over_walking(rows, im):
        # Player 28: a step script's MENU_VERTICAL can leave the walking menu on row 24 (Valjevo's gate, ECL 5:3
        # 0xA8D0, on a bump W from 12,7 / 12,8: p27k3-k5 asked it, the tool read "walking" and bumped on): the
        # question on row 17, one item white (lit), the others green
        its, hl = _vmenu_items(rows, im)
        out.update(kind="vmenu", question=rows[17].strip("? "), items=its, highlight=hl)
    elif "ENCAMP" in b and b.endswith("LOOK"):     # AREA CAST VIEW ENCAMP SEARCH LOOK; CAST ... LOOK in the wilderness
        out["kind"] = "walking"
    elif "PRESS <ENTER>" in b or "PRESS <RETURN>" in b or b.startswith("PRESS BUTTON OR") or b.startswith("PRESS ANY KEY"):   # 5:7 (Player 2); 2:9's "PRESS BUTTON OR <RETURN>" (Player 3)
        out["kind"] = "enter"
    elif b.startswith("MOVE VIEW AIM") or ("QUICK" in b and "DONE" in b):
        out["kind"] = "combat"
        out["member"] = rows[1].strip("? ").strip()
    elif b.startswith("CONTINUE BATTLE"):
        out["kind"] = "continue"
    elif b.startswith("COMBAT WAIT FLEE") or b.startswith("COMBAT FLEE"):
        out["kind"] = "encounter"
    elif b.startswith("VIEW") and "EXIT" in b and ("POOL" in b or "TAKE" in b):
        out["kind"] = "treasure"
    elif b.startswith("CHOOSE A FUNCTION"):
        out["kind"] = "mainmenu"
        # Player 3: the party menu (also a training hall's, PROGRAM 0): the party at rows 4-9 from column 1, the
        # chosen member white (End = next, Home = previous); the functions by their first letters.
        names, hl = [], None
        # Player 57 (p57i1: the hired CURATE on row 10, lit, and the seq found no highlight): rows 4-11, eight members
        for r in range(4, 12):
            name = rows[r][1:16].strip("? ").strip()
            if not name:
                continue
            names.append(name)
            if _rowcol(im, r, 8, 16 * 8) == WHITE:
                hl = len(names) - 1
        out["names"], out["highlight"] = names, hl
    elif b.startswith("LOAD WHICH GAME"):
        out["kind"] = "load"
    elif b.startswith("SAVE WHICH GAME"):
        out["kind"] = "saveslot"
    elif b.endswith("SELECT") or b.endswith("SELECT EXIT"):
        out["kind"] = "member"
        out["question"] = b
        # the party list: rows 4-9, columns 18-38; the highlighted name is white (Player 36: rows 10-11 too, an NPC
        # as the seventh: p36k1, PRINCESS FATIMA on row 10 and TRADE WITH WHOM had no rule)
        hl = None
        names = []
        for r in range(4, 12):
            name = rows[r][17:32].strip("? ").strip()
            if not name:
                continue
            names.append(name)
            if _rowcol(im, r, 17 * 8, 33 * 8) == WHITE:
                hl = len(names) - 1
        out["names"], out["highlight"] = names, hl
    elif b == "" and rows[17].strip("? "):
        # a vertical menu: the question on row 17, items below, the highlighted one white
        its, hl = [], None
        for r in range(18, 23):
            t = rows[r].strip("? ").strip()
            if not t:
                continue
            its.append(t)
            if _rowcol(im, r) == WHITE:
                hl = len(its) - 1
        out.update(kind="vmenu", question=rows[17].strip("? "), items=its, highlight=hl)
    elif b in ("YES NO", "YES  NO") or b.endswith(" YES NO"):
        out["kind"] = "yesno"
    elif b.startswith("CAMP") or b.startswith("SAVE VIEW MAGIC") or "REST" in b and "EXIT" in b:
        out["kind"] = "camp"
    elif b:
        out["kind"] = "hmenu"
        out["items"] = b.split()
    else:
        out["kind"] = "unknown"
    return out

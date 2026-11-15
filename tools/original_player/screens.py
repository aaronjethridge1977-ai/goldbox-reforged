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


def classify(st):
    rows, im, site = st["rows"], st["im"], st["site"]
    b = rows[24].strip("? ")
    text = " ".join(rows[r].strip("? ") for r in range(17, 23) if rows[r].strip("? \\"))
    out = {"bottom": b, "text": text}
    if site == "OVR:0010f":
        out["kind"] = "title"
    elif site == "EXE:07cc6" or "PARTY HAS BEEN DESTROYED" in " ".join(rows[r] for r in range(1, 10)):
        out["kind"] = "wiped"
    elif b.startswith("INPUT THE CODE WORD"):
        out["kind"] = "wheel"
    elif b.startswith("AREA") and "ENCAMP" in b:
        out["kind"] = "walking"
    elif "PRESS <ENTER>" in b or "PRESS <RETURN>" in b:
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
    elif b.startswith("LOAD WHICH GAME"):
        out["kind"] = "load"
    elif b.startswith("SAVE WHICH GAME"):
        out["kind"] = "saveslot"
    elif b.endswith("SELECT") or b.endswith("SELECT EXIT"):
        out["kind"] = "member"
        out["question"] = b
        # the party list: rows 4-9, columns 18-38; the highlighted name is white
        hl = None
        names = []
        for r in range(4, 10):
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

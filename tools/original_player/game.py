"""The running original as a game the Player can read and drive.

  state()  which input the original is waiting for (from the key-wait hook in memory), the screen's
           text rows (the game's own 8x8 font, exact), the party's square and facing, the clock.
  press(k) sends one key, only while the original waits for one, and waits until it has taken it.
"""
import os, struct, sys, time, json
import orig, hooks

sys.path.insert(0, orig.LAB)


class _Lazy:
    """The lab's keys.py (XTest sender) and lab.py (screen and font) open the X display when imported:
    import them only once this lab's Xvfb runs."""
    def __init__(self, name):
        self.name, self.mod = name, None

    def __getattr__(self, a):
        if self.mod is None:
            self.mod = __import__(self.name)
        return getattr(self.mod, a)


_keys = _Lazy("keys")
_lab = _Lazy("lab")

BLOCK = 0x84DC    # the current ECL block (lab: 20 in the Slums -> 18 in Podol Plaza; README.md)


class Timeout(Exception):
    pass


class Stalemate(Timeout):
    """A fight that draws dice but in which no figure's hit points change for OP_STALE seconds (Player 2)."""


KINDS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "waits.json")))


class Game:
    def __init__(self, log=None):
        self.mem = orig.Mem()
        hooks.install(self.mem)
        self.keys = hooks.Keys(self.mem)
        self.where = hooks.Locator(self.mem, orig.GAME, os.path.join(orig.LAB, "re", "start.img"))
        self.log = log or (lambda *a: None)
        self.nkeys = 0
        self.last = None
        self.unknown_sites = set()
        # Player 15: OP_MAGIC=1: Alt-M once a fight, at its first computer turn (QUICK members cast only with MAGIC
        # ON, off at every fight's start: GAME.OVR 0xE457, Combat's combat_screen.gd toggle_magic); player.py clears
        # magic_sent when the fight is over
        self.auto_magic = os.environ.get("OP_MAGIC") == "1"
        self.magic_sent = False
        # Player 30: `tactics on`: Space at the fight's first poll hands the party's QUICK members back to the player
        # (GAME.OVR 0xBC26); player.py clears control_sent when the fight is over, as magic_sent
        self.take_control = False
        self.control_sent = False
        # Player 27: `shortcutwin <area> <x,y>` (Q27 (a), main's bot's logged shortcut win): ((area), (x, y)) armed by
        # the plan; at the first poll of the next fight there, every monster's HP and status are set to 0 / dead
        self.shortcut = None
        self.shortcut_note = None
        # Player 29: `shortcutwin <area> <x,y> <n>`: the next n fights there (5:7 3,8: the two guards, then
        # Tyranthraxus after the vote); re-armed once the last one's figures are gone from the list
        self.shortcut_more = 0
        self.shortcut_rearm = None
        self.shortcut_sig = None
        self.party_size = 0
        self.beat = time.monotonic()
        self.stale = None         # (the figures' hit points, since when) while dice are drawn
        self.stale_limit = float(os.environ.get("OP_STALE", "600"))

    # -- reading ------------------------------------------------------------------------------------------
    def wait_kind(self, dt=0.06):
        """('key', site) while GetKey waits, ('poll', site) while a loop keeps polling KeyPressed,
        ('busy', None) otherwise."""
        a = self.keys.read()
        if a["waiting"]:
            return "key", self.where(*a["caller"])
        time.sleep(dt)
        b = self.keys.read()
        if b["waiting"]:
            return "key", self.where(*b["caller"])
        if b["polls"] != a["polls"] and b["pcaller"] == a["pcaller"]:
            return "poll", self.where(*b["pcaller"])
        if b["polls"] != a["polls"]:
            # Player 24: an animated picture (7:23's fountain, p24b2) polls the keyboard from its own loop between the
            # screen's waits, so the two reads can name different callers: a known input site among them is the wait.
            for s in (self.where(*b["pcaller"]), self.where(*a["pcaller"])):
                if s in KINDS:
                    return "poll", s
        return "busy", None

    def rows(self, im=None):
        im = im or _lab.screen()
        return {r: _lab.text(im, r) for r in range(25)}, im

    def area(self):
        """(data set, block): the data set is ECL 0x6E12 (words at [DS:0x49D6] + 2 x addr + 0x2A00)."""
        s, o = self.mem.farptr(0x49D6)
        ds_ = self.mem.far(s, (o + 0x6E12 * 2 + 0x2A00) & 0xFFFF, 1)[0]
        return ds_, self.mem.u8(BLOCK)

    def party(self):
        """[(name, level, hp, max hp)] from the party's records: a list from the far pointer DS:0x5D96, each
        record's next at +0x104; name +0 (length first), max HP +0x32, HP +0x11B, levels +0x96..+0x9D,
        status +0x10C (README.md)."""
        out = []
        s, o = self.mem.farptr(0x5D96)
        while s and len(out) < 8:
            r = self.mem.far(s, o, 0x120)
            name = r[1:1 + min(r[0], 15)].decode("latin1")
            lv = "/".join(str(v) for v in r[0x96:0x9E] if v)
            out.append((name, lv, r[0x11B], r[0x32]))
            if self.party_size and len(out) >= self.party_size:
                break
            o, s = struct.unpack_from("<HH", r, 0x104)
        return out

    def figures(self, limit=90):
        """[(name, hp, status)] for the whole list from DS:0x5D96: the party, and in fights the monsters after
        it (README.md). Player 2: read at every heartbeat to tell a fight that goes on from one that stalls."""
        out = []
        s, o = self.mem.farptr(0x5D96)
        while s and len(out) < limit:
            r = self.mem.far(s, o, 0x120)
            out.append((r[1:1 + min(r[0], 15)].decode("latin1"), r[0x11B], r[0x10C]))
            o, s = struct.unpack_from("<HH", r, 0x104)
        return out

    def _shortcut_win(self, site):
        """Player 27: the logged shortcut win (Q27 (a)): every figure after the party in DS:0x5D96's list gets HP 0
        (+0x11B), status 6, dead (+0x10C), out of the fight (+0x10D 0), no blows or spells, at the fight's first
        poll, if the party stands where the plan armed it."""
        (area, xy), here = self.shortcut, (self.area(), tuple(self.mem.ds(0x6AAD, 2)))
        if here != (area, xy):
            return
        n = len(self.party())
        out, i = [], 0
        s, o = self.mem.farptr(0x5D96)
        while s and i < 90:
            r = self.mem.far(s, o, 0x120)
            if i >= n:
                out.append("%s %d" % (r[1:1 + min(r[0], 15)].decode("latin1"), r[0x11B]))
                # HP 0, status dead, out of the fight (+0x10D: START.EXE 0xBA:0x23DB's count of enemies left; the
                # turn order skips figures not in it); p27c1 showed HP and status alone don't stop a monster that
                # already has its initiative, so its blows (cached dice +0x115-0x11A) and memorized spells
                # (+0x17-0x2B) are emptied too for the rest of the round
                self.mem.wlin(s * 16 + o + 0x11B, bytes([0]))
                self.mem.wlin(s * 16 + o + 0x10C, bytes([6]))
                self.mem.wlin(s * 16 + o + 0x10D, bytes([0]))
                self.mem.wlin(s * 16 + o + 0x115, bytes(6))
                self.mem.wlin(s * 16 + o + 0x17, bytes(21))
            o, s = struct.unpack_from("<HH", r, 0x104)
            i += 1
        self.shortcut = None
        self.shortcut_sig = self._monster_sig()
        if self.shortcut_more > 0:
            self.shortcut_more -= 1
            self.shortcut_rearm = (area, xy)
        self.shortcut_note = "SHORTCUT win at %d:%d %d,%d (Q27 (a), as main's bot's): %d monsters set to HP 0, dead, at %s: %s" % (
            area + xy + (len(out), site, ", ".join(out)))
        self.log(self.shortcut_note)

    def _monster_sig(self):
        """Player 29: the figures after the party in DS:0x5D96's list, by name (a new fight's monsters differ)."""
        n, out, i = len(self.party()), [], 0
        s, o = self.mem.farptr(0x5D96)
        while s and i < 90:
            r = self.mem.far(s, o, 0x120)
            if i >= n:
                out.append(r[1:1 + min(r[0], 15)].decode("latin1"))
            o, s = struct.unpack_from("<HH", r, 0x104)
            i += 1
        return tuple(out)

    def _nfigures(self):
        try:
            return len(self.figures())
        except Exception:
            return 0

    def fight_beat(self):
        """The heartbeat's look at the fight: a log line (figures, standing, hit points) and the stalemate
        clock: Stalemate once no figure's hit points or status changed for stale_limit seconds."""
        try:
            f = self.figures()
        except Exception as e:     # the list is rebuilt between fights
            self.log("BEAT figures unreadable: %s" % e)
            return
        sig = tuple((h, st) for _, h, st in f)
        up = sum(1 for _, h, st in f if h > 0 and st == 0)
        self.log("BEAT figures %d standing %d hp %d" % (len(f), up, sum(h for _, h, _ in f)))
        now = time.monotonic()
        if self.stale is None or self.stale[0] != sig:
            self.stale = (sig, now)
        elif now - self.stale[1] > self.stale_limit:
            names = {}
            for n, h, st in f[self.party_size or 0:]:
                if h > 0 and st == 0:
                    names[n] = names.get(n, 0) + 1
            raise Stalemate("stalemate: no hit point or status changed for %d s while the fight drew dice "
                            "(%d figures, %d standing; monsters standing: %s)" % (
                                now - self.stale[1], len(f), up,
                                ", ".join("%s x%d" % kv for kv in names.items()) or "none"))

    def status(self):
        s, o = self.mem.farptr(0x5D96)
        out = []
        while s and len(out) < 8:
            r = self.mem.far(s, o, 0x120)
            out.append(r[0x10C])
            o, s = struct.unpack_from("<HH", r, 0x104)
        return out

    def state(self):
        kind, site = self.wait_kind()
        rows, im = self.rows()
        name = KINDS.get(site, "?") if site else None
        return {"wait": kind, "site": site, "screen": name, "bottom": rows[24].strip("? "),
                "rows": rows, "im": im}

    def settled(self, timeout=60):
        """Waits until the original waits for input at a known site (a GetKey wait counts always) and the
        screen reads the same twice; returns the state (also kept as self.last)."""
        t = time.monotonic()
        prev = None
        mark = None
        near = 0
        while time.monotonic() - t < timeout:
            now = (self.mem.seed(), self.mem.ds(0x6AAD, 3))
            if now != mark:            # dice drawn or the party moved: the game is working, not stuck
                mark, t = now, time.monotonic()
                if time.monotonic() - self.beat > 30:     # the watchdog's heartbeat while a fight plays itself
                    self.beat = time.monotonic()
                    self.log("BEAT seed %08x" % now[0])
                    self.fight_beat()
            kind, site = self.wait_kind()
            if kind == "key" or (kind == "poll" and site in KINDS):
                self.stale = None
                rows, im = self.rows()
                box = [rows[r] for r in range(17, 25)]
                if prev is not None and site == prev[1] and (rows == prev[0] or (box == prev[2] and near >= 5)):
                    # (Player 24: or the text box and the site the same over five reads while an animated picture
                    # keeps the other rows changing: 7:23's fountain)
                    self.last = {"wait": kind, "site": site, "rows": rows, "im": im,
                                 "bottom": rows[24].strip("? ")}
                    return self.last
                near = near + 1 if prev is not None and site == prev[1] and box == prev[2] else 0
                prev = (rows, site, box)
                time.sleep(0.05)
                continue
            if kind == "poll" and site not in KINDS and str(site).startswith("OVR:") and self.shortcut_rearm \
                    and len(self.party()) < self._nfigures() and self._monster_sig() != self.shortcut_sig:
                self.shortcut, self.shortcut_rearm = self.shortcut_rearm, None
                self.log("SHORTCUT re-armed at %d:%d %d,%d (%d more after this)" % (
                    self.shortcut[0] + self.shortcut[1] + (self.shortcut_more,)))
            if kind == "poll" and site not in KINDS and str(site).startswith("OVR:") and self.shortcut \
                    and len(self.party()) < self._nfigures():
                self._shortcut_win(site)
            if kind == "poll" and site not in KINDS and str(site).startswith("OVR:") and self.auto_magic \
                    and not self.magic_sent \
                    and len(self.party()) < self._nfigures():
                self.magic_sent = True
                _keys.key("alt+m")
                self.log("MAGIC alt+m (MAGIC ON for the party's QUICK members) at %s" % site)
            elif kind == "poll" and site not in KINDS and str(site).startswith("OVR:") and self.take_control \
                    and not self.control_sent and len(self.party()) < self._nfigures():
                self.control_sent = True
                _keys.key("space")
                self.log("CONTROL space (the party's QUICK members handed back for the tactical mode) at %s" % site)
            if kind == "poll" and site not in self.unknown_sites:
                self.unknown_sites.add(site)
                self.log("SITE polled (not an input wait):", site)
            if kind == "busy" and time.monotonic() - t > 15:
                # Player 24: 7:23's fountain (p24b2, p24b3): its picture animates while the text box waits, and the
                # original's key reads come from no caller we know; after 15 s busy, a text box asking for RETURN that
                # reads the same twice is that wait (the menu site's, OVR:2ce3a, as every text box).
                rows, im = self.rows()
                if "PRESS BUTTON OR <RETURN> TO CONTINUE" in rows[24]:
                    box = [rows[r] for r in range(17, 25)]    # the text box only: the picture's rows animate
                    if prev is not None and box == prev[0] and prev[1] == "busy-enter":
                        self.log("BUSY text box asks for RETURN: taken as the menu's wait")
                        self.last = {"wait": "poll", "site": "OVR:2ce3a", "rows": rows, "im": im,
                                     "bottom": rows[24].strip("? ")}
                        return self.last
                    prev = (box, "busy-enter")
                    time.sleep(0.3)
                    continue
            prev = None
            time.sleep(0.1)
        return None

    # -- driving ------------------------------------------------------------------------------------------
    def until_waiting(self, timeout=60, step=0.1):
        t = time.monotonic()
        while time.monotonic() - t < timeout:
            kind, site = self.wait_kind()
            if kind != "busy":
                return kind, site
            time.sleep(step)
        return None, None

    def press(self, k, timeout=60):
        """Sends k once the original waits for a key; returns when it has taken it (GetKey's leave count
        moves, or the BIOS buffer empties for polled input)."""
        kind, site = self.until_waiting(timeout)
        if kind is None:
            raise Timeout("the original never waited for a key (before %r)" % k)
        # Player 27: OP_KEYDELAY=<s>: wait that long before each key (a film for a person: texts stay readable)
        if os.environ.get("OP_KEYDELAY"):
            time.sleep(float(os.environ["OP_KEYDELAY"]))
        before = self.keys.read()
        self.nkeys += 1
        self.log("KEY %d %s at %s %s" % (self.nkeys, k, kind, site))
        _keys.key(k)
        t = time.monotonic()
        while time.monotonic() - t < 5:
            now = self.keys.read()
            if now["leave"] != before["leave"]:
                return kind, site
            time.sleep(0.02)
        raise Timeout("key %r not taken at %s %s" % (k, kind, site))


def boot(save, log=print):
    """A fresh DOSBox: the hook goes in before the title, then title -> LOAD SAVED GAME -> the save (and the
    code word whenever it is asked). Returns at the save's first walking menu."""
    import screens
    orig.start()
    t = time.monotonic()
    while True:
        try:
            m = orig.Mem()
            break
        except (RuntimeError, SystemExit):
            if time.monotonic() - t > 30:
                raise Timeout("START.EXE never appeared in DOSBox's memory")
            time.sleep(0.05)
    hooks.install(m)
    g = Game(log=log)
    for _ in range(30):
        st = g.settled()
        if st is None:
            raise Timeout("boot: no input wanted")
        k = screens.classify(st)["kind"]
        if k == "walking":
            return g
        if k == "wheel":
            log("BOOT code word: %s" % _keys.solve_wheel(log))
            time.sleep(0.5)
            continue
        key = {"title": "enter", "mainmenu": "l", "load": save.lower()}.get(k)
        if key is None:
            # Player 2: a save the original refuses stops on a DOS line ("Unable to load wallset in
            # LoadWallSet."): keep the picture and every row of text.
            shot = os.path.join(orig.LAB, "logs", "boot_stop_%s.png" % time.strftime("%H%M%S"))
            st["im"].save(shot)
            text = " / ".join(r.strip() for r in st["rows"].values() if r.strip())
            raise Timeout("boot: unexpected screen %s %r (screen text: %s; %s)" % (k, st["bottom"], text, shot))
        g.press(key)
    raise Timeout("boot: never reached the walking screen")

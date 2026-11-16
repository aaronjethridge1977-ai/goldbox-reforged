#!/usr/bin/env python3
"""sfx.py: Pool of Radiance's PC-speaker sound driver (START.EXE, unpacked image: code and data both in segment 0x8AE),
run in Python on the game's own data, a reference for ours' port (scripts/ui/speaker.gd).

    sfx.py list                 every row's speaker output: (ticks, PIT divisor or 0 for off) runs
    sfx.py wav <row> <out.wav>  a row rendered as the speaker's square wave (44100 Hz, 8-bit)

The driver (Combat Chat 10): the timer is set to divisor 0x13B1 (1193182 / 5041 = 236.7 ticks a second, 0x9E83); each
tick 0x9F57 steps the four speaker voices (block DS:0x22D, 0x30 bytes each, note table DS:0x3AD) and the speaker sounds
the first voice with a duration left and a non-zero gate word (+0x0A): PIT channel 2 gets its divisor (+0x08), port 0x61
its gate bits (+0x0A & 3), if sound is on (DS:0x20D). A sound starts at 0xA222 (row n: four script pointers at DS:0x55F +
8n). The game calls the wrapper 0x8BBC with id n: 0 all off, 1 on, 0xFF stop, else row n - 1 on the speaker (DS:0x5372 =
1) or the Tandy (0). Voice fields: +0 ticks left, +2 script, +4 base divisor, +6 slide, +8 out, +0A gate/volume, +0C its
slide, +0E tempo, +12 transpose, +14 release count, +16 envelope table, +18 its index, +1A its step count, +1C vibrato
table, +1E phase, +20 speed, +22 depth, +24 length. Script bytes: FA reset this voice, FB return, FC call, FD reset the
voice at the operand, FE loop (field, target), FF set field (field 0 ends the tick's chain), else a 3-byte note event
(byte 0: voice in bits 5-7, byte 1: note & 0x7F (0x7F rest), bit 7 the chain's last, byte 2: duration x tempo)."""
import os, struct, sys, wave

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
import ovr  # noqa: E402

TICK_HZ = 1193182 / 0x13B1
SEG = 0x8AE * 16


class Driver:
    def __init__(self, img):
        self.m = bytearray(img[SEG:SEG + 0x10000])     # the driver's segment (code and data)
        self.block, self.notes, self.size = 0x22D, 0x3AD, self.m[0x1DA]
        self.ret = 0
        self.playing = 0

    def w(self, a):
        return struct.unpack_from("<H", self.m, a & 0xFFFF)[0]

    def sw(self, a, v):
        struct.pack_into("<H", self.m, a & 0xFFFF, v & 0xFFFF)

    def start(self, row):
        self.playing = row + 1
        for k in range(4):
            ptr = self.w(0x55F + 8 * row + 2 * k)
            v = self.block + k * self.size
            if ptr:
                for o in range(0, 0x30, 2):
                    self.sw(v + o, 0)
                self.sw(v + 2, ptr)
                self.sw(v, 1)

    def _reset(self, v):
        for o in (4, 6, 8, 0xA, 0xC, 0x10, 0x12, 0x16, 0x18, 0x1A, 0x1C, 0x1E, 0x20, 0x22, 0x24):
            self.sw(v + o, 0)

    def _events(self, si):
        di = self.w(si + 2)
        if di == 0:
            return
        cur = si
        while True:
            bl = self.m[di]; di += 1
            if bl >= 0xFA:
                op = bl
                if op == 0xFE:                       # loop: counter field, target
                    f = self.m[di]; tgt = self.w(di + 1); di += 3
                    if self.w(si + f) == 0:
                        di = tgt
                    else:
                        self.sw(si + f, self.w(si + f) - 1)
                        if self.w(si + f) != 0:
                            di = tgt
                    continue
                if op == 0xFD:                       # reset another voice
                    self._reset(self.w(di) + self.block); di += 2
                    continue
                if op == 0xFA:                       # reset this voice
                    self._reset(si)
                    continue
                if op == 0xFF:                       # set a field
                    f = self.m[di]; v = self.w(di + 1); di += 3
                    self.sw(si + f, v)
                    if f != 0:
                        continue
                    break
                if op == 0xFB:                       # return
                    di = self.ret
                    continue
                if op == 0xFC:                       # call
                    tgt = self.w(di); self.ret = di + 2; di = tgt
                    continue
            # note events: byte 0 (bl), then note, duration
            while True:
                cl = bl >> 5
                v = self.block + cl * self.size
                tempo = self.w(si + 0xE)
                dur = self.m[di + 1] if (tempo & 0xFF) <= 1 else ((tempo & 0xFF) * self.m[di + 1]) & 0xFFFF
                self.sw(si, dur)
                note = self.m[di] & 0x7F
                if note != 0x7F and cl == 0:
                    d = self.w(si)
                    self.sw(v, d); self.sw(v + 0x14, d)
                    ax = (note + self.w(v + 0x12)) & 0xFFFF
                    self.sw(v + 0x18, 0); self.sw(v + 0x1A, 1)
                    octv, ax = divmod(ax, 12)
                    div = self.w(self.notes + 2 * ax) >> octv
                    self.sw(v + 4, div); self.sw(v + 8, div)
                last = self.m[di] & 0x80
                di += 2
                if last:
                    break
                bl = self.m[di]; di += 1
            break
        # end of the chain (0xA16F)
        if self.w(cur) == 0:
            di = 0
        self.sw(cur + 2, di)

    def _step(self, si):
        self.sw(si + 0xA, self.w(si + 0xA) + self.w(si + 0xC))
        self.sw(si + 4, self.w(si + 4) + self.w(si + 6))
        dx = 0
        ax = (self.w(si + 0x1E) + self.w(si + 0x20)) & 0xFFFF
        if ax:
            if ax >= self.w(si + 0x24):
                ax = (ax - self.w(si + 0x24)) & 0xFFFF
            self.sw(si + 0x1E, ax)
            sax = ax - 0x10000 if ax & 0x8000 else ax
            idx = (sax >> 4) + self.w(si + 0x1C)
            b = self.m[idx & 0xFFFF]
            p = ((b << 8) - (0x10000 if b & 0x80 else 0)) * (self.w(si + 0x22) - (0x10000 if self.w(si + 0x22) & 0x8000 else 0))
            dx = (p >> 16) & 0xFFFF
        self.sw(si + 8, dx + self.w(si + 4))
        if self.w(si + 0x14):
            self.sw(si + 0x14, self.w(si + 0x14) - 1)
            if self.w(si + 0x14) == 0:
                self.sw(si + 0x18, 0x10); self.sw(si + 0x1A, 1)
        self.sw(si, self.w(si) - 1)
        if self.w(si) == 0:
            self._events(si)
        if self.w(si + 0x1A):
            self.sw(si + 0x1A, self.w(si + 0x1A) - 1)
            if self.w(si + 0x1A) == 0:
                while True:
                    bx = self.w(si + 0x16) + self.w(si + 0x18)
                    if self.w(bx + 2) == 0xFFFF:
                        self.sw(si + 0xA, self.w(bx))
                        if self.w(bx) == 0:
                            self.sw(si + 0xC, 0)
                        self.sw(si + 0x18, self.w(si + 0x18) + 4)
                        continue
                    self.sw(si + 0xC, self.w(bx)); self.sw(si + 0x1A, self.w(bx + 2))
                    self.sw(si + 0x18, self.w(si + 0x18) + 4)
                    break

    def tick(self):
        """One timer tick (0x9F57): the speaker's divisor, or 0 for off."""
        if not self.playing:
            return 0
        pick = 0
        for k in range(4):
            si = self.block + k * self.size
            if self.w(si):
                self._step(si)
                if not pick and self.w(si + 0xA) and self.w(si):
                    pick = si
        if not pick or not (self.w(pick + 0xA) & 3):
            return 0
        return self.w(pick + 8)

    def active(self):
        return any(self.w(self.block + k * self.size) for k in range(4))


def render(row, max_ticks=2400):
    d = Driver(ovr.image())
    d.start(row)
    out = []
    for t in range(max_ticks):
        out.append(d.tick())
        if not d.active():
            break
    return out


def runs(seq):
    r = []
    for v in seq:
        if r and r[-1][1] == v:
            r[-1][0] += 1
        else:
            r.append([1, v])
    return r


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "list":
        for row in range(21):
            s = render(row)
            rs = runs(s)
            print("row %2d (id %2d): %4d ticks %.2fs: %s" % (row, row + 1, len(s), len(s) / TICK_HZ,
                  " ".join("%dx%s" % (n, "off" if v == 0 else "%dHz" % round(1193182 / v)) for n, v in rs[:14]) +
                  (" ..." if len(rs) > 14 else "")))
    elif a[0] == "wav":
        s = render(int(a[1]))
        rate, ph, data = 44100, 0.0, bytearray()
        per = rate / TICK_HZ
        acc = 0.0
        for v in s:
            acc += per
            n = int(acc); acc -= n
            for _ in range(n):
                if v:
                    ph = (ph + (1193182 / v) / rate) % 1.0
                    data.append(200 if ph < 0.5 else 56)
                else:
                    data.append(128)
        with wave.open(a[2], "wb") as f:
            f.setnchannels(1); f.setsampwidth(1); f.setframerate(rate); f.writeframes(bytes(data))
        print("%s: %d ticks, %.2f s" % (a[2], len(s), len(s) / TICK_HZ))

"""Make a lab save for the original that jumps to another area on the first step.

  python3 mksave.py <base letter> <new letter (B-I)> <ecl file> <block> <x> <y> <facing N|E|S|W> [addr=val ...] [xp<n>=<experience>] [pp<n>=<platinum>] [gp<n>=<gold>] [item<n>=<DAX>:<block>:<index>] [wplus<n>=<plus>] [strong]

The original's save holds the current area's script image from byte 0x1401 (base 0x9900).
This patches the script's "on move" entry (its first GOTO's target) to do what the game's
own boats and gates do: set the square (C04B/C04C/C04D) and the data set (6E12), then
NEW_ECL <block>. Load the save in the original and press Up once. addr=val writes a byte
of ECL memory 0x4900-0x4AFF in the save (hex address).
Character files CHRDAT<base>n are copied to CHRDAT<new>n. item<n>= gives character file n a copy of
the item record at that index of an item DAX block (e.g. item1=ITEM8:50:0, the silver bottle).
wplus<n>=<plus> sets the magic plus (record byte 50, signed) of character file n's first readied
item, its weapon in the shipped parties: both games use it for to-hit and damage (check 5's start).
strong gives 200 HP and AC -10 only: the original works THAC0 out again from the class and level
(it ignores 0x2D/0x110), so writing it would give ours a party the original doesn't have.
"""
import glob, os, shutil, struct, sys
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "game")
base, new, n, b, x, y, f = sys.argv[1:8]
B, N = base.upper(), new.upper()
s = bytearray(open(os.path.join(G, "SAVGAM%s.DAT" % B), "rb").read())
on_move = struct.unpack_from("<H", s, 0x1401 + 2)[0]      # GOTO [addr] at 0x9900
o = 0x1401 + on_move - 0x9900
def wm(v, a):
    return bytes([0x09, 0x00, v, 0x01, a & 255, a >> 8])
patch = wm(int(x), 0xC04B) + wm(int(y), 0xC04C) + wm("NESW".index(f.upper()), 0xC04D) + wm(int(n), 0x6E12) + bytes([0x20, 0x00, int(b)])
s[o:o + len(patch)] = patch
strong = "strong" in sys.argv[8:]
xp = {}
pp = {}
gp = {}
give = []
wplus = {}
for a in sys.argv[8:]:
    if a == "strong":
        continue
    if a.startswith("xp"):          # xp<n>=<experience> for character file n (1-6)
        k, v = a[2:].split("=")
        xp[int(k)] = int(v)
        continue
    if a.startswith("wplus"):       # wplus<n>=<plus> for character file n's first readied item
        k, v = a[5:].split("=")
        wplus[int(k)] = int(v)
        continue
    if a.startswith("item"):        # item<n>=<DAX>:<block>:<index> for character file n
        k, v = a[4:].split("=")
        give.append((int(k), v.split(":")))
        continue
    if a.startswith("gp"):          # gp<n>=<gold pieces> for character file n (chat 36)
        k, v = a[2:].split("=")
        gp[int(k)] = int(v)
        continue
    if a.startswith("pp"):          # pp<n>=<platinum pieces> for character file n
        k, v = a[2:].split("=")
        pp[int(k)] = int(v)
        continue
    k, v = a.split("=")
    s[1 + 2 * (int(k, 16) - 0x4900)] = int(v, 0)
for k in range(8):
    p = 0x3209 + k * 41
    ln = s[p]
    if 0 < ln <= 12:
        s[p + 1:p + 1 + ln] = s[p + 1:p + 1 + ln].replace(b"CHRDAT" + B.encode(), b"CHRDAT" + N.encode())
for p in glob.glob(os.path.join(G, "CHRDAT%s?.*" % B)):
    shutil.copy(p, p.replace("CHRDAT" + B, "CHRDAT" + N))
if strong:   # lab only: 200 HP, AC -10, so the walker survives late areas (THAC0 left alone)
    for p in glob.glob(os.path.join(G, "CHRDAT%s?.SAV" % N)):
        d = bytearray(open(p, "rb").read())
        d[0x32] = d[0x11B] = 200
        d[0xA9] = d[0x111] = 70
        open(p, "wb").write(d)
for n_, v in xp.items():
    p_ = os.path.join(G, "CHRDAT%s%d.SAV" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    struct.pack_into("<I", d_, 0xAC, v)
    open(p_, "wb").write(d_)
for n_, v in pp.items():
    p_ = os.path.join(G, "CHRDAT%s%d.SAV" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    struct.pack_into("<H", d_, 0x88 + 4 * 2, v)
    open(p_, "wb").write(d_)
for n_, v in gp.items():
    p_ = os.path.join(G, "CHRDAT%s%d.SAV" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    struct.pack_into("<H", d_, 0x88 + 3 * 2, v)
    open(p_, "wb").write(d_)
for n_, (f_, b_, i_) in give:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import dax
    rec = bytearray(dax.read_dax(os.path.join(G, f_ + ".DAX"))[int(b_)][63 * int(i_):63 * int(i_) + 63])
    rec[42:46] = bytes(4)            # the next-item pointer, zeroed as in a save
    stem = os.path.join(G, "CHRDAT%s%d" % (N, n_))
    with open(stem + ".ITM", "ab") as fh:
        fh.write(rec)
    d_ = bytearray(open(stem + ".SAV", "rb").read())
    d_[0xC7] += 1                    # the number of items
    open(stem + ".SAV", "wb").write(d_)
for n_, v in wplus.items():
    p_ = os.path.join(G, "CHRDAT%s%d.ITM" % (N, n_))
    d_ = bytearray(open(p_, "rb").read())
    for i_ in range(len(d_) // 63):
        if d_[63 * i_ + 52] == 1:
            d_[63 * i_ + 50] = v & 255
            break
    else:
        sys.exit("CHRDAT%s%d has no readied item" % (N, n_))
    open(p_, "wb").write(d_)
open(os.path.join(G, "SAVGAM%s.DAT" % N), "wb").write(s)
print("SAVGAM%s.DAT: first step goes to ECL%s block %s at %s,%s %s" % (N, n, b, x, y, f))

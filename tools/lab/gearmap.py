"""The magic-gear map (chat 69): every TREASURE item list and every monster's carried items, by area and event.

python3 gearmap.py <gear.tsv from gearmap.gd> <folder of ECL listings ecl_ECL<f>_<b>.txt> [all]
Marks: * magic (a plus, a save plus, cursed, a scroll), $ worth 100 gp or more, ! a story item.
Prints, area by area, each TREASURE (address, event number and its squares, coins, item list) and each fight's
monsters that carry items, with the items (magic ones marked *). 'all' lists ordinary items too.
The search script's dispatch (its longest ON_GOTO) gives the code's entry; the entry at or before an address is
taken as its own (shared subroutines can mislead: the address is printed). Squares: the GEO squares whose event
(info byte & the mask the script ANDs with) leads to that entry, directly or through a byte table
(COPY_MEM [table], [event], [var]); 'entry n' without squares when the dispatch isn't traced.
python3 gearmap.py <gear.tsv> <listings> [all] needs the game's ECL<f>.DAX for the tables: GAME=<folder> (default ./game).
"""
import collections, glob, os, re, sys
sys.path.insert(0, os.path.expanduser('~/gbr/lab'))
import dax

tsv, ldir = sys.argv[1], sys.argv[2]
show_all = len(sys.argv) > 3 and sys.argv[3] == 'all'
# START.EXE DS:0x05D6 by class: cleric 2, druid 16, fighter 8, paladin 64, ranger 128, magic-user 1, thief 4, monk 32;
# no item type has bit 128 (the ranger's): not read further.
CLS = [(1, 'MU'), (2, 'C'), (4, 'T'), (8, 'F'), (16, 'D'), (64, 'P')]
items = collections.defaultdict(list)   # (file, list) -> [row]
mons, sqinfo = {}, collections.defaultdict(list)   # (f, b) -> [(x, y, info)]
for line in open(tsv):
    p = line.rstrip('\n').split('\t')
    if p[0] == 'ITEM':
        items[(p[1], int(p[2]))].append(dict(type=int(p[4]), plus=int(p[5]), sp=int(p[6]), cursed=int(p[7]),
            count=int(p[8]), price=int(p[9]), weight=int(p[10]), cls=int(p[11]), name=p[12], spells=p[13] if len(p) > 13 else ''))
    elif p[0] == 'MON':
        mons[(int(p[1]), int(p[2]))] = p[3]
    elif p[0] == 'EVT':
        sqinfo[(int(p[1]), int(p[2]))].append((int(p[3]), int(p[4]), int(p[5])))


STORY = ('Holy Symbol', 'Key', 'Pass', 'Bottle', 'Tapestr', 'Boots')


def kind(it):
    """'*' magic (a plus, a save plus, cursed, a scroll), '$' worth 100 gp or more, '!' a story item, ' ' the rest."""
    if it['plus'] > 0 or it['sp'] > 0 or it['cursed'] or it['type'] in (61, 62):
        return '*'
    if it['price'] >= 100:
        return '$'
    if any(w in it['name'] for w in STORY):
        return '!'
    return ' '


def magic(it):
    return kind(it) != ' '


def who(c):
    if c & 0x5F == 0x5F:
        return 'any'
    return '/'.join(n for b, n in CLS if c & b)


def fmt(it):
    mark = kind(it)
    extra = ' CURSED' if it['cursed'] else ''
    sp = ': ' + it['spells'] if it['spells'] else ''
    return '%s %s%s%s (%s gp, wt %d, %s)' % (mark, it['name'], extra, sp, it['price'], it['weight'], who(it['cls']))


def treasure_list(f, lid):
    for n in [f] + [k for k in range(1, 9) if k != f]:
        if ('ITEM%d' % n, lid) in items:
            return 'ITEM%d' % n, list(reversed(items[('ITEM%d' % n, lid)]))
    return None, []


for path in sorted(glob.glob(os.path.join(ldir, 'ecl_ECL*_*.txt')), key=lambda s: [int(x) for x in re.findall(r'\d+', os.path.basename(s))]):
    f, b = [int(x) for x in re.findall(r'ECL(\d+)_(\d+)', path)[0]]
    ops = []
    for line in open(path):
        m = re.match(r'([0-9A-F]{4})  (\S+)\s*(.*)', line)
        if m:
            ops.append((int(m.group(1), 16), m.group(2), m.group(3)))
    table = max((o for o in ops if o[1] == 'ON_GOTO'), key=lambda o: o[2].count('['), default=None)
    entries, sq_of = [], {}
    if table:
        addrs = [int(x, 16) for x in re.findall(r'\[([0-9A-F]{4})\]', table[2])[1:]]
        entries = sorted((a, n) for n, a in enumerate(addrs))
        var = re.match(r'\[([0-9A-F]{4})\]', table[2]).group(1)
        k = ops.index(table)
        before = ops[max(0, k - 25):k]
        mask = 127
        evvar = None
        for a_, op_, args_ in before:
            m = re.match(r'(?:\[C04F\], (\d+)|(\d+), \[C04F\]), \[([0-9A-F]{4})\]', args_) if op_ == 'AND' else None
            if m:
                mask, evvar = int(m.group(1) or m.group(2)), m.group(3)
        blk = dax.read_dax(os.path.join(os.environ.get('GAME', 'game'), 'ECL%d.DAX' % f))[b]
        lookup = None
        for a_, op_, args_ in before:
            m = re.match(r'\[([0-9A-F]{4})\], \[([0-9A-F]{4})\], \[([0-9A-F]{4})\]', args_) if op_ == 'COPY_MEM' else None
            if m and m.group(2) == evvar and m.group(3) == var:
                t = int(m.group(1), 16) - 0x9900 + 2   # the block's 2-byte header: 0x9900 is byte 2
                lookup = lambda e, t=t, blk=blk: blk[t + e]
        if lookup is None and evvar and (var == evvar or var == '9800'):   # 9800: a loop counting up to the event
            lookup = lambda e: e
        if lookup:
            for x, y, info in sqinfo[(f, b)]:
                e = info & mask
                if e:
                    sq_of.setdefault(lookup(e), []).append((x, y))

    def event_of(addr):
        ev = None
        for a, n in entries:
            if a <= addr:
                ev = n
        return ev

    def where_of(addr):
        ev = event_of(addr)
        if ev is None:
            return 'a header script'
        sq = sq_of.get(ev)
        return 'entry %d at %s' % (ev, ' '.join('%d,%d' % s for s in sq[:8]) + (' ...' if len(sq) > 8 else '')) if sq else 'entry %d (no square traced)' % ev

    out = []
    for addr, op, args in ops:
        if op == 'TREASURE':
            a = [x.strip() for x in args.split(',')]
            lst = a[7] if len(a) > 7 else '?'
            where = where_of(addr)
            coins = ', '.join(a[:7])
            if lst.isdigit() and int(lst) < 128:
                src, lt = treasure_list(f, int(lst))
                shown = [it for it in lt if show_all or magic(it)]
                head = '%04X TREASURE (%s) list %s [%s] coins %s' % (addr, where, lst, src, coins)
                out.append(head + (':' if shown else ': nothing magic (%d items)' % len(lt)))
                out += ['      ' + fmt(it) for it in shown]
            elif lst.isdigit() and lst != '255':
                out.append('%04X TREASURE (%s) %d random items (TreasureMaker) coins %s' % (addr, where, int(lst) - 128, coins))
            elif not lst.isdigit():
                out.append('%04X TREASURE (%s) list from %s coins %s' % (addr, where, lst, coins))
        elif op == 'LOAD_MON':
            a = [x.strip() for x in args.split(',')]
            if a[0].isdigit():
                lt = items.get(('MON%dITM' % f, int(a[0])), [])
                shown = [it for it in lt if show_all or magic(it)]
                if shown:
                    out.append('%04X fight (%s): %s x%s, each carries:' % (addr, where_of(addr),
                        mons.get((f, int(a[0])), '#' + a[0]), a[1]))
                    out += ['      ' + fmt(it) for it in shown]
    if out:
        print('== %d:%d' % (f, b))
        print('\n'.join(out))

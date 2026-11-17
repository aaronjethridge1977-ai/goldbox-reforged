class_name CoinPile
## The money pile the treasure screen and the shops share with the party, as the original keeps it
## (Combat Chat 13, from GAME.OVR; Player 12's shop POOL request). One pile, seven counts (copper,
## silver, electrum, gold, platinum, gems, jewellery: DS:0x67F4, 7 dwords), emptied as a shop opens
## (0x7230).
##   POOL (0x25191): every player character's coins, all seven kinds, go on the pile; an NPC
##     (control byte 128 and over) keeps his, unless his control is 0xB3.
##   SHARE (0x252C3): each kind is split by the number of player characters (control 0 or 0xB3);
##     each player character in party order (an NPC, 0x80 and over, gets nothing) takes his part
##     from jewellery down to copper, then the remainder as share() says (Combat Chat 16: the
##     overloaded member's word arithmetic and the second pass over the remainder).
##   A pile's or a purse's worth in gold (0x24D31, 0x238F8): its five coin kinds in copper, + 100,
##     / 200 (rounded, a word); setting a worth (0x24E0E, 0x24DB9) empties the five coin kinds and
##     leaves worth / 5 platinum and worth % 5 gold (gems and jewellery untouched).

const COIN_VALUE := [1, 10, 100, 200, 1000]


## Whether `m`'s coins go on the pile at POOL and he counts at SHARE.
static func pools(m: PartyMember) -> bool:
	return m.npc == 0 or m.npc == 0xB3


static func has_money(pile: PackedInt32Array) -> bool:
	for c in pile:
		if c > 0:
			return true
	return false


## POOL: returns the new pile.
static func pool(party: Array[PartyMember], pile: PackedInt32Array) -> PackedInt32Array:
	var out := pile.duplicate()
	for m in party:
		if not pools(m):
			continue
		for c in 7:
			out[c] += m.money[c]
			m.money[c] = 0
	return out


## SHARE: returns what stays on the pile. As GAME.OVR 0x252C3 does it, word for word (Combat Chat 16,
## Player 11's p11t1: the original's save after the fight has LIRA's jewellery at 63644, ARN's at 1290,
## BRAM's at 602, and ARN's load at its ceiling, 4500):
##   each player character in party order (an NPC, control 0x80 and over, skipped) takes his part of each
##   kind, jewellery down to copper. One whose load (a word: items + all seven coin kinds) would pass his
##   ceiling (0x24CDD) takes the ceiling less his load instead, as a word: nothing at the ceiling, and from
##   an overloaded one the excess is taken away (his count wraps below 0); what he didn't take goes to the
##   remainder. One whose part fit takes one more coin of the remainder if the whole remainder would fit.
##   Then (0x25517) each kind's remainder goes, in party order and to anyone (NPCs too), as far as each
##   one's room (the ceiling less his load, a word: an overloaded one's room is huge) holds it; what is
##   left after everyone stays on the pile.
static func share(party: Array[PartyMember], pile: PackedInt32Array) -> PackedInt32Array:
	var n := 0
	for m in party:
		if pools(m):
			n += 1
	if n == 0:
		return pile.duplicate()
	var each := []
	var rest := []
	for c in 7:
		each.append((pile[c] / n) & 0xFFFF)
		rest.append((pile[c] % n) & 0xFFFF)
	for m in party:
		if m.npc >= 0x80:
			continue
		for c in range(6, -1, -1):
			var top := m.max_load() & 0xFFFF
			if ((m.encumbrance() + int(each[c])) & 0xFFFF) > top:
				var fit := (top - m.encumbrance()) & 0xFFFF
				m.money[c] = (m.money[c] + fit) & 0xFFFF
				rest[c] = (int(rest[c]) + int(each[c]) - fit) & 0xFFFF
			else:
				m.money[c] = (m.money[c] + int(each[c])) & 0xFFFF
				if rest[c] > 0 and ((m.encumbrance() + int(rest[c])) & 0xFFFF) <= top:
					m.money[c] = (m.money[c] + 1) & 0xFFFF
					rest[c] -= 1
	for c in range(6, -1, -1):
		if rest[c] == 0:
			continue
		for m in party:
			var room := ((m.max_load() & 0xFFFF) - m.encumbrance()) & 0xFFFF
			if room == 0:
				continue
			var give := mini(int(rest[c]), room)
			m.money[c] = (m.money[c] + give) & 0xFFFF
			rest[c] -= give
	var out := PackedInt32Array()
	for c in 7:
		out.append(rest[c])
	return out


## The worth in gold of seven counts (a purse or the pile), as the original rounds it.
static func gold_of(money: PackedInt32Array) -> int:
	var copper := 0
	for c in 5:
		copper += money[c] * COIN_VALUE[c]
	return ((copper + 100) / 200) & 0xFFFF


## Sets seven counts to a worth in gold: platinum and gold, the other coins gone.
static func set_gold(money: PackedInt32Array, gold: int) -> PackedInt32Array:
	var out := money.duplicate()
	gold &= 0xFFFF
	for c in 5:
		out[c] = 0
	out[4] = gold / 5
	out[3] = gold % 5
	return out

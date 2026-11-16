class_name CoinPile
## The money pile the treasure screen and the shops share with the party, as the original keeps it
## (Combat Chat 13, from GAME.OVR; Player 12's shop POOL request). One pile, seven counts (copper,
## silver, electrum, gold, platinum, gems, jewellery: DS:0x67F4, 7 dwords), emptied as a shop opens
## (0x7230).
##   POOL (0x25191): every player character's coins, all seven kinds, go on the pile; an NPC
##     (control byte 128 and over) keeps his, unless his control is 0xB3.
##   SHARE (0x252C3): each kind is split by the number of player characters (control 0 or 0xB3);
##     each player character in party order (an NPC, 0x80 and over, gets nothing) takes his part
##     from jewellery down to copper, then one more coin of the remainder while any is left; a
##     part that doesn't fit under his load (0x24CDD) is partly taken and the rest stays on the pile.
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


## SHARE: returns what stays on the pile.
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
		each.append(pile[c] / n)
		rest.append(pile[c] % n)
	for m in party:
		if m.npc >= 0x80:
			continue
		for c in range(6, -1, -1):
			var fit := mini(int(each[c]), m.coins_room())
			m.money[c] += fit
			if fit == each[c]:
				if rest[c] > 0 and m.coins_room() >= 1:
					m.money[c] += 1
					rest[c] -= 1
			else:
				rest[c] += each[c] - fit
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

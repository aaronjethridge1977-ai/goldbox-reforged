class_name Spoils
extends RefCounted
## What a won fight (or a treasure find) leaves: experience for the party and the treasure
## on the ground: coins, gems and jewellery (7 counts, as a character's money) and items.
##
## As the original does it (rules as documented by Pilgrim's reconstruction; checked in
## the lab on the Slums orcs, 3 orcs and their leader with 24 silver each and a +1 scroll):
## - The pile is the event's TREASURE (coins, gems, jewellery, an item list) plus every
##   defeated monster's money and items (unreadied). A monster's item worth nothing (price
##   0) makes the pile only on a d10 of 1-3, and only while fewer than 8 of the monsters'
##   items have made it; priced items always do; with ECL 0x6DE3 = 1 no monster's item does
##   (GAME.OVR 0x5600-0x579B; found roll for roll in the lab, the Slums goblin patrol).
## - Experience: each defeated monster's worth (per hit point x hit points rolled + value),
##   plus the pile's money in gold (coins at their copper value / 200, a gem 250, a piece of
##   jewellery 2200), plus 400 for each plus of every magic item. The total is split evenly
##   among the party members still standing (rounded down): 60 + 4 + 400 = 464, so 77 each
##   with six standing and 116 each with four, as the original showed.
## - Each standing member adds the share with their class's bonus or split
##   (PartyMember.gain_experience); a fighter with STR 17 got 84 of the 77.

const GEM_GOLD := 250
const JEWELRY_GOLD := 2200
const ITEM_PLUS_XP := 400

var money := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var items: Array[GameItem] = []
var experience := 0          # the whole fight's experience
var share := 0               # each standing member's share, before class adjustments
var fought := false          # monsters were defeated (otherwise a treasure find)


## `script_money`: the event's TREASURE coins (copper..platinum, gems, jewellery).
static func gather(defeated: Array, script_money: Array, script_items: Array[GameItem],
		monster_items := true) -> Spoils:
	var s := Spoils.new()
	for i in mini(script_money.size(), 7):
		s.money[i] += int(script_money[i])
	for it in script_items:
		var c := it.copy()
		c.name = it.name
		s.items.append(c)
	var worth := 0
	var kept := 0
	# GAME.OVR 0x571E: the fight's end puts each defeated figure's items on the pile (DS:0x6810) at its
	# head, one by one, so they come first and in reverse order, the last figure's last item at the top
	# (Combat Chat 16; DOSBox, the Player's p11t1: DIRTEN's items listed last to first after the fight).
	var theirs: Array[GameItem] = []
	for m in defeated:
		var pm: PartyMember = m
		s.fought = true
		worth += pm.experience_worth()
		for i in 7:
			s.money[i] += pm.money[i]
		if not monster_items:
			continue
		if OS.has_environment("APDBG"):
			print("   spoils: %s status %d hp %d items %s" % [pm.name, pm.status, pm.hp, ", ".join(pm.items.map(func(x): return "%s/%d/n%d/r%d" % [x.name, x.price, x.count, 1 if x.readied else 0]))])
		for it in pm.items:
			if it.price == 0 and (kept >= 8 or _d10() > 3):
				continue
			kept += 1
			var c := it.copy()
			c.name = it.name
			theirs.push_front(c)
	theirs.append_array(s.items)
	s.items = theirs
	worth += s.money_worth()
	for it in s.items:
		if it.plus > 0:
			worth += it.plus * ITEM_PLUS_XP
	s.experience = worth
	return s


static func _d10() -> int:
	return TpDice.random(10, "a monster's item in the pile?") + 1 if TpDice.on else randi_range(1, 10)


## The pile's money in gold, as the original counts it for experience.
func money_worth() -> int:
	var copper := 0
	for i in 5:
		copper += money[i] * PartyMember.COIN_VALUE[i]
	return copper / PartyMember.COIN_VALUE[3] + money[5] * GEM_GOLD + money[6] * JEWELRY_GOLD


func has_treasure() -> bool:
	return has_money() or not items.is_empty()


func has_money() -> bool:
	for c in money:
		if c > 0:
			return true
	return false


## Gives each standing member their share. Returns the share (before class adjustments).
## `only`: a duel's fighter (CALL 0x8000 / 0x8001): the share is still the whole party's (the experience
## over every standing member), but only he gets it. GAME.OVR 0x58A0 divides by the party's count less
## the downed, 0x58D3 adds the share to each record that was in the fight (+0x10D); a duel's onlookers
## weren't (Player 18, p18a3, Podol's buccaneer: 981 over six, ARN +179 with his bonus, ours gave him 1079).
func award(standing: Array, only: PartyMember = null) -> int:
	if standing.is_empty():
		share = 0
		return 0
	share = experience / standing.size()
	for m in standing:
		if only == null or m == only:
			(m as PartyMember).gain_experience(share)
	return share

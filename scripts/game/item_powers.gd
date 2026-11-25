class_name ItemPowers
extends RefCounted
## What a magic item does while it is readied, as the original does it. An item record's
## byte 62 with bit 7 set names a handler in the effect table (GAME.OVR DS:0x682C), which
## readying and unreadying call (0x22511: flag 0 ready, 1 unready); byte 61 is its
## parameter:
##   0x81, 0x85, 0x88, 0x8A  the bearer has effect <byte 61> while it is readied (0x11B35):
##                 Ring of Fire Resistance 0x3D, Cloak of Displacement 0x59, Two-Handed
##                 Sword +1 +3 vs Undead 0x03. Built here as an effect the item lends
##                 (PartyMember.has_affect looks at readied items).
##   0x83          Gauntlets of Ogre Power: STR 18/00 while readied (0x11BB2; Strength).
##   0x84          a sword for one alignment (byte 61: alignment in the low 4 bits, damage
##                 in the high 4): anyone else who readies it takes that much magic damage
##                 and it won't stay readied (0x11D00); its plus doesn't count for them
##                 (0xBF41). Long Sword +3 (0x52: alignment 2, 5 damage), Long Sword +2
##                 (0xF0: alignment 0, 15).
##   0x87          a Boulder: only STR 19 or more can ready it, "MUST HAVE GIANT STRENGTH"
##                 (0x11D8F).
##   0x89          Spiritual Hammer's hammer: unreadying it ends the spell (0x11DD5).

const LENDS := [0x81, 0x85, 0x88, 0x8A]
const GAUNTLETS := 0x83
const ALIGNED := 0x84
const BOULDER := 0x87
const HAMMER := 0x89


static func power(it: GameItem) -> int:
	return it.raw[62] if it.raw.size() > 62 and it.raw[62] >= 0x80 else 0


## The effect types lent by `m`'s readied items.
static func lent(m: PartyMember) -> Array:
	var out: Array = []
	for it in m.items:
		if it.readied and power(it) in LENDS:
			out.append(it.raw[61])
	return out


## Before readying: a reason to refuse ("" if none).
static func refuse(m: PartyMember, it: GameItem) -> String:
	if power(it) == BOULDER and m.stats[0] < 19:
		return "MUST HAVE GIANT STRENGTH"
	return ""


## After `it` was readied (`readying`) or unreadied. Returns the lines to show; may
## unready the item again (an aligned sword in the wrong hands).
static func changed(m: PartyMember, it: GameItem, readying: bool) -> PackedStringArray:
	var out := PackedStringArray()
	match power(it):
		0x81, 0x85, 0x88, 0x8A:
			# 0x11B35: readying appends a record of the effect (0 minutes, power 12; 0x2BD3C), unreadying removes
			# the bearer's first record of that type (0x2AF10). So the .SPC carries it, and a computer-run member
			# who puts the item away in a fight loses it (Combat Chat 40, DOSBox: Player 37's p37i1, BRAM on QUICK
			# put his Two-Handed Sword +1 +3 vs Undead away and his effect 3 went).
			var t: int = it.raw[61]
			if readying:
				m.affects.append({"effect": t, "spell": 0, "minutes": 0, "value": 12})
			else:
				for a in m.affects:
					if int(a.effect) == t:
						m.affects.erase(a)
						break
		GAUNTLETS:
			if readying:
				if Strength.add(m, Strength.STRENGTH, 0, 18, 100, 0):
					out.append("%s IS STRONGER" % m.name)
			else:
				_drop_gauntlets(m)
		ALIGNED:
			if readying and not aligned(m, it):
				it.readied = false
				var dmg: int = it.raw[61] >> 4
				out.append(SpecialAffects.damage_words(m.name, dmg, SpecialAffects.MAGIC))
				# The damage goes through the general damage call (0x11D66 -> 0xB0:0x7F -> START.EXE 0xBA:0x2228):
				# short of the HP the excess decides (more than 9 dead, else dying), an ANIMATED member at 0 dies,
				# and one left in any status but OKAY or ANIMATED gets record +0x10D 0 (main chat 136, checks
				# 523, 524: ELWEN at 9 HP DYING, at 4 HP DEAD in the original's camp; ours had UNCONSCIOUS).
				var past := dmg - m.hp if dmg > m.hp else 0
				m.hp = maxi(m.hp - dmg, 0)
				if past > 9 or (m.hp == 0 and m.status == PartyMember.STATUS_ANIMATED):
					m.status = PartyMember.STATUS_DEAD
				elif past > 0:
					m.status = PartyMember.STATUS_DYING
				elif m.hp == 0:
					m.status = PartyMember.STATUS_UNCONSCIOUS
				if m.status not in [PartyMember.STATUS_OKAY, PartyMember.STATUS_ANIMATED] and m.raw.size() > 0x10D:
					m.raw[0x10D] = 0
		HAMMER:
			if not readying:
				for a in m.affects.duplicate():
					if int(a.effect) == 0x17:
						m.affects.erase(a)
	return out


## Does an aligned sword (0x84) answer to `m`?
static func aligned(m: PartyMember, it: GameItem) -> bool:
	if power(it) != ALIGNED:
		return true
	var al: int = m.raw[0xA0] if m.raw.size() > 0xA0 else -1
	return (it.raw[61] & 0x0F) == al


## Unreadying the gauntlets: a strength effect goes (the first one if the bearer is at
## 18/00, otherwise the one that holds 18/00), and its end is run.
static func _drop_gauntlets(m: PartyMember) -> void:
	var at_max := Strength.current(m) == Vector2i(18, 100)
	for a in m.affects:
		if int(a.effect) != Strength.STRENGTH:
			continue
		var v := Strength.unpack(int(a.value))
		if at_max or v == Vector2i(18, 100):
			m.affects.erase(a)
			Strength.ended(m, a)
			return

class_name Strength
extends RefCounted
## Spells and items that raise strength, as the original does it (GAME.OVR 0x2C046 raise,
## 0xF115 the effect's end, 0x2BFCE / 0x2BFF7 the packing):
## - The record's STR (0x10) and exceptional STR (0x16) are changed directly. The effect
##   (0x0C Enlarge, 0x26 Strength, Giant Strength, Gauntlets of Ogre Power) keeps a packed
##   strength in its power byte: 18/xx as xx + 1, anything else as STR + 100. Bit 7 clear:
##   the effect is the one in force and holds the strength to go back to. Bit 7 set: it is
##   waiting and holds its own strength.
## - Raising to less than the current strength does nothing ("waiting" effect). Otherwise
##   the effect in force (if any) gives back the strength it held and waits with its own;
##   the new one holds what was there before.
## - When the effect in force ends, the strength it held returns, and the strongest waiting
##   one takes over.
## Enlarge: 18 and 0, 1, 51, 76, 91, 100 for caster levels 1-6 (0x282BD). Strength: + 1d4
## magic-user, 1d6 cleric or thief, 1d8 fighter (the last that applies); over 18, a fighter
## gets 18/(10 per point over, plus what he had), others 18 (0x28F59). Giant Strength 21.
## Gauntlets of Ogre Power 18/00 while readied (0x11BB2).

const ENLARGE := 0x0C
const STRENGTH := 0x26
const TYPES := [ENLARGE, STRENGTH]
const ENLARGE_PCT := [0, 0, 1, 51, 76, 91, 100]


static func pack(s: int, pct: int) -> int:
	return pct + 1 if s == 18 else s + 100


static func unpack(v: int) -> Vector2i:
	v &= 0x7F
	return Vector2i(18, v - 1) if v <= 101 else Vector2i(v - 100, 0)


static func current(m: PartyMember) -> Vector2i:
	return Vector2i(m.stats[0], m.strength_exceptional if m.stats[0] == 18 else 0)


static func set_to(m: PartyMember, v: Vector2i) -> void:
	m.stats[0] = v.x
	m.strength_exceptional = v.y if v.x == 18 else 0
	if m.raw.size() > 0x16:
		m.raw[0x10] = v.x
		m.raw[0x16] = m.strength_exceptional


static func _better(a: Vector2i, b: Vector2i) -> bool:
	return a.x > b.x or (a.x == 18 and b.x == 18 and a.y > b.y)


## Raises `m` to `s`/`pct`; returns [raised, power byte for the new effect].
static func raise(m: PartyMember, s: int, pct: int) -> Array:
	var cur := current(m)
	if s < cur.x or (s == 18 and pct < cur.y):
		return [false, pack(s, pct) + 0x80]
	for a in m.affects:
		if int(a.effect) in TYPES and int(a.value) < 0x80:
			var held := unpack(int(a.value))
			a.value = pack(cur.x, cur.y) + 0x80
			cur = held
			break
	set_to(m, Vector2i(s, pct))
	return [true, pack(cur.x, cur.y)]


## Adds a strength effect that raises `m` to `s`/`pct` for `minutes` (0 = for good).
## Returns true if the strength went up ("IS STRONGER").
static func add(m: PartyMember, type: int, spell: int, s: int, pct: int, minutes: int) -> bool:
	var r := raise(m, s, pct)
	m.affects.append({"effect": type, "spell": spell, "minutes": minutes, "value": r[1]})
	return r[0]


## The effect `a` ends (it must already be out of m.affects).
static func ended(m: PartyMember, a: Dictionary) -> void:
	if int(a.value) > 0x7F:
		return
	set_to(m, unpack(int(a.value)))
	var best: Dictionary = {}
	var best_v := Vector2i.ZERO
	for o in m.affects:
		if int(o.effect) in TYPES:
			var v := unpack(int(o.value))
			if best.is_empty() or _better(v, best_v):
				best = o
				best_v = v
	if not best.is_empty():
		var cur := current(m)
		best.value = pack(cur.x, cur.y)
		set_to(m, best_v)


## The Strength spell's new strength for `m` (`roll(count, size)`).
static func spell_target(m: PartyMember, roll: Callable) -> Vector2i:
	var d := 0
	if m.level_in(5) > 0:
		d = int(roll.call(1, 4))
	if m.level_in(0) > 0 or m.level_in(6) > 0:
		d = int(roll.call(1, 6))
	var fighter := m.level_in(2) > 0
	if fighter:
		d = int(roll.call(1, 8))
	var s := m.stats[0] + d
	if s <= 18:
		return Vector2i(s, 0)
	if fighter:
		return Vector2i(18, mini((s - 18) * 10 + m.strength_exceptional, 100))
	return Vector2i(18, 0)


static func enlarge_target(caster_level: int) -> Vector2i:
	return Vector2i(18, ENLARGE_PCT[clampi(caster_level, 1, 6)])

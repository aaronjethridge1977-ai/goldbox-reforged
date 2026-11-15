class_name TreasureMaker
extends RefCounted
## Random treasure, as Pool of Radiance makes it (chat 28, from GAME.OVR; combat's request).
##
## An event's TREASURE with an item list of 128 or more (the eighth operand) doesn't name an
## ITEM*.DAX block: the original's TREASURE handler (GAME.OVR 0x26F5) makes (list - 128) items
## at once, from the dice, before the fight that follows (128 makes none, 255 is "no items").
## Each item: a d100 picks the kind (0x28B4), then the item is built from its type (0x25C99).
## The items go to the front of the treasure list one by one (the last made comes first).
##
## The kind (d100):
##   1-60   a weapon or armour: a second d100 (0x28D3): 1-47 and 50-59 that type (45 is 59),
##          60-90 a d10 (0x2910): 1-4 type 36, 5-7 35, 8 34, 9 37, 10 38; 91-94 type 73,
##          95-97 93, 98-100 77; 48 and 49 set no type (the original keeps the last one: its
##          variable isn't set; for the first item of a TREASURE nobody can say what the
##          stack held, ours takes 0, an item of nothing)
##   61-85  type 61 (a magic-user's scroll), 86-92 type 62 (a cleric's scroll)
##   93-98  a d16: 1-7 type 71, 8-9 70, 10 84, 11-12 78, 13-14 79, 15 92, 16 67
##   99-100 type 69
## Built (0x25C99): the record cleared, byte 53 (hidden name words) 6.
##   Types 1-59, 73, 77, 93: a plus from a d20 (0x25C5B: 1-14 +1, 15-19 +2, 20 +3), name words
##   by type (below), weight and price by type; type 21 also rolls a d5 and on 5 becomes
##   the special item 0x90 (the table read one word off, as the original).
##   Types 61, 62 (scrolls): d3 spells, each a d3 for its level, then the spell from the
##   level's die (magic-user 1: d13+8, 2: d7+28, 3: d11+44; cleric 1: d8, 2: d7+21, 3: d9+35),
##   in bytes 60.., price 300 a spell level, weight 25, plus 1.
##   Other types: a special item from START.EXE's table (DS:0x970, eight words an entry: the
##   three name words, weight, price, three special bytes), some by a die (69: d10,
##   78: d3 + 1, 71: d11, 70: d10); plus 1 and save plus 1 (entry 0x61: 2 and 2).

const DS_SPECIALS := 0x0970

var ok := false
var _rules: CreationRules

static var _shared: TreasureMaker = null
static var _shared_path := ""


static func shared(game_path: String) -> TreasureMaker:
	if _shared == null or _shared_path != game_path:
		_shared = TreasureMaker.new()
		_shared._rules = CreationRules.shared(game_path)
		_shared.ok = _shared._rules.ok
		_shared_path = game_path
	return _shared


## Makes `count` items with `die` (a Callable(lo, hi) -> int, the game's dice), in the order
## the treasure list shows them (the last made first).
func make(count: int, die: Callable) -> Array[GameItem]:
	var out: Array[GameItem] = []
	var kind := 0
	for n in count:
		kind = _pick_kind(die, kind)
		out.push_front(GameItem.from_record(build(kind, die)))
	return out


## GAME.OVR 0x28A9..0x2A13: the item's type.
static func _pick_kind(die: Callable, last: int) -> int:
	var r: int = die.call(1, 100)
	if r <= 60:
		var r2: int = die.call(1, 100)
		if r2 <= 47 or (r2 >= 50 and r2 <= 59):
			return 59 if r2 == 45 else r2
		if r2 >= 60 and r2 <= 90:
			var d: int = die.call(1, 10)
			if d <= 4:
				return 0x24
			if d <= 7:
				return 0x23
			return [0x22, 0x25, 0x26][d - 8]
		if r2 >= 91 and r2 <= 94:
			return 0x49
		if r2 >= 95 and r2 <= 97:
			return 0x5D
		if r2 >= 98:
			return 0x4D
		return last      # 48, 49: the original sets nothing
	if r <= 85:
		return 0x3D
	if r <= 92:
		return 0x3E
	if r <= 98:
		var d16: int = die.call(1, 16)
		if d16 <= 7:
			return 0x47
		if d16 <= 9:
			return 0x46
		if d16 == 10:
			return 0x54
		if d16 <= 12:
			return 0x4E
		if d16 <= 14:
			return 0x4F
		return 0x5C if d16 == 15 else 0x43
	return 0x45


## GAME.OVR 0x25C99: a 63-byte item record of `type`.
func build(type: int, die: Callable) -> PackedByteArray:
	var rec := PackedByteArray()
	rec.resize(GameItem.SIZE)
	rec[0x35] = 6
	rec[0x2E] = type
	var special := 0
	if (type >= 1 and type <= 0x3B) or type in [0x49, 0x4D, 0x5D]:
		var plus := _plus(die)
		rec[0x32] = plus
		match type:
			0x15:
				if die.call(1, 5) == 5:
					special = 0x90
				rec[0x31] = 0x15
				rec[0x30] = plus + 0xA1
			0x1C:
				rec[0x31] = 0x1C
				rec[0x30] = plus + 0xA1
			0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A:
				rec[0x31] = type
				rec[0x30] = 0x31 if type <= 0x33 else (0x32 if type == 0x34 else 0x30)
				rec[0x2F] = plus + 0xA1
				rec[0x35] = 4
			0x49:
				rec[0x31] = 0x3D
				rec[0x30] = plus + 0xA1
			0x4D:
				rec[0x31] = 0x4F
				rec[0x30] = 0xA7
				plus = plus * 2 + 2
				rec[0x32] = plus
				if plus == 4:
					rec[0x2F] = 0xDD
				elif plus == 6:
					rec[0x2F] = 0xDE
				elif plus == 8:
					rec[0x2F] = 0xDC
			0x5D:
				rec[0x31] = 0x42
				rec[0x30] = 0xE0
				rec[0x2F] = plus + 0xA1
			_:
				rec[0x31] = type
				rec[0x30] = plus + 0xA1
		var w := _weight(type)
		rec.encode_u16(0x37, w[0])
		rec[0x39] = w[1]
		rec.encode_u16(0x3A, (plus * _price_each(type)) & 0xFFFF)
	elif type == 0x3D or type == 0x3E:
		var spells: int = die.call(1, 3)
		rec[0x31] = 0xD1 if type == 0x3D else 0xD0
		rec[0x30] = spells + 0xD1
		rec[0x32] = 1
		rec.encode_u16(0x37, 25)
		var price := 0
		for k in range(1, spells + 1):
			var level: int = die.call(1, 3)
			rec[0x3B + k] = _mu_spell(level, die) if type == 0x3D else _cleric_spell(level, die)
			price += level * 300
		rec.encode_u16(0x3A, price & 0xFFFF)
	else:
		special = _special_of(type, die)
	if special != 0:
		_apply_special(rec, special)
	return rec


static func _mu_spell(level: int, die: Callable) -> int:
	match level:
		1:
			return die.call(1, 13) + 8
		2:
			return die.call(1, 7) + 0x1C
		3:
			return die.call(1, 11) + 0x2C
	return 0


static func _cleric_spell(level: int, die: Callable) -> int:
	match level:
		1:
			return die.call(1, 8)
		2:
			return die.call(1, 7) + 0x15
		3:
			return die.call(1, 9) + 0x23
	return 0


## 0x25C5B: d20, 1-14 +1, 15-19 +2, 20 +3.
static func _plus(die: Callable) -> int:
	var d: int = die.call(1, 20)
	if d <= 14:
		return 1
	return 2 if d <= 19 else 3


## 0x25F0E: [weight, count] by type.
static func _weight(type: int) -> Array:
	match type:
		1, 0xD, 0xE, 0x23:
			return [75, 0]
		2, 0x14, 0x1D, 0x1F, 0x20, 0x21, 0x27, 0x2A, 0x2C, 0x2E, 0x3B:
			return [50, 0]
		3, 0x18, 0x28:
			return [125, 0]
		4, 0xF, 0x17, 0x22, 0x2B, 0x2D, 0x33:
			return [100, 0]
		5, 0xC, 0x11, 0x13, 0x32:
			return [150, 0]
		6:
			return [15, 0]
		7:
			return [30, 0]
		8, 0x4D:
			return [10, 0]
		9:
			return [25, 5]
		0xA, 0x1A, 0x24:
			return [60, 0]
		0xB, 0x10, 0x19, 0x1B, 0x29, 0x2F:
			return [80, 0]
		0x12:
			return [175, 0]
		0x15:
			return [20, 0]
		0x16, 0x1E:
			return [40, 0]
		0x25:
			return [35, 0]
		0x26, 0x35:
			return [250, 0]
		0x34:
			return [200, 0]
		0x36, 0x38:
			return [400, 0]
		0x37:
			return [300, 0]
		0x39:
			return [350, 0]
		0x3A:
			return [450, 0]
		0x5D:
			return [1, 0]
	return [40, 10]


## 0x2612B: the price is the plus times this.
static func _price_each(type: int) -> int:
	match type:
		0x3B:
			return 2500
		0x49, 0x1C:
			return 150
		0x35, 0x36, 0x4D:
			return 3000
		0x37, 0x38:
			return 3500
		0x39:
			return 4000
		0x3A:
			return 5000
	return 2000


## 0x26378: the special table's entry for the other types (0: none).
static func _special_of(type: int, die: Callable) -> int:
	match type:
		0x3F:
			return 0x49
		0x43:
			return 0x91
		0x45:
			var d: int = die.call(1, 10)
			return 0x29 if d == 1 else (0x79 if d <= 6 else 0x81)
		0x4E:
			var d: int = die.call(1, 3) + 1
			return {1: 0x31, 2: 0x41, 3: 0x71}.get(d, 0)
		0x4F:
			return 0x39
		0x54:
			return 0x09
		0x5C:
			return 0x61
		0x47:
			var d: int = die.call(1, 11)
			if d <= 5:
				return 0x11
			if d <= 8:
				return 0x01
			return {9: 0x19, 10: 0x51}.get(d, 0)
		0x46:
			var d: int = die.call(1, 10)
			return 0x59 if d <= 7 else 0x89
	return 0


## 0x26494: name words, weight, price and special bytes from START.EXE's table DS:0x970
## (words; entry e is words e..e+7); plus and save plus 1 (2 for entry 0x61).
func _apply_special(rec: PackedByteArray, e: int) -> void:
	if not ok:
		return
	var w := func(i: int) -> int: return _rules.ds_word(DS_SPECIALS + i * 2)
	for k in 3:
		rec[0x2F + k] = w.call(e + k) & 0xFF
	var p := 2 if e == 0x61 else 1
	rec[0x32] = p
	rec[0x33] = p
	rec.encode_u16(0x37, w.call(e + 3))
	rec[0x39] = 0
	rec.encode_u16(0x3A, w.call(e + 4))
	for k in range(1, 4):
		rec[0x3B + k] = w.call(e + 4 + k) & 0xFF

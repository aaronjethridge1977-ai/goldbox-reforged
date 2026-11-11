class_name CreationRules
extends RefCounted
## Pool of Radiance's character creation, as GAME.OVR does it (the function at file 0x19EEB),
## with its tables read from START.EXE's data segment (DS offsets below; the segment is
## found by the race names at DS:0x0F03, "Monster", "Dwarf"...). Checked against the original in the lab.
##
## The order: race (no half-orc offered), sex, class (the race's list), alignment (the
## class's list), then the roll: age once, then abilities, spells, gold and hit points,
## rolled again each time the player turns the character down.
##
## Abilities, each STR..CHA: the best of six 3d6 rolls, each roll adjusted for race (dwarf
## CON+1 CHA-1, elf DEX+1 CON-1, halfling STR-1 DEX+1, half-orc STR+1 CON+1 CHA-2); then age
## (older than each of the race's four age marks: STR +1 -1 -2 -1, INT . +1 . +1,
## WIS -1 +1 +1 +1, DEX . . -2 -1, CON . -1 -1 -1); then the race's limits (STR by sex),
## the class's minimum, and WIS at least 13 for the cleric multi-classes. STR 18 with a
## fighter level rolls d100 exceptional strength, capped by race and sex.
## Hit points: each class's level-1 die (at least two thirds of its size), plus the CON
## bonus, divided among the classes. Gold: each class's dice x 10, divided likewise.
## Clerics know every 1st-level cleric spell; magic-users know spells 11, 18, 19 and 21.

const DS_RACE_NAMES := 0x0F03   # 10-byte Pascal strings by race
const DS_CLASS_NAMES := 0x0D38  # 27-byte Pascal strings by class
const DS_ICON_COLOURS := 0x3CF5 # 1..6
const DS_CLASS_LISTS := 0x3E17  # race * 12: count, classes
const DS_AGE := 0x3E5B          # race * 28 + class * 4: base (u16), dice count, dice size
const DS_LIMITS := 0x3DA3       # race * 16: STR min, max, 18/xx max (by sex), INT..CHA min, max
const DS_AGE_MARKS := 0x3F31    # race * 10: u16 x 5
const DS_CLASS_MIN := 0x3F81    # class * 6
const DS_ALIGNMENTS := 0x3FE7   # class * 10: count, alignments
const DS_GOLD := 0x4263         # class * 2: dice count, size
const DS_CLASS_FLAGS := 0x05D6  # class: bit summed into record 0xB0
const DS_HP_MASK := 0x05DE
const DS_HP_COUNT := 0x08B6
const DS_HP_SIZE := 0x08BE
const DS_HEADS := 0x2870        # 14 head pictures, then 12 bodies
const HEADS := 14
const BODIES := 12

const RACE_CHOICES := [1, 2, 3, 4, 5, 7]
const MAGE_START_SPELLS := [11, 18, 19, 21]
## A multi-class's age comes from one of its classes, the most it could roll.
const MULTI_AGE_CLASS := {8: 0, 9: 0, 10: 0, 11: 0, 12: 0, 13: 5, 14: 2, 15: 5, 16: 5}
## Age adjustments by ability, for ages past the race's marks 0..3.
const AGE_ADJUST := [[1, -1, -2, -1], [0, 1, 0, 1], [-1, 1, 1, 1], [0, 0, -2, -1], [0, -1, -1, -1], [0, 0, 0, 0]]
const RACE_ADJUST := {1: [0, 0, 0, 0, 1, -1], 2: [0, 0, 0, 1, -1, 0], 5: [-1, 0, 0, 1, 0, 0], 6: [1, 0, 0, 0, 1, -2]}

var ok := false
var _ds := PackedByteArray()
var _base := 0

static var _shared: CreationRules = null
static var _shared_path := ""


static func shared(game_path: String) -> CreationRules:
	if _shared == null or _shared_path != game_path:
		_shared = CreationRules.new()
		_shared._load(game_path)
		_shared_path = game_path
	return _shared


func _load(game_path: String) -> void:
	var image := Exepack.unpack(FileAccess.get_file_as_bytes(game_path.path_join("START.EXE")))
	if image.is_empty():
		return
	var at := ItemNames._find(image, PackedByteArray([7]) + "Monster".to_ascii_buffer() + PackedByteArray([0, 0, 5]) + "Dwarf".to_ascii_buffer())
	if at < 0:
		return
	_ds = image
	_base = at - DS_RACE_NAMES
	ok = _byte(DS_CLASS_LISTS + 12) == 3   # dwarves: three classes


func _byte(off: int) -> int:
	return _ds[_base + off]


func _word(off: int) -> int:
	return _ds.decode_u16(_base + off)


func _pstring(off: int) -> String:
	var n := _byte(off)
	return _ds.slice(_base + off + 1, _base + off + 1 + n).get_string_from_ascii().to_upper()


func race_name(race: int) -> String:
	return _pstring(DS_RACE_NAMES + race * 10)


func class_name_of(c: int) -> String:
	return _pstring(DS_CLASS_NAMES + c * 27)


func classes_for(race: int) -> Array[int]:
	var out: Array[int] = []
	for i in _byte(DS_CLASS_LISTS + race * 12):
		out.append(_byte(DS_CLASS_LISTS + race * 12 + 1 + i))
	return out


func alignments_for(c: int) -> Array[int]:
	var out: Array[int] = []
	for i in _byte(DS_ALIGNMENTS + c * 10):
		out.append(_byte(DS_ALIGNMENTS + c * 10 + 1 + i))
	return out


func head_id(index: int) -> int:
	return _byte(DS_HEADS + posmod(index, HEADS))


func body_id(index: int) -> int:
	return _byte(DS_HEADS + HEADS + posmod(index, BODIES))


## The classes (0..7) a class id is made of.
static func parts(c: int) -> Array[int]:
	var table := {8: [0, 2], 9: [0, 2, 5], 10: [0, 4], 11: [0, 5], 12: [0, 6], 13: [2, 5],
		14: [2, 6], 15: [2, 5, 6], 16: [5, 6]}
	var out: Array[int] = []
	out.assign(table.get(c, [c]))
	return out


static func dice(rng: RandomNumberGenerator, count: int, size: int) -> int:
	var t := 0
	for i in count:
		t += rng.randi_range(1, maxi(size, 1))
	return t


## A new record (285 bytes) with everything set before the roll.
func start_record(race: int, sex: int, c: int, alignment: int, rng: RandomNumberGenerator) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(285)
	for i in range(1, 7):
		var k := _byte(DS_ICON_COLOURS + i)
		d[0xC0 + i] = ((k + 8) << 4) + k
	d[0xA9] = 50
	d[0x2D] = 40
	d[0x10D] = 1
	d[0xBB] = 1
	d[0xBC] = 1
	d[0x6C] = 1
	d[0xAB] = rng.randi_range(0, 255)
	d[0x2E] = race
	d[0xC0] = 1 if race in [1, 3, 5] else 2   # icon size: the small folk 1
	d[0x9E] = sex
	d[0x2F] = c
	d[0x73] = 1
	d[0xB0] = 0
	for p in parts(c):
		d[0x96 + p] = 1
		d[0xB0] += _byte(DS_CLASS_FLAGS + p)
	d[0xA0] = alignment
	# Age, once.
	var ac := MULTI_AGE_CLASS.get(c, c) as int
	var e := DS_AGE + race * 28 + ac * 4
	var age := _word(e)
	if c >= 8:
		age += _byte(e + 2) * _byte(e + 3)
	else:
		age += dice(rng, _byte(e + 2), _byte(e + 3))
	d.encode_u16(0x30, age)
	return d


## Rolls abilities, spells, gold and hit points into the record (again on each reroll).
func roll(d: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var race := d[0x2E]
	var sex := d[0x9E] & 1
	var c := d[0x2F]
	var age := d.decode_u16(0x30)
	d[0x16] = 0
	for i in 6:
		var best := 0
		for k in 6:
			var r: int = dice(rng, 3, 6) + (RACE_ADJUST[race][i] if RACE_ADJUST.has(race) else 0)
			best = maxi(best, r)
		for m in 4:
			if age > _word(DS_AGE_MARKS + race * 10 + m * 2):
				best += AGE_ADJUST[i][m]
		var lo: int
		var hi: int
		if i == 0:
			lo = _byte(DS_LIMITS + race * 16 + sex)
			hi = _byte(DS_LIMITS + race * 16 + 2 + sex)
		else:
			lo = _byte(DS_LIMITS + race * 16 + 6 + (i - 1) * 2)
			hi = _byte(DS_LIMITS + race * 16 + 7 + (i - 1) * 2)
		best = clampi(best, lo, hi) if hi >= lo else maxi(best, lo)
		best = maxi(best, _byte(DS_CLASS_MIN + c * 6 + i))
		if i == 2 and best < 13 and c >= 8 and c <= 12:
			best = 13
		d[0x10 + i] = best
		if i == 0 and best == 18 and d[0x98] > 0:
			d[0x16] = mini(rng.randi_range(1, 100), _byte(DS_LIMITS + race * 16 + 4 + sex))
	# Spells, gold and hit points.
	for k in range(0x33, 0x6B):
		d[k] = 0
	var classes := 0
	var gold := 0
	for p in 8:
		if d[0x96 + p] == 0:
			continue
		classes += 1
		gold += dice(rng, _byte(DS_GOLD + p * 2), _byte(DS_GOLD + p * 2 + 1))
		if p == 5:
			for id in MAGE_START_SPELLS:
				d[0x32 + id] = 1
	d.encode_u16(0x8E, gold * 10 / maxi(classes, 1))
	var rolled := 0
	for p in 8:
		if d[0x96 + p] == 0 or (_byte(DS_HP_MASK + p) & 0xFF) == 0:
			continue
		var size := _byte(DS_HP_SIZE + p)
		var r := dice(rng, _byte(DS_HP_COUNT + p), size)
		if d[0x96 + p] == 1:
			r = maxi(r, size * 2 / 3)
		rolled += r
	var con := 0
	for p in 8:
		if d[0x96 + p] > 0:
			con += PartyMember.con_hp_bonus(d[0x14], c)
	var hp: int
	if con < 0 and rolled <= -con + classes:
		hp = 1
	else:
		hp = (rolled + con) / maxi(classes, 1)
	d[0x32] = clampi(hp, 1, 255)
	d[0x11B] = d[0x32]
	d[0xB1] = rolled / maxi(classes, 1)
	d[0xA1] = 2
	d[0xA3] = 1
	d[0xA5] = 2
	d[0xAA] = 1
	d[0x72] = 12
	d[0x6B] = 1


## The finished member from a record (class tables, cleric spells, derived values).
func member(d: PackedByteArray, tables: ClassTables, spells: SpellTable, types: ItemTypes) -> PartyMember:
	var m := PartyMember.from_bytes(d, PackedByteArray())
	if tables != null:
		m.apply_class_tables(tables, spells)
	m.recalculate(types)
	return m

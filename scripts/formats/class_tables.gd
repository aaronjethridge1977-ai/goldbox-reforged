class_name ClassTables
extends RefCounted
## Pool of Radiance's own class tables, read from START.EXE (EXEPACK-compressed). Classes
## in the record's order: 0 cleric, 1 druid, 2 fighter, 3 paladin, 4 ranger, 5 magic-user,
## 6 thief, 7 monk.
##
## - One 56-byte block per class, starting with the cleric's (found by its 1,501 and 3,001):
##   eight 32-bit experience totals needed for levels 2..9 (-1 where the class stops: the
##   level caps are cleric 6, fighter 8, magic-user 6, thief 9; druids, paladins, rangers
##   and monks can't advance), then the spells per day for levels 2..6 as five rows of
##   three (spell levels 1-3), then padding. A first-level caster has one first-level spell.
## - THAC0 (as 60 - THAC0) by class and level 0..10, found by the cleric's row.
## - Saving throws by class and level 1..9: five values each (poison, petrification,
##   rod/staff/wand, breath, spell), found by the cleric's first rows.
## - Hit dice by class (d8 d8 d10 d10 d8 d4 d6 d4) and how many are rolled at first level.
## Checked against the shipped characters: every first-level save and THAC0 matches the
## record's cached values, and Brother Sean's three first-level spells are 1 plus wisdom.

const CLASS_COUNT := 8
const CLASS_NAMES := ["CLERIC", "DRUID", "FIGHTER", "PALADIN", "RANGER", "MAGIC-USER", "THIEF", "MONK"]
## The class bits the training halls use (written to 0x6DA8 by their scripts) and items
## check: cleric 2, druid 2, fighter 8, paladin 16, ranger 32, magic-user 1, thief 4, monk 4.
const CLASS_MASKS := [2, 2, 8, 16, 32, 1, 4, 4]

var exp_needed := []     # [class][level] experience needed for that level (-1: can't); index 0, 1 = 0
var slots := []          # [class][level] -> [l1, l2, l3] spells per day (before wisdom)
var thac0_60 := []       # [class][level 0..10]
var saves := []          # [class][level 1..9] -> PackedInt32Array of 5
var hit_die := [8, 8, 10, 10, 8, 4, 6, 4]
var first_dice := [1, 1, 1, 1, 2, 1, 1, 2]
var ok := false

static var _shared: ClassTables = null
static var _shared_path := ""


static func shared(game_path: String) -> ClassTables:
	if _shared == null or _shared_path != game_path:
		_shared = ClassTables.load_from(game_path)
		_shared_path = game_path
	return _shared


static func load_from(game_path: String) -> ClassTables:
	var t := ClassTables.new()
	var image := Exepack.unpack(FileAccess.get_file_as_bytes(game_path.path_join("START.EXE")))
	if image.is_empty():
		return t
	var sig := PackedByteArray()
	sig.resize(8)
	sig.encode_s32(0, 1501)
	sig.encode_s32(4, 3001)
	var base := ItemNames._find(image, sig)
	var th := ItemNames._find(image, PackedByteArray([40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 40]))
	var sv := ItemNames._find(image, PackedByteArray([10, 13, 14, 16, 15, 10, 13, 14, 16, 15]))
	var dice := ItemNames._find(image, PackedByteArray([1, 1, 1, 1, 2, 1, 1, 2, 8, 8, 10, 10, 8, 4, 6, 4]))
	if base < 0 or th < 0 or sv < 0:
		return t
	for c in CLASS_COUNT:
		var p := base + c * 56
		var e := [0, 0]
		var s := [[0, 0, 0], [1, 0, 0]]
		for k in 8:
			e.append(image.decode_s32(p + k * 4))
		for k in 5:
			var q := p + 32 + k * 3
			s.append([image[q], image[q + 1], image[q + 2]])
		t.exp_needed.append(e)
		t.slots.append(s)
		var row := []
		for lvl in 11:
			row.append(image[th + c * 11 + lvl])
		t.thac0_60.append(row)
		var sr := [PackedInt32Array([20, 20, 20, 20, 20])]
		for lvl in 9:
			var q := sv + (c * 9 + lvl) * 5
			sr.append(PackedInt32Array([image[q], image[q + 1], image[q + 2], image[q + 3], image[q + 4]]))
		t.saves.append(sr)
	if dice >= 0:
		for c in CLASS_COUNT:
			t.first_dice[c] = image[dice + c]
			t.hit_die[c] = image[dice + 8 + c]
	t.ok = true
	return t


## Experience needed to reach `level` in class `c` (-1 if the class can't reach it).
func needed(c: int, level: int) -> int:
	if c < 0 or c >= exp_needed.size() or level < 0:
		return -1
	if level >= exp_needed[c].size():
		return -1
	return exp_needed[c][level]


## Spells per day for class `c` at `level` (cleric and magic-user rows; others none).
func slots_at(c: int, level: int) -> Array:
	if c < 0 or c >= slots.size() or level <= 0:
		return [0, 0, 0]
	if c != 0 and c != 5:
		return [0, 0, 0]
	var rows: Array = slots[c]
	return (rows[mini(level, rows.size() - 1)] as Array).duplicate()


func thac0_at(c: int, level: int) -> int:
	return thac0_60[c][clampi(level, 0, 10)]


func saves_at(c: int, level: int) -> PackedInt32Array:
	return saves[c][clampi(level, 0, 9)]

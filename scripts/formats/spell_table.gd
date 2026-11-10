class_name SpellTable
extends RefCounted
## Pool of Radiance's own spell list, read from START.EXE (EXEPACK-compressed): 56 names
## as 41-byte Pascal strings (found by the first, "Bless"), followed at once by one
## 16-byte entry per spell (id 1..63; ids over 56 are monster powers with no name here).
##
## Entry bytes (meanings as documented by Pilgrim's reconstruction of the engine, which
## uses the same layout; the values here are Pool of Radiance's own):
##   0 class (0 cleric, 1 magic-user, 2 monster)   1 spell level
##   2 range (255 = touch)   3 range per caster level
##   4 duration   5 duration per caster level (rounds; a round is a minute)
##   6 area of effect code   7 target (0 in combat, 1 self, 2 one party member,
##   4 the whole party)   8 on a save (0 no save, 1 no effect, 2 half damage, 3 special)
##   9 save against (0 poison, 1 petrification, 2 rod/staff/wand, 3 breath, 4 spell)
##   10 effect id   11 when (0 camp only, 1 combat only, 2 both)   12 casting delay
##   13 priority (the computer's choice)   14 offensive   15 area kind
## Checked: Brother Sean's and Darkstar's spell books list in the original's MEMORIZE
## screen as these names, in this order.

const NAME_SIZE := 41
const ENTRY_SIZE := 16
const NAMED := 56
const COUNT := 63

const CLERIC := 0
const MAGE := 1
const MONSTER := 2

const TARGET_COMBAT := 0
const TARGET_SELF := 1
const TARGET_MEMBER := 2
const TARGET_PARTY := 4

const WHEN_CAMP := 0
const WHEN_COMBAT := 1
const WHEN_BOTH := 2

static var _shared: SpellTable = null
static var _shared_path := ""

var names: PackedStringArray = []     # by id; index 0 unused
var entries: Array = []               # by id: PackedByteArray of 16


static func shared(game_path: String) -> SpellTable:
	if _shared == null or _shared_path != game_path:
		_shared = SpellTable.load_from(game_path)
		_shared_path = game_path
	return _shared


static func load_from(game_path: String) -> SpellTable:
	var t := SpellTable.new()
	t.names.append("")
	t.entries.append(PackedByteArray())
	var image := Exepack.unpack(FileAccess.get_file_as_bytes(game_path.path_join("START.EXE")))
	if image.is_empty():
		return t
	var at := ItemNames._find(image, "\u0005Bless".to_ascii_buffer())
	if at < 0:
		return t
	for i in NAMED:
		var p := at + i * NAME_SIZE
		t.names.append(image.slice(p + 1, p + 1 + mini(image[p], NAME_SIZE - 1)).get_string_from_ascii())
	var base := at + NAMED * NAME_SIZE
	for i in COUNT:
		t.entries.append(image.slice(base + i * ENTRY_SIZE, base + (i + 1) * ENTRY_SIZE))
	for i in range(NAMED + 1, COUNT + 1):
		t.names.append("")
	return t


func is_loaded() -> bool:
	return names.size() > 1


func valid(id: int) -> bool:
	return id > 0 and id < entries.size() and entries[id].size() == ENTRY_SIZE


func name_of(id: int) -> String:
	return names[id].to_upper() if id > 0 and id < names.size() else ""


func field(id: int, i: int) -> int:
	return entries[id][i] if valid(id) else 0


func spell_class(id: int) -> int:
	return field(id, 0)


func level(id: int) -> int:
	return field(id, 1)


func target(id: int) -> int:
	return field(id, 7)


func when(id: int) -> int:
	return field(id, 11)


func effect(id: int) -> int:
	return field(id, 10)


## Signed range in squares (-1 = touch) before the caster's level is added.
func base_range(id: int) -> int:
	var r := field(id, 2)
	return -1 if r == 255 else r


## Range in squares for a caster of `lvl` (touch counts as 1), as the original works it out.
func range_for(id: int, lvl: int) -> int:
	var r := base_range(id)
	if r == -1:
		return 1
	r += field(id, 3) * lvl
	if r == 0 and field(id, 6) != 0:
		r = 1
	return maxi(r, 1) if r != 0 else 0


## Duration in rounds (minutes) for a caster of `lvl`.
func duration_for(id: int, lvl: int) -> int:
	return field(id, 4) + field(id, 5) * lvl


## The effect's name for DISPLAY: the name of the first spell that gives it.
func effect_name(effect_id: int) -> String:
	for id in range(1, NAMED + 1):
		if effect(id) == effect_id:
			return name_of(id)
	return "EFFECT %d" % effect_id

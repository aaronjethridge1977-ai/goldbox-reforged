class_name EclVM
extends RefCounted
## Runs Gold Box ECL event scripts.
##
## Memory is a flat 64 KB byte array, as in the original: the script is loaded at 0x9900,
## game state lives at fixed addresses (see the constants below). Operands that name a
## memory address read and write a byte (types 0x01, 0x05) or a 16-bit word (0x03).
##
## The VM runs until the script exits, or pauses for a menu choice. Output (text, picture,
## menu, notices for features not built yet) is collected for the caller to show.
##
## Behaviour of each opcode follows the ssi-engine project's documentation; game features
## that don't exist yet here (combat, shops, treasure...) are reported, not performed.

# --- memory map (Pool of Radiance) ---
const PARTY_X := 0xC04B
const PARTY_Y := 0xC04C
const PARTY_DIR := 0xC04D       # 0 north, 1 east, 2 south, 3 west
const WALL_AHEAD := 0xC04E      # wall type on the side being faced
const SQUARE_INFO := 0xC04F     # current square's info byte (low 7 bits: event number)
const CLOCK_HOUR := 0x49C9      # scripts treat >= 14 as night
const SKY_OUTDOORS := 0x49FD
const SKY_INDOORS := 0x49FE
const MOVEMENT_BLOCK := 0x6DC9  # 255 = the move is refused
const PICTURE_HEAD := 0x6DE1    # head portrait for the next PICTURE (255 = plain picture)
const COMBAT_RESULT := 0x6DC7
const SHOP_FLAG := 0x6E6C       # 1 = the next COMBAT opens the treasure list as a shop
const TEMPLE_FLAG := 0x6DE2     # 1 = the next COMBAT opens a temple (New Phlan's temples)

enum State { IDLE, RUNNING, MENU, WAIT, SHOP, COMBAT, DONE, NEW_ECL, ERROR, TEMPLE }

var mem := PackedByteArray()
var ecl: EclScript
var state := State.IDLE
var pc := 0                      # offset into script.code
var stack: Array[int] = []
var compare := 0

# Output since the last clear_output()
var text := ""                   # accumulated message text
var text_changed := false        # set by PRINT/PRINT_CLEAR (including clearing to "")
var picture := -1                # last PICTURE id (255 = cleared), -1 = untouched
var picture_head := 255
## A figure approaching in the 3D view: sprite id (-1 none), distance 2 far .. 0 close,
## and the portrait it turns into once close (picture id, head id or 255).
var sprite_id := -1
var sprite_distance := 0
## Monsters loaded for the next COMBAT: [[monster id, count, picture id], ...].
var monsters: Array = []
## Encounter distance: the maximum from SPRITE_START, less one per SPRITE_ADVANCE.
var encounter_max := 2
var encounter_advances := 0
var sprite_picture := 255
var sprite_head := 255
var menu: Array = []             # menu item strings while State.MENU
var notes: Array[String] = []    # things the engine would do but can't yet
var new_ecl := -1                # block id requested by NEW_ECL
var area_map := []               # last LOAD_AREA_MAP operands
var area_deco := []              # last LOAD_AREA_DECO operands
## Last TREASURE operands: coin amounts (copper, silver, electrum, gold, platinum),
## gems, jewelry, item list id (ITEM block; 255 = none).
var treasure := []
var error := ""

var _menu_dest := {}             # operand the menu choice is written to
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mem.resize(0x10000)
	_rng.randomize()


## Loads a script block and copies its code into memory at EclScript.BASE.
func load_script(block: PackedByteArray) -> void:
	ecl = EclScript.decode(block)
	for i in ecl.code.size():
		if EclScript.BASE + i < mem.size():
			mem[EclScript.BASE + i] = ecl.code[i]
	state = State.IDLE


## Address an entry point jumps to (0 on move, 1 on step/search, 2 rest, 3 rest
## interrupted, 4 init), as an offset into the code.
func entry_offset(index: int) -> int:
	var ins: Dictionary = ecl.instructions.get(index * 4, {})
	if ins.is_empty():
		return -1
	return int(ins.args[0].value) - EclScript.BASE


func clear_output() -> void:
	text = ""
	picture = -1
	menu = []
	notes = []
	new_ecl = -1
	error = ""


## Runs an entry point to completion or until a menu.
func start(entry: int) -> State:
	pc = entry_offset(entry)
	stack.clear()
	if pc < 0:
		state = State.DONE
		return state
	state = State.RUNNING
	return run()


## Continues after a menu: writes the chosen index (0-based) and resumes.
func choose(index: int) -> State:
	if state != State.MENU:
		return state
	if menu.size() > 1:
		_write(_menu_dest, index)
	menu = []
	state = State.RUNNING
	return run()


## Continues after the temple closes.
func close_temple() -> State:
	if state != State.TEMPLE:
		return state
	write_byte(TEMPLE_FLAG, 0)
	state = State.RUNNING
	return run()


## Continues after the shop closes.
func close_shop() -> State:
	if state != State.SHOP:
		return state
	write_byte(SHOP_FLAG, 0)
	state = State.RUNNING
	return run()


## Continues after a fight. `result`: 0 = the party won (the script reads it).
func end_combat(result: int) -> State:
	if state != State.COMBAT:
		return state
	write_byte(COMBAT_RESULT, result)
	monsters = []
	treasure = []
	state = State.RUNNING
	return run()


## Continues after a DELAY pause.
func resume() -> State:
	if state != State.WAIT:
		return state
	state = State.RUNNING
	return run()


func run(max_steps: int = 20000) -> State:
	var steps := 0
	while state == State.RUNNING:
		steps += 1
		if steps > max_steps:
			_fail("step limit reached at %04X" % (pc + EclScript.BASE))
			break
		var ins := ecl._read(pc)
		if ins.is_empty():
			_fail("cannot decode instruction at %04X" % (pc + EclScript.BASE))
			break
		var next := pc + int(ins["size"])
		pc = next
		_exec(ins)
	return state


# ---------------------------------------------------------------- memory

func read_byte(addr: int) -> int:
	return mem[addr & 0xFFFF]


func write_byte(addr: int, value: int) -> void:
	mem[addr & 0xFFFF] = value & 0xFF


func _value(a: Dictionary) -> int:
	var t: int = a.type
	match t:
		0x00, 0x02, 0x04:
			return int(a.value)
		0x01, 0x05:
			return read_byte(int(a.value))
		0x03:
			return read_byte(int(a.value)) | (read_byte(int(a.value) + 1) << 8)
	return 0


func _string(a: Dictionary) -> String:
	var t: int = a.type
	if t == 0x80:
		return a.value
	if t == 0x81 or t == 0x01:
		var s := ""
		var addr := int(a.value)
		while read_byte(addr) != 0 and s.length() < 256:
			s += char(read_byte(addr))
			addr += 1
		return s
	return str(_value(a))


func _write(dest: Dictionary, value: int, offset: int = 0) -> void:
	var t: int = dest.get("type", -1)
	var addr: int = int(dest.get("value", 0)) + offset
	if t == 0x03:
		write_byte(addr, value)
		write_byte(addr + 1, value >> 8)
	elif t == 0x01 or t == 0x05 or t == 0x81:
		write_byte(addr, value)


func _write_string(dest: Dictionary, s: String) -> void:
	var addr := int(dest.value)
	for i in s.length():
		write_byte(addr + i, s.unicode_at(i))
	write_byte(addr + s.length(), 0)


# ---------------------------------------------------------------- execution

func _jump(a: Dictionary) -> void:
	pc = int(a.value) - EclScript.BASE


func _fail(message: String) -> void:
	error = message
	state = State.ERROR


func _note(message: String) -> void:
	notes.append(message)


## Opcodes with no visible effect here yet (sprites, sound, party checks...).
const QUIET := ["CLEAR_BOX",
	"SOUND", "CLOCK", "PARTY_STRENGTH", "PARTY_CHECK", "PARTY_SKILL_CHECK", "SURPRISE",
	"HAS_EFFECT", "FIND_ITEM", "DESTROY_ITEM", "LOAD_CHAR", "NPC_ADD", "NPC_REMOVE",
	"WHO", "SPELL", "UNUSED_1F", "UNUSED_42", "UNKNOWN_44", "UNKNOWN_48",
	"UNKNOWN_49", "UNKNOWN_4A", "UNKNOWN_4B", "FOR_START", "FOR_REPEAT", "PICTURE2", "CALL"]


func _exec(ins: Dictionary) -> void:
	var a: Array = ins.args
	var op := String(ins.op)
	if op in QUIET:
		return
	match op:
		"EXIT":
			state = State.DONE
		"GOTO":
			_jump(a[0])
		"GOSUB":
			stack.append(pc)
			_jump(a[0])
		"RETURN":
			if stack.is_empty():
				state = State.DONE
			else:
				pc = stack.pop_back()
		"COMPARE":
			if a[0].type == 0x80 or a[1].type == 0x80 or a[0].type == 0x81 or a[1].type == 0x81:
				var s0 := _string(a[0])
				var s1 := _string(a[1])
				compare = 0 if s0 == s1 else (-1 if s0 < s1 else 1)
			else:
				compare = _value(a[0]) - _value(a[1])
		"COMPARE_AND":
			compare = 0 if (_value(a[0]) == _value(a[1]) and _value(a[2]) == _value(a[3])) else 1
		"IF_EQ", "IF_NE", "IF_LT", "IF_GT", "IF_LE", "IF_GE":
			if not _test(op):
				var skipped := ecl._read(pc)
				if not skipped.is_empty():
					pc += int(skipped["size"])
		"ADD":
			_write(a[2], _value(a[0]) + _value(a[1]))
		"SUBTRACT":
			_write(a[2], _value(a[1]) - _value(a[0]))
		"MULTIPLY":
			_write(a[2], _value(a[0]) * _value(a[1]))
		"DIVIDE":
			var d := _value(a[1])
			_write(a[2], _value(a[0]) / d if d != 0 else 0)
		"AND":
			var r := _value(a[0]) & _value(a[1])
			_write(a[2], r)
			compare = 0 if r == 0 else 1
		"OR":
			var r := _value(a[0]) | _value(a[1])
			_write(a[2], r)
			compare = 0 if r == 0 else 1
		"RANDOM":
			_write(a[1], _rng.randi_range(0, maxi(0, _value(a[0]))))
		"RANDOM0":
			var top := _value(a[1])
			_write(a[0], _rng.randi_range(0, top) if top > 0 else top)
		"WRITE_MEM":
			if a[0].type == 0x80:
				_write_string(a[1], a[0].value)
			else:
				_write(a[1], _value(a[0]))
		"WRITE_MEM_BASE_OFF":
			_write(a[1], _value(a[0]), _value(a[2]))
		"COPY_MEM":
			var src: Dictionary = a[0]
			var addr := int(src.value) + _value(a[1])
			var v := read_byte(addr)
			if src.type == 0x03:
				v |= read_byte(addr + 1) << 8
			_write(a[2], v)
		"PRINT":
			text += _string(a[0])
			text_changed = true
		"PRINT_CLEAR":
			text = _string(a[0])
			text_changed = true
		"PRINT_RETURN":
			text += "\n"
			text_changed = true
		"SPRITE_START":
			# A figure walks up: sprite id, starting distance, the portrait it ends on.
			sprite_id = _value(a[0])
			sprite_distance = clampi(_value(a[1]), 0, 2)
			encounter_max = _value(a[1])
			encounter_advances = 0
			sprite_picture = _value(a[2])
			sprite_head = read_byte(PICTURE_HEAD)
		"SPRITE_ADVANCE":
			sprite_distance = maxi(0, sprite_distance - 1)
			encounter_advances += 1
		"SPRITE_OFF":
			sprite_id = -1
		"CLEAR_MON":
			sprite_id = -1
			monsters = []
		"DELAY":
			state = State.WAIT
		"PICTURE":
			picture = _value(a[0])
			picture_head = read_byte(PICTURE_HEAD)
			if picture == 255:
				write_byte(PICTURE_HEAD, 255)
		"MENU_HORIZONTAL":
			var items := []
			for i in range(2, a.size()):
				items.append(_string(a[i]))
			_pause_for_menu(a[0], items)
		"MENU_VERTICAL":
			var items := []
			for i in range(3, a.size()):
				items.append(_string(a[i]))
			_pause_for_menu(a[0], items)
		"ON_GOTO", "ON_GOSUB":
			var index := _value(a[0])
			if index >= 0 and index < _value(a[1]) and index + 2 < a.size():
				if op == "ON_GOSUB":
					stack.append(pc)
				_jump(a[index + 2])
		"NEW_ECL":
			new_ecl = _value(a[0])
			state = State.NEW_ECL
		"LOAD_AREA_MAP":
			area_map = [_value(a[0]), _value(a[1]), _value(a[2])]
		"LOAD_AREA_DECO":
			area_deco = [_value(a[0]), _value(a[1]), _value(a[2])]
		"COMBAT":
			if read_byte(TEMPLE_FLAG) == 1:
				state = State.TEMPLE
			elif read_byte(SHOP_FLAG) == 1:
				# Shops reuse the after-combat treasure screen: pause and let the caller
				# open the shop with the TREASURE item list.
				state = State.SHOP
			elif not monsters.is_empty() or not treasure.is_empty():
				# A fight, or with treasure only a treasure find: pause while the caller
				# runs it (experience and treasure screens), then end_combat().
				state = State.COMBAT
			else:
				_note("combat")
				write_byte(COMBAT_RESULT, 0)
		"ENCOUNTER_MENU":
			_note("encounter")
			_write(a[3], 1)
		"TREASURE":
			treasure = []
			for i in a.size():
				treasure.append(_value(a[i]))

		"LOAD_MON":
			if monsters.size() < 63:
				monsters.append([_value(a[0]), maxi(_value(a[1]), 1), _value(a[2])])
		"DAMAGE":
			_note("damage")
		"GIVE_EXP":
			_note("experience")
		"ROB":
			_note("robbed")
		"PARLAY":
			_note("parley")
		"PROGRAM":
			_note("program %d" % _value(a[0]))
			state = State.DONE
		"INPUT_NUMBER", "INPUT_STRING", "PRINT_RUNES":
			_note(op.to_lower())
		_:
			_note("unhandled " + op)


func _test(op: String) -> bool:
	match op:
		"IF_EQ": return compare == 0
		"IF_NE": return compare != 0
		"IF_LT": return compare < 0
		"IF_GT": return compare > 0
		"IF_LE": return compare <= 0
		"IF_GE": return compare >= 0
	return false


func _pause_for_menu(dest: Dictionary, items: Array) -> void:
	# One item is a "press to continue" prompt; its choice is not stored.
	_menu_dest = dest
	menu = items
	state = State.MENU

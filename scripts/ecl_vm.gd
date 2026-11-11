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
const MORALE_BASE := 0x6DC6     # the encounter's morale (scripts write it before COMBAT; 99 = steady)
const AMBUSH := 0x6DCB          # surprise: 1 the party is surprised, 2 the monsters (SURPRISE)
const SHOP_FLAG := 0x6E6C       # 1 = the next COMBAT opens the treasure list as a shop
const TEMPLE_FLAG := 0x6DE2     # 1 = the next COMBAT opens a temple (New Phlan's temples)

const LEAVING_MAP := 0x6DD5    # 1 while a step would leave the map (on-move moves to the next area)
const FILE_SET := 0x6E12        # data set (ECLn, GEOn, ...) of the block the next NEW_ECL loads
const PARTY_SIZE := 0x6E3E     # how many are in the party (the finale's vote, hirelings' room)
const TRAINING_MASK := 0x6DA8   # class bits the training hall's room trains (read by PROGRAM 0)
# The wilderness (see OverlandMap): the party's square, and its heading as the on-move
# script reads it (8-way: 0 north, 2 east, 4 south, 6 west; the original keeps the
# party's facing there, doubled).
const OVERLAND_X := 0x49C3
const OVERLAND_Y := 0x49C4
const OVERLAND_HEADING := 0x033D

enum State { IDLE, RUNNING, MENU, WAIT, SHOP, COMBAT, DONE, NEW_ECL, ERROR, TEMPLE, PROGRAM, INPUT }

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
## Set by the game: the party (for PARTY_STRENGTH, PARTY_SKILL_CHECK and the encounter
## menu) and a Callable giving how many open squares lie ahead (0..2).
var party: Array = []
var open_ahead: Callable
var _menu_kind := ""             # "", "encounter" or "parlay": how a choice is stored
var _enc := {}                   # the ENCOUNTER_MENU's operands while it is open
var _parlay_values: Array = []
var encounter_distance := 0      # squares between party and monsters, as the menu sees it
var notes: Array[String] = []    # things the engine would do but can't yet
var new_ecl := -1                # block id requested by NEW_ECL
var area_map := []               # last LOAD_AREA_MAP operands
var area_deco := []              # last LOAD_AREA_DECO operands
## The wilderness map, which band of it LOAD_AREA_MAP 4,4,0 / 5,5,0 / 6,6,0 last chose
## (0..2), and whether the party is out on it (false in a 3D area).
var overland: OverlandMap
var overland_band := 0
var on_overland := false
## Last TREASURE operands: coin amounts (copper, silver, electrum, gold, platinum),
## gems, jewelry, item list id (ITEM block; 255 = none).
var treasure := []
var error := ""
## PROGRAM n: hands over to a game screen (0 the party menu / training, 9 camp, 8 the end
## of the game, 3 the party is lost); the caller resumes with close_program().
var program := -1
## The character window: ECL addresses 0x6B00 + offset read and write fields of the selected
## party member (LOAD_CHAR, WHO), at the offsets the Gold Box engine uses:
##   0x00 name   0x18 constitution   0x21.. memorized spells (from 1, as SPELL counts)
##   0x72 race   0x73 class   0x9B save vs petrification   0xA5..0xAC thief skills
##   0xB8 control (0 a player character, 128+ an NPC)   0xBB copper 0xBD electrum
##   0xBF silver 0xC1 gold 0xC3 platinum (16-bit)   0xD8 alignment
##   0x100 condition (1 able, 0x80 not, 0 no one selected; writing 0 dismisses an NPC,
##   who leaves at the next LOAD_CHAR with the high bit)   0x10C 0x80 computer-run /
##   0x81 against the party   0x11B movement   0x2B1, 0x2B4 the member's party index.
## Anything else in that range is plain memory (0x6DA8, 0x6DC6, 0x6DE1... are game state).
const CHAR_WINDOW := 0x6B00
var selected := 0                # party index the window shows (-1: LOAD_CHAR found no one)
var tables: ClassTables          # set by the game (thief skills)
var party_changed := false       # an NPC joined or left: the game redraws the party
var duel := 0                    # CALL 0x8000 (1, the arena) / 0x8001 (2): the next COMBAT is a duel
var _dismiss := false

## Minutes the script moved the clock on (CLOCK); the game runs spell effects down by them.
var minutes_passed := 0
## NPC_ADD requests waiting for the game: [monster id, morale].
var npc_requests: Array = []

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
var rune_lines: Array[String] = []
var runes_shown := false
var runes_changed := false


## INPUT_STRING / INPUT_NUMBER: the script waits for typed text (passwords, "TYPE A SINGLE
## WORD", wagers). input_max is the most characters (digits) the original takes.
var input_max := 0
var input_numeric := false
var _input_dest := {}


func answer_input(text: String) -> State:
	if state != State.INPUT:
		return state
	text = text.strip_edges().to_upper().left(input_max)
	if input_numeric:
		_write(_input_dest, int(text) if text.is_valid_int() else 0)
	else:
		_write_string(_input_dest, text)
	state = State.RUNNING
	return run()


func choose(index: int) -> State:
	if state != State.MENU:
		return state
	if _menu_kind == "encounter":
		menu = []
		_menu_kind = ""
		if not _encounter_choice(index):
			return state      # the menu is shown again (both sides wait, or they close in)
		state = State.RUNNING
		return run()
	if _menu_kind == "who":
		selected = index
		_menu_kind = ""
		menu = []
		state = State.RUNNING
		return run()
	if _menu_kind == "parlay":
		_write(_menu_dest, int(_parlay_values[index]) if index < _parlay_values.size() else 0)
		_menu_kind = ""
		menu = []
		state = State.RUNNING
		return run()
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


## Continues after the screen PROGRAM opened. PROGRAM 9 (camp) ends the script, as in the
## original; the others carry on with the next instruction.
func close_program() -> State:
	if state != State.PROGRAM:
		return state
	var was := program
	program = -1
	if was == 9 or was == 3:
		state = State.DONE
		return state
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
	addr &= 0xFFFF
	if addr == PARTY_SIZE and party != null:
		return party.size()
	if addr >= CHAR_WINDOW and addr < CHAR_WINDOW + 0x300:
		var v := _char_get(addr - CHAR_WINDOW)
		if v >= 0:
			return v & 0xFF
	return mem[addr]


func write_byte(addr: int, value: int) -> void:
	addr &= 0xFFFF
	if addr >= CHAR_WINDOW and addr < CHAR_WINDOW + 0x300 and _char_set(addr - CHAR_WINDOW, value & 0xFF):
		return
	mem[addr] = value & 0xFF


# ---------------------------------------------------------------- character window

const _COIN_AT := {0xBB: 0, 0xBD: 2, 0xBF: 1, 0xC1: 3, 0xC3: 4}   # offset -> money index


func selected_member() -> PartyMember:
	return party[selected] if selected >= 0 and selected < party.size() else null


## A field of the selected member, or -1 if `off` isn't one (then it's plain memory).
func _char_get(off: int) -> int:
	if off == 0x2B1 or off == 0x2B4:
		return maxi(selected, 0)
	var m := selected_member()
	if off == 0x100:
		if m == null:
			return 0
		return 1 if m.status == PartyMember.STATUS_OKAY else 0x80
	if m == null:
		return -1 if off >= 0x200 else 0
	if off < 0x10:
		return m.name.unicode_at(off) if off < m.name.length() else 0
	if off >= 0xBB and off <= 0xC4:
		var base := off - ((off - 0xBB) & 1)
		var coins: int = m.money[_COIN_AT[base]]
		return coins & 0xFF if off == base else (coins >> 8) & 0xFF
	if off >= 0x21 and off <= 0x35:
		return m.memorized[off - 0x21] if off - 0x21 < m.memorized.size() else 0
	if off >= 0xA5 and off <= 0xAC:
		return m.thief_skill(tables, off - 0xA5) if tables != null else 0
	match off:
		0x18: return m.stats[4]
		0x72: return m.race_id
		0x73: return m.class_id
		0x9B: return m.saves[1] if m.saves.size() > 1 else 20
		0xB8: return m.npc
		0xD8: return m.raw[0xA0] if m.raw.size() > 0xA0 else 0
		0x10C: return m.script_team
		0x11B: return m.movement
	return -1


func _char_set(off: int, v: int) -> bool:
	var m := selected_member()
	if m == null:
		return false
	if off == 0:
		if v == 0:
			m.name = ""
		return true
	if off == 0x100:
		if v == 0:
			_dismiss = true
		return true
	if off >= 0xBB and off <= 0xC4:
		var base := off - ((off - 0xBB) & 1)
		var i: int = _COIN_AT[base]
		if off == base:
			m.money[i] = (m.money[i] & 0xFF00) | v
		else:
			m.money[i] = (m.money[i] & 0xFF) | (v << 8)
		return true
	if off >= 0x21 and off <= 0x35:
		var k := off - 0x21
		if k < m.memorized.size():
			if v == 0:
				m.memorized.remove_at(k)
			else:
				m.memorized[k] = v
		return true
	match off:
		0xB8:
			m.npc = v
			return true
		0x10C:
			m.script_team = v
			return true
		0xD8:
			if m.raw.size() > 0xA0:
				m.raw[0xA0] = v
			return true
	return false


## LOAD_CHAR n: selects party member n & 0x7F. With the high bit the original redraws the
## party, and a member dismissed through the window (0x6C00 = 0) leaves now.
func _load_char(v: int) -> void:
	if v & 0x80 and _dismiss and selected_member() != null:
		party.remove_at(selected)
		party_changed = true
	_dismiss = false
	var i := v & 0x7F
	selected = i if i < party.size() else -1


## Damage from a script (traps, green slime, falling...), as the original applies it:
## "<NAME> IS HIT FOR n POINTS OF DAMAGE." or "<NAME> DIES." when it is more than 10 past
## the hit points left.
func _hurt(m: PartyMember, damage: int) -> void:
	if m.status == PartyMember.STATUS_DEAD:
		return
	if m.hp + 10 < damage:
		text += "  %s DIES. " % m.name
	else:
		text += "  %s IS HIT FOR %d POINTS OF DAMAGE. " % [m.name, damage]
	text_changed = true
	m.hp -= damage
	if m.hp > 0:
		return
	if m.hp < -9:
		m.status = PartyMember.STATUS_DEAD
	else:
		m.status = PartyMember.STATUS_UNCONSCIOUS
	m.hp = maxi(m.hp, 0) if m.status != PartyMember.STATUS_DEAD else m.hp


func _save_roll(m: PartyMember, bonus: int, kind: int) -> bool:
	var need: int = m.saves[clampi(kind, 0, 4)] if m.saves.size() == 5 else 20
	return _rng.randi_range(1, 20) + bonus + CombatSpells.racial_save_bonus(m, clampi(kind, 0, 4)) >= need


func _random_member() -> PartyMember:
	return party[_rng.randi_range(0, party.size() - 1)] if not party.is_empty() else null


func _damage(a: Array) -> void:
	var flags := _value(a[0])
	var count := _value(a[1])
	var size := _value(a[2])
	var plus := _value(a[3])
	var extra := _value(a[4])
	var roll := func() -> int:
		var t := plus
		for i in count:
			t += _rng.randi_range(1, maxi(size, 1))
		return t
	var damage: int = roll.call()
	if flags & 0x80:
		var bonus := flags & 0x1F
		var kind := extra & 7
		if flags & 0x40:
			for m in party.duplicate():
				if flags & 0x20 or not _save_roll(m, bonus, kind) or flags & 0x10:
					_hurt(m, damage)
		elif extra & 0x80:
			var m := selected_member()
			if m != null and (kind == 0 or not _save_roll(m, bonus, kind - 1) or flags & 0x10):
				_hurt(m, damage)
		else:
			var m := _random_member()
			if m != null and (not _save_roll(m, bonus, kind) or flags & 0x10):
				_hurt(m, damage)
	else:
		for i in flags:
			var m := _random_member()
			if m == null:
				break
			var d := _rng.randi_range(1, 20)
			if d > 1 and (d == 20 or d + extra > 60 - m.ac):
				_hurt(m, damage)
			damage = roll.call()
	var standing := false
	for m in party:
		if m.status == PartyMember.STATUS_OKAY:
			standing = true
	if not standing and not party.is_empty():
		text += "\nTHE ENTIRE PARTY IS KILLED!"
		program = 3
		state = State.PROGRAM


## ROB everyone (or the selected member): coins scaled down by the percentage taken, and
## each item lost with the chance given (the original lowers that chance for good after a
## heavy item: -90 for one over 255, -50 for one over 24).
func _rob(a: Array) -> void:
	var keep := (100 - _value(a[1])) / 100.0
	var chance := _value(a[2])
	var victims: Array = party if _value(a[0]) != 0 else [selected_member()]
	for m in victims:
		if m == null:
			continue
		for i in m.money.size():
			m.money[i] = int(m.money[i] * keep)
		var kept: Array[GameItem] = []
		for it in m.items:
			if it.weight > 255:
				chance = chance - 90 if chance > 90 else 0
			elif it.weight > 24:
				chance = chance - 50 if chance > 50 else 0
			if _rng.randi_range(1, 100) > chance:
				kept.append(it)
		m.items = kept


## PARTY_CHECK field, effect, a, b, c, d: for a thief skill (or movement), the party's
## average, best and worst into b, c, d (a = 0); for 0x6C00 + 0x... the original checks an
## effect on anyone instead.
func _party_check(a: Array) -> void:
	if int(a[0].type) == 0x00:
		# PARTY_CHECK 0, <effect>, ..., dest: is anyone under that spell effect (19, the
		# traps scripts test it before their thief-skill rolls)? 1 or 0 in the last operand.
		var found := 0
		for m in party:
			if (m as PartyMember).has_affect(_value(a[1])):
				found = 1
		_write(a[5], found)
		return
	var addr := int(a[0].value)
	var off := addr - CHAR_WINDOW
	var keep := selected
	var lo := 255
	var hi := 0
	var total := 0
	for i in party.size():
		selected = i
		var v := _char_get(off)
		lo = mini(lo, v)
		hi = maxi(hi, v)
		total += v
	selected = keep
	_write(a[2], 0)
	_write(a[3], total / maxi(party.size(), 1))
	_write(a[4], hi)
	_write(a[5], lo if not party.is_empty() else 255)


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
	"SOUND", "UNUSED_1F", "UNUSED_42", "UNKNOWN_44", "UNKNOWN_48",
	"UNKNOWN_49", "UNKNOWN_4A", "UNKNOWN_4B", "FOR_START", "FOR_REPEAT", "PICTURE2"]


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
		"PROGRAM":
			program = _value(a[0])
			state = State.PROGRAM
		"LOAD_CHAR":
			_load_char(_value(a[0]))
		"WHO":
			# The prompt, then a party member is picked; the window shows them.
			text = _string(a[0])
			text_changed = true
			var names := []
			for m in party:
				names.append((m as PartyMember).name)
			_pause_for_menu({}, names)
			_menu_kind = "who"
		"SPELL":
			# Finds the spell memorized by anyone: its place in that member's list (from 1)
			# and the member's index; 255 and the last index if no one has it.
			var id := _value(a[0])
			var place := 255
			var who := party.size() - 1
			for i in party.size():
				var k: int = (party[i] as PartyMember).memorized.find(id)
				if k >= 0:
					place = k + 1
					who = i
					break
			_write(a[1], place)
			_write(a[2], who)
		"FIND_ITEM":
			# Sets the comparison: equal if anyone carries an item of that type.
			var kind := _value(a[0])
			compare = 1
			for m in party:
				for it in (m as PartyMember).items:
					if it.type == kind:
						compare = 0
		"DESTROY_ITEM":
			var kind := _value(a[0])
			for m in party:
				var kept: Array[GameItem] = []
				for it in (m as PartyMember).items:
					if it.type != kind:
						kept.append(it)
				m.items = kept
		"HAS_EFFECT":
			var m := selected_member()
			compare = 0 if m != null and m.has_affect(_value(a[0])) else 1
		"PARTY_CHECK":
			_party_check(a)
		"NPC_ADD":
			# The game loads the monster record as a party member (see EclVM.npc_requests).
			npc_requests.append([_value(a[0]), _value(a[1])])
			party_changed = true
		"NPC_REMOVE":
			var m := selected_member()
			if m != null and m.npc >= 128:
				party.remove_at(selected)
				party_changed = true
		"CALL":
			match int(a[0].value):
				0x8000, 0x8001:
					duel = int(a[0].value) - 0x7FFF
				0xC01E:
					# The party moves one square ahead (wrapping at the map edge, as the
					# original masks the coordinates).
					var d := read_byte(PARTY_DIR) & 3
					write_byte(PARTY_X, (read_byte(PARTY_X) + [0, 1, 0, -1][d]) & 0x0F)
					write_byte(PARTY_Y, (read_byte(PARTY_Y) + [-1, 0, 1, 0][d]) & 0x0F)
				0xC01B, 0xC018:
					# Read / change a wilderness square through 0x00FB, 0x00FC, 0x00B1 and
					# 0x035F. The original never does either: its ECL memory ignores writes
					# to those three addresses and has nothing behind 0x035F, so the scripts'
					# lists of blocked squares never match (checked in the lab: squares on
					# them can be walked onto). The squares the scripts mean to change are
					# changed by the wilderness view itself (OverlandMap.tile).
					pass
				0x0806:
					pass    # the wilderness view gives way to the picture frame (main does it)
				0x2C90:
					pass    # redraws the view after the script changed it
				0xBA03:
					pass    # plays sound effect [0x03DE] (8 the Rolf tour's, 10 thunder); silent here
				_:
					_note("call %04X" % int(a[0].value))
		"CLOCK":
			# Pool of Radiance's form: one operand, minutes (its forced walk passes one a step).
			minutes_passed += GameClock.add_minutes(self, _value(a[0]))
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
			elif a[0].type == 0x81:
				# A string held in memory: copied whole ("YOU HAVE SURPRISED A PARTY OF" +
				# the monsters' name, put together this way by the random encounters).
				_write_string(a[1], _string(a[0]))
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
			# 4,4,0 / 5,5,0 / 6,6,0: the wilderness, one of its three bands; a map of
			# its own (mode 0 or 2) means a 3D area.
			if area_map[0] == area_map[1] and area_map[0] >= 4 and area_map[0] <= 6 and area_map[2] == 0:
				overland_band = area_map[0] - 4
				on_overland = true
			elif area_map[0] < 127 and area_map[1] in [0, 2]:
				on_overland = false
			# Mode 16 turns the view into a page for PRINT_RUNES; mode 2 brings the view back.
			if area_map[1] == 16:
				rune_lines = []
				runes_shown = true
			elif area_map[1] == 2 and runes_shown:
				runes_shown = false
				rune_lines = []
		"LOAD_AREA_DECO":
			area_deco = [_value(a[0]), _value(a[1]), _value(a[2])]
		"SURPRISE":
			# As the original: a d6 for each side against (d + 2 - a) and (b + 2 - c); the
			# monsters' surprise wins when both come up (names from ssi-engine: the result
			# is COMBAT_IS_AMBUSH; rules as documented by Pilgrim's reconstruction).
			var party_roll := randi_range(1, 6)
			var mon_roll := randi_range(1, 6)
			var result := 0
			if party_roll <= _value(a[3]) + 2 - _value(a[0]):
				result = 1
			if mon_roll <= _value(a[1]) + 2 - _value(a[2]):
				result = 2
			write_byte(AMBUSH, result)
		"COMBAT":
			if read_byte(TEMPLE_FLAG) == 1:
				state = State.TEMPLE
			elif read_byte(SHOP_FLAG) == 1:
				# Shops reuse the after-combat treasure screen: pause and let the caller
				# open the shop with the TREASURE item list.
				state = State.SHOP
			elif not monsters.is_empty() or not treasure.is_empty() or duel == 1:
				# A fight (the arena's needs no monsters: CALL 0x8000 makes the opponent), or with treasure only a treasure find: pause while the caller
				# runs it (experience and treasure screens), then end_combat().
				state = State.COMBAT
			else:
				_note("combat")
				write_byte(COMBAT_RESULT, 0)
		"ENCOUNTER_MENU":
			_enc = {"dest": a[3], "reactions": [], "texts": [],
				"flee_need": _value(a[12]), "mon_speed": _value(a[13])}
			for i in range(4, 9):
				_enc.reactions.append(_value(a[i]))
			for i in range(9, 12):
				_enc.texts.append(_string(a[i]))
			var ahead := 2
			if open_ahead.is_valid():
				ahead = int(open_ahead.call())
			encounter_max = _value(a[1])
			encounter_distance = maxi(mini(ahead, encounter_max) - encounter_advances, 0)
			# The monsters' figure stands at that distance (it becomes their picture
			# when they reach the party).
			sprite_id = _value(a[0])
			sprite_picture = _value(a[2])
			sprite_head = read_byte(PICTURE_HEAD)
			sprite_distance = encounter_distance
			_show_encounter_menu()
		"TREASURE":
			treasure = []
			for i in a.size():
				treasure.append(_value(a[i]))

		"LOAD_MON":
			if monsters.size() < 63:
				monsters.append([_value(a[0]), maxi(_value(a[1]), 1), _value(a[2])])
		"DAMAGE":
			_damage(a)
		"GIVE_EXP":
			_note("experience")
		"ROB":
			_rob(a)
		"PARLAY":
			_parlay_values = []
			for i in 5:
				_parlay_values.append(_value(a[i]))
			_pause_for_menu(a[5], ["HAUGHTY", "SLY", "NICE", "MEEK", "ABUSIVE"])
			_menu_kind = "parlay"
		"PARTY_STRENGTH":
			_write(a[0], party_strength())
		"PARTY_SKILL_CHECK":
			# As the original: the first flag says a ranger is in the party (harder to
			# surprise); the second is always 0.
			var ranger := 0
			for m in party:
				if (m as PartyMember).class_id == 4 or (m as PartyMember).class_id == 10:
					ranger = 1
			_write(a[0], ranger)
			_write(a[1], 0)
		"INPUT_NUMBER", "INPUT_STRING":
			input_max = maxi(_value(a[0]), 1)
			input_numeric = op == "INPUT_NUMBER"
			_input_dest = a[1]
			state = State.INPUT
		"PRINT_RUNES":
			# Rune text: each character code is drawn with that glyph of the game's font
			# (codes 0x40-0x7F are the rune glyphs, two to a rune).
			rune_lines.append(_string(a[0]))
			runes_changed = true
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


# --- Encounters -------------------------------------------------------------------------
# ENCOUNTER_MENU as the original does it (rules as documented by Pilgrim's reconstruction):
# operands: sprite, maximum distance, picture, where to store the outcome, five reaction
# types (one for each choice: COMBAT, WAIT, FLEE, ADVANCE, PARLAY), three texts (by
# distance 0, 1, 2), the party movement needed to flee, and the monsters' speed.
# The menu offers COMBAT WAIT FLEE PARLAY when the monsters are close (distance 0) and
# COMBAT WAIT FLEE ADVANCE otherwise. Outcomes stored: 0 the monsters flee, 1 a fight,
# 2 the party gets away, 3 talk (the script goes on to PARLAY).
#   reaction 0: FLEE gets away if the party's slowest is at least the needed movement,
#               anything else is a fight
#   reaction 1: COMBAT fights; WAIT: "BOTH SIDES WAIT."; FLEE gets away; ADVANCE comes a
#               square closer; PARLAY closes in, then talks
#   reaction 2: the monsters flee ("THE MONSTERS FLEE."), unless COMBAT and they are
#               faster than the party's fastest (then a fight)
#   reaction 3: COMBAT fights; WAIT/ADVANCE close in ("BOTH SIDES WAIT." when there);
#               FLEE gets away; PARLAY closes in, then talks
#   reaction 4: COMBAT fights; FLEE gets away; anything else closes in, then talks

func _show_encounter_menu() -> void:
	var texts: Array = _enc.texts
	var i := clampi(encounter_distance, 0, 2)
	var line := ""
	for k in 3:
		var t: String = texts[(i + k) % 3]
		if t != "":
			line = t
			break
	if line != "":
		text = line
		text_changed = true
	var last := "PARLAY" if encounter_distance == 0 else "ADVANCE"
	_pause_for_menu({}, ["COMBAT", "WAIT", "FLEE", last])
	_menu_kind = "encounter"


func _party_moves() -> Vector2i:
	var lo := 255
	var hi := 0
	for m in party:
		var mv := (m as PartyMember).movement
		lo = mini(lo, mv)
		hi = maxi(hi, mv)
	return Vector2i(lo, hi)


func _close_in() -> bool:
	if encounter_distance > 0:
		encounter_distance -= 1
		encounter_advances += 1
		sprite_distance = encounter_distance
		return true
	return false


## Resolves a choice; returns false when the menu should be shown again.
func _encounter_choice(choice: int) -> bool:
	if choice == 3 and encounter_distance == 0:
		choice = 4       # PARLAY sits where ADVANCE would be
	var reaction: int = _enc.reactions[choice] if choice < _enc.reactions.size() else 0
	var moves := _party_moves()
	var outcome := -1
	match reaction:
		0:
			outcome = 2 if choice == 2 and moves.x >= int(_enc.flee_need) else 1
		1:
			match choice:
				0: outcome = 1
				1: _say("BOTH SIDES WAIT.")
				2: outcome = 2
				3:
					if not _close_in():
						_say("BOTH SIDES WAIT.")
				4:
					if not _close_in():
						outcome = 3
		2:
			if choice == 0 and int(_enc.mon_speed) <= moves.y:
				outcome = 1
			else:
				outcome = 0
				_say("THE MONSTERS FLEE.")
		3:
			match choice:
				0: outcome = 1
				1, 3:
					if not _close_in():
						_say("BOTH SIDES WAIT.")
				2: outcome = 2
				4:
					if not _close_in():
						outcome = 3
		4:
			match choice:
				0: outcome = 1
				2: outcome = 2
				_:
					if not _close_in():
						outcome = 3
	if outcome < 0:
		_show_encounter_menu()
		return false
	_write(_enc.dest, outcome)
	_enc = {}
	return true


func _say(line: String) -> void:
	text = line
	text_changed = true


## PARTY_STRENGTH as the original works it out: for each character, (cleric levels x 4 +
## HP + 5 per point of AC below 0 + 5 per point of THAC0 below 21 + magic-user levels x 8)
## / 10, added up.
func party_strength() -> int:
	var total := 0
	for p in party:
		var m: PartyMember = p
		var cleric: int = m.raw[0x96] if m.raw.size() > 0x9B else 0
		var mage: int = m.raw[0x9B] if m.raw.size() > 0x9B else 0
		var ac_bonus := maxi(-m.ac, 0)
		var hit_bonus := maxi(21 - m.thac0, 0)
		total += (cleric * 4 + m.hp + ac_bonus * 5 + hit_bonus * 5 + mage * 8) / 10
	return mini(total, 255)


func _pause_for_menu(dest: Dictionary, items: Array) -> void:
	# One item is a "press to continue" prompt; its choice is not stored.
	_menu_dest = dest
	_menu_kind = ""
	menu = items
	state = State.MENU

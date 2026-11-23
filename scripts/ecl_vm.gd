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
const DEFEATED := 0x6DC8        # monsters the last fight put down (main._on_event_fight_finished)
const MORALE_BASE := 0x6DC6     # the encounter's morale (scripts write it before COMBAT; 99 = steady)
const AMBUSH := 0x6DCB          # surprise: 1 the party is surprised, 2 the monsters (SURPRISE)
## The approach's maximum and distance: the original's game state [0x49D6] +0x580 / +0x582, which are
## these ECL cells (one word a cell from 0x6B00). SPRITE_START and ENCOUNTER_MENU write both (GAME.OVR
## 0x111F-0x116C, 0x2C89-0x2D6C), SPRITE_ADVANCE takes 1 off the distance (0x1564), COMBAT caps it by
## the open squares ahead (0x2549-0x2568) and places the monsters there (0xE015). Scripts read them as
## an ENCOUNTER_MENU's maximum (7:17's kobold waves: SPRITE_START 0,2,0 then ENCOUNTER_MENU 0, [6DC0]).
const APPROACH_MAX := 0x6DC0
const APPROACH_DISTANCE := 0x6DC1
const SHOP_FLAG := 0x6E6C       # 1 = the next COMBAT opens the treasure list as a shop
const ALLY_ATTACKED := 0x6E33   # 1 = a player answered YES at ATTACK ALLY in this fight (chat 17)
const TEMPLE_FLAG := 0x6DE2     # 1 = the next COMBAT opens a temple (New Phlan's temples)

const LEAVING_MAP := 0x6DD5    # 1 while a step would leave the map (on-move moves to the next area)
const FILE_SET := 0x6E12        # data set (ECLn, GEOn, ...) of the block the next NEW_ECL loads
const AREA_MAP_ID := 0x49C5     # the map LOAD_AREA_MAP loaded (scripts test it)
const PREVIOUS_X := 0x49F0      # the square the party stood on before its last step
const PREVIOUS_Y := 0x49F1      #   (scripts put the party back there: "you are pushed back")
const PARTY_SIZE := 0x6E3E     # how many are in the party (the finale's vote, hirelings' room)
const TRAINING_MASK := 0x6DA8   # class bits the training hall's room trains (read by PROGRAM 0)
# The wilderness (see OverlandMap): the party's square, and its heading as the on-move
# script reads it (8-way: 0 north, 2 east, 4 south, 6 west; the original keeps the
# party's facing there, doubled).
const OVERLAND_X := 0x49C3
const OVERLAND_Y := 0x49C4
const OVERLAND_HEADING := 0x033D
const VIEW_3D := 0x49E6         # 1 on entering an area; the bands' scripts clear it for their wilderness view

enum State { IDLE, RUNNING, MENU, WAIT, SHOP, COMBAT, DONE, NEW_ECL, ERROR, TEMPLE, PROGRAM, INPUT }

var mem := PackedByteArray()
## The high bytes of the 16-bit cells (see is_cell), by address; only those not 0. `mem` holds
## the low byte, so the engine's byte reads see what they always saw.
var hi := {}
var ecl: EclScript
var state := State.IDLE
var pc := 0                      # offset into script.code
## The current map's info byte for a square (set by main), for CALL 0x2C90.
var square_info: Callable
var wall_info: Callable   # (x, y, facing) -> the wall on the script's map (main: CALL 0xC01E / 0xC018)
var stack: Array[int] = []
var compare := 0
## The original keeps six flags (DS 0x6F78-0x6F7D: EQ NE LT GT LE GE); COMPARE, AND and OR set all six
## from two numbers (GAME.OVR 0x8DBE), `compare` here; COMPARE_AND and FIND_ITEM clear them and set only EQ
## or NE, so IF_LT .. IF_GE are then false (chat 62).
var compare_eq_only := false
var _prev_op := ""         # the op run before (SPELL reads what its handler left: chat 62)

# Output since the last clear_output()
var text := ""                   # accumulated message text
var text_changed := false        # set by PRINT/PRINT_CLEAR (including clearing to "")
## Texts to record when shown ("A:B ADDR": the area's block_key and the PRINT's address; main sets
## them from QuestLog.shown_keys(): City Hall's offers that set no flag; Q11, chat 39), and those
## shown so far ("A:B ADDR" -> true). Ours' addition, kept in the companion / quick save; the
## original keeps no such record. Nothing in the game reads it.
var watch_texts := {}
var shown_texts := {}
var picture := -1                # last PICTURE id (255 = cleared), -1 = untouched
var picture_head := 255
## A figure approaching in the 3D view: sprite id (-1 none), distance 2 far .. 0 close,
## and the portrait it turns into once close (picture id, head id or 255).
var sprite_id := -1
var sprite_distance := 0
## Chat 114: a picture is up (the original's DS:0x84C9: set by PICTURE n and by a figure that became its picture,
## cleared by PICTURE 255 and when the script stops, GAME.OVR 0x159C / 0xD47). While it is, a figure at a distance
## isn't drawn at all (GAME.OVR 0x7A21 skips the sprite, 0x7A4B): the view a CALL 0x2C90 drew stays as it is
## (DOSBox: 6:28's tour, after the commandant's PICTURE 50 the guard's SPRITE_START 16, 1, 6 at the barracks, the
## watch towers and the quarters shows nothing; ours drew the guard). The figure's distance still counts.
var picture_up := false
var sprite_hidden := false
## Monsters loaded for the next COMBAT: [[monster id, count, picture id], ...].
var monsters: Array = []
## Each creature LOAD_MON loaded, in order: its 0x6C0C (0x80 fights for the party). LOAD_CHAR
## past the party selects them, as the original's list of players and monsters (Hassad's
## nomads, 7:17: LOAD_CHAR party size + n, 0x6C0C = 128).
var monster_teams: Array[int] = []
## Each loaded creature's morale (record +0x84) as a script wrote it through 0x6BB8, -1 untouched (Combat
## Chat 32: GAME.OVR 0x7F94 stores the value, less 0x32 over 0xB2, in the selected figure's +0x84; the
## tavern brawl's patrons get 178: own morale (0x32) x 2 = 100, so they fight on where 255 made them surrender).
var monster_morale: Array[int] = []
## Creatures loaded since the last CLEAR_MON (the original's DS:0x4435, GAME.OVR 0x1196): LOAD_MON stops
## at 63, and only CLEAR_MON sets it back to 0 (a fight's end doesn't).
var monsters_loaded := 0
var selected_creature := -1
## Encounter distance: the maximum from SPRITE_START, less one per SPRITE_ADVANCE.
var encounter_max := 0          # 0 until a SPRITE_START / ENCOUNTER (combat lane, Combat Chat 7: Player 5's Tyranthraxus from a save: the original places him and DIRTEN beside the party, 28,14 / 27,13, as distance 0 does)
var encounter_advances := 0
var sprite_picture := 255
var sprite_head := 255
var menu: Array = []             # menu item strings while State.MENU
## MENU_VERTICAL: its question and its items listed in the text area, one a line (lab, chat 13:
## Podol Plaza's "HOW WILL YOU PROCEDE?"); the walking screen's menu row stays empty.
var menu_vertical := false
var menu_question := ""
## Set by the game: the party (for PARTY_STRENGTH, PARTY_SKILL_CHECK and the encounter
## menu) and a Callable giving how many open squares lie ahead (0..2).
var party: Array = []
var open_ahead: Callable
var _menu_kind := ""             # "", "encounter", "parlay", "who" or "press" (a key to go on)
const PRESS_TO_CONTINUE := "PRESS <ENTER>/<RETURN> TO CONTINUE"
## row24_left when a step's script runs: the walking menu the step left on row 24 (chat 117, DOSBox: 2:15's garden;
## the original types the square's text and waits its DELAY over AREA CAST VIEW ENCAMP SEARCH LOOK, AREA lit).
const WALK_MENU_LEFT := "\u0001WALK"
var _enc := {}                   # the ENCOUNTER_MENU's operands while it is open
var _enc_waited := false
## Characters PRINTed since the script last stopped, and those before the DELAY now running: the original types
## each one at game speed x 10 ms (START.EXE 0x7782) before a DELAY's own wait (main.gd _script_delay, P104).
var print_chars := 0
var delay_chars := 0
## A PRINT_CLEAR waits while the text it replaces "types" (no DELAY of its own), then clears (chat 107).
var typing_wait := false         # BOTH SIDES WAIT. is up; the menu comes back after one DELAY (P106)
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
## The items a TREASURE with list 128+ made (TreasureMaker, at the TREASURE as the original,
## before the fight's dice); the treasure list shows them after the fight.
var treasure_items: Array[GameItem] = []
var treasure_maker: TreasureMaker = null
var error := ""
## PROGRAM n: hands over to a game screen (0 the party menu / training, 9 camp, 8 the end
## of the game, 3 the party is lost); the caller resumes with close_program().
var program := -1
## The character window: ECL addresses 0x6B00 + offset read and write fields of the selected
## party member (LOAD_CHAR, WHO), at the offsets the Gold Box engine uses:
##   0x00 name   0x18 constitution   0x20..0x70 the record's bytes 0x18..0x68 (writes only)
##   0x73 class (0x72 race is not read: a plain cell, as GAME.OVR 0x7C8F)   0x9B save vs petrification   0xA5..0xAC thief skills
##   0xB8 control (0 a player character, 128+ an NPC)   0xBB copper 0xBD electrum
##   0xBF silver 0xC1 gold 0xC3 platinum (16-bit)   0xD8 alignment
##   0x100 condition (1 able, 0x80 not, 0 no one selected; writing 0 dismisses an NPC,
##   who leaves at the next LOAD_CHAR with the high bit)   0x10C 0x80 computer-run /
##   0x81 against the party   0x11B movement   0x2B1, 0x2B4 the member's party index
##   0x2CF (0x6DCF) the parley bonus from charisma, which several PARLAYs add (GAME.OVR
##   0x7E78: CHA 3 0, 4 5, 5 10, 6 15, 7 20, 8-12 25, 13 30, 14 35, 15 40, 16 50, 17 55, 18+ 60).
## Anything else in that range is plain memory (0x6DA8, 0x6DC6, 0x6DE1... are game state).
const CHAR_WINDOW := 0x6B00
var selected := 0                # party index the window shows (-1: a figure past the party, selected_creature)
var tables: ClassTables          # set by the game (thief skills)
var party_changed := false       # an NPC joined or left: the game redraws the party
var duel := 0                    # CALL 0x8000 (1, the arena) / 0x8001 (2): the next COMBAT is a duel
var _dismiss := false
## Chat 114: the member whose name a script blanked (WRITE_MEM 0, [6B00]), as a party index (-1: none). The original's
## write goes to the record, but the party list on screen changes only at the next LOAD_CHAR's redraw (DOSBox: 3:0's
## SKULLCRUSHER SPEAKS, 'I MUST GO TO MY MASTER NOW.' types with his name in the list; ours showed an empty row
## while it typed). Reads see the blank name at once; the list keeps it until LOAD_CHAR.
var _blank_name := -1
## Chat 114: the member lit in the party list as the original last drew it: the pick when the script started, or
## the one a LOAD_CHAR with 0x80 (a redraw) points at. A LOAD_CHAR without it moves the window, not the list's
## highlight (DOSBox: 3:0's farewell types with THRENDER GRONE lit while the script has SKULLCRUSHER picked).
## main.gd lights it during a typing wait, the one time a script's mid-run pick shows.
var list_lit := -1

## Minutes the script moved the clock on (CLOCK); the game runs spell effects down by them.
var minutes_passed := 0
## NPC_ADD requests waiting for the game: [monster id, morale].
var npc_requests: Array = []

var _menu_dest := {}             # operand the menu choice is written to
var _rng := RandomNumberGenerator.new()
## Dev only (--coverage=): records which instructions, branches and menu choices ran.
var coverage: ScriptCoverage = null
var block_key := ""              # "file:block" of the loaded script, for coverage
var _at := 0                     # offset of the instruction running now
var _menu_at := -1               # offset of the instruction whose menu is open


func _init() -> void:
	mem.resize(0x10000)
	_rng.randomize()


## Dev only (ShadowExplorer): a copy that can run on without touching this VM or the party
## (members are cloned); it records into `cov`.
func fork(cov: ScriptCoverage) -> EclVM:
	var f := EclVM.new()
	f.copy_from(self)
	f.square_info = square_info
	f.wall_info = wall_info
	f.open_ahead = open_ahead
	f.tables = tables
	var copies: Array = []
	for m in party:
		copies.append((m as PartyMember).clone())
	f.party = copies
	f.coverage = cov
	return f


## Dev (M6 coverage runs): takes over `src`'s script state (memory, the running script, an
## open menu, its dice), keeping this VM's own party, coverage and callbacks. A coverage run
## puts the game back to a snapshot this way.
func copy_from(src: EclVM) -> void:
	mem = src.mem.duplicate()
	hi = src.hi.duplicate()
	watch_texts = src.watch_texts
	shown_texts = src.shown_texts.duplicate()
	ecl = src.ecl
	state = src.state
	pc = src.pc
	stack.assign(src.stack)
	compare = src.compare
	compare_eq_only = src.compare_eq_only
	_prev_op = src._prev_op
	menu = src.menu.duplicate()
	menu_vertical = src.menu_vertical
	menu_question = src.menu_question
	_menu_kind = src._menu_kind
	_press_queue = src._press_queue.duplicate(true)
	_blank_name = src._blank_name
	picture_up = src.picture_up
	white_from = src.white_from
	row24_left = src.row24_left
	damage_page = src.damage_page
	place_blank = src.place_blank.duplicate()
	sprite_hidden = src.sprite_hidden
	list_lit = src.list_lit
	_enc = src._enc.duplicate(true)
	_enc_waited = src._enc_waited
	print_chars = src.print_chars
	delay_chars = src.delay_chars
	typing_wait = src.typing_wait
	_menu_dest = src._menu_dest.duplicate()
	_parlay_values = src._parlay_values.duplicate()
	encounter_distance = src.encounter_distance
	encounter_advances = src.encounter_advances
	encounter_max = src.encounter_max
	monsters = src.monsters.duplicate(true)
	monster_teams.assign(src.monster_teams)
	monster_morale.assign(src.monster_morale)
	selected = src.selected
	walk_selected = src.walk_selected
	_script_pick = src._script_pick
	selected_creature = src.selected_creature
	_input_dest = src._input_dest.duplicate()
	input_max = src.input_max
	input_numeric = src.input_numeric
	overland = src.overland
	overland_band = src.overland_band
	on_overland = src.on_overland
	block_key = src.block_key
	_at = src._at
	_menu_at = src._menu_at
	new_ecl = src.new_ecl
	area_map = src.area_map.duplicate()
	area_deco = src.area_deco.duplicate()
	_rng.state = src._rng.state


## Loads a script block and copies its code into memory at EclScript.BASE.
func load_script(block: PackedByteArray, key: String = "") -> void:
	block_key = key
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
	white_from = -1
	damage_page = false
	picture = -1
	menu = []
	notes = []
	new_ecl = -1
	error = ""


var running_entry := -1    # the entry point start() last ran (4: the init)


## Runs an entry point to completion or until a menu.
func start(entry: int) -> State:
	running_entry = entry
	step_fresh = step_next
	step_next = false
	picture_up = false
	row24_left = WALK_MENU_LEFT if walk_menu_next else ""
	walk_menu_next = false
	list_lit = selected
	_runes_to_box = false
	pc = entry_offset(entry)
	stack.clear()
	if pc < 0:
		state = State.DONE
		return state
	state = State.RUNNING
	return run()


## Continues after a menu: writes the chosen index (0-based) and resumes.
## PRINT_RUNES (main chat 109, DOSBox): the original prints a rune string where the text cursor is, at once (not
## typed), each code c as glyph c + 1 of the game's font (8X8D1 block 201), white: 5:4's gnoll's paper puts the six
## dwarvish runes on the text box's row 18 under "YOU LOOK AT THE WRITING...", the 3D view untouched. Ours keeps them
## in the text as RUNE_BASE + c (drawn by main.gd). After a CLEAR_BOX (the view window cleared, no inner frame) they go
## into the view window instead, from row 5, two rows a PRINT_RETURN (4:21's elf scroll: three lines at screen y 40,
## 56, 72): rune_lines, shown while runes_shown. That page stays up after LOAD_AREA_MAP's mode 2 until the script's
## next stop is answered (the press after "...THE LAST PART IS EATEN AWAY."), then the view is empty (its inner frame,
## black) until the party turns or steps (view_blank). Ours had drawn the page in the 3D view's square a glyph off
## and dropped it at the mode 2, before the press: none of Pool's four rune texts was ever seen.
const RUNE_BASE := 0xE000
var rune_lines: Array[String] = []
var runes_shown := false
var runes_closing := false
## The place line CALL 0x2C90 drew: {"hide": 0x49FB then, "at": [x, y, facing]} (main's _place_line keeps it until the
## party is elsewhere); {} for the live cell.
var place_drawn := {}
var redraw_pending := false   # a CALL 0x2C90 waits for its text to type: main keeps the old square till then
var view_redrawn := false   # the script ran something that redraws the view (main's _stale_view; main chat 110)
var view_blank := false
var _runes_to_box := false


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
	if coverage != null and _menu_kind != "who" and menu.size() > 1:
		var c := index
		if _menu_kind == "encounter" and index == 3 and not advance_offered():
			c = 4      # PARLAY sits where ADVANCE would be
		coverage.branch(block_key, _menu_at, "c%d" % c)
	if _menu_kind == "encounter":
		menu = []
		_menu_kind = ""
		if not _encounter_choice(index):
			return state      # the menu is shown again (both sides wait, or they close in)
		state = State.RUNNING
		return run()
	if _menu_kind == "press":
		if not _press_queue.is_empty():
			var page: Array = _press_queue.pop_front()
			_show_page(page)
			menu = [page[1]]
			return state
		damage_page = false
		row24_left = PRESS_TO_CONTINUE
		_menu_kind = ""
		menu = []
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
	# P72 (combat lane, Combat Chat 15): the shop's TREASURE list ends with the shop, as a fight's
	# does at end_combat(); kept, a later fight whose event sets no TREASURE (the Slums orcs) took
	# the shop's whole stock as its pile.
	treasure = []
	treasure_items = []
	state = State.RUNNING
	return run()


## Every COMBAT ends by zeroing the script's fight modifiers 0x6E70-0x6E72 (to-hit and
## movement, used by the combat screen; GAME.OVR 0x6BAF, side lane 2026-11-14), and the two
## fight switches 0x6DE3 (no monster's item on the pile, read at 0x567D) and 0x6DE6 (the party
## can't be destroyed, read at 0x5B0F): 0x6BDB / 0x6BE6. Chat 63: New Phlan's tavern brawl (3:0
## 0xA767) sets both; ours kept 0x6DE3 = 1 after it, so no later fight dropped a monster's item.
func _clear_fight_mods() -> void:
	for a in [0x6E70, 0x6E71, 0x6E72, 0x6DE3, 0x6DE6]:
		write_byte(a, 0)


## Continues after a fight. `result`: 0 = the party won (the script reads it).
func end_combat(result: int) -> State:
	if state != State.COMBAT:
		return state
	write_byte(COMBAT_RESULT, result)
	_clear_fight_mods()
	monsters = []
	monster_teams = []
	monster_morale = []
	treasure = []
	treasure_items = []
	PartyMember.colours_drawn.clear()
	state = State.RUNNING
	return run()


## Continues after a DELAY pause.
func resume() -> State:
	if state != State.WAIT:
		return state
	if _enc_waited:
		_enc_waited = false
		_show_encounter_menu()
		return state
	typing_wait = false
	state = State.RUNNING
	return run()


func run(max_steps: int = 20000) -> State:
	var steps := 0
	print_chars = 0
	redraw_pending = false
	if runes_closing:
		runes_closing = false
		runes_shown = false
		rune_lines = []
		view_blank = true
	while state == State.RUNNING:
		steps += 1
		if steps > max_steps:
			_fail("step limit reached at %04X" % (pc + EclScript.BASE))
			break
		var ins := ecl._read(pc)
		if ins.is_empty():
			_fail("cannot decode instruction at %04X" % (pc + EclScript.BASE))
			break
		_at = pc
		if coverage != null:
			coverage.hit(block_key, pc, ecl.instructions.has(pc))
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
	if not hi.is_empty():
		hi.erase(addr)


## The original keeps each ECL address of three windows as a 16-bit cell of its own: 0x4900-0x4CFF
## (the flags), 0x6B00-0x6EFF (the character window and the scratch bytes) and 0x9700-0x98FF.
## Its variable write (GAME.OVR 0x814A, the address classed at 0x7BCE) stores the whole value
## there, whatever the operand's type, and its read (0x82DF, from 0x7609 for types 1 and 3)
## gives the whole cell back. The script image (0x9900-0xB6FF) holds bytes. Chat 25 (lab, 7:26's
## tile loop: ADD into [4A09] as a word left 0x4A0A at 7 in ours, 0 in the original).
static func is_cell(addr: int) -> bool:
	return (addr >= 0x4900 and addr < 0x4D00) or (addr >= 0x6B00 and addr < 0x6F00) \
			or (addr >= 0x9700 and addr < 0x9900)


## A script's variable read: the whole cell in the windows (the character window's named fields
## as the original gives them, coins as words), else a byte.
func read_var(addr: int) -> int:
	addr &= 0xFFFF
	if addr == PARTY_SIZE and party != null:
		return party.size()
	if addr >= CHAR_WINDOW and addr < CHAR_WINDOW + 0x300:
		var v := _char_get(addr - CHAR_WINDOW, true)
		if v >= 0:
			return v & 0xFFFF
	if is_cell(addr):
		return mem[addr] | (int(hi.get(addr, 0)) << 8)
	return read_byte(addr)


## A script's variable write (GAME.OVR 0x814A): the whole value (16 bits) into a cell, a byte
## elsewhere.
func write_var(addr: int, value: int) -> void:
	addr &= 0xFFFF
	value &= 0xFFFF
	if addr >= CHAR_WINDOW and addr < CHAR_WINDOW + 0x300 and _char_set(addr - CHAR_WINDOW, value, true):
		return
	if not is_cell(addr):
		write_byte(addr, value)
		return
	mem[addr] = value & 0xFF
	if value >> 8:
		hi[addr] = value >> 8
	elif not hi.is_empty():
		hi.erase(addr)


# ---------------------------------------------------------------- character window

const _COIN_AT := {0xBB: 0, 0xBD: 2, 0xBF: 1, 0xC1: 3, 0xC3: 4}   # offset -> money index


## The parley bonus for a charisma (window field 0x2CF); below 3 the original leaves it unset.
static func charisma_bonus(cha: int) -> int:
	if cha >= 18:
		return 60
	if cha >= 8 and cha <= 12:
		return 25
	return {3: 0, 4: 5, 5: 10, 6: 15, 7: 20, 13: 30, 14: 35, 15: 40, 16: 50, 17: 55}.get(cha, 0)


func selected_member() -> PartyMember:
	return party[selected] if selected >= 0 and selected < party.size() else null


## A field of the selected member, or -1 if `off` isn't one (then it's plain memory).
func _char_get(off: int, whole := false) -> int:
	if off == 0x2B1 or off == 0x2B4:
		return maxi(selected, 0)
	if selected < 0 and selected_creature >= 0 and off == 0x10C:
		return monster_teams[selected_creature]
	var m := selected_member()
	if off == 0x2CF:
		return charisma_bonus(m.stats[5] if m != null and m.stats.size() > 5 else 0)
	if off == 0x100:
		if m == null:
			return 0
		return 1 if m.status == PartyMember.STATUS_OKAY else 0x80
	if m == null:
		return -1 if off >= 0x200 else 0
	if off < 0x10:
		if selected == _blank_name:
			return 0
		return m.name.unicode_at(off) if off < m.name.length() else 0
	if off >= 0xBB and off <= 0xC4:
		var base := off - ((off - 0xBB) & 1)
		var coins: int = m.money[_COIN_AT[base]]
		# A script's read (whole) gets the coins as a word (GAME.OVR 0x7D26-0x7D8A); the byte
		# after each is a plain cell there. The engine's byte reads keep the two halves.
		if whole:
			return coins if off == base else -1
		return coins & 0xFF if off == base else (coins >> 8) & 0xFF
	if off >= 0xA5 and off <= 0xAC:
		return m.thief_skill(tables, off - 0xA5) if tables != null else 0
	match off:
		0x18: return m.stats[4]
		# Not 0x72 (race): the original's window read (GAME.OVR 0x7C8F) has no case for it, so
		# [6B72] is a plain cell no script writes, 0 (chat 48, DOSBox at 8:29 5,8: cell 0 and 980D 0
		# after the search loop). The secret-door searches' elf / half-elf bonus (1:24, 5:7, 7:22,
		# 7:23, 8:13, 8:29's table at 0xAFE5) never applies there, and 1:18 counts everyone non-human.
		0x73: return m.class_id
		0x9B: return m.saves[1] if m.saves.size() > 1 else 20
		0xB8: return m.npc
		0xD8: return m.raw[0xA0] if m.raw.size() > 0xA0 else 0
		0x10C: return m.script_team
		0x11B: return m.movement
	return -1


func _char_set(off: int, v: int, whole := false) -> bool:
	if selected < 0 and selected_creature >= 0 and off == 0x10C:
		monster_teams[selected_creature] = v
		return true
	if selected < 0 and selected_creature >= 0 and off == 0xB8:
		monster_morale[selected_creature] = (v - 0x32 if v > 0xB2 else v) & 0xFF
		return true
	var m := selected_member()
	if m == null:
		return false
	if off == 0:
		if v == 0:
			_blank_name = selected
		return true
	if off == 0x100:
		# GAME.OVR 0x803F: 0 dismisses; 0x87 turns the member to stone (the trap door in
		# Valjevo's castle, "TURNS TO STONE"); other values of 0x80+ only mark it unable.
		if v == 0:
			_dismiss = true
		elif v == 0x87:
			m.status = SpecialAffects.STONED
		return true
	if off >= 0xBB and off <= 0xC4:
		var base := off - ((off - 0xBB) & 1)
		var i: int = _COIN_AT[base]
		if whole:
			# A script's write stores the word (GAME.OVR 0x7FB3-0x8017); the byte after is a cell.
			if off != base:
				return false
			m.money[i] = v
			return true
		if off == base:
			m.money[i] = (m.money[i] & 0xFF00) | v
		else:
			m.money[i] = (m.money[i] & 0xFF) | (v << 8)
		return true
	if off >= 0x20 and off <= 0x70:
		# Chat 62, GAME.OVR 0x7F6C: the record's bytes 0x18..0x68 as they lie (offset - 8: the memorized
		# spells, the spell book...), and the cell as well (0x8199 stores it first); a read is the plain
		# cell (0x7C9F has no case for them). Ours had 0x21.. as the memorized list from its top.
		m.set_record_byte(off - 8, v & 0xFF)
		return false
	match off:
		0xB8:
			m.npc = v
			# The same byte of the record (the original's saves carry it; chat 31).
			if m.raw.size() > 0xB8:
				m.raw[0xB8] = v
			# The original's write goes to the record's +0x84, the morale (GAME.OVR 0x7F94: less 0x32 over
			# 0xB2; Combat Chat 32), which its fights' morale check reads.
			m.morale = (v - 0x32 if v > 0xB2 else v) & 0xFF
			if m.raw.size() > 0x84:
				m.raw[0x84] = m.morale
			return true
		0x10C:
			m.script_team = v
			# The original keeps it in the record (GAME.OVR 0x8074-0x80C5): 0x10E the side, 0x10F
			# computer-run; so a save carries it (combat lane, Combat Chat 6).
			if m.raw.size() > 0x10F and v in [0, 0x80, 0x81]:
				m.raw[0x10E] = 1 if v == 0x81 else 0
				m.raw[0x10F] = 0 if v == 0 else 1
			return true
		0xD8:
			if m.raw.size() > 0xA0:
				m.raw[0xA0] = v
			return true
	return false


## The player's own selection and the script's (Combat Chat 18, GAME.OVR; seen in DOSBox: the inn's WHO WILL
## PAY? answered with the sixth member, its script's LOAD_CHAR, then the camp opens with the first member lit,
## the one selected on the walking screen). The main loop keeps the selected member each time the walking
## menu returns (0x40E3 -> 0x4436); every LOAD_CHAR flags the selection as the script's (0x102C: 0x4430 = 1);
## EXIT (0xDAC) and PROGRAM (0x3B5C) put the kept member back when the flag is set and clear it. WHO's pick
## sets no flag: it stays unless a LOAD_CHAR follows. Not modelled: LOAD_CHAR with the high bit clears the flag
## when it lands on the kept member while the party's redraw flags (0x84D2, 0x84D3) are set (0x10AE).
var walk_selected := -1
var _script_pick := false


func _restore_pick() -> void:
	if not _script_pick:
		return
	_script_pick = false
	if party != null and walk_selected >= 0 and walk_selected < party.size():
		selected = walk_selected
		selected_creature = -1


## LOAD_CHAR n: selects party member n & 0x7F. With the high bit the original redraws the
## party, and a member dismissed through the window (0x6C00 = 0) leaves now.
## Chat 113: the original types a script's text before the next instruction runs (START.EXE 0x7782), so an
## instruction that changes the screen after it (a figure walking up, a picture, a member joining or leaving) waits
## for the text printed since the script last stopped (DOSBox: 1:18's tavern, YOU HAVE ENTERED A CROWDED TAVERN.
## types over the old view, then the drunk's picture, then the next text). True: wait that typing time, then the
## instruction runs again (print_chars is spent, so it runs on).
func _wait_typing() -> bool:
	if print_chars <= 0 or running_entry == 2 or text.strip_edges() == "":
		return false
	pc = _at
	delay_chars = print_chars
	print_chars = 0
	typing_wait = true
	state = State.WAIT
	return true


func _load_char(v: int) -> void:
	_script_pick = true
	if _blank_name >= 0 and _blank_name < party.size():
		(party[_blank_name] as PartyMember).name = ""
	_blank_name = -1
	if v & 0x80 and _dismiss and selected_member() != null:
		party.remove_at(selected)
		party_changed = true
	_dismiss = false
	var i := v & 0x7F
	var k := i - party.size()
	# Chat 21, from GAME.OVR 0x1026: LOAD_CHAR walks n figures down the list from its head and points the
	# window at the one it reaches; past the end of the list it leaves the window where it was (the member
	# selected before stays). Ours had "no one" (-1), so the parley bonus (0x6DCF) read 0 ever after:
	# 2:20's patrols were angered at every parley.
	if i < party.size():
		selected = i
		selected_creature = -1
	elif k < monster_teams.size():
		selected = -1
		selected_creature = k
	if v & 0x80:
		list_lit = selected


## The text box as the original's printer fills it during a DAMAGE (chat 43, DOSBox at 5:6's
## altar): rows 17-22 (0..5 here), 38 columns. Each hit line starts on a new row (GAME.OVR 0x9691
## sets the column to 38 first); a line that fills the row leaves the cursor on the next one; a
## new row past the box shows "PRESS ANY KEY TO CONTINUE" (the printer) and starts a clear box,
## and a cursor already past it before a line gives "PRESS <ENTER>/<RETURN> TO CONTINUE" (0x9661).
## Pages waiting for their key: [text, row 24's prompt] each; the last one is the box itself.
const PRESS_ANY_KEY := "PRESS ANY KEY TO CONTINUE"
var _box_rows := PackedStringArray()
var _box_row := 0
var _box_pages: Array = []
var _box_white := -1      # the page's first row a hit line went to (-1: none yet)
## Hit lines finished (the party's redraw after each, which blanks the place line) when a page was cut (chat 117,
## DOSBox: 2:9's bugbears, TAKE THE PUNCH: a page cut inside the first hit line keeps the place line and the HP).
var _box_hits := 0
## Chat 114 (DOSBox, 8:13's rocks): the original prints DAMAGE's hit lines in white under the script's green text,
## the printer's PRESS ANY KEY TO CONTINUE in colour 13, and its party redraw after a hit blanks the place line.
## white_from: the shown text's first white row (-1 none); damage_page: a page with hits is up.
var white_from := -1
var damage_page := false
## Chat 115 (DOSBox: 4:10's fumes, 5:6's altar): the place line a page with hits blanked stays blank after the
## script goes on or stops (PRINT_CLEAR, a YES/NO menu, the walking menu) until something redraws it: a CALL
## 0x2C90, a fight, a new area, a step or turn, SEARCH (main). [x, y, facing] where it went blank; [] none.
var place_blank := []
## Main sets step_next before the square's script after a step (_finish_move); start() moves it to step_fresh for
## that run. A DAMAGE page in it sets a redraw flag again (step_fresh false).
var step_next := false
## Main sets walk_menu_next before a step attempt's square script (entry 1): start() leaves row24_left = WALK_MENU_LEFT.
var walk_menu_next := false
var step_fresh := false
## Chat 114 (DOSBox, 5:4's kitchen, check 60): DAMAGE's last PRESS <ENTER>/<RETURN> TO CONTINUE stays on row 24 after
## its key (GAME.OVR 0x37CD draws it, nothing clears it); a vertical menu after it leaves row 24 alone, a horizontal
## menu, a question or the walking menu redraws it. The row as left ("" when redrawn).
var row24_left := ""
## The pages still to show after the one on screen (a "press" menu's next texts).
var _press_queue: Array = []


func _box_start() -> void:
	_box_rows = PrintWrap.lines(text, 38) if text != "" else PackedStringArray([""])
	_box_row = _box_rows.size() - 1
	if _box_rows[_box_row].length() >= 38:
		_box_row += 1
	_box_pages = []
	_box_white = -1
	_box_hits = 0


func _box_page(prompt: String) -> void:
	_box_pages.append(["\n".join(_box_rows), prompt, _party_snap(), _box_white, _box_hits])
	_box_rows = PackedStringArray([""])
	_box_row = 0
	_box_white = -1


func _box_line(line: String) -> void:
	var fresh := false
	if _box_row > 5:
		_box_page(PRESS_TO_CONTINUE)
		fresh = true      # the box starts clear at its top row
	var parts := PrintWrap.lines(line, 38)
	for i in parts.size():
		# A new line always moves to the next row; its own wrapped rest only when the part
		# before didn't fill its row (that already moved the cursor).
		if (i == 0 and not fresh) or (i > 0 and parts[i - 1].length() < 38):
			_box_row += 1
		if _box_row > 5:
			_box_page(PRESS_ANY_KEY)
		while _box_rows.size() <= _box_row:
			_box_rows.append("")
		_box_rows[_box_row] = parts[i]
		if _box_white < 0:
			_box_white = _box_row
		if parts[i].length() >= 38:
			_box_row += 1


## Chat 114: the original prints each hit and redraws the party's HP column before the next hit is rolled, so a
## page of hits waiting for its key shows the HP as they stood when that page filled (DOSBox: 8:13's rocks, check
## 87: page 1 RHIANNON and THRENDER GRONE hit, BROTHER SEAN still 10 and PHINEAS 4; ours showed every member's
## end HP on page 1). A page keeps the party's HP and status as they stood ([hp, status] each); the last page
## the end values. Shown by _show_page.
func _party_snap() -> Array:
	var s := []
	for m in party:
		s.append([(m as PartyMember).hp, (m as PartyMember).status])
	return s


func _show_page(page: Array) -> void:
	text = page[0]
	text_changed = true
	white_from = int(page[3]) if page.size() > 3 else -1
	damage_page = white_from >= 0 and (page.size() < 5 or int(page[4]) > 0)
	if damage_page:
		place_blank = [read_byte(PARTY_X) & 15, read_byte(PARTY_Y) & 15, read_byte(PARTY_DIR) & 3]
		step_fresh = false
	if page.size() > 2 and (page[2] as Array).size() == party.size():
		for i in party.size():
			(party[i] as PartyMember).hp = page[2][i][0]
			(party[i] as PartyMember).status = page[2][i][1]


## Damage from a script (traps, green slime, falling...), as the original applies it:
## "<NAME> IS HIT FOR n POINTS OF DAMAGE." or "<NAME> DIES." when it is more than 10 past
## the hit points left, each on its own row (_box_line).
func _hurt(m: PartyMember, damage: int) -> void:
	if m.status == PartyMember.STATUS_DEAD:
		return
	_box_line("%s DIES." % m.name if m.hp + 10 < damage else "%s IS HIT FOR %d POINTS OF DAMAGE." % [m.name, damage])
	# The original's damage routine (START.EXE 0xBA:0x2228, called from GAME.OVR 0x96BF), as in a fight
	# (combat.gd): HP at or above the damage just drops (to 0: unconscious); short of it, the excess decides:
	# more than 9 dead, else dying; an ANIMATED member brought to 0 dies; down, dying and dead keep 0 HP.
	# Chat 61, check 87 (8:13's rocks: PHINEAS, 4 HP, hit for 5: dying in the original's save; ours had
	# him unconscious, and a member killed outright kept a negative HP).
	var past := damage - m.hp if damage > m.hp else 0
	m.hp = maxi(m.hp - damage, 0)
	if past > 9 or (m.hp == 0 and m.status == PartyMember.STATUS_ANIMATED):
		m.status = PartyMember.STATUS_DEAD
	elif past > 0:
		m.status = PartyMember.STATUS_DYING
	elif m.hp == 0:
		m.status = PartyMember.STATUS_UNCONSCIOUS
	_box_hits += 1


## The original's saving throw (GAME.OVR 0x2BC4D, the same one fights use: Combat's `_save`): a natural 1
## fails and a natural 20 saves whatever the bonus (chat 61; ours had added the bonus to every roll).
func _save_roll(m: PartyMember, bonus: int, kind: int) -> bool:
	var need: int = m.saves[clampi(kind, 0, 4)] if m.saves.size() == 5 else 20
	var d := _ri(1, 20)
	if d == 1:
		return false
	if d == 20:
		return true
	return d + bonus + CombatSpells.racial_save_bonus(m, clampi(kind, 0, 4)) >= need


func _random_member() -> PartyMember:
	return party[_ri(0, party.size() - 1)] if not party.is_empty() else null


func _damage(a: Array) -> void:
	var flags := _value(a[0])
	var count := _value(a[1])
	var size := _value(a[2])
	var plus := _value(a[3])
	var extra := _value(a[4])
	var roll := func() -> int:
		var t := plus
		for i in count:
			t += _ri(1, maxi(size, 1))
		return t
	var damage: int = roll.call()
	_box_start()
	# The original picks a random member right after the damage roll whenever 0x40 (the whole
	# party) is off, whatever the form: one Random(party size) the volley form and the selected
	# member's form never use (GAME.OVR 0x354C-0x355E; trace of 5:3's gate, chat 42).
	var picked: PartyMember = null if flags & 0x40 else _random_member()
	if flags & 0x80:
		# Bits 0-4 are the save bonus (GAME.OVR 0x3570; chat 61: no separate 0x10 "always hurt", which ours had;
		# no DAMAGE in Pool sets 0x80 and 0x10 together), 0x20 no save for the whole party, 0x40 the whole party.
		var bonus := flags & 0x1F
		var kind := extra & 7
		if flags & 0x40:
			for m in party.duplicate():
				if flags & 0x20 or not _save_roll(m, bonus, kind):
					_hurt(m, damage)
		elif extra & 0x80:
			var m := selected_member()
			if m != null and (kind == 0 or not _save_roll(m, bonus, kind - 1)):
				_hurt(m, damage)
		else:
			var m := picked
			if m != null and not _save_roll(m, bonus, kind):
				_hurt(m, damage)
	else:
		for i in flags:
			var m := _random_member()
			if m == null:
				break
			var d := _ri(1, 20)
			if d > 1 and (d == 20 or d + extra > 60 - m.ac):
				_hurt(m, damage)
			damage = roll.call()
	var standing := false
	for m in party:
		if m.status == PartyMember.STATUS_OKAY:
			standing = true
	text = "\n".join(_box_rows)
	text_changed = true
	if not standing and not party.is_empty():
		text += "\nTHE ENTIRE PARTY IS KILLED!"
		program = 3
		state = State.PROGRAM
		return
	# The original always ends DAMAGE with "PRESS <ENTER>/<RETURN> TO CONTINUE" on row 24 and
	# waits for a key (any key: GetKey), whoever was hit (GAME.OVR 0x37CD-0x37DF, START.EXE
	# 0x709:0xBF5; chat 43, 5:3's boulders); full boxes before it wait the same way.
	_press_queue = _box_pages
	_press_queue.append([text, PRESS_TO_CONTINUE, _party_snap(), _box_white, _box_hits])
	_box_pages = []
	var page: Array = _press_queue.pop_front()
	_show_page(page)
	_pause_for_menu({}, [page[1]])
	_menu_kind = "press"


## ROB everyone (or the selected member): coins scaled down by the percentage taken, and
## each item lost with a chance (GAME.OVR 0x92C3, called once per member: a d100 at or under
## the chance takes the item; after a heavy item the chance stays lower for the rest of that
## member's items: -90 for one over 255, -50 for one over 24; the next member starts again).
## The original's handler (0x2AF7) reads the second operand twice: the items' chance is the
## coins' percentage and the third operand is never read (2:20's PAY, `ROB 1, 50, 0`, takes
## items half the time).
func _rob(a: Array) -> void:
	var keep := 100 - _value(a[1])      # the percentage kept: CoinPile.real48_keep (Combat Chat 35)
	var victims: Array = party if _value(a[0]) != 0 else [selected_member()]
	for m in victims:
		if m == null:
			continue
		var chance := _value(a[1])
		for i in m.money.size():
			m.money[i] = CoinPile.real48_keep(m.money[i], keep)
		var kept: Array[GameItem] = []
		for it in m.items:
			if it.weight > 255:
				chance = chance - 90 if chance > 90 else 0
			elif it.weight > 24:
				chance = chance - 50 if chance > 50 else 0
			if _ri(1, 100) > chance:
				kept.append(it)
		m.items = kept


## PARTY_CHECK field, effect, a, b, c, d (GAME.OVR 0x217B, its writer 0x211D): for a field
## the party's worst, best and average into a, b, c and 0 into d; for field 0 whether anyone
## is under the effect, into d (a and b 0). The original knows two fields only: [6BA7]
## (record +0x79, find / remove traps) and [6C1B] (record +0x11C, movement); any other
## writes nothing.
func _party_check(a: Array) -> void:
	if int(a[0].type) == 0x00:
		# PARTY_CHECK 0, <effect>, ..., dest: is anyone under that spell effect (19, the
		# traps scripts test it before their thief-skill rolls)? 1 or 0 in the last operand.
		# The original writes 0, 0, then c from an unset stack byte (left as it is here), then d.
		var found := 0
		for m in party:
			if (m as PartyMember).has_affect(_value(a[1])):
				found = 1
		_write(a[2], 0)
		_write(a[3], 0)
		_write(a[5], found)
		return
	var addr := int(a[0].value)
	if addr != 0x6BA7 and addr != 0x6C1B:
		return
	var off := addr - CHAR_WINDOW
	var keep := selected
	var lo := 255
	var hi := 0
	var total := 0
	for i in party.size():
		selected = i
		var v := _char_get(off) & 0xFF
		lo = mini(lo, v)
		hi = maxi(hi, v)
		total += v
	selected = keep
	_write(a[2], lo)
	_write(a[3], hi)
	_write(a[4], total / maxi(party.size(), 1))
	_write(a[5], 0)


func _value(a: Dictionary) -> int:
	var t: int = a.type
	match t:
		0x00, 0x02, 0x04:
			return int(a.value)
		0x01, 0x03:
			return read_var(int(a.value))
		0x05:
			return read_byte(int(a.value))
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
	if t == 0x01 or t == 0x03 or t == 0x05 or t == 0x81:
		write_var(addr, value)


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
const QUIET := [
	"SOUND", "UNUSED_1F", "UNUSED_42", "UNKNOWN_44", "UNKNOWN_48",
	"UNKNOWN_49", "UNKNOWN_4A", "UNKNOWN_4B", "FOR_START", "FOR_REPEAT", "PICTURE2"]


func _exec(ins: Dictionary) -> void:
	var a: Array = ins.args
	var op := String(ins.op)
	var prev_op := _prev_op
	_prev_op = op
	if op in QUIET:
		return
	if op in ["PICTURE", "NEW_ECL", "LOAD_AREA_MAP", "LOAD_AREA_DECO", "COMBAT"]:
		view_redrawn = true
	if op == "COMBAT":
		picture_up = false      # GAME.OVR 0x24E1 clears DS:0x84C8-9 after the fight (0x261F)
	match op:
		"EXIT":
			_restore_pick()
			state = State.DONE
		"GOTO":
			_jump(a[0])
		"PROGRAM":
			_restore_pick()
			program = _value(a[0])
			state = State.PROGRAM
		"LOAD_CHAR":
			var lc := _value(a[0])
			if lc & 0x80 and _dismiss and selected_member() != null and print_chars > 0 and running_entry != 2 \
					and text.strip_edges() != "":
				# Chat 113 (DOSBox, 8:13's exit with PRINCESS FATIMA): the original types its text before the next
				# instruction runs, so a member dismissed after it stays in the party list while it types (her
				# farewell, then she leaves). Ours dropped her at once. Wait the typing time, then run it again.
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
			_load_char(lc)
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
			# Chat 62, GAME.OVR 0x3949: the loop's stop flag ([bp-8]) is never cleared before it, so it
			# holds what the handler before left in that stack slot. After an ON_GOTO / ON_GOSUB (Pool's
			# only SPELL, 3:14's cabinets: CAST KNOCK) that is the high byte of a jump target, never 0: the
			# loop doesn't run and SPELL answers place 1, member 0, so the first member "casts Knock"
			# whether anyone has it or not, and nobody's Knock is spent (DOSBox, three parties). With the
			# flag clear (ours assumes so after any other op: not seen) the loop reads only the first
			# member's record bytes 0x18..0x69 and counts one past him.
			var id := _value(a[0])
			var place := 1
			var who := 0
			if not (prev_op in ["ON_GOTO", "ON_GOSUB"]) and not party.is_empty():
				var d: PackedByteArray = (party[0] as PartyMember).to_record()
				place = 255
				for p in range(1, 0x53):
					if 0x17 + p < d.size() and d[0x17 + p] == id:
						place = p
						break
				who = 1
			_write(a[1], place)
			_write(a[2], who)
		"FIND_ITEM":
			# Sets the comparison: equal if anyone carries an item of that type.
			var kind := _value(a[0])
			compare = 1
			compare_eq_only = true    # GAME.OVR 0x33B0: EQ or NE only
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
			compare_eq_only = false
		"PARTY_CHECK":
			_party_check(a)
		"NPC_ADD":
			if print_chars > 0 and running_entry != 2 and text.strip_edges() != "":
				# Chat 113 (DOSBox, 4:2's SKULLCRUSHER): the original types the text before NPC_ADD runs, so the
				# member joins the party list once it has typed (with the press after it); ours showed him with
				# the text's first character. Wait the typing time, then run it again (as LOAD_CHAR, NEW_ECL).
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
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
					# A place line a DAMAGE blanked stays blank on the new square (chat 115, DOSBox: 5:5's hedge, check
					# 121's keys: the view at 11,5, no place line until the party turns).
					if not place_blank.is_empty():
						place_blank = [read_byte(PARTY_X) & 15, read_byte(PARTY_Y) & 15, d]
					# ... and reads the new square's info byte and wall ahead on the map up
					# (GAME.OVR 0x8F1F, 0x8F33; chat 61).
					if wall_info.is_valid() and not on_overland:
						var nx := read_byte(PARTY_X) & 15
						var ny := read_byte(PARTY_Y) & 15
						if square_info.is_valid():
							write_byte(SQUARE_INFO, int(square_info.call(nx, ny)))
						write_byte(WALL_AHEAD, int(wall_info.call(nx, ny, d)))
				0xC018 when (not on_overland or running_entry == 4) and wall_info.is_valid():
					# In a 3D area (DS 0x49FA = 1) the original's 0xC018 reads the wall ahead
					# again (GAME.OVR 0x3AFA-0x3B12; chat 61); nothing else. An arrival runs
					# the new block's init with 0x49FA = 1 whatever the area (GAME.OVR 0x3F2E;
					# the view's kind is set after it, 0x3F4C-0x3F94), so a band's or the
					# wilderness's init reads it too: on the 3D map still in memory, at the
					# square and facing last written (chat 72, DOSBox: 1:18 0,4 W off the edge,
					# the wilderness, into 8:27's band: 1, 1:18's wall at 15,4 E; p22c2).
					write_byte(WALL_AHEAD, int(wall_info.call(read_byte(PARTY_X) & 15,
						read_byte(PARTY_Y) & 15, read_byte(PARTY_DIR) & 3)))
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
					if print_chars > 0 and running_entry != 2 and text.strip_edges() != "":
						# The text before it types first, over the old view (main chat 109, DOSBox: 1:18's FLEE, THE
						# PARTY RUNS AND ESCAPES. typed in 1.0 s beside the orc at 14,5, then 9,4 W with the text
						# still up; ours moved at once). As at COMBAT and NEW_ECL: wait, then run the CALL again. The
						# view and the place line stay where they were until it runs (redraw_pending: 14,5 S while it types).
						redraw_pending = true
						pc = _at
						delay_chars = print_chars
						print_chars = 0
						typing_wait = true
						state = State.WAIT
						return
					# Redraws the view after the script moved the party, and with it the new
					# square's info byte (0xC04F), which the step script then reads for its
					# event: the Slums' booth (event 19) puts the party out at 14,12 and runs
					# the step script again, which must find 14,12's event, not the booth's
					# (ours looped there; the original doesn't).
					if square_info.is_valid():
						write_byte(SQUARE_INFO, int(square_info.call(read_byte(PARTY_X) & 15, read_byte(PARTY_Y) & 15)))
					# ... and the place line as 0x49FB is now: a script that sets it after this call (1:18's FLEE,
					# 0x9E62) still shows the square until the party turns or steps (main chat 109, DOSBox: 9,4 W
					# 10:56, then S 10:56 at the first turn; ours hid it at once). See main's _place_line.
					view_redrawn = true
					# The original's handler (GAME.OVR 0x3A3F) redraws only with a redraw flag set (DS:0x84E0/E3/E5/E6/E8);
					# a step clears 0x84E0 after its own redraw, before the square's script (0x421E), so the step script's
					# CALL leaves a blanked place line blank (chat 115, DOSBox: 5:5's hedge, check 121's keys).
					if not step_fresh:
						place_blank = []
					place_drawn = {"hide": read_byte(0x49FB), "at": [read_byte(PARTY_X) & 15, read_byte(PARTY_Y) & 15,
						read_byte(PARTY_DIR) & 3]}
					# The redraw also wipes an approaching figure: City Hall's guard (3:8 0xB3D9)
					# walks up, YES to "DO YOU LEAVE?" puts the party outside and calls this;
					# ours kept drawing the guard over the street (Jeremy, 2026-11-13).
					sprite_id = -1
					# ... and a picture: the temple's "THEN YOU MUST LEAVE." (3:0 0xAA3B) puts
					# the party back a square and calls this; the original shows the 3D view
					# (the door), ours kept the priest's portrait (P44, Jeremy 2026-11-14).
					picture = 255
				0x2C4E, 0x2C51, 0xC003, 0xC009:
					# Around the bands' loops that rewrite wilderness tiles (7:26's land recovering
					# after the pyramid, 0xAD66..0xAE89 with 0xC003/0xC009 a row at a time; 8:27's
					# at 0xAB25..0xAB99). The original's CALL handler (GAME.OVR 0x3A36, value -
					# 0x7FFF) acts only on 0x2C90, 0x8000/0x8001, 0xBA03, 0xC01E and 0xC018:
					# these do nothing there (chat 24). Our wilderness view draws those squares
					# from 0x4AB3 itself (OverlandMap.tile). Before, ours printed "[not built
					# yet: call C003 ...]" in the message box after the recovery text.
					pass
				0xBA03:
					pass    # plays sound effect [0x03DE] (8 the Rolf tour's, 10 thunder); silent here
				_:
					_note("call %04X" % int(a[0].value))
		"CLOCK":
			# GAME.OVR 0x3807 (chat 64): the handler reads its operand, then fetches the value of
			# operand number [bp-1], a stack byte it never sets (what the previous handler left,
			# as SPELL's flag, chat 62), and adds that many minutes (0x241A1, unit 1 = 0x49C7).
			# Pool's only CLOCK (7:17 0x9D37, the nomads' escorted walks) always follows a GOSUB,
			# and there the slot read holds 0: no time passes (DOSBox: 13 + 5 steps, the clock
			# cells unchanged; differential check 94). Other cases keep the operand (not seen).
			if prev_op != "GOSUB":
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
			compare_eq_only = false
			if a[0].type == 0x80 or a[1].type == 0x80 or a[0].type == 0x81 or a[1].type == 0x81:
				var s0 := _string(a[0])
				var s1 := _string(a[1])
				compare = 0 if s0 == s1 else (-1 if s0 < s1 else 1)
			else:
				compare = _value(a[0]) - _value(a[1])
		"COMPARE_AND":
			compare = 0 if (_value(a[0]) == _value(a[1]) and _value(a[2]) == _value(a[3])) else 1
			compare_eq_only = true    # GAME.OVR 0x1833: EQ or NE only
		"IF_EQ", "IF_NE", "IF_LT", "IF_GT", "IF_LE", "IF_GE":
			var passed := _test(op)
			if coverage != null:
				coverage.branch(block_key, _at, "T" if passed else "F")
			if not passed:
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
			var r := _value(a[0]) & _value(a[1]) & 0xFF   # a byte (GAME.OVR 0x1B6B)
			_write(a[2], r)
			# GAME.OVR 0x1B84: the flags compare 0 with the result (0x8DBE), so IF_GT is never true and IF_LT
			# is "not 0" (chat 62: 3:14's rugs test bit 4 with IF_GT; the original offers them again and again).
			compare = -r
			compare_eq_only = false
		"OR":
			var r := (_value(a[0]) | _value(a[1])) & 0xFF
			_write(a[2], r)
			compare = -r
			compare_eq_only = false
		"RANDOM":
			# GAME.OVR 0xF7A: the top is a byte, raised by one unless it is 255, then Random(n): 0..top, but
			# 0..254 for a top of 255 (3:0's tavern: RANDOM 255; ours rolled 0..255; chat 62).
			var top := _value(a[0]) & 0xFF
			_write(a[1], _script_roll(top if top < 255 else 254))
		"RANDOM0":
			var top := _value(a[1])
			_write(a[0], _script_roll(top) if top > 0 else top)
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
			# GAME.OVR 0x1BA7: the cell at the address plus a byte offset, whatever the source's type.
			_write(a[2], read_var(int(a[0].value) + (_value(a[1]) & 0xFF)))
		"PRINT":
			_runes_to_box = false
			text += _string(a[0])
			print_chars += _string(a[0]).length()
			text_changed = true
			_note_shown()
		"PRINT_CLEAR":
			if print_chars > 0 and running_entry != 2 and text.strip_edges() != "":
				# The text printed since the script last stopped hasn't been seen: the original types it at game
				# speed x 10 ms a character before this one clears it (1:18 0xA713 "... ONLY A WAND OF FEAR!",
				# then 0xA38A's PRINT_CLEAR: up 2.2 s at speed 4 in DOSBox; ours never showed it). Wait for that,
				# then run this PRINT_CLEAR again (main chat 107).
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
			_runes_to_box = false
			text = _string(a[0])
			white_from = -1
			print_chars += _string(a[0]).length()
			text_changed = true
			_note_shown()
		"PRINT_RETURN":
			if _runes_to_box and runes_shown:
				rune_lines.append("")
			else:
				text += "\n"
				text_changed = true
		"CLEAR_BOX":
			_runes_to_box = true
		"SPRITE_START":
			if _wait_typing():
				return
			# A figure walks up: sprite id, starting distance, the portrait it ends on.
			sprite_id = _value(a[0])
			encounter_max = _value(a[1])
			encounter_advances = 0
			write_byte(APPROACH_MAX, encounter_max)
			write_byte(APPROACH_DISTANCE, mini(int(open_ahead.call()) if open_ahead.is_valid() else 2, encounter_max))
			# GAME.OVR 0x10FA: the figure is drawn at that distance (0x6DC1: the given one, nearer with a wall
			# in the way), and SPRITE_ADVANCE counts it down (0x155D); ours drew it at the given one, so with a
			# wall one square nearer it took one ADVANCE more to become the picture (chat 63).
			sprite_distance = read_byte(APPROACH_DISTANCE)
			sprite_picture = _value(a[2])
			sprite_head = read_byte(PICTURE_HEAD)
			sprite_hidden = picture_up and sprite_distance > 0
			# A figure that starts at distance 0 is the picture at once: START (GAME.OVR 0x1188) and ADVANCE
			# (0x158C) draw through the same routine with the distance, and at 0 it draws the picture (P102,
			# main chat 107, DOSBox: 2:15's mad man, START 15, 0, 25, shows picture 25 with his text; ours drew
			# figure 15's nearest frame until a DELAY ended, so IGNORE flashed the picture up).
			if sprite_distance == 0:
				_arrived()
		"SPRITE_ADVANCE":
			if _wait_typing():
				return
			encounter_advances += 1
			if read_byte(APPROACH_DISTANCE) > 0:
				write_byte(APPROACH_DISTANCE, read_byte(APPROACH_DISTANCE) - 1)
			sprite_distance = read_byte(APPROACH_DISTANCE)
			sprite_hidden = picture_up and sprite_distance > 0
			# Reaching the party it becomes their picture at once (chat 40, DOSBox: the Slums'
			# orcs, 2:20 0x9E22 START at 1, ADVANCE, PRINT: the orc's picture with the text and
			# under A BATTLE BEGINS...; ours drew the nearest figure frame, then the corridor).
			if sprite_distance == 0:
				_arrived()
		"SPRITE_OFF":
			if _wait_typing():
				return
			sprite_id = -1
		"CLEAR_MON":
			# GAME.OVR 0x1FA3: the creature count (0x4435) back to 0, the coin pile (0x67F4) and the item
			# pile (0x6810) emptied: a TREASURE before CLEAR_MON is gone (no Pool script has one; chat 63).
			sprite_id = -1
			monsters = []
			monster_teams = []
			monster_morale = []
			monsters_loaded = 0
			treasure = []
			treasure_items = []
			PartyMember.colours_drawn.clear()
		"DELAY":
			state = State.WAIT
			delay_chars = print_chars
			print_chars = 0
		"PICTURE":
			if print_chars > 0 and running_entry != 2 and text.strip_edges() != "":
				# Chat 113 (DOSBox, 2:20's patrol, PAY: THEY PAW THROUGH YOUR COINS AND LEAVE. types over the kobold,
				# then PICTURE 255 brings the view back with the text up): the old picture stays while the text types.
				# Ours changed it with the text's first character. Wait the typing time, then run it again.
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
			picture = _value(a[0])
			picture_head = read_byte(PICTURE_HEAD)
			picture_up = picture != 255
			if picture == 255:
				write_byte(PICTURE_HEAD, 255)
		"MENU_HORIZONTAL":
			var items := []
			for i in range(2, a.size()):
				items.append(_string(a[i]))
			# GAME.OVR 0x1E5A: a menu of one choice reading exactly this is shown as the
			# game's own prompt (the other press-return wordings stay as the script has them).
			if items.size() == 1 and items[0] == "PRESS <RETURN> OR BUTTON TO CONTINUE":
				items[0] = PRESS_TO_CONTINUE
			_pause_for_menu(a[0], items)
		"MENU_VERTICAL":
			var items := []
			for i in range(3, a.size()):
				items.append(_string(a[i]))
			var left := row24_left
			_pause_for_menu(a[0], items)
			row24_left = left if left != WALK_MENU_LEFT else ""   # the walking menu under one: not seen
			menu_vertical = true
			menu_question = _string(a[1])
		"ON_GOTO", "ON_GOSUB":
			var index := _value(a[0])
			var inside := index >= 0 and index < _value(a[1]) and index + 2 < a.size()
			if coverage != null:
				coverage.branch(block_key, _at, str(index) if inside else "out")
			if inside:
				if op == "ON_GOSUB":
					stack.append(pc)
				_jump(a[index + 2])
		"NEW_ECL":
			if print_chars > 0 and running_entry != 2 and text.strip_edges() != "":
				# As at COMBAT (main chat 108): the original types the text printed since the script last stopped
				# before the next instruction runs (START.EXE 0x7782), so it is up for its typing time before the
				# new block loads and its init prints over it (main chat 109: 5:5's YOU GO UPSTAIRS. before NEW_ECL
				# 7, 6:28's YOU ESCAPE FROM THE OUTPOST., 8:13's princess; six sites). Wait, then run it again.
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
			place_blank = []      # once the text has typed (see COMBAT's)
			row24_left = ""
			new_ecl = _value(a[0])
			state = State.NEW_ECL
			# Combat Chat 28, GAME.OVR 0x404E: entering the new block clears the script-pick flag (0x4430), so
			# a LOAD_CHAR before NEW_ECL is never undone: the member it left stays selected (8:13's DO YOU
			# WANT TO LEAVE looks for PRINCESS FATIMA with LOAD_CHAR 0..7 and leaves the last member lit; the
			# original's camp at 8:27 opens on DORN, seen in DOSBox from p22c3's s16c).
			_script_pick = false
		"LOAD_AREA_MAP":
			area_map = [_value(a[0]), _value(a[1]), _value(a[2])]
			# The original keeps the loaded map's id at 0x49C5 (lab, chat 10: save F in New
			# Phlan has 0, save J from the Slums 20); scripts test it (the Wealthy Area's
			# 31 is the Temple of Bane's map, 1:24 0x993D, 0x99C7).
			# 4,4,0 / 5,5,0 / 6,6,0: the wilderness, one of its three bands; a map of
			# its own (mode 0 or 2) means a 3D area. The wilderness leaves 0x49C5 as it was
			# (lab, chat 20: into 6:25 from the Slums the original kept 20; ours wrote 4).
			var band: bool = area_map[0] == area_map[1] and area_map[0] >= 4 and area_map[0] <= 6 and area_map[2] == 0
			if area_map[0] < 127 and not band:
				write_byte(AREA_MAP_ID, area_map[0])
			if band:
				overland_band = area_map[0] - 4
				on_overland = true
			elif area_map[0] < 127 and area_map[1] in [0, 2]:
				on_overland = false
			# Mode 16 turns the view into a page for PRINT_RUNES; mode 2 brings the view back.
			if area_map[1] == 2 and runes_shown:
				runes_closing = true
		"LOAD_AREA_DECO":
			area_deco = [_value(a[0]), _value(a[1]), _value(a[2])]
		"SURPRISE":
			# As the original: a d6 for each side against (d + 2 - a) and (b + 2 - c); the
			# monsters' surprise wins when both come up (names from ssi-engine: the result
			# is COMBAT_IS_AMBUSH; rules as documented by Pilgrim's reconstruction).
			var party_roll := _ri(1, 6)
			var mon_roll := _ri(1, 6)
			var result := 0
			if party_roll <= _value(a[3]) + 2 - _value(a[0]):
				result = 1
			if mon_roll <= _value(a[1]) + 2 - _value(a[2]):
				result = 2
			write_byte(AMBUSH, result)
		"COMBAT":
			if print_chars > 0 and running_entry != 2 and text.strip_edges() != "" \
					and (read_byte(TEMPLE_FLAG) == 1 or read_byte(SHOP_FLAG) == 1 \
					or not monsters.is_empty() or not treasure.is_empty() or duel == 1):
				# The original types a script's text before the next instruction runs (START.EXE 0x7782, game
				# speed x 10 ms a character), so a text PRINTed just before a fight, a treasure, a shop or a
				# temple is up while it types; ours went to that screen at once and the text was never seen
				# (4:10 0xACBC, the knight's gifts: 4.5 s at speed 4 in DOSBox, then THE PARTY HAS FOUND
				# TREASURE!). Wait as at a PRINT_CLEAR (main chat 108), then run this COMBAT again.
				pc = _at
				delay_chars = print_chars
				print_chars = 0
				typing_wait = true
				state = State.WAIT
				return
			# The fight brings the place line back, not the COMBAT before its text has typed (chat 116, DOSBox
			# 8:13's truce kobold, REFUSE: the roof's DAMAGE, then BEFORE YOU RECOVER, KOBOLDS ARRIVE. types with
			# the place line still blank; ours showed it again during the text).
			place_blank = []
			row24_left = ""       # the fight's screen redraws row 24
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
				# Chat 17: a fight starts with 0x6E33 ("an ally was attacked") clear (GAME.OVR 0xE492).
				write_byte(ALLY_ATTACKED, 0)
			else:
				_note("combat")
				write_byte(COMBAT_RESULT, 0)
				_clear_fight_mods()
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
			# A new approach (GAME.OVR 0x2C80-0x2D6C: +0x580 = argument 2, +0x582 = the open
			# squares ahead capped by it): an earlier SPRITE_START's advances don't count (Combat
			# Chat 20, p13b5: 2:20's kobolds after the goblins' SPRITE_ADVANCE stood 1 square too near).
			encounter_advances = 0
			encounter_distance = mini(ahead, encounter_max)
			write_byte(APPROACH_MAX, encounter_max)
			write_byte(APPROACH_DISTANCE, encounter_distance)
			# The monsters' figure stands at that distance (it becomes their picture
			# when they reach the party).
			sprite_id = _value(a[0])
			sprite_picture = _value(a[2])
			sprite_head = read_byte(PICTURE_HEAD)
			sprite_distance = encounter_distance
			sprite_hidden = picture_up and sprite_distance > 0
			_arrived()
			_show_encounter_menu()
		"TREASURE":
			treasure = []
			for i in a.size():
				treasure.append(_value(a[i]))
			# GAME.OVR 0x26F5: a list of 128+ is made at once from the dice (list - 128 items).
			treasure_items = []
			if treasure.size() >= 8 and treasure[7] >= 128 and treasure[7] != 255 and treasure_maker != null and treasure_maker.ok:
				treasure_items = treasure_maker.make(treasure[7] - 128, _ri)

		"LOAD_MON":
			# GAME.OVR 0x1196: at most 63 creatures since the last CLEAR_MON (0x4435), a count of 0 loads 1;
			# with 63 loaded already it does nothing (Pool's fights stay under 57: 7:17 loads 56 - n).
			if monsters_loaded < 63:
				var n := mini(maxi(_value(a[1]), 1), 63 - monsters_loaded)
				monsters_loaded += n
				monsters.append([_value(a[0]), n, _value(a[2])])
				PartyMember.draw_colours(_value(a[0]))   # the record loads now in the original
				for i in n:
					if monster_teams.size() < 63:
						monster_teams.append(0)
						monster_morale.append(-1)
		"DAMAGE":
			# Chat 114: the hit lines and the HP column change once the text before has typed (DOSBox: 8:13's
			# rocks, KOBOLDS APPEAR AND BOMBARD YOU WITH ROCKS. types with the HP as they were).
			if _wait_typing():
				return
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
			row24_left = ""
			input_max = maxi(_value(a[0]), 1)
			input_numeric = op == "INPUT_NUMBER"
			_input_dest = a[1]
			state = State.INPUT
		"PRINT_RUNES":
			# Rune text where the cursor is (see RUNE_BASE): two codes to a rune, not typed (no print_chars).
			var runes := ""
			for ch in _string(a[0]):
				runes += char(RUNE_BASE + ch.unicode_at(0))
			if _runes_to_box:
				if not runes_shown:
					rune_lines = [""]
					runes_shown = true
					view_blank = false
				rune_lines[-1] += runes
			else:
				text += runes
				text_changed = true
		_:
			_note("unhandled " + op)


func _test(op: String) -> bool:
	match op:
		"IF_EQ": return compare == 0
		"IF_NE": return compare != 0
		"IF_LT": return compare < 0 and not compare_eq_only
		"IF_GT": return compare > 0 and not compare_eq_only
		"IF_LE": return compare <= 0 and not compare_eq_only
		"IF_GE": return compare >= 0 and not compare_eq_only
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
	var last := "ADVANCE" if advance_offered() else "PARLAY"
	_pause_for_menu({}, ["COMBAT", "WAIT", "FLEE", last])
	_menu_kind = "encounter"


## The party's slowest and fastest (GAME.OVR 0x9484, called at ENCOUNTER_MENU's start): each figure's
## movement (+0x11C), doubled as a byte under Haste (effect 39), else halved under Slow (effect 42).
func _party_moves() -> Vector2i:
	var lo := 255
	var hi := 0
	for m in party:
		var mv := (m as PartyMember).movement
		if (m as PartyMember).has_affect(39):
			mv = (mv << 1) & 0xFF
		elif (m as PartyMember).has_affect(42):
			mv >>= 1
		lo = mini(lo, mv)
		hi = maxi(hi, mv)
	return Vector2i(lo, hi)


func _close_in() -> bool:
	if encounter_distance > 0:
		encounter_distance -= 1
		encounter_advances += 1
		write_byte(APPROACH_DISTANCE, encounter_distance)
		sprite_distance = encounter_distance
		sprite_hidden = picture_up and sprite_distance > 0
		_arrived()
		return true
	return false


## Monsters at distance 0 show their picture, not the nearest figure frame: P31, Jeremy's
## capture of the original (New Phlan 14,5 S: "YOU ARE BEING APPROACHED BY SOME ANGRY
## GOBLINS." with no ADVANCE, a wall ahead, the goblin's picture in the view). As an
## approaching figure's arrival at the end of a DELAY (main), and a SPRITE_ADVANCE to 0 (chat 40).
func _arrived() -> void:
	if sprite_id >= 0 and encounter_distance == 0:
		picture = sprite_picture
		picture_head = sprite_head
		sprite_id = -1
		picture_up = true


## Resolves a choice; returns false when the menu should be shown again.
## ADVANCE is offered only at a distance and while 0x49E6 is set (GAME.OVR 0x2EC1-0x2EEF: the
## wilderness bands clear it while their wilderness view is up, and their menus show PARLAY at any
## distance; picked there, PARLAY closes in as ADVANCE would, 0x306C, until the distance is 0).
func advance_offered() -> bool:
	return encounter_distance > 0 and read_byte(VIEW_3D) != 0


func _encounter_choice(choice: int) -> bool:
	if choice == 3 and not advance_offered():
		choice = 4       # PARLAY sits where ADVANCE would be (GAME.OVR 0x2F28-0x2F46)
	var reaction: int = _enc.reactions[choice] if choice < _enc.reactions.size() else 0
	var moves := _party_moves()
	var outcome := -1
	var both_wait := false
	match reaction:
		0:
			outcome = 2 if choice == 2 and moves.x >= int(_enc.flee_need) else 1
		1:
			match choice:
				0: outcome = 1
				1: both_wait = true
				2: outcome = 2
				3:
					if not _close_in():
						both_wait = true
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
						both_wait = true
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
		if both_wait:
			_say("BOTH SIDES WAIT.")
			# The original prints BOTH SIDES WAIT. (GAME.OVR 0x2D8D's loop), then the menu's text again at
			# once: at speed 4 it is up for about 0.2 s while it types (DOSBox, P106). Ours prints at once, so
			# it holds the line for one script delay (as a DELAY) before the menu comes back.
			_enc_waited = true
			state = State.WAIT
			return false
		_show_encounter_menu()
		return false
	_write(_enc.dest, outcome)
	_enc = {}
	return true


## Records the PRINT running now if main watches its text (watch_texts).
func _note_shown() -> void:
	if watch_texts.is_empty():
		return
	var key := "%s %04X" % [block_key, _at + EclScript.BASE]
	if watch_texts.has(key):
		shown_texts[key] = true


func _say(line: String) -> void:
	text = line
	text_changed = true


## PARTY_STRENGTH as the original works it out: for each character, (cleric levels x 4 +
## HP + 5 per point of AC below 0 + 5 per point of THAC0 below 21 + magic-user levels x 8)
## / 10, added up.
## GAME.OVR 0x200C: per member (current HP + 5 x AC below 0 + 5 x (21 - THAC0) + 8 x MU level + 4 x cleric
## level) / 10, from the record's cached AC and THAC0 (+0x111, +0x110), every figure in the list; the sum is
## a byte, so it wraps past 255 (chat 62; ours capped it: no Pool party comes near).
func party_strength() -> int:
	var total := 0
	for p in party:
		var m: PartyMember = p
		var cleric: int = m.raw[0x96] if m.raw.size() > 0x9B else 0
		var mage: int = m.raw[0x9B] if m.raw.size() > 0x9B else 0
		var ac_bonus := maxi(m.cached_ac_60() - 60, 0)          # the record's cache (main chat 82)
		var hit_bonus := maxi(m.cached_thac0_60() - 39, 0)
		total += (cleric * 4 + m.hp + ac_bonus * 5 + hit_bonus * 5 + mage * 8) / 10
	return total & 0xFF


func _pause_for_menu(dest: Dictionary, items: Array) -> void:
	# One item is a "press to continue" prompt; its choice is not stored.
	_menu_dest = dest
	_menu_kind = ""
	row24_left = ""
	menu_vertical = false
	menu_question = ""
	_menu_at = _at
	menu = items
	state = State.MENU


## Dev (chat 18, coverage runs): called at a script's RANDOM with (instruction offset, top); a
## value 0..top is used as the roll, -1 rolls as usual.
var dev_dice_hook := Callable()


## A script's RANDOM: 0..top, or what a coverage run's dice hook gives.
func _script_roll(top: int) -> int:
	if dev_dice_hook.is_valid():
		var v: int = dev_dice_hook.call(_at, top)
		if v >= 0 and v <= top:
			return v
	return _ri(0, top)


## The script's dice: Godot's generator, or the original's own in a lab comparison (TpDice).
func _ri(lo: int, hi: int) -> int:
	return TpDice.between(lo, hi, "ecl") if TpDice.on else _rng.randi_range(lo, hi)

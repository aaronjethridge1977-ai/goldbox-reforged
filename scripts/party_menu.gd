class_name PartyMenu
extends Control
## The party menu the scripts open with PROGRAM 0: the training halls (each room writes its
## class bits to 0x6DA8 first) and the start of the game. Drawn as the original draws it
## (Jeremy, 2026-11-12: every screen matches the original).
##
## From the lab (chat 10, New Phlan's fighters' hall, save H): a page framed in rope (rows 0
## and 23), the party at column 1 ("NAME", "AC" at 33, "HP" at 37; the chosen member white,
## the others cyan; Home/End choose), the functions from row 12 at column 2 with their first
## letters white, "CHOOSE A FUNCTION" (magenta) on row 24 and no item lit:
## CREATE NEW CHARACTER, DROP CHARACTER, MODIFY CHARACTER, TRAIN CHARACTER (in a hall),
## VIEW CHARACTER, ADD CHARACTER TO PARTY, REMOVE CHARACTER FROM PARTY, SAVE CURRENT GAME,
## BEGIN ADVENTURING, EXIT TO DOS.
## - TRAIN: "<NAME>" (cyan) "WILL BECOME:" at row 4 column 4, "A LEVEL n <CLASS>" at row 5
##   column 10, "DO YOU WISH TO TRAIN?" (magenta) YES NO with NO lit; YES: "CONGRATULATIONS..."
##   (green, row 24) for a moment, then the menu. One who can't train (too little experience
##   or money): nothing happens. Ours (P57, an exception, Jeremy 2026-11-14) says why on row 24
##   for a moment, white, in place of CHOOSE A FUNCTION. Then a magic-user who gained a level
##   picks a new spell.
## - DROP: "DROP <NAME> FOREVER?" (yellow) YES NO, NO lit; YES: "ARE YOU SURE?" YES NO, NO lit. REMOVE: at once,
##   no question. After either the member before the one gone is lit (chat 88, DOSBox).
## - ADD: the waiting characters listed from row 2 at column 1, "ADD A CHARACTER:" ADD EXIT.
## - SAVE: "SAVE WHICH GAME:" A to J. EXIT TO DOS: "QUIT TO DOS" (yellow) YES NO, NO lit.
## - MODIFY for one who has adventured: nothing happens.
## Not yet seen in the original: the spell-learning page (drawn as the camp's spell lists).
## Removed characters wait in the roster (saved with the game) and ADD brings them back;
## DROP removes one for good. CREATE runs CharacterCreator; MODIFY runs CharacterModify for a
## character with no experience yet.

signal closed
signal save_requested(letter: String)
## LOAD SAVED GAME with an empty party (main chat 103): the game loads the slot and closes the hall.
signal load_requested(letter: String)
## Set by the game while handling save_requested when the save couldn't be written.
var save_failed := false

const MAGENTA := 13
const PROMPT := 14
const YES_NO := ["YES", "NO"]
const LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]

var party: Array[PartyMember] = []
var roster: Array[PartyMember] = []   # characters removed from the party
var hall_mask := 0                     # 0x6DA8: the classes this hall trains (0 = no training)
var tables: ClassTables
var spells: SpellTable
var types: ItemTypes
var game_path := ""
var _creator: CharacterCreator
var _modifier: CharacterModify

var _sel := 0
var _mode := "menu"   # menu, confirm_train, congrats, confirm_drop, confirm_drop2, quit, save, learn, add
## The lit word: the highlight every horizontal menu shares (GAME.OVR 0x2CC8C's DS:0x6B2B, EclVM.menu_hl; main chat
## 122, Combat Chat 55): what a menu here leaves lit, the next menu anywhere lights, and the other way round.
var _pick: int:
	get:
		return EclVM.menu_hl
	set(v):
		EclVM.menu_hl = v
var _plan: Array[int] = []
var _cursor := 0
# ADD's list: which waiting characters were added while it is open (shown "* NAME"; main chat 102).
var _added: Array[bool] = []
var _list: Array[int] = []
var _scr: GameScreen
var _note := Label.new()               # what happened, for the bot's log
var _row24 := ""                       # P57: training's refusal, on row 24 for a moment
var _sheet: CharacterSheet
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_note.visible = false
	add_child(_note)


func open(members: Array[PartyMember], mask: int) -> void:
	party = members
	hall_mask = mask
	_sel = clampi(_sel, 0, maxi(party.size() - 1, 0))
	_rng.randomize()
	if _scr == null:
		_build()
	_note.text = ""
	visible = true
	_show_menu()


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	ShopScreen._fill(bg, 0)
	add_child(bg)
	_scr = GameScreen.new()
	add_child(_scr)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	_sheet.visibility_changed.connect(func() -> void:
		if not _sheet.visible and visible:
			_refresh())
	add_child(_sheet)


func _items() -> Array:
	# An empty party (every member removed, or PARTY CREATION's start): the original's hall offers only these four
	# (main chat 103, DOSBox at 3:11 after REMOVE x6; check 384).
	if party.is_empty():
		return ["CREATE NEW CHARACTER", "ADD CHARACTER TO PARTY", "LOAD SAVED GAME", "EXIT TO DOS"]
	var out := ["CREATE NEW CHARACTER", "DROP CHARACTER", "MODIFY CHARACTER"]
	if hall_mask > 0:
		out.append("TRAIN CHARACTER")
	out.append_array(["VIEW CHARACTER", "ADD CHARACTER TO PARTY", "REMOVE CHARACTER FROM PARTY",
		"SAVE CURRENT GAME", "BEGIN ADVENTURING", "EXIT TO DOS"])
	return out


# --- Drawing ------------------------------------------------------------------------------

func _frame() -> void:
	_scr.clear()
	for c in 40:
		_scr.tile(c, 0, 22)
		_scr.tile(c, 23, 22)
	for r in range(1, 23):
		_scr.tile(0, r, 21)
		_scr.tile(39, r, 21)
	for r in [0, 23]:
		_scr.tile(0, r, 20)
		_scr.tile(39, r, 20)


func _draw_party() -> void:
	if party.is_empty():          # the original draws no heading over an empty party (main chat 103)
		return
	_scr.text(1, 2, "NAME", GameScreen.WHITE)
	_scr.text(33, 2, "AC", GameScreen.WHITE)
	_scr.text(37, 2, "HP", GameScreen.WHITE)
	for i in mini(party.size(), 8):
		var m: PartyMember = party[i]
		var down := m.status >= PartyMember.STATUS_UNCONSCIOUS or m.hp <= 0
		_scr.text(1, 4 + i, m.name.left(15), GameScreen.WHITE if i == _sel else (GameScreen.RED if down else GameScreen.CYAN))
		var ac := str(m.ac)
		_scr.text(35 - ac.length(), 4 + i, ac, GameScreen.GREEN)
		var hp := str(m.hp)
		_scr.text(39 - hp.length(), 4 + i, hp, GameScreen.GREEN if m.hp >= m.hp_max else GameScreen.YELLOW)


func _refresh() -> void:
	if _scr == null or not visible:
		return
	_frame()
	match _mode:
		"confirm_train", "congrats":
			var m := _who()
			_scr.text(4, 4, m.name, GameScreen.CYAN)
			_scr.text(5 + m.name.length(), 4, "WILL BECOME:", GameScreen.GREEN)
			for i in _plan.size():
				var c := _plan[i]
				var line := ("A LEVEL %d %s" if i == 0 else "AND A LEVEL %d %s") % [m.level_in(c) + (0 if _mode == "congrats" else 1), ClassTables.CLASS_NAMES[c]]
				_scr.text(10 if i == 0 else 6, 5 + i, line, GameScreen.GREEN)
			if _mode == "confirm_train":
				_scr.text(0, 24, "DO YOU WISH TO TRAIN?", MAGENTA)
				_scr.menu_line(24, YES_NO, 22, EclVM.menu_lit(YES_NO.size()))
			else:
				_scr.text(0, 24, "CONGRATULATIONS...", GameScreen.GREEN)
		"add":
			for i in roster.size():
				var shown: String = ("* " if i < _added.size() and _added[i] else "") + roster[i].name
				_scr.text(1, 2 + i, shown, GameScreen.WHITE if i == _cursor else GameScreen.CYAN)
				_scr.list_line(2 + i, i)
			_scr.list_chosen(_cursor)
			_scr.text(0, 24, "ADD A CHARACTER:", MAGENTA)
			_scr.menu_line(24, ["ADD", "EXIT"], 17, _pick)
		"learn":
			# The original (Player 3's still after ELWEN trained): "<NAME>'S" cyan and " SPELLS TO
			# CHOOSE FROM" green on row 1, rope on row 2; from row 5 a level heading (magenta,
			# column 1) wherever the level changes and the spells at column 3, green, the lit one
			# white (the last at first); row 24 "CHOOSE SPELL:" LEARN.
			var who := _who().name + "'S"
			_scr.text(1, 1, who, GameScreen.CYAN)
			_scr.text(2 + who.length(), 1, "SPELLS TO CHOOSE FROM", GameScreen.GREEN)
			for c in 40:
				_scr.tile(c, 2, 22)
			var row := 5
			var last_level := 0
			for i in _list.size():
				var lv := spells.level(_list[i])
				if lv != last_level:
					last_level = lv
					_scr.text(1, row, CharacterSheet.LEVEL_WORDS[clampi(lv - 1, 0, CharacterSheet.LEVEL_WORDS.size() - 1)], MAGENTA)
					row += 1
				_scr.text(3, row, spells.names[_list[i]].to_upper(), GameScreen.WHITE if i == _cursor else GameScreen.GREEN)
				_scr.list_line(row, i)
				row += 1
			_scr.list_chosen(_cursor)
			_scr.text(0, 24, "CHOOSE SPELL:", MAGENTA)
			_scr.menu_line(24, ["LEARN"], 14, 0)
		_:
			_draw_party()
			var items := _items()
			for i in items.size():
				_scr.menu_line(12 + i, [items[i]], 2, -1)
			match _mode:
				"menu":
					if _row24 != "":
						_scr.text(0, 24, _row24, GameScreen.WHITE)
					else:
						_scr.text(0, 24, "CHOOSE A FUNCTION", MAGENTA)
				"confirm_drop":
					var q := "DROP %s FOREVER?" % _who().name
					_scr.text(0, 24, q, PROMPT)
					_scr.menu_line(24, YES_NO, q.length() + 1, EclVM.menu_lit(YES_NO.size()))
				"confirm_drop2":
					_scr.text(0, 24, "ARE YOU SURE?", PROMPT)
					_scr.menu_line(24, YES_NO, 14, EclVM.menu_lit(YES_NO.size()))
				"quit":
					_scr.text(0, 24, "QUIT TO DOS", PROMPT)
					_scr.menu_line(24, YES_NO, 12, EclVM.menu_lit(YES_NO.size()))
				"save":
					_scr.text(0, 24, "SAVE WHICH GAME:", MAGENTA)
					_scr.menu_line(24, LETTERS, 17, -1)
				"load":
					_scr.text(0, 24, "LOAD WHICH GAME:", MAGENTA)
					_scr.menu_line(24, LETTERS, 17, -1)
	_scr.update()


func _show_menu() -> void:
	_mode = "menu"
	_refresh()


## QoL 5 (Q10): SAVE CURRENT GAME opens the saved games' list in place of the letter prompt.
var _save_list: SaveListScreen


func _open_save_list() -> void:
	if _save_list == null:
		_save_list = SaveListScreen.new()
		add_child(_save_list)
		_save_list.picked.connect(func(slot: String) -> void:
			save_failed = false
			save_requested.emit(slot)
			_note.text = "COULDN'T SAVE THE GAME." if save_failed else "GAME SAVED."
			_show_menu())
		_save_list.cancelled.connect(_show_menu)
	_save_list.open("save", game_path)


## P57: why training refused, on row 24 for a moment (as the camp's refusals), then the menu.
func _say_24(text: String) -> void:
	_row24 = text
	_refresh()
	await get_tree().create_timer(1.5 * CampScreen.delay_scale()).timeout
	if _row24 == text:
		_row24 = ""
		_refresh()


# --- Actions (the bot calls these too) ----------------------------------------------------

func _create() -> void:
	if _creator == null:
		_creator = CharacterCreator.new()
		_creator.created.connect(_on_created)
		_creator.cancelled.connect(_show_menu)
		add_child(_creator)
	_creator.tables = tables
	_creator.spells = spells
	_creator.types = types
	_creator.open(game_path)


func _modify() -> void:
	if _modifier == null:
		_modifier = CharacterModify.new()
		_modifier.finished.connect(func(_c: bool) -> void: _show_menu())
		add_child(_modifier)
	_modifier.tables = tables
	_modifier.spells = spells
	_modifier.types = types
	var m := _who()
	_modifier.open(game_path, m, CharacterCreator.portrait_for(game_path, maxi(m.raw[0xBB] - 1, 0), maxi(m.raw[0xBC] - 1, 0)))


func _on_created(m: PartyMember) -> void:
	roster.append(m)
	_show_menu()


func _who() -> PartyMember:
	return party[_sel] if _sel < party.size() else null


func _train() -> void:
	var m := _who()
	if m == null or tables == null:
		return
	var plan := m.training_plan(tables, hall_mask)
	if plan.has("error"):
		_note.text = plan.error       # the original says nothing; ours shows it (P57)
		_say_24(plan.error)
		return
	_plan.assign(plan.classes)
	_note.text = ""
	_pick = 1                          # NO lit (lab)
	_mode = "confirm_train"
	_refresh()


func _do_train() -> void:
	var m := _who()
	var learn := m.train(tables, spells, _plan, _rng)
	_note.text = "CONGRATULATIONS..."
	if learn and spells != null:
		_list = m.learnable_spells(spells)
		if not _list.is_empty():
			_cursor = _list.size() - 1      # the original lights the last spell (Player 3)
			_mode = "learn"
			_refresh()
			return
	_mode = "congrats"
	_refresh()
	await get_tree().create_timer(0.6 * CampScreen.delay_scale()).timeout
	if _mode == "congrats":
		_show_menu()


## What the screen shows (for the lab's headless checks).
func screen_text() -> String:
	return "%s | %s" % [_mode, _note.text]


func _pick_member(d: int) -> void:
	if party.is_empty():
		return
	_sel = (_sel + d + party.size()) % party.size()
	_refresh()


# --- Keys ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or not event is InputEventKey or _sheet.visible \
			or (_creator != null and _creator.visible) or (_modifier != null and _modifier.visible):
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode
	var up := key in [KEY_HOME, KEY_KP_7, KEY_UP]
	var down := key in [KEY_END, KEY_KP_1, KEY_DOWN]
	var enter := key in [KEY_ENTER, KEY_KP_ENTER]
	var esc := key == KEY_ESCAPE
	if _row24 != "":                  # any key ends the refusal's moment
		_row24 = ""
		_refresh()
	match _mode:
		"menu":
			# The hall's menu moves the lit member on Home / End and on 7 / 1 (GAME.OVR 0x2CC8C makes the digits the
			# keypad's keys, 0x2CF60); Up / Down, 8 and 2 do nothing (Combat Chat 57, DOSBox at 3:11, check 103's
			# start; main chat 123's request). It wraps both ways.
			var m_up := key in [KEY_HOME, KEY_KP_7, KEY_7]
			if m_up or key in [KEY_END, KEY_KP_1, KEY_1]:
				_pick_member(-1 if m_up else 1)
				return
			for it in _items():
				if String(it).unicode_at(0) == key:
					_function(it)
					return
		"confirm_train", "confirm_drop", "confirm_drop2", "quit":
			# The hall's questions take only Y and N: Enter and Left / Right do nothing, the
			# light stays on NO (main chat 89, DOSBox at 3:11: DO YOU WISH TO TRAIN?, QUIT TO DOS; check 289;
			# Q24 extended, as the temple's).
			var yes := key == KEY_Y
			# Esc does nothing at any of them (main chat 94 and 95, DOSBox at 3:11: DO YOU WISH TO TRAIN?, QUIT TO
			# DOS, DROP <NAME> FOREVER?, ARE YOU SURE?; checks 319, 321).
			var no := key == KEY_N
			if yes:
				match _mode:
					"confirm_train": _do_train()
					"confirm_drop":
						# Chat 88 (DOSBox): YES asks again, ARE YOU SURE? (yellow) YES NO, NO lit.
						_mode = "confirm_drop2"
						_pick = 1
						_refresh()
					"confirm_drop2":
						party.remove_at(_sel)
						# Chat 88 (DOSBox): the member before the dropped one is lit (the first if it was the first).
						_sel = clampi(_sel - 1, 0, maxi(party.size() - 1, 0))
						_show_menu()
					"quit": get_tree().quit()
			elif no:
				_show_menu()
		"load":
			if esc:
				_show_menu()
				return
			for l in LETTERS:
				if String(l).unicode_at(0) == key:
					load_requested.emit(l)
					return
		"save":
			if esc:
				_show_menu()
				return
			for l in LETTERS:
				if String(l).unicode_at(0) == key:
					save_failed = false
					save_requested.emit(l)
					_note.text = "COULDN'T SAVE THE GAME." if save_failed else "GAME SAVED."
					_show_menu()
		"learn":
			if up or down:
				_cursor = (_cursor + (1 if down else -1) + _list.size()) % _list.size()
				_refresh()
			elif enter or key == KEY_L:
				_who().spell_book[_list[_cursor] - 1] = 1
				_note.text = "%s LEARNS %s." % [_who().name, spells.names[_list[_cursor]].to_upper()]
				_show_menu()
		"add":
			if (up or down) and not roster.is_empty():
				_cursor = (_cursor + (1 if down else -1) + roster.size()) % roster.size()
				_refresh()
			elif key == KEY_LEFT or key == KEY_RIGHT or key == KEY_COMMA or key == KEY_PERIOD:
				_pick = 1 - EclVM.menu_lit(2)
				_refresh()
			elif key == KEY_A or (enter and EclVM.menu_lit(2) == 0):
				# Main chat 102 (DOSBox): the list stays open, the added one marked "* NAME" and still lit;
				# ADD on an added one does nothing. Main chat 104 (DOSBox, GAME.OVR 0x1CB26-0x1CBF5; checks 395, 396,
				# 399): a player character joins while fewer than six are in the party, an NPC while fewer than
				# eight in all; the list stays open when no one is left waiting.
				if not roster.is_empty() and not _added[_cursor] and _room_for(roster[_cursor]):
					party.append(roster[_cursor])
					_added[_cursor] = true
					_sel = party.size() - 1      # lab: the one added is chosen
				# Main chat 103 (DOSBox, check 344's own keys): the ADD that fills the party (six) closes it too.
				if _player_characters() >= 6 or party.size() >= 8:
					_close_add()
				else:
					_refresh()
			elif key == KEY_E or esc or (enter and EclVM.menu_lit(2) == 1):
				_close_add()


## The party's player characters (record 0x84 below 0x80; a hired NPC doesn't count: GAME.OVR 0x1CB5C).
func _player_characters() -> int:
	var n := 0
	for m in party:
		if (m as PartyMember).npc < 0x80:
			n += 1
	return n


## ADD's room (GAME.OVR 0x1CB74): a player character while fewer than six, an NPC while fewer than eight in all.
func _room_for(m: PartyMember) -> bool:
	return _player_characters() < 6 if m.npc < 0x80 else party.size() < 8


## Leaves ADD's list: the added ones leave the waiting list (main chat 102).
func _close_add() -> void:
	for i in range(roster.size() - 1, -1, -1):
		if i < _added.size() and _added[i]:
			roster.remove_at(i)
	_added = []
	_show_menu()


func _function(item: String) -> void:
	match item:
		"CREATE NEW CHARACTER":
			if game_path != "":
				_create()
		"DROP CHARACTER":
			# The original drops the last one too (main chat 103, DOSBox at 3:11: REMOVE x5, DROP, YES, YES: empty).
			if not party.is_empty():
				_pick = 1
				_mode = "confirm_drop"
				_refresh()
		"MODIFY CHARACTER":
			if _who() != null and game_path != "" and _who().experience == 0:
				_modify()
		"TRAIN CHARACTER":
			_train()
		"VIEW CHARACTER":
			if _who() != null:
				_sheet.open(party, "PARTY", _sel, false, 0, true)
		"ADD CHARACTER TO PARTY":
			if not roster.is_empty():
				_cursor = 0
				_pick = 0
				_added = []
				_added.resize(roster.size())
				_added.fill(false)
				_mode = "add"
				_refresh()
		"REMOVE CHARACTER FROM PARTY":
			# The original removes the last one too (main chat 103, DOSBox at 3:11: REMOVE x6 empties the party).
			if not party.is_empty():
				roster.append(party[_sel])
				party.remove_at(_sel)
				# Chat 88 (DOSBox): as after DROP, the member before the removed one is lit.
				_sel = clampi(_sel - 1, 0, maxi(party.size() - 1, 0))
				_show_menu()
		"LOAD SAVED GAME":
			_mode = "load"
			_refresh()
		"SAVE CURRENT GAME":
			if SaveListScreen.on() and game_path != "":
				_open_save_list()
			else:
				_mode = "save"
				_refresh()
		"BEGIN ADVENTURING":
			if not party.is_empty():
				visible = false
				closed.emit()
		"EXIT TO DOS":
			_pick = 1
			_mode = "quit"
			_refresh()

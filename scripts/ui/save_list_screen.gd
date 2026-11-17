class_name SaveListScreen
extends Control
## QoL 5 (R2; Jeremy's Q10, 2026-11-16: all three recommendations): the saved games as a list in place of
## the original's letter prompt ("SAVE WHICH GAME:" A-J in camp and the party menu, "LOAD WHICH GAME?" on
## the start menu). A letter still saves or loads its slot at once, as the original's prompt; Up / Down (and
## Home / End) light a slot, and its details show below. NAME gives the lit slot the player's own name
## (kept in ours' companion file: the original never sees it). The layout is main chat 38's mockup, in the
## original's frame and font. Data: SaveSlots (main). SETTINGS: SAVE LIST (on by default); off, the
## original's letter prompt.
##
##   row 1      SAVE A GAME / LOAD A GAME
##   rows 3-13  A-J, then (LOAD only) QUICK: letter, area, square and facing, DAY n HH:MM
##   row 15     the slot's name in yellow (or the game's state: EMPTY, CAN'T BE READ...)
##   row 16     SAVED <the file's date>    MAP (when the automap comes with it)
##   rows 17-22 the party: name, class, HP / max, status
##   row 24     SAVE (or LOAD) NAME EXIT; NAME types the name there

signal picked(slot: String)   # "A".."J", or "QUICK" (LOAD only)
signal cancelled

const SETTINGS_KEY := "savelist"
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const NAME_MAX := 24
const MAGENTA := 13

## The quick save's file (main sets it at start: its _save_path()).
static var quick_path := ""
static var _cached := -1

var game_path := ""
var _mode := "save"           # save or load
var _slots: Array[Dictionary] = []
var _cursor := 0
var _pick := 0
var _typing := false
var _typed := ""
var _flash := ""
var _scr: GameScreen


static func on() -> bool:
	if _cached < 0:
		var cf := ConfigFile.new()
		_cached = 1
		if cf.load(GameData.SETTINGS_PATH) == OK:
			_cached = int(bool(cf.get_value("qol", SETTINGS_KEY, true)))
	return _cached == 1


static func save_on(value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", SETTINGS_KEY, value)
	cf.save(GameData.SETTINGS_PATH)
	_cached = int(value)


func _init() -> void:
	visible = false


## Opens the list: `mode` "save" (camp, party menu) or "load" (start menu). The light starts on `lit`
## when it names a slot, else on the first slot holding a game (save: the first).
func open(mode: String, path: String, lit: String = "") -> void:
	_mode = mode
	game_path = path
	if _scr == null:
		ShopScreen._fill(self, 0)
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_scr = GameScreen.new()
		ShopScreen._fill(_scr, 0)
		add_child(_scr)
	_slots = SaveSlots.list(game_path, quick_path if mode == "load" and quick_path != "" and FileAccess.file_exists(quick_path) else "")
	_cursor = 0
	for i in _slots.size():
		if lit != "" and String(_slots[i].slot) == lit:
			_cursor = i
			break
		if lit == "" and mode == "load" and bool(_slots[i].exists):
			_cursor = i
			break
	_pick = 0
	_typing = false
	_flash = ""
	visible = true
	_draw()


func close() -> void:
	visible = false


func _menu() -> Array:
	return ["SAVE" if _mode == "save" else "LOAD", "NAME", "EXIT"]


func _draw() -> void:
	var g := _scr
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
		g.tile(c, 14, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23), Vector2i(0, 14), Vector2i(39, 14)]:
		g.tile(p.x, p.y, 20)
	g.text(2, 1, "SAVE A GAME" if _mode == "save" else "LOAD A GAME", GameScreen.WHITE)
	for i in _slots.size():
		var e: Dictionary = _slots[i]
		var row := 3 + i
		var lit := i == _cursor
		var col := GameScreen.WHITE if lit else GameScreen.GREEN
		g.text(1, row, ">" if lit else " ", GameScreen.WHITE)
		g.text(2, row, "Q" if e.kind == "quick" else String(e.slot), GameScreen.WHITE)
		g.text(4, row, _line(e), col)
		g.list_line(row, i)
	g.list_chosen(_cursor)
	_details(_slots[_cursor] if _cursor < _slots.size() else {})
	if _typing:
		g.text(0, 24, "NAME: ", GameScreen.GREEN)
		g.text(6, 24, _typed + "_", GameScreen.WHITE)
	elif _flash != "":
		g.text(0, 24, _flash, GameScreen.GREEN)
	else:
		g.menu_line(24, _menu(), 0, _pick)
	g.update()


## A slot's line, 34 characters: area (13), square and facing (7), the game's day and time.
func _line(e: Dictionary) -> String:
	if not bool(e.exists):
		return "(EMPTY)"
	if not bool(e.get("ok", true)):
		return "(CAN'T BE READ)"
	var area := String(e.get("area", "")).to_upper()
	if e.kind == "quick" and area == "":
		area = "QUICK SAVE"
	var sq := ""
	if bool(e.get("started", true)) and e.has("x"):
		sq = "%d,%d %s" % [int(e.x), int(e.y), String(e.get("facing_text", ""))]
	var t := String(e.get("time_text", ""))
	return "%-13s %-7s %s" % [area.left(13), sq.left(7), t.left(13)]


func _details(e: Dictionary) -> void:
	var g := _scr
	if e.is_empty():
		return
	if not bool(e.exists):
		g.text(1, 15, "NOTHING SAVED HERE YET.", GameScreen.GREEN)
		return
	if not bool(e.get("ok", true)):
		g.text(1, 15, String(e.get("error", "")).to_upper().left(38), GameScreen.GREEN)
		return
	var label := String(e.get("label", ""))
	if label != "":
		g.text(1, 15, "\"%s\"" % label.left(NAME_MAX), GameScreen.YELLOW)
	var line := "SAVED " + _date(int(e.get("saved_at", 0)))
	if bool(e.get("map", false)):
		line += "   MAP"
	g.text(1, 16, line.left(38), GameScreen.CYAN)
	var party: Array = e.get("party", [])
	for k in mini(party.size(), 6):
		var p: Dictionary = party[k]
		var hp := "%d/%d" % [int(p.hp), int(p.hp_max)]
		g.text(1, 17 + k, String(p.name).left(15), GameScreen.GREEN)
		g.text(17, 17 + k, String(p.get("class", "")).to_upper().left(9), GameScreen.GREEN)
		g.text(33 - hp.length(), 17 + k, hp, GameScreen.GREEN)
		g.text(34, 17 + k, String(p.status).left(5), GameScreen.GREEN)
	if party.size() > 6:
		g.text(25, 16, "+%d MORE" % (party.size() - 6), GameScreen.CYAN)


## The file's own date and time, local: "17 NOV 13:05".
func _date(unix: int) -> String:
	if unix <= 0:
		return "?"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%d %s %02d:%02d" % [int(d.day), MONTHS[int(d.month) - 1], int(d.hour), int(d.minute)]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	var key := k.keycode
	if _typing:
		_type(k)
		return
	_flash = ""
	if key == KEY_ESCAPE:
		close()
		cancelled.emit()
		return
	if key in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_KP_7, KEY_KP_1]:
		var step := 1 if key in [KEY_DOWN, KEY_END, KEY_KP_1] else -1
		_cursor = clampi(_cursor + step, 0, maxi(_slots.size() - 1, 0))
		_draw()
		return
	if key == KEY_LEFT or key == KEY_RIGHT:
		_pick = (_pick + (1 if key == KEY_RIGHT else -1) + _menu().size()) % _menu().size()
		_draw()
		return
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		_do(_menu()[_pick])
		return
	# A letter A-J takes its slot at once, as the original's prompt (Q10); so E is slot E, not EXIT (Esc, or
	# Enter on EXIT, leaves). Q is the quick save on LOAD. S / L and N are the menu's.
	var ch := char(k.unicode).to_upper() if k.unicode > 0 else OS.get_keycode_string(key).to_upper()
	if ch.length() == 1 and SaveSlots.LETTERS.contains(ch):
		_take(ch)
		return
	if ch == "Q" and _mode == "load":
		_take("QUICK")
		return
	for it in _menu():
		if String(it).left(1) == ch:
			_pick = _menu().find(it)
			_do(it)
			return


func _do(choice: String) -> void:
	match choice:
		"SAVE", "LOAD":
			if _cursor < _slots.size():
				_take(String(_slots[_cursor].slot))
		"NAME":
			var e: Dictionary = _slots[_cursor] if _cursor < _slots.size() else {}
			if e.is_empty() or not bool(e.exists) or not bool(e.get("ok", true)):
				_flash = "NOTHING TO NAME THERE."
				_draw()
				return
			_typing = true
			_typed = String(e.get("label", ""))
			_draw()
		"EXIT":
			close()
			cancelled.emit()


func _take(slot: String) -> void:
	var e: Dictionary = {}
	for x in _slots:
		if String(x.slot) == slot:
			e = x
	if e.is_empty():
		return
	if _mode == "load" and (not bool(e.exists) or not bool(e.get("ok", true))):
		# The original's LOAD offers only the letters holding a game.
		_cursor = _slots.find(e)
		_flash = "NO GAME SAVED THERE."
		_draw()
		return
	close()
	picked.emit(slot)


func _type(k: InputEventKey) -> void:
	match k.keycode:
		KEY_ESCAPE:
			_typing = false
		KEY_ENTER, KEY_KP_ENTER:
			_typing = false
			var e: Dictionary = _slots[_cursor]
			if SaveSlots.set_label(game_path, String(e.slot), _typed, quick_path):
				_slots[_cursor] = SaveSlots.read_quick(quick_path) if e.kind == "quick" else SaveSlots.read_game(game_path, String(e.slot))
			else:
				_flash = "COULDN'T NAME IT."
		KEY_BACKSPACE:
			_typed = _typed.left(-1)
		_:
			var c := char(k.unicode).to_upper() if k.unicode > 0 else ""
			# The font's own characters: letters, digits, space and the usual marks.
			if c.length() == 1 and _typed.length() < NAME_MAX and c.unicode_at(0) >= 0x20 and c.unicode_at(0) < 0x5B \
					and c != "\"":
				_typed += c
	_draw()

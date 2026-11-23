class_name QuestScreen
extends Control
## THE QUEST LOG (QoL, Jeremy's Q11 / C11-4, 2026-11-16: option (a) with both spoiler rules; a
## SETTINGS switch, default ON; a FEATURES page). The original keeps no list: the council's clerk
## reads the commissions once and the party remembers them. Q while walking opens it; Esc, E or
## Q closes it. The data is main's (QuestLog over content/<game>/quests.json, main.quest_view()):
## this screen only draws what it is given.
##
## The list (rows 4-15, twelve to a page, NEXT / PREV only when they'd move, as FEATURES): the
## open quests, then the done ones (the reward waiting at City Hall), then the failed, then one
## folded line "REPORTED (n)"; VIEW on it unfolds the reported quests under it (VIEW again folds).
## Quests the party hasn't heard of are left out. The box under the rope (rows 17-22): who gave
## it, where (only once the offer was heard) and the start of the offer.
## VIEW on a quest: its page: title, giver, where, state, the steps done so far ("*" each; a
## step not yet done isn't shown, Jeremy's spoiler rule), then the offer, or the clerk's words
## once reported. P116 (Jeremy, 2026-11-22 23:05): SETTINGS SHOW ALL QUEST STEPS (default OFF)
## lists every step instead, the done ones marked "*", the rest plain.

signal closed

const KEY := "quests"
const STEPS_KEY := "quest_steps"
const PER_PAGE := 12
const STATE_WORD := {"open": "OPEN", "done": "DONE", "failed": "FAILED", "reported": "REPORTED"}
const MENU_LIST := ["VIEW", "EXIT"]
const MENU_PAGE := ["EXIT"]

var _screen: GameScreen
var _quests: Array = []      # QuestLog.evaluate()'s entries, hidden ones left out
var _rows: Array = []        # the list's lines: an index into _quests, or -1 for the fold line
var _sel := 0
var _unfolded := false
var _page_view := false


static func on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", KEY, true))


static func save_on(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", KEY, value)
	c.save(GameData.SETTINGS_PATH)


## P116: SHOW ALL QUEST STEPS, default OFF (the spoiler rule).
static func all_steps_on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return false
	return bool(c.get_value("qol", STEPS_KEY, false))


static func save_all_steps(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", STEPS_KEY, value)
	c.save(GameData.SETTINGS_PATH)


## Opens on `view` (main.quest_view()).
func open(view: Array) -> void:
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	_quests = view.filter(func(q): return String(q.get("state", "hidden")) != "hidden")
	_page_view = false
	_build_rows()
	_sel = clampi(_sel, 0, maxi(_rows.size() - 1, 0))
	visible = true
	_draw()


func _build_rows() -> void:
	_rows.clear()
	var reported: Array = []
	for st in ["open", "done", "failed"]:
		for i in _quests.size():
			if String(_quests[i].state) == st:
				_rows.append(i)
	for i in _quests.size():
		if String(_quests[i].state) == "reported":
			reported.append(i)
	if not reported.is_empty():
		_rows.append(-1)
		if _unfolded:
			_rows.append_array(reported)


func _count(state: String) -> int:
	return _quests.filter(func(q): return String(q.state) == state).size()


func _menu() -> Array:
	if _page_view:
		return MENU_PAGE
	var items: Array = MENU_LIST.duplicate()
	var page := _sel / PER_PAGE
	if page > 0:
		items.insert(1, "PREV")
	if (page + 1) * PER_PAGE < _rows.size():
		items.insert(1, "NEXT")
	return items


## A title as the list shows it: capitals (the game's font has no small letters).
static func title_of(q: Dictionary) -> String:
	return String(q.get("title", "")).to_upper()


## `s` in at most `width` characters, cut at a space when it is longer ("..." marks the cut).
static func cut(s: String, width: int) -> String:
	if s.length() <= width:
		return s
	var t := s.left(width - 2)
	var sp := t.rfind(" ")
	if sp > width / 2:
		t = t.left(sp)
	return t + ".."


## WHERE without the data's map numbers ("2:15 Mendor's library" -> "MENDOR'S LIBRARY").
static func where_of(q: Dictionary) -> String:
	var w := String(q.get("where", ""))
	var re := RegEx.create_from_string("^\\d+:\\d+\\s+")
	return re.sub(w, "").to_upper()


func _frame(g: GameScreen, rope: bool) -> void:
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
		if rope:
			g.tile(c, 16, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	var corners := [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]
	if rope:
		corners += [Vector2i(0, 16), Vector2i(39, 16)]
	for p in corners:
		g.tile(p.x, p.y, 20)


func _draw() -> void:
	var g := _screen
	if _page_view:
		_draw_page(g)
		return
	_frame(g, true)
	g.text(2, 2, "QUESTS", GameScreen.WHITE)
	var counts := "OPEN %d  DONE %d  REPORTED %d" % [_count("open"), _count("done"), _count("reported")]
	g.text(38 - counts.length(), 2, counts, GameScreen.CYAN)
	if _rows.is_empty():
		g.text(4, 4, "NO QUESTS KNOWN YET.", GameScreen.GREEN)
		g.menu_line(24, MENU_PAGE)
		g.update()
		return
	_sel = clampi(_sel, 0, _rows.size() - 1)
	var first := _sel / PER_PAGE * PER_PAGE
	for k in range(first, mini(first + PER_PAGE, _rows.size())):
		var row := 4 + k - first
		var lit := k == _sel
		var i: int = _rows[k]
		if i < 0:
			var s := "%s REPORTED (%d)" % ["-" if _unfolded else "+", _count("reported")]
			g.text(2, row, s, GameScreen.WHITE if lit else GameScreen.YELLOW)
		else:
			var q: Dictionary = _quests[i]
			var reported := String(q.state) == "reported"
			# Reported quests sit under their fold line with no state word; the others end
			# in OPEN / DONE / FAILED from column 33.
			var indent := 4 if reported else 2
			var width := (38 if reported else 32) - indent
			g.text(indent, row, cut(title_of(q), width), GameScreen.WHITE if lit else GameScreen.GREEN)
			if not reported:
				var word: String = STATE_WORD.get(String(q.state), "")
				g.text(33, row, word, GameScreen.WHITE if lit else GameScreen.CYAN)
		g.list_line(row, k)
	g.list_chosen(_sel)
	var lines := _box_lines()
	for n in mini(lines.size(), 6):
		g.text(1, 17 + n, lines[n][0], lines[n][1])
	g.menu_line(24, _menu())
	g.update()


## The box: giver, where (once offered), the offer's first lines; on the fold line a hint.
func _box_lines() -> Array:
	var out: Array = []
	var i: int = _rows[_sel]
	if i < 0:
		out.append(["QUESTS REPORTED AT CITY HALL AND PAID.", GameScreen.GREEN])
		out.append(["VIEW SHOWS OR HIDES THEM.", GameScreen.GREEN])
		return out
	var q: Dictionary = _quests[i]
	if String(q.get("giver", "")) != "":
		for l in GameScreen.wrap("FROM: " + String(q.giver).to_upper(), 38):    # main's chat 42: a long giver ran past the frame
			out.append([l, GameScreen.GREEN])
	if bool(q.get("offered", false)) and where_of(q) != "":
		for l in GameScreen.wrap("WHERE: " + where_of(q), 38):
			out.append([l, GameScreen.GREEN])
	for l in GameScreen.wrap(String(q.get("offer", "")).to_upper(), 38):
		out.append([l, GameScreen.CYAN])
	return out


func _draw_page(g: GameScreen) -> void:
	_frame(g, false)
	var q: Dictionary = _quests[_rows[_sel]]
	var row := 2
	for l in GameScreen.wrap(title_of(q), 36):
		g.text((40 - l.length()) / 2, row, l, GameScreen.YELLOW)
		row += 1
	row += 1
	var info: Array = []
	if String(q.get("giver", "")) != "":
		info.append("FROM: " + String(q.giver).to_upper())
	if bool(q.get("offered", false)) and where_of(q) != "":
		info.append("WHERE: " + where_of(q))
	var st := String(q.state)
	info.append("STATE: " + {"open": "OPEN", "done": "DONE: REPORT AT CITY HALL", "failed": "FAILED",
		"reported": "REPORTED AND PAID"}.get(st, st.to_upper()))
	for t in info:
		for l in GameScreen.wrap(t, 36):
			if row <= 22:
				g.text(2, row, l, GameScreen.GREEN)
			row += 1
	var all_steps := all_steps_on()
	var shown: Array = q.get("steps", []).filter(func(s): return all_steps or bool(s.get("done", false)))
	if not shown.is_empty():
		row += 1
		for s in shown:
			if bool(s.get("done", false)) and row <= 22:
				g.text(2, row, "*", GameScreen.WHITE)
			for l in GameScreen.wrap(String(s.text).to_upper(), 34):
				if row <= 22:
					g.text(4, row, l, GameScreen.WHITE)
				row += 1
	var words := String(q.get("report", "")) if st == "reported" else String(q.get("offer", ""))
	if words != "":
		row += 1
		for l in GameScreen.wrap(words.to_upper(), 36):
			if row <= 22:
				g.text(2, row, l, GameScreen.CYAN)
			row += 1
	g.menu_line(24, MENU_PAGE)
	g.update()


func _close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()      # the walking screen under it reads no key meanwhile
	if not event.pressed:
		return
	var key := (event as InputEventKey).keycode
	if _page_view:
		if key in [KEY_ESCAPE, KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_page_view = false
			_draw()
		return
	if key in [KEY_ESCAPE, KEY_E, KEY_Q]:
		_close()
		return
	if _rows.is_empty():
		return
	if event.is_action("ui_up"):
		_sel = (_sel + _rows.size() - 1) % _rows.size()
	elif event.is_action("ui_down"):
		_sel = (_sel + 1) % _rows.size()
	elif key == KEY_HOME:
		_sel = 0
	elif key == KEY_END:
		_sel = _rows.size() - 1
	elif key == KEY_N and "NEXT" in _menu():
		_sel = (_sel / PER_PAGE + 1) * PER_PAGE
	elif key == KEY_P and "PREV" in _menu():
		_sel = (_sel / PER_PAGE - 1) * PER_PAGE
	elif key in [KEY_V, KEY_ENTER, KEY_KP_ENTER]:
		if int(_rows[_sel]) < 0:
			_unfolded = not _unfolded
			_build_rows()
		else:
			_page_view = true
	_draw()

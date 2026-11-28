class_name MessageScreen
extends Control
## P58, THE MESSAGE LOG's screen (QoL; Jeremy's Q43, 2026-11-28 07:28: the mockup as drawn). H or Esc on the walking
## screen opens it (main.gd); the lines are MessageLog's (scripts/game/message_log.gd).
## The list (rope at row 16): the areas the party has had text in, newest first: the name, its newest line's time (the
## time today, else the day), how many lines; twelve to a page. The box under the rope shows the lit area's newest line.
## VIEW (V or Enter) opens the lit area; EXIT (E, Esc or H) goes back to walking. Up / Down / Home / End move the light.
## VIEW on an area: its lines newest first, each with its time in cyan; script text green, fight lines yellow; NEXT /
## PREV page to older and newer lines; EXIT (E or Esc) back to the list.

signal closed

const PER_PAGE := 12
const BOX_ROWS := 5          # rows 18-22, under the time on row 17
const TEXT_COL := 8          # VIEW's text, after a time of up to six characters ("DAY 12")
const TEXT_WIDTH := 30

var _screen: GameScreen
var _log: MessageLog
var _areas: Array = []
var _today := 0
var _sel := 0
var _page_view := false
var _pages: Array = []       # VIEW's pages: each a list of entries
var _page := 0


func open(log: MessageLog) -> void:
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	_log = log
	_areas = log.areas()
	var w: Array = log.where.call() if log.where.is_valid() else ["", 0, 0]
	_today = int(w[1])
	_sel = 0                 # the newest area
	_page_view = false
	visible = true
	_draw()


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


static func colour(e: Dictionary) -> int:
	return GameScreen.YELLOW if String(e.k) == MessageLog.FIGHT else GameScreen.GREEN


func _menu() -> Array:
	if _page_view:
		var words: Array = []
		if _page + 1 < _pages.size():
			words.append("NEXT")
		if _page > 0:
			words.append("PREV")
		return words + ["EXIT"]
	var items: Array = ["VIEW", "EXIT"] if not _areas.is_empty() else ["EXIT"]
	var page := _sel / PER_PAGE
	if page > 0:
		items.insert(items.size() - 1, "PREV")
	if (page + 1) * PER_PAGE < _areas.size():
		items.insert(items.size() - 1, "NEXT")
	return items


func _draw() -> void:
	var g := _screen
	if _page_view:
		_draw_page(g)
		return
	_frame(g, true)
	g.text(2, 2, "MESSAGES", GameScreen.WHITE)
	g.text(26, 2, "NEWEST FIRST", GameScreen.CYAN)
	if _areas.is_empty():
		g.text(2, 4, "NO MESSAGES YET.", GameScreen.GREEN)
		g.menu_line(24, _menu())
		g.update()
		return
	_sel = clampi(_sel, 0, _areas.size() - 1)
	var first := _sel / PER_PAGE * PER_PAGE
	for k in range(first, mini(first + PER_PAGE, _areas.size())):
		var row := 4 + k - first
		var lit := k == _sel
		var a: Dictionary = _areas[k]
		var name := String(a.name) if String(a.name) != "" else "?"
		g.text(2, row, QuestScreen.cut(name, 22), GameScreen.WHITE if lit else GameScreen.GREEN)
		g.text(25, row, MessageLog.when(int(a.d), int(a.m), _today), GameScreen.WHITE if lit else GameScreen.CYAN)
		var n := "(%d)" % int(a.count)
		g.text(38 - n.length(), row, n, GameScreen.WHITE if lit else GameScreen.CYAN)
		g.list_line(row, k)
	g.list_chosen(_sel)
	var newest: Dictionary = _log.entries[int(_areas[_sel].last)]
	g.text(1, 17, MessageLog.when(int(newest.d), int(newest.m), _today), GameScreen.CYAN)
	var lines := GameScreen.wrap(String(newest.x), 38)
	for n in mini(lines.size(), BOX_ROWS):
		g.text(1, 18 + n, lines[n], colour(newest))
	g.menu_line(24, _menu())
	g.update()


## VIEW's pages: the area's lines newest first, each wrapped to TEXT_WIDTH with a blank row after it, as many as fit
## rows 4-22.
func _build_pages() -> void:
	_pages = []
	var page: Array = []
	var row := 4
	for e in _log.lines_of(String(_areas[_sel].name)):
		var h := GameScreen.wrap(String(e.x), TEXT_WIDTH).size()
		if row + h - 1 > 22 and not page.is_empty():
			_pages.append(page)
			page = []
			row = 4
		page.append(e)
		row += h + 1
	if not page.is_empty():
		_pages.append(page)


func _draw_page(g: GameScreen) -> void:
	_frame(g, false)
	g.text(2, 2, QuestScreen.cut(String(_areas[_sel].name), 27), GameScreen.WHITE)
	var p := "PAGE %d" % (_page + 1)
	g.text(38 - p.length(), 2, p, GameScreen.CYAN)
	var row := 4
	for e in _pages[_page]:
		g.text(1, row, MessageLog.when(int(e.d), int(e.m), _today), GameScreen.CYAN)
		var lines := GameScreen.wrap(String(e.x), TEXT_WIDTH)
		for n in lines.size():
			if row + n <= 22:
				g.text(TEXT_COL, row + n, lines[n], colour(e))
		row += lines.size() + 1
	g.menu_line(24, _menu())
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
		if key in [KEY_ESCAPE, KEY_E]:
			_page_view = false
			_draw()
		elif key in [KEY_N, KEY_PAGEDOWN] and "NEXT" in _menu():
			_page += 1
			_draw()
		elif key in [KEY_P, KEY_PAGEUP] and "PREV" in _menu():
			_page -= 1
			_draw()
		return
	if key in [KEY_ESCAPE, KEY_E, KEY_H]:
		_close()
		return
	if _areas.is_empty():
		return
	if event.is_action("ui_up"):
		_sel = (_sel + _areas.size() - 1) % _areas.size()
	elif event.is_action("ui_down"):
		_sel = (_sel + 1) % _areas.size()
	elif key == KEY_HOME:
		_sel = 0
	elif key == KEY_END:
		_sel = _areas.size() - 1
	elif key == KEY_N and "NEXT" in _menu():
		_sel = (_sel / PER_PAGE + 1) * PER_PAGE
	elif key == KEY_P and "PREV" in _menu():
		_sel = (_sel / PER_PAGE - 1) * PER_PAGE
	elif key in [KEY_V, KEY_ENTER, KEY_KP_ENTER]:
		_build_pages()
		if not _pages.is_empty():
			_page_view = true
			_page = 0
	_draw()

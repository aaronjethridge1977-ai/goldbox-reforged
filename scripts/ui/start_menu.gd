class_name StartMenu
extends Control
## The way into the game: the title picture, then a menu in the original's font and frame.
##   CONTINUE        the quick save (F2), when there is one
##   LOAD SAVED GAME the original's own saves (SAVGAMA..J.DAT in the game folder)
##   NEW GAME        the ready-made party (CHRDATA1-6) from the start of the adventure
##   EXIT
## Keys: the hot letters, Up/Down and Enter. Saved-game letters pick a save.

signal chosen(what: String, letter: String)

var game_path := ""
var has_quick_save := false
var _screen: GameScreen
var _title: TextureRect
var _stage := "title"
var _items: Array = []
var _sel := 0
var _saves: Array[String] = []


func open(path: String, quick: bool) -> void:
	game_path = path
	has_quick_save = quick
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_title = TextureRect.new()
		_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ShopScreen._fill(_title, 0)
		add_child(_title)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	var dax := DaxFile.open(game_path.path_join("TITLE.DAX"))
	if dax != null and dax.blocks.has(2):
		var pic := EgaPicture.decode(dax.blocks[2])
		if pic != null:
			_title.texture = ImageTexture.create_from_image(pic.frames[0])
	_saves.clear()
	for c in "ABCDEFGHIJ":
		if FileAccess.file_exists(game_path.path_join("SAVGAM%s.DAT" % c)):
			_saves.append(c)
	_stage = "title"
	_title.visible = true
	_screen.visible = false
	visible = true


func _show_menu() -> void:
	_stage = "menu"
	_title.visible = false
	_screen.visible = true
	_items = []
	if has_quick_save:
		_items.append("CONTINUE")
	if not _saves.is_empty():
		_items.append("LOAD SAVED GAME")
	_items.append("NEW GAME")
	_items.append("EXIT")
	_sel = clampi(_sel, 0, _items.size() - 1)
	_draw()


func _draw() -> void:
	var g := _screen
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	g.text(10, 2, "POOL OF RADIANCE", GameScreen.YELLOW)
	g.text(9, 3, "GOLD BOX REFORGED", GameScreen.CYAN)
	if _stage == "menu":
		for i in _items.size():
			var s: String = _items[i]
			g.text(12, 7 + i * 2, s.substr(0, 1), GameScreen.WHITE)
			g.text(13, 7 + i * 2, s.substr(1), GameScreen.WHITE if i == _sel else GameScreen.GREEN)
		g.text(2, 20, "YOUR OWN COPY OF THE GAME'S FILES", GameScreen.CYAN)
		g.text(2, 21, "PLAYS HERE.", GameScreen.CYAN)
	else:
		g.text(4, 7, "LOAD WHICH GAME?", GameScreen.WHITE)
		g.menu_line(24, _saves + ["EXIT"])
	g.update()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _stage == "title":
		_show_menu()
		return
	var letter := OS.get_keycode_string(key).to_upper() if key != KEY_NONE else ""
	if _stage == "load":
		if _saves.has(letter):
			visible = false
			chosen.emit("load", letter)
		elif key == KEY_E or key == KEY_ESCAPE:
			_show_menu()
		return
	if event.is_action("ui_up"):
		_sel = (_sel + _items.size() - 1) % _items.size()
	elif event.is_action("ui_down"):
		_sel = (_sel + 1) % _items.size()
	elif event.is_action("ui_accept"):
		_pick(_items[_sel])
		return
	else:
		for it in _items:
			if String(it).begins_with(letter) and letter != "":
				_pick(it)
				return
	_draw()


func _pick(item: String) -> void:
	match item:
		"CONTINUE":
			visible = false
			chosen.emit("continue", "")
		"LOAD SAVED GAME":
			_stage = "load"
			_draw()
		"NEW GAME":
			visible = false
			chosen.emit("new", "")
		"EXIT":
			get_tree().quit()

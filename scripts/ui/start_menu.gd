class_name StartMenu
extends Control
## The way into the game. On first launch, as the original: the SSI / AD&D logo, the title
## picture (each drawn in from the top), the game's own credits; then a menu in the original's
## font and frame. A key moves on at once.
##   CONTINUE        the quick save (F2), when there is one
##   LOAD SAVED GAME the original's own saves (SAVGAMA..J.DAT in the game folder)
##   NEW GAME        the ready-made party (CHRDATA1-6) from the start of the adventure
##   PARTY CREATION  the original's way in: create characters, add them, begin
##   SETTINGS        the additions that can be turned on or off (automap, portraits, start memorized, quick bandages, quick tactics)
##   ABOUT           Gold Box Reforged's credits and the Godot license
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
# Lab, 2026-11-13 (DOSBox at GOG's speed, cycles=auto = 3000): TITLE.DAX block 1 (SSI presents,
# AD&D) draws top to bottom in about 0.4 s and stays about 7 s, then block 2 (the title) draws the
# same way. A key cuts the logo's wait short.
const WIPE_SECS := 0.4
const LOGO_SECS := 7.0
# The original then shows the title about 5 s and its credits (GAME.OVR) about 10 s before the
# code wheel; the credits screen is drawn in over about 0.4 s.
const TITLE_SECS := 5.0
const CREDITS_SECS := 10.0
var _intro := false        # first launch: the screens move on by themselves, as the original's
var _hold_t := 0.0
var _credits_layout := {}
var _draw_t := -1.0
var _pages: Array = []
var _page := 0
static var _intro_done := false
var _logo_pic: Image
var _title_pic: Image
var _wipe_src: Image
var _wipe_img: Image
var _wipe_t := -1.0
var _logo_t := 0.0


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
	_logo_pic = _title_block(dax, 1)
	_title_pic = _title_block(dax, 2)
	_saves.clear()
	for c in "ABCDEFGHIJ":
		if FileAccess.file_exists(game_path.path_join("SAVGAM%s.DAT" % c)):
			_saves.append(c)
	_title.visible = true
	_screen.visible = false
	visible = true
	if not _intro_done and _logo_pic != null:
		_intro_done = true
		_stage = "logo"
		_logo_t = 0.0
		_intro = true
		_wipe_in(_logo_pic)
	else:
		_intro_done = true
		_intro = false
		_start_title()


func _title_block(dax: DaxFile, id: int) -> Image:
	if dax == null or not dax.blocks.has(id):
		return null
	var pic := EgaPicture.decode(dax.blocks[id])
	return pic.frames[0] if pic != null else null


func _start_title() -> void:
	_stage = "title"
	_hold_t = 0.0
	_wipe_in(_title_pic)


## The original's credits screen, read from the player's GAME.OVR; straight to the menu without it.
func _start_original_credits() -> void:
	_wipe_t = -1.0
	_credits_layout = Credits.original_layout(game_path)
	if _credits_layout.is_empty():
		_intro = false
		_show_menu()
		return
	_stage = "orig_credits"
	_title.visible = false
	_screen.visible = true
	_hold_t = 0.0
	_draw_t = 0.0
	Credits.draw_original(_screen, _credits_layout, 0)
	set_process(true)


func _show_credits_page() -> void:
	Credits.draw_page(_screen, _pages[_page], _page == _pages.size() - 1)


## Show a picture drawing in from the top, as the original draws its title screens.
func _wipe_in(pic: Image) -> void:
	_wipe_src = pic
	if pic == null:
		_title.texture = null
		_wipe_t = -1.0
		return
	# The original paints the new picture down over the one on screen (the title over the logo).
	var under := _wipe_img
	_wipe_img = Image.create_empty(pic.get_width(), pic.get_height(), false, pic.get_format())
	_wipe_img.fill(Color.BLACK)
	if under != null and under.get_size() == pic.get_size() and under.get_format() == pic.get_format():
		_wipe_img.copy_from(under)
	_title.texture = ImageTexture.create_from_image(_wipe_img)
	_wipe_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _wipe_t >= 0.0:
		_wipe_t += minf(delta, 1.0 / 30.0)   # a slow first frame doesn't skip the wipe
		var h := _wipe_src.get_height()
		var rows := clampi(int(h * _wipe_t / WIPE_SECS), 0, h)
		_wipe_img.blit_rect(_wipe_src, Rect2i(0, 0, _wipe_src.get_width(), rows), Vector2i.ZERO)
		(_title.texture as ImageTexture).update(_wipe_img)
		if rows >= h:
			_wipe_t = -1.0
	elif _stage == "logo":
		_logo_t += delta
		if _logo_t >= LOGO_SECS:
			_start_title()
	elif _stage == "title" and _intro:
		_hold_t += delta
		if _hold_t >= TITLE_SECS:
			_start_original_credits()
	elif _stage == "orig_credits":
		var steps: int = _credits_layout.texts.size()
		if _draw_t >= 0.0:
			_draw_t += minf(delta, 1.0 / 30.0)
			var n := clampi(int(steps * _draw_t / WIPE_SECS), 0, steps)
			Credits.draw_original(_screen, _credits_layout, n)
			if n >= steps:
				_draw_t = -1.0
		else:
			_hold_t += delta
			if _hold_t >= CREDITS_SECS:
				_intro = false
				_show_menu()
	else:
		set_process(false)


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
	_items.append("PARTY CREATION")
	_items.append("SETTINGS")
	_items.append("ABOUT")
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
	elif _stage == "settings":
		g.text(2, 5, "SETTINGS (ADDITIONS TO THE ORIGINAL)", GameScreen.WHITE)
		g.text(4, 7, "A", GameScreen.WHITE)
		g.text(5, 7, "UTOMAP: " + ("ON" if Automap.load_enabled() else "OFF"), GameScreen.GREEN)
		g.text(6, 8, "WALKING: M MINI-MAP, F FULL MAP", GameScreen.CYAN)
		g.text(4, 9, "P", GameScreen.WHITE)
		g.text(5, 9, "ORTRAITS: " + ("MATCHED" if CharacterCreator.matched_portraits() else "ORIGINAL"), GameScreen.GREEN)
		g.text(6, 10, "MATCHED: NEW CHARACTERS START", GameScreen.CYAN)
		g.text(6, 11, "ON A HEAD AND BODY THAT FIT", GameScreen.CYAN)
		g.text(4, 12, "S", GameScreen.WHITE)
		g.text(5, 12, "TART MEMORIZED: " + ("ON" if CampScreen.start_memorized_on() else "OFF"), GameScreen.GREEN)
		g.text(6, 13, "ON: CASTERS PICK SPELLS AT", GameScreen.CYAN)
		g.text(6, 14, "BEGIN ADVENTURING, NO REST", GameScreen.CYAN)
		g.text(4, 15, "Q", GameScreen.WHITE)
		g.text(5, 15, "UICK BANDAGES: " + ("ON" if Combat.quick_bandages_on() else "OFF"), GameScreen.GREEN)
		g.text(6, 16, "ON: QUICK FIGHTERS BANDAGE", GameScreen.CYAN)
		g.text(6, 17, "THE DYING (THE ORIGINAL'S DON'T)", GameScreen.CYAN)
		g.text(4, 18, "T", GameScreen.WHITE)
		g.text(5, 18, "ACTICS FOR QUICK: " + ("SMARTER" if SmartQuick.on() else "ORIGINAL"), GameScreen.GREEN)
		g.text(6, 19, "SMARTER: QUICK HEALS, AIMS AT", GameScreen.CYAN)
		g.text(6, 20, "THE WEAKEST, SAVES ITS SPELLS", GameScreen.CYAN)
		g.text(4, 22, "A, P, S, Q OR T CHANGES IT, ESC: BACK", GameScreen.CYAN)
	else:
		g.text(4, 7, "LOAD WHICH GAME?", GameScreen.WHITE)
		g.menu_line(24, _saves + ["EXIT"])
	g.update()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _stage == "logo":
		_start_title()
		return
	if _stage == "title":
		_wipe_t = -1.0
		if _intro:
			_start_original_credits()
		else:
			_show_menu()
		return
	if _stage == "orig_credits":
		_intro = false
		_show_menu()
		return
	if _stage == "credits":
		var last := _page >= _pages.size() - 1
		if key == KEY_E or key == KEY_ESCAPE or (last and (key == KEY_ENTER or key == KEY_SPACE)):
			_show_menu()
		elif not last:
			_page += 1
			_show_credits_page()
		return
	var letter := OS.get_keycode_string(key).to_upper() if key != KEY_NONE else ""
	if _stage == "settings":
		if key == KEY_A:
			Automap.save_enabled(not Automap.load_enabled())
			_draw()
		elif key == KEY_P:
			CharacterCreator.save_matched_portraits(not CharacterCreator.matched_portraits())
			_draw()
		elif key == KEY_S:
			CampScreen.save_start_memorized(not CampScreen.start_memorized_on())
			_draw()
		elif key == KEY_Q:
			Combat.save_quick_bandages(not Combat.quick_bandages_on())
			_draw()
		elif key == KEY_T:
			SmartQuick.save(not SmartQuick.on())
			_draw()
		elif key == KEY_E or key == KEY_ESCAPE:
			_show_menu()
		return
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
		"PARTY CREATION":
			visible = false
			chosen.emit("create", "")
		"SETTINGS":
			_stage = "settings"
			_draw()
		"ABOUT":
			_stage = "credits"
			_pages = Credits.pages()
			_page = 0
			_show_credits_page()
		"EXIT":
			get_tree().quit()

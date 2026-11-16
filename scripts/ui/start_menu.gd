class_name StartMenu
extends Control
## The way into the game. On first launch, as the original: the SSI / AD&D logo, the title
## picture (each drawn in from the top), the game's own credits; then a menu in the original's
## font and frame. A key moves on at once.
##   CONTINUE        the quick save (F2), when there is one
##   LOAD SAVED GAME the original's own saves (SAVGAMA..J.DAT in the game folder)
##   NEW GAME        the ready-made party (CHRDATA1-6) from the start of the adventure
##   PARTY CREATION  the original's way in: create characters, add them, begin
##   SETTINGS        the additions that can be turned on or off (automap, portraits, start memorized, FIX in camp, quick bandages, DONE's MAGIC, quick tactics, monster tactics),
##                   one line each; Up/Down highlights one and the box below explains it (P21)
##   ABOUT           a menu (P21): FEATURES (each addition: a list, then a page each) and CREDITS
##                   (Gold Box Reforged's credits and the Godot license)
##   EXIT
## Keys: the hot letters, Up/Down and Enter. Saved-game letters pick a save.
## All the text of SETTINGS, FEATURES and CREDITS comes from content/features.json (FeatureText).

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
var _set_sel := 0        # SETTINGS: the highlighted item
var _about_sel := 0      # ABOUT: the highlighted item
var _feat_sel := 0       # FEATURES: the highlighted feature (and the page shown)
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
	if _stage == "features":
		_draw_features(g)
		return
	if _stage == "feature":
		_draw_feature_page(g)
		return
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	if _stage == "settings":
		_divider(g)
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
		_draw_settings(g)
	elif _stage == "about":
		g.text(9, 5, FeatureText.text("about_title", "ABOUT"), GameScreen.WHITE)
		var items := FeatureText.menu("about")
		for i in items.size():
			var s: String = items[i]
			g.text(12, 7 + i * 2, s.substr(0, 1), GameScreen.WHITE)
			g.text(13, 7 + i * 2, s.substr(1), GameScreen.WHITE if i == _about_sel else GameScreen.GREEN)
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
			_stage = "about"
			_draw()
		elif not last:
			_page += 1
			_show_credits_page()
		return
	var letter := OS.get_keycode_string(key).to_upper() if key != KEY_NONE else ""
	if _stage == "settings":
		var sets := FeatureText.settings()
		if key == KEY_E or key == KEY_ESCAPE:
			_show_menu()
			return
		if event.is_action("ui_up"):
			_set_sel = (_set_sel + sets.size() - 1) % sets.size()
		elif event.is_action("ui_down"):
			_set_sel = (_set_sel + 1) % sets.size()
		elif event.is_action("ui_accept") or key == KEY_C or key == KEY_SPACE:
			change_setting(String(sets[_set_sel].setting))
		else:
			for i in sets.size():
				if letter != "" and String(sets[i].label).begins_with(letter):
					_set_sel = i
					change_setting(String(sets[i].setting))
					break
		_draw()
		return
	if _stage == "about":
		var items := FeatureText.menu("about")
		var pick := ""
		if key == KEY_ESCAPE:
			pick = "EXIT"
		elif event.is_action("ui_up"):
			_about_sel = (_about_sel + items.size() - 1) % items.size()
		elif event.is_action("ui_down"):
			_about_sel = (_about_sel + 1) % items.size()
		elif event.is_action("ui_accept"):
			pick = items[_about_sel]
		else:
			for it in items:
				if letter != "" and String(it).begins_with(letter):
					pick = it
		match _about_index(pick):
			0:
				_stage = "features"
			1:
				_stage = "credits"
				_pages = Credits.pages()
				_page = 0
				_show_credits_page()
				return
			2:
				_show_menu()
				return
		_draw()
		return
	if _stage == "features":
		var n := FeatureText.features().size()
		if key == KEY_E or key == KEY_ESCAPE:
			_stage = "about"
		elif event.is_action("ui_up"):
			_feat_sel = (_feat_sel + n - 1) % n
		elif event.is_action("ui_down"):
			_feat_sel = (_feat_sel + 1) % n
		elif event.is_action("ui_accept") or key == KEY_V:
			_stage = "feature"
		elif key == KEY_N and "NEXT" in _features_menu():
			_feat_sel = (_feat_sel / FEATURES_PER_PAGE + 1) * FEATURES_PER_PAGE
		elif key == KEY_P and "PREV" in _features_menu():
			_feat_sel = (_feat_sel / FEATURES_PER_PAGE - 1) * FEATURES_PER_PAGE
		_draw()
		return
	if _stage == "feature":
		var n := FeatureText.features().size()
		if key == KEY_E or key == KEY_ESCAPE:
			_stage = "features"
		elif key == KEY_N or event.is_action("ui_accept") or event.is_action("ui_right") or event.is_action("ui_down"):
			_feat_sel = (_feat_sel + 1) % n
		elif key == KEY_P or event.is_action("ui_left") or event.is_action("ui_up"):
			_feat_sel = (_feat_sel + n - 1) % n
		_draw()
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
			_set_sel = 0
			_draw()
		"ABOUT":
			_stage = "about"
			_about_sel = 0
			_draw()
		"EXIT":
			get_tree().quit()


# ---------------------------------------------------------------- SETTINGS and FEATURES (P21)

func _enter_tree() -> void:
	add_to_group("display_mode")


## Alt+Enter / F11 while SETTINGS is up: show the new FULL SCREEN value.
func display_mode_changed() -> void:
	if visible and _stage == "settings":
		_draw()


## A SETTINGS item's value as the index into its "values" in content/features.json.
static func setting_value(id: String) -> int:
	match id:
		"automap": return int(Automap.load_enabled())
		"portraits": return int(CharacterCreator.matched_portraits())
		"memorized": return int(CampScreen.start_memorized_on())
		"bandages": return int(Combat.quick_bandages_on())
		"magicmenu": return int(Combat.magic_menu_on())
		"fix": return int(CampScreen.fix_on())
		"tactics": return int(SmartQuick.on())
		"monsters": return int(SmartQuick.monsters_on())
		"fullscreen": return int(DisplayMode.load_on())
		"sound": return int(Speaker.on())
	return 0


## Moves a SETTINGS item on to its next value.
static func change_setting(id: String) -> void:
	match id:
		"automap": Automap.save_enabled(not Automap.load_enabled())
		"portraits": CharacterCreator.save_matched_portraits(not CharacterCreator.matched_portraits())
		"memorized": CampScreen.save_start_memorized(not CampScreen.start_memorized_on())
		"bandages": Combat.save_quick_bandages(not Combat.quick_bandages_on())
		"magicmenu": Combat.save_magic_menu(not Combat.magic_menu_on())
		"fix": CampScreen.save_fix(not CampScreen.fix_on())
		"tactics": SmartQuick.save(not SmartQuick.on())
		"monsters": SmartQuick.save_monsters(not SmartQuick.monsters_on())
		"fullscreen": DisplayMode.toggle(Engine.get_main_loop() as SceneTree)
		"sound": Speaker.save_on(not Speaker.on())


func _about_index(item: String) -> int:
	return FeatureText.menu("about").find(item)


## The start menu's frame (the caller has drawn it) with a rope across row 16, as the walking
## screen's, making a text box of rows 17..22.
func _divider(g: GameScreen) -> void:
	for c in 40:
		g.tile(c, 16, 22)
	g.tile(0, 16, 20)
	g.tile(39, 16, 20)


func _frame(g: GameScreen) -> void:
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)


## SETTINGS: one line an item (hot letter white, name green, value cyan; the highlighted line
## all white, as the original's menus), the highlighted item's help in the box, CHANGE EXIT.
func _draw_settings(g: GameScreen) -> void:
	g.text(2, 4, FeatureText.text("settings_title"), GameScreen.WHITE)
	var sets := FeatureText.settings()
	_set_sel = clampi(_set_sel, 0, maxi(sets.size() - 1, 0))
	for i in sets.size():
		var f: Dictionary = sets[i]
		var label := String(f.label)
		var vals: Array = f.get("values", [])
		var v := setting_value(String(f.setting))
		var on := i == _set_sel
		g.text(4, 6 + i, label.substr(0, 1), GameScreen.WHITE)
		g.text(5, 6 + i, label.substr(1), GameScreen.WHITE if on else GameScreen.GREEN)
		g.text(24, 6 + i, String(vals[v]) if v < vals.size() else str(v), GameScreen.WHITE if on else GameScreen.CYAN)
	if not sets.is_empty():
		_box(g, FeatureText.box_lines(sets[_set_sel], true))
	g.menu_line(24, FeatureText.menu("settings"))


func _box(g: GameScreen, lines: Array) -> void:
	for i in lines.size():
		if String(lines[i][0]) != "":
			g.text(1, 17 + i, lines[i][0], lines[i][1])


## FEATURES: every addition, the highlighted one's help in the box, VIEW EXIT. P66: twelve to a
## page (rows 4-15, above the box's rope), NEXT and PREV on the menu only when they'd move, as
## the original's lists (VIEW NEXT PREV EXIT).
const FEATURES_PER_PAGE := 12


func _features_menu() -> Array:
	var n := FeatureText.features().size()
	var page := _feat_sel / FEATURES_PER_PAGE
	var items: Array = FeatureText.menu("features").duplicate()
	var at := maxi(items.find("EXIT"), 0)
	if page > 0:
		items.insert(at, "PREV")
	if (page + 1) * FEATURES_PER_PAGE < n:
		items.insert(at, "NEXT")
	return items


func _draw_features(g: GameScreen) -> void:
	_frame(g)
	_divider(g)
	g.text(2, 2, FeatureText.text("features_title"), GameScreen.WHITE)
	var fs := FeatureText.features()
	_feat_sel = clampi(_feat_sel, 0, maxi(fs.size() - 1, 0))
	var first := _feat_sel / FEATURES_PER_PAGE * FEATURES_PER_PAGE
	for i in range(first, mini(first + FEATURES_PER_PAGE, fs.size())):
		g.text(4, 4 + i - first, String(fs[i].name), GameScreen.WHITE if i == _feat_sel else GameScreen.GREEN)
	if not fs.is_empty():
		_box(g, FeatureText.box_lines(fs[_feat_sel], false))
	g.menu_line(24, _features_menu())
	g.update()


## One feature's page: its name, then WHAT IT DOES, KEYS, DEFAULT and IN THE ORIGINAL.
func _draw_feature_page(g: GameScreen) -> void:
	_frame(g)
	var fs := FeatureText.features()
	if fs.is_empty():
		g.update()
		return
	var f: Dictionary = fs[_feat_sel]
	var name := String(f.name)
	g.text((40 - name.length()) / 2, 2, name, GameScreen.YELLOW)
	var row := 4
	for k in ["what", "keys", "default", "original"]:
		var t := String(f.get(k, ""))
		if t == "":
			continue
		if row > 4:
			row += 1
		g.text(2, row, FeatureText.heading(k), GameScreen.YELLOW)
		row += 1
		for l in GameScreen.wrap(t, 36):
			if row <= 22:
				g.text(2, row, l, GameScreen.CYAN)
			row += 1
	g.menu_line(24, FeatureText.menu("page"))
	g.update()

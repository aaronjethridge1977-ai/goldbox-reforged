class_name GameFolderScreen
extends Control
## Shown when the player's Pool of Radiance files aren't found: asks for them, checks them
## and remembers the answer (GameData). The player's own copy (GOG, Steam or the original
## disks) is the only source of game data; nothing from it ships with the engine.
##
## The look (Jeremy, Q15 / Q16, 2026-11-16: mockup V4, Combat Chat 14's C14-1): framed windows
## as the later Gold Box games' VGA screens, in a frame of our own (a bronze bar, red stones in
## green rings where the bars meet), dark panels, our own GB shield as pixel art, and the text
## in our own 8x8 bold pixel font (PixelFont): no game file is read before the folder is chosen.
## Drawn on the 320 x 200 grid and scaled up whole. Row 24: CHOOSE EXIT (keys C / E, Left / Right
## and Enter, or the mouse on a word).
##
## Desktop: a folder dialog. The game's folder ("Pool of Radiance" or POOLRAD inside it, or any
## folder holding GEO1.DAX) will do.
## Web: the browser can't open a folder by path, so a folder picker (an <input> with
## webkitdirectory) reads the chosen folder's files and they are copied into the browser's
## own storage for the game (user://poolrad, IndexedDB behind Godot's file system), once.
## Only the files the game reads are kept (see WANTED).

signal ready_to_start(path: String)

const WEB_FOLDER := "user://poolrad"
## Extensions the engine reads from the game folder (plus a few named files).
const WANTED := ["DAX", "OVR", "EXE", "SAV", "ITM", "SPC", "DAT", "TXT", "CFG"]
const WANTED_NAMES := ["ITEMS"]

const W := 320
const H := 200
const BAR := 5                  # the frame bar's thickness
const SPLIT_X := 116            # the emblem window's right bar
const SPLIT_Y := 132            # the text strip's top bar
const BOTTOM := 186             # the bottom bar (row 24 below it)
const PITCH := 10               # text lines 10 pixels apart: 8-pixel letters, 2 between
const MENU := ["CHOOSE", "EXIT"]

const GREEN := Color8(84, 252, 84)
const YELLOW := Color8(252, 252, 84)
const CYAN := Color8(84, 252, 252)
const WHITE := Color8(252, 252, 252)
const RED := Color8(252, 84, 84)
## The bronze bar: a highlight edge, three body shades, a shadow edge.
const TONES := [Color8(250, 226, 160), Color8(196, 146, 70), Color8(150, 100, 40), Color8(96, 60, 22), Color8(44, 26, 8)]
const RING := Color8(60, 150, 120)
const RING_DARK := Color8(16, 56, 44)
const GEM := Color8(200, 30, 40)
const GEM_HI := Color8(255, 150, 150)
const PANEL := Color8(14, 10, 8)
const SHIELD := Color8(70, 20, 24)
const LETTERS := Color8(250, 226, 160)
const LIT_BG := Color8(120, 70, 20)

const BODY := ("PLAYS POOL OF RADIANCE FROM YOUR OWN COPY: GOG, STEAM OR THE ORIGINAL DISKS.|"
	+ "CHOOSE THE FOLDER THAT HOLDS THE GAME'S FILES (GEO1.DAX).")
const BODY_WEB := ("PLAYS POOL OF RADIANCE FROM YOUR OWN COPY: GOG, STEAM OR THE ORIGINAL DISKS.|"
	+ "CHOOSE ITS FOLDER: THE FILES ARE COPIED INTO THIS BROWSER AND STAY ON YOUR COMPUTER.")

var _base: Image                # the frame, panels, emblem and body text (drawn once)
var _tex: ImageTexture
var _lit := 0                   # the lit menu word
var _folder := "NONE CHOSEN"
var _note := "CHOOSE OPENS A FOLDER PICKER."
var _note_color := GREEN
var _dialog: FileDialog
var _js_callback = null        # keeps the JavaScript callback alive
var _expected := 0
var _received := 0


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base = _draw_base()
	_redraw()
	if OS.has_feature("web") and GameData.is_valid_game_path(WEB_FOLDER):
		ready_to_start.emit.call_deferred(WEB_FOLDER)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _tex != null:
		draw_texture_rect(_tex, _screen_rect(), false)


## The 320 x 200 picture's place: whole multiples of the game pixel where the window allows, centred.
func _screen_rect() -> Rect2:
	var k := maxf(1.0, floorf(minf(size.x / W, size.y / H)))
	if size.x / W < 1.0 or size.y / H < 1.0:
		k = minf(size.x / W, size.y / H)
	var s := Vector2(W, H) * k
	return Rect2(((size - s) / 2).floor(), s)


# --- Drawing ----------------------------------------------------------------------------------

func _draw_base() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 15
	_panel(img, Rect2i(BAR, BAR, SPLIT_X - BAR, SPLIT_Y - BAR), rnd)
	_panel(img, Rect2i(SPLIT_X + BAR, BAR, W - BAR - SPLIT_X - BAR, SPLIT_Y - BAR), rnd)
	_panel(img, Rect2i(BAR, SPLIT_Y + BAR, W - 2 * BAR, BOTTOM - SPLIT_Y - BAR), rnd)
	_bar(img, 0, 0, W - 1, BAR - 1, true)
	_bar(img, 0, BOTTOM, W - 1, BOTTOM + BAR - 1, true)
	_bar(img, 0, SPLIT_Y, W - 1, SPLIT_Y + BAR - 1, true)
	_bar(img, 0, 0, BAR - 1, BOTTOM + BAR - 1, false)
	_bar(img, W - BAR, 0, W - 1, BOTTOM + BAR - 1, false)
	_bar(img, SPLIT_X, 0, SPLIT_X + BAR - 1, SPLIT_Y + BAR - 1, false)
	# The emblem window: a thin inner frame, small red stones at its corners, our shield.
	var ib := Rect2i(BAR + 8, BAR + 8, SPLIT_X - 9 - BAR - 8 + 1, SPLIT_Y - 9 - BAR - 8 + 1)
	_outline(img, ib, TONES[1])
	_outline(img, ib.grow(-1), TONES[3])
	_shield(img, ib.grow(-2))
	for p in [ib.position, Vector2i(ib.end.x - 1, ib.position.y), Vector2i(ib.position.x, ib.end.y - 1), ib.end - Vector2i.ONE]:
		img.fill_rect(Rect2i(p - Vector2i.ONE, Vector2i(3, 3)), GEM)
	# Stones where the bars meet.
	var h := BAR / 2
	for p in [Vector2i(h, h), Vector2i(W - 1 - h, h), Vector2i(SPLIT_X + h, h), Vector2i(h, SPLIT_Y + h),
			Vector2i(SPLIT_X + h, SPLIT_Y + h), Vector2i(W - 1 - h, SPLIT_Y + h), Vector2i(h, BOTTOM + h),
			Vector2i(W - 1 - h, BOTTOM + h)]:
		_stud(img, p)
	# The title and the text.
	var x := SPLIT_X + BAR + 6
	PixelFont.draw_text(img, x, 12, "GOLD BOX REFORGED", YELLOW)
	img.fill_rect(Rect2i(x, 24, W - BAR - 6 - x, 1), TONES[2])
	var y := 32
	var paras: PackedStringArray = (BODY_WEB if OS.has_feature("web") else BODY).split("|")
	for i in paras.size():
		if i > 0:
			y += PITCH / 2
		for line in wrap_words(paras[i], (W - BAR - 6 - x) / 8):
			PixelFont.draw_text(img, x, y, line, GREEN)
			y += PITCH
	return img


func _redraw() -> void:
	var img: Image = _base.duplicate()
	var y := SPLIT_Y + BAR + 9
	PixelFont.draw_text(img, 12, y, "FOLDER:", CYAN)
	PixelFont.draw_text(img, 12 + 8 * 8, y, _folder, WHITE)
	var ny := y + 2 * PITCH
	for line in wrap_words(_note, (W - 24) / 8).slice(0, 2):
		PixelFont.draw_text(img, 12, ny, line, _note_color)
		ny += PITCH
	# Row 24: the menu, the lit word on a bar, each word's first letter white.
	var mx := 0
	for i in MENU.size():
		var w: String = MENU[i]
		if i == _lit:
			img.fill_rect(Rect2i(mx, 192, w.length() * 8, 8), LIT_BG)
		PixelFont.draw_text(img, mx, 192, w[0], WHITE, false)
		PixelFont.draw_text(img, mx + 8, 192, w.substr(1), WHITE if i == _lit else GREEN, false)
		mx += (w.length() + 1) * 8
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	queue_redraw()


static func wrap_words(s: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for w in s.split(" ", false):
		if line != "" and line.length() + 1 + w.length() > width:
			out.append(line)
			line = w
		else:
			line = w if line == "" else line + " " + w
	out.append(line)
	return out


func _panel(img: Image, r: Rect2i, rnd: RandomNumberGenerator) -> void:
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			var v := rnd.randi_range(-3, 3) / 255.0
			img.set_pixel(xx, yy, Color(maxf(0, PANEL.r + v), maxf(0, PANEL.g + v), maxf(0, PANEL.b + v)))


## A frame bar: TONES across its thickness, the highlight edge first.
func _bar(img: Image, x0: int, y0: int, x1: int, y1: int, horizontal: bool) -> void:
	var n := TONES.size()
	if horizontal:
		var t := y1 - y0 + 1
		for k in t:
			img.fill_rect(Rect2i(x0, y0 + k, x1 - x0 + 1, 1), TONES[mini(k * n / t, n - 1)])
	else:
		var t := x1 - x0 + 1
		for k in t:
			img.fill_rect(Rect2i(x0 + k, y0, 1, y1 - y0 + 1), TONES[mini(k * n / t, n - 1)])


func _outline(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 1), c)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), c)
	img.fill_rect(Rect2i(r.position.x, r.position.y, 1, r.size.y), c)
	img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), c)


## A red stone cut in a green ring (11 pixels across).
func _stud(img: Image, c: Vector2i) -> void:
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var d2 := dx * dx + dy * dy
			var col := Color.TRANSPARENT
			if d2 <= 16:
				col = RING
			elif d2 <= 27:
				col = RING_DARK
			var m := absi(dx) + absi(dy)
			if m <= 3:
				col = GEM_HI if dy <= 0 and dx >= 0 else GEM
			if dx == -1 and dy == -1:
				col = Color.WHITE
			var x := c.x + dx
			var y := c.y + dy
			if col.a > 0 and x >= 0 and y >= 0 and x < W and y < H:
				img.set_pixel(x, y, col)


## Our own emblem: a shield in the frame's bronze with GB, pixel by pixel.
func _shield(img: Image, r: Rect2i) -> void:
	var cx := r.position.x + r.size.x / 2
	var top := r.position.y + 14
	var bot := r.end.y - 13
	var w := r.size.x / 2 - 14
	var shoulder := top + (bot - top) * 55 / 100
	for y in range(top, bot + 1):
		var half := w if y <= shoulder else int(round(w * float(bot - y) / float(bot - shoulder)))
		if half < 0:
			continue
		img.fill_rect(Rect2i(cx - half, y, 2 * half + 1, 1), TONES[3])
		var ih := half - 3
		if y > top + 2 and y < bot - 3 and ih >= 0:
			img.fill_rect(Rect2i(cx - ih, y, 2 * ih + 1, 1), SHIELD)
	img.fill_rect(Rect2i(cx - w + 3, top + 3, 2 * w - 5, 1), TONES[0])
	var ly := top + 20
	PixelFont.draw_big(img, cx - 16, ly, PixelFont.BIG_G, LETTERS)
	PixelFont.draw_big(img, cx + 2, ly, PixelFont.BIG_B, LETTERS)


# --- Keys and the mouse -----------------------------------------------------------------------

func _busy() -> bool:
	return _dialog != null and _dialog.visible


func _unhandled_input(event: InputEvent) -> void:
	if _busy() or not (event is InputEventKey) or not event.pressed:
		return
	var k: InputEventKey = event
	match k.keycode:
		KEY_LEFT, KEY_UP:
			_light((_lit + MENU.size() - 1) % MENU.size())
		KEY_RIGHT, KEY_DOWN, KEY_TAB:
			_light((_lit + 1) % MENU.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_pick(_lit)
		KEY_C:
			_pick(0)
		KEY_E:
			_pick(1)
		_:
			return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _busy() or not (event is InputEventMouse):
		return
	var word := _word_at(event.position)
	if event is InputEventMouseMotion:
		if word >= 0:
			_light(word)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and word >= 0:
		_pick(word)
		accept_event()


## The menu word under a point (local pixels), or -1.
func _word_at(p: Vector2) -> int:
	var r := _screen_rect()
	var g := (p - r.position) / (r.size.x / W)
	if g.y < 192 or g.y >= 200:
		return -1
	var mx := 0
	for i in MENU.size():
		var n: int = MENU[i].length()
		if g.x >= mx and g.x < mx + n * 8:
			return i
		mx += (n + 1) * 8
	return -1


func _light(i: int) -> void:
	if i != _lit:
		_lit = i
		_redraw()


func _pick(i: int) -> void:
	_light(i)
	if i == 1:
		get_tree().quit()
	else:
		_choose()


func _say(text: String, color := GREEN) -> void:
	_note = text
	_note_color = color
	_redraw()


func _choose() -> void:
	if OS.has_feature("web"):
		_choose_web()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = OS.get_name() in ["Windows", "macOS"]
		_dialog.title = "Pool of Radiance folder (the one holding GEO1.DAX)"
		_dialog.dir_selected.connect(_on_dir)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


## Accepts the game's folder or the POOLRAD folder inside it.
static func resolve(path: String) -> String:
	for p in [path, path.path_join("POOLRAD"), path.path_join("Pool of Radiance/POOLRAD")]:
		if GameData.is_valid_game_path(p):
			return p
	return ""


## A path cut to fit n letters (its end kept).
static func fit(path: String, n: int) -> String:
	return path if path.length() <= n else "..." + path.right(n - 3)


func _on_dir(path: String) -> void:
	_folder = fit(path, 28)
	var found := resolve(path)
	if found == "":
		_say("NO GEO1.DAX IN THAT FOLDER: CHOOSE THE ONE THAT HOLDS THE GAME'S FILES.", RED)
		return
	GameData.save_game_path(found)
	ready_to_start.emit(found)


# --- Web ------------------------------------------------------------------------------------

func _choose_web() -> void:
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window = JavaScriptBridge.get_interface("window")
	window.gbrFile = _js_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.webkitdirectory = true;
			input.multiple = true;
			input.onchange = async function () {
				var files = Array.from(input.files);
				window.gbrFile('count', files.length, '');
				for (var f of files) {
					var buf = new Uint8Array(await f.arrayBuffer());
					var bin = '';
					for (var i = 0; i < buf.length; i += 8192)
						bin += String.fromCharCode.apply(null, buf.subarray(i, i + 8192));
					window.gbrFile('file', f.name, btoa(bin));
				}
				window.gbrFile('done', 0, '');
			};
			input.click();
		})();
	""", true)
	_say("WAITING FOR THE FOLDER...")


func _on_web_file(args: Array) -> void:
	var kind := str(args[0])
	match kind:
		"count":
			_expected = int(args[1])
			_received = 0
			DirAccess.make_dir_recursive_absolute(WEB_FOLDER)
		"file":
			_received += 1
			var name := str(args[1]).to_upper()
			if name.get_extension() in WANTED or name in WANTED_NAMES:
				var f := FileAccess.open(WEB_FOLDER.path_join(name), FileAccess.WRITE)
				if f != null:
					f.store_buffer(Marshalls.base64_to_raw(str(args[2])))
					f.close()
			_say("COPYING THE GAME'S FILES: %d OF %d" % [_received, _expected])
		"done":
			if GameData.is_valid_game_path(WEB_FOLDER):
				GameData.save_game_path(WEB_FOLDER)
				ready_to_start.emit(WEB_FOLDER)
			else:
				_say("NO GEO1.DAX IN THAT FOLDER: CHOOSE THE ONE THAT HOLDS THE GAME'S FILES.", RED)

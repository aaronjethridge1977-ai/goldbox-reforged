class_name MouseInput
extends RefCounted
## QoL (Jeremy's C11-1, option b, 2026-11-16): the mouse does what a key does, menus first.
## A click on a menu word (row 24's hot-letter menus, drawn by GameScreen.menu_line) presses its
## hot letter; the word under the pointer lights as the highlighted item does; the right button
## is Esc; the wheel is Up / Down. Nothing new happens that a key couldn't do. SETTINGS: USE MOUSE
## (on by default). The original reads no mouse in Pool of Radiance's DOS version.

const SETTINGS_KEY := "mouse"

static var _cached := -1


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


## Presses and releases a key as if typed (the screens read it as they read the keyboard).
static func press(keycode: Key, unicode: int = 0) -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.keycode = keycode
		k.physical_keycode = keycode
		k.unicode = unicode
		k.pressed = down
		Input.parse_input_event(k)


## A menu word's hot letter as a key press.
static func press_letter(letter: String) -> void:
	if letter == "":
		return
	var code := OS.find_keycode_from_string(letter.to_upper())
	if code != KEY_NONE:
		press(code, letter.to_lower().unicode_at(0))

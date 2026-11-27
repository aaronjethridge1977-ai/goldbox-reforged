class_name KeyBurst
extends RefCounted
## Keys typed while a screen waits with no key read (a script DELAY, a note, a spell's text): the menu after the wait
## takes them as the original's get-key does (START.EXE 0x899:0x59; main chat 127, DOSBox at speed 4): it reads one
## character; if it isn't 0 it reads every key still waiting and keeps the last byte; if it is 0 (an extended key)
## the caller reads the scan code, and that read drains the same way. So a burst's FIRST key decides plain or extended
## and its LAST byte the value: Down then Enter is an extended key with scan 0x0D (nothing); Enter then Down is 'P'.
## One kind throughout is simply the last key. Keys that type nothing (Shift, Ctrl) never reach the BIOS buffer.
## The rule as main.gd's `_type_ahead_add` / `_dos_burst` (the same tables, kept here for the screens' own waits).

## The DOS keyboard's extended keys (sent as 0 then this scan code) by ours' key (main.gd's DOS_SCANS).
const DOS_SCANS := {KEY_UP: 0x48, KEY_DOWN: 0x50, KEY_LEFT: 0x4B, KEY_RIGHT: 0x4D, KEY_HOME: 0x47, KEY_END: 0x4F,
	KEY_PAGEUP: 0x49, KEY_PAGEDOWN: 0x51, KEY_INSERT: 0x52, KEY_DELETE: 0x53, KEY_F1: 0x3B, KEY_F2: 0x3C, KEY_F3: 0x3D,
	KEY_F4: 0x3E, KEY_F5: 0x3F, KEY_F6: 0x40, KEY_F7: 0x41, KEY_F8: 0x42, KEY_F9: 0x43, KEY_F10: 0x44}
## Alt and a letter: the BIOS sends 0 then the letter key's scan code (Alt-M is 0x32: a fight's poll, GAME.OVR 0xBB81).
const ALT_SCANS := {KEY_Q: 0x10, KEY_W: 0x11, KEY_E: 0x12, KEY_R: 0x13, KEY_T: 0x14, KEY_Y: 0x15, KEY_U: 0x16,
	KEY_I: 0x17, KEY_O: 0x18, KEY_P: 0x19, KEY_A: 0x1E, KEY_S: 0x1F, KEY_D: 0x20, KEY_F: 0x21, KEY_G: 0x22, KEY_H: 0x23,
	KEY_J: 0x24, KEY_K: 0x25, KEY_L: 0x26, KEY_Z: 0x2C, KEY_X: 0x2D, KEY_C: 0x2E, KEY_V: 0x2F, KEY_B: 0x30, KEY_N: 0x31,
	KEY_M: 0x32}

var _first_ext := false
var _last: InputEventKey = null


## A key typed during the wait.
func add(ev: InputEventKey) -> void:
	var ext := is_ext(ev)
	if not ext and dos_char(ev) < 0:
		return
	if _last == null:
		_first_ext = ext
	_last = ev


func has_key() -> bool:
	return _last != null


func clear() -> void:
	_last = null


## What the menu after the wait reads (null: nothing, or an extended scan code no key has); the burst is emptied.
func take() -> InputEventKey:
	if _last == null:
		return null
	var ev := burst(_first_ext, _last)
	_last = null
	return ev


## The byte the get-key's drain keeps for the burst (-1: nothing waits): the last key's character, or its scan code
## for an extended key (the first key's kind doesn't change it). The burst is emptied.
func take_byte() -> int:
	if _last == null:
		return -1
	var b := dos_byte(_last)
	_last = null
	return b


## An extended key (0 then a scan code): the DOS_SCANS keys and Alt with a letter.
static func is_ext(ev: InputEventKey) -> bool:
	return DOS_SCANS.has(ev.keycode) or (ev.alt_pressed and ALT_SCANS.has(ev.keycode))


## A key's last byte in the BIOS buffer: an extended key's scan code, else its character (-1: none).
static func dos_byte(ev: InputEventKey) -> int:
	if DOS_SCANS.has(ev.keycode):
		return DOS_SCANS[ev.keycode]
	if ev.alt_pressed and ALT_SCANS.has(ev.keycode):
		return ALT_SCANS[ev.keycode]
	return dos_char(ev)


## A digit at a menu that takes extended keys (GAME.OVR's menu routine 0x2CC8C with its extended flag set, and every
## list through 0x2D8A0): 0x2CF60 turns 1-4 and 6-9 into the keypad's scan codes (DS:0x288C: End, Down, PgDn, Left,
## Right, Home, Up, PgUp), as a DOS keypad with Num Lock types them, top row and keypad alike (main chat 157, DOSBox at
## 3:0's arms and armour shop: 1 moves the buyer down as End, 7 at APPRAISE appraises a gem as Home; 2 does nothing
## there). 8 and 2 come back as the keypad's Up / Down, not the arrows ours' lists also take as Home / End (P33/P45).
## Returns `ev` itself for any other key.
const EXT_DIGITS := {KEY_1: KEY_END, KEY_2: KEY_KP_2, KEY_3: KEY_PAGEDOWN, KEY_4: KEY_LEFT, KEY_6: KEY_RIGHT,
		KEY_7: KEY_HOME, KEY_8: KEY_KP_8, KEY_9: KEY_PAGEUP, KEY_KP_1: KEY_END, KEY_KP_3: KEY_PAGEDOWN,
		KEY_KP_4: KEY_LEFT, KEY_KP_6: KEY_RIGHT, KEY_KP_7: KEY_HOME, KEY_KP_9: KEY_PAGEUP}


static func ext_digit(ev: InputEventKey) -> InputEventKey:
	if ev.ctrl_pressed or ev.alt_pressed or not EXT_DIGITS.has(ev.keycode):
		return ev
	var e := InputEventKey.new()
	e.pressed = true
	e.echo = ev.echo
	e.keycode = EXT_DIGITS[ev.keycode]
	e.physical_keycode = e.keycode
	e.key_label = e.keycode
	return e


## What a screen's menu reads for a key typed with Ctrl or Alt (main chat 129's request, DOSBox at 3:0's camp: Ctrl+V
## and Alt+V do nothing; main.gd's walking screen and _input_char the same): Ctrl and a letter types a control code
## (1-26: no menu letter), except Ctrl+M (0x0D, Enter's), Ctrl+H (Backspace's) and Ctrl+[ (Escape's); Alt and a letter
## or digit is an extended key with its own scan code (no menu letter, no arrow). Returns the key to act on: the event
## itself (no Ctrl or Alt, or an F-key, Escape), Enter / Backspace / Escape for those three, or null (nothing). `keep`
## lists Alt keys a screen reads itself (the fight's Alt-M MAGIC and Alt-Q QUICK).
static func menu_key(ev: InputEventKey, keep: Array = []) -> InputEventKey:
	if not (ev.ctrl_pressed or ev.alt_pressed):
		return ev
	var k := ev.keycode
	if (k >= KEY_F1 and k <= KEY_F12) or k == KEY_ESCAPE or k in [KEY_SHIFT, KEY_CTRL, KEY_ALT]:
		return ev
	if ev.alt_pressed and not ev.ctrl_pressed:
		return ev if k in keep else null
	if ev.ctrl_pressed and not ev.alt_pressed:
		var to := KEY_NONE
		match k:
			KEY_M:
				to = KEY_ENTER
			KEY_H:
				to = KEY_BACKSPACE
			KEY_BRACKETLEFT:
				to = KEY_ESCAPE
		if to != KEY_NONE:
			var e := InputEventKey.new()
			e.pressed = true
			e.echo = ev.echo
			e.keycode = to
			e.physical_keycode = to
			e.key_label = to
			return e
	return null


## A plain key's DOS character (-1: a key that types nothing).
static func dos_char(ev: InputEventKey) -> int:
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			return 13
		KEY_ESCAPE:
			return 27
		KEY_BACKSPACE:
			return 8
		KEY_TAB:
			return 9
		KEY_SPACE:
			return 32     # (the lab's timed= Space carries no unicode)
	if ev.keycode >= KEY_KP_0 and ev.keycode <= KEY_KP_9:
		return 48 + ev.keycode - KEY_KP_0
	return ev.unicode if ev.unicode > 0 and ev.unicode < 127 else -1


static func burst(first_ext: bool, last: InputEventKey) -> InputEventKey:
	var last_ext := is_ext(last)
	if first_ext == last_ext:
		return last
	var e := InputEventKey.new()
	e.pressed = true
	if not first_ext:
		var scan: int = dos_byte(last)
		e.keycode = scan as Key      # the scan code as a character: Godot's keycode for an ASCII capital is its code
		e.unicode = scan
		return e
	var c := dos_char(last)
	for k in DOS_SCANS:
		if DOS_SCANS[k] == c:
			e.keycode = k
			return e
	return null

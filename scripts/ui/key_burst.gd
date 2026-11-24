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

var _first_ext := false
var _last: InputEventKey = null


## A key typed during the wait.
func add(ev: InputEventKey) -> void:
	var ext := DOS_SCANS.has(ev.keycode)
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
	if ev.keycode >= KEY_KP_0 and ev.keycode <= KEY_KP_9:
		return 48 + ev.keycode - KEY_KP_0
	return ev.unicode if ev.unicode > 0 and ev.unicode < 127 else -1


static func burst(first_ext: bool, last: InputEventKey) -> InputEventKey:
	var last_ext := DOS_SCANS.has(last.keycode)
	if first_ext == last_ext:
		return last
	var e := InputEventKey.new()
	e.pressed = true
	if not first_ext:
		var scan: int = DOS_SCANS[last.keycode]
		e.keycode = scan as Key      # the scan code as a character: Godot's keycode for an ASCII capital is its code
		e.unicode = scan
		return e
	var c := dos_char(last)
	for k in DOS_SCANS:
		if DOS_SCANS[k] == c:
			e.keycode = k
			return e
	return null

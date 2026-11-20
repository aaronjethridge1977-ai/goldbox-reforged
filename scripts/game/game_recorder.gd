class_name GameRecorder
extends RefCounted
## SETTINGS: RECORD MY GAME (Jeremy, 2026-11-20 07:40, through the Lead; default off). While on, each game
## loaded or started writes a session file the lab can replay exactly in ours: the build's version, the dice
## seed (every generator is seeded with it before the load), the starting save's files and the SETTINGS
## switches, then every key pressed with its time. Written to `user://recordings/<date>-<time>.gbrrec`
## (Windows: %APPDATA%\Godot\app_userdata\Gold Box Reforged\recordings\; Linux:
## ~/.local/share/godot/app_userdata/Gold Box Reforged/recordings/). JSON, a line each: the header first, then
## {"t": ms since the start, "k": key name, "m": "shift+alt+ctrl" modifiers if any}. Keys only: mouse clicks
## are not recorded yet. tools/lab/replay_recording.py turns a file into ours' --keys replay.
## Never in a lab run (OriginalBugs.lab_run: the replays would record themselves).

const KEY := "record_game"
const DIR := "user://recordings"

static var _file: FileAccess = null
static var _t0 := 0


static func enabled() -> bool:
	if OriginalBugs.lab_run():
		return false
	var cf := ConfigFile.new()
	return cf.load(GameData.SETTINGS_PATH) == OK and bool(cf.get_value("qol", KEY, false))


static func save(value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", KEY, value)
	cf.save(GameData.SETTINGS_PATH)
	if not value:
		stop()


## A new session: `kind` "slot" (the original's save `letter`), "quick" (ours' quick save) or "new" (a new
## game); `files` the starting save's files (name -> path). Returns the seed the caller must seed every
## generator with before loading, or -1 when not recording.
static func begin(kind: String, letter: String, files: Dictionary) -> int:
	stop()
	if not enabled():
		return -1
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var path := "%s/%s.gbrrec" % [DIR, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return -1
	var seed_value := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	seed_value &= 0x7FFFFFFF
	var saved := {}
	for name in files:
		var bytes := FileAccess.get_file_as_bytes(String(files[name]))
		if not bytes.is_empty():
			saved[name] = Marshalls.raw_to_base64(bytes)
	var qol := {}
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) == OK and cf.has_section("qol"):
		for k in cf.get_section_keys("qol"):
			qol[k] = cf.get_value("qol", k)
	_file.store_line(JSON.stringify({"format": 1, "build": str(ProjectSettings.get_setting("application/config/version", "")),
		"date": Time.get_datetime_string_from_system(), "seed": seed_value, "start": kind, "letter": letter,
		"files": saved, "qol": qol}))
	_file.flush()
	_t0 = Time.get_ticks_msec()
	return seed_value


## Each key pressed (main.gd's _input).
static func key(ev: InputEventKey) -> void:
	if _file == null or not ev.pressed or ev.echo:
		return
	var line := {"t": Time.get_ticks_msec() - _t0, "k": OS.get_keycode_string(ev.keycode)}
	var mods := PackedStringArray()
	if ev.shift_pressed:
		mods.append("shift")
	if ev.alt_pressed:
		mods.append("alt")
	if ev.ctrl_pressed:
		mods.append("ctrl")
	if not mods.is_empty():
		line["m"] = "+".join(mods)
	_file.store_line(JSON.stringify(line))
	_file.flush()


static func stop() -> void:
	if _file != null:
		_file.close()
		_file = null

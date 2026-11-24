class_name GameRecorder
extends RefCounted
## SETTINGS: RECORD MY GAME (Jeremy, 2026-11-20 07:40, through the Lead; default off). While on, each game
## loaded or started writes a session file the lab can replay exactly in ours: the build's version, the dice
## seed (every generator is seeded with it before the load), the starting save's files and the SETTINGS
## switches, then every key pressed with its time. Written to `user://recordings/<date>-<time>.gbrrec`
## (Windows: %APPDATA%\Godot\app_userdata\Gold Box Reforged\recordings\; Linux:
## ~/.local/share/godot/app_userdata/Gold Box Reforged/recordings/). JSON, a line each: the header first, then
## {"t": ms since the start, "k": key name, "m": "shift+alt+ctrl" modifiers if any}. The mouse (main chat 73):
## a click a screen turns into keys (a menu word, a list line, the view, the fight's field, the wheel, the right
## button) is recorded as those keys; a click no screen takes as keys (the GUI leaves it unhandled: PRESS ENTER,
## a message ended by any key) is {"t", "c": mouse button index}. tools/lab/replay_recording.py turns a file into
## ours' --keys replay (a "c" line is `click<n>`, main.gd's replay presses that button off any menu).
## Never in a lab run (OriginalBugs.lab_run: the replays would record themselves).

const KEY := "record_game"
const DIR := "user://recordings"

static var _file: FileAccess = null
static var _t0 := 0
static var _tap: Node = null


## Main chat 73: the recorder listens from a node of its own, the root's last child, so its _input comes first
## (Godot calls _input from the last node up): a key a screen takes in its own _input (the quest log) is recorded
## too, and its _unhandled_input sees the clicks no screen made into keys. Called from main's _ready (and again
## after F3's scene reload, which adds main after it).
static func attach(tree: SceneTree) -> void:
	if _tap == null or not is_instance_valid(_tap):
		_tap = Tap.new()
		_tap.name = "GameRecorderTap"
		tree.root.add_child.call_deferred(_tap)
	elif _tap.is_inside_tree():
		_tap.get_parent().move_child.call_deferred(_tap, -1)


class Tap extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			GameRecorder.key(event)

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			GameRecorder.click(event)


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
## generator with before loading, or -1 when not recording. `extra` goes into the header (a slot load's script
## memory before the load: main.gd's _record_start).
static func begin(kind: String, letter: String, files: Dictionary, extra: Dictionary = {}) -> int:
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
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var commit := build_commit()
	_file.store_line(JSON.stringify({"format": 1, "build": version if commit == "" else "%s (%s)" % [version, commit],
		"commit": commit, "date": Time.get_datetime_string_from_system(), "seed": seed_value, "start": kind, "letter": letter,
		"files": saved, "qol": qol}.merged(extra)))
	_file.flush()
	_t0 = Time.get_ticks_msec()
	return seed_value


## The commit the game runs from (main chat 109, the coach's request: editor runs and test builds all said "0.1.6", so a
## recording didn't say which build it replays on): a build's is stamped into its project.godot by tools/build's scripts
## (application/config/build_commit); a run from a checkout reads .git. "" when neither is there.
static func build_commit() -> String:
	var c := str(ProjectSettings.get_setting("application/config/build_commit", ""))
	if c != "":
		return c
	var git := ProjectSettings.globalize_path("res://").path_join(".git")
	var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref: "):
		return head.left(7)
	var ref := head.trim_prefix("ref: ")
	var sha := FileAccess.get_file_as_string(git.path_join(ref)).strip_edges()
	if sha == "":
		for line in FileAccess.get_file_as_string(git.path_join("packed-refs")).split("\n"):
			if line.ends_with(" " + ref):
				sha = line.get_slice(" ", 0)
	return sha.left(7)


## Each key pressed (the Tap's _input), the keys a click makes included. A held key's repeats too, marked "e": 1
## (main chat 128: the walking screen steps and turns on them, so a recording without them replayed a held arrow as
## one step).
static func key(ev: InputEventKey) -> void:
	if _file == null or not ev.pressed:
		return
	var line := {"t": Time.get_ticks_msec() - _t0, "k": OS.get_keycode_string(ev.keycode)}
	if ev.echo:
		line["e"] = 1
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


## A mouse button press no screen took as keys (the Tap's _unhandled_input).
static func click(ev: InputEventMouseButton) -> void:
	if _file == null or not ev.pressed:
		return
	_file.store_line(JSON.stringify({"t": Time.get_ticks_msec() - _t0, "c": int(ev.button_index)}))
	_file.flush()


static func stop() -> void:
	if _file != null:
		_file.close()
		_file = null

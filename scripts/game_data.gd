class_name GameData
extends RefCounted
## Locates the player's own Pool of Radiance (DOS) data folder.
##
## Search order:
##   1. Command line:  --game-path="D:/path/to/POOLRAD"  (after `--` when run from the editor)
##   2. Settings file: user://settings.cfg, key [game] path
##   3. Default:       "<project folder>/Pool of Radiance/POOLRAD" (the GOG install copied beside the project),
##                     or the same path beside the executable in exported builds

const DEFAULT_SUBPATH := "Pool of Radiance/POOLRAD"
const SETTINGS_PATH := "user://settings.cfg"
## A file every DOS copy of Pool of Radiance has; used to confirm the folder is right.
const MARKER_FILE := "GEO1.DAX"


static func find_game_path() -> String:
	for candidate in _candidates():
		if is_valid_game_path(candidate):
			return candidate
	return ""


static func is_valid_game_path(path: String) -> bool:
	return path != "" and exists(path.path_join(MARKER_FILE))


## The game's files are looked up without regard to case (Lead, 2026-11-19, chat 67): a Linux
## player's copy may hold lower-case names (taken from disks, some installers), and Linux file
## systems tell GEO1.DAX from geo1.dax. `path` as written when that file is there; otherwise the
## file in the same folder whose name differs only in case; otherwise `path` unchanged (so a new
## file is made with the name ours gives it, and a missing one stays missing). On Windows and Mac
## the first test answers. Saving over a save keeps the name the file already has.
static func real_path(path: String) -> String:
	if path == "" or FileAccess.file_exists(path):
		return path
	var dir_path := path.get_base_dir()
	var want := path.get_file().to_upper()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return path
	for f in dir.get_files():
		if f.to_upper() == want:
			return dir_path.path_join(f)
	return path


## FileAccess.file_exists, blind to the name's case (real_path).
static func exists(path: String) -> bool:
	return FileAccess.file_exists(real_path(path))


## FileAccess.get_file_as_bytes, blind to the name's case (real_path).
static func read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(real_path(path))


## Lists the data files in the game folder, sorted by name, in upper case (the names the engine
## asks for; real_path finds a file whose name is in lower case).
static func list_files(path: String, extension: String = "") -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if extension == "" or file_name.get_extension().to_upper() == extension.to_upper():
			result.append(file_name.to_upper())
	result.sort()
	return result


static func save_game_path(path: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("game", "path", path)
	config.save(SETTINGS_PATH)


static func _candidates() -> PackedStringArray:
	var result := PackedStringArray()
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--game-path="):
			result.append(arg.trim_prefix("--game-path=").trim_prefix("\"").trim_suffix("\""))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		result.append(str(config.get_value("game", "path", "")))
	result.append(ProjectSettings.globalize_path("res://").path_join(DEFAULT_SUBPATH))
	# Exported builds: look beside the executable.
	result.append(OS.get_executable_path().get_base_dir().path_join(DEFAULT_SUBPATH))
	return result

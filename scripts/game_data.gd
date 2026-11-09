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
	return path != "" and FileAccess.file_exists(path.path_join(MARKER_FILE))


## Lists the data files in the game folder, sorted by name.
static func list_files(path: String, extension: String = "") -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if extension == "" or file_name.get_extension().to_upper() == extension.to_upper():
			result.append(file_name)
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

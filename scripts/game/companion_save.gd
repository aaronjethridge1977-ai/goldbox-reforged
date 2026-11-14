class_name CompanionSave
extends RefCounted
## Our additions to one of the original's saved games, in a file of their own beside it
## (decided, Methods 3, 2026-11-14): SAVGAM<letter>.GBR in the game folder, next to
## SAVGAM<letter>.DAT. The original's files stay byte for byte the original's, so the save
## still loads in DOSBox.
##
## A ConfigFile:
##   [save] savgam_sha256  the SHA-256 of SAVGAM<letter>.DAT as it was written with this
##                         companion. One that doesn't match (the slot saved over by the
##                         original, or by a build without companions) is stale: ignored.
##   [qol]  visited        the automap's squares (Automap.to_save()).
## Later additions (the quest tracker...) go in [qol] beside it.
## No companion, or a stale one: the game loads with an empty map, which maps from there.


static func path(game_path: String, letter: String) -> String:
	return game_path.path_join("SAVGAM%s.GBR" % letter.to_upper())


static func _savgam(game_path: String, letter: String) -> String:
	return game_path.path_join("SAVGAM%s.DAT" % letter.to_upper())


## Writes the companion for the save just written in that slot. `qol`: key -> value.
static func write(game_path: String, letter: String, qol: Dictionary) -> bool:
	var hash := FileAccess.get_sha256(_savgam(game_path, letter))
	if hash == "":
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("save", "savgam_sha256", hash)
	for k in qol:
		cfg.set_value("qol", k, qol[k])
	return cfg.save(path(game_path, letter)) == OK


## The slot's [qol] values, or {} when there is no companion or it belongs to another save.
static func read(game_path: String, letter: String) -> Dictionary:
	var p := path(game_path, letter)
	if not FileAccess.file_exists(p):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return {}
	if String(cfg.get_value("save", "savgam_sha256", "")) != FileAccess.get_sha256(_savgam(game_path, letter)):
		print("   (the automap of saved game %s belongs to an older save: not loaded)" % letter.to_upper())
		return {}
	var out := {}
	if cfg.has_section("qol"):
		for k in cfg.get_section_keys("qol"):
			out[k] = cfg.get_value("qol", k)
	return out

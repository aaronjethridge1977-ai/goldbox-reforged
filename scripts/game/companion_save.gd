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
##          label          the player's own name for the save (set_label; the save/load menu).
## Later additions (the quest tracker...) go in [qol] beside it.
## No companion, or a stale one: the game loads with an empty map, which maps from there.


static func path(game_path: String, letter: String) -> String:
	return game_path.path_join("SAVGAM%s.GBR" % letter.to_upper())


static func _savgam(game_path: String, letter: String) -> String:
	return GameData.real_path(game_path.path_join("SAVGAM%s.DAT" % letter.to_upper()))


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


## Sets (or with "" clears) the player's own name for the slot's save ([qol] label; Q10, chat 39),
## keeping the companion's other values. A missing or stale companion gives one holding the label
## alone (a stale one's map belongs to another save). False when the slot has no save.
static func set_label(game_path: String, letter: String, label: String) -> bool:
	if not FileAccess.file_exists(_savgam(game_path, letter)):
		return false
	var qol := read(game_path, letter, true)
	label = clean_label(label)
	if label == "":
		qol.erase("label")
	else:
		qol["label"] = label
	return write(game_path, letter, qol)


## A label as kept: spaces at the ends dropped, capitals (the original's font has no small
## letters), at most LABEL_MAX characters.
static func clean_label(label: String) -> String:
	return label.strip_edges().to_upper().left(LABEL_MAX).strip_edges()


const LABEL_MAX := 24


## "none" (no companion), "ok" (it belongs to the slot's save) or "stale" (another save's), quietly
## (the save list, SaveSlots).
static func state(game_path: String, letter: String) -> String:
	var p := path(game_path, letter)
	if not FileAccess.file_exists(p):
		return "none"
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return "stale"
	var ok := String(cfg.get_value("save", "savgam_sha256", "")) == FileAccess.get_sha256(_savgam(game_path, letter))
	return "ok" if ok else "stale"


## The slot's [qol] values, or {} when there is no companion or it belongs to another save.
## `quiet`: no line about a stale companion (the save list reads every slot).
static func read(game_path: String, letter: String, quiet: bool = false) -> Dictionary:
	var p := path(game_path, letter)
	if not FileAccess.file_exists(p):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return {}
	if String(cfg.get_value("save", "savgam_sha256", "")) != FileAccess.get_sha256(_savgam(game_path, letter)):
		if not quiet:
			print("   (the automap of saved game %s belongs to an older save: not loaded)" % letter.to_upper())
		return {}
	var out := {}
	if cfg.has_section("qol"):
		for k in cfg.get_section_keys("qol"):
			out[k] = cfg.get_value("qol", k)
	return out

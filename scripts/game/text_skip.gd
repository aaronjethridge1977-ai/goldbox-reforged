class_name TextSkip
## P156 (Jeremy, 2026-11-27 20:04, QoL): SETTINGS' TEXT SKIP, on by default. A script's timed text (the hold while
## it "types" and its DELAY) ends at once on any key or click, after a floor of SKIP_FLOOR_MS so a key held or typed
## as the text appears can't skip it unread. Texts the original waits on (PRESS RETURN, questions, menus, inputs) wait
## as before. Off: as the original, which reads no key during the hold (a key typed then waits for the next reader).
## Every lab run has it off (OriginalBugs.lab_run(): --keys=, tpseed=, GBR_ORIGINAL_BUGS=1; and the bot's --play=),
## so the differential checks and the match keep the original's meaning of a key typed during a hold. A RECORD MY
## GAME replay plays the session's own switch (kept in the settings' "qol" section).

const KEY := "text_skip"
const SKIP_FLOOR_MS := 300
static var _on := -1      # -1: not read yet


static func on() -> bool:
	if OriginalBugs.lab_run():
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--play="):
			return false
	return setting()


## The switch itself (SETTINGS shows it whatever the run).
static func setting() -> bool:
	if _on < 0:
		var cf := ConfigFile.new()
		_on = 1
		if cf.load(GameData.SETTINGS_PATH) == OK:
			_on = int(bool(cf.get_value("qol", KEY, true)))
	return _on == 1


static func save_on(value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", KEY, value)
	cf.save(GameData.SETTINGS_PATH)
	_on = int(value)

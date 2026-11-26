class_name WalkPace
## P119 (Jeremy, 2026-11-26 08:04): SETTINGS' WALK PACE, ORIGINAL (the default) or FAST (QoL).
## ORIGINAL: after a step or a turn the walking screen holds keys while the view redraws, as the original does (chat 128:
## ~0.3 s a step, ~0.16 s a turn, a held arrow walking about every 0.3 s; main.gd's _redraw_hold). FAST: no hold, the
## pace before that fix: every key and every repeat of a held one acts at once.
## Kept in the settings' "qol" section, so a RECORD MY GAME recording carries it and its replay walks at its pace.

const KEY := "walk_pace_fast"
static var _fast := -1      # -1: not read yet


static func fast() -> bool:
	if _fast < 0:
		var cf := ConfigFile.new()
		_fast = 1 if cf.load(GameData.SETTINGS_PATH) == OK and bool(cf.get_value("qol", KEY, false)) else 0
	return _fast == 1


static func save_fast(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", KEY, on)
	cf.save(GameData.SETTINGS_PATH)
	_fast = 1 if on else 0

class_name SaveSlots
extends RefCounted
## The save/load menu's data side (QoL 5, R2; chat 38): what each slot holds, as a list a screen can
## read. Draws nothing and changes nothing (the screen is Combat's; the mockup is on the board).
##
## Slots: the original's ten saved games A-J (SAVGAM<letter>.DAT with its CHRDAT<letter>n files, and
## ours' companion SAVGAM<letter>.GBR beside it: CompanionSave), and ours' quick save (F2 / F3: one
## ConfigFile, main.gd's _quick_save). Each entry is a Dictionary:
##   kind        "game" (A-J) or "quick"
##   slot        "A".."J" or "QUICK"
##   path        the file
##   exists      false for an empty letter (then only kind, slot, path)
##   ok          false when the file is there but can't be read (then "error" says why)
##   started     false for a game saved from the party menu before the adventure (no area)
##   set, block  the area's ECL data set and block ("2:20"); block -1 when not found
##   area        the area's name in capitals (AreaNames: content/poolrad/areas.json), or "AREA 2:20"
##               where the table has none
##   area_confirmed  whether Jeremy has confirmed that name (the table ships before he has: a
##               screen may mark the unconfirmed ones); absent for "PARTY MENU" / "AREA n:?"
##   x, y, facing  the party's square and facing (0..3 = N E S W); facing_text "N"
##   clock       {"year", "month", "day", "hour", "minute"}: the game's clock (GameClock's counters)
##   day         the adventure's day, from 1 (a new game starts on day 0 of month 0 of year 0, 10:50)
##   time_text   "DAY 1 10:56"
##   party       [{"name", "class", "hp", "hp_max", "status"}] in party order (status: STATUS_NAMES)
##   saved_at    the file's modified time (unix seconds; the screen shows the real date)
##   companion   "none", "ok" or "stale" (a quick save holds everything itself: "ok")
##   map         whether the automap's squares come with it
##   label       the player's own name for the slot ([qol] label in the companion, ours' addition;
##               "" when none: the original's saves have no names)

const LETTERS := "ABCDEFGHIJ"
const FACING := ["N", "E", "S", "W"]

## Decoded scripts per data set, for finding a save's area (several slots share a set).
static var _codes := {}


## Every slot, A-J then the quick save (if `quick_path` is given), empty letters included.
static func list(game_path: String, quick_path: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in LETTERS:
		out.append(read_game(game_path, c))
	if quick_path != "":
		out.append(read_quick(quick_path))
	return out


## Names a slot's save (the menu's NAME; "" clears it): A-J in its companion file
## (CompanionSave.set_label), "QUICK" in the quick save itself ([qol] label). Saving a game
## writes a new companion without a name, so a screen names the slot after the save is written.
## False when the slot is empty or the file can't be written.
static func set_label(game_path: String, slot: String, label: String, quick_path: String = "") -> bool:
	if slot.to_upper() != "QUICK":
		return CompanionSave.set_label(game_path, slot, label)
	var cfg := ConfigFile.new()
	if quick_path == "" or cfg.load(quick_path) != OK:
		return false
	label = CompanionSave.clean_label(label)
	if label == "":
		if cfg.has_section_key("qol", "label"):
			cfg.erase_section_key("qol", "label")
	else:
		cfg.set_value("qol", "label", label)
	return cfg.save(quick_path) == OK


## One of the original's saved games.
static func read_game(game_path: String, letter: String) -> Dictionary:
	letter = letter.to_upper()
	var path := game_path.path_join("SAVGAM%s.DAT" % letter)
	var e := {"kind": "game", "slot": letter, "path": path, "exists": FileAccess.file_exists(path)}
	if not e.exists:
		return e
	var s := FileAccess.get_file_as_bytes(path)
	if s.size() < 0x3300:
		return _bad(e, "too short (%d bytes)" % s.size())
	e.saved_at = FileAccess.get_modified_time(path)
	var started := false
	for b in s.slice(OriginalSave.SCRIPT_AT, OriginalSave.SCRIPT_AT + OriginalSave.SCRIPT_BYTES):
		if b != 0:
			started = true
			break
	e.started = started
	e.set = s[0]
	e.block = area_block(game_path, s) if started else -1
	e.x = s[OriginalSave.POS_AT]
	e.y = s[OriginalSave.POS_AT + 1]
	e.facing = (s[OriginalSave.POS_AT + 2] / 2) & 3
	var cell := func(a: int) -> int: return s[1 + 2 * (a - 0x4900)]
	_clock(e, [cell.call(0x49C6), cell.call(0x49C7), cell.call(0x49C8), cell.call(0x49C9), cell.call(0x49CA),
		cell.call(0x49CB), s[1 + 2 * (0x49CC - 0x4900)] | (s[2 + 2 * (0x49CC - 0x4900)] << 8)])
	var party: Array[Dictionary] = []
	for k in 8:
		var o := OriginalSave.NAMES_AT + k * 41
		var n := s[o]
		if n <= 0 or n > 12:
			continue
		var stem := game_path.path_join(s.slice(o + 1, o + 1 + n).get_string_from_ascii())
		var rec := FileAccess.get_file_as_bytes(stem + ".SAV")
		if rec.size() >= 285:     # a name whose file is gone: the load skips it too
			party.append(_member(rec))
	e.party = party
	e.companion = CompanionSave.state(game_path, letter)
	var extra := CompanionSave.read(game_path, letter, true)
	var visited = extra.get("visited", {})
	e.map = visited is Dictionary and (visited as Dictionary).size() > 0
	e.label = String(extra.get("label", ""))
	_place(e)
	e.ok = true
	return e


## Ours' quick save (main.gd's _quick_save writes it).
static func read_quick(path: String) -> Dictionary:
	var e := {"kind": "quick", "slot": "QUICK", "path": path, "exists": FileAccess.file_exists(path)}
	if not e.exists:
		return e
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return _bad(e, "not a quick save")
	e.saved_at = FileAccess.get_modified_time(path)
	e.started = true
	e.set = int(cfg.get_value("script", "file", 0))
	e.block = int(cfg.get_value("script", "block", -1))
	e.x = int(cfg.get_value("place", "x", 0))
	e.y = int(cfg.get_value("place", "y", 0))
	e.facing = int(cfg.get_value("place", "facing", 0)) & 3
	var mem: PackedByteArray = cfg.get_value("script", "memory", PackedByteArray())
	var hi: Dictionary = cfg.get_value("script", "memory_hi", {})
	var b := func(a: int) -> int: return mem[a] if a < mem.size() else 0
	_clock(e, [b.call(0x49C6), b.call(0x49C7), b.call(0x49C8), b.call(0x49C9), b.call(0x49CA), b.call(0x49CB),
		b.call(0x49CC) | (int(hi.get(0x49CC, 0)) << 8)])
	var party: Array[Dictionary] = []
	for m in cfg.get_value("party", "members", []):
		var d := _member(m.get("record", PackedByteArray()))
		if d.name == "?":      # early quick saves (before the record was kept) hold the name alone
			d.name = String(m.get("name", "?"))
		d.hp = int(m.get("hp", d.get("hp", 0)))
		d.status = PartyMember.STATUS_NAMES[int(m.get("status", 0))] if int(m.get("status", 0)) < PartyMember.STATUS_NAMES.size() else "?"
		party.append(d)
	e.party = party
	e.companion = "ok"
	var visited = cfg.get_value("qol", "visited", {})
	e.map = visited is Dictionary and (visited as Dictionary).size() > 0
	e.label = String(cfg.get_value("qol", "label", ""))
	_place(e)
	e.ok = true
	return e


## The area of an original's save: the block of its data set whose script the saved image
## (byte 0x1401 on) matches best: the image holds the script's tables as they stood, so a few
## bytes differ. -1 when none matches three quarters of its first 512 bytes. main.gd's
## load_original_save uses it too.
static func area_block(game_path: String, s: PackedByteArray) -> int:
	var key := "%s|%d" % [game_path, s[0]]
	if not _codes.has(key):
		var codes := {}
		var ecl := DaxFile.open(game_path.path_join("ECL%d.DAX" % s[0]))
		if ecl != null:
			for id in ecl.ids():
				codes[id] = EclScript.decode(ecl.blocks[id]).code
		_codes[key] = codes
	var block_id := -1
	var best := 0
	var codes: Dictionary = _codes[key]
	for id in codes:
		var code: PackedByteArray = codes[id]
		var same := 0
		for i in mini(code.size(), 512):
			if s[OriginalSave.SCRIPT_AT + i] == code[i]:
				same += 1
		if code.size() > 64 and same > best and same * 4 > mini(code.size(), 512) * 3:
			best = same
			block_id = id
	return block_id


static func _bad(e: Dictionary, why: String) -> Dictionary:
	e.ok = false
	e.error = why
	return e


static func _clock(e: Dictionary, c: Array) -> void:
	e.clock = {"minute": int(c[2]) * 10 + int(c[1]), "hour": int(c[3]), "day": int(c[4]), "month": int(c[5]),
		"year": int(c[6])}
	e.day = int(c[6]) * 360 + int(c[5]) * 30 + int(c[4]) + 1
	e.time_text = "DAY %d %02d:%02d" % [e.day, e.clock.hour, e.clock.minute]


static func _member(rec: PackedByteArray) -> Dictionary:
	var m := PartyMember.from_bytes(rec, PackedByteArray()) if rec.size() >= 285 else null
	if m == null:
		return {"name": "?", "class": "", "hp": 0, "hp_max": 0, "status": "?"}
	return {"name": m.name, "class": m.char_class, "hp": m.hp, "hp_max": m.hp_max, "status": m.status_name()}


static func _place(e: Dictionary) -> void:
	e.facing_text = FACING[e.facing]
	if not e.started:
		e.area = "PARTY MENU"    # saved before the adventure started
	elif e.block < 0:
		e.area = "AREA %d:?" % e.set
	else:
		var a := AreaNames.lookup(e.set, e.block)
		e.area = String(a.name).to_upper() if a.size() > 0 else "AREA %d:%d" % [e.set, e.block]
		e.area_confirmed = bool(a.get("confirmed", false))

extends SceneTree
## Lab tool (M6 item 4, differential checks): compares the game state our engine saved with the
## state the original saved at the same point, from the same starting save.
##
## godot --headless --path <project> --script res://tools/statediff.gd -- \
##     --ours=<our quick save .cfg> --orig=<folder>/SAVGAM<X>.DAT [--ignore=49C9,49CA,...]
##
## Compared: script memory 0x4900-0x4AFF (the original's save keeps it at byte 1 + 2 x
## (address - 0x4900); ours keeps all of ECL memory), the party's order (chat 73), and for each party member (by name, from
## the original's CHRDAT<X><n>.SAV and .ITM files beside the save): hit points, maximum hit
## points, experience, status, the ability scores (chat 66), the seven kinds of coins, and the items (type, name words, plus, save
## plus, readied, cursed, count, price, bytes 60-62: chat 66; before, the name words only), the standing effects (the original's .SPC beside
## the record: type, minutes, power; ours' affects; chat 66), the memorized spells (chat 62), the magic-user's spell book and the levels (chat 97), race, sex, class and alignment, the portrait and the combat icon (chat 101); the square and facing, and the wall ahead (0xC04E) in a 3D area. Prints one
## line per difference and a total; exit code 1 if any.

const NAMES := {0x49C3: "wilderness x", 0x49C4: "wilderness y", 0x49C5: "clock minutes",
	0x49C6: "clock (part)", 0x49C7: "clock (part)", 0x49C8: "clock (part)", 0x49C9: "clock hour",
	0x49CA: "clock day", 0x49CB: "clock (part)", 0x49F2: "current block", 0x49FB: "square hidden",
	0x49FD: "sky outdoors", 0x49FE: "sky indoors"}


## Chat 82: compare the records' cached THAC0 and AC too (+0x110, +0x111): only checks that ask (diffcheck.sh passes
## --cache for a check folder holding a `cache` file); the cache follows the original's refreshes only in part.
var compare_cache := false


func _init() -> void:
	var ours_path := ""
	var orig_path := ""
	var ignore := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ours="):
			ours_path = arg.trim_prefix("--ours=")
		elif arg.begins_with("--orig="):
			orig_path = arg.trim_prefix("--orig=")
		elif arg == "--cache":
			compare_cache = true
		elif arg.begins_with("--ignore="):
			for a in arg.trim_prefix("--ignore=").split(","):
				ignore[a.hex_to_int()] = true
	var cfg := ConfigFile.new()
	if cfg.load(ours_path) != OK:
		print("can't read ", ours_path)
		quit(2)
		return
	var orig := FileAccess.get_file_as_bytes(orig_path)
	if orig.size() < 1 + 2 * 0x200:
		print("can't read ", orig_path)
		quit(2)
		return
	var diffs := 0
	var mem: PackedByteArray = cfg.get_value("script", "memory", PackedByteArray())
	# Each address is a 16-bit cell in the original (chat 25): ours keeps the high bytes apart.
	var hi: Dictionary = cfg.get_value("script", "memory_hi", {})
	for a in range(0x4900, 0x4B00):
		if ignore.has(a):
			continue
		var o: int = orig[1 + 2 * (a - 0x4900)] | (orig[2 + 2 * (a - 0x4900)] << 8)
		var u: int = (mem[a] | (int(hi.get(a, 0)) << 8)) if a < mem.size() else -1
		if o != u:
			diffs += 1
			print("memory %04X%s: original %d, ours %d" % [a, " (%s)" % NAMES[a] if NAMES.has(a) else "", o, u])
	# The party's square and facing in a 3D area (chat 51: memory alone missed a step carried one
	# square on, check 38). The original's save: 0x3201 x, y, facing x 2; 0x3206 the view (1 = 3D).
	if orig.size() > 0x3206 and orig[0x3206] == 1 and cfg.has_section_key("place", "x"):
		var o_place := "%d,%d %s" % [orig[0x3201], orig[0x3202], "NESW"[(orig[0x3203] >> 1) & 3]]
		var u_place := "%d,%d %s" % [int(cfg.get_value("place", "x")), int(cfg.get_value("place", "y")),
			"NESW"[int(cfg.get_value("place", "facing", 0)) & 3]]
		if o_place != u_place:
			diffs += 1
			print("place: original %s, ours %s" % [o_place, u_place])
	# The wall ahead (chat 61): the original's save keeps ECL 0xC04E at 0x3204 (a 3D area only); it is
	# the last step's or turn's wall, not the square's, after an arrival or a script's jump (13 of the
	# 74 checks differed there before main.gd's _write_wall_ahead).
	if orig.size() > 0x3206 and orig[0x3206] == 1:
		var o_wall: int = orig[0x3204]
		var u_wall: int = mem[0xC04E] if mem.size() > 0xC04E else -1
		if o_wall != u_wall:
			diffs += 1
			print("wall ahead (0xC04E): original %d, ours %d" % [o_wall, u_wall])
	# The party: the original's character files beside its save (CHRDAT<letter><n>).
	var letter := orig_path.get_file().get_basename().right(1)
	var folder := orig_path.get_base_dir()
	var theirs := {}
	var their_order: Array[String] = []
	# Chat 41: only the files the save names (its party: 0x3208 the count, 41-byte names from 0x3209); a
	# slot keeps older files past the party's size (the original leaves them), which aren't the party.
	var stems: Array[String] = []
	if orig.size() >= 0x3209 + 41 * 8:
		for k in mini(orig[0x3208], 8):
			var ln: int = orig[0x3209 + k * 41]
			if ln > 0 and ln <= 12:
				stems.append(orig.slice(0x3209 + k * 41 + 1, 0x3209 + k * 41 + 1 + ln).get_string_from_ascii())
	else:
		for n in range(1, 9):
			stems.append("CHRDAT%s%d" % [letter, n])
	for stem in stems:
		var sav := folder.path_join(stem + ".SAV")
		if not FileAccess.file_exists(sav):
			continue
		var d := FileAccess.get_file_as_bytes(sav)
		var itm := folder.path_join(stem + ".ITM")
		var items := FileAccess.get_file_as_bytes(itm) if FileAccess.file_exists(itm) else PackedByteArray()
		var spc := folder.path_join(stem + ".SPC")
		var aff := []
		if FileAccess.file_exists(spc):
			var sd := FileAccess.get_file_as_bytes(spc)
			for o in range(0, sd.size() - 8, 9):
				if sd[o] != 0:
					aff.append("%d/%d/%d" % [sd[o], sd.decode_u16(o + 1), sd[o + 3]])
		aff.sort()
		theirs[_name(d)] = {"record": d, "items": items, "affects": aff}
		their_order.append(_name(d))
	var ours := {}
	var our_order: Array[String] = []
	for m in cfg.get_value("party", "members", []):
		if not m.has("record"):
			continue
		var items := PackedByteArray()
		for it in m.get("items", []):
			items.append_array(it)
		var aff := []
		for e in m.get("affects", []):
			aff.append("%d/%d/%d" % [int(e.effect), int(e.minutes), int(e.get("value", 0))])
		aff.sort()
		ours[_name(m.record)] = {"record": m.record, "items": items, "affects": aff}
		our_order.append(_name(m.record))
	for name in theirs:
		if not ours.has(name):
			diffs += 1
			print("party: %s is in the original's party, not ours" % name)
			continue
		diffs += _member(name, theirs[name], ours[name])
	for name in ours:
		if not theirs.has(name):
			diffs += 1
			print("party: %s is in ours, not the original's" % name)
	# Main chat 73 (check 142, camp ALTER ORDER): the party's order (the original's save lists it in order).
	if their_order != our_order and theirs.size() == ours.size() and theirs.keys().all(func(k): return ours.has(k)):
		diffs += 1
		print("party order: original %s, ours %s" % [str(their_order), str(our_order)])
	print("%d difference%s" % [diffs, "" if diffs == 1 else "s"])
	quit(1 if diffs > 0 else 0)


static func _name(d: PackedByteArray) -> String:
	return d.slice(1, 1 + mini(d[0], 15)).get_string_from_ascii().strip_edges()


func _member(name: String, t: Dictionary, u: Dictionary) -> int:
	var n := 0
	var a: PackedByteArray = t.record
	var b: PackedByteArray = u.record
	var fields := [["HP", 0x11B, 1], ["max HP", 0x32, 1], ["experience", 0xAC, 4], ["status", 0x10C, 1],
			["age", 0x30, 2],     # chat 81: the camp's Haste ages each member it hastes
			# Chat 101 (checks 344-356, CREATE NEW CHARACTER): what the creation lists pick.
			["race", 0x2E, 1], ["sex", 0x9E, 1], ["class", 0x2F, 1], ["alignment", 0xA0, 1],
			# Chat 101 (checks 359-360, the icon editor's SIZE): the portrait and the combat icon.
			["portrait head", 0xBB, 1], ["portrait body", 0xBC, 1], ["icon head", 0xBD, 1], ["icon weapon", 0xBE, 1],
			["icon size", 0xC0, 1], ["icon body colours", 0xC1, 1], ["icon arm colours", 0xC2, 1],
			["icon leg colours", 0xC3, 1], ["icon hair colours", 0xC4, 1], ["icon shield colours", 0xC5, 1],
			["icon weapon colours", 0xC6, 1],
			# Chat 102 (checks 367-372, NPC_ADD): ADD_NPC's control byte (128 + morale / 2) and side.
			["control", 0x84, 1], ["side", 0x10E, 1]]
	if compare_cache:     # chat 82: the record's cached THAC0 and AC (a check with a `cache` file; TRAIN leaves them stale)
		fields.append_array([["cached THAC0", 0x110, 1], ["cached AC", 0x111, 1]])
	for i in 7:
		fields.append(["coins %d" % i, 0x88 + 2 * i, 2])
	for i in 7:     # the ability scores and STR 18/xx (chat 66: a temple's RAISE DEAD costs a point of CON)
		fields.append([["STR", "INT", "WIS", "DEX", "CON", "CHA", "STR 18/xx"][i], 0x10 + i, 1])
	for f in fields:
		var x := _int(a, f[1], f[2])
		var y := _int(b, f[1], f[2])
		if x != y:
			n += 1
			print("%s %s: original %d, ours %d" % [name, f[0], x, y])
	var ts := _spells(a)
	var us := _spells(b)
	if ts != us:
		n += 1
		print("%s memorized spells: original %s, ours %s" % [name, str(ts), str(us)])
	# Chat 97 (check 329, a magic-user's training): the spell book (0x33..0x6A, one byte per spell id: the
	# spell picked at training, SCRIBE) and the levels by class (0x96..0x9D).
	var tb := _book(a)
	var ub := _book(b)
	if tb != ub:
		n += 1
		print("%s spell book: original %s, ours %s" % [name, str(tb), str(ub)])
	var tl := Array(a.slice(0x96, 0x9E))
	var ul := Array(b.slice(0x96, 0x9E))
	if tl != ul:
		n += 1
		print("%s levels: original %s, ours %s" % [name, str(tl), str(ul)])
	if t.affects != u.affects:
		n += 1
		print("%s affects: original %s, ours %s" % [name, str(t.affects), str(u.affects)])
	var ti := _items(t.items)
	var ui := _items(u.items)
	if ti != ui:
		n += 1
		print("%s items: original %s, ours %s" % [name, str(ti), str(ui)])
	return n


static func _int(d: PackedByteArray, off: int, size: int) -> int:
	if off + size > d.size():
		return -1
	match size:
		1: return d[off]
		2: return d.decode_u16(off)
	return d.decode_u32(off)


## The magic-user spell ids in the spell book (record bytes 0x33..0x6A, one per spell id 1..56: non-zero = known).
## Only the magic-user's (ids 9-21, 29-35, 45-55, from the game's spell table): a magic-user's book changes only by
## the training pick and SCRIBE. The cleric's part isn't compared: the original fills every castable cleric spell in
## as it loads a save (ours at training and creation: the same in play, but lab-edited saves differ), and in 5:x it
## sets DIRTEN's 56 (RESTORATION, cleric level 7) for a reason not yet read (chat 97: 47 gate checks differed on these).
static func _book(d: PackedByteArray) -> Array:
	var out := []
	for i in range(0x33, mini(0x6B, d.size())):
		var id := i - 0x32
		if d[i] != 0 and ((id >= 9 and id <= 21) or (id >= 29 and id <= 35) or (id >= 45 and id <= 55)):
			out.append(id)
	return out


## The memorized spells (record bytes 0x17..0x2B, a spell id each, + 0x80 while being memorized), sorted:
## where they sit in the record isn't compared (ours keeps no gaps; chat 62).
static func _spells(d: PackedByteArray) -> Array:
	var out := []
	for i in range(0x17, mini(0x2C, d.size())):
		if d[i] != 0:
			out.append(d[i])
	out.sort()
	return out


## Items as comparable keys (63-byte records): name words 47-49, type 46, plus 50 and 51, readied 52, cursed 54,
## count 57, price 58-59, bytes 60-62 (chat 66: until then only the name words were compared; all 109 checks
## matched with the rest added; chat 75: byte 53, the hidden name words an ID clears, as `h`, check 152).
static func _items(d: PackedByteArray) -> Array:
	var out := []
	for i in range(0, d.size() - 62, 63):
		out.append("%d.%d.%d t%d +%d/%d r%d h%d c%d n%d $%d x%d.%d.%d" % [d[i + 47], d[i + 48], d[i + 49], d[i + 46],
				d[i + 50], d[i + 51], d[i + 52], d[i + 53], d[i + 54], d[i + 57], d.decode_u16(i + 58), d[i + 60], d[i + 61],
				d[i + 62]])
	out.sort()
	return out

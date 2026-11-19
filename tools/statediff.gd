extends SceneTree
## Lab tool (M6 item 4, differential checks): compares the game state our engine saved with the
## state the original saved at the same point, from the same starting save.
##
## godot --headless --path <project> --script res://tools/statediff.gd -- \
##     --ours=<our quick save .cfg> --orig=<folder>/SAVGAM<X>.DAT [--ignore=49C9,49CA,...]
##
## Compared: script memory 0x4900-0x4AFF (the original's save keeps it at byte 1 + 2 x
## (address - 0x4900); ours keeps all of ECL memory), and for each party member (by name, from
## the original's CHRDAT<X><n>.SAV and .ITM files beside the save): hit points, maximum hit
## points, experience, status, the seven kinds of coins, and the items (name bytes, plus,
## count, readied), the memorized spells (chat 62); the square and facing, and the wall ahead (0xC04E) in a 3D area. Prints one
## line per difference and a total; exit code 1 if any.

const NAMES := {0x49C3: "wilderness x", 0x49C4: "wilderness y", 0x49C5: "clock minutes",
	0x49C6: "clock (part)", 0x49C7: "clock (part)", 0x49C8: "clock (part)", 0x49C9: "clock hour",
	0x49CA: "clock day", 0x49CB: "clock (part)", 0x49F2: "current block", 0x49FB: "square hidden",
	0x49FD: "sky outdoors", 0x49FE: "sky indoors"}


func _init() -> void:
	var ours_path := ""
	var orig_path := ""
	var ignore := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ours="):
			ours_path = arg.trim_prefix("--ours=")
		elif arg.begins_with("--orig="):
			orig_path = arg.trim_prefix("--orig=")
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
		theirs[_name(d)] = {"record": d, "items": items}
	var ours := {}
	for m in cfg.get_value("party", "members", []):
		if not m.has("record"):
			continue
		var items := PackedByteArray()
		for it in m.get("items", []):
			items.append_array(it)
		ours[_name(m.record)] = {"record": m.record, "items": items}
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
	print("%d difference%s" % [diffs, "" if diffs == 1 else "s"])
	quit(1 if diffs > 0 else 0)


static func _name(d: PackedByteArray) -> String:
	return d.slice(1, 1 + mini(d[0], 15)).get_string_from_ascii().strip_edges()


func _member(name: String, t: Dictionary, u: Dictionary) -> int:
	var n := 0
	var a: PackedByteArray = t.record
	var b: PackedByteArray = u.record
	var fields := [["HP", 0x11B, 1], ["max HP", 0x32, 1], ["experience", 0xAC, 4], ["status", 0x10C, 1]]
	for i in 7:
		fields.append(["coins %d" % i, 0x88 + 2 * i, 2])
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


## The memorized spells (record bytes 0x17..0x2B, a spell id each, + 0x80 while being memorized), sorted:
## where they sit in the record isn't compared (ours keeps no gaps; chat 62).
static func _spells(d: PackedByteArray) -> Array:
	var out := []
	for i in range(0x17, mini(0x2C, d.size())):
		if d[i] != 0:
			out.append(d[i])
	out.sort()
	return out


## Items as comparable keys: name word bytes 47-49, plus, count, readied (63-byte records).
static func _items(d: PackedByteArray) -> Array:
	var out := []
	for i in range(0, d.size() - 62, 63):
		out.append("%d.%d.%d" % [d[i + 47], d[i + 48], d[i + 49]])
	out.sort()
	return out

extends SceneTree
## Lab check (chat 41, Player 12's request): the character files ours' save writer leaves, against what the
## original writes (DOSBox, chat 41: a member with no items gets no .ITM, one with no standing effects no .SPC,
## and that member's old file in the slot is removed; files of slots past the party's size stay).
##
## godot --headless --path <project> --script res://tools/check_save_files.gd -- <game folder> <slot> <scratch dir>
##
## Absolute paths. Loads the slot's party, empties member 1's items and effects, puts stale files in the scratch
## folder's slot T (member 1's .ITM and .SPC, and a member past the party's size), saves the party there with
## OriginalSave.write, then checks the files. Prints PASS or the differences; exit 0 only on PASS.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("usage: -- <game folder> <slot> <scratch dir>")
		quit(2)
		return
	var src: String = args[0]
	var slot: String = args[1].to_upper()
	var out: String = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	var dat := FileAccess.get_file_as_bytes(src.path_join("SAVGAM%s.DAT" % slot))
	if dat.size() < OriginalSave.SIZE:
		print("no SAVGAM%s.DAT in %s" % [slot, src])
		quit(2)
		return
	var n: int = dat[OriginalSave.POS_AT + 7]
	var party: Array[PartyMember] = []
	for k in n:
		var stem := src.path_join("CHRDAT%s%d" % [slot, k + 1])
		var m := PartyMember.load_files(stem + ".SAV", stem + ".ITM")
		if m == null:
			print("member %d did not load" % (k + 1))
			quit(2)
			return
		party.append(m)
	party[0].items.clear()
	party[0].affects.clear()
	var stale := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9])
	for f in ["CHRDATT1.ITM", "CHRDATT1.SPC", "CHRDATT%d.SAV" % (n + 1), "CHRDATT%d.ITM" % (n + 1)]:
		_put(out.path_join(f), stale)
	var mem := PackedByteArray()
	mem.resize(0x10000)
	if not OriginalSave.write(out, "T", 1, mem, 1, 1, 0, party):
		print("FAIL: the write failed")
		quit(1)
		return
	var bad: Array[String] = []
	for k in n:
		var m := party[k]
		var stem := out.path_join("CHRDATT%d" % (k + 1))
		var want_itm := m.items.size() * GameItem.SIZE
		var want_spc := m.affects.size() * 9
		for pair in [[".ITM", want_itm], [".SPC", want_spc]]:
			var p: String = stem + pair[0]
			var have := FileAccess.file_exists(p)
			if pair[1] == 0 and have:
				bad.append("member %d: %s written (%d bytes), the original writes none" % [k + 1, pair[0], FileAccess.get_file_as_bytes(p).size()])
			elif pair[1] > 0 and (not have or FileAccess.get_file_as_bytes(p).size() != pair[1]):
				bad.append("member %d: %s missing or not %d bytes" % [k + 1, pair[0], pair[1]])
		var back := PartyMember.load_files(stem + ".SAV", stem + ".ITM")
		if back == null or back.items.size() != m.items.size():
			bad.append("member %d: reads back with %s items, wrote %d" % [k + 1, "no" if back == null else str(back.items.size()), m.items.size()])
	for f in ["CHRDATT%d.SAV" % (n + 1), "CHRDATT%d.ITM" % (n + 1)]:
		if FileAccess.get_file_as_bytes(out.path_join(f)) != stale:
			bad.append("%s past the party's size changed (the original leaves it)" % f)
	for b in bad:
		print("FAIL: " + b)
	print("PASS (%d members, member 1 emptied)" % n if bad.is_empty() else "FAIL (%d)" % bad.size())
	quit(0 if bad.is_empty() else 1)


func _put(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()

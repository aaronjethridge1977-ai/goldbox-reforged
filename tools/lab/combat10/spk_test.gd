extends SceneTree
## spk_test.gd (run in a built proj with --game-path=...): each speaker row's divisors per tick from scripts/ui/speaker.gd,
## one line a row, for combat10/spk_cmp.sh to compare with sfx.py.
func _init() -> void:
	var gp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game-path="):
			gp = a.substr(12)
	CharacterSheet.game_path = gp
	var seg := Speaker._driver_segment()
	if seg.is_empty():
		print("NO DRIVER")
		quit()
		return
	for row in 21:
		var s := Speaker.new()
		s._m = seg.duplicate()
		s._size = maxi(seg[0x1DA], 0x30)
		s._start(row, true)
		var out := PackedStringArray()
		for t in 2400:
			out.append(str(s._tick()))
			var any := false
			for k in 4:
				any = any or s._w(Speaker.BLOCK + k * s._size) != 0
			if not any:
				break
		print("ROW %d %s" % [row, " ".join(out)])
		s.free()
	quit()

extends SceneTree
## Developer tool: names each area. For every ECL block, prints the first few texts its
## disassembly holds (strings in PRINT / PRINTCLEAR operands), to tell the areas apart.
##
## godot --headless --path <project> --script res://tools/areas.gd -- --game-path=<POOLRAD>


func _init() -> void:
	var game_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-path="):
			game_path = arg.trim_prefix("--game-path=")
	for n in range(1, 9):
		var ecl := DaxFile.open(game_path.path_join("ECL%d.DAX" % n))
		if ecl == null:
			continue
		for id in ecl.ids():
			var dis := EclScript.decode(ecl.blocks[id]).disassemble()
			var texts := PackedStringArray()
			for line in dis.split("\n"):
				var q := line.find("\"")
				if q >= 0 and line.contains("PRINT"):
					var t := line.substr(q + 1).trim_suffix("\"")
					if t.length() > 20:
						texts.append(t.left(90))
				if texts.size() >= 3:
					break
			print("%d:%d  %s" % [n, id, " || ".join(texts)])
	quit()

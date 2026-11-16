extends SceneTree
## Lab tool (QoL 3, chat 37): prints the quest tracker's view (QuestLog.evaluate) of a saved game.
##
## godot --headless --path <project> --script res://tools/quest_report.gd -- <save> [<save> ...]
##
## A save is ours' quick save (.cfg: the whole ECL memory) or the original's SAVGAM<X>.DAT
## (0x4900-0x4CFF at byte 1 + 2 x (address - 0x4900)). One line per quest that isn't hidden:
## state, title, and the steps done of all.


func _init() -> void:
	var ql := QuestLog.load_file()
	for path in OS.get_cmdline_user_args():
		var mem := _memory(path)
		if mem.is_empty():
			print("%s: can't read" % path)
			continue
		print("== %s" % path.get_file())
		var read := func(a: int) -> int: return mem[a] if a < mem.size() else 0
		for q in ql.evaluate(read):
			if q["state"] == QuestLog.HIDDEN:
				continue
			var done := 0
			for s in q["steps"]:
				done += 1 if s["done"] else 0
			print("  %-9s %-45s steps %d/%d" % [q["state"], q["title"], done, q["steps"].size()])
	quit()


func _memory(path: String) -> PackedByteArray:
	if path.get_extension().to_lower() == "cfg":
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			return PackedByteArray()
		return cfg.get_value("script", "memory", PackedByteArray())
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() < 0x801:
		return PackedByteArray()
	var mem := PackedByteArray()
	mem.resize(0x4D00)
	for k in 0x400:
		mem[0x4900 + k] = raw[1 + 2 * k]
	return mem

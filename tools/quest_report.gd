extends SceneTree
## Lab tool (QoL 3, chat 37): prints the quest tracker's view (QuestLog.evaluate) of a saved game.
##
## godot --headless --path <project> --script res://tools/quest_report.gd -- <save> [<save> ...]
##
## A save is ours' quick save (.cfg: the whole ECL memory) or the original's SAVGAM<X>.DAT
## (0x4900-0x4CFF at byte 1 + 2 x (address - 0x4900)). One line per quest that isn't hidden:
## state, title, and the steps done of all; "offered" when the party has heard the offer. Offer
## texts shown (chat 39): a quick save's [qol] offers, or the companion SAVGAM<X>.GBR beside a .DAT.


func _init() -> void:
	var ql := QuestLog.load_file()
	for path in OS.get_cmdline_user_args():
		var mem := _memory(path)
		if mem.is_empty():
			print("%s: can't read" % path)
			continue
		print("== %s" % path.get_file())
		var read := func(a: int) -> int: return mem[a] if a < mem.size() else 0
		var shown := _shown(path)
		for q in ql.evaluate(read, shown):
			if q["state"] == QuestLog.HIDDEN:
				continue
			var done := 0
			for s in q["steps"]:
				done += 1 if s["done"] else 0
			print("  %-9s %-45s steps %d/%d%s" % [q["state"], q["title"], done, q["steps"].size(),
				"  offered" if q["offered"] else ""])
	quit()


func _shown(path: String) -> Dictionary:
	var keys = []
	if path.get_extension().to_lower() == "cfg":
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			keys = cfg.get_value("qol", "offers", [])
	else:
		var letter := path.get_file().get_basename().right(1)
		keys = CompanionSave.read(path.get_base_dir(), letter, true).get("offers", [])
	var out := {}
	for k in keys:
		out[String(k)] = true
	return out


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

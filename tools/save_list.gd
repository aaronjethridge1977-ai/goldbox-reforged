extends SceneTree
## Lab tool (QoL 5, chat 38): prints the save/load menu's data (SaveSlots.list) for a game folder.
##
## godot --headless --path <project> --script res://tools/save_list.gd -- <game folder> [<quick save .cfg>]
##
## Absolute paths (Godot resolves relative ones inside the project). One line per slot, then the party.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <game folder> [<quick save .cfg>]")
		quit(1)
		return
	for e in SaveSlots.list(args[0], args[1] if args.size() > 1 else ""):
		if not e.exists:
			print("%-5s (empty)" % e.slot)
			continue
		if not e.ok:
			print("%-5s can't read: %s" % [e.slot, e.error])
			continue
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var when := Time.get_datetime_string_from_unix_time(int(e.saved_at) + bias, true)
		print("%-5s %-22s %2d,%-2d %s  %-12s  map %-3s  companion %-5s  saved %s%s" % [e.slot, e.area, e.x, e.y,
			e.facing_text, e.time_text, "yes" if e.map else "no", e.companion, when,
			"  \"%s\"" % e.label if e.label != "" else ""])
		for m in e.party:
			print("        %-16s %-24s %3d/%-3d %s" % [m.name, m["class"], m.hp, m.hp_max, m.status])
	quit()

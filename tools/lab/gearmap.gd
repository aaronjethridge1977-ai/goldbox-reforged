extends SceneTree
# gearmap.gd <game folder> (chat 69): every item list the game can hand out, as TSV for the magic-gear map
# (tools/lab/gearmap.py joins it with the areas' ECL listings).
#   ITEM <file> <list> <n> <type> <plus> <save plus> <cursed> <count> <price> <weight> <class flags> <name> <scroll spells>
#     for ITEM1-8.DAX (TREASURE item lists) and MON*ITM.DAX (a monster's items, by monster id)
#   MON <file> <id> <name>   (MON*CHA.DAX: the monster's name)
#   CLASS <class> <flag>     (START.EXE's class item flags, DS:0x05D6)
#   EVT <ecl> <block> <x> <y> <flag>   (each square's info byte, GEO<ecl>.DAX: the event is its low bits)
func _init() -> void:
	var g: String = OS.get_cmdline_user_args()[0]
	var names := ItemNames.shared(g)
	var types := ItemTypes.load_file(g)
	var rules := CreationRules.shared(g)
	var spells := SpellTable.shared(g)
	for c in 8:
		print("CLASS\t%d\t%d" % [c, rules._byte(CreationRules.DS_CLASS_FLAGS + c)])
	var files := []
	for n in range(1, 9):
		files.append("ITEM%d" % n)
		files.append("MON%dITM" % n)
	for f in files:
		var dax := DaxFile.open(g.path_join(f + ".DAX"))
		if dax == null:
			continue
		for id in dax.ids():
			var items := GameItem.list_from(dax.blocks[id])
			for i in items.size():
				var it: GameItem = items[i]
				var raw := it.raw.duplicate()
				raw[53] = 0
				var shown := GameItem.from_record(raw)
				var sp: int = it.raw[51] - 256 if it.raw[51] > 127 else it.raw[51]
				# Scrolls (types 61, 62): the spells in bytes 60-62.
				var extra := PackedStringArray()
				if it.type in [61, 62]:
					for k in [60, 61, 62]:
						if it.raw[k] != 0:
							extra.append(spells.name_of(it.raw[k]))
				print("ITEM\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s" % [f, id, i, it.type, it.plus, sp,
					1 if it.cursed else 0, it.count, it.price, it.weight, types.class_flags(it.type), names.name_of(shown),
					", ".join(extra)])
	for n in range(1, 9):
		var dax := DaxFile.open(g.path_join("MON%dCHA.DAX" % n))
		if dax == null:
			continue
		for id in dax.ids():
			var b: PackedByteArray = dax.blocks[id]
			print("MON\t%d\t%d\t%s" % [n, id, b.slice(1, 1 + mini(b[0], 15)).get_string_from_ascii()])
	for n in range(1, 9):
		var dax := DaxFile.open(g.path_join("GEO%d.DAX" % n))
		if dax == null:
			continue
		for id in dax.ids():
			var m := GeoMap.decode(dax.blocks[id])
			if m == null:
				continue
			for y in 16:
				for x in 16:
					var e: int = m.flag(x, y)
					if e > 0:
						print("EVT\t%d\t%d\t%d\t%d\t%d" % [n, id, x, y, e])
	quit()

extends SceneTree
## Developer check: magic items and strength outside fights, against what the original's
## handlers do (see ItemPowers, Strength, SpellCaster). Prints PASS / FAIL lines.
##
## godot --headless --path <project> --script res://tools/check_items.gd -- --game-path=<POOLRAD>

var game_path := ""
var fails := 0
var types: ItemTypes
var spells: SpellTable
var names: ItemNames


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-path="):
			game_path = arg.trim_prefix("--game-path=")
	types = ItemTypes.load_file(game_path)
	spells = SpellTable.shared(game_path)
	names = ItemNames.shared(game_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Thrender (fighter): gauntlets, Enlarge, Strength, then everything wears off.
	var f := _member(1)
	var base := Strength.current(f)
	print("Fighter %s STR %d/%d" % [f.name, base.x, base.y])
	var g := find_item("Gauntlets of Ogre Power")
	f.items.append(g)
	var sheet_note := " / ".join(ItemPowers.changed(f, _ready(g), true))
	check("gauntlets raise to 18/00", Strength.current(f) == Vector2i(18, 100), str(Strength.current(f)))
	check("gauntlets say IS STRONGER", sheet_note.contains("IS STRONGER"), sheet_note)
	var lines := SpellCaster.cast_outside(spells, f, 12, [f], f, rng, true)     # Enlarge at level 6
	check("Enlarge below 18/00 waits", Strength.current(f) == Vector2i(18, 100), str(Strength.current(f)))
	g.readied = false
	ItemPowers.changed(f, g, false)
	# Enlarge at caster level 6 is 18/00 too, so it took over when it was cast; taking the
	# gauntlets off removes their (waiting) effect and Enlarge keeps 18/00 until it ends.
	check("gauntlets off: Enlarge keeps 18/00", Strength.current(f) == Vector2i(18, 100) and f.has_affect(12) and not f.has_affect(0x26),
		str(Strength.current(f)) + " " + str(f.affects))
	SpellCaster.pass_time([f], 100000)
	check("everything ends: STR back", Strength.current(f) == base, str(Strength.current(f)))

	# Potion of Giant Strength (item spell 82 -> 59) and of Healing (85 -> 62).
	var p := find_item("Potion of Giant Strength")
	check("potion maps to 59", SpellTable.from_item(p.raw[61]) == 59, str(p.raw[61]))
	lines = SpellCaster.cast_outside(spells, f, 59, [f], f, rng, true)
	check("Giant Strength: STR 21", Strength.current(f).x == 21, str(Strength.current(f)) + " " + " / ".join(lines))
	SpellCaster.pass_time([f], 200)
	check("Giant Strength ends", Strength.current(f) == base, str(Strength.current(f)))
	f.hp = 1
	lines = SpellCaster.cast_outside(spells, f, 62, [f], f, rng, true)
	check("Potion of Healing heals 4-10", f.hp >= 5 and f.hp <= 11 and " / ".join(lines).contains("IS HEALED"), "%d %s" % [f.hp, " / ".join(lines)])

	# Speed, refused when slowed.
	lines = SpellCaster.cast_outside(spells, f, 57, [f], f, rng, true)
	check("Speed hastes", f.has_affect(39) and " / ".join(lines).contains("IS SPEEDY"), " / ".join(lines))

	# Ring of Fire Resistance lends 0x3D while readied.
	var ring := find_item("Ring of Fire Resistance")
	f.items.append(ring)
	check("ring off: no 0x3D", not f.has_affect(0x3D), "")
	ring.readied = true
	check("ring on: 0x3D", f.has_affect(0x3D), "")
	check("fire 3d6=12 with the ring: 12-6 = 6", CombatSpells.resisted(f, SpecialAffects.FIRE, 12, 3) == 6, str(CombatSpells.resisted(f, SpecialAffects.FIRE, 12, 3)))
	check("fire 3d6=4 with the ring: at least 3", CombatSpells.resisted(f, SpecialAffects.FIRE, 4, 3) == 3, str(CombatSpells.resisted(f, SpecialAffects.FIRE, 4, 3)))

	# The aligned Long Sword +3 (0x84, byte 61 0x52): alignment 2 only, 5 damage otherwise.
	var sword := find_item("Long Sword +3", 0x84)
	f.items.append(sword)
	f.hp = 20
	var al: int = f.raw[0xA0]
	sword.readied = true
	var said := ItemPowers.changed(f, sword, true)
	if al == 2:
		check("aligned sword kept (alignment 2)", sword.readied, "")
	else:
		check("aligned sword refused: 5 damage", not sword.readied and f.hp == 15, "%d %s" % [f.hp, " / ".join(said)])

	# Boulder needs STR 19.
	var boulder := find_item("Boulder")
	check("boulder refused below STR 19", ItemPowers.refuse(f, boulder) == "MUST HAVE GIANT STRENGTH", "")

	# Manual of Bodily Health: reading a day, training 30 days, CON + 1.
	var con := f.stats[4]
	lines = SpellCaster.cast_outside(spells, f, 67, [f], f, rng, true)
	var out := SpellCaster.pass_time([f], 1440)
	check("manual: starts to train", " / ".join(out).contains("STARTS TO TRAIN"), " / ".join(out))
	out = SpellCaster.pass_time([f], 43200)
	check("manual: CON + 1", f.stats[4] == con + 1 and " / ".join(out).contains("IS HARDIER"), " / ".join(out))

	print("%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()


func _member(i: int) -> PartyMember:
	var m := PartyMember.load_files(game_path.path_join("CHRDATA%d.SAV" % i), game_path.path_join("CHRDATA%d.ITM" % i))
	m.recalculate(types)
	return m


func _ready(it: GameItem) -> GameItem:
	it.readied = true
	return it


func check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", what, detail if not ok else ""])
	if not ok:
		fails += 1


## The first item in the game's lists whose name starts with `name` (and, if given, whose
## record byte 62 is `power`).
func find_item(name: String, power: int = -1) -> GameItem:
	for file in ["ITEM1", "ITEM2", "ITEM3", "ITEM4", "ITEM5", "ITEM6", "ITEM7", "ITEM8",
			"MON2ITM", "MON3ITM", "MON5ITM", "MON6ITM", "MON7ITM"]:
		var dax := DaxFile.open(game_path.path_join(file + ".DAX"))
		if dax == null:
			continue
		for id in dax.ids():
			var b: PackedByteArray = dax.blocks[id]
			for o in range(0, b.size() - 62, 63):
				var it := GameItem.from_record(b.slice(o, o + 63))
				var shown := GameItem.from_record(b.slice(o, o + 63))
				shown.raw[53] = 0
				var n := names.name_of(shown)
				if n.begins_with(name) and (power < 0 or it.raw[62] == power):
					it.name = n
					return it
	push_error("no item " + name)
	return null

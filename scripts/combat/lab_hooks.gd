class_name LabHooks
## The side lane's lab keys for main.gd's `--keys` replay (moved out of main.gd, decided 2026-11-14,
## Methods 2). Owned by the side lane; main.gd keeps one call into it. Lab only.

const KEYS := ["smartquick", "smartmonsters", "fightend", "partyhp", "monsters", "outcome"]
const PREFIXES := ["order=", "memorize=", "stage=", "hp="]


## Whether `n` is one of these keys.
static func handles(n: String) -> bool:
	if n in KEYS:
		return true
	for p in PREFIXES:
		if n.begins_with(p):
			return true
	return false


## Runs key `n` against the game (main.gd). True: the replay goes straight on to the next key
## (no wait for the game to settle, no state line), as main.gd's `continue` did.
static func handle(main: Node, n: String) -> bool:
	var combat = main._combat
	if n == "smartquick":               # SETTINGS' smarter QUICK tactics in the open fight
		if combat._combat != null:
			combat._combat.smart_quick = true
	elif n.begins_with("order="):       # order=<member>:<0-4>: B3's standing order (SmartQuick.ORDER_NAMES)
		var a := n.trim_prefix("order=").split(":")
		main._party[int(a[0])].quick_order = int(a[1])
		return true
	elif n == "smartmonsters":          # SETTINGS' smarter monster tactics in the open fight
		if combat._combat != null:
			combat._combat.smart_monsters = true
	elif n == "fightend":               # waits until the fight is over or asks CONTINUE BATTLE
		var waited := 0
		var foes := []
		while combat.visible and not combat._asking_continue and waited < 2400:
			if combat._combat != null:
				foes = combat._combat.combatants.filter(func(c): return c.team == 1).map(func(c): return c.who)
			await main.get_tree().create_timer(0.5).timeout
			waited += 1
		if combat._asking_continue:
			print("   ASKED CONTINUE BATTLE")
		for f in foes:
			print("   FOE %d %d" % [f.hp, f.status])
	elif n == "partyhp":                # each member's HP and status byte (record 0x11B, 0x10C)
		for k in main._party.size():
			print("   PARTY %d %d %d" % [k + 1, main._party[k].hp, main._party[k].status])
		return true
	elif n.begins_with("memorize="):    # memorize=<member>:<id>;<id>...: the member's memorized spells; no ids: list them
		var a := n.trim_prefix("memorize=").split(":")
		var who: PartyMember = main._party[int(a[0])]
		var st := SpellTable.shared(main._game_path)
		if a.size() > 1 and a[1] != "":
			who.memorized.clear()
			for id in a[1].split(";"):
				who.memorized.append(int(id))
		print("   %s: %s" % [who.name, ", ".join(who.memorized.map(func(id): return "%d %s" % [id, st.name_of(id)]))])
		return true
	elif n == "monsters":               # monsters: the test fight's MON file, id and name of each (side chat 5)
		var cha := DaxFile.open(main._game_path.path_join("MON%dCHA.DAX" % combat._mon_file))
		var ids: Array = cha.ids() if cha else []
		ids.sort()
		for id in ids:
			var m := PartyMember.load_monster(main._game_path, combat._mon_file, id)
			if m != null:
				print("   MON %d %s HP %d " % [id, m.name, m.hp])
		return true
	elif n.begins_with("stage="):       # stage=<id>x<n>;<id>x<n>...: the open test fight (before F) against those monsters
		var rows := []
		for part in n.trim_prefix("stage=").split(";"):
			var a := part.split("x")
			rows.append([int(a[0]), int(a[1]) if a.size() > 1 else 1, int(a[0])])
		combat._encounters = [{"monsters": rows, "text": "staged"}]
		combat._enc_index = 0
		combat._load_monsters()
	elif n.begins_with("hp="):          # hp=<pct>: every party member in the open fight at that share of its full HP
		var pct := int(n.trim_prefix("hp="))
		if combat._combat != null:
			for c in combat._combat.combatants:
				if c.team == 0:
					c.who.hp = maxi(1, c.who.hp_max * pct / 100)
		return true
	elif n == "outcome":                # outcome: the open fight's result (0 on, 1 won, 2 lost, 3 ran away) and each figure
		if combat._combat != null:
			print("   OUTCOME %d ROUND %d" % [combat._combat.outcome(), combat._combat.round_no])
			for c in combat._combat.combatants:
				print("   FIG %d %s HP %d/%d DOWN %s FLED %s" % [c.team, c.who.name, c.who.hp, c.who.hp_max,
					str(c.down), str(c.get("fled", false))])
		else:
			print("   OUTCOME none (result %d)" % combat._result)
		return true
	return false

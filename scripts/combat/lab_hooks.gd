class_name LabHooks
## The side lane's lab keys for main.gd's `--keys` replay (moved out of main.gd, decided 2026-11-14,
## Methods 2). Owned by the side lane; main.gd keeps one call into it. Lab only.

const KEYS := ["smartquick", "smartmonsters", "fightend", "partyhp"]
const PREFIXES := ["order=", "memorize="]


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
	return false

class_name LabHooks
## The side lane's lab keys for main.gd's `--keys` replay (moved out of main.gd, decided 2026-11-14,
## Methods 2). Owned by the side lane; main.gd keeps one call into it. Lab only.

const KEYS := ["smartquick", "smartmonsters", "fightend", "fightmenu", "fightaim", "partyhp", "monsters", "outcome", "who", "temple",
		"ending", "fxlog", "fxwatch"]
const PREFIXES := ["magicat=", "order=", "memorize=", "stage=", "hp=", "foehp=", "poison=", "handcast=", "handflee=", "controlat="]


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
	elif n.begins_with("magicat="):     # magicat=<draw>: MAGIC ON at the first computer turn from that draw on (Combat Chat 25)
		Combat.magic_at_draws.append(int(n.trim_prefix("magicat=")))     # queued in draw order (Combat Chat 26)
		return true
	elif n.begins_with("controlat="):   # controlat=<draw>: Space (QUICK handed back) at the first computer turn from that draw on (Combat Chat 52)
		Combat.control_at_draws.append(int(n.trim_prefix("controlat=")))
		return true
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
		# A lost fight waits for a key on "THE PARTY HAS FALLEN." (_result 2): over too.
		while combat.visible and not combat._asking_continue and combat._result != 2 and waited < 2400:
			if combat._combat != null:
				foes = combat._combat.combatants.filter(func(c): return c.team == 1).map(func(c): return c.who)
			await main.get_tree().create_timer(0.5).timeout
			waited += 1
		if combat._asking_continue:
			print("   ASKED CONTINUE BATTLE")
		for f in foes:
			print("   FOE %d %d" % [f.hp, f.status])
	elif n == "fightmenu":              # waits (up to 60 s) for a member's fight menu, steady 3 frames (Combat Chat 39)
		# Player 39's p37i1: a replayed key reached ours while the spectres' turn still ran (the original's gap
		# 0.5 s) and DORN's MOVE keys were lost; a replay puts this before a fight menu's key. No fight: no wait.
		var t_end := Time.get_ticks_msec() + 60000
		var steady := 0
		while combat.visible and combat._combat != null and Time.get_ticks_msec() < t_end:
			var up: bool = combat._cmode == "menu" and combat._combat.active >= 0 \
					and not combat._combatants[combat._combat.active].get("quick", false) and not combat._announcing \
					and combat._flash == "" and combat._row24_msg == "" and not main._busy and not combat._asking_continue
			steady = steady + 1 if up else 0
			if steady >= 3:
				break
			await main.get_tree().process_frame
		return true
	elif n == "fightaim":               # waits (up to 60 s) for a member's AIM (a begun spell going off), steady 3 frames
		# Combat Chat 52, Player 48's p45i5: ELWEN's MANUAL key for her begun Hold Person reached ours while a guard's
		# turn still ran, and her first pick fell on herself; a replay puts this before an AIM's first key.
		var t_end := Time.get_ticks_msec() + 60000
		var steady := 0
		while combat.visible and combat._combat != null and Time.get_ticks_msec() < t_end:
			var up: bool = combat._cmode == "aim" and combat._combat.active >= 0 \
					and not combat._combatants[combat._combat.active].get("quick", false) and not combat._announcing \
					and combat._flash == "" and not main._busy
			steady = steady + 1 if up else 0
			if steady >= 3:
				break
			await main.get_tree().process_frame
		return true
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
	elif n == "fxwatch":                # fxwatch: a figure's status, HP and effects whenever they change (Combat Chat 42)
		Combat.lab_watch_effects = true
		return true
	elif n == "fxlog":                  # fxlog: every figure's effects (effect:minutes) at each round's start (Combat Chat 41)
		Combat.lab_print_effects = true
		return true
	elif n == "who":                    # who: whose turn it is in the open fight, and where everyone stands
		var act: int = combat._combat.active
		print("   ACTIVE %s" % (combat._combatants[act].who.name if act >= 0 else "-"))
		for c in combat._combatants:
			if not c.down:
				print("   %s %s %d,%d" % ["P" if c.team == 0 else "M", c.who.name, c.cell.x, c.cell.y])
	elif n == "ending":                 # ending: the closing scene (PROGRAM 8) over the walking screen (Combat Chat 4)
		if main._ending == null:
			main._ending = EndingScreen.new()
			main.add_child(main._ending)
		main._ending.open(main._game_path)
	elif n == "temple":                 # temple: the temple screen on the party (as a script's temple opens it)
		main._temple.open(main._party)
	elif n.begins_with("poison="):      # poison=<member>: poisoned as a fight's failed save leaves one (dead, 0x37)
		var m: PartyMember = main._party[int(n.trim_prefix("poison="))]
		SpellCaster.add_affect(m, SpecialAffects.POISONED, 0, 0, 0xFF)
		m.hp = 0
		m.status = PartyMember.STATUS_DEAD
		# In an open fight, its copy of the member falls there too (Combat Chat 4: Slow Poison
		# on the body).
		if combat._combat != null:
			for j in combat._combat.combatants.size():
				var c: Dictionary = combat._combat.combatants[j]
				if c.team == 0 and not c.down and c.who.name == m.name:
					SpellCaster.add_affect(c.who, SpecialAffects.POISONED, 0, 0, 0xFF)
					c.who.hp = 0
					c.who.status = PartyMember.STATUS_DEAD
					c.down = true
					combat._combat._went_down(j)
	elif n.begins_with("foehp="):       # foehp=<n>: every monster in the open fight at n HP (a blow that lands kills; side chat 6)
		for c in combat._combatants:
			if c.team != 0:
				c.who.hp = mini(c.who.hp, int(n.trim_prefix("foehp=")))
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
	elif n.begins_with("handcast="):    # handcast=<aimskip>:<picks>: the lab's handcast.py in ours (Combat Chat 34)
		await _handcast(main, n.trim_prefix("handcast="))
		return true
	elif n.begins_with("handflee="):    # handflee=<dirs, by .>: the lab's combat41/fleemove.py in ours (Combat Chat 41)
		await _handflee(main, n.trim_prefix("handflee="))
		return true
	return false


## handflee=<dir.dir...>: plays the open fight as the lab's combat41/fleemove.py plays the original's: at a member's
## menu with MOVE (not on QUICK): M, then the first direction that moves (ATTACK ALLY: n and the next direction; a key
## that left MOVE LEFT as it was: the next direction; after 3 x directions + 12 keys: Enter); FLEE: y; the same
## member's menu again after its MOVE, or a menu without MOVE: DONE, then QUIT; CONTINUE BATTLE: NO.
static func _handflee(main: Node, arg: String) -> void:
	# handflee=@<file>: the keys of a run of the original's fleemove.py ("KEY <key> (...)" lines), pressed in order at
	# the same points (the original's screen sometimes lags a step, so its choices can't always be recomputed).
	var script_keys := PackedStringArray()
	if arg.begins_with("@"):
		for line in FileAccess.get_file_as_string(arg.substr(1)).split("\n"):
			var w := line.strip_edges().split(" ", false)
			var at := w.find("KEY")
			if at >= 0 and at + 1 < w.size():
				script_keys.append(w[at + 1].capitalize() if w[at + 1].length() > 1 else w[at + 1])
		arg = ""
	var ki := 0
	var dirs := arg.split(".") if arg != "" else PackedStringArray(["Left", "Home", "End", "Up", "Down"])
	var cs = main._combat
	var di := 0
	var tries := 0
	var left_before := -1
	var lastdir := ""
	var moving := false
	var moved_who := -1
	var seen := false
	var last := ""
	var steady := 0
	var t_end := Time.get_ticks_msec() + 1800000
	while Time.get_ticks_msec() < t_end:
		await main.get_tree().process_frame
		if not cs.visible or cs._combat == null:
			if seen:
				break
			continue
		if cs._result != 0 and not cs._asking_continue:
			break
		var st := ""
		if cs._asking_continue:
			st = "continue"
		elif cs._asking_ally:
			st = "ally"
		elif cs._asking_flee:
			st = "flee"
		elif cs._flash != "" or cs._row24_msg != "" or cs._announcing or main._busy:
			st = ""
		elif cs._cmode == "move":
			st = "move:%d" % (int(cs._combatants[cs._combat.active].moves) / 2)
		elif cs._cmode == "done":
			st = "done"
		elif cs._cmode == "menu" and cs._combat.active >= 0 and not cs._combatants[cs._combat.active].get("quick", false):
			st = "menu:%d:" % cs._combat.active + ",".join(cs._bottom_menu())
		steady = steady + 1 if st == last else 0
		last = st
		if st == "" or steady < 3:
			continue
		var k := ""
		var why := ""
		if st == "continue":
			if seen:
				k = "n"
				why = "continue battle: no"
		elif st == "ally":
			di += 1
			k = "n"
			why = "attack ally?"
		elif st == "flee":
			k = "y"
			why = "flee?"
		elif st == "done":
			k = "q"
			why = "DONE's QUIT"
		elif st.begins_with("move:"):
			if not moving:
				continue
			var n := int(st.split(":")[1])
			if left_before >= 0 and n == left_before and lastdir == dirs[di % dirs.size()]:
				di += 1
			left_before = n
			tries += 1
			if tries > 3 * dirs.size() + 12:
				k = "Enter"
				why = "end MOVE"
				moving = false
			else:
				lastdir = dirs[di % dirs.size()]
				k = lastdir
				why = "step (left %d)" % n
		elif st.begins_with("menu:"):
			seen = true
			var p := st.split(":")
			var who := int(p[1])
			var items := p[2].split(",")
			if moving or who == moved_who:
				moving = false
				moved_who = -1
				k = "d"
				why = "DONE"
			elif "MOVE" in items:
				di = 0
				left_before = -1
				tries = 0
				lastdir = ""
				moved_who = who
				moving = true
				k = "m"
				why = "MOVE " + cs._combatants[who].who.name
			else:
				k = "d"
				why = "DONE"
		if k == "":
			continue
		if ki < script_keys.size():
			if script_keys[ki].to_lower() != k.to_lower():
				why += ", the original's key " + script_keys[ki]
				k = script_keys[ki]
			ki += 1
		print("   HAND KEY %s (%s)" % [k, why])
		await main._press(k)
		last = ""
		steady = 0
		if st == "continue":
			break


## handcast=<aimskip>:<picks>[:1]: plays the open fight as the lab's combat33/handcast.py plays the original's, for
## a lone caster: at the member's menu CAST (else QUICK, and QUICK for good once taken), the spell list's lit
## spell, NEXT <aimskip> times then TARGET (several picks: NEXT and TARGET again up to <picks>, then EXIT),
## ABORT SPELL? YES, CONTINUE BATTLE NO; with :1, TURN first while the menu offers it; :<casts>:1 as handuse.py's CASTS and QUICKOTHERS. Each key is printed (HAND KEY), so the two games' key lists compare.
static func _handcast(main: Node, arg: String) -> void:
	var a := arg.split(":")
	var aim_skip := int(a[0]) if a.size() > 0 and a[0] != "" else 1
	var picks_max := int(a[1]) if a.size() > 1 else 1
	var turn_first := a.size() > 2 and a[2] == "1"     # handcast.py's TURNFIRST: TURN while the menu offers it
	# Combat Chat 38 (combat38/handuse.py): :<casts> the caster's CASTs at most, then QUICK; :1 after it, a member
	# without CAST goes on QUICK and the caster keeps casting (QUICKOTHERS).
	var casts_max := int(a[3]) if a.size() > 3 and a[3] != "" else 99
	var quick_others := a.size() > 4 and a[4] == "1"
	# Combat Chat 39 (combat38/handuse.py's USES / USEDOWN): :<uses>:<down> USE that many times while the menu
	# offers it, each time End <down> times on the item list, then U (the lit item), then the aim as a spell's.
	var uses_max := int(a[5]) if a.size() > 5 and a[5] != "" else 0
	var use_down := int(a[6]) if a.size() > 6 and a[6] != "" else 0
	# Combat Chat 50 (combat50/handcast3.py): :1 eighth, each pick one NEXT deeper, so several picks take different figures.
	var deeper := a.size() > 7 and a[7] == "1"
	# Combat Chat 58 (combat58/handg.py, P115): :<name> ninth, NEXT until a figure whose name begins so is lit, then TARGET.
	var aim_name := a[8] if a.size() > 8 else ""
	var uses := 0
	var downs := 0
	var casts := 0
	var cs = main._combat
	CombatScreen.lab_original_aim = true     # the original's AIM cycle (TARGETING SKIPS PARTY off)
	var aim_n := 0
	var picks := 0
	var quick := false
	var seen := false
	var last := ""
	var steady := 0
	var t_end := Time.get_ticks_msec() + 1800000
	while Time.get_ticks_msec() < t_end:
		await main.get_tree().process_frame
		if not cs.visible or cs._combat == null:
			if seen:
				break
			continue
		if cs._result != 0 and not cs._asking_continue:
			break
		var st := ""
		var sheet = cs._sheet
		if cs._asking_continue:
			st = "continue"
		elif cs._asking_abort:
			st = "abort"
		elif sheet != null and sheet.visible and sheet._mode in ["cast", "scroll"]:
			st = "choose"      # (Combat Chat 60: a scroll's page, CHOOSE SPELL: CAST EXIT, as handuse.py's)
		elif sheet != null and sheet.visible and sheet._mode == "items":
			st = "use"
		elif cs._flash != "" or cs._row24_msg != "":
			st = ""             # a message on row 24 (handcast.py waits for the menu to come back)
		elif cs._cmode == "aim" and cs._aim_for == "spell":
			st = "aim:" + ",".join(cs._bottom_menu())
		elif cs._cmode == "menu" and cs._combat.active >= 0 and not cs._combatants[cs._combat.active].get("quick", false) \
				and not cs._announcing and cs._flash == "" and cs._row24_msg == "" and not main._busy:
			st = "menu:" + ",".join(cs._bottom_menu())
		steady = steady + 1 if st == last else 0
		last = st
		if st == "" or steady < 3:
			continue
		var k := ""
		var why := ""
		if st == "continue":
			if seen:
				k = "n"
				why = "continue battle: no"
		elif st == "abort":
			k = "y"
			why = "abort spell"
		elif st == "choose":
			if sheet._mode == "scroll":     # Combat Chat 61: the scroll page's list and its lit spell, for the lab's shots
				print("HAND SCROLL %s lit %d" % [str(sheet._scroll_ids()), sheet._scroll_cursor])
			k = "c"
			why = "cast the lit spell"
			aim_n = 0
			picks = 0
		elif st == "use":
			if downs < use_down:
				k = "End"
				why = "item list down"
				downs += 1
			else:
				k = "u"
				why = "use the lit item"
				uses += 1
				downs = 0
				aim_n = 0
				picks = 0
		elif st.begins_with("aim:"):
			var lit_j: int = cs._aim_list[cs._aim_index] if cs._aim_index < cs._aim_list.size() else -1
			var named: bool = lit_j >= 0 and aim_n >= 1 and String(cs._combatants[lit_j].who.name).begins_with(aim_name)
			if "TARGET" in st.split(":")[1].split(",") and (named if aim_name != "" else aim_n >= aim_skip + (picks if deeper else 0)):
				k = "t"
				var tj: int = cs._aim_list[cs._aim_index] if cs._aim_index < cs._aim_list.size() else -1
				why = "target %s %s" % [cs._combatants[tj].who.name if tj >= 0 else "-", str(cs._combatants[tj].cell) if tj >= 0 else ""]
				picks += 1
				aim_n = 0
			elif picks >= picks_max or aim_n > 40:
				k = "e"
				why = "aim exit"
				aim_n = 0
			else:
				k = "n"
				why = "aim next"
				aim_n += 1
		elif st.begins_with("menu:"):
			seen = true
			if "USE" in st.split(":")[1].split(",") and not quick and uses < uses_max:     # handuse.py: USE first
				k = "u"
				why = "USE"
				downs = 0
			elif turn_first and "TURN" in st.split(":")[1].split(",") and not quick:
				k = "t"
				why = "TURN"
			elif "CAST" in st.split(":")[1].split(",") and not quick and casts < casts_max:
				k = "c"
				why = "CAST"
				picks = 0
				aim_n = 0
				casts += 1
			elif quick_others and not ("CAST" in st.split(":")[1].split(",")):
				k = "q"
				why = "QUICK (not the caster)"
			else:
				k = "q"
				why = "QUICK"
				quick = true
		if k == "":
			continue
		if k == "t":     # the aim list as NEXT walks it (figure, cell, H = helpless)
			var al := PackedStringArray()
			for x in mini(cs._aim_list.size(), aim_skip + 3):
				var fc: Dictionary = cs._combatants[cs._aim_list[x]]
				al.append("%d:%s%s" % [cs._aim_list[x], str(fc.cell), "H" if CombatSpells.held(fc.who) else ""])
			print("   HAND AIMLIST " + " ".join(al))
		print("   HAND KEY %s (%s)" % [k, why])
		await main._press(k)
		last = ""
		steady = 0
		if st == "continue":
			break

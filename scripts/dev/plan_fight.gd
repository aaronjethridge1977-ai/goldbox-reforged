class_name PlanFight
## Lab (main chat 96, Guide 12's step 3: "try plans in ours first"): plays the open fight by a plan file and prints
## its result, so candidate plans can be compared in ours over many seeds before the Player plays the best one in the
## original. Key `planfight=<plan file>` in main.gd's --keys replay, once the fight is open (after the keys that walk
## into it). tools/lab/planfight.sh runs a plan list over seeds and sums the results.
##
## The plan file, one entry a line (# comments; names and spells as the game shows them, any case):
##   <MEMBER> <round> cast <SPELL> [on <FIGURE>] [x<picks>]   CAST that spell (the first in the list with that name);
##                                                             aimed by NEXT until a figure whose name holds FIGURE
##                                                             (else the aim's first), TARGET <picks> times, EXIT
##   <MEMBER> <round> use <ITEM> [on <FIGURE>] [x<picks>]     USE the first item whose name holds ITEM, aimed so
##   <MEMBER> <round> aim <FIGURE>                             AIM, NEXT to that figure, TARGET
##   <MEMBER> <round> turn | guard | delay | done | quick      TURN; DONE's GUARD / DELAY / QUIT; QUICK
##   magic on                                                  Alt-M at the first turn: QUICK members cast
## <round> is a number or a range (1-3) or "*" (every round). A member's turn with no entry is played on QUICK for
## that turn (ours' QUICK, as the original's); the member is taken off QUICK again before a round with an entry.
## Entries that can't be carried out (no CAST on the menu, the spell not memorized) fall back to QUICK, logged.
##
## Prints "PLANFIGHT <key> <why>" per key and at the end one line:
##   PLANFIGHT RESULT outcome=<won|lost|fled|other> rounds=<n> hp=<before>-><after> lost=<n> down=<names> dead=<names>

const _OUTCOMES := {1: "won", 2: "lost", 3: "fled"}


static func _parse(path: String) -> Dictionary:
	var plan := {"entries": [], "magic": false}
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var l := raw.split("#")[0].strip_edges()
		if l == "":
			continue
		var w := l.split(" ", false)
		if w[0].to_lower() == "magic":
			plan.magic = w.size() < 2 or w[1].to_lower() == "on"
			continue
		if w.size() < 3:
			push_warning("planfight: bad line: " + l)
			continue
		var e := {"who": w[0].to_upper(), "act": w[2].to_lower(), "arg": "", "on": "", "picks": 1, "line": l}
		var r := w[1]
		if r == "*":
			e.r0 = 1
			e.r1 = 9999
		elif "-" in r:
			e.r0 = int(r.split("-")[0])
			e.r1 = int(r.split("-")[1])
		else:
			e.r0 = int(r)
			e.r1 = int(r)
		var rest := w.slice(3)
		var words := PackedStringArray()
		var i := 0
		while i < rest.size():
			if rest[i].to_lower() == "on" and i + 1 < rest.size():
				e.on = " ".join(rest.slice(i + 1)).to_upper()
				var m := RegEx.create_from_string(" X([0-9]+)$").search(e.on)
				if m != null:
					e.picks = int(m.get_string(1))
					e.on = e.on.substr(0, m.get_start())
				break
			if RegEx.create_from_string("^x[0-9]+$").search(rest[i].to_lower()) != null:
				e.picks = int(rest[i].substr(1))
			else:
				words.append(rest[i])
			i += 1
		e.arg = " ".join(words).to_upper()
		if e.act == "aim":
			e.on = e.arg
		plan.entries.append(e)
	return plan


static func _entry(plan: Dictionary, who: String, rnd: int) -> Dictionary:
	for e in plan.entries:
		if e.who == who.to_upper() and rnd >= e.r0 and rnd <= e.r1:
			return e
	return {}


static func _party_hp(cs) -> Array:
	var hp := 0
	var down := PackedStringArray()
	var dead := PackedStringArray()
	for c in cs._combatants:
		if c.team != 0:
			continue
		var m: PartyMember = c.who
		hp += maxi(m.hp, 0)
		if m.status >= 6:     # DEAD, STONED, GONE (PartyMember.STATUS_NAMES)
			dead.append(m.name.replace(" ", "_"))
		elif m.status in [4, 5] or m.hp <= 0:     # UNCONSCIOUS, DYING
			down.append(m.name.replace(" ", "_"))
	return [hp, down, dead]


## Key `planprep=<plan file>`, before the keys that walk into the fight: each member's QUICK flag (the record's, kept
## from the last fight: GAME.OVR 0xAA38) set as the plan's round 1 wants it: off for a member with a round-1 entry (so
## the menu comes, even for the fight's first figure), on for the others. NPCs are left alone.
static func prepare(main: Node, path: String) -> void:
	var plan := _parse(path)
	for m in main._party:
		var w: PartyMember = m
		if w.npc >= 128:
			continue
		var want := not _entry(plan, w.name, 1).is_empty()
		Combat.set_record_quick(w, not want)
		print("   PLANFIGHT prep %s %s" % [w.name, "menu in round 1" if want else "QUICK"])


## The field as the fight opens: every figure (team, name, cell, HP) and each member's memorized spells, so a plan can
## name its figures and spells.
static func _print_field(cs) -> void:
	for c in cs._combatants:
		var w: PartyMember = c.who
		var line := "PLANFIGHT FIELD %s %s %s HP %d" % ["party" if c.team == 0 else "foe", w.name, str(c.cell), w.hp]
		if c.team == 0 and cs._sheet != null:
			var names := PackedStringArray()
			for row in cs._sheet._spell_rows(w):
				if row[1] != 0:
					names.append(String(row[0]).to_upper())
			if not names.is_empty():
				line += " spells " + ", ".join(names)
		print(line)


static func run(main: Node, path: String) -> void:
	var plan := _parse(path)
	var cs = main._combat
	CombatScreen.lab_original_aim = true     # the original's AIM cycle (TARGETING SKIPS PARTY off)
	var seen := false
	var hp0 := -1
	var last_round := -1
	var cur: Dictionary = {}     # the entry being carried out
	var phase := ""              # "", "choose", "aim", "done"
	var aim_n := 0
	var picks := 0
	var last := ""
	var steady := 0
	var pressed_at := ""         # the state a key was sent at: no key again until the state changes (or 3 s pass:
	var pressed_ms := 0          # a key the screen ate, as at the fight's first menu, is sent again)
	var result := 0
	var rounds := 0
	var t_end := Time.get_ticks_msec() + 3600000
	while Time.get_ticks_msec() < t_end:
		await main.get_tree().process_frame
		if not cs.visible or cs._combat == null:
			if seen:
				break
			continue
		if hp0 < 0:
			hp0 = _party_hp(cs)[0]
			_print_field(cs)
			if plan.magic:     # at the fight's start: a plan with no entries never shows a menu
				cs.toggle_magic()
				print("   PLANFIGHT magic on")
		rounds = maxi(rounds, cs._combat.round_no)
		if cs._result != 0 and not cs._asking_continue:
			result = cs._result
			break
		# A new round: members with an entry in it come off QUICK (not the one acting).
		if cs._combat.round_no != last_round:
			last_round = cs._combat.round_no
			for i in cs._combatants.size():
				var c: Dictionary = cs._combatants[i]
				var w: PartyMember = c.who
				if c.team != 0 or w.npc >= 128 or i == cs._combat.active:
					continue
				var want := not _entry(plan, w.name, last_round).is_empty()
				if want and c.get("quick", false):
					c.quick = false
					Combat.set_record_quick(w, false)
		var st := ""
		var sheet = cs._sheet
		if cs._asking_continue:
			st = "continue"
		elif cs._asking_abort:
			st = "abort"
		elif cs._asking_ally:
			st = "ally"
		elif cs._asking_flee:
			st = "flee"
		elif sheet != null and sheet.visible and sheet._mode == "cast":
			st = "choose"
		elif sheet != null and sheet.visible and sheet._mode == "items":
			st = "use"
		elif cs._flash != "" or cs._row24_msg != "" or cs._announcing or main._busy:
			st = ""
		elif cs._cmode == "aim":
			st = "aim:%d:%d" % [cs._aim_index, cs._aim_list.size()]
		elif cs._cmode == "done":
			st = "done"
		elif cs._cmode == "menu" and cs._combat.active >= 0 and not cs._combatants[cs._combat.active].get("quick", false):
			st = "menu:%d:%d:" % [cs._combat.active, cs._combat.round_no] + ",".join(cs._bottom_menu())
		steady = steady + 1 if st == last else 0
		last = st
		if pressed_at != "":
			if (st == pressed_at or st == "") and Time.get_ticks_msec() - pressed_ms < 3000:
				continue
			pressed_at = ""
		if st == "" or steady < 3:
			continue
		var k := ""
		var why := ""
		if st == "continue":
			k = "n"
			why = "CONTINUE BATTLE: NO"
		elif st == "abort":
			k = "y"
			why = "ABORT SPELL: YES"
		elif st == "ally" or st == "flee":
			k = "n"
			why = st + "? NO"
		elif st == "choose":
			var ids: Array = sheet._spell_ids()
			var want_id := -1
			for row in sheet._spell_rows(sheet._who()):
				if row[1] != 0 and String(row[0]).to_upper() == cur.get("arg", ""):
					want_id = int(row[1])
					break
			if want_id < 0 or not want_id in ids:
				k = "e"
				why = "no %s to cast: EXIT" % cur.get("arg", "?")
				cur = {"act": "quick"}
			elif ids[clampi(sheet._cast_cursor, 0, ids.size() - 1)] != want_id:
				k = "End"
				why = "spell list down"
			else:
				k = "c"
				why = "CAST " + cur.arg
				aim_n = 0
				picks = 0
		elif st == "use":
			var m: PartyMember = sheet._who()
			var at := -1
			for j in m.items.size():
				if cur.get("arg", "") != "" and cur.arg in m.items[j].name.to_upper():
					at = j
					break
			if at < 0 or cur.get("act", "") != "use":
				k = "e"
				why = "no %s to use: EXIT" % cur.get("arg", "?")
				cur = {"act": "quick"}
			elif sheet._cursor != at:
				k = "End"
				why = "item list down"
			else:
				k = "u"
				why = "USE " + m.items[at].name
				aim_n = 0
				picks = 0
		elif st.begins_with("aim:"):
			var items: Array = cs._bottom_menu()
			var tj: int = cs._aim_list[cs._aim_index] if cs._aim_index < cs._aim_list.size() else -1
			var tname := String(cs._combatants[tj].who.name).to_upper() if tj >= 0 else ""
			var on: String = cur.get("on", "")
			var match_here := on == "" or on in tname
			if picks >= int(cur.get("picks", 1)) or aim_n > 2 * cs._aim_list.size() + 4:
				k = "e"
				why = "aim EXIT"
			elif "TARGET" in items and (match_here or aim_n >= cs._aim_list.size()):
				k = "t"
				why = "TARGET %s %s" % [tname, str(cs._combatants[tj].cell) if tj >= 0 else ""]
				picks += 1
				aim_n = 0
			else:
				k = "n"
				why = "aim NEXT"
				aim_n += 1
		elif st == "done":
			var items: Array = cs._bottom_menu()
			var act: String = cur.get("act", "done")
			if act == "guard" and "GUARD" in items:
				k = "g"
				why = "GUARD"
			elif act == "delay" and "DELAY" in items:
				k = "d"
				why = "DELAY"
			else:
				k = "q"
				why = "QUIT"
		elif st.begins_with("menu:"):
			seen = true
			var p := st.split(":")
			var who: PartyMember = cs._combatants[int(p[1])].who
			var rnd := int(p[2])
			var items := p[3].split(",")
			cur = _entry(plan, who.name, rnd)
			var act: String = cur.get("act", "quick")
			if act == "cast" and "CAST" in items:
				k = "c"
			elif act == "use" and "USE" in items:
				k = "u"
			elif act == "aim" and "AIM" in items:
				k = "a"
				aim_n = 0
				picks = 0
			elif act == "turn" and "TURN" in items:
				k = "t"
			elif act in ["guard", "delay", "done"]:
				k = "d"
			else:
				if act != "quick":
					print("   PLANFIGHT round %d %s: %s not on the menu (%s): QUICK" % [rnd, who.name, act, ",".join(items)])
				k = "q"
				act = "quick"
			why = "round %d %s: %s" % [rnd, who.name, cur.get("line", "QUICK (no entry)") if act != "quick" or not cur.is_empty() else "QUICK (no entry)"]
		if k == "":
			continue
		print("   PLANFIGHT %s (%s)" % [k, why])
		await main._press(k)
		# Lists (End) and the aim (NEXT) may stay in the same state string: those need no change to go on.
		pressed_at = "" if k in ["End", "n"] else st
		pressed_ms = Time.get_ticks_msec()
		last = ""
		steady = 0
	var end := _party_hp(cs)
	print("PLANFIGHT RESULT outcome=%s rounds=%d hp=%d->%d lost=%d down=%s dead=%s" % [_OUTCOMES.get(result, "other(%d)" % result),
		rounds, hp0, end[0], hp0 - end[0], ",".join(end[1]), ",".join(end[2])])

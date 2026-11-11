class_name PlayBot
extends Node
## Lab: plays the game from a plan file, headless, as a player would: walks with the tour
## (Main._tour), answers prompts, fights on Quick, rests, memorizes, shops, trains. Logs
## every screen and every surprise; used for the M6 whole-game playthrough.
##
##   godot --headless --path <project> -- --game-path=<POOLRAD> --play=<plan file> [--fast]
##
## Plan lines ("#" starts a comment):
##   char <race> <class> <alignment> <name>   roll a character with the creation rules
##            (rerolled until its class's main abilities are 15+, as a player rerolls)
##   begin                 start the adventure with them (PARTY CREATION's BEGIN ADVENTURING)
##   tour <x>,<y> ...      walk to each square in turn, playing whatever happens
##   face N|E|S|W / step / key <name> / answers a;b;c / say <text>
##   heal                  camp and rest until everyone is at full HP (handles interruptions)
##   memorize              fill every caster's spell slots (first spells in the book) and rest
##   train                 (in a training hall's party menu) train everyone who can
##   buy <member> <item>   (in a shop) buy the first item whose name starts so; pool first
##   temple                (at a temple) raise / cure / heal everyone who needs it
##   checkpoint <name>     quick save to user://bot_<name>.cfg; a wipe goes back to the last
##   expect <set>:<block>  log a mismatch if the party isn't in that area
##   log <text>            a heading in the log
##   stop                  end here

var main: Node
var lines: PackedStringArray = []
var _pc := 0
var _checkpoint := ""
var _checkpoint_pc := 0
var _retries := 0
var _new_party: Array[PartyMember] = []
var _rng := RandomNumberGenerator.new()
var issues: PackedStringArray = []


func run(plan_path: String) -> void:
	_rng.randomize()
	CombatSpells.party_casts = true
	var text := FileAccess.get_file_as_string(plan_path)
	lines = text.split("\n")
	main.auto_hook = _hook
	while _pc < lines.size():
		var line := lines[_pc].strip_edges()
		_pc += 1
		if line == "" or line.begins_with("#"):
			continue
		print("\n>> ", line)
		if line == "stop":
			break
		await _do(line)
		if _wiped():
			_issue("party wiped at plan line %d (%s)" % [_pc, line])
			if _checkpoint == "" or _retries >= 3:
				break
			_retries += 1
			print("== back to checkpoint %s (try %d)" % [_checkpoint, _retries + 1])
			_load(_checkpoint)
			_pc = _checkpoint_pc
	print("\n== PLAYTHROUGH ENDED at plan line %d; %d issues" % [_pc, issues.size()])
	for i in issues:
		print("ISSUE ", i)
	print(main._state_line())
	_party_report()
	main.get_tree().quit()


func _issue(t: String) -> void:
	issues.append(t)
	print("!! ", t)


func _wiped() -> bool:
	if main._party.is_empty():
		return false
	if main._lost:
		return true
	for m in main._party:
		if m.status == PartyMember.STATUS_OKAY:
			return false
	return true


func _do(line: String) -> void:
	var w := line.split(" ", false)
	match w[0]:
		"char":
			_make_char(w[1], w[2], w[3], " ".join(w.slice(4)))
		"begin":
			main._party.clear()
			for m in _new_party:
				main._party.append(m)
			main._vm.party = main._party
			main._new_game()
			main._show()
			await _settle()
		"tour":
			for xy in w.slice(1):
				if _wiped():
					return
				var a := xy.split(",")
				await main._tour(Vector2i(int(a[0]), int(a[1])))
				await _settle()
				print("   at ", main._state_line())
				if _wiped():
					return
		"face":
			var d := "NESW".find(w[1])
			while int(main._facing) != d:
				await main._press("right")
		"step":
			await main._press("up")
			await _settle()
		"key":
			await main._press(w[1])
			await _settle()
		"answers":
			main._tour_answers = Array(w[1].split(";"))
		"say":
			main._on_typed(" ".join(w.slice(1)))
			await _settle()
		"heal":
			await _heal()
		"shop":
			# shop x,y | <member> <item> | <member> <item> ...
			var parts := line.split("|")
			_buys = []
			for p in parts.slice(1):
				var q := p.strip_edges().split(" ", false, 1)
				_buys.append([int(q[0]), q[1]])
			_want = "shop"
			var a := w[1].split(",")
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_want = ""
			_ready_all()
		"inn":
			_want = "inn"
			var a := w[1].split(",")
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			if _want == "inn":
				_issue("the inn didn't take us (%s); memorizing in camp here" % main._message.text.strip_edges())
				_want = ""
				await _memorize()
				await _heal()
		"trainat":
			_want = "train"
			var a := w[1].split(",")
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_want = ""
		"ready":
			_ready_all()
		"travel":
			await _travel(w[1])
		"explore":
			await _explore(w.slice(1))
		"memorize":
			await _memorize()
		"train":
			await _train()
		"buy":
			_buy(int(w[1]), " ".join(w.slice(2)))
		"temple":
			_want = "temple"
			var a := w[1].split(",")
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_want = ""
		"checkpoint":
			_checkpoint = w[1]
			_checkpoint_pc = _pc
			_retries = 0
			main._quick_save()
			DirAccess.copy_absolute(main._save_path(), "user://bot_%s.cfg" % w[1])
		"expect":
			var a := w[1].split(":")
			if main._vm_file != int(a[0]) or main._vm_block != int(a[1]):
				_issue("expected area %s, in %d:%d (%s)" % [w[1], main._vm_file, main._vm_block, line])
		"log":
			print("==== ", " ".join(w.slice(1)))
		_:
			_issue("unknown plan command: " + line)
	print("   ", main._state_line())


## Waits until nothing is open or running, playing it out with the tour's policy.
func _settle() -> void:
	var guard := 0
	while guard < 20000:
		guard += 1
		await get_tree().process_frame
		if not await main._auto_handle():
			for i in 10:
				await get_tree().process_frame
			if not await main._auto_handle():
				return


## The tour's policy, with the party's own judgement where it matters: in fights everyone
## on Quick (the computer fights for them, as the original's QUICK does).
func _hook() -> bool:
	if main._vm.state == EclVM.State.MENU and main._message.text.contains("WHO WILL PAY") and main._vm.menu.size() == main._party.size():
		var best := 0
		for i in main._party.size():
			if main._party[i].money[4] > main._party[best].money[4]:
				best = i
		print("   >> %d (most platinum: %d)" % [best + 1, main._party[best].money[4]])
		await main._press(str(best + 1))
		return true
	if _want == "shop" and main._shop.visible:
		for b in _buys:
			_buy(int(b[0]), String(b[1]))
		_buys = []
		_want = ""
		main._shop._exit()
		return true
	if _want == "inn" and main._camp.visible:
		_want = ""
		_pick_spells()
		var need := 0
		for m in main._party:
			if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
				need = maxi(need, m.hp_max - m.hp)
		await _rest_in_camp(mini(need, 14))
		print("   inn: %s | %s" % [" ".join(main._party.map(func(m): return "%d/%d" % [m.hp, m.hp_max])),
			" ".join(main._party.map(func(m): return str(m.memorized)))])
		return true
	if _want == "temple" and main._temple.visible:
		_want = ""
		_temple_cures()
		await main._press("esc")
		return true
	if _want == "train" and main._party_menu.visible:
		_want = ""
		await _train()
		return true
	return false


var _training := false
var _want := ""          # "shop" or "train": what to do when that screen opens on the way
var _buys: Array = []    # [member, item name start]


## Readies what each member carries, as the character sheet's READY does (best armour and
## first weapon; the sheet refuses what doesn't fit).
func _ready_all() -> void:
	var sheet: CharacterSheet = main._sheet
	for m in main._party:
		for it in m.items:
			if not it.readied:
				var why: String = sheet._ready_item(m, it)
				if why != "" and not why.contains("STRONGER"):
					pass
		m.recalculate(main._types)


# --- Getting around -----------------------------------------------------------------------
# The area graph comes from tools/sweep.gd's EXIT lines (where each square's on-move or
# on-step script leads), kept in the lab folder: --exits=<file>.

var _exits := {}     # "set:block" -> [{x, y, dir, entry, to}]


func _load_exits() -> void:
	if not _exits.is_empty():
		return
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--exits="):
			path = arg.trim_prefix("--exits=")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var w := line.split(" ", false)
		if w.size() < 9 or w[0] != "EXIT":
			continue
		var xy := w[3].split(",")
		var to := w[7]
		if to.begins_with("0:"):
			to = w[1].split(":")[0] + to.substr(1)     # NEW_ECL in the same data set
		var e := {"x": int(xy[0]), "y": int(xy[1]), "dir": "NESW".find(w[4]), "entry": w[5], "to": to}
		if not _exits.has(w[1]):
			_exits[w[1]] = []
		_exits[w[1]].append(e)


func _here() -> String:
	return "%d:%d" % [main._vm_file, main._vm_block]


## Walks from area to area (shortest number of areas) to `goal` ("set:block").
func _travel(goal: String) -> void:
	_load_exits()
	for hop in 12:
		if _here() == goal or _wiped():
			return
		# Breadth first over areas.
		var came := {_here(): ""}
		var queue := [_here()]
		while not queue.is_empty():
			var a: String = queue.pop_front()
			if a == goal:
				break
			for e in _exits.get(a, []):
				if not came.has(e.to):
					came[e.to] = a
					queue.append(e.to)
		if not came.has(goal):
			_issue("travel: no way from %s to %s" % [_here(), goal])
			return
		var next := goal
		while came[next] != _here():
			next = came[next]
		# The nearest open way out to `next`.
		var map: GeoMap = main._maps[main._map_index].map
		var best := {}
		var best_len := 1 << 20
		for e in _exits.get(_here(), []):
			if e.to != next:
				continue
			if e.entry == "move" and map.wall(e.x, e.y, e.dir) > 0 and map.door(e.x, e.y, e.dir) == 0:
				continue
			var path: Array = main._find_path(main._pos, Vector2i(e.x, e.y))
			if (path.size() > 0 or main._pos == Vector2i(e.x, e.y)) and path.size() < best_len:
				best = e
				best_len = path.size()
		if best.is_empty():
			_issue("travel: no open way from %s to %s" % [_here(), next])
			return
		print("   travel %s -> %s by %d,%d %s" % [_here(), next, best.x, best.y, "NESW"[best.dir]])
		var before := _here()
		await main._tour(Vector2i(best.x, best.y))
		await _settle()
		if _here() == before and best.entry == "move":
			while int(main._facing) != int(best.dir):
				await main._press("right")
			await main._press("up")
			await _settle()
		if _here() == before:
			_issue("travel: the way out at %d,%d didn't lead to %s" % [best.x, best.y, next])
			return
		await _heal_if_low()


## Visits a square of every event in the area, nearest first (except the listed events),
## healing when anyone is below half.
func _explore(skip: Array) -> void:
	var map: GeoMap = main._maps[main._map_index].map
	var area := _here()
	var todo := {}
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var ev := map.flag(x, y) & 127
			if ev == 0 or str(ev) in skip or todo.has(ev):
				continue
			todo[ev] = Vector2i(x, y)
	while not todo.is_empty() and not _wiped() and _here() == area:
		var best := -1
		var best_len := 1 << 20
		for ev in todo:
			var path: Array = main._find_path(main._pos, todo[ev])
			if path.size() > 0 and path.size() < best_len:
				best = ev
				best_len = path.size()
		if best < 0:
			print("   explore: no route to events %s" % str(todo.keys()))
			return
		var at: Vector2i = todo[best]
		todo.erase(best)
		print("   explore: event %d at %s" % [best, at])
		await main._tour(at)
		await _settle()
		await _heal_if_low()


func _heal_if_low() -> void:
	for m in main._party:
		if m.status != PartyMember.STATUS_OKAY or m.hp * 2 < m.hp_max:
			await _heal()
			return


# --- Characters -----------------------------------------------------------------------------

const RACES := {"dwarf": 1, "elf": 2, "gnome": 3, "half-elf": 4, "halfling": 5, "human": 7}
const CLASSES := {"cleric": 0, "fighter": 2, "magic-user": 5, "thief": 6, "cleric/fighter": 8,
	"cleric/fighter/magic-user": 9, "cleric/magic-user": 11, "cleric/thief": 10,
	"fighter/magic-user": 13, "fighter/thief": 14, "fighter/magic-user/thief": 15,
	"magic-user/thief": 16}
const ALIGNMENTS := {"lg": 0, "ln": 1, "le": 2, "ng": 3, "tn": 4, "ne": 5, "cg": 6, "cn": 7, "ce": 8}
## Main abilities by class part (0 cleric WIS, 2 fighter STR CON, 5 magic-user INT, 6 thief DEX).
const PRIME := {0: [2, 4], 2: [0, 4], 5: [1, 3], 6: [3, 4]}


func _make_char(race: String, cls: String, al: String, name: String) -> void:
	var rules := CreationRules.shared(main._game_path)
	var r: int = RACES[race]
	var c: int = CLASSES[cls]
	if not c in rules.classes_for(r):
		_issue("%s can't be a %s (classes %s)" % [race, cls, str(rules.classes_for(r))])
		return
	var align: int = ALIGNMENTS[al]
	if not align in rules.alignments_for(c):
		align = rules.alignments_for(c)[0]
	var rec := rules.start_record(r, 0, c, align, _rng)
	var best := PackedByteArray()
	var best_score := -1
	for attempt in 3000:
		rules.roll(rec, _rng)
		var score := 0
		var ok := true
		for p in CreationRules.parts(c):
			for a in PRIME.get(p, []):
				score += rec[0x10 + a]
				if rec[0x10 + a] < 15:
					ok = false
		if score > best_score:
			best_score = score
			best = rec.duplicate()
		if ok:
			best = rec.duplicate()
			break
	best[0] = name.length()
	for i in 15:
		best[1 + i] = name.unicode_at(i) if i < name.length() else 0
	best[0xBB] = _rng.randi_range(1, 14)
	best[0xBC] = _rng.randi_range(1, 12)
	var m := rules.member(best, ClassTables.shared(main._game_path), SpellTable.shared(main._game_path), main._types)
	m.recalculate(main._types)
	_new_party.append(m)
	print("   %s: %s %s STR %d/%d INT %d WIS %d DEX %d CON %d CHA %d HP %d gold %d" % [m.name, race, cls,
		m.stats[0], m.strength_exceptional, m.stats[1], m.stats[2], m.stats[3], m.stats[4], m.stats[5],
		m.hp_max, m.wealth_copper() / 200])


func _party_report() -> void:
	for m in main._party:
		print("   %-12s %s lv %s xp %d hp %d/%d AC %d THAC0 %d gp %d items %s" % [m.name, m.status_name(),
			str(Array(m.raw.slice(0x96, 0x9E)).filter(func(x): return x > 0)), m.experience, m.hp, m.hp_max,
			m.ac, m.thac0, m.wealth_copper() / 200, ", ".join(m.items.map(func(it): return it.name))])


# --- Camp ---------------------------------------------------------------------------------

func _needs_rest() -> bool:
	for m in main._party:
		if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
				and m.hp < m.hp_max and not SpecialAffects.diseased(m):
			return true
	return false


func _open_camp() -> bool:
	await _settle()
	if not main._camp.visible:
		await main._press("e")
		for i in 10:
			await get_tree().process_frame
	return main._camp.visible


## Rests in camp a day at a time until everyone is healed; an interruption is fought out
## and the rest begun again.
func _heal() -> void:
	var days := 0
	if _pick_spells():
		if await _open_camp():
			await _rest_in_camp(0)
			await _settle()
	while _needs_rest() and days < 60 and not _wiped():
		if not await _open_camp():
			_issue("couldn't open camp to heal at %s" % main._state_line())
			return
		var camp: CampScreen = main._camp
		camp._rest_menu()
		var need := 0
		for m in main._party:
			need = maxi(need, m.hp_max - m.hp)
		camp._to_rest = mini(need, 10) * 288
		camp._start_rest()
		while camp.visible and camp._resting:
			await get_tree().process_frame
		days += 1
		if camp.visible:
			await main._press("esc")
			await main._press("e")
		await _settle()
	if days > 0:
		print("   rested; %s" % " ".join(main._party.map(func(m): return "%d/%d" % [m.hp, m.hp_max])))


## What the bot memorizes, by class and level, in turn: clerics Cure Light Wounds twice to
## a Bless; Hold Person; Prayer. Magic-users Sleep and Magic Missile; Stinking Cloud;
## Fireball, Haste, Lightning Bolt.
const PICKS := [[[3, 3, 1], [23], [42]], [[21, 15], [34, 32], [47, 48, 51]]]


func _memorize() -> void:
	if not _pick_spells():
		return
	if not await _open_camp():
		return
	await _rest_in_camp(0)
	await _settle()
	print("   memorized: %s" % " | ".join(main._party.map(func(m): return "%s %s" % [m.name, str(m.memorized)])))


## Rests in the open camp: long enough to memorize, and `days` more.
func _rest_in_camp(days: int) -> void:
	var camp: CampScreen = main._camp
	camp._rest_menu()
	camp._to_rest += days * 288
	camp._start_rest()
	while camp.visible and camp._resting:
		await get_tree().process_frame
	if camp.visible:
		await main._press("esc")
		if camp.visible:
			await main._press("e")


## Queues the bot's spells in every caster's free slots; true if any.
func _pick_spells() -> bool:
	var table := SpellTable.shared(main._game_path)
	var any := false
	for m in main._party:
		if m.status != PartyMember.STATUS_OKAY:
			continue
		for c in 2:
			for lvl in range(1, 4):
				var n: int = m.slots_left(table, c, lvl)
				var picks: Array = PICKS[c][lvl - 1].filter(func(id): return m.knows(id))
				var k := 0
				while n > 0 and not picks.is_empty():
					m.memorized.append(int(picks[k % picks.size()]) + PartyMember.LEARNING)
					k += 1
					n -= 1
					any = true
	return any


# --- Town ---------------------------------------------------------------------------------

func _buy(who: int, name: String) -> void:
	var shop: ShopScreen = main._shop
	if not shop.visible:
		_issue("buy %s: no shop open" % name)
		return
	for i in shop._items.size():
		if shop._items[i].name.to_upper().begins_with(name.to_upper()):
			shop._buyer = who
			shop._pool()
			shop._reselect(i)
			shop._buy()
			print("   buy %s for %s: %s" % [shop._items[i].name, main._party[who].name, shop._note.text])
			return
	_issue("buy %s: not in this shop (%s)" % [name, ", ".join(shop._items.map(func(it): return it.name))])


func _train() -> void:
	var pm: PartyMenu = main._party_menu
	if not pm.visible:
		_issue("train: no training hall menu open")
		return
	_training = true
	for i in main._party.size():
		pm._sel = i
		pm._train()
		if pm._mode == "confirm_train":
			pm._do_train()
			if pm._mode == "learn":
				pm._learn_selected() if pm.has_method("_learn_selected") else await main._press("enter")
			print("   %s trained: %s" % [main._party[i].name, pm._note.text])
		else:
			print("   %s: %s" % [main._party[i].name, pm._note.text])
	_training = false
	await main._press("esc")
	await _settle()


## At an open temple: Raise Dead, Stone to Flesh and Cure Disease for whoever needs them,
## pooling the party's money with them first.
func _temple_cures() -> void:
	var t: TempleScreen = main._temple
	for i in main._party.size():
		for cure in [5, 8, 1]:
			if t._needs(main._party[i], cure):
				t._who = i
				t._pool()
				t._cure = cure
				t._pay()
				print("   temple: %s %s: %s" % [main._party[i].name, TempleScreen.CURES[cure][0], t._note.text])


func _load(name: String) -> void:
	DirAccess.copy_absolute("user://bot_%s.cfg" % name, main._save_path())
	main._lost = false
	if main._start_menu != null:
		main._start_menu.visible = false
	main._quick_load()
	await _settle()

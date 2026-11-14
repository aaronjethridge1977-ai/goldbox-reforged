class_name PlayBot
extends Node
## Lab: plays the game from a plan file, headless, as a player would: walks with the tour
## (Main._tour), answers prompts, fights on Quick, rests, memorizes, shops, trains. Logs
## every screen and every surprise; used for the M6 whole-game playthrough.
##
##   godot --headless --path <project> -- --game-path=<POOLRAD> --play=<plan file> [--fast]
##         [--resume=<quick save>:<checkpoint name>]   (start from another run's checkpoint)
##
## Plan lines ("#" starts a comment):
##   char <race> <class> <alignment> <name>   roll a character with the creation rules
##            (rerolled until its class's main abilities are 15+, as a player rerolls)
##   modify                MODIFY CHARACTER on the new characters, as a player would with the
##            party menu's MODIFY: every ability to 18 as far as race and class allow (fighters
##            on to 18/00 where allowed), HP to the most the classes and CON allow
##   begin                 start the adventure with them (PARTY CREATION's BEGIN ADVENTURING)
##   tour <x>,<y> ...      walk to each square in turn, playing whatever happens
##   face N|E|S|W / step / key <name> / answers a;b;c / say <text>
##   heal                  camp and rest until everyone is at full HP (handles interruptions)
##   memorize              fill every caster's spell slots (first spells in the book) and rest
##   train                 (in a training hall's party menu) train everyone who can
##   buy <member> <item>   (in a shop) buy the first item whose name starts so; pool first
##   temple                (at a temple) raise / cure / heal everyone who needs it
##   travel <set>:<block>  walk area to area by the area graph (--exits=)
##   explore [events]      visit every event of this area, resting first, training on the way;
##            the listed events (and any whose first fight looks unwinnable) wait for training
##   grind <hex addr> <n> rest here, fighting what comes, until script memory addr reaches n
##   town                  New Phlan's round: the clerk's rewards, temple, training halls, inn
##   clerk                 City Hall twice (rewards, then up to three commissions a visit)
##   rest <set:block> inn|camp [<hex addr> <value>]   where to rest in an area (the inn until
##            script memory addr reaches value, then camp); unlisted areas camp
##   status                print the counters (fights, rests, wipes, gold by source, trainings)
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
## M6 shortcuts: the last scripted fight opened ({key, area, at, monsters}), the fights to win
## by shortcut (keys), and the log of every shortcut used and every fight it skipped.
var _last_fight := {}
var _win_fights: PackedStringArray = []
var _shortcuts: Array = []
var _skipped_fights: Array = []
var _win_at: Array = []    # the plan's "shortcut win <n> at ...": [{n, at, ev, area}]
var _expected_level := {}
var _event_now := ""            # the event explore is walking to ("area map:event")
var _skip_events := {}          # events passed by shortcut after they beat the party twice       # area -> the level the game expects there (plan: level)
var _new_party: Array[PartyMember] = []
var _rng := RandomNumberGenerator.new()
var issues: PackedStringArray = []


func run(plan_path: String) -> void:
	_rng.randomize()
	CombatSpells.party_casts = true
	CombatSpells.party_planner = _plan_spell
	Combat.party_judge = _judge_fight
	main._combat.dev_win_if = _fight_opens
	main._combat.dev_round_check = _stalemate
	var text := FileAccess.get_file_as_string(plan_path)
	lines = text.split("\n")
	main.auto_hook = _hook
	main._camp.interrupted.connect(func(): _count("interrupted"))
	# Watchdog: the game's state every 2 real minutes, so a run that goes quiet shows where.
	var watch := Timer.new()
	watch.wait_time = 120.0
	watch.ignore_time_scale = true
	watch.timeout.connect(func() -> void:
		print("   [watch] ", main._state_line(), "  (busy %s, timer %s, walk %d, combat %s, camp %s)" % [
			main._busy, "stopped" if main._timer.is_stopped() else "running", main._walk_path.size(),
			main._combat.visible, main._camp.visible])
		# Coverage on disk every two minutes too (chat 13: a run stopped by its time limit
		# never reached _exit_tree, which is where it was saved).
		if main._vm != null and main._vm.coverage != null:
			main._vm.coverage.save()
		if main._shadow != null:
			main._shadow.coverage.save())
	add_child(watch)
	watch.start()
	# --resume=<quick save file>:<checkpoint name>: start from another run's checkpoint,
	# at the plan line after "checkpoint <name>" (the lab keeps them; game data, not in git).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resume="):
			var spec := arg.trim_prefix("--resume=")
			var cut := spec.rfind(":")
			var file := spec.left(cut)
			var name := spec.substr(cut + 1)
			var at := -1
			for i in lines.size():
				if lines[i].strip_edges() == "checkpoint " + name:
					at = i + 1
			if at < 0 or not FileAccess.file_exists(file):
				_issue("resume: no checkpoint %s in the plan, or no file %s" % [name, file])
				break
			DirAccess.copy_absolute(file, "user://bot_%s.cfg" % name)
			_load_counters(file.get_basename() + ".json")
			# The plan's standing rules above the checkpoint still hold.
			for i in at:
				var rule := lines[i].strip_edges()
				if rule.get_slice(" ", 0) in ["rest", "parley", "fight", "hire", "answer", "gate", "exit", "expect_level"]:
					await _do(rule)
			_pc = at
			_checkpoint = name
			_checkpoint_pc = at
			print("== resuming at checkpoint %s (plan line %d)" % [name, at + 1])
			await _load(name)
	while _pc < lines.size():
		var line := lines[_pc].strip_edges()
		_pc += 1
		if line == "" or line.begins_with("#"):
			continue
		print("\n>> [%ds] %s" % [Time.get_ticks_msec() / 1000, line])
		_last_fight = {}
		_event_now = ""
		if line == "stop":
			break
		await _do(line)
		if _wiped():
			_count("wipes")
			_issue("party wiped at plan line %d (%s)" % [_pc, line])
			if _checkpoint == "" or _retries >= 8:
				break
			_retries += 1
			var beaten := _last_fight.duplicate()
			var event_then := _event_now
			print("== back to checkpoint %s (try %d)" % [_checkpoint, _retries + 1])
			await _load(_checkpoint)
			_pc = _checkpoint_pc
			# M6 (Jeremy, 2026-11-12): the bot doesn't need to win. A failure takes the
			# smallest shortcut that works, logged, and the run moves on: first the party
			# restored before trying again, then the fight that beat it won by shortcut (it
			# goes on the list for the combat test suite). This replaced grinding a level.
			if _retries == 1:
				_shortcut("restore", DevShortcuts.restore(main._party), "wiped at plan line %d" % (_pc + 1))
			elif beaten.is_empty() and event_then != "":
				# Beaten twice by something that isn't a fight (a trap, a script): the smallest
				# shortcut is to pass that event by, logged.
				_shortcut("restore", DevShortcuts.restore(main._party), "wiped again")
				_skip_events[event_then] = true
				_shortcut("skip", event_then, "it beat the party twice, not in a fight")
			elif not beaten.is_empty():
				_shortcut("restore", DevShortcuts.restore(main._party), "wiped again")
				_win_fights.append(beaten.key)
				print("== the fight that beat the party will be won by shortcut: %s" % beaten.key)
	print("\n== PLAYTHROUGH ENDED at plan line %d; %d issues" % [_pc, issues.size()])
	for i in issues:
		print("ISSUE ", i)
	print(main._state_line())
	_party_report()
	_report()
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
	# The tour's memory of steps the game turned back only grows; over a long run it closes
	# whole routes ("no route from 0,4"). Each plan step starts with it empty.
	main._refused.clear()
	var w := line.split(" ", false)
	match w[0]:
		"char":
			_make_char(w[1], w[2], w[3], " ".join(w.slice(4)))
		"modify":
			_modify_all()
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
			var before := _coin()
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_book("shop", before)
			_want = ""
			_ready_all()
		"sell":
			_want = "sell"
			var a := w[1].split(",")
			var before := _coin()
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_book("selling", before)
			_want = ""
		"inn":
			_want = "inn"
			var a := w[1].split(",")
			if main._pos == Vector2i(int(a[0]), int(a[1])):
				await _step_off()
			var before := _coin()
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_book("inn", before)
			if _want == "inn" and main._message.text.contains("ENOUGH PLATINUM") and not _inn_retry:
				# Nobody has a platinum piece (the coins went on training). A purchase gives its
				# change in the largest coins (the original's way), so the richest buys a few
				# arrows and pays the inn from the change.
				_want = ""
				_inn_retry = true
				var rich := 0
				for k in main._party.size():
					if main._party[k].npc < 128 and main._party[k].wealth_copper() > main._party[rich].wealth_copper():
						rich = k
				print("   (no platinum for the inn: %s buys arrows for change)" % main._party[rich].name)
				await _do("shop 13,8 | %d 10 Arrow" % rich)
				await _do(line)
				_inn_retry = false
				return
			if _want == "inn" and main._pos != Vector2i(int(a[0]), int(a[1])) and not _inn_retry and not _wiped():
				# The walk stopped short (a fight on the way, or a stop left from the trip home:
				# chat 12, five members at 0 HP camped instead and set out again): once more.
				_want = ""
				_inn_retry = true
				main.tour_stop = false
				await _do(line)
				_inn_retry = false
				return
			if _want == "inn":
				_issue("the inn didn't take us (%s); memorizing in camp here" % main._message.text.strip_edges())
				_want = ""
				# Not the inn again from inside this (chat 13: arriving by boat at night, no
				# route to the inn; healing in camp sent the party back to the inn, and so on
				# for ten thousand lines): camp here as if at the inn.
				var was_at_inn := _at_inn
				_at_inn = true
				await _memorize()
				await _heal()
				_at_inn = was_at_inn
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
		"town":
			await _town()
		"grind":
			# grind <hex address> <value>: rest in this area (its patrols interrupt) and fight
			# them until the script's counter reaches the value (the Slums: 0x4ABB, 25 wins
			# make it 254, which the clerk's reward and the end of the patrols read).
			await _grind(w[1].hex_to_int(), int(w[2]))
		"level":
			# level <n>: camp here, fighting what interrupts (Podol Plaza's patrols, sized
			# to the party), training in town as each character qualifies, until everyone
			# is at least level n (a player's way to get strong enough for the next area).
			await _level_up(int(w[1]))
		"explore":
			await _keep_level()
			await _explore(w.slice(1))
		"expect_level":
			# expect_level <set:block> <n>: the level the game expects of a party there (M6: the
			# party is kept near it, since some encounters scale with the party).
			_expected_level[w[1]] = int(w[2])
		"memorize":
			await _memorize()
		"train":
			await _train()
		"buy":
			_buy(int(w[1]), " ".join(w.slice(2)))
		"temple":
			_want = "temple"
			var a := w[1].split(",")
			var before := _coin()
			await main._tour(Vector2i(int(a[0]), int(a[1])))
			await _settle()
			_book("temple", before)
			_want = ""
		"clerk":
			await _clerk()
		"rest":
			# rest <set:block> inn|camp [<hex address> <value>]: where a player rests in that
			# area (the Clue Book's table). "inn" with an address: the inn until script
			# memory there reaches the value (the area's condition for safe rests), then camp.
			_rest_rules[w[1]] = {"rule": w[2], "addr": w[3].hex_to_int() if w.size() > 4 else -1,
				"value": int(w[4]) if w.size() > 4 else 0}
		"status":
			_report()
		"search":
			# search on|off: SEARCH mode as the original's (steps take 10 minutes; some scripts,
			# the library's stacks, only give what they hide to a searching party).
			main._searching = w[1] == "on"
			main._vm.write_byte(main.SEARCH_FLAG, 1 if main._searching else 0)
		"revisit":
			# revisit <event> <times>: walk onto that event's nearest square again and again
			# (off and back on), playing whatever it gives (the library's stacks: one book a visit).
			for n in int(w[2]):
				if _wiped():
					break
				var map: GeoMap = main._maps[main._map_index].map
				var best := Vector2i(-1, -1)
				var best_len := 1 << 20
				for y in GeoMap.SIZE:
					for x in GeoMap.SIZE:
						if map.flag(x, y) & 127 == int(w[1]):
							var path: Array = main._find_path(main._pos, Vector2i(x, y))
							if path.size() > 0 and path.size() < best_len:
								best = Vector2i(x, y)
								best_len = path.size()
				if best.x < 0:
					_issue("revisit: no way to event %s" % w[1])
					break
				if main._pos == best:
					await _step_off()
				await main._tour(best)
				await _settle()
				await _heal_if_low()
		"restuntil":
			# restuntil <hour>: camp here and rest until that hour of the day (Stojanow Gate's
			# trader drives up only before 14:00); interruptions are fought out.
			var want := int(w[1])
			var hrs := (want - GameClock.hour(main._vm) + 24) % 24
			if hrs > 0 and not _wiped() and await _open_camp():
				var camp: CampScreen = main._camp
				camp._rest_menu()
				camp._to_rest += hrs * 12
				_start_rest(camp)
				while camp.visible and camp._resting:
					await get_tree().process_frame
				if camp.visible:
					await main._press("esc")
					if camp.visible:
						await main._press("e")
				await _settle()
			print("   rested until %s" % GameClock.text(main._vm))
		"campday":
			# campday <n>: camp here n days whatever comes (a script that moves on when the
			# party rests: the nomads' kobold attack), fighting each interruption.
			for d in int(w[1]):
				if _wiped() or not await _open_camp():
					break
				await _rest_in_camp(1)
				await _settle()
				if _hurt():
					_cure_in_camp()
		"exit":
			# exit <from set:block> <x>,<y> <N|E|S|W> <to set:block>: a map edge the area graph
			# can't name (scripts that pick the next area from a table: the Temple of Bane).
			_load_exits()
			var xy := w[2].split(",")
			if not _exits.has(w[1]):
				_exits[w[1]] = []
			_exits[w[1]].append({"x": int(xy[0]), "y": int(xy[1]), "dir": "NESW".find(w[3]), "entry": "move", "to": w[4]})
		"gate":
			# gate <from set:block> <x>,<y> <to set:block> <choice>: a way between areas that
			# a menu opens (the band outside the walls: "EASTERN EDGE ... NORTH SOUTH BOAT").
			_load_exits()
			var xy := w[2].split(",")
			if not _exits.has(w[1]):
				_exits[w[1]] = []
			_exits[w[1]].append({"x": int(xy[0]), "y": int(xy[1]), "dir": 0, "entry": "gate", "to": w[3], "answer": " ".join(w.slice(4)).to_upper()})
		"answer":
			# answer <set:block> <words of the question>|<choice>: answer that question so.
			var spec := " ".join(w.slice(2)).split("|")
			if not _answer_rules.has(w[1]):
				_answer_rules[w[1]] = []
			_answer_rules[w[1]].append([spec[0].strip_edges(), spec[1].strip_edges().to_upper(), 0])
		"fight":
			# fight <set:block> <words of the encounter's text>: COMBAT there (a story fight the
			# bot's odds would flee: Tyranthraxus's guards). Lost twice, it goes by shortcut.
			if not _fight_cues.has(w[1]):
				_fight_cues[w[1]] = []
			_fight_cues[w[1]].append(" ".join(w.slice(2)))
		"parley":
			# parley <set:block> <words of the encounter's text>: PARLAY there, not COMBAT.
			if not _parley_cues.has(w[1]):
				_parley_cues[w[1]] = []
			_parley_cues[w[1]].append(" ".join(w.slice(2)))
		"hire":
			# hire <n>: how many hired NPCs the party takes on when the arena offers them.
			_hire_wanted = int(w[1])
		"shortcut":
			await _shortcut_command(w)
		"rules":
			# rules <plan file>: the standing rules of another plan (answer, parley, fight, rest,
			# gate, exit, hire, expect_level lines), for a coverage plan that starts mid-game.
			var text := FileAccess.get_file_as_string("res://tools/plans/" + w[1])
			for rule in text.split("\n"):
				rule = rule.strip_edges()
				if rule.get_slice(" ", 0) in ["rest", "parley", "fight", "hire", "answer", "gate", "exit", "expect_level"]:
					await _do(rule)
		"start":
			# start <checkpoint name>: load bot_<name>.cfg from the folder given by
			# --checkpoints=<folder> (the lab keeps the main line's checkpoints; game data).
			var folder := ""
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--checkpoints="):
					folder = arg.trim_prefix("--checkpoints=")
			# (<folder>/<name>: a checkpoint from an earlier run's set, e.g. chat10a_latest/slums)
			var file := folder.path_join(w[1].get_base_dir()).path_join("bot_%s.cfg" % w[1].get_file())
			if not FileAccess.file_exists(file):
				_issue("start: no checkpoint %s" % file)
				_pc = lines.size()
				return
			DirAccess.copy_absolute(file, "user://bot_%s.cfg" % w[1].get_file())
			_load_counters(file.get_basename() + ".json")
			_checkpoint = w[1].get_file()
			_checkpoint_pc = _pc
			await _load(w[1].get_file())
		"cover":
			# cover <set:block> [minutes]: a coverage run of that area (M6, method of
			# 2026-11-13): every event square from every side on every map of the area, fights
			# won at once by logged shortcut, and every menu choice not yet taken played for
			# real from a snapshot of the step that led to it.
			# "all" after the minutes: every other choice is played, taken before or not
			# (a variant run, a smaller party, whose answers lead elsewhere).
			# "fresh" (chat 15): each event is walked to from the part's arrival, not from where
			# the last one left the party (an alarm raised by one fight changes every event
			# after it: 5:4's fighter only comes out while the alarm is off).
			_cover_all = "all" in w.slice(3)
			_cover_fresh = "fresh" in w.slice(3)
			await _cover(w[1], int(w[2]) if w.size() > 2 else 60)
			_cover_all = false
			_cover_fresh = false
		"checkpoint":
			_checkpoint = w[1]
			_checkpoint_pc = _pc
			_retries = 0
			main._quick_save()
			DirAccess.copy_absolute(main._save_path(), "user://bot_%s.cfg" % w[1])
			_save_counters("user://bot_%s.json" % w[1])
			print("== checkpoint %s" % w[1])
			_report()
		"expect":
			var a := w[1].split(":")
			if main._vm_file != int(a[0]) or main._vm_block != int(a[1]):
				_issue("expected area %s, in %d:%d (%s)" % [w[1], main._vm_file, main._vm_block, line])
		"log":
			print("==== ", " ".join(w.slice(1)))
		_:
			_issue("unknown plan command: " + line)
	print("   ", main._state_line(), " map ", main._maps[main._map_index].id)


## Waits until nothing is open or running, playing it out with the tour's policy.
## The quiet window _settle waits for before it trusts that nothing more is coming (ms, and
## at least 10 frames). 70 matched the old 10 frames at 145 a second; 15 is enough (chat 16:
## 4:21 and 6:28 the same at both), and a coverage run calls _settle thousands of times.
const QUIET_MS := 15


func _settle() -> void:
	# Chat 16: the limits are real time, not frames. Headless runs used to sleep 6.9 ms a frame
	# (145 frames a second); with --fast that sleep is gone, and 20000 frames ran out in 3 s,
	# in the middle of 6:28's guided tour. 140 s is what 20000 frames were.
	var deadline := Time.get_ticks_msec() + 140000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await main._auto_handle():
			# Chat 17: the window is game time (what the timers count): QUIET_MS of real time at
			# --fast's 25 times. With --time-scale=1000 it passes in a few frames; the 15 ms of
			# real time were most of a coverage run's time. Real time still bounds it.
			var quiet := Time.get_ticks_msec() + QUIET_MS
			var game_ms := 0.0
			var frames := 0
			while frames < 10 or (game_ms < QUIET_MS * 25.0 and Time.get_ticks_msec() < quiet):
				frames += 1
				await get_tree().process_frame
				game_ms += get_process_delta_time() * 1000.0
			if not await main._auto_handle():
				return


## The tour's policy, with the party's own judgement where it matters: in fights everyone
## on Quick (the computer fights for them, as the original's QUICK does).
func _hook() -> bool:
	if _cover_area != "" and await _cover_hook():
		return true
	# Names and passwords the game tells the party ("SPEAK MY NAME, OHLO."), for when a
	# script asks for a word.
	var said: String = main._message.text
	# An encounter menu with no text of its own (Stojanow Gate's trader: "A MAN DRIVING A
	# WAGON..." comes first, then a bare COMBAT WAIT FLEE PARLAY) is read with what came before.
	if said.strip_edges() != "" and not said.contains("COMBAT    2) WAIT"):
		_said_before = said
	if not _first_day.has(_here()) and main._vm_file > 0:
		_first_day[_here()] = _day()
		print("   (first time in %s: day %d)" % [_here(), _day()])
	for cue in ["SPEAK MY NAME, ", "THE PASSWORD IS ", "PASSWORD IS "]:
		var at := said.find(cue)
		if at >= 0:
			var rest := said.substr(at + cue.length())
			var word := ""
			for ch in rest:
				if ch < "A" or ch > "Z":
					break
				word += ch
			if word != "" and not word in _words:
				_words.append(word)
				print("   (bot remembers the word %s)" % word)
	if main._vm.state == EclVM.State.INPUT and main._tour_answers.is_empty():
		# A player reads the word from the runes or the journal; the bot reads what the script
		# compares the answer with, just ahead ('RHODIA', the booth's 'OHLO').
		var lit := _word_ahead()
		if lit != "":
			print("   >> typed %s (the word the script expects)" % lit)
			main._on_typed(lit)
			return true
	if main._vm.state == EclVM.State.INPUT and main._tour_answers.is_empty() and not _words.is_empty():
		var w: String = _words[_word_try % _words.size()]
		_word_try += 1
		print("   >> typed %s (remembered)" % w)
		main._on_typed(w)
		return true
	if main._combat.visible and main._combat._result != 0 and not _fight_noted:
		_fight_noted = true
		_count(["", "won", "lost", "fled"][main._combat._result])
		if _hurt():
			main.tour_stop = true
			_interrupted = true
	elif not main._combat.visible:
		_fight_noted = false
	if main._vm.state == EclVM.State.MENU and main._vm._menu_kind == "encounter" and not main._combat.visible:
		var k := _encounter_choice()
		# Encounters the Clue Book says to talk to (Ferran Martinez...): PARLAY.
		var offered: Array = Array(main._vm.menu).map(func(x): return String(x).strip_edges().to_upper())
		var heard := said
		if said.split("\n")[0].strip_edges() == "" or said.strip_edges().begins_with("1) COMBAT"):
			heard = _said_before
		for cue in _fight_cues.get(_here(), []):
			if heard.contains(cue) and "COMBAT" in offered:
				k = offered.find("COMBAT") + 1
				_judged = "the plan fights here (%s)" % cue
		for cue in _parley_cues.get(_here(), []):
			if heard.contains(cue) and "PARLAY" in offered:
				k = offered.find("PARLAY") + 1
				_judged = "the plan parleys here (%s)" % cue
			elif heard.contains(cue) and "ADVANCE" in offered:
				# Not close enough to talk yet (the pyramid's pumping room: the slaves stand
				# three squares off): ADVANCE until PARLAY is offered.
				k = offered.find("ADVANCE") + 1
				_judged = "closing in to parley (%s)" % cue
		if k == 3:
			_count("avoided")
		print("   >> %d (encounter: %s)" % [k, _judged])
		await main._press(str(k))
		return true
	if main._vm.state == EclVM.State.MENU and main._message.text.contains("WHO WILL PAY") and main._vm.menu.size() == main._party.size():
		# NPCs won't pay ("THAT PERSON WON'T PAY.": 0x6BB8 is 128 and up).
		var best := -1
		for i in main._party.size():
			if main._party[i].npc < 128 and (best < 0 or main._party[i].money[4] > main._party[best].money[4]):
				best = i
		best = maxi(best, 0)
		print("   >> %d (most platinum: %d)" % [best + 1, main._party[best].money[4]])
		await main._press(str(best + 1))
		return true
	if main._treasure.visible and main._treasure._page == 1 and not main._treasure._amount_open \
			and not main._treasure._asking_exit:
		if not _looted:
			# A player takes the money (SHARE) and every item, handed round the party.
			_looted = true
			var t: TreasureScreen = main._treasure
			var before := _coin()
			var gems_before := _gems()
			t._share()
			# City Hall's rewards come through a treasure screen too.
			var source := "rewards" if _here() == "3:8" else "treasure"
			_book(source, before)
			_gem_ledger[source] = int(_gem_ledger.get(source, 0)) + _gems() - gems_before
			# Items: only what a player carries off (magic, scrolls, potions, wands...), not
			# every orc's spear.
			for n in 60:
				var pick := -1
				for i in t._spoils.items.size():
					if _worth_taking(t._spoils.items[i]):
						pick = i
						break
				if pick < 0:
					break
				t._who = _loot_turn % main._party.size()
				_loot_turn += 1
				if not t._take_item(pick):
					break
				print("   loot: %s" % t._note.text)
			_ready_all()
		return false
	if not main._treasure.visible:
		_looted = false
	if _want == "sell" and main._shop.visible:
		# The town round: every gem and piece of jewellery appraised and sold.
		_want = ""
		var shop: ShopScreen = main._shop
		var got := 0
		for i in main._party.size():
			shop._buyer = i
			var m: PartyMember = main._party[i]
			while m.money[5] > 0 or m.money[6] > 0:
				var v := shop.appraise_one(m.money[5] == 0)
				if v < 0:
					break
				got += v
				shop.settle(true)
		print("   appraised and sold gems and jewellery for %d gold" % got)
		# And the plain gear nobody has readied, at the shop's half price.
		var gear := 0
		for m in main._party:
			if m.npc >= 128:
				continue
			for it in m.items.duplicate():
				if not it.readied and not _keeper(it) and not _missile_kit(m, it) and it.price >= 2:
					m.items.erase(it)
					m.receive_gold(CharacterSheet._sale_price(it))
					gear += CharacterSheet._sale_price(it)
		print("   sold spare gear for %d gold" % gear)
		shop._mode = "menu"
		shop._exit()
		return true
	if _want == "shop" and main._shop.visible:
		for b in _buys:
			_buy(int(b[0]), String(b[1]))
		_buys = []
		_want = ""
		main._shop._exit()
		return true
	if main._vm.state == EclVM.State.MENU and main._tour_answers.is_empty() and main._vm._menu_kind != "encounter":
		# A player doesn't attack the people the scripts put in his way (the Slums' fortune
		# teller: murdering her raises the alarm for good). LEAVE when it is offered.
		var items: Array = Array(main._vm.menu).map(func(x): return String(x).strip_edges().to_upper())
		# The same question again and again (a script that puts the party back outside, and the
		# walk going straight back in): stop the walk.
		var ask: String = "%s %s|" % [_here(), main._pos] + main._message.text.strip_edges().left(80) + "|" + " ".join(items)
		# Chat 17: counted since the last restore (a coverage run comes back to a square from a
		# snapshot many times on purpose; 6:25's cave passage then answered LEAVE CAVE).
		ask = "%d|%s" % [main.dev_restores, ask]
		# (Any way out counts: "LEAVE IT" at Kovel Mansion's trapped cabinet, chat 10, where
		# EXAMINE / LEAVE over and over set the gas trap off until the party died.)
		if "ATTACK" in items or "TALK" in items or items.any(func(x): return String(x).begins_with("LEAVE")):
			_asked[ask] = int(_asked.get(ask, 0)) + 1
		if int(_asked.get(ask, 0)) > 3:
			main.tour_stop = true
			if int(_asked[ask]) == 4:
				_issue("the same question keeps coming at %s %s: %s" % [_here(), str(main._pos), ask.left(120)])
			# A script asking over and over without the party moving (Kovel Mansion's
			# trapped cabinet loops on its own): take the way out it offers.
			for k in items.size():
				if String(items[k]).begins_with("LEAVE"):
					print("   >> %d (%s: asked too often)" % [k + 1, items[k]])
					await main._press(str(k + 1))
					return true
		# Ladders and stairs to the area's other map: not while this map still has events to
		# see (Kuto's Well: down the rungs, then 'CLIMB UP THE RUNGS?' at the bottom).
		var planned: bool = Array(_answer_rules.get(_here(), [])).any(func(r): return said.contains(String(r[0])))
		if "YES" in items and "NO" in items and (said.contains("CLIMB") or said.contains("STAIRS")) and not planned:
			# Only when explore is going for the ladder on purpose (its last stop on a map,
			# or the way back up); passing the well on the way elsewhere is a NO.
			var left := _unvisited_here()
			var k: int = items.find("YES") if left == 0 and _ladder_ok else items.find("NO")
			if items[k] == "YES":
				_ladder_ok = false
				_climbed = true
			var key := "%d:%d" % [main._map_index, main._maps[main._map_index].map.flag(main._pos.x, main._pos.y) & 127]
			if items[k] == "NO" and left > 0:
				_visited.erase(key)       # come back to it last
				_ladders[key] = true
			elif items[k] == "YES":
				_ladders.erase(key)
			print("   >> %d (%s: %d events left on this map)" % [k + 1, items[k], left])
			await main._press(str(k + 1))
			return true
		if "SURRENDER" in items and ("FIGHT" in items or "ATTACK" in items):
			# Norris the Gray's 'SURRENDER OR DIE!': surrendering loses every valuable.
			var fight: int = items.find("FIGHT") if "FIGHT" in items else items.find("ATTACK")
			print("   >> %d (no surrender)" % (fight + 1))
			await main._press(str(fight + 1))
			return true
		# "YOU ARE ABOUT TO LEAVE THIS AREA. DO YOU WANT TO RETURN?" (stepping out into the
		# band): LEAVE on the way somewhere, RETURN while exploring.
		if said.contains("ABOUT TO LEAVE THIS AREA") and "RETURN" in items and "LEAVE" in items:
			var k: String = "LEAVE" if _travelling else "RETURN"
			print("   >> %d (%s)" % [items.find(k) + 1, k])
			await main._press(str(items.find(k) + 1))
			return true
		# "BACK INTO THE WILDERNESS?": yes on the way out, no while exploring.
		if said.contains("BACK INTO THE WILDERNESS") and "YES" in items and "NO" in items:
			var k: String = "YES" if _travelling else "NO"
			await main._press(str(items.find(k) + 1))
			return true
		# An exit the sweep found behind menu choices ("DO YOU WANT TO LEAVE?" YES): its picks.
		if not _gate_picks.is_empty() and _travelling and main._pos == _gate_square:
			var k: int = _gate_picks.pop_front()
			print("   >> %d (the way out)" % k)
			await main._press(str(k))
			return true
		# A gate travel is going through (gate lines): its choice.
		# (Several choices, comma-separated, for a way through more than one menu: the
		# rowboat's YES, then the pyramid door's ENTER.)
		for g in _gate_answer.split(",", false):
			if g.strip_edges() in items:
				# Chat 17: the same gate answer over and over (6:19 empty: in, out at once, the
				# cave's menu again) ends the trip through it.
				_gate_uses += 1
				if _gate_uses > 6:
					print("   (the gate's answer given 6 times: giving up on it)")
					_gate_answer = ""
					_gate_uses = 0
					main.tour_stop = true
					break
				print("   >> %d (%s: the way to go)" % [items.find(g.strip_edges()) + 1, g.strip_edges()])
				await main._press(str(items.find(g.strip_edges()) + 1))
				return true
		# A wilderness site passed on the way elsewhere ("YOU HAVE FOUND SOME RUINED HUTS.
		# WILL YOU INVESTIGATE?" INVESTIGATE / LEAVE): leave it (chat 12: travel went into the
		# huts' sub-map of 7:26 and lost its way); explore still goes in.
		if _travelling and items.size() == 2 and items[1] == "LEAVE" and said.contains("WILL YOU"):
			print("   >> 2 (LEAVE: only passing)")
			await main._press("2")
			return true
		# The plan's answers to particular questions (answer <area> <text>|<choice>[,<choice>...]):
		# several choices are taken in turn, one each time the question comes (the pyramid's
		# rocks room: THROW A ROCK, then MOVE ON).
		for rule in _answer_rules.get(_here(), []):
			if not said.contains(rule[0]):
				continue
			var picks: PackedStringArray = String(rule[1]).split(",")
			var pick: String = picks[int(rule[2]) % picks.size()].strip_edges()
			if pick in items:
				rule[2] = int(rule[2]) + 1
				print("   >> %d (%s: the plan's answer)" % [items.find(pick) + 1, pick])
				await main._press(str(items.find(pick) + 1))
				return true
		# PARLAY's manner (HAUGHTY SLY NICE MEEK ABUSIVE): NICE, as the Clue Book advises with
		# anyone not plainly hostile (Ohlo fights the HAUGHTY and the ABUSIVE and offers his
		# commission to the NICE and the MEEK).
		if "NICE" in items and "HAUGHTY" in items:
			_count("parleys")
			print("   >> %d (parley: NICE)" % (items.find("NICE") + 1))
			await main._press(str(items.find("NICE") + 1))
			return true
		# Podol Plaza's gate (STRIDE BOLDLY / DISGUISE / SNEAK): the Clue Book goes in
		# disguised, on the clerk's secret mission.
		for k in items.size():
			if String(items[k]).begins_with("DISGUISE"):
				print("   >> %d (DISGUISE)" % (k + 1))
				await main._press(str(k + 1))
				return true
		if "ACCEPT THE COMMISSION" in items:
			print("   >> 1 (accepting the commission)")
			await main._press("1")
			return true
		for talk in ["TALK", "SPEAK"]:
			if "ATTACK" in items and talk in items and int(_asked.get(ask, 0)) <= 2:
				print("   >> %d (%s rather than ATTACK)" % [items.find(talk) + 1, talk])
				await main._press(str(items.find(talk) + 1))
				return true
		if "ATTACK" in items and "LEAVE" in items:
			print("   >> %d (LEAVE rather than ATTACK)" % (items.find("LEAVE") + 1))
			await main._press(str(items.find("LEAVE") + 1))
			return true
		# The arena's hirelings ("DO YOU SEEK A PARTNER", then each offer): only as many hired
		# NPCs as the plan asks for (`hire <n>`; none by default). Each takes shares of every
		# treasure (three for a robber or a swordsman).
		if (said.contains("SEEK A PARTNER") or said.contains("CONSIDER SOMEONE ELSE") or said.contains("IS THIS ACCEPTABLE")) \
				and "YES" in items and "NO" in items:
			var hired: int = main._party.filter(func(m): return m.npc >= 128).size()
			var k: String = "YES" if hired < _hire_wanted else "NO"
			print("   >> %d (%s: %d hired, plan wants %d)" % [items.find(k) + 1, k, hired, _hire_wanted])
			await main._press(str(items.find(k) + 1))
			return true
		# City Hall's council guard: "HALT. YOUR PRESENCE IS NOT AUTHORIZED. LEAVE. DO YOU LEAVE?"
		if said.contains("DO YOU LEAVE") and "YES" in items:
			print("   >> %d (leaving, as the guard asks)" % (items.find("YES") + 1))
			await main._press(str(items.find("YES") + 1))
			return true
		# Nor does he break into the town's houses or fight the city watch.
		if said.contains("BREAK IN") and "NO" in items:
			print("   >> %d (no breaking in)" % (items.find("NO") + 1))
			await main._press(str(items.find("NO") + 1))
			return true
		# The arena's duels give nothing the plan needs.
		if said.contains("DO YOU DUEL") and "NO" in items:
			print("   >> %d (no duel)" % (items.find("NO") + 1))
			await main._press(str(items.find("NO") + 1))
			return true
		if said.contains("CITY WATCH") and "RUN" in items:
			print("   >> %d (running from the watch)" % (items.find("RUN") + 1))
			await main._press(str(items.find("RUN") + 1))
			return true
	if main._vm.state == EclVM.State.MENU and ((_want == "train" and main._message.text.contains("WANT TO TRAIN")) \
			or (_want in ["sell", "shop"] and (main._message.text.contains("SHOW YOU OUR WARES") \
				or main._message.text.contains("CAN I SHOW YOU SOMETHING") or main._message.text.contains("SEE OUR SELECTION"))) \
			or (_want == "temple" and main._message.text.contains("HEALING"))):
		await main._press("1")
		return true
	if _want == "inn" and main._vm.state == EclVM.State.MENU and main._message.text.contains("TO REST HERE"):
		await main._press("1")
		return true
	if not main._camp.visible:
		_own_camp = false
	if _want == "" and main._camp.visible and not _own_camp and not _resting_now and not main._camp._resting:
		# A script's own lodging (the nomads' hut: "HERE YOU MAY REST", then the headman's
		# morning): a night's rest, and long enough to memorize.
		_resting_now = true
		_pick_spells()
		var camp: CampScreen = main._camp
		camp._rest_menu()
		camp._to_rest = maxi(camp._to_rest, 10 * 12)
		_start_rest(camp)
		while camp.visible and camp._resting:
			await get_tree().process_frame
		if camp.visible:
			await main._press("esc")
			if camp.visible:
				await main._press("e")
		_resting_now = false
		print("   (rested in the lodging the script gave)")
		return true
	if _want == "inn" and main._camp.visible:
		_want = ""
		_pick_spells()
		var need := 0
		for m in main._party:
			if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
				need = maxi(need, m.hp_max - m.hp)
		# Long enough to memorize and heal; on to the morning when New Phlan's doors are
		# shut (from hour 14) and the party came to wait for them.
		var camp: CampScreen = main._camp
		camp._rest_menu()
		camp._to_rest += mini(need, 14) * 288
		if _inn_till_day:
			var h := GameClock.hour(main._vm)
			var till := ((24 - h) * 60 - GameClock.minute(main._vm) + 5) / 5
			camp._to_rest = maxi(camp._to_rest, till)
		_start_rest(camp)
		while camp.visible and camp._resting:
			await get_tree().process_frame
		if camp.visible:
			await main._press("esc")
			if camp.visible:
				await main._press("e")
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


## Readies the best of what each member carries, as a player does with the character
## sheet's READY (the sheet refuses what doesn't fit): first anything into an empty slot,
## then each spare weapon, shield and armour tried in place of what holds its slot, kept
## when it scores better (expected melee damage a round against AC 5, plus AC).
## Missile weapons are left to the fight's own weapon choice (Combat picks a readied bow or
## the best melee weapon carried).
func _ready_all() -> void:
	var sheet: CharacterSheet = main._sheet
	var types: ItemTypes = main._types
	for m in main._party:
		for it in m.items:
			if not it.readied:
				sheet._ready_item(m, it)
		m.recalculate(types)
		for round_no in 2:
			for it in m.items.duplicate():
				if _try_ready(m, it, 0.01):
					print("   ready: %s readies %s" % [m.name, it.name])
	# Then hand spare weapons and armour round (TRADE): a player gives the cleric's spare
	# sword to the fighter. Hired NPCs neither give nor take.
	for m in main._party:
		if m.npc >= 128:
			continue
		for it in m.items.duplicate():
			if it.readied or it.cursed or not _swappable(it):
				continue
			for o in main._party:
				if o == m or o.npc >= 128 or o.status != PartyMember.STATUS_OKAY:
					continue
				m.items.erase(it)
				o.items.append(it)
				if _try_ready(o, it, 0.5):
					print("   trade: %s gives %s to %s, who readies it" % [m.name, it.name, o.name])
					m.recalculate(types)
					break
				o.items.erase(it)
				m.items.append(it)


func _swappable(it: GameItem) -> bool:
	var types: ItemTypes = main._types
	var slot := types.slot(it.type)
	if not slot in [ItemTypes.SLOT_WEAPON, ItemTypes.SLOT_SHIELD, ItemTypes.SLOT_ARMOR]:
		return false
	return not (slot == ItemTypes.SLOT_WEAPON and types.flags(it.type) & (ItemTypes.FLAG_LAUNCHER | ItemTypes.FLAG_THROWN))


## Readies `it` on m in place of what holds its slot (a shield and a two-handed weapon
## exclude each other) when that raises m's gear score by more than `gain`; else puts
## everything back. True if it was kept.
func _try_ready(m: PartyMember, it: GameItem, gain: float) -> bool:
	var sheet: CharacterSheet = main._sheet
	var types: ItemTypes = main._types
	if it.readied or it.cursed or not _swappable(it):
		return false
	var slot := types.slot(it.type)
	var off: Array[GameItem] = []
	for o in m.items:
		if not o.readied or o == it:
			continue
		var os := types.slot(o.type)
		if os == slot or (slot == ItemTypes.SLOT_WEAPON and os == ItemTypes.SLOT_SHIELD and types.hands(it.type) >= 2) \
				or (slot == ItemTypes.SLOT_SHIELD and os == ItemTypes.SLOT_WEAPON and types.hands(o.type) >= 2):
			off.append(o)
	if off.any(func(o): return o.cursed):
		return false
	var score := _gear_score(m)
	for o in off:
		sheet._ready_item(m, o)
	sheet._ready_item(m, it)
	m.recalculate(types)
	if it.readied and _gear_score(m) > score + gain:
		return true
	if it.readied:
		sheet._ready_item(m, it)
	for o in off:
		sheet._ready_item(m, o)
	m.recalculate(types)
	return false


## How good a member's readied gear is: expected melee damage a round against AC 5, plus
## a third of a point for each point of AC (one AC point is 5% fewer enemy hits).
func _gear_score(m: PartyMember) -> float:
	var types: ItemTypes = main._types
	var missile := 0.0
	for it in m.items:
		if it.readied and types.slot(it.type) == ItemTypes.SLOT_WEAPON \
				and types.flags(it.type) & (ItemTypes.FLAG_LAUNCHER | ItemTypes.FLAG_THROWN):
			missile = 100.0     # a bow in hand outside a fight: a melee weapon is better
	return _dpr(m, 5) + (10 - m.ac) * 0.35 - missile


# --- A player's judgement in fights --------------------------------------------------------

var _judged := ""
var _fight_noted := false
var _looted := false
var _asked := {}      # script questions answered, by text and choices
var _visited := {}    # "map:event" explored in this area's explore
var _ladders := {}    # "map:event" ladders and stairs left for last
var _no_route := {}   # "map:event" explore found no way to
var _todo_now := {}   # the current explore pass's list of events still to visit
var _ladder_ok := false   # explore is going for a ladder on purpose
var _climbed := false     # explore took stairs or a ladder (YES) since the last pass
var _purse_needed := 0   # after a town round that trained nobody: the purse to come back with
var _words: PackedStringArray = []   # names and passwords the game has told the party
var _word_try := 0
var _loot_turn := 0
var _interrupted := false     # a tour was stopped after a fight that left the party hurt
var _at_inn := false          # on a trip to the inn and back


## Hurt enough to stop and rest: anyone down, or the party below 60% of its HP.
func _hurt() -> bool:
	var hp := 0
	var most := 0
	for m in main._party:
		if m.status in [PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
			return true
		if m.status == PartyMember.STATUS_OKAY:
			hp += m.hp
			most += m.hp_max
	return hp * 5 < most * 3
var _fled: PackedStringArray = []


## Expected damage a round from `a` against armour class `ac`.
static func _dpr(a: PartyMember, ac: int) -> float:
	var hit := clampf((21.0 - (a.thac0 - ac)) / 20.0, 0.05, 0.95)
	var d: Array = a.damage
	var avg := float(d[0]) * (float(d[1]) + 1.0) / 2.0 + float(d[2])
	var d2: Array = a.base_damage_2
	if a.is_monster and int(d2[0]) > 0:
		avg += float(d2[0]) * (float(d2[1]) + 1.0) / 2.0 + float(d2[2])
	return hit * maxf(avg, 1.0) * maxf(a.half_attacks, 1) / 2.0


## COMBAT (1) or FLEE (3) at an encounter menu: the party's staying power times its damage
## against the monsters' (Lanchester's square law in rough form), with what the party's
## Sleep spells would take out of the fight first.
func _encounter_choice() -> int:
	var mons: Array[PartyMember] = []
	for row in main._vm.monsters + _monsters_ahead():
		var first := PartyMember.load_monster(main._game_path, maxi(main._vm_file, 1), int(row[0]))
		if first == null:
			continue
		first.recalculate(main._types)
		for n in int(row[1]):
			mons.append(first)
	# A party already beaten up runs, whatever it meets.
	var standing := 0
	var hp := 0
	var hp_max := 0
	for m in main._party:
		hp_max += m.hp_max
		if m.status == PartyMember.STATUS_OKAY:
			standing += 1
			hp += m.hp
	if standing * 2 < main._party.size() or hp * 5 < hp_max * 2:
		_judged = "%d standing, %d/%d HP" % [standing, hp, hp_max]
		return 3
	if mons.is_empty():
		_judged = "no monsters known"
		return 1
	var up: Array[PartyMember] = []
	for m in main._party:
		if m.status == PartyMember.STATUS_OKAY:
			up.append(m)
	# Sleep: about 10 hit dice of the weakest per spell.
	var sleeps := 0
	for m in up:
		for id in m.ready_spells():
			if id == 21:
				sleeps += 1
	var left: Array[PartyMember] = mons.duplicate()
	left.sort_custom(func(a, b): return a.raw[0x73] < b.raw[0x73])
	var budget := sleeps * 10
	var slept := 0
	while not left.is_empty() and budget > 0 and int(left[0].raw[0x73]) <= 4:
		var cost: int = [1, 1, 2, 4, 6][int(left[0].raw[0x73])]
		if cost > budget:
			break
		budget -= cost
		left.pop_front()
		slept += 1
	var p_hp := 0.0
	var p_dmg := 0.0
	var p_ac := 0.0
	for m in up:
		p_hp += m.hp
		p_ac += m.ac
	p_ac /= maxf(up.size(), 1)
	var m_hp := 0.0
	var m_dmg := 0.0
	var m_ac := 0.0
	for e in left:
		m_hp += e.hp_max
		m_ac += e.ac
		m_dmg += _dpr(e, int(round(p_ac)))
	m_ac = m_ac / left.size() if not left.is_empty() else 10.0
	for m in up:
		p_dmg += _dpr(m, int(round(m_ac)))
	var ours := p_hp * p_dmg
	var theirs := m_hp * m_dmg
	var ratio := ours / maxf(theirs, 0.01)
	# Spellcasters' blasts and holds aren't in HP against damage: one round of driders' three
	# Fireballs and a Stinking Cloud downed a level 4 party (chat 10). Each such spell in the
	# enemies' memory cuts the odds.
	var blasts := 0
	for e in mons:
		for id in e.memorized:
			if id in [47, 51, 34, 23, 49, 21]:
				blasts += 1
	if blasts > 0:
		ratio /= 1.0 + 1.5 * blasts
	_judged = "%d %s, %d asleep; party %d HP x %.1f vs %d HP x %.1f: %.2f" % [mons.size(), mons[0].name,
		slept, int(p_hp), p_dmg, int(m_hp), m_dmg, ratio]
	if ratio < 1.5:
		_fled.append("%s %s: %s" % [_here(), str(main._pos), _judged])
		return 3
	return 1


## Runs when the fight left is hopeless: the party's standing HP times damage against the
## awake enemies', below a fifth, and no Sleep or Stinking Cloud left to turn it.
func _judge_fight(c: Combat, i: int) -> String:
	var us: Array[PartyMember] = []
	var them: Array[PartyMember] = []
	var spells_left := false
	for e in c.combatants:
		if e.down:
			continue
		if e.team == 0:
			us.append(e.who)
			for id in e.who.ready_spells():
				if id in [21, 34]:
					spells_left = true
		elif not CombatSpells.held(e.who) and not e.get("fleeing", false):
			them.append(e.who)
	# A duel is "normally not to the death" and its double may block the way out.
	if them.is_empty() or spells_left or main._arena:
		return ""
	var ratio := _odds(us, them, true)
	# Strategy change 9: decide early. A retreat after a hero falls leaves him behind for
	# good, so while everyone stands the party goes below half odds; once someone is down it
	# fights on unless the fight is hopeless (below a fifth).
	var fallen := false
	for e in c.combatants:
		if e.team == 0 and e.down and e.who.status in [PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
			fallen = true
	if ratio < 0.2 or (not fallen and ratio < 0.5):
		if c.combatants[i].get("judged", "") != "flee":
			print("   (bot: %s runs, odds %.2f)" % [c.combatants[i].who.name, ratio])
		c.combatants[i]["judged"] = "flee"
		return "flee"
	return ""


## Rough odds: (party HP x damage a round) / (enemies' HP x damage a round).
func _odds(us: Array[PartyMember], them: Array[PartyMember], current_hp: bool) -> float:
	if them.is_empty():
		return 99.0
	var p_hp := 0.0
	var p_ac := 0.0
	for m in us:
		p_hp += m.hp
		p_ac += m.ac
	p_ac /= maxf(us.size(), 1)
	var m_hp := 0.0
	var m_ac := 0.0
	var m_dmg := 0.0
	for e in them:
		m_hp += e.hp if current_hp else e.hp_max
		m_ac += e.ac
		m_dmg += _dpr(e, int(round(p_ac)))
	m_ac /= them.size()
	var p_dmg := 0.0
	for m in us:
		p_dmg += _dpr(m, int(round(m_ac)))
	return (p_hp * p_dmg) / maxf(m_hp * m_dmg, 0.01)


## The monsters the script loads after the encounter menu, read ahead from where it waits
## (straight on, following GOTOs, up to its COMBAT): [[id, count, picture], ...].
func _monsters_ahead(start: int = -1) -> Array:
	var vm: EclVM = main._vm
	var out := []
	var p: int = vm.pc if start < 0 else start
	var back: Array[int] = []
	var after_if := false
	for n in 200:
		var ins: Dictionary = vm.ecl._read(p)
		if ins.is_empty():
			break
		var was_if := after_if
		after_if = String(ins.op).begins_with("IF_")
		if was_if and String(ins.op) in ["EXIT", "RETURN", "GOTO"] and start >= 0:
			# Reading an event from its start: take the way where its tests pass
			# (an "already done" check exits here).
			p += int(ins.size)
			continue
		match String(ins.op):
			"LOAD_MON":
				var a: Array = ins.args
				out.append([vm._value(a[0]), maxi(vm._value(a[1]), 1), vm._value(a[2])])
			"COMBAT", "EXIT", "NEW_ECL":
				break
			"RETURN":
				if back.is_empty():
					break
				p = back.pop_back()
				continue
			"GOTO":
				p = int(ins.args[0].value) - EclScript.BASE
				continue
			"ON_GOTO":
				# After an encounter menu the script branches on its outcome: 1 is a fight.
				if ins.args.size() > 3:
					p = int(ins.args[3].value) - EclScript.BASE
					continue
			"GOSUB":
				if back.size() < 8:
					back.append(p + int(ins.size))
					p = int(ins.args[0].value) - EclScript.BASE
					continue
		p += int(ins.size)
	return out


## Where event `ev` of the current area starts: the on-step entry's ON_GOTO on the event
## number (ECL memory 0x9800); -1 if not found.
func _event_start(ev: int) -> int:
	# The step script's event table: an ON_GOTO on the square's event number, kept at 0x9800
	# by most areas and at 0x6E82 by others (the Textile House, the Temple of Bane, Valjevo:
	# AND 127 of the square's info first). The longest such table is the one.
	var best := {}
	for p in main._vm.ecl.instructions:
		var ins: Dictionary = main._vm.ecl.instructions[p]
		if ins.op in ["ON_GOTO", "ON_GOSUB"] and int(ins.args[0].value) in [0x9800, 0x6E82] \
				and ins.args[0].type in [1, 2, 3, 5, 0x81] and (best.is_empty() or ins.args.size() > best.args.size()):
			best = ins
	if not best.is_empty() and 2 + ev < best.args.size():
		return int(best.args[2 + ev].value) - EclScript.BASE
	return -1


## The party's odds (fresh, with its Sleep spells) against an event's first fight; 99 if
## the event has no fight.
func _event_odds(ev: int) -> float:
	var at := _event_start(ev)
	if at < 0:
		return 99.0
	var rows := _monsters_ahead(at)
	if rows.is_empty():
		return 99.0
	var mons: Array[PartyMember] = []
	for row in rows:
		var first := PartyMember.load_monster(main._game_path, maxi(main._vm_file, 1), int(row[0]))
		if first == null:
			continue
		first.recalculate(main._types)
		for n in int(row[1]):
			mons.append(first)
	var us: Array[PartyMember] = []
	var sleeps := 0
	for m in main._party:
		if m.status == PartyMember.STATUS_OKAY:
			us.append(m)
			var table := SpellTable.shared(main._game_path)
			if m.knows(21):
				sleeps += m.spell_slots[1][0]
	mons.sort_custom(func(a, b): return a.raw[0x73] < b.raw[0x73])
	# Sleep's small area catches a handful at best: about 7 hit dice, 5 figures a spell.
	var budget := sleeps * 7
	var figures := sleeps * 5
	while not mons.is_empty() and budget > 0 and figures > 0 and int(mons[0].raw[0x73]) <= 4:
		var cost: int = [1, 1, 2, 4, 6][int(mons[0].raw[0x73])]
		if cost > budget:
			break
		budget -= cost
		figures -= 1
		mons.pop_front()
	# At full health.
	var hp := []
	for m in us:
		hp.append(m.hp)
		m.hp = m.hp_max
	var odds := _odds(us, mons, false)
	for i in us.size():
		us[i].hp = hp[i]
	# Enemy casters with Hold Person (cleric 23, magic-user 49): each casting can leave three
	# of the party helpless, and a helpless figure dies at the next blow (lab, chat 10: the
	# original's Grishnak, 200 HP party members slain one blow each). The party's odds count
	# those spells as the fight's real danger.
	var holds := 0
	for row in rows:
		var first := PartyMember.load_monster(main._game_path, maxi(main._vm_file, 1), int(row[0]))
		if first != null:
			holds += (first.memorized.count(23) + first.memorized.count(49)) * int(row[1])
	if holds > 0:
		# HP against damage says nothing about this: one casting can end the fight. Two or
		# more in the enemy's memory wait until the party's saves are better (every member at
		# 6th level), one costs the odds a factor.
		odds /= 1.0 + holds
		if holds >= 2 and _lowest_level() < 6:
			odds = minf(odds, 0.5)
		print("   (event %d: %d Hold Person ahead; odds %.2f)" % [ev, holds, odds])
	return odds


## The first string the script writes or compares within a few instructions of where it
## waits for typed input ("" if none).
func _word_ahead() -> String:
	var vm: EclVM = main._vm
	var p: int = vm.pc
	# Chat 16: numeric COMPAREs on the way are worked out from memory and their IFs followed
	# (4:21's patrol wants SHESTNI unless 0x4A26 is 255, then SAMOSUD: the first literal ahead
	# was always typed).
	var cmp := 0
	for n in 12:
		var ins: Dictionary = vm.ecl._read(p)
		if ins.is_empty():
			break
		var op := String(ins.op)
		var a: Array = ins.args
		if op == "COMPARE" and a.size() >= 2 and int(a[0].type) != 0x80 and int(a[1].type) != 0x80 \
				and int(a[0].type) != 0x81 and int(a[1].type) != 0x81:
			cmp = vm._value(a[0]) - vm._value(a[1])
			p += int(ins.size)
			continue
		if op.begins_with("IF_"):
			var holds: bool = {"IF_EQ": cmp == 0, "IF_NE": cmp != 0, "IF_LT": cmp < 0, "IF_GT": cmp > 0,
				"IF_LE": cmp <= 0, "IF_GE": cmp >= 0}.get(op, true)
			p += int(ins.size)
			if not holds:
				var skipped: Dictionary = vm.ecl._read(p)
				if skipped.is_empty():
					break
				p += int(skipped.size)
			continue
		if op in ["COMPARE", "WRITE_MEM"]:
			for x in a:
				if int(x.type) == 0x80 and String(x.value).strip_edges() != "":
					return String(x.value).strip_edges()
		if op in ["EXIT", "RETURN", "GOTO"]:
			break
		p += int(ins.size)
	return ""


## How urgently an enemy should be stopped (the Clue Book's "who to hit first"): 3 for a
## spellcaster, 2 for an archer, a level drainer or a paralyser, else 0.
func _threat(w: PartyMember) -> int:
	var up := w.name.to_upper()
	for word in ["MU", "MAGE", "MAGIC", "CLERIC", "SHAMAN", "PRIEST", "WIZARD", "SORCER"]:
		if (" " + up + " ").contains(" " + word + " ") or up.begins_with(word):
			return 3
	for s in w.memorized:
		if s > 0:
			return 3
	for word in ["WIGHT", "WRAITH", "SPECTRE", "VAMPIRE", "GHOUL", "GHAST", "THRI-KREEN", "BASILISK", "MEDUSA"]:
		if up.contains(word):
			return 2
	var types: ItemTypes = main._types
	for it in w.items:
		if it.readied and types.slot(it.type) == ItemTypes.SLOT_WEAPON \
				and types.flags(it.type) & (ItemTypes.FLAG_LAUNCHER | ItemTypes.FLAG_THROWN):
			return 2
	if up.contains("ARCHER"):
		return 2
	return 0


## A player's spell for party member i (CombatSpells.party_planner): Sleep or Stinking Cloud
## where it catches the most enemies and none of the party; Hold Person on the strongest;
## Bless before the fight closes; Cure Light Wounds on whoever is hurt worst; Magic Missile
## and other blasts on the enemy nearest to falling. {} keeps the spell and fights.
func _plan_spell(cs: CombatSpells, i: int) -> Dictionary:
	var c: Combat = cs.c
	var me: Dictionary = c.combatants[i]
	var list := cs.castable(i)
	var foes: Array[int] = []
	for j in c.combatants.size():
		var e: Dictionary = c.combatants[j]
		if not e.down and e.team != me.team and not CombatSpells.held(e.who):
			foes.append(j)
	if foes.is_empty():
		return {}
	# Keep the spells when the fight is already won (a wave fight's next wave, the next event):
	# the kobolds' first wave at the nomads' camp took eight Hold Persons and every Sleep, and
	# the last battle found the casters empty (chat 10). Cures still go out.
	var us: Array[PartyMember] = []
	var them: Array[PartyMember] = []
	for e in c.combatants:
		if e.down:
			continue
		if e.team == me.team:
			us.append(e.who)
		elif not CombatSpells.held(e.who) and not e.get("fleeing", false):
			them.append(e.who)
	var easy := _odds(us, them, true) >= 4.0
	if easy:
		var cures: Array[int] = []
		if 3 in list:
			cures.append(3)
		list = cures
	# Area spells that leave enemies helpless.
	for id in [21, 34]:
		if not id in list:
			continue
		var best := {}
		var best_n := 0
		for j in foes:
			var cell: Vector2i = c.combatants[j].cell
			if cs.why_not(i, id, cell) != "":
				continue
			var n := 0
			var mine := false
			for k in cs._people_in(cs.area_cells(i, id, cell)):
				var e: Dictionary = c.combatants[k]
				if e.team == me.team:
					mine = true
				elif not CombatSpells.held(e.who) and (id != 21 or int(e.who.raw[0x73]) <= 4):
					n += 1
			if not mine and n > best_n:
				best_n = n
				var picked: Array[int] = [j]
				best = {"id": id, "cell": cell, "picked": picked}
		if best_n >= mini(2, foes.size()):
			return best
	# Cure the worst hurt (below half) in reach.
	if 3 in list:
		var worst := -1
		for j in c.combatants.size():
			var e: Dictionary = c.combatants[j]
			if e.team == me.team and not e.down and e.who.hp * 2 < e.who.hp_max \
					and cs.why_not(i, 3, e.cell) == "" and (worst < 0 or e.who.hp < c.combatants[worst].who.hp):
				worst = j
		if worst >= 0:
			var one: Array[int] = [worst]
			return {"id": 3, "cell": c.combatants[worst].cell, "picked": one}
	# Bless at the start, when there is a real fight.
	if 1 in list and c.round_no <= 2 and foes.size() >= 3 and not me.who.has_affect(1):
		var self_only: Array[int] = [i]
		return {"id": 1, "cell": me.cell, "picked": self_only}
	# Blasts at whoever is nearest to falling.
	for id in list:
		if cs.table.field(id, 14) == 0 or id in [21, 34]:
			continue
		# Charm and Hold Person don't touch monsters (raw 0x9F above 1) or large creatures.
		var fit: Array[int] = []
		for j in foes:
			var w: PartyMember = c.combatants[j].who
			if not id in [10, 23, 49] or (not w.is_large() and (w.raw[0x9F] if w.raw.size() > 0x9F else 0) <= 1):
				fit.append(j)
		# Strategy change 6: casters first, then archers, then drainers and paralysers, then
		# whoever is nearest to falling (the Clue Book's order).
		fit.sort_custom(func(a, b):
			var ta := _threat(c.combatants[a].who)
			var tb := _threat(c.combatants[b].who)
			return ta > tb or (ta == tb and c.combatants[a].who.hp < c.combatants[b].who.hp))
		var t := -1
		for j in fit:
			if cs.why_not(i, id, c.combatants[j].cell) == "":
				t = j
				break
		if t < 0:
			continue
		var picked: Array[int] = [t]
		if cs.aim_kind(id) == "pick":
			for j in fit:
				if picked.size() >= cs.max_picks(id):
					break
				if not j in picked and cs.why_not(i, id, c.combatants[j].cell) == "":
					picked.append(j)
		elif cs.aim_kind(id) == "area":
			var hits_us := false
			for k in cs._people_in(cs.area_cells(i, id, c.combatants[t].cell)):
				if c.combatants[k].team == me.team:
					hits_us = true
			if hits_us:
				continue
		return {"id": id, "cell": c.combatants[t].cell, "picked": picked}
	return {}


# --- Getting around -----------------------------------------------------------------------
# The area graph comes from tools/sweep.gd's EXIT lines (where each square's on-move or
# on-step script leads), kept in the lab folder: --exits=<file>.

var _bad_exits := {}   # "area x,y dir" ways out that didn't work
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
		# "EXIT <from> ev<n> x,y <dir> <entry> [>choice ...] -> <to> at ...": the menu choices
		# the sweep took on the way (1-based), then the area reached.
		var arrow := w.find("->")
		if arrow < 0 or arrow + 1 >= w.size():
			continue
		var picks: Array[int] = []
		for k in range(6, arrow):
			if w[k].begins_with(">"):
				picks.append(int(w[k].substr(1)))
		var to := w[arrow + 1]
		if to.begins_with("0:"):
			to = w[1].split(":")[0] + to.substr(1)     # NEW_ECL in the same data set
		var e := {"x": int(xy[0]), "y": int(xy[1]), "dir": "NESW".find(w[4]), "entry": w[5], "to": to, "picks": picks}
		# "... -> <to> at x,y,dir": where the sweep arrived (the part of the area it lands in).
		var at := w.find("at", arrow)
		if at > 0 and at + 1 < w.size() and w[at + 1].count(",") == 2:
			var axy := w[at + 1].split(",")
			e["ax"] = int(axy[0])
			e["ay"] = int(axy[1])
		if not _exits.has(w[1]):
			_exits[w[1]] = []
		_exits[w[1]].append(e)


func _here() -> String:
	return "%d:%d" % [main._vm_file, main._vm_block]


## Walks from area to area (shortest number of areas) to `goal` ("set:block").
func _travel(goal: String) -> void:
	# A trip can start another (a fight on the way, then the inn): the outer trip is still
	# travelling when the inner one ends (chat 12: it went on as if exploring, into the huts).
	var was_travelling := _travelling
	_travelling = true
	# Chat 11: what failed on an earlier trip is tried again. Run A kept every failed way
	# out for good, and once the caves' "DO YOU WANT TO LEAVE?" had been answered NO while
	# exploring (main's rule for a question asked twice), its exits were marked bad and the
	# caves to town took about 30 teleports.
	_bad_exits.clear()
	main._menu_seen.clear()
	await _travel_hops(goal)
	_travelling = was_travelling
	# M6: stuck short of the goal (no way found or every way failed): the smallest shortcut
	# is a teleport there, entering the area as its init places the party. Logged.
	if _here() != goal and not _wiped() and goal.contains(":"):
		var from := _here()
		var a := goal.split(":")
		var ok: bool = main.dev_teleport(int(a[0]), int(a[1]), Vector2i(-1, -1), 0)
		await _settle()
		_shortcut("teleport", "%s -> %s%s" % [from, goal, "" if ok and _here() == goal else " FAILED"],
			"travel found no way")


## The ways out of this area the party can walk to from where it stands.
func _open_exits() -> Array:
	var map: GeoMap = main._maps[main._map_index].map
	var out := []
	for e in _exits.get(_here(), []):
		if _bad_exits.has("%s %d,%d %d" % [_here(), e.x, e.y, e.dir]):
			continue
		if not main._vm.on_overland and e.entry == "move" and map.wall(e.x, e.y, e.dir) > 0 and map.door(e.x, e.y, e.dir) == 0:
			continue
		var at := Vector2i(e.x, e.y)
		var here: Vector2i = _overland_at() if main._vm.on_overland else main._pos
		if here == at:
			out.append(e)
			continue
		var path: Array = _overland_path(at) if main._vm.on_overland else main._find_path(main._pos, at)
		if path.size() > 0:
			out.append(e)
	return out


func _travel_hops(goal: String) -> void:
	_load_exits()
	for hop in 12:
		if _here() == goal or _wiped():
			return
		# Breadth first over areas. From here only the ways out the party can walk to now
		# (a band of the wilderness is split by the poisoned river: arriving on its west side
		# from Podol Plaza, its east edge can't be reached).
		# Nodes are an area and, in a wilderness band, the part of it the party is in (the
		# river splits them): learned arrivals say which part an exit leads to.
		var open_here := _open_exits()
		var start := _here() + "#" + str(_part_now())
		var came := {start: ""}
		var via := {}
		var queue := [start]
		var reached := ""
		while not queue.is_empty():
			var node: String = queue.pop_front()
			var a: String = node.get_slice("#", 0)
			var part := int(node.get_slice("#", 1))
			if a == goal:
				reached = node
				break
			for e in (open_here if node == start else _exits.get(a, [])):
				if node != start and part >= 0 and _part_of(a, Vector2i(e.x, e.y)) not in [part, -1]:
					continue
				var nxt: String = e.to + "#" + str(_arrival_part(a, e))
				if not came.has(nxt):
					came[nxt] = node
					via[nxt] = e
					queue.append(nxt)
		if reached != "":
			var n2 := reached
			while came[n2] != start:
				n2 = came[n2]
			came = {_here(): ""}
			came[goal] = "x"
			_first_hop = n2.get_slice("#", 0)
		else:
			came = {_here(): ""}
			_first_hop = ""
		if not came.has(goal) and goal == SOKAL and _here() == TOWN:
			# Sokal Keep is reached by boat: the harbor master (event 2, 11,1), SOKAL, then
			# the pier's end (event 1, 15,1). The area graph doesn't follow boats.
			print("   travel 3:0 -> 4:21 by boat")
			main._tour_answers = ["1"]
			await main._tour(Vector2i(11, 1))
			await _settle()
			await main._tour(Vector2i(15, 1))
			await _settle()
			main._tour_answers = []
			continue
		if not came.has(goal):
			_issue("travel: no way from %s to %s" % [_here(), goal])
			return
		var next := _first_hop
		# The nearest open way out to `next`.
		var map: GeoMap = main._maps[main._map_index].map
		var best := {}
		var best_len := 1 << 20
		for e in _exits.get(_here(), []):
			if e.to != next or _bad_exits.has("%s %d,%d %d" % [_here(), e.x, e.y, e.dir]):
				continue
			if e.entry == "move" and map.wall(e.x, e.y, e.dir) > 0 and map.door(e.x, e.y, e.dir) == 0:
				continue
			var path: Array = _overland_path(Vector2i(e.x, e.y)) if main._vm.on_overland \
				else main._find_path(main._pos, Vector2i(e.x, e.y))
			if (path.size() > 0 or main._pos == Vector2i(e.x, e.y)) and path.size() < best_len:
				best = e
				best_len = path.size()
		if best.is_empty():
			_issue("travel: no open way from %s to %s" % [_here(), next])
			return
		print("   travel %s -> %s by %d,%d %s" % [_here(), next, best.x, best.y, "NESW"[best.dir]])
		var before := _here()
		for attempt in 6:
			# A wandering monster can interrupt the walk: fight it out and try again.
			if _wiped() or _here() != before:
				break
			# (On the way to the inn, push on: camping where the party is, Podol Plaza say,
			# only brings more patrols.)
			if _interrupted:
				_interrupted = false
				if goal != TOWN and not _at_inn:
					await _heal()
			_gate_answer = String(best.get("answer", ""))
			_gate_uses = 0
			_gate_picks = Array(best.get("picks", []))
			_gate_square = Vector2i(best.x, best.y)
			if main._vm.on_overland:
				await _overland_walk(Vector2i(best.x, best.y))
				await _settle()
				if best.entry == "move" and _here() == before and _overland_at() == Vector2i(best.x, best.y):
					await _overland_step(int(best.dir))     # over the band's edge
				_gate_answer = ""
				_gate_picks = []
				# Only a way out the party stood on and that kept it here is bad; a walk cut
				# short by an encounter is tried again (chat 11: 6:25 12,31, the Buccaneers'
				# base, was given up after a fight with giant snakes on the way).
				if _here() == before and _overland_at() == Vector2i(best.x, best.y):
					_bad_exits["%s %d,%d %d" % [before, best.x, best.y, best.dir]] = true
					break
				continue
			if main._pos == Vector2i(best.x, best.y) and (_gate_answer != "" or best.entry == "step"):
				await _step_off()     # its event runs on stepping onto the square
			await main._tour(Vector2i(best.x, best.y))
			await _settle()
			_gate_answer = ""
			_gate_picks = []
			if _here() == before and best.entry == "move" and main._pos == Vector2i(best.x, best.y):
				while int(main._facing) != int(best.dir):
					await main._press("right")
				await main._press("up")
				await _settle()
		if _wiped():
			return
		if _here() == before:
			# The graph's way out didn't work from here (a one-way edge, a script that turns
			# the party back): try the next nearest.
			_issue("travel: the way out at %d,%d didn't lead to %s; trying another" % [best.x, best.y, next])
			_bad_exits["%s %d,%d %d" % [before, best.x, best.y, best.dir]] = true
			continue
		if BANDS.has(_here()):
			# Learn which part of the band this way in arrives in.
			_arrivals["%s %d,%d %d" % [before, best.x, best.y, best.dir]] = _part_now()
		if goal != TOWN and not _at_inn:
			await _heal_if_low()


## Visits a square of every event in the area, nearest first (except the listed events),
## healing when anyone is below half.
## Explores the area in passes: the events it can't win yet wait until the party has
## trained (New Phlan and back), up to four passes; what still waits is logged.
func _explore(later: Array) -> void:
	# Events the plan leaves out are walked round, not through (a teleporter on the way).
	main.avoid_events = {}
	for e in later:
		if str(e).is_valid_int():
			main.avoid_events[int(e)] = true
	await _explore_areas(later)
	main.avoid_events = {}


func _explore_areas(later: Array) -> void:
	if main._vm.on_overland:
		# A band's squares are its sites (gates and site tables), not a dungeon map's events;
		# the tour can't walk to them (chat 13: it wandered 8:27 for an hour).
		print("   explore: %s is wilderness; its sites come by travel and gates" % _here())
		return
	var area := _here()
	var start_map: int = main._map_index
	_visited = {}
	_ladders = {}
	_no_route = {}
	var arrivals := {}       # map index -> the square the party arrived on there
	var trips := 0
	_climbed = false
	var after_town := false
	for n in 12:
		var map_before: int = main._map_index
		# The plan's skipped events stay skipped on the passes that follow a ladder or stairs
		# (only a pass after a trip to town takes them on).
		var deferred: Dictionary = await _explore_pass(later if n == 0 or not after_town else [])
		if _wiped() or _here() != area:
			return
		if main._map_index != map_before:
			if not arrivals.has(main._map_index):
				arrivals[main._map_index] = main._pos
			continue     # a ladder or stair took the party to the area's other map: explore it
		if _climbed and n < 11:
			# Stairs that stay on the same map (Valjevo's towers, chat 13): what had no route
			# from below may have one from here.
			_climbed = false
			continue
		if deferred.is_empty():
			break
		if not _can_train() or trips >= 3 or not _round_trip(area):
			_issue("explore %s: events %s left for later (the party can't win them yet)" % [area, str(deferred.keys())])
			break
		trips += 1
		after_town = true
		await _town()
		await _travel(area)
		if _here() != area:
			return
	# Back up the ladder to the map the area's ways out are on.
	for n in 3:
		if main._map_index == start_map or _wiped() or _here() != area or not arrivals.has(main._map_index):
			break
		print("   explore: back to map %d by %s" % [start_map, arrivals[main._map_index]])
		_todo_now = {}
		_ladder_ok = true
		await main._tour(arrivals[main._map_index])
		await _settle()


func _explore_pass(skip: Array) -> Dictionary:
	var map: GeoMap = main._maps[main._map_index].map
	var area := _here()
	var todo := {}
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var ev := map.flag(x, y) & 127
			if ev == 0 or todo.has(ev) or _visited.has("%d:%d" % [main._map_index, ev]) \
					or _skip_events.has("%s %d:%d" % [area, main._map_index, ev]):
				continue
			todo[ev] = Vector2i(x, y)
	# Ladders and stairs declined while the map had more to see come last.
	var ladders := {}
	for ev in todo.keys():
		if _ladders.has("%d:%d" % [main._map_index, ev]):
			ladders[ev] = todo[ev]
			todo.erase(ev)
	if todo.is_empty() and not ladders.is_empty():
		todo = ladders
		ladders = {}
		_ladder_ok = true
	var deferred := {}
	for ev in todo.keys():
		# Event fights come without a menu to flee by: wait for clear odds ("+n" in the
		# plan's list takes event n on whatever the odds, when the plan judges it ready).
		var odds := 0.0 if str(ev) in skip else _event_odds(ev)
		if ("+%d" % ev) in skip:
			odds = 99.0
		if odds < 2.0:
			print("   explore: event %d deferred (odds %.2f)" % [ev, odds])
			deferred[ev] = todo[ev]
			todo.erase(ev)
	var map_now: int = main._map_index
	_todo_now = todo
	_ladder_ok = false
	while not todo.is_empty() and not _wiped() and _here() == area and main._map_index == map_now:
		var best := -1
		var best_len := 1 << 20
		for ev in todo:
			var path: Array = main._find_path(main._pos, todo[ev])
			if path.size() > 0 and path.size() < best_len:
				best = ev
				best_len = path.size()
		if best < 0:
			# Nothing else reachable: now the ladders and stairs declined on the way.
			for y in GeoMap.SIZE:
				for x in GeoMap.SIZE:
					var lev := map.flag(x, y) & 127
					if _ladders.has("%d:%d" % [map_now, lev]) and not ladders.has(lev):
						ladders[lev] = Vector2i(x, y)
			if not ladders.is_empty():
				todo = ladders
				_todo_now = {}         # nothing else left on this map
				_ladder_ok = true
				for lev in ladders:
					_ladders.erase("%d:%d" % [map_now, lev])
				ladders = {}
				continue
			print("   explore: no route to events %s" % str(todo.keys()))
			for ev in todo:
				_no_route["%d:%d" % [map_now, ev]] = true
			return deferred
		var at: Vector2i = todo[best]
		todo.erase(best)
		_visited["%d:%d" % [map_now, best]] = true
		# A player rests and memorizes before walking into the next event.
		await _prepare()
		if _wiped() or _here() != area:
			break
		main._refused.clear()
		print("   explore: event %d at %s" % [best, at])
		_event_now = "%s %d:%d" % [area, map_now, best]
		_last_fight = {}
		_asked = {}
		for attempt in 4:
			_interrupted = false
			await main._tour(at)
			await _settle()
			if _wiped() or _here() != area or not _interrupted:
				break
			print("   explore: stopped to rest on the way to event %d" % best)
			await _prepare()
			if _wiped() or _here() != area:
				break
		await _heal_if_low()
		if not _wiped() and _can_train() and area != TOWN and _round_trip(area):
			# Training first: to New Phlan and back, then on with the area.
			var back: Vector2i = main._pos
			await _town()
			await _travel(area)
			if _here() != area:
				return deferred
			await main._tour(back)
			await _settle()
		if not _wiped() and _here() == area:
			# A checkpoint after each event; a wipe comes back here and explores again
			# (events already done do nothing the second time).
			_checkpoint = "explore"
			_checkpoint_pc = _pc - 1
			main._quick_save()
			DirAccess.copy_absolute(main._save_path(), "user://bot_explore.cfg")
	return deferred


const TOWN := "3:0"
## Where the bot grinds a level: Podol Plaza, whose patrols are sized to the party.
const GRIND_AREA := "1:18"
const SOKAL := "4:21"
## New Phlan's training halls (squares on the town map), the clerk, the temple and the inn.
## (Events 16 fighters 8,0, 12 clerics 5,0, 13 magic-users 7,0, 17 thieves 9,0; 6,0 is a sign.
## After a hall's question the next two event squares stay quiet (0x4A09), which this order
## walks off on the way.)
const HALLS := ["8,0", "5,0", "7,0", "9,0"]


## Full HP and spells before an event (resting can bring random encounters; they are
## fought or fled as any other).
func _prepare() -> void:
	_pick_spells()
	if not _learning() and not _needs_rest():
		return
	# Where the area isn't safe to camp in (the plan's rest lines, from the Clue Book), a
	# player rests at the inn rather than in monster country.
	if _rest_rule() == "inn":
		# Every trip to the inn crosses monster country (the Textile House's ghouls), so a
		# player goes only when worn down: cures from the cleric's memory first, then the
		# inn when the party is hurt or its spells are mostly spent.
		_cure_in_camp()
		if not _worn_down():
			return
		if await _rest_safe():
			return
	await _memorize()
	if _needs_rest():
		await _heal()


## Hurt (anyone down, or under 60% of the party's HP) or the casters' spells mostly spent.
func _worn_down() -> bool:
	if _hurt():
		return true
	var slots := 0
	var left := 0
	for m in main._party:
		if m.status != PartyMember.STATUS_OKAY:
			continue
		for c in 2:
			for l in 3:
				slots += m.spell_slots[c][l]
		left += m.memorized.filter(func(x): return x < PartyMember.LEARNING).size()
	return slots > 0 and left * 2 < slots


## Walks to the inn, rests there and comes back to this square, when town is at most `hops`
## areas away and there is a way back (not Sokal Keep, reached by boat). True if done.
func _rest_at_inn(hops: int) -> bool:
	var area := _here()
	if _at_inn or area == TOWN or _hops(area, TOWN) > hops or _hops(TOWN, area) > hops + 1:
		return false
	_at_inn = true      # not again from inside the trip (a rest on the way back)
	var back: Vector2i = main._pos
	print("   == to the inn to rest")
	await _travel(TOWN)
	var ok := _here() == TOWN
	if ok:
		await _do("inn 4,12")
		await _travel(area)
		ok = _here() == area
	if ok:
		await main._tour(back)
		await _settle()
	_at_inn = false
	return ok


## Events still on explore's list for this map (the one underfoot excluded).
func _unvisited_here() -> int:
	var map: GeoMap = main._maps[main._map_index].map
	var here := map.flag(main._pos.x, main._pos.y) & 127
	var n := 0
	for ev in _todo_now:
		if int(ev) != here:
			n += 1
	return n


func _grind(addr: int, value: int) -> void:
	var area := _here()
	for n in 40:
		if main._vm.read_byte(addr) >= value or _wiped() or _here() != area:
			break
		print("   grind: 0x%X = %d (want %d)" % [addr, main._vm.read_byte(addr), value])
		if not await _open_camp():
			return
		var camp: CampScreen = main._camp
		camp._rest_menu()
		camp._to_rest = 288      # a day; a patrol may interrupt
		_start_rest(camp)
		while camp.visible and camp._resting:
			await get_tree().process_frame
		if camp.visible:
			await main._press("esc")
			if camp.visible:
				await main._press("e")
		await _settle()
		if _hurt():
			await _prepare()
	print("   grind: 0x%X = %d" % [addr, main._vm.read_byte(addr)])


func _lowest_level() -> int:
	var low := 99
	for m in main._party:
		if m.status == PartyMember.STATUS_DEAD or m.npc >= 128:
			continue     # (hired NPCs aren't the bot's to train)
		var top := 0
		for x in m.raw.slice(0x96, 0x9E):
			top = maxi(top, x)
		low = mini(low, top)
	return low


func _level_up(goal: int) -> void:
	var area := _here()
	# A wipe while grinding goes back to the last save of the grind (taken at the start and
	# after each training), so the levels already earned aren't lost.
	_grind_save()
	var reloads := 0
	for n in 200:
		if _wiped() and reloads < 4:
			reloads += 1
			_count("wipes")
			_issue("party wiped while grinding in %s; back to the grind's last save" % area)
			await _load("grind")
		if _lowest_level() >= goal or _wiped():
			break
		if _can_train():
			await _town()
			await _travel(area)
			if not _wiped():
				_grind_save()
		if _here() != area:
			await _travel(area)
			if _here() != area:
				return
		if n % 5 == 0:
			var purse := 0
			for m in main._party:
				if m.npc < 128:
					purse += m.wealth_copper() / 200
			print("   level: lowest %d (want %d), purse %d gold" % [_lowest_level(), goal, purse])
		if not await _open_camp():
			return
		var camp: CampScreen = main._camp
		camp._rest_menu()
		camp._to_rest = 288
		_start_rest(camp)
		while camp.visible and camp._resting:
			await get_tree().process_frame
		if camp.visible:
			await main._press("esc")
			if camp.visible:
				await main._press("e")
		await _settle()
		if _hurt() or _learning():
			await _prepare()
	print("   level: lowest %d" % _lowest_level())


func _grind_save() -> void:
	main._quick_save()
	DirAccess.copy_absolute(main._save_path(), "user://bot_grind.cfg")


## New Phlan locks its shop, City Hall and more from hour 14 (0x49C9 >= 14, the town's
## on-move script): a player camps until the doors open.
func _wait_for_day() -> void:
	var h := GameClock.hour(main._vm)
	if h < 14:
		return
	if _here() == TOWN and not _at_inn:
		# The Clue Book: in New Phlan only the inn is safe (the watch rousts campers).
		_inn_till_day = true
		await _do("inn 4,12")
		_inn_till_day = false
		if GameClock.hour(main._vm) < 14:
			return
	if not await _open_camp():
		return
	print("   (waiting in camp for the doors to open: %02d:00)" % h)
	var camp: CampScreen = main._camp
	camp._rest_menu()
	camp._to_rest = (24 - h) * 12
	_start_rest(camp)
	while camp.visible and camp._resting:
		await get_tree().process_frame
	if camp.visible:
		await main._press("esc")
		if camp.visible:
			await main._press("e")
	await _settle()


## Areas between `a` and `b` by the area graph (99 if there is no way).
func _hops(a: String, b: String) -> int:
	_load_exits()
	var dist := {a: 0}
	var queue := [a]
	while not queue.is_empty():
		var x: String = queue.pop_front()
		if x == b:
			return dist[x]
		for e in _exits.get(x, []):
			if not dist.has(e.to):
				dist[e.to] = dist[x] + 1
				queue.append(e.to)
	return 99


## Whether travel can go from `area` to New Phlan and back (chat 12: the pyramid has no way
## out but the priest's hole, so a training trip from it ended in a teleport).
func _round_trip(area: String) -> bool:
	return _hops(TOWN, area) < 99 and _hops(area, TOWN) < 99


## Whether anyone has the experience for a new level.
func _can_train() -> bool:
	var t := ClassTables.shared(main._game_path)
	var purse := 0
	for m in main._party:
		if m.npc >= 128:
			continue
		purse += m.wealth_copper() + (m.money[5] * 50 + m.money[6] * 500) * 200   # gems and jewellery at a guess
		for it in m.items:
			if not it.readied and not _keeper(it) and not _missile_kit(m, it):
				purse += it.price / 2 * 200     # spare gear the shop buys
	if purse < 1000 * 200 or purse < _purse_needed:
		return false     # training costs 1000 gold; the party can't pay it yet
	for m in main._party:
		if m.status == PartyMember.STATUS_OKAY and m.npc < 128 and _has_exp(m, t):
			return true
	return false


static func _has_exp(m: PartyMember, t: ClassTables) -> bool:
	for c in m.class_indices():
		var need := t.needed(c, m.level_in(c) + 1)
		if need > 0 and m.experience >= need:
			return true
	return false


## The round in New Phlan: the clerk's rewards, the temple, every training hall, the inn.
func _town() -> void:
	print("   == to New Phlan to train")
	await _travel(TOWN)
	if _here() != TOWN:
		return
	await _clerk()
	var levels_before := 0
	for m in main._party:
		levels_before += Array(m.raw.slice(0x96, 0x9E)).reduce(func(a, b): return a + b, 0)
	var gems := 0
	for m in main._party:
		gems += m.money[5] + m.money[6]
		for it in m.items:
			if not it.readied and not _keeper(it) and not _missile_kit(m, it) and it.price >= 2:
				gems += 1
	var round := ["sell 13,8"] if gems > 0 else []
	for sq in round + ["temple 2,12"] + HALLS.map(func(h): return "trainat " + h) + ["inn 4,12"]:
		await _do(sq)
		if _wiped():
			return
	# Nobody trained: don't come back until the purse has grown by a training's price.
	var levels_after := 0
	var purse := 0
	for m in main._party:
		levels_after += Array(m.raw.slice(0x96, 0x9E)).reduce(func(a, b): return a + b, 0)
		purse += m.wealth_copper()
	_purse_needed = purse + 1000 * 200 if levels_after == levels_before else 0


func _heal_if_low() -> void:
	if _wiped():
		return
	if _rest_rule() == "inn" and not _at_inn:
		_cure_in_camp()
		if not _worn_down():
			return
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
				if rec[0x10 + a] < 17:
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


## What MODIFY CHARACTER allows, at its most (CharacterModify's limits): abilities up to 18
## within the race's and class's range, a fighter's 18 on to the race's best 18/xx, HP to
## the classes' dice at their most with CON. Applied as MODIFY's KEEP does.
func _modify_all() -> void:
	var rules := CreationRules.shared(main._game_path)
	var tables := ClassTables.shared(main._game_path)
	var spells := SpellTable.shared(main._game_path)
	for m in _new_party:
		var d := m.to_record()
		for i in 6:
			var r := rules.ability_range(d, i)
			d[0x10 + i] = clampi(18, r.x, r.y)
		d[0x16] = rules.exceptional_max(d) if d[0x98] > 0 and d[0x10] == 18 else 0
		var hp := rules.hp_most(d)
		d[0x32] = hp
		d[0x11B] = hp
		var fresh := PartyMember.from_bytes(d, PackedByteArray())
		for k in [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x32, 0x11B]:
			m.raw[k] = d[k]
		m.stats = fresh.stats
		m.strength_exceptional = fresh.strength_exceptional
		m.hp_max = fresh.hp_max
		m.hp = fresh.hp
		m.apply_class_tables(tables, spells)
		m.recalculate(main._types)
		print("   MODIFY %s: STR %d/%d INT %d WIS %d DEX %d CON %d CHA %d HP %d" % [m.name, m.stats[0],
			m.strength_exceptional, m.stats[1], m.stats[2], m.stats[3], m.stats[4], m.stats[5], m.hp_max])


func _party_report() -> void:
	for m in main._party:
		print("   %-12s %s lv %s xp %d hp %d/%d AC %d THAC0 %d gp %d items %s" % [m.name, m.status_name(),
			str(Array(m.raw.slice(0x96, 0x9E)).filter(func(x): return x > 0)), m.experience, m.hp, m.hp_max,
			m.ac, m.thac0, m.wealth_copper() / 200, ", ".join(m.items.map(func(it): return ("*" if it.readied else "") + it.name + (" (%+d)" % it.plus if it.plus != 0 else "")))])


# --- Camp ---------------------------------------------------------------------------------

func _needs_rest() -> bool:
	for m in main._party:
		if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
				and m.hp < m.hp_max and not SpecialAffects.diseased(m):
			return true
	return false


func _open_camp() -> bool:
	await _settle()
	_own_camp = true
	if not main._camp.visible:
		await main._press("e")
		for i in 10:
			await get_tree().process_frame
	return main._camp.visible


## Rests in camp a day at a time until everyone is healed; an interruption is fought out
## and the rest begun again.
func _heal() -> void:
	if _needs_rest() and _rest_rule() == "inn" and not _at_inn and await _rest_safe():
		return
	# Cure Light Wounds first, rest for the rest (the guides): cast every cure on the most
	# hurt, rest just long enough to memorize them again, and repeat while that heals more
	# than a day's rest would.
	for round_no in 12:
		if not _needs_rest() or _wiped():
			break
		var cured := _cure_in_camp()
		if not _needs_rest():
			break
		if cured == 0 and round_no > 0:
			break
		if not _pick_spells() or not await _open_camp():
			break
		var hits := [0]
		var count := func(): hits[0] += 1
		main._camp.interrupted.connect(count)
		await _rest_in_camp(0)
		main._camp.interrupted.disconnect(count)
		await _settle()
		if hits[0] > 0:
			break
	if not _needs_rest():
		return
	var days := 0
	var interrupted := 0
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
		var hits := [0]
		var count := func(): hits[0] += 1
		camp.interrupted.connect(count)
		_start_rest(camp)
		while camp.visible and camp._resting:
			await get_tree().process_frame
		camp.interrupted.disconnect(count)
		days += 1
		if camp.visible:
			await main._press("esc")
			if camp.visible:
				await main._press("e")
		await _settle()
		# An interrupted rest: a player gives up camping among the monsters and walks to
		# the inn (when there is a way back); north of Podol Plaza ghouls and wights come.
		if hits[0] > 0:
			interrupted += 1
			if not _wiped():
				_interrupted = false
				if await _rest_at_inn(5):
					return
	if days > 0:
		print("   rested; %s" % " ".join(main._party.map(func(m): return "%d/%d" % [m.hp, m.hp_max])))


## Casts every memorized Cure Light Wounds (3) outside a fight on whoever is most hurt (by at
## least 4 HP), as the camp's MAGIC menu does. Returns the casts made.
func _cure_in_camp() -> int:
	var table := SpellTable.shared(main._game_path)
	var n := 0
	for caster in main._party:
		if caster.status != PartyMember.STATUS_OKAY:
			continue
		while caster.memorized.has(3):
			var worst: PartyMember = null
			for m in main._party:
				if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
						and m.hp_max - m.hp >= 4 and (worst == null or m.hp_max - m.hp > worst.hp_max - worst.hp):
					worst = m
			if worst == null:
				return n
			var said := SpellCaster.cast_outside(table, caster, 3, main._party, worst, _rng)
			n += 1
			_count("cures")
			print("   camp: %s" % " / ".join(said))
	return n


## What the bot memorizes, by class and level, in turn: clerics Cure Light Wounds twice to
## a Bless; Hold Person; Prayer. Magic-users Sleep and Magic Missile; Stinking Cloud;
## Fireball, Haste, Lightning Bolt.
## A magic-user's new spell at training, in order of want: Knock (the
## library's wizard-locked doors), Magic Missile, Sleep, Stinking Cloud, Invisibility, Mirror Image, Fireball,
## Haste, Lightning Bolt, Hold Person, Dispel Magic, Slow.
const LEARN_ORDER := [31, 15, 21, 34, 30, 32, 47, 48, 51, 49, 46, 55]
const PICKS := [[[3, 3, 1], [23], [42]], [[21, 15], [31, 34, 32], [47, 48, 51]]]


func _memorize() -> void:
	_pick_spells()
	if not _learning():
		return
	if _rest_rule() == "inn" and not _at_inn and await _rest_safe():
		return
	if not await _open_camp():
		return
	var hits := [0]
	var count := func(): hits[0] += 1
	main._camp.interrupted.connect(count)
	await _rest_in_camp(0)
	main._camp.interrupted.disconnect(count)
	await _settle()
	# Interrupted: off to the inn rather than camping again among the monsters.
	if hits[0] > 0 and not _wiped():
		_interrupted = false
		await _rest_at_inn(5)
	print("   memorized: %s" % " | ".join(main._party.map(func(m): return "%s %s" % [m.name, str(m.memorized)])))


## Rests in the open camp: long enough to memorize, and `days` more.
func _rest_in_camp(days: int) -> void:
	var camp: CampScreen = main._camp
	camp._rest_menu()
	camp._to_rest += days * 288
	_start_rest(camp)
	while camp.visible and camp._resting:
		await get_tree().process_frame
	if camp.visible:
		await main._press("esc")
		if camp.visible:
			await main._press("e")


## Whether any spell is queued and not yet memorized.
func _learning() -> bool:
	for m in main._party:
		for s in m.memorized:
			if s >= PartyMember.LEARNING:
				return true
	return false


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
		_fund(i)
		pm._sel = i
		var before := _coin()
		pm._train()
		if pm._mode == "confirm_train":
			pm._do_train()
			if pm._mode == "learn":
				# The spell a player wants next (LEARN_ORDER), else the first offered.
				for id in LEARN_ORDER:
					if pm._list.has(id):
						pm._cursor = pm._list.find(id)
						break
				await main._press("enter")
			_book("training", before)
			var m: PartyMember = main._party[i]
			_trainings.append("%s %s day %d" % [m.name, "/".join(Array(m.raw.slice(0x96, 0x9E)).filter(func(x): return x > 0).map(func(x): return str(x))), _day()])
			print("   %s trained: %s" % [main._party[i].name, pm._note.text])
		else:
			print("   %s: %s" % [main._party[i].name, pm._note.text])
	_training = false
	await main._press("b")         # BEGIN ADVENTURING
	await _settle()


const QUEST_ITEM_TYPES := [74, 75, 82, 91]
const LOOT_WORDS := ["SCROLL", "POTION", "WAND", "RING", "NECKLACE", "BRACERS", "GAUNTLETS", "CLOAK",
	"DUST", "JAVELIN", "MANUAL", "GEM", "JEWEL", "HOLY", "MIRROR", "BOOK", "TOME", "MAP", "STAFF OF", "ROD", "KEY"]


static func _worth_taking(it: GameItem) -> bool:
	if _keeper(it):
		return true
	# Plain gear the shop pays for (half its price): training is 1000 gold a level.
	return it.price >= 20 and it.weight <= 400


## A bow, sling, thrown weapon or ammunition its carrier can use: the archer's kit, never
## sold (the fight readies it itself; out of a fight a melee weapon is in hand).
func _missile_kit(m: PartyMember, it: GameItem) -> bool:
	var types: ItemTypes = main._types
	if it.type == ItemTypes.TYPE_ARROW or it.type == ItemTypes.TYPE_QUARREL:
		return true
	var missile := func(x: GameItem) -> bool:
		return types.slot(x.type) == ItemTypes.SLOT_WEAPON and (m.class_flags & types.class_flags(x.type)) != 0 \
			and types.flags(x.type) & (ItemTypes.FLAG_LAUNCHER | ItemTypes.FLAG_THROWN) != 0
	if not missile.call(it):
		return false
	# Only the best one each (the highest plus, then the dearest): the rest are sold.
	for o in m.items:
		if o != it and missile.call(o) and (o.plus > it.plus or (o.plus == it.plus and o.price > it.price) \
				or (o.plus == it.plus and o.price == it.price and m.items.find(o) < m.items.find(it))):
			return false
	return true


## Magic and the things a player keeps (scrolls, potions, wands, books...): never sold.
static func _keeper(it: GameItem) -> bool:
	if it.plus != 0 or it.name.contains("+"):
		return true
	# The item types some script looks for (every FIND_ITEM in Pool of Radiance's ECL1-8):
	# a player keeps those. Chat 16: 6:1's captain's pass (91), bought from the seedy man,
	# has no price and no magic word, so the bot left it on the treasure screen.
	if it.type in QUEST_ITEM_TYPES:
		return true
	var up := it.name.to_upper()
	for w in LOOT_WORDS:
		if up.contains(w):
			return true
	return false


## Moves coins (largest first) from the others to member i until it has the 1000 gold training
## costs (only when it has the experience).
func _fund(i: int) -> void:
	var m: PartyMember = main._party[i]
	var t := ClassTables.shared(main._game_path)
	if m.npc >= 128 or not _has_exp(m, t):
		return
	for o in main._party:
		if o.npc >= 128:
			continue     # an NPC's money is its own
		for coin in [4, 3, 2, 1, 0]:
			while o != m and o.money[coin] > 0 and m.wealth_copper() < 1000 * 200:
				o.money[coin] -= 1
				m.money[coin] += 1


## At an open temple: Raise Dead, Stone to Flesh and Cure Disease for whoever needs them,
## pooling the party's money with them first.
func _temple_cures() -> void:
	var t: TempleScreen = main._temple
	for i in main._party.size():
		for cure_name in ["RAISE DEAD", "STONE TO FLESH", "CURE DISEASE"]:
			var cure := t.cure_index(cure_name)
			if t._needs(main._party[i], cure):
				t._who = i
				t._pool()
				t._cure = cure
				t._pay()
				print("   temple: %s %s: %s" % [main._party[i].name, TempleScreen.CURES[cure][0], t._note.text])


# --- Counters and the money ledger (strategy change 0) --------------------------------------
# Per area: fights won, lost and fled, encounters avoided at the menu, wipes, rests begun and
# interrupted. Money: coins in by source (treasure, rewards, selling, other) and out (shop,
# training, inn, temple), in copper; gems and jewellery counted as pieces. Saved beside each
# checkpoint (user://bot_<name>.json) so a resumed run carries them on.

var _stats := {}          # area -> {key: count}
var _ledger := {}         # "in:<source>" / "out:<source>" -> copper
var _gem_ledger := {}     # source -> gems and jewellery gained (pieces)
var _first_day := {}      # area -> game day first entered
var _trainings: PackedStringArray = []   # "<name> <levels> day <n>"
var _mark := -1           # the party's coins at the last ledger entry
var _first_hop := ""             # the area travel heads for next
var _arrivals := {}             # "from x,y dir" -> where in the band an exit arrived (learned)
var _parts := {}                # band "set:block" -> {Vector2i: part id} (river-split parts)
var _gate_picks: Array = []
var _gate_square := Vector2i(-1, -1)   # the exit square those choices belong to     # menu choices (1-based) on the way through the exit being used
var _gate_answer := ""     # the menu choice of the gate travel is walking to
var _gate_uses := 0        # chat 17: times _gate_answer was given since it was set
var _answer_rules := {}      # area -> [[question text, choice]] (answer lines)
var _parley_cues := {}       # area -> encounter texts to PARLAY at (parley lines)
var _fight_cues := {}        # area -> encounter texts to fight at (fight lines)
var _said_before := ""        # the last text shown before the current menu
var _hire_wanted := 0         # hired NPCs the plan wants (hire <n>)
var _inn_till_day := false
var _resting_now := false
var _inn_retry := false
var _own_camp := false       # the camp open is the bot's own (ENCAMP), not a script's lodging
var _travelling := false     # inside _travel    # resting in a script's lodging   # the inn's rest runs on until New Phlan's doors open
var _last_said := ""
var _rest_rules := {}     # area -> {rule, addr, value}


func _count(key: String) -> void:
	var a := _here()
	if not _stats.has(a):
		_stats[a] = {}
	_stats[a][key] = int(_stats[a].get(key, 0)) + 1


## The player characters' coins in copper (hired NPCs' money is their own).
func _coin() -> int:
	var c := 0
	for m in main._party:
		if m.npc < 128:
			c += m.wealth_copper()
	return c


func _gems() -> int:
	var n := 0
	for m in main._party:
		if m.npc < 128:
			n += m.money[5] + m.money[6]
	return n


## Books the change in coins since `before` to `source`; a change since the last entry
## that nothing booked goes to "other" first (script gifts and robberies).
func _book(source: String, before: int) -> void:
	if _mark >= 0 and before != _mark:
		_add_ledger("other", before - _mark)
	_add_ledger(source, _coin() - before)
	_mark = _coin()


func _add_ledger(source: String, delta: int) -> void:
	if delta == 0:
		return
	var key := ("in:" if delta > 0 else "out:") + source
	_ledger[key] = int(_ledger.get(key, 0)) + absi(delta)


## Days since the game's calendar began (day, month of 30 days, year of 12 months).
func _day() -> int:
	var vm: EclVM = main._vm
	return vm.read_byte(0x49CA) + 30 * vm.read_byte(0x49CB) + 360 * vm.read_byte(0x49CC)


func _report() -> void:
	_book("other", _coin())
	var levels := []
	for m in main._party:
		levels.append("%s %s" % [m.name, "/".join(Array(m.raw.slice(0x96, 0x9E)).filter(func(x): return x > 0).map(func(x): return str(x)))])
	print("== COUNTERS day %d, %s, in %s" % [_day(), GameClock.text(main._vm), _here()])
	print("   levels: %s" % ", ".join(levels))
	var total := {}
	for a in _stats:
		var s: Dictionary = _stats[a]
		print("   %-6s first day %s: won %d, lost %d, fled %d, avoided %d, wipes %d, rests %d (interrupted %d)" % [a,
			str(_first_day.get(a, "?")), s.get("won", 0), s.get("lost", 0), s.get("fled", 0), s.get("avoided", 0),
			s.get("wipes", 0), s.get("rests", 0), s.get("interrupted", 0)])
		for k in s:
			total[k] = int(total.get(k, 0)) + int(s[k])
	print("   all: %s" % str(total))
	var ins := []
	var outs := []
	for k in _ledger:
		var t := "%s %d" % [String(k).get_slice(":", 1), int(_ledger[k]) / 200]
		(ins if String(k).begins_with("in:") else outs).append(t)
	print("   gold in: %s | out: %s | gems/jewels in: %s | purse %d gold, %d gems/jewels" % [", ".join(ins),
		", ".join(outs), str(_gem_ledger), _coin() / 200, _gems()])
	print("   trainings: %s" % ", ".join(_trainings))


func _save_counters(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"stats": _stats, "ledger": _ledger, "gems": _gem_ledger,
			"first": _first_day, "trainings": Array(_trainings), "shortcuts": _shortcuts,
			"skipped_fights": _skipped_fights}))


func _load_counters(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	_stats = d.get("stats", {})
	_ledger = d.get("ledger", {})
	_gem_ledger = d.get("gems", {})
	_first_day = d.get("first", {})
	_trainings = PackedStringArray(d.get("trainings", []))
	_shortcuts = d.get("shortcuts", [])
	_skipped_fights = d.get("skipped_fights", [])
	print("== counters carried on from %s" % path)


## The party's square in the wilderness band (0x49C3 x within the band, 0x49C4 y).
func _overland_at() -> Vector2i:
	return Vector2i(main._vm.read_byte(EclVM.OVERLAND_X), main._vm.read_byte(EclVM.OVERLAND_Y))


## A path over the wilderness band to `to` (water stops; the poisoned river until 0x4AA2).
func _overland_path(to: Vector2i) -> Array:
	var ov = main._vm.overland
	var bx: int = ov.band_x(main._vm.overland_band)
	var from := _overland_at()
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for d in 4:
			var nxt: Vector2i = cur + DungeonView.DELTA[d]
			if nxt.x < 0 or nxt.x > 15 or nxt.y < 0 or nxt.y >= OverlandMap.HEIGHT or came.has(nxt):
				continue
			var v: int = ov.value(nxt.x + bx, nxt.y)
			if OverlandMap.water(v) or (OverlandMap.river(v) and main._vm.read_byte(0x4AA2) == 0):
				continue
			came[nxt] = cur
			queue.append(nxt)
	var path: Array = []
	if not came.has(to):
		return path
	var p := to
	while p != from:
		path.push_front(p)
		p = came[p]
	path.push_front(from)
	return path


## Walks the wilderness band to `to`, a step at a time, playing what each step brings (12
## hours a step; encounters and the edges' menus). Stops when the party leaves the band.
func _overland_walk(to: Vector2i) -> void:
	var area := _here()
	for n in 80:
		if _wiped() or _here() != area or not main._vm.on_overland:
			return
		var path := _overland_path(to)
		if _overland_at() == to:
			if path.size() <= 1:
				# Standing on the gate: step off and back on to bring its menu up again.
				for d in 4:
					var nb: Vector2i = to + DungeonView.DELTA[d]
					if _overland_path(nb).size() == 2:
						await _overland_step(d)
						break
				if _here() != area:
					return
				path = _overland_path(to)
			else:
				return
		if path.size() < 2:
			_issue("wilderness: no way from %s to %s" % [str(_overland_at()), str(to)])
			return
		var d := DungeonView.DELTA.find(path[1] - path[0])
		await _overland_step(d)
		if _overland_at() == to:
			await _settle()
			return


func _overland_step(d: int) -> void:
	# In the wilderness the four arrows move the party that way (no turning).
	await main._press(["up", "right", "down", "left"][d])
	await _settle()


## One step to any open neighbouring square (to walk back onto an event square).
func _step_off() -> void:
	for d in DungeonView.DELTA:
		var n: Vector2i = main._pos + d
		if n.x < 0 or n.y < 0 or n.x >= GeoMap.SIZE or n.y >= GeoMap.SIZE:
			continue
		if main._find_path(main._pos, n).size() == 2:
			await main._tour(n)
			await _settle()
			return


## A rest begun in camp (counted).
func _start_rest(camp: CampScreen) -> void:
	_count("rests")
	camp._start_rest()


# --- Where to rest (strategy change 2) ----------------------------------------------------

## "inn" or "camp" for the area the party is in, by the plan's rest lines (default camp).
func _rest_rule() -> String:
	var r: Dictionary = _rest_rules.get(_here(), {})
	if r.is_empty():
		return "camp"
	if r.rule == "inn" and int(r.addr) >= 0 and main._vm.read_byte(int(r.addr)) >= int(r.value):
		return "camp"
	return String(r.rule)


## To the inn and back, for an area where camping isn't safe. True if the party rested there.
func _rest_safe() -> bool:
	if _at_inn:
		return false
	if _here() == TOWN:
		await _wait_for_day()
		await _do("inn 4,12")
		return true
	var ok := await _rest_at_inn(99)
	if not ok:
		_issue("no safe rest from %s %s (no way to the inn); camping" % [_here(), str(main._pos)])
	return ok


# --- City Hall (strategy change 1) --------------------------------------------------------

## The clerk: in and out of City Hall twice (she checks for rewards and offers up to three
## open commissions a visit, 0x4A05; a second visit after leaving lets her look again).
func _clerk() -> void:
	await _travel(TOWN)
	if _here() != TOWN:
		return
	await _wait_for_day()
	for visit in 2:
		await main._tour(Vector2i(4, 4))
		await _settle()
		await main._tour(Vector2i(4, 5))
		await _settle()
		while int(main._facing) != 1:
			await main._press("right")
		await main._press("up")
		await _settle()
		await _travel(TOWN)
		if visit == 0 and [0x4A97, 0x4A98, 0x4A99, 0x4A9A].any(func(a): return main._vm.read_byte(a) == 254):
			await _summoned()
	var flags := []
	for a in [0x4ABB, 0x4AA7, 0x4AC2, 0x4AB0, 0x4A97, 0x4A9B, 0x4AB2, 0x4AB7, 0x4AB6, 0x4AB3, 0x4AB5, 0x4A98, 0x4A99, 0x4A9A, 0x4ABE]:
		flags.append("%X=%d" % [a, main._vm.read_byte(a)])
	print("   commission flags: %s" % " ".join(flags))


## A summons inside City Hall (the clerk sets 254: Cadorna 0x4A97 east, his pouch 0x4A98
## and Lord Urslingen 0x4A99 south, the council 0x4A9A): back in, to that room's event
## (City Hall's events 30-33; 34 is the guard who turns the uninvited away).
func _summoned() -> void:
	# City Hall's squares carry events 26-34 on New Phlan's map (its script subtracts 26):
	# Cadorna's chambers 30, his pouch 31, Lord Urslingen 32, the council 33.
	var want := {0x4A97: 30, 0x4A98: 31, 0x4A99: 32, 0x4A9A: 33}
	await main._tour(Vector2i(4, 4))
	await _settle()
	await main._tour(Vector2i(4, 5))
	await _settle()
	while int(main._facing) != 1:
		await main._press("right")
	await main._press("up")
	await _settle()
	if _here() != "3:8":
		_issue("summoned to City Hall but not inside (%s)" % _here())
		return
	var map: GeoMap = main._maps[main._map_index].map
	for addr in want:
		if main._vm.read_byte(addr) != 254:
			continue
		var at := Vector2i(-1, -1)
		for y in GeoMap.SIZE:
			for x in GeoMap.SIZE:
				if map.flag(x, y) & 127 == want[addr] and at.x < 0:
					at = Vector2i(x, y)
		print("   summoned (0x%X): to City Hall's event %d at %s" % [addr, want[addr], at])
		if at.x >= 0:
			await main._tour(at)
			await _settle()
		if main._vm.read_byte(addr) != 255:
			_issue("City Hall summons 0x%X not answered at %s" % [addr, str(at)])
	if _here() == "3:8":
		await _travel(TOWN)


func _load(name: String) -> void:
	_bad_exits.clear()
	DirAccess.copy_absolute("user://bot_%s.cfg" % name, main._save_path())
	main._lost = false
	if main._start_menu != null:
		main._start_menu.visible = false
	main._quick_load()
	await _settle()


# --- M6 dev shortcuts (DevShortcuts; logged, debug builds only) ---------------------------

func _shortcut(kind: String, detail: String, why: String) -> void:
	var entry := "%s day %d %s: %s (%s)" % [_here(), _day(), kind, detail if detail != "" else "nothing to do", why]
	_shortcuts.append(entry)
	_count("shortcut " + kind)
	print("== SHORTCUT ", entry)


## Called by the combat screen at each new round: a fight where nobody has lost or gained a
## hit point for STALEMATE rounds (everyone guarding, the fleeing unable to get away: seen
## in the kobold king's hall, 8:13, round 5363) is won by shortcut, logged, and listed for
## the combat suite.
const STALEMATE := 40
var _stale_hp := -1
var _stale_rounds := 0


func _stalemate(round_no: int) -> bool:
	var hp := 0
	for c in main._combat._combat.combatants:
		hp = hp * 31 % 1000003 + int(c.who.hp) + (1000 if c.down else 0)
	if round_no <= 1 or hp != _stale_hp:
		_stale_hp = hp
		_stale_rounds = 0
		return false
	_stale_rounds += 1
	if _stale_rounds < STALEMATE:
		return false
	_stale_rounds = 0
	var key: String = _last_fight.get("key", "%s %d,%d" % [_here(), main._pos.x, main._pos.y])
	_shortcut("win", key, "stalemate: no one hurt for %d rounds, round %d" % [STALEMATE, round_no])
	_skipped_fights.append(key + " (stalemate)")
	print("SKIPPED FIGHT ", key, " (stalemate)")
	return true


## Called by the combat screen as each scripted fight opens: remembers it (for the fight that
## beat the party) and says whether to win it by shortcut.
func _fight_opens(rows: Array) -> bool:
	var names: PackedStringArray = []
	for r in rows:
		names.append("%d x%d" % [int(r[0]), int(r[1])])
	var key := "%s %d,%d [%s]" % [_here(), main._pos.x, main._pos.y, ", ".join(names)]
	_last_fight = {"key": key}
	var ev_here: int = main._maps[main._map_index].map.flag(main._pos.x, main._pos.y) & 127
	var rule := {}
	for r in _win_at:
		if int(r.n) > 0 and r.area == _here() and (r.at == main._pos or (int(r.ev) >= 0 and int(r.ev) == ev_here)):
			rule = r
			break
	if not rule.is_empty():
		rule.n = int(rule.n) - 1
		_shortcut("win", key, "the plan (a story event the party can't win)")
		_skipped_fights.append(key)
		print("SKIPPED FIGHT ", key)
		return true
	if key in _win_fights:
		# Once: the same patrol coming again (chat 13: Valjevo's giant patrol interrupting
		# every rest in 5:4 was won by shortcut 180 times) is fought again, and earns a
		# shortcut only by beating the party twice more.
		_win_fights.erase(key)
		_shortcut("win", key, "this fight beat the party twice")
		_skipped_fights.append(key)
		print("SKIPPED FIGHT ", key)
		return true
	return false


## Plan command: shortcut restore | level [member|all] | win | teleport <file:block> x,y <dir>
func _shortcut_command(w: PackedStringArray) -> void:
	match w[1] if w.size() > 1 else "":
		"restore":
			_shortcut("restore", DevShortcuts.restore(main._party), "the plan")
		"level":
			for m in main._party:
				if m.npc >= 128 or (w.size() > 2 and w[2] != "all" and m.name != w[2]):
					continue
				var got := DevShortcuts.grant_level(m, main._vm.tables, SpellTable.shared(main._game_path),
					RandomNumberGenerator.new(), _pick_spell)
				_shortcut("level", "%s %s" % [m.name, got if got != "" else "at the cap"], "the plan")
		"win":
			# shortcut win [<n> at <x>,<y> | at ev<k>]: the next fight, or the next n scripted
			# fights that open with the party on that square or on that event's squares (a
			# story event of several fights).
			if w.size() > 4 and w[3] == "at":
				# at <x>,<y> (a square) or at ev<n> (any square of that event)
				var at := Vector2i(-1, -1)
				var ev := -1
				if w[4].begins_with("ev"):
					ev = int(w[4].substr(2))
				else:
					var xy := w[4].split(",")
					at = Vector2i(int(xy[0]), int(xy[1]))
				_win_at.append({"n": int(w[2]), "at": at, "ev": ev, "area": _here()})
				print("   (shortcut: the next %s fights at %s %s are won)" % [w[2], _here(), w[4]])
			else:
				main._combat.dev_auto_win = true
				_shortcut("win", "the next fight", "the plan")
		"keep":
			# shortcut keep <n>: only the first n members go on (a coverage run's smaller
			# party, for the branches a script takes on the party's strength).
			var n := int(w[2])
			var gone: PackedStringArray = []
			while main._party.size() > n:
				gone.append(main._party[main._party.size() - 1].name)
				main._party.remove_at(main._party.size() - 1)
			main._vm.party = main._party
			main._show()
			_shortcut("keep", "%d members (left out %s)" % [n, ", ".join(gone)], "the plan")
		"flag":
			# Chat 15: `shortcut flag 4A65 or 1 <why...>`: a story flag as a player can have it
			# (a coverage variant: 5:6's disguise worn into 5:4). Logged.
			var addr := w[2].hex_to_int()
			var v := int(w[4])
			var old: int = main._vm.read_byte(addr)
			var now := v
			match w[3]:
				"or":
					now = old | v
				"and":
					now = old & v
			main._vm.write_byte(addr, now)
			_shortcut("flag", "%04X %d -> %d" % [addr, old, now], " ".join(w.slice(5)) if w.size() > 5 else "the plan")
		"item":
			# Chat 17: `shortcut item <type> <name...>`: the first member carries an item of that
			# type, as a player who found it does (6:19: Diogenes asks for the kobolds' silver
			# bottle, type 82, FIND_ITEM). A bare record: the name and the type. Logged.
			var rec := PackedByteArray()
			rec.resize(GameItem.SIZE)
			var nm := " ".join(w.slice(3)).to_upper()
			rec[0] = mini(nm.length(), 41)
			for i in rec[0]:
				rec[1 + i] = nm.unicode_at(i)
			rec[46] = int(w[2])
			rec[57] = 1
			var it := GameItem.from_record(rec)
			main._party[0].items.append(it)
			_shortcut("item", "%s carries %s (type %d)" % [main._party[0].name, nm, it.type], "the plan")
		"teleport":
			var a := w[2].split(":")
			var xy := w[3].split(",")
			var ok: bool = main.dev_teleport(int(a[0]), int(a[1]), Vector2i(int(xy[0]), int(xy[1])), "NESW".find(w[4]))
			await _settle()
			_shortcut("teleport", "%s %s %s%s" % [w[2], w[3], w[4], "" if ok else " REFUSED"], "the plan")
		_:
			_issue("shortcut: unknown kind in '%s'" % " ".join(w))


func _pick_spell(offered: Array) -> int:
	for id in LEARN_ORDER:
		if id in offered:
			return id
	return offered[0]


## M6 (plan: expect_level): a member more than one level below what the area expects (its best class, as multi-class
## characters run behind) first trains normally if it can; what's still missing is granted by
## shortcut, logged.
func _keep_level() -> void:
	var want: int = int(_expected_level.get(_here(), 0)) - 1
	if want <= 0:
		return
	var behind := func() -> Array:
		var out := []
		for m in main._party:
			if m.npc < 128 and m.status == PartyMember.STATUS_OKAY and _top_level(m) < want:
				out.append(m)
		return out
	if behind.call().is_empty():
		return
	if _can_train() and _round_trip(_here()):
		var area := _here()
		await _town()
		await _travel(area)
	for m in behind.call():
		for k in 8:
			if _top_level(m) >= want:
				break
			var got := DevShortcuts.grant_level(m, main._vm.tables, SpellTable.shared(main._game_path),
				RandomNumberGenerator.new(), _pick_spell)
			if got == "":
				break
			_shortcut("level", "%s to %s" % [m.name, got], "%s expects level %d" % [_here(), want + 1])


func _top_level(m: PartyMember) -> int:
	var top := 0
	for x in m.raw.slice(0x96, 0x9E):
		top = maxi(top, x)
	return top


## Wilderness bands: the parts the poisoned river and water split them into (flood fill with
## the walk's own rules). -1 when not a band or unknown.
const BANDS := {"6:25": 0, "7:26": 1, "8:27": 2}

func _part_of(area: String, at: Vector2i) -> int:
	if not BANDS.has(area):
		return _dungeon_part(area, at)
	if not _parts.has(area):
		var ov = main._vm.overland
		if ov == null:
			return -1
		var bx: int = ov.band_x(BANDS[area])
		var label := {}
		var id := 0
		for y in OverlandMap.HEIGHT:
			for x in 16:
				var p := Vector2i(x, y)
				if label.has(p) or not _walkable(ov, bx, p):
					continue
				var stack: Array[Vector2i] = [p]
				label[p] = id
				while not stack.is_empty():
					var c: Vector2i = stack.pop_back()
					for d in 4:
						var q: Vector2i = c + DungeonView.DELTA[d]
						if q.x < 0 or q.x > 15 or q.y < 0 or q.y >= OverlandMap.HEIGHT or label.has(q):
							continue
						if _walkable(ov, bx, q):
							label[q] = id
							stack.append(q)
				id += 1
		_parts[area] = label
	return int(_parts[area].get(at, -1))


func _walkable(ov, bx: int, p: Vector2i) -> bool:
	var v: int = ov.value(p.x + bx, p.y)
	return not (OverlandMap.water(v) or (OverlandMap.river(v) and main._vm.read_byte(0x4AA2) == 0))


func _part_now() -> int:
	if not main._vm.on_overland:
		var a := _here().split(":")
		if main._maps[main._map_index].id != int(a[1]):
			return -1       # on another of the area's maps: parts unknown
		return _part_of(_here(), main._pos)
	return _part_of(_here(), _overland_at())


## Chat 14 (region-aware travel): a dungeon area's parts are the squares that can reach each
## other on foot through open sides and doors of the area's own map (the GEO block with the
## script's number; areas whose script runs on other maps have no parts: -1, any). Two ways
## into one area can land in parts with no way between them (5:3's 0,11 west lands in a
## walled-off corner of 5:6).
var _dungeon_parts := {}


func _dungeon_part(area: String, at: Vector2i) -> int:
	if not _dungeon_parts.has(area):
		var a := area.split(":")
		var map: GeoMap = null
		var ecl: EclScript = main._script(int(a[0]), int(a[1]))
		for m in main._maps:
			if String(m.file) == "GEO%s.DAX" % a[0] and int(m.id) == int(a[1]) and ecl != null and ecl.loads_map(int(a[1])):
				map = m.map
		var label := {}
		if map != null:
			var id := 0
			for y in GeoMap.SIZE:
				for x in GeoMap.SIZE:
					var p := Vector2i(x, y)
					if label.has(p):
						continue
					var stack: Array[Vector2i] = [p]
					label[p] = id
					while not stack.is_empty():
						var c: Vector2i = stack.pop_back()
						for d in 4:
							if map.wall(c.x, c.y, d) > 0 and map.door(c.x, c.y, d) == 0:
								continue
							var q: Vector2i = c + DungeonView.DELTA[d]
							if q.x < 0 or q.y < 0 or q.x >= GeoMap.SIZE or q.y >= GeoMap.SIZE or label.has(q):
								continue
							label[q] = id
							stack.append(q)
					id += 1
		_dungeon_parts[area] = label
	return int(_dungeon_parts[area].get(at, -1))


## The part of the destination an exit arrives in: learned, else unknown (-1, any).
func _arrival_part(from: String, e: Dictionary) -> int:
	if not BANDS.has(e.to):
		# A dungeon: the part of the square the sweep arrived on.
		if e.has("ax"):
			return _part_of(e.to, Vector2i(int(e.ax), int(e.ay)))
		return -1
	var key := "%s %d,%d %d" % [from, e.x, e.y, e.dir]
	return int(_arrivals.get(key, -1))



# --- M6 coverage runs, area by area (decided 2026-11-13; chat 14) --------------------------
#
# A coverage run plays one area (one script block) as thoroughly as it can, for real: every
# event square of every map the block runs on, entered and then left in each of the four
# directions (so each square's on-move branches run); a rest on each map (the rest and
# interrupted-rest entries); and at every script menu, each choice not yet taken in any run
# is queued as a job. A job puts the game back to the snapshot taken as the step that led to
# the menu began (main.dev_snapshot), takes the same step, gives the same answers up to that
# menu and then the other choice, and plays on from there with the bot's usual policy (its
# own menus queue more jobs). A typed answer queues a wrong one too. Every fight is won at once
# by shortcut and logged for the combat suite ("COVER FIGHT"); a party that falls anyway (a
# trap, a script's damage) is put back as it was before that move ("COVER WIPE", a finding).

var _cover_area := ""
var _cover_snap := {}          # the game as the current step began (in the area only)
var _cover_fresh := false      # chat 15: each event walked to from the part's arrival
var _cover_flee_next := false  # chat 15: the next set fight is fled (a flee job)
var _cover_flee_at := -1        # chat 16: ... the one at this script offset (fights before it are won)
var _cover_target := Vector2i(-1, -1)   # chat 15: the square the walk is going to
var _cover_resting := false    # chat 15: the menus now come from a rest, not a step
const QUEST_LO := 0x4A00       # the area markers and quest flags
const QUEST_HI := 0x4B00
var _cover_states := {}        # chat 15: quest-flag changes a job made -> its end snapshot
var _cover_states_walked := {}
var _cover_dir := -1           # that step's direction
var _cover_path: Array = []    # the answers given since: {"c": i, "at": menu offset} / {"t": text}
var _cover_jobs: Array = []
var _cover_queued := {}
var _cover_forced: Array = []  # a job's answers still to give
var _cover_fights: PackedStringArray = []
var _cover_log := {"jobs": 0, "diverged": 0, "wipes": 0, "squares": 0, "tries": 0, "maps": 0}


func _cover(area: String, minutes: int) -> void:
	_cover_area = area
	_cover_jobs = []
	_cover_queued = {}
	_cover_ran = {}
	_cover_states = {}
	_cover_parts_walked = {}
	_cover_states_walked = {}
	_cover_exits_used = {}
	_cover_fights = []
	_cover_log = {"jobs": 0, "diverged": 0, "wipes": 0, "squares": 0, "tries": 0, "maps": 0}
	var win_if: Callable = main._combat.dev_win_if
	main._combat.dev_win_if = _cover_fight
	main.dev_step_hook = _cover_step
	main.dev_choice_hook = _cover_choice
	main.dev_typed_hook = _cover_typed
	var deadline := Time.get_ticks_msec() + minutes * 60000
	_cover_resume_load()
	if false:
		pass
	else:
		_cover_level()
		print("==== COVER %s: walking every map" % area)
		var start: Dictionary = main.dev_snapshot()
		await _cover_walk(deadline)
		print("==== COVER %s: %d menu choices queued" % [area, _cover_jobs.size()])
		var done := 0
		while not _cover_jobs.is_empty() and Time.get_ticks_msec() < deadline:
			var job: Dictionary = _cover_jobs.pop_front()
			if _cover_taken(job.key) or _cover_ran.has(job.key):
				continue
			_cover_ran[job.key] = true
			if _cover_resume_skip(job.key):
				continue
			done += 1
			await _cover_job(job)
			_cover_resume_note("ran", job.key)
		# Chat 17: an area whose script reads the hour (0x49C8/0x49C9: the smith works by day in
		# 5:6, the scribes close at 17:00 in 5:4) is walked again twelve hours later, the clock
		# moved on by shortcut (logged; as a player who rested that long has it).
		if _cover_reads_clock(area):
			main.dev_restore(start)
			await _settle()
			GameClock.add_minutes(main._vm, 12 * 60)
			_shortcut("clock", "+12 hours, now %s" % GameClock.text(main._vm), "coverage run: %s's script reads the hour" % area)
			_cover_states["part clock +12h"] = main.dev_snapshot()
		# The states jobs opened, each walked like an arrival (its events again, its menus'
		# new choices queued and played), up to six.
		var walked := 0
		while not _cover_states.is_empty() and Time.get_ticks_msec() < deadline:
			# Parts no walk has been in first, all of them; then up to six flag states.
			var sig: String = _cover_states.keys()[0]
			for k: String in _cover_states:
				if not k.begins_with("outside "):
					sig = k     # chat 17: states inside the area before those outside it
					break
			for k: String in _cover_states:
				if k.begins_with("part "):
					sig = k
					break
			if walked >= 6 and not sig.begins_with("part "):
				break
			var snap: Dictionary = _cover_states[sig]
			_cover_states.erase(sig)
			if _cover_states_walked.has(sig):
				continue
			_cover_states_walked[sig] = true
			walked += 1
			if _cover_resumed.states.has(sig):
				print("==== COVER %s: the state %s was walked before the restart" % [area, sig.strip_edges()])
				continue
			print("==== COVER %s: walking again in the state %s" % [area, sig.strip_edges()])
			main.dev_restore(snap)
			await _settle()
			await _cover_walk(deadline, true)
			while not _cover_jobs.is_empty() and Time.get_ticks_msec() < deadline:
				var job: Dictionary = _cover_jobs.pop_front()
				if _cover_taken(job.key) or _cover_ran.has(job.key):
					continue
				_cover_ran[job.key] = true
				if _cover_resume_skip(job.key):
					continue
				done += 1
				await _cover_job(job)
				_cover_resume_note("ran", job.key)
			_cover_resume_note("states", sig)
		_cover_log["states"] = walked
		if not _cover_jobs.is_empty():
			_issue("cover %s: out of time with %d choices still queued" % [area, _cover_jobs.size()])
		_cover_log.jobs = done
		main.dev_restore(start)
		await _settle()
	main.dev_step_hook = Callable()
	main.dev_choice_hook = Callable()
	main.dev_typed_hook = Callable()
	main._combat.dev_win_if = win_if
	print("==== COVER %s done: %s" % [area, str(_cover_log)])
	for f in _cover_fights:
		print("COVER FIGHT ", f)
	_cover_area = ""
	main._vm.coverage.save()


## Chat 17: a run cut off by a restart of the workspace (every 30 minutes or so) starts again
## with the same jobs; the jobs and state walks it finished are kept in BOT_RESUME's file, so
## the rerun walks the maps again (that queues the jobs, with their snapshots) but skips them.
var _cover_resumed := {"ran": {}, "states": {}, "opened": {}}   # from before the restart
var _cover_resume_file := ""


func _cover_resume_load() -> void:
	_cover_resumed = {"ran": {}, "states": {}, "opened": {}}
	_cover_resume_file = OS.get_environment("BOT_RESUME")
	if _cover_resume_file == "" or not FileAccess.file_exists(_cover_resume_file):
		return
	var f := FileAccess.open(_cover_resume_file, FileAccess.READ)
	for line in f.get_as_text().split("\n", false):
		var kind := line.get_slice("\t", 0)
		var key := line.get_slice("\t", 1)
		if kind == "opened":
			# A job that opened a state: run again unless that state was walked.
			var jk := key.get_slice("|||", 0)
			if not _cover_resumed.opened.has(jk):
				_cover_resumed.opened[jk] = []
			_cover_resumed.opened[jk].append(key.get_slice("|||", 1))
		elif _cover_resumed.has(kind):
			_cover_resumed[kind][key] = true
	print("==== COVER %s: resuming: %d jobs and %d states done before the restart" % [_cover_area,
		_cover_resumed.ran.size(), _cover_resumed.states.size()])


## A job done before the restart is skipped, unless a state it opened wasn't walked then.
func _cover_resume_skip(key: String) -> bool:
	if not _cover_resumed.ran.has(key):
		return false
	for sig in _cover_resumed.opened.get(key, []):
		if not _cover_resumed.states.has(sig):
			return false
	return true


func _cover_resume_note(kind: String, key: String) -> void:
	if _cover_resume_file == "":
		return
	var f: FileAccess
	if FileAccess.file_exists(_cover_resume_file):
		f = FileAccess.open(_cover_resume_file, FileAccess.READ_WRITE)
	else:
		f = FileAccess.open(_cover_resume_file, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s\t%s" % [kind, key])


## Chat 17: whether the area's script reads the clock's hour (0x49C8, 0x49C9).
func _cover_reads_clock(area: String) -> bool:
	var a := area.split(":")
	var ecl: EclScript = main._script(int(a[0]), int(a[1]))
	if ecl == null:
		return false
	for off in ecl.offsets():
		for arg in ecl.instructions[off].args:
			if typeof(arg.value) == TYPE_INT and int(arg.type) in [0x01, 0x03, 0x05, 0x81] \
					and int(arg.value) in [0x49C8, 0x49C9]:
				return true
	return false


## Whether a queued choice has run since it was queued (in this run or another).
var _cover_all := false
var _cover_ran := {}
var _cover_parts_walked := {}  # chat 16: "part map:region" walked in this run
var _cover_looking := false    # LOOK is running (its menus' jobs look again rather than step)


func _cover_taken(key: String) -> bool:
	if _cover_all or key.contains("@"):
		return false
	var a := key.split("|")
	var b: Dictionary = main._vm.coverage.blocks.get(a[0], {})
	return b.has("br") and b.br.has(a[1])


var _cover_last_step := ""     # "map:x,y,dir" of the last step begun in the area
var _cover_exits_used := {}    # such steps that took the party away: walks keep off them


func _cover_step(direction: int) -> void:
	_cover_path = []
	_cover_dir = direction
	if main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
		# (Outside the area too: a step into it can open its arrival menu, Diogenes's magic
		# mouth; only the area's own menus queue jobs.)
		_cover_snap = main.dev_snapshot()
		if main._vm.block_key == _cover_area:
			_cover_last_step = "%d:%d,%d,%d" % [main._map_index, main._pos.x, main._pos.y, direction]
	else:
		_cover_snap = {}


func _cover_choice(choice: int) -> void:
	var vm: EclVM = main._vm
	if not _cover_snap.is_empty() and vm.block_key == _cover_area and vm._menu_kind != "who" and vm.menu.size() > 1:
		for j in vm.menu.size():
			if j == choice:
				continue
			var c := j
			if vm._menu_kind == "encounter" and j == 3 and vm.encounter_distance == 0:
				c = 4
			var key := "%s|%d:c%d" % [vm.block_key, vm._menu_at, c]
			if vm._menu_kind == "encounter" and c == 3 and vm.encounter_distance > 1:
				# Chat 17: ADVANCE from each distance is a job of its own, so a job's ADVANCE can
				# be followed by another until the monsters stand at 0 and PARLAY is offered
				# (2:15's kobolds plead for mercy at distance 2; their PARLAY was never seen).
				key += "d%d" % vm.encounter_distance
			# A menu in a subroutine (5:5's YES/NO at 0x9A1D, called by several events): its
			# choice taken from one caller says nothing of another's, so each caller gets its
			# own job (run once a run; coverage can't tell callers apart).
			if not vm.stack.is_empty():
				key += "@%d" % vm.stack.back()
			if _cover_taken(key):
				continue
			# Chat 17: the same choice again when the area's flags differ (up to three ways a
			# choice is met): 7:22's THROW A ROCK toggles a flag, and the second throw is another
			# path (0xA139). A repeat's key gets "#n".
			var flags := vm.mem.slice(QUEST_LO, QUEST_HI).hex_encode()
			var met: Dictionary = _cover_queued.get(key, {})
			if met.has(flags) or met.size() >= 3:
				continue
			if not met.is_empty():
				key += "#%d" % met.size()
			met[flags] = true
			_cover_queued[key.get_slice("#", 0)] = met
			var path := _cover_path.duplicate(true)
			path.append({"c": j, "at": vm._menu_at})
			_cover_jobs.append({"snap": _cover_snap, "dir": _cover_dir, "path": path, "key": key, "rest": _cover_resting,
				"look": _cover_looking, "what": "%04X %s" % [vm._menu_at + EclScript.BASE, String(vm.menu[j]).strip_edges()],
				"reroll": vm._menu_kind in ["encounter", "parlay"]})
	_cover_path.append({"c": choice, "at": vm._menu_at})


const WRONG_WORD := "XYZZY"


func _cover_typed(text: String) -> void:
	var vm: EclVM = main._vm
	if not _cover_snap.is_empty() and vm.block_key == _cover_area and text != WRONG_WORD:
		var key := "%s|%d:wrong" % [vm.block_key, vm._at]
		if not _cover_queued.has(key):
			_cover_queued[key] = true
			var path := _cover_path.duplicate(true)
			path.append({"t": WRONG_WORD})
			_cover_jobs.append({"snap": _cover_snap, "dir": _cover_dir, "path": path, "key": key,
				"rest": _cover_resting, "look": _cover_looking, "what": "%04X typed %s" % [vm._at + EclScript.BASE, WRONG_WORD]})
	_cover_path.append({"t": text})


## The bot's hook in a coverage run: a job's answers first; then COMBAT at encounters (the
## fight is won by shortcut; the other choices are queued).
var _cover_stairs_for := ""     # chat 17: the walk's target the stairs were taken for


func _cover_hook() -> bool:
	var vm: EclVM = main._vm
	if _here() == _cover_area and _cover_going_in:
		# In: the way's answers are spent (Diogenes's mouth puts the party back on the
		# band's cave square, whose menu would send it in again and again).
		_gate_answer = ""
		_gate_picks = []
	if _here() != _cover_area and _here() != "0:0" and not _cover_going_in:
		# Out of the area (stairs, a gate, a teleporter on the way): the walk ends there;
		# the coverage run puts the party back.
		main.tour_stop = true
	if not _cover_forced.is_empty() and vm.state in [EclVM.State.MENU, EclVM.State.INPUT]:
		var f: Dictionary = _cover_forced.pop_front()
		if f.has("t") and vm.state == EclVM.State.INPUT:
			print("   >> typed %s (coverage job)" % f.t)
			main._on_typed(f.t)
			return true
		if f.has("c") and vm.state == EclVM.State.MENU and int(f.at) == vm._menu_at and int(f.c) < vm.menu.size():
			print("   >> %d (%s: coverage job)" % [int(f.c) + 1, String(vm.menu[int(f.c)]).strip_edges()])
			main.dev_choose(int(f.c))
			return true
		_cover_log.diverged += 1
		print("   (coverage job: the game went another way at %04X; playing on)" % (vm._at + EclScript.BASE))
		_cover_forced = []
	if vm.state == EclVM.State.MENU and vm.block_key == _cover_area and vm._menu_kind != "encounter":
		# Ladders and stairs: up or down, always (the other map of the area is the point; the
		# walk comes back by the snapshot). The explore rule saves them for last.
		var said: String = main._message.text
		var opts: Array = Array(vm.menu).map(func(x): return String(x).strip_edges().to_upper())
		if "YES" in opts and "NO" in opts and (said.contains("CLIMB") or said.contains("STAIRS") \
				or said.contains("LADDER") or said.contains("GO DOWN") or said.contains("GO UP")):
			# Chat 15: only on the square the walk is going to; stairs on the way are passed
			# (2:9's tower stairs bounced the walk up and down a dozen times).
			if _cover_target.x >= 0 and main._pos != _cover_target:
				print("   >> %d (NO: stairs on the way to %s)" % [opts.find("NO") + 1, _cover_target])
				main.dev_choose(opts.find("NO"))
				return true
			# Chat 17: once per square walked to: 2:9's tower stairs land the party on the other
			# stairs, which asked again, and the walk went up and down until the loop rule.
			if _cover_stairs_for == "%d:%s" % [main._map_index, _cover_target]:
				print("   >> %d (NO: the stairs were taken once already)" % (opts.find("NO") + 1))
				main.dev_choose(opts.find("NO"))
				return true
			_cover_stairs_for = "%d:%s" % [main._map_index, _cover_target]
			print("   >> %d (YES: coverage run, the other level)" % (opts.find("YES") + 1))
			main.dev_choose(opts.find("YES"))
			return true
	if vm.state == EclVM.State.MENU and vm._menu_kind == "encounter" and not main._combat.visible \
			and vm.block_key == _cover_area:
		var items: Array = Array(vm.menu).map(func(x): return String(x).strip_edges().to_upper())
		if "COMBAT" in items:
			print("   >> %d (encounter: COMBAT, coverage run)" % (items.find("COMBAT") + 1))
			main.dev_choose(items.find("COMBAT"))
			return true
	return false


func _cover_fight(rows: Array) -> bool:
	var vm: EclVM = main._vm
	if _cover_flee_next and (_cover_flee_at < 0 or vm._at == _cover_flee_at):
		# Chat 16: only the fight the job was queued for; 6:28's chained fights had fled the
		# first fight of the chain instead (the guards before the commandant).
		# A flee job (chat 15): this fight is fled by shortcut, so the script's other side
		# (0x6DC7 = 129, "THE PARTY HAS FLED") runs.
		_cover_flee_next = false
		main._combat.dev_flee = true
		_shortcut("flee", "%s at %04X" % [vm.block_key, vm._at + EclScript.BASE], "coverage run: the fled side of a set fight")
		return false
	# Each set fight of the area also queues a job that flees it (once a run).
	if not _cover_snap.is_empty() and vm.block_key == _cover_area and _cover_forced.is_empty():
		var key := "%s|flee@%d" % [vm.block_key, vm._at]
		if not _cover_queued.has(key):
			_cover_queued[key] = true
			_cover_jobs.append({"snap": _cover_snap, "dir": _cover_dir, "path": _cover_path.duplicate(true),
				"key": key, "rest": _cover_resting, "flee": true, "look": _cover_looking, "flee_at": vm._at,
				"what": "%04X COMBAT fled" % [vm._at + EclScript.BASE]})
	var names: PackedStringArray = []
	for r in rows:
		names.append("%d x%d" % [int(r[0]), int(r[1])])
	var key := "%s map %d %d,%d [%s]" % [_here(), main._maps[main._map_index].id, main._pos.x, main._pos.y, ", ".join(names)]
	if not key in _cover_fights:
		_cover_fights.append(key)
	_count("shortcut win")
	print("   (coverage run: fight won by shortcut: %s)" % key)
	return true


## The party at the level the game expects in the area (expect_level), by the level shortcut
## (logged): a coverage run's party, not the story run's (decided 2026-11-13).
func _cover_level() -> void:
	var want: int = int(_expected_level.get(_cover_area, 0))
	for m in main._party:
		if m.npc >= 128:
			continue
		for k in 12:
			if _top_level(m) >= want:
				break
			var got := DevShortcuts.grant_level(m, main._vm.tables, SpellTable.shared(main._game_path),
				RandomNumberGenerator.new(), _pick_spell)
			if got == "":
				break
			_shortcut("level", "%s to %s" % [m.name, got], "coverage run: %s expects level %d" % [_cover_area, want])


## Anyone dead, down or hurt is put right by the restore shortcut (logged), so every event is
## met by the whole party at full strength.
func _cover_heal() -> void:
	for m in main._party:
		if m.status != PartyMember.STATUS_OKAY or m.hp < m.hp_max / 2:
			_shortcut("restore", DevShortcuts.restore(main._party), "coverage run")
			return


## A step or walk is over: a fallen party goes back as it was (logged), so the run goes on.
func _cover_recover(back: Dictionary, what: String) -> bool:
	if not _wiped():
		return false
	_cover_log.wipes += 1
	print("== COVER WIPE %s (%s): back to the snapshot" % [what, main._state_line()])
	main.dev_restore(back)
	await _settle()
	return true


## Chat 17: a choice at an encounter or PARLAY menu is played three times, the dice rerolled for
## the 2nd and 3rd: what it brings is a roll (the monsters' reaction; 2:20's patrols answer a
## PARLAY with a fight, a toll or "DA BOSS DON'T LIKE YOUSE GUYS").
func _cover_job(job: Dictionary) -> void:
	await _cover_job_once(job)
	if job.get("reroll", false):
		for k in 2:
			var again: Dictionary = job.duplicate()
			again["reroll"] = false
			again["reseed"] = true
			await _cover_job_once(again)


func _cover_job_once(job: Dictionary) -> void:
	print("\n== COVER JOB %s: %s (%d answers, then this)%s" % [job.key, job.what, job.path.size() - 1,
		" (again, the dice rerolled)" if job.get("reseed", false) else ""])
	main.dev_restore(job.snap)
	if job.get("reseed", false):
		main._vm._rng.seed = randi() ^ Time.get_ticks_usec()
	_cover_forced = job.path.duplicate(true)
	_cover_stairs_for = ""
	_cover_snap = {}
	_cover_flee_next = job.get("flee", false)
	_cover_flee_at = int(job.get("flee_at", -1))
	if job.get("rest", false):
		# A menu a rest brought: rest again until it comes (an interruption is a roll).
		# Chat 16: what the rest brings queues its own jobs (3:11's watch, fought from a rest
		# job, never had a flee job: its fled side, 0xA094, is the halls' NEW_ECL 0 way out).
		for n in 8:
			if n > 0:
				main.dev_restore(job.snap)
				# Chat 17: the restore brings the same dice back; the next try needs others.
				main._vm._rng.seed = randi() ^ Time.get_ticks_usec()
				_cover_forced = job.path.duplicate(true)
				_cover_flee_next = job.get("flee", false)
			_cover_snap = job.snap
			_cover_path = []
			_cover_resting = true
			await _settle()
			if await _open_camp():
				await _rest_in_camp(1)
			await _settle()
			if _cover_forced.size() < job.path.size():
				break
		_cover_resting = false
	elif job.get("look", false):
		await _cover_face(int(job.dir))
		await main._press("l")
	else:
		main._try_move(int(job.dir))
	await _settle()
	if not _cover_forced.is_empty():
		_cover_log.diverged += 1
		print("   (coverage job: %d answers not used; the menu never came)" % _cover_forced.size())
		_cover_forced = []
	_cover_flee_next = false
	var wiped: bool = await _cover_recover(job.snap, "job " + String(job.key))
	print("   job ends: ", main._state_line())
	# Chat 15: a job that leaves the party in the area with its quest flags changed (the
	# bugbears fought instead of warned, the watch fought, a pass shown) opens a state the walk
	# hasn't seen: kept for a walk of its own once the jobs are done.
	# Chat 17: a job that ends outside the area (Diogenes's mouth sends every party out) with the
	# story flags (0x4A20 up) changed opens a state too; its walk comes in again by the ways in.
	var inside := _here() == _cover_area
	if not wiped and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE] and (inside or _here() != "0:0"):
		var before: PackedByteArray = job.snap.vm.mem.slice(QUEST_LO, QUEST_HI)
		var now: PackedByteArray = main._vm.mem.slice(QUEST_LO, QUEST_HI)
		var sig := "" if inside else "outside "
		for i in now.size():
			if not inside and i < 0x20:
				continue
			# Flags and the area's own markers (0x4A00-0x4A1F), as they go on or off; a
			# counter going up (a sign read again) is not a new state.
			if (now[i] == 0) != (before[i] == 0):
				sig += "%04X=%d " % [QUEST_LO + i, now[i]]
			elif now[i] != before[i] and i >= 0x20:
				var bits: int = now[i] & ~before[i]
				if bits != 0:
					sig += "%04X|%d " % [QUEST_LO + i, bits]
		if sig != "" and sig != "outside ":
			if not _cover_states.has(sig) and not _cover_states_walked.has(sig) and _cover_states.size() < 12:
				_cover_states[sig] = main.dev_snapshot()
				print("   (a new state for the walk: %s)" % sig.strip_edges())
				_cover_resume_note("opened", "%s|||%s" % [job.key, sig])
		# Chat 16: a job that leaves the party on a part of a map no walk has been in (6:25's
		# caves: ENTER, then STAY IN; the walk answers LEAVE CAVE) is walked as an arrival too.
		if inside and not main._vm.on_overland:
			var part := "part %d:%d" % [main._map_index, _region_id(main._pos)]
			if not _cover_parts_walked.has(part) and not _cover_states.has(part) and not _cover_states_walked.has(part):
				_cover_states[part] = main.dev_snapshot()
				print("   (a part no walk has been in: %s)" % part)
				_cover_resume_note("opened", "%s|||%s" % [job.key, part])


## Every map the area's script runs on: its events, each square from every side, a rest, and
## a step off each edge. Each part of a map (squares that reach each other on foot) is walked
## once, from wherever the party first arrives in it: another map of the area, or another part
## of this one (a tower room reached from the next map), joins the queue.
func _cover_walk(deadline: int, again := false) -> void:
	var start: Dictionary = main.dev_snapshot()
	# Outside the area (an area that turns a party out at once, Diogenes's cave mouth): only
	# the ways in.
	var arrivals: Array = [start] if _here() == _cover_area else []
	var seen := {}
	_cover_done = {}
	_cover_probed = {}
	_cover_groups_in = {}
	if again:
		_cover_groups_in["all"] = true
	if _here() == _cover_area and _area_map(_cover_area) == main._maps[main._map_index].map:
		_cover_groups_in["part %d" % _dungeon_part(_cover_area, main._pos)] = true
	var ways_in := [] if again and not arrivals.is_empty() else _cover_ways_in()
	while Time.get_ticks_msec() < deadline:
		if arrivals.is_empty():
			# Every way into the area the graph knows, once each (Valjevo's outer castle runs
			# one script over several maps: which map and part the party lands in depends on
			# the way it came): from the next area, walk it in for real.
			if ways_in.is_empty():
				break
			var e: Dictionary = ways_in.pop_front()
			var group := String(e.get("group", ""))
			if group != "" and _cover_groups_in.has(group):
				continue        # that part has been reached already
			main.dev_restore(e.get("from_snap", start))
			await _settle()
			if e.get("teleport", false):
				# Chat 15: no walking way into this part worked (the way in starts on another map
				# of the next area, or behind a wall there): placed on the arrival square.
				var ta := String(e.to).split(":")
				var ok: bool = main.dev_teleport(int(ta[0]), int(ta[1]), Vector2i(int(e.ax), int(e.ay)), int(e.dir))
				await _settle()
				_shortcut("teleport", "%s %d,%d %s%s" % [e.to, e.ax, e.ay, "NESW"[int(e.dir)], "" if ok else " REFUSED"],
					"coverage run: no walking way into part %s worked" % group)
				if ok and _here() == _cover_area and not _wiped() and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
					_cover_groups_in[group] = true
					print("   came in on map %d at %s" % [main._maps[main._map_index].id, main._pos])
					arrivals.append(main.dev_snapshot())
				continue
			print("== COVER way in from %s at %d,%d %s" % [e.from, e.x, e.y, "NESW"[e.dir]])
			_cover_going_in = true
			await _travel(e.from)
			_cover_going_in = false
			if _here() != e.from or _wiped():
				print("   (couldn't get to %s: in %s at %s)" % [e.from, _here(), main._pos])
				continue
			if not main._vm.on_overland and (e.entry == "gate" or main._pos == Vector2i(e.x, e.y)):
				await _step_off()
			_gate_answer = String(e.get("answer", ""))
			_gate_uses = 0
			_gate_picks = Array(e.get("picks", []))
			_gate_square = Vector2i(e.x, e.y)
			_travelling = true
			_cover_going_in = true
			main.tour_stop = false
			if main._vm.on_overland:
				await _overland_walk(Vector2i(e.x, e.y))
			else:
				await main._tour(Vector2i(e.x, e.y))
			_cover_going_in = false
			await _settle()
			if _here() == e.from and e.entry == "move" and main._pos == Vector2i(e.x, e.y):
				await _cover_face(int(e.dir))
				await main._press("up")
				await _settle()
			_travelling = false
			_gate_answer = ""
			_gate_picks = []
			if _here() == _cover_area and not _wiped() and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
				print("   came in on map %d at %s" % [main._maps[main._map_index].id, main._pos])
				if group != "":
					_cover_groups_in[group] = true
				arrivals.append(main.dev_snapshot())
			else:
				print("   (that way in ends in %s at %s: %s, vm %d)" % [_here(), main._pos, main._state_line(), main._vm.state])
				# Chat 17: an area that sends every party out (Diogenes's mouth) and changed the
				# story flags on the way: the same way in once more, from here (his thanks set
				# 0x4A87 bit 1; the next visit finds the cave empty, 0x996E).
				var was: PackedByteArray = (e.get("from_snap", start) as Dictionary).vm.mem.slice(QUEST_LO + 0x20, QUEST_HI)
				if not e.has("from_snap") and not _wiped() and main._vm.mem.slice(QUEST_LO + 0x20, QUEST_HI) != was:
					var again_e: Dictionary = e.duplicate()
					again_e["from_snap"] = main.dev_snapshot()
					ways_in.push_front(again_e)
					print("   (the story flags changed: that way in once more)")
			continue
		var arrival: Dictionary = arrivals.pop_front()
		main.dev_restore(arrival)
		await _settle()
		if main._vm.on_overland:
			# A wilderness band (chat 15): every square of the part arrived in.
			var bregion := "band:%d" % _part_of(_here(), _overland_at())
			if seen.has(bregion):
				print("   (part %s from %s: walked already)" % [bregion, _overland_at()])
				continue
			seen[bregion] = true
			_cover_log.maps += 1
			print("== COVER %s part %s from %s" % [_here(), bregion, _overland_at()])
			arrivals.append_array(await _cover_band(deadline))
			continue
		var mi: int = main._map_index
		var region := "%d:%d" % [mi, _region_id(main._pos)]
		if seen.has(region):
			print("   (part %s from %s: walked already)" % [region, main._pos])
			continue
		seen[region] = true
		_cover_parts_walked["part " + region] = true
		_cover_log.maps += 1
		print("== COVER map %d part %s (%s) from %s" % [main._maps[mi].id, region, _here(), main._pos])
		var found: Array = await _cover_map(deadline)
		arrivals.append_array(found)
		var base: Dictionary = main.dev_snapshot()
		# A rest here (the area's rest entries and its patrols). A menu the rest brings (a
		# patrol, the city watch) queues jobs that rest again (chat 15).
		_cover_snap = main.dev_snapshot()
		_cover_path = []
		_cover_resting = true
		if await _open_camp():
			await _rest_in_camp(1)
			await _settle()
			await _cover_recover(base, "resting")
		_cover_resting = false
		# Chat 16: saved and loaded here (the area's init with the area already up: 5:4's
		# 0x9B73, 8:29's well bottom, 6:28's 0xB6CD).
		main.dev_restore(base)
		await _settle()
		if main.dev_reload():
			print("   saved and loaded at %s" % main._pos)
			await _settle()
			await _cover_recover(base, "loading a game saved here")
		# Each edge of the map, once from each part: the next map of the area, or the way out.
		for side in 4:
			if Time.get_ticks_msec() >= deadline:
				break
			main.dev_restore(base)
			await _settle()
			var sq := _cover_edge(side)
			if sq.x < 0:
				continue
			await main._tour(sq)
			await _settle()
			if main._pos != sq or main._map_index != mi or _here() != _cover_area:
				continue
			await _cover_face(side)
			await main._press("up")
			await _settle()
			if await _cover_recover(base, "edge"):
				continue
			print("   edge %s of map %d: now %s map %d at %s" % ["NESW"[side], main._maps[mi].id, _here(), main._maps[main._map_index].id, main._pos])
			if _here() == _cover_area and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
				arrivals.append(main.dev_snapshot())
		main.dev_restore(base)
		await _settle()


## The graph's ways into the cover area. A square (stairs, a door, a gate) is a way of its own;
## a map edge leads in all along it, so edges are grouped by the part of the area's own map
## they arrive in (chat 15: 5:4's south edge reaches four parts, and the one try a side that
## chat 14 made landed in the one with no events). Edge arrivals whose entering side is walled
## on the area's map are left out. Each group's ways are tried in turn until one gets in; when
## none does, the group ends with a teleport to its first arrival square (a logged shortcut).
func _cover_ways_in() -> Array:
	_load_exits()
	var out: Array = []
	var groups := {}
	var amap: GeoMap = _area_map(_cover_area)
	for from in _exits:
		if from == _cover_area:
			continue
		for e in _exits[from]:
			if e.to != _cover_area:
				continue
			var k := "%s %d,%d" % [from, e.x, e.y]
			if e.entry == "move":
				var part := -1
				if e.has("ax") and amap != null:
					# The arrival square's side the party comes in by must be open.
					var back: int = (int(e.dir) + 2) % 4
					if amap.wall(int(e.ax), int(e.ay), back) > 0 and amap.door(int(e.ax), int(e.ay), back) == 0:
						continue
					part = _dungeon_part(_cover_area, Vector2i(int(e.ax), int(e.ay)))
				k = "%s %s part %d" % [from, "NESW"[int(e.dir)], part]
			if not groups.has(k):
				groups[k] = []
			if groups[k].size() < 4:
				var w: Dictionary = e.duplicate()
				w["from"] = from
				w["group"] = k
				groups[k].append(w)
	# Parts: one group per part of the area's map is enough (the first way in that reaches it).
	var by_part := {}
	for k in groups:
		var ws: Array = groups[k]
		var pk: String = k.get_slice(" part ", 1) if k.contains(" part ") else k
		for w in ws:
			w["group"] = "part " + pk if k.contains(" part ") else k
		if not by_part.has(pk):
			by_part[pk] = []
		by_part[pk].append_array(ws)
	for pk in by_part:
		var ws: Array = by_part[pk]
		out.append_array(ws)
		if ws[0].has("ax") and ws[0].entry == "move":
			var t: Dictionary = ws[0].duplicate()
			t["teleport"] = true
			out.append(t)
	return out.slice(0, 40)


## The area's own map (the GEO block with the script's number, when the script loads it).
func _area_map(area: String) -> GeoMap:
	var a := area.split(":")
	var ecl: EclScript = main._script(int(a[0]), int(a[1]))
	for m in main._maps:
		if String(m.file) == "GEO%s.DAX" % a[0] and int(m.id) == int(a[1]) and ecl != null and ecl.loads_map(int(a[1])):
			return m.map
	return null


var _cover_groups_in := {}     # chat 15: way-in groups (parts) already reached in this run


var _cover_going_in := false   # travelling round to a way in: walks outside the area go on
var _cover_done := {}     # "map:x,y" event squares visited in this coverage run
var _cover_probed := {}   # "map:event" walked to through walls already


## The part of the current map `at` is in: the lowest square index it reaches on foot.
func _region_id(at: Vector2i) -> int:
	var map: GeoMap = main._maps[main._map_index].map
	var seen := {at: true}
	var stack: Array[Vector2i] = [at]
	var low := at.y * 16 + at.x
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		low = mini(low, c.y * 16 + c.x)
		for d in 4:
			if map.wall(c.x, c.y, d) > 0 and map.door(c.x, c.y, d) == 0:
				continue
			var q: Vector2i = c + DungeonView.DELTA[d]
			if q.x < 0 or q.y < 0 or q.x >= GeoMap.SIZE or q.y >= GeoMap.SIZE or seen.has(q):
				continue
			seen[q] = true
			stack.append(q)
	return low


## The nearest square on `side`'s edge of the map with that side open (-1,-1: none reachable).
func _cover_edge(side: int) -> Vector2i:
	var map: GeoMap = main._maps[main._map_index].map
	var best := Vector2i(-1, -1)
	var best_len := 1 << 20
	for i in GeoMap.SIZE:
		var sq: Vector2i = [Vector2i(i, 0), Vector2i(15, i), Vector2i(i, 15), Vector2i(0, i)][side]
		if map.wall(sq.x, sq.y, side) != 0 and map.door(sq.x, sq.y, side) == 0:
			continue
		var path: Array = main._find_path(main._pos, sq)
		if (path.size() > 0 or main._pos == sq) and path.size() < best_len:
			best = sq
			best_len = path.size()
	return best


func _cover_face(d: int) -> void:
	for i in 4:
		if int(main._facing) == d:
			return
		await main._press("right")


## This map's events: the nearest square of each, reached by walking (whatever happens on the
## way plays), then a step from it in each direction, each from the same arrival. Returns
## snapshots of other maps of the area that events took the party to.
func _cover_map(deadline: int) -> Array:
	var mi: int = main._map_index
	var map: GeoMap = main._maps[mi].map
	var found: Array = []
	# Chat 16: every square of every event, not one square an event: scripts tell an event's
	# squares apart by position (6:1's 0x9A0F turns the square into one of 13 cases).
	var todo := {}       # square -> event
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var ev := map.flag(x, y) & 127
			if ev != 0:
				todo[Vector2i(x, y)] = ev
	var done := {}       # squares visited ("x,y")
	for k in _cover_done:
		if int(k.get_slice(":", 0)) == mi:
			done[k.get_slice(":", 1)] = true
	var arrival: Dictionary = main.dev_snapshot()
	var regions_found := {_region_id(main._pos): true}
	while Time.get_ticks_msec() < deadline:
		if _cover_fresh:
			main.dev_restore(arrival)
			await _settle()
		# The nearest event not yet visited.
		var best := -1
		var best_sq := Vector2i(-1, -1)
		var best_len := 1 << 20
		for sq: Vector2i in todo:
			if done.has("%d,%d" % [sq.x, sq.y]):
				continue
			var path: Array = main._find_path(main._pos, sq)
			var n := 0 if main._pos == sq else path.size()
			if (n > 0 or main._pos == sq) and n < best_len:
				best = todo[sq]
				best_sq = sq
				best_len = n
		var probe := false
		if best < 0:
			# No walking route: the nearest by straight distance, by trying the walls on the
			# way (a hedge to cut through, a wall the area's script lets the party pass).
			for sq: Vector2i in todo:
				if done.has("%d,%d" % [sq.x, sq.y]) or _cover_probed.has("%d:%d" % [mi, todo[sq]]):
					continue
				var n: int = absi(sq.x - main._pos.x) + absi(sq.y - main._pos.y)
				if n < best_len:
					best = todo[sq]
					best_sq = sq
					best_len = n
			probe = true
		if best < 0:
			break
		if probe:
			# Through the walls only once an event; arriving in another part may reach it.
			_cover_probed["%d:%d" % [mi, best]] = true
		else:
			done["%d,%d" % [best_sq.x, best_sq.y]] = true
			_cover_done["%d:%d,%d" % [mi, best_sq.x, best_sq.y]] = true
		# Steps the tour gave up on (a hedge answered NO by the menu-loop rule) are tried
		# again; only the steps that took the party away stay closed.
		main._refused = _cover_exits_used.duplicate()
		var pre: Dictionary = main.dev_snapshot()
		print("   cover: event %d at %s%s" % [best, best_sq, " (no route: trying the walls)" if probe else ""])
		_cover_stairs_for = ""
		if main._pos == best_sq:
			await _step_off()
			await _settle()
		_cover_target = best_sq
		if probe:
			await _cover_probe(best_sq)
		else:
			await main._tour(best_sq)
		await _settle()
		_cover_target = Vector2i(-1, -1)
		if await _cover_recover(pre, "walking to event %d" % best):
			continue
		if _here() != _cover_area or main._map_index != mi:
			if _here() == _cover_area and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
				found.append(main.dev_snapshot())
			print("   (event %d took the party to %s map %d; back, and not that way again: %s)" % [best, _here(),
				main._maps[main._map_index].id, _cover_last_step])
			# The step that left (stairs, a gate) is closed to the walks that follow; it was
			# taken once, and the four steps from its own square try it again on purpose.
			if _cover_last_step != "":
				_cover_exits_used[_cover_last_step] = true
			await _cover_first_search(pre, best_sq, best)
			main.dev_restore(pre)
			await _settle()
			continue
		if main._pos != best_sq:
			print("   (didn't reach %s: at %s)" % [best_sq, main._pos])
			_cover_new_part(regions_found, found, "walking to event %d" % best)
			continue
		done["%d,%d" % [best_sq.x, best_sq.y]] = true
		_cover_done["%d:%d,%d" % [mi, best_sq.x, best_sq.y]] = true
		_cover_log.squares += 1
		_cover_heal()
		var here: Dictionary = main.dev_snapshot()
		for d in 4:
			if Time.get_ticks_msec() >= deadline:
				break
			main.dev_restore(here)
			await _settle()
			await _cover_face(d)
			await main._press("up")
			await _settle()
			_cover_log.tries += 1
			if await _cover_recover(here, "stepping %s from event %d" % ["NESW"[d], best]):
				continue
			if _here() == _cover_area and main._map_index == mi:
				_cover_new_part(regions_found, found, "stepping %s from event %d" % ["NESW"[d], best])
			if _here() == _cover_area and main._map_index != mi and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
				found.append(main.dev_snapshot())
		# Chat 16: LOOK facing each way. LOOK runs the area's search entry from where the party
		# faces, and scripts test the wall ahead there (6:1's slave pen: the boy and the
		# merchant come only to a party looking at the pen, 0xC04E = 8).
		for d in 4:
			if Time.get_ticks_msec() >= deadline:
				break
			main.dev_restore(here)
			await _settle()
			await _cover_face(d)
			# Menus LOOK brings queue jobs that look again (as a step's do with the step).
			_cover_snap = main.dev_snapshot()
			_cover_path = []
			_cover_dir = d
			_cover_looking = true
			await main._press("l")
			await _settle()
			_cover_looking = false
			_cover_snap = {}
			_cover_log.tries += 1
			await _cover_recover(here, "looking %s at event %d" % ["NESW"[d], best])
		# And once more onto the square, now that its event has run (the "already done" side).
		# Chat 15: three times, the script's dice rerolled each time (a restore brings the same
		# dice back, so a RANDOM in the event would always come out the same: New Phlan's
		# pickpocket, the gambling wheel).
		# Chat 16: from each open side in turn (at least three times), so the party arrives
		# facing each way: scripts test the wall ahead (6:1's slave pen: 0xC04E = 8) and the facing.
		var sides: Array = []
		for dd in DungeonView.DELTA:
			var nb: Vector2i = best_sq + dd
			if nb.x >= 0 and nb.y >= 0 and nb.x < GeoMap.SIZE and nb.y < GeoMap.SIZE \
					and main._find_path(best_sq, nb).size() == 2:
				sides.append(nb)
		for k in maxi(3, sides.size()):
			if Time.get_ticks_msec() >= deadline:
				break
			main.dev_restore(here)
			await _settle()
			if k > 0:
				main._vm._rng.seed = randi() ^ Time.get_ticks_usec()
			if sides.is_empty():
				await _step_off()
			else:
				await main._tour(sides[k % sides.size()])
				await _settle()
			_cover_target = best_sq
			await main._tour(best_sq)
			_cover_target = Vector2i(-1, -1)
			await _settle()
			await _cover_recover(here, "coming back to event %d" % best)
		# And once with SEARCH on (scripts test 0x6DCA: Valjevo's loose stone, hidden treasure).
		# Chat 15: four times in a row, without going back between (what a search found the
		# first time is "already found" the next: 5:4's reports), the dice rerolled each time
		# (the reports are a roll of 10).
		if Time.get_ticks_msec() < deadline:
			main.dev_restore(here)
			await _settle()
			for k in 4:
				if Time.get_ticks_msec() >= deadline or _here() != _cover_area or main._map_index != mi:
					break
				main._vm._rng.seed = randi() ^ Time.get_ticks_usec()
				main._searching = true
				main._vm.write_byte(main.SEARCH_FLAG, 1)
				await _step_off()
				_cover_target = best_sq
				await main._tour(best_sq)
				_cover_target = Vector2i(-1, -1)
				await _settle()
				main._searching = false
				main._vm.write_byte(main.SEARCH_FLAG, 0)
				if await _cover_recover(here, "searching at event %d" % best):
					break
		await _cover_first_search(pre, best_sq, best)
		main.dev_restore(here)
		await _settle()
	return found


## Chat 17: the first arrival on an event square, again with SEARCH on. Scripts take another way
## when the party searches the first time it comes (7:22's rocks room: searching, "A STRANGE
## TINGLE" and THROW A ROCK; not searching, a flash takes the party to 7:23, and the square is
## done after that, so the walk's later searches never saw the other side).
func _cover_first_search(pre: Dictionary, sq: Vector2i, ev: int) -> void:
	main.dev_restore(pre)
	await _settle()
	main._vm._rng.seed = randi() ^ Time.get_ticks_usec()
	main._searching = true
	main._vm.write_byte(main.SEARCH_FLAG, 1)
	if main._pos == sq:
		await _step_off()
	_cover_target = sq
	await main._tour(sq)
	_cover_target = Vector2i(-1, -1)
	await _settle()
	main._searching = false
	main._vm.write_byte(main.SEARCH_FLAG, 0)
	_cover_log.tries += 1
	await _cover_recover(pre, "searching on the first arrival at event %d" % ev)


## Chat 15: a wilderness band's coverage walk. The band's script works by square (its sites,
## gates and the river's edges are tables of coordinates, not event numbers), so every square of
## the part the party is in is stepped on, the nearest not yet visited first, a step at a time.
## A step that takes the party out of the band (a gate, a site's own area) is undone and that
## square isn't walked through again; one the game refuses (a menu answered no) is left too.
## Each square is left in all four directions once (a site's "already here" side, and the steps
## off it).
func _cover_band(deadline: int) -> Array:
	var found: Array = []
	var area := _here()
	var ov = main._vm.overland
	var bx: int = ov.band_x(main._vm.overland_band)
	var part := _part_of(area, _overland_at())
	var todo := {}
	for y in OverlandMap.HEIGHT:
		for x in 16:
			if _part_of(area, Vector2i(x, y)) == part:
				todo[Vector2i(x, y)] = true
	var seen := {}
	var blocked := {}
	var steps := 0
	var left := 0
	while Time.get_ticks_msec() < deadline and not _wiped():
		if _here() != area or not main._vm.on_overland:
			break
		var at := _overland_at()
		seen[at] = true
		var path := _band_path(ov, bx, at, todo, seen, blocked)
		if path.size() < 2:
			break
		var to: Vector2i = path[1]
		var d := DungeonView.DELTA.find(to - at)
		var pre: Dictionary = main.dev_snapshot()
		var msg_before := String(main._message.text)
		await _overland_step(d)
		await _settle()
		steps += 1
		if await _cover_recover(pre, "band step onto %s" % to):
			seen[to] = true
			blocked[to] = true
			continue
		if _here() == area and not main._vm.on_overland and main._vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
			# A map the band's own script loads (7:26's lizard men's village): walked later
			# like any map of the area.
			print("   (band: the step onto %s opens map %d of %s at %s)" % [to, main._maps[main._map_index].id, area, main._pos])
			found.append(main.dev_snapshot())
			seen[to] = true
			blocked[to] = true
			main.dev_restore(pre)
			await _settle()
			continue
		if _here() != area or not main._vm.on_overland:
			print("   (band: the step onto %s led to %s; back, and not that way again)" % [to, _here()])
			seen[to] = true
			blocked[to] = true
			left += 1
			main.dev_restore(pre)
			await _settle()
			continue
		if _overland_at() != to:
			seen[to] = true
			if _overland_at() == at:
				blocked[to] = true
			continue
		var said := String(main._message.text)
		if said != "" and said != msg_before:
			print("   band %s: %s" % [to, said.left(90)])
		_cover_heal()
	# A rest out here (the band's rest entries and its night encounters).
	if _here() == area and main._vm.on_overland and not _wiped():
		var base: Dictionary = main.dev_snapshot()
		_cover_snap = base
		_cover_path = []
		_cover_resting = true
		if await _open_camp():
			await _rest_in_camp(1)
			await _settle()
			await _cover_recover(base, "resting")
		_cover_resting = false
	_cover_log.squares += seen.size()
	_cover_log.tries += steps
	print("   band walk: %d of %d squares, %d steps, %d ways out, %d maps found" % [seen.size(), todo.size(), steps, left, found.size()])
	return found


## The shortest way over the band from `at` to the nearest square of `todo` not in `seen`,
## through squares not `blocked` (water stops; the poisoned river until 0x4AA2).
func _band_path(ov, bx: int, at: Vector2i, todo: Dictionary, seen: Dictionary, blocked: Dictionary) -> Array:
	var came := {at: at}
	var queue: Array[Vector2i] = [at]
	var goal := Vector2i(-1, -1)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur != at and todo.has(cur) and not seen.has(cur):
			goal = cur
			break
		if cur != at and blocked.has(cur):
			continue
		for d in 4:
			var nxt: Vector2i = cur + DungeonView.DELTA[d]
			if nxt.x < 0 or nxt.x > 15 or nxt.y < 0 or nxt.y >= OverlandMap.HEIGHT or came.has(nxt):
				continue
			if not _walkable(ov, bx, nxt):
				continue
			if blocked.has(nxt) and seen.has(nxt):
				continue
			came[nxt] = cur
			queue.append(nxt)
	if goal.x < 0:
		return []
	var path: Array = []
	var p := goal
	while p != at:
		path.push_front(p)
		p = came[p]
	path.push_front(at)
	return path


## Chat 15: a step that puts the party in another part of the same map (2:9's tower stairs
## move it within map 9) is a new arrival, walked later like any other.
func _cover_new_part(regions: Dictionary, found: Array, how: String) -> void:
	if main._vm.state not in [EclVM.State.IDLE, EclVM.State.DONE] or _wiped():
		return
	var r := _region_id(main._pos)
	if regions.has(r):
		return
	regions[r] = true
	print("   (%s put the party in another part of the map, at %s)" % [how, main._pos])
	found.append(main.dev_snapshot())


## Walks toward `goal` through walls where the game allows it: the cheapest way counting each
## wall as 25 steps, trying each step; a step the game refuses closes that side and the way is
## worked out again.
func _cover_probe(goal: Vector2i) -> void:
	var refused := {}
	var mi: int = main._map_index
	for n in 150:
		if main._pos == goal or _here() != _cover_area or main._map_index != mi or _wiped():
			return
		var d := _probe_step(main._pos, goal, refused)
		if d < 0:
			print("   (no way at all to %s)" % goal)
			return
		var before: Vector2i = main._pos
		main._menu_seen.clear()      # each wall's question is new (a hedge on each side)
		await _cover_face(d)
		await main._press("up")
		await _settle()
		if main._pos == before:
			refused["%d,%d,%d" % [before.x, before.y, d]] = true
		elif not _wiped():
			_cover_heal()


## The first step's direction on the cheapest way from `a` to `b` (walls cost 25; refused
## sides are closed), or -1.
func _probe_step(a: Vector2i, b: Vector2i, refused: Dictionary) -> int:
	var map: GeoMap = main._maps[main._map_index].map
	var dist := {b: 0}
	var open := [b]
	# Costs from the goal back, so the answer is the neighbour of `a` with the least.
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if int(dist[open[i]]) < int(dist[open[bi]]):
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		for d in 4:
			var p: Vector2i = c - DungeonView.DELTA[d]       # a square whose step d reaches c
			if p.x < 0 or p.y < 0 or p.x >= GeoMap.SIZE or p.y >= GeoMap.SIZE:
				continue
			if refused.has("%d,%d,%d" % [p.x, p.y, d]) or _cover_exits_used.has("%d:%d,%d,%d" % [main._map_index, p.x, p.y, d]):
				continue
			var cost := 1 if map.wall(p.x, p.y, d) == 0 or map.door(p.x, p.y, d) != 0 else 25
			var nd: int = int(dist[c]) + cost
			if not dist.has(p) or nd < int(dist[p]):
				dist[p] = nd
				open.append(p)
	var best := -1
	var best_cost := 1 << 20
	for d in 4:
		var q: Vector2i = a + DungeonView.DELTA[d]
		if dist.has(q) and not refused.has("%d,%d,%d" % [a.x, a.y, d]) and not _cover_exits_used.has("%d:%d,%d,%d" % [main._map_index, a.x, a.y, d]):
			var cost: int = int(dist[q]) + (1 if map.wall(a.x, a.y, d) == 0 or map.door(a.x, a.y, d) != 0 else 25)
			if cost < best_cost:
				best_cost = cost
				best = d
	return best

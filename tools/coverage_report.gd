extends SceneTree
## Developer tool (M6): how much of the game's event scripts has run, from the file the engine
## writes with --coverage=<file> (ScriptCoverage), against what each block's static decode
## can reach (EclScript._follow: the five entry points, every GOTO, GOSUB, ON_GOTO target and
## both sides of every IF).
##
## godot --headless --path <project> --script res://tools/coverage_report.gd -- \
##     --game-path=<POOLRAD> --coverage=<file> [--areas=1:18,7:17] [--missed=7:17] [--critical=5:5]
##
## Per block: instructions run, branch outcomes taken (both sides of each IF, each ON_GOTO /
## ON_GOSUB target), menu choices made (each item of each menu, the encounter menu's five,
## PARLAY's five), flag writes run (instructions writing ECL 0x4A00-0x4AFF, the area and
## quest bytes), and "extra" (instructions that ran but the decoder never reached: a bug).
## Branch outcomes and choices no state can take ("dead": _dead) are left out of the counts.
## --missed=<block> lists that block's branch outcomes and choices never taken, with the
## instruction text, for working out why.
## --critical=<block> (chat 14, the per-area done criteria of 2026-11-13): the story-critical
## instructions and which have run: ways in and out (NEW_ECL, LOAD_AREA_MAP, CALL 0xC01E, the
## step through the map's edge), set fights (COMBAT) and quest flags (writes to 0x4A20-0x4AFF,
## the bytes that carry over from area to area: 0x4A00-0x4A1F are per visit), with the ones not
## run listed.

const FLAGS_LO := 0x4A00
const FLAGS_HI := 0x4AFF
const WRITES := {"WRITE_MEM": 1, "ADD": 2, "SUBTRACT": 2, "MULTIPLY": 2, "DIVIDE": 2, "AND": 2,
	"OR": 2, "RANDOM": 1, "RANDOM0": 1, "COPY_MEM": 1, "PARTY_STRENGTH": 0}


func _init() -> void:
	var game_path := ""
	var cov_path := ""
	var only: PackedStringArray = []
	var missed := ""
	var critical := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-path="):
			game_path = arg.trim_prefix("--game-path=")
		elif arg.begins_with("--coverage="):
			cov_path = arg.trim_prefix("--coverage=")
		elif arg.begins_with("--areas="):
			only = arg.trim_prefix("--areas=").split(",")
		elif arg.begins_with("--missed="):
			missed = arg.trim_prefix("--missed=")
		elif arg.begins_with("--critical="):
			critical = arg.trim_prefix("--critical=")
	if game_path == "":
		game_path = GameData.find_game_path()
	_settable = _settable_bits(game_path)
	var cov := ScriptCoverage.new(cov_path)
	var totals := [0, 0, 0, 0, 0, 0, 0, 0]   # ins run/all, branches, choices, flags
	var entered := 0
	var all_blocks := 0
	var never: PackedStringArray = []
	print("%-6s %-26s %14s %14s %12s %12s %s" % ["block", "area", "instructions", "branches", "choices", "flag writes", "extra"])
	for n in range(1, 9):
		var dax := DaxFile.open(game_path.path_join("ECL%d.DAX" % n))
		if dax == null:
			continue
		for id in dax.ids():
			var key := "%d:%d" % [n, id]
			if not only.is_empty() and not key in only:
				continue
			all_blocks += 1
			var block: PackedByteArray = dax.blocks[id]
			var ecl := EclScript.decode(block)
			var c: Dictionary = cov.blocks.get(key, {"ins": {}, "br": {}, "extra": {}})
			if c.ins.is_empty():
				never.append(key)
			else:
				entered += 1
			var r := _measure(ecl, c)
			var extra := 0      # ran, but the decoder doesn't reach it (judged now, not when recorded)
			for o in c.ins:
				if not ecl.instructions.has(int(o)):
					extra += 1
			for i in 8:
				totals[i] += r.counts[i]
			if not c.ins.is_empty() or not only.is_empty():
				var strings := GoldBoxText.find_strings(block)
				var name: String = strings[0].text.left(26) if not strings.is_empty() else ""
				print("%-6s %-26s %14s %14s %12s %12s %s" % [key, name.replace("\n", " "),
					_pct(r.counts[0], r.counts[1]), _pct(r.counts[2], r.counts[3]),
					_pct(r.counts[4], r.counts[5]), _pct(r.counts[6], r.counts[7]),
					(str(extra) if extra > 0 else "") + ("  dead %d" % r.dead if r.dead > 0 else "")])
			if key == missed:
				for line in r.missed:
					print("   missed ", line)
			if key == critical:
				_critical(ecl, c)
	print("\nOverall: blocks entered %d of %d; instructions %s; branches %s; choices %s; flag writes %s" % [
		entered, all_blocks, _pct(totals[0], totals[1]), _pct(totals[2], totals[3]),
		_pct(totals[4], totals[5]), _pct(totals[6], totals[7])])
	if not never.is_empty():
		print("Never entered: ", ", ".join(never))
	quit()


static func _pct(a: int, b: int) -> String:
	if b == 0:
		return "-"
	return "%d/%d %3d%%" % [a, b, int(floor(100.0 * a / b))]


## counts: instructions run/all, branch outcomes taken/all, choices made/all, flag writes run/all.
func _measure(ecl: EclScript, c: Dictionary) -> Dictionary:
	var counts := [0, 0, 0, 0, 0, 0, 0, 0]
	var missed: PackedStringArray = []
	var dead := _dead(ecl)
	var dead_n := 0
	for off in ecl.offsets():
		var ins: Dictionary = ecl.instructions[off]
		var op: String = ins.op
		var ran: bool = c.ins.has(off)
		counts[1] += 1
		if ran:
			counts[0] += 1
		var outcomes: Array = []
		var choices: Array = []
		if op.begins_with("IF_"):
			outcomes = ["T", "F"]
		elif op == "ON_GOTO" or op == "ON_GOSUB":
			for i in ins.args.size() - 2:
				outcomes.append(str(i))
		elif op == "MENU_HORIZONTAL" and ins.args.size() - 2 > 1:
			for i in ins.args.size() - 2:
				choices.append("c%d" % i)
		elif op == "MENU_VERTICAL" and ins.args.size() - 3 > 1:
			for i in ins.args.size() - 3:
				choices.append("c%d" % i)
		elif op == "ENCOUNTER_MENU" or op == "PARLAY":
			for i in 5:
				choices.append("c%d" % i)
		for o in outcomes:
			if dead.has("%d:%s" % [off, o]):
				dead_n += 1
				continue
			counts[3] += 1
			if c.br.has("%d:%s" % [off, o]):
				counts[2] += 1
			else:
				missed.append("%04X %s -> %s" % [off + EclScript.BASE, op, o])
		for o in choices:
			if dead.has("%d:%s" % [off, o]):
				dead_n += 1
				continue
			counts[5] += 1
			if c.br.has("%d:%s" % [off, o]):
				counts[4] += 1
			else:
				missed.append("%04X %s choice %s %s" % [off + EclScript.BASE, op, o.trim_prefix("c"), _choice_name(ins, op, int(o.trim_prefix("c")))])
		if WRITES.has(op) and int(WRITES[op]) < ins.args.size():
			var dest: Dictionary = ins.args[int(WRITES[op])]
			if int(dest.type) in [0x01, 0x03, 0x05, 0x81] and int(dest.value) >= FLAGS_LO and int(dest.value) <= FLAGS_HI:
				counts[7] += 1
				if ran:
					counts[6] += 1
	return {"counts": counts, "missed": missed, "dead": dead_n}


## Chat 14: branch outcomes and choices no game state can take (left out of "reachable", as the
## done criteria of 2026-11-13 say), worked out from the encounter rules (EclVM._encounter_choice):
## an ENCOUNTER_MENU's five reactions decide which outcomes its choices can give (0 the
## monsters leave: only a reaction 2; 1 a fight; 2 the party gets away: FLEE; 3 talk: PARLAY,
## or WAIT/ADVANCE where the reaction is 4); an ON_GOTO/ON_GOSUB right after it on the same
## variable can't take an outcome no choice gives. And where the menu's distance is 0, ADVANCE
## (choice 3) is never offered (PARLAY stands in its place).
func _dead(ecl: EclScript) -> Dictionary:
	var out := {}
	var offs: Array = ecl.offsets()
	_dead_never_set(ecl, offs, out)
	for i in offs.size():
		var ins: Dictionary = ecl.instructions[offs[i]]
		if ins.op != "ENCOUNTER_MENU" or ins.args.size() < 9:
			continue
		var lit := true
		for k in [1, 4, 5, 6, 7, 8]:
			if int(ins.args[k].type) != 0:
				lit = false
		if not lit:
			continue
		var at_zero := int(ins.args[1].value) == 0
		if at_zero:
			out["%d:c3" % offs[i]] = true
		var can := {}
		for ch in 5:
			if ch == 3 and at_zero:
				continue
			match int(ins.args[4 + ch].value):
				0:
					can[1] = true
					if ch == 2:
						can[2] = true
				1, 3:
					if ch == 0:
						can[1] = true
					elif ch == 2:
						can[2] = true
					elif ch == 4:
						can[3] = true
				2:
					can[0] = true
					if ch == 0:
						can[1] = true
				4:
					if ch == 0:
						can[1] = true
					elif ch == 2:
						can[2] = true
					else:
						can[3] = true
		if i + 1 >= offs.size():
			continue
		var nxt: Dictionary = ecl.instructions[offs[i + 1]]
		if not nxt.op in ["ON_GOTO", "ON_GOSUB"] or nxt.args.is_empty():
			continue
		var dest: Dictionary = ins.args[3]
		if int(nxt.args[0].type) != int(dest.type) or int(nxt.args[0].value) != int(dest.value):
			continue
		for k in nxt.args.size() - 2:
			if not can.has(k):
				out["%d:%d" % [offs[i + 1], k]] = true
	return out


## Chat 15: the bits of each flag byte (0x4A00-0x4AFF) any script of any data set can set:
## OR with a constant sets those bits, AND with the byte itself sets none, WRITE_MEM of a
## constant sets its bits, anything else (a copy, a sum, a value from elsewhere) any bit.
var _settable := {}


static func _is_mem(a: Dictionary) -> bool:
	return int(a.type) in [0x01, 0x02, 0x03, 0x05]


static func _is_const(a: Dictionary) -> bool:
	return int(a.type) in [0x00, 0x04]


func _settable_bits(game_path: String) -> Dictionary:
	var bits := {}
	for n in range(1, 9):
		var dax := DaxFile.open(game_path.path_join("ECL%d.DAX" % n))
		if dax == null:
			continue
		for id in dax.ids():
			var ecl := EclScript.decode(dax.blocks[id])
			for off in ecl.offsets():
				var ins: Dictionary = ecl.instructions[off]
				var op: String = ins.op
				if not WRITES.has(op):
					continue
				var dests: Array = [int(WRITES[op])]
				if op == "COPY_MEM":
					dests = [1, 2]
				for di in dests:
					if di >= ins.args.size():
						continue
					var d: Dictionary = ins.args[di]
					if not (int(d.type) in [0x01, 0x02, 0x03, 0x05, 0x81]):
						continue
					var x := int(d.value)
					if x < FLAGS_LO or x > FLAGS_HI:
						continue
					var set := 0xFF
					var a: Array = ins.args
					if op == "WRITE_MEM" and _is_const(a[0]):
						set = int(a[0].value) & 0xFF
					elif op == "OR" and a.size() >= 2:
						set = 0
						for k in 2:
							if _is_const(a[k]):
								set |= int(a[k].value) & 0xFF
							elif not (_is_mem(a[k]) and int(a[k].value) == x):
								set = 0xFF
					elif op == "AND" and a.size() >= 2:
						if (_is_mem(a[0]) and int(a[0].value) == x) or (_is_mem(a[1]) and int(a[1].value) == x):
							set = 0
						elif _is_const(a[0]):
							set = int(a[0].value) & 0xFF
						elif _is_const(a[1]):
							set = int(a[1].value) & 0xFF
					bits[x] = int(bits.get(x, 0)) | set
	return bits


## Chat 15: a test of flag bits no script ever sets (5:5's 0x9C93 tests 0x4A67 bit 7, which
## on-move clears and nothing sets): AND [x], m followed by an IF, or COMPARE [x], 0 with x
## never set, always sees 0, so the IF's other outcome is dead.
func _dead_never_set(ecl: EclScript, offs: Array, out: Dictionary) -> void:
	for i in offs.size() - 1:
		var ins: Dictionary = ecl.instructions[offs[i]]
		var nxt: Dictionary = ecl.instructions[offs[i + 1]]
		if not String(nxt.op).begins_with("IF_") or ins.args.size() < 2:
			continue
		var zero := false
		var a: Array = ins.args
		if ins.op == "AND":
			for k in 2:
				var o: Dictionary = a[1 - k]
				if _is_mem(a[k]) and _is_const(o) and int(a[k].value) >= FLAGS_LO and int(a[k].value) <= FLAGS_HI:
					if int(_settable.get(int(a[k].value), 0)) & int(o.value) == 0:
						zero = true
		elif ins.op == "COMPARE":
			for k in 2:
				var o: Dictionary = a[1 - k]
				if _is_mem(a[k]) and _is_const(o) and int(o.value) == 0 and int(a[k].value) >= FLAGS_LO \
						and int(a[k].value) <= FLAGS_HI and int(_settable.get(int(a[k].value), 0)) == 0:
					zero = true
		if not zero:
			continue
		# The test always sees 0 (equal): EQ, LE and GE hold; NE, LT and GT don't.
		var holds: bool = nxt.op in ["IF_EQ", "IF_LE", "IF_GE"]
		out["%d:%s" % [offs[i + 1], "F" if holds else "T"]] = true


static func _choice_name(ins: Dictionary, op: String, i: int) -> String:
	match op:
		"MENU_HORIZONTAL":
			return str(ins.args[i + 2].value)
		"MENU_VERTICAL":
			return str(ins.args[i + 3].value)
		"ENCOUNTER_MENU":
			return ["COMBAT", "WAIT", "FLEE", "ADVANCE", "PARLAY"][i]
		"PARLAY":
			return ["HAUGHTY", "SLY", "NICE", "MEEK", "ABUSIVE"][i]
	return ""


## The story-critical instructions of a block (--critical): counts per kind and what hasn't run.
func _critical(ecl: EclScript, c: Dictionary) -> void:
	var kinds := {"way in/out": [0, 0], "set fight": [0, 0], "quest flag": [0, 0]}
	var left: PackedStringArray = []
	for off in ecl.offsets():
		var ins: Dictionary = ecl.instructions[off]
		var op: String = ins.op
		var kind := ""
		if op in ["NEW_ECL", "LOAD_AREA_MAP"] or (op == "CALL" and ins.args.size() > 0 and int(ins.args[0].value) == 0xC01E):
			kind = "way in/out"
		elif op == "COMBAT":
			kind = "set fight"
		elif WRITES.has(op) and int(WRITES[op]) < ins.args.size():
			var dest: Dictionary = ins.args[int(WRITES[op])]
			if int(dest.type) in [0x01, 0x03, 0x05, 0x81] and int(dest.value) >= 0x4A20 and int(dest.value) <= FLAGS_HI:
				kind = "quest flag"
		if kind == "":
			continue
		kinds[kind][1] += 1
		if c.ins.has(off):
			kinds[kind][0] += 1
		else:
			var args: PackedStringArray = []
			for a in ins.args:
				args.append(EclScript._arg_text(a))
			left.append("%04X %-11s %s %s" % [off + EclScript.BASE, kind, op, ", ".join(args)])
	var parts: PackedStringArray = []
	for k in kinds:
		parts.append("%s %d/%d" % [k, kinds[k][0], kinds[k][1]])
	print("   critical: ", "; ".join(parts))
	for l in left:
		print("   critical not run: ", l)

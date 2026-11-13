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
					str(extra) if extra > 0 else ""])
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
			counts[3] += 1
			if c.br.has("%d:%s" % [off, o]):
				counts[2] += 1
			else:
				missed.append("%04X %s -> %s" % [off + EclScript.BASE, op, o])
		for o in choices:
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
	return {"counts": counts, "missed": missed}


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

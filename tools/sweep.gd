extends SceneTree
## Developer tool: runs every area's event scripts through our VM and reports what the
## engine can't do yet. For each ECL block: the init, then every square that has an event,
## from every facing, the on-move and on-step entries; every menu choice is followed (up to a
## depth), fights are taken as won, shops and other screens closed at once.
##
## godot --headless --path <project> --script res://tools/sweep.gd -- --game-path=<POOLRAD>
##     [--only=<set>:<block>] [--depth=3]
## Prints one line per finding (unhandled opcode, unknown CALL, note, script error), with
## where it happened, then a summary per area: areas reached (NEW_ECL), PROGRAMs, CALLs.

var game_path := ""
var depth_limit := 3
var findings := {}      # text -> [count, first place]
var reached := {}       # "set:block" -> {"new_ecl": {}, "program": {}, "calls": {}}
var budget := 0
var exits: PackedStringArray = []   # where each square leads (NEW_ECL), for the playthrough bot


func _init() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-path="):
			game_path = arg.trim_prefix("--game-path=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--depth="):
			depth_limit = int(arg.trim_prefix("--depth="))
	var party: Array = []
	for i in range(1, 7):
		var m := PartyMember.load_files(game_path.path_join("CHRDATA%d.SAV" % i), game_path.path_join("CHRDATA%d.ITM" % i))
		if m != null:
			m.recalculate(ItemTypes.load_file(game_path))
			party.append(m)
	for n in range(1, 9):
		var ecl := DaxFile.open(game_path.path_join("ECL%d.DAX" % n))
		if ecl == null:
			continue
		for id in ecl.ids():
			if only != "" and only != "%d:%d" % [n, id]:
				continue
			_sweep_area(n, id, ecl.blocks[id], party)
	var keys := findings.keys()
	keys.sort()
	for k in keys:
		print("%-60s x%-4d first at %s" % [k, findings[k][0], findings[k][1]])
	for e in exits:
		print(e)
	print("--- areas")
	var areas := reached.keys()
	areas.sort()
	for a in areas:
		var r: Dictionary = reached[a]
		print("%s  new_ecl %s  program %s  calls %s" % [a, str(r.new_ecl.keys()), str(r.program.keys()), str(r.calls.keys())])
	quit()


func _sweep_area(set_no: int, block_id: int, block: PackedByteArray, party: Array) -> void:
	var where := "%d:%d" % [set_no, block_id]
	reached[where] = {"new_ecl": {}, "program": {}, "calls": {}}
	var vm := EclVM.new()
	vm.party = party
	vm.tables = ClassTables.shared(game_path)
	vm.load_script(block)
	GameClock.set_time(vm, 0, 10)
	vm.area_map = []
	vm.start(4)
	_follow(vm, where, "init", 0)
	# The area's map: from LOAD_AREA_MAP in the init (or the block id).
	var map_id: int = vm.area_map[0] if not vm.area_map.is_empty() and vm.area_map[0] < 127 else block_id
	var map: GeoMap = null
	var geo := DaxFile.open(game_path.path_join("GEO%d.DAX" % set_no))
	if geo != null and geo.blocks.has(map_id):
		map = GeoMap.decode(geo.blocks[map_id])
	var base := vm.mem.duplicate()
	var events := {}
	if map != null:
		for y in GeoMap.SIZE:
			for x in GeoMap.SIZE:
				var ev := map.flag(x, y) & 127
				var edge := x == 0 or y == 0 or x == GeoMap.SIZE - 1 or y == GeoMap.SIZE - 1
				if not events.has(ev):
					events[ev] = Vector2i(x, y)
				elif edge:
					events[1000 + y * 16 + x] = Vector2i(x, y)
	else:
		events[0] = Vector2i(8, 8)
	for ev in events:
		var p: Vector2i = events[ev]
		for d in 4:
			var nxt: Vector2i = p + DungeonView.DELTA[d]
			var off := nxt.x < 0 or nxt.y < 0 or nxt.x >= GeoMap.SIZE or nxt.y >= GeoMap.SIZE
			for entry in [0, 1]:
				vm.mem = base.duplicate()
				vm.write_byte(EclVM.PARTY_X, p.x)
				vm.write_byte(EclVM.PARTY_Y, p.y)
				vm.write_byte(EclVM.PARTY_DIR, d)
				vm.write_byte(EclVM.SQUARE_INFO, map.flag(p.x, p.y) if map != null else 0)
				vm.write_byte(EclVM.WALL_AHEAD, map.wall(p.x, p.y, d) if map != null else 0)
				vm.write_byte(EclVM.LEAVING_MAP, 1 if off and entry == 0 else 0)
				vm.clear_output()
				vm.start(entry)
				_follow(vm, where, "ev%d %d,%d %s %s" % [ev % 1000, p.x, p.y, "NESW"[d], ["move", "step"][entry]], 0)
	# Rest and rest-interrupted.
	for entry in [2, 3]:
		vm.mem = base.duplicate()
		vm.clear_output()
		vm.start(entry)
		_follow(vm, where, ["", "", "rest", "rest interrupted"][entry], 0)


func _record(vm: EclVM, where: String, place: String) -> void:
	for n in vm.notes:
		var key := "note: " + n
		if n.begins_with("call "):
			reached[where].calls[n.trim_prefix("call ")] = true
		if not findings.has(key):
			findings[key] = [0, where + " " + place]
		findings[key][0] += 1
	vm.notes = []
	if vm.state == EclVM.State.ERROR:
		var key := "error: " + vm.error
		if not findings.has(key):
			findings[key] = [0, where + " " + place]
		findings[key][0] += 1


## Runs the VM on from its current pause, following every menu choice.
func _follow(vm: EclVM, where: String, place: String, depth: int) -> void:
	for guard in 60:
		_record(vm, where, place)
		match vm.state:
			EclVM.State.WAIT:
				vm.resume()
			EclVM.State.COMBAT:
				vm.end_combat(0)
			EclVM.State.SHOP:
				vm.close_shop()
			EclVM.State.TEMPLE:
				vm.close_temple()
			EclVM.State.INPUT:
				vm.answer_input("")
			EclVM.State.PROGRAM:
				reached[where].program[vm.program] = true
				vm.close_program()
			EclVM.State.NEW_ECL:
				reached[where].new_ecl["%d:%d" % [vm.read_byte(EclVM.FILE_SET), vm.new_ecl]] = true
				exits.append("EXIT %s %s -> %d:%d at %d,%d,%s" % [where, place, vm.read_byte(EclVM.FILE_SET),
					vm.new_ecl, vm.read_byte(EclVM.PARTY_X) & 15, vm.read_byte(EclVM.PARTY_Y) & 15,
					"NESW"[vm.read_byte(EclVM.PARTY_DIR) & 3]])
				return
			EclVM.State.MENU:
				if depth >= depth_limit:
					return
				var n := vm.menu.size()
				var snap := _snapshot(vm)
				for i in maxi(n, 1):
					_restore(vm, snap)
					vm.choose(i)
					_follow(vm, where, place + " >%d" % (i + 1), depth + 1)
				return
			_:
				return


func _snapshot(vm: EclVM) -> Dictionary:
	return {"mem": vm.mem.duplicate(), "pc": vm.pc, "stack": vm.stack.duplicate(), "compare": vm.compare,
		"state": vm.state, "menu": vm.menu.duplicate(), "kind": vm._menu_kind, "enc": vm._enc.duplicate(true),
		"dest": vm._menu_dest.duplicate(), "parlay": vm._parlay_values.duplicate(), "dist": vm.encounter_distance,
		"adv": vm.encounter_advances, "selected": vm.selected}


func _restore(vm: EclVM, s: Dictionary) -> void:
	vm.mem = s.mem.duplicate()
	vm.pc = s.pc
	vm.stack.assign(s.stack)
	vm.compare = s.compare
	vm.state = s.state
	vm.menu = s.menu.duplicate()
	vm._menu_kind = s.kind
	vm._enc = s.enc.duplicate(true)
	vm._menu_dest = s.dest.duplicate()
	vm._parlay_values = s.parlay.duplicate()
	vm.encounter_distance = s.dist
	vm.encounter_advances = s.adv
	vm.selected = s.selected

extends Control
## M1/M2 data browser.
##   Tab          : pictures -> maps -> walk -> pictures
##   Pictures     : Left/Right picture, Up/Down file
##   Maps         : Left/Right map, Enter to walk the map
##   Walk         : Up forward, Down back, Left/Right turn,
##                  O slot outlines, C capture (PNG + slot report to captures/), G go to "x y dir",
##                  E write the area's event script listing to captures/, N day/night,
##                  1-9 choose a menu item, Enter continue,
##                  V party character sheets, M monster sheets (every MONnCHA block),
##                  B test battle here (battlefield and placement; the area's set battles, PgUp/PgDn)
## Starts on the title screen.

enum Mode { PICTURES, MAPS, WALK }

@onready var _picture: TextureRect = $Picture
@onready var _map_view: MapView = $MapView
@onready var _status: Label = $Status

var _game_path := ""
var _mode := Mode.PICTURES
var _pictures: Array = []   # [{file, id, pic}]
var _maps: Array = []       # [{file, id, map}]
var _area_text := {}        # block id -> first event text in that area's ECL block
var _pic_index := 0
var _map_index := 0

# Walk mode state
var _dungeon := DungeonView.new()
var _walls: WallSet
var _walls_for := -1        # map index the wall set was built for
var _pos := Vector2i(8, 8)
var _facing := DungeonView.Dir.NORTH
var _goto: LineEdit
var _deco := []             # current area's wall set ids, from its event script

# Event scripts
var _vm := EclVM.new()      # one VM for the session, so game flags persist between areas
var _vm_map := -1           # map index whose script is loaded
var _vm_file := 0           # ECL file number of the loaded script
var _vm_block := -1         # ECL block id of the loaded script
var _pending_move := -1     # direction of a move waiting on an on-move menu
var _event_image: Image     # picture shown in the view by an event (null = 3D view)
var _message: Label
var _dax_cache := {}

# Timed playback: script DELAYs and script-driven walks
const DELAY_SECONDS := 0.45
const WALK_STEP_SECONDS := 0.22
var _timer: Timer
var _busy := false                  # a delay or walk is playing; input waits
var _walk_path: Array[Vector2i] = []
var _walk_final_dir := 0
var _held_message := ""
var _sprite_cache := {}             # "file:id" -> frames
var _jump_next := false             # the next script move is a placement, not a walk

# The party (the game's saved party A, CHRDATA1-6) and the shop overlay
var _party: Array[PartyMember] = []
var _shop: ShopScreen
var _sheet: CharacterSheet
var _combat: CombatScreen
var _types: ItemTypes


func _ready() -> void:
	_goto = LineEdit.new()
	_goto.placeholder_text = "x y facing (e.g. 12 6 S), Enter to go, Esc to cancel"
	_goto.visible = false
	_goto.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_goto.offset_left = -210
	_goto.offset_right = 210
	_goto.offset_top = 8
	_goto.text_submitted.connect(_on_goto)
	_goto.focus_exited.connect(_on_goto_closed)
	_goto.gui_input.connect(_on_goto_input)
	add_child(_goto)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_message.add_theme_font_size_override("font_size", 18)
	_message.anchor_left = 0.0
	_message.anchor_right = 0.5
	_message.anchor_top = 1.0
	_message.anchor_bottom = 1.0
	_message.offset_left = 16
	_message.offset_right = -8
	_message.offset_top = -230
	_message.offset_bottom = -64
	_message.visible = false
	add_child(_message)
	_vm.write_byte(EclVM.CLOCK_HOUR, 0)   # a new game starts at 00:00
	_shop = ShopScreen.new()
	_shop.visible = false
	_shop.closed.connect(_on_shop_closed)
	add_child(_shop)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)
	_combat = CombatScreen.new()
	_combat.visible = false
	_combat.finished.connect(_on_event_fight_finished)
	add_child(_combat)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_game_path = GameData.find_game_path()
	if _game_path == "":
		_status.text = (
			"Pool of Radiance (DOS) data not found.\n"
			+ "Place the GOG install folder \"Pool of Radiance\" next to the project,\n"
			+ "or run with --game-path=\"<folder containing GEO1.DAX>\"."
		)
		return
	_types = ItemTypes.load_file(_game_path)
	for i in range(1, 7):
		var m := PartyMember.load_files(_game_path.path_join("CHRDATA%d.SAV" % i), _game_path.path_join("CHRDATA%d.ITM" % i))
		if m != null:
			m.recalculate(_types)
			_party.append(m)
	var battle_only := false
	for arg in OS.get_cmdline_user_args():
		battle_only = battle_only or arg.begins_with("--battle=")
	for file_name in GameData.list_files(_game_path, "DAX"):
		if battle_only and not file_name.begins_with("GEO"):
			continue
		var dax := DaxFile.open(_game_path.path_join(file_name))
		if dax == null:
			continue
		for id in dax.ids():
			var block: PackedByteArray = dax.blocks[id]
			if file_name.begins_with("ECL"):
				var strings := GoldBoxText.find_strings(block)
				if not strings.is_empty():
					_area_text[id] = strings[0].text
				continue
			if file_name.begins_with("GEO"):
				var m := GeoMap.decode(block)
				if m != null:
					_maps.append({"file": file_name, "id": id, "map": m})
				continue
			var animated := file_name.begins_with("PIC") or file_name.begins_with("SPRIT") or file_name.begins_with("FINAL")
			var pic := EgaPicture.decode_any(block) if animated else EgaPicture.decode(block)
			if pic != null:
				_pictures.append({"file": file_name, "id": id, "pic": pic})
	# Start on the main title screen (TITLE.DAX block 2).
	for i in _pictures.size():
		if _pictures[i].file == "TITLE.DAX" and _pictures[i].id == 2:
			_pic_index = i
	# Testing aid for the lab: --battle=GEO2.DAX:20:13:7:W:2:4:6:4:2 (map file, map id, x, y,
	# facing, monster file, monster id, count, picture, distance or -1) [--battle-image=path]
	# prints where everyone starts and saves the battlefield, then quits. With
	# --battle-fight=<seed> it also fights it out (computer on both sides), printing every roll.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battle="):
			_battle_check(arg.trim_prefix("--battle="))
			return
	# Testing aid: start straight in the last quick save, if there is one.
	if FileAccess.file_exists(_save_path()):
		_quick_load()
		return
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if _game_path == "" or not event.is_pressed() or _shop.visible or _sheet.visible or _combat.visible:
		return
	if _mode != Mode.WALK and event is InputEventKey and (event as InputEventKey).keycode == KEY_F3:
		_quick_load()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		_mode = ((_mode + 1) % 3) as Mode
	elif _mode == Mode.WALK:
		var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
		if _busy:
			get_viewport().set_input_as_handled()
			return
		if _vm.state == EclVM.State.MENU:
			# A menu is open: only its choices count.
			var choice := -1
			if key >= KEY_1 and key <= KEY_9:
				choice = key - KEY_1
			elif event.is_action("ui_accept") and _vm.menu.size() == 1:
				choice = 0
			if choice >= 0 and choice < _vm.menu.size():
				_message.text = ""
				_vm.choose(choice)
				_after_vm()
			get_viewport().set_input_as_handled()
			_show()
			return
		if key == KEY_F2:
			_quick_save()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_F3:
			_quick_load()
		elif key == KEY_V:
			for m in _party:
				m.recalculate(_types)
			_sheet.open(_party, "PARTY")
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_B:
			for m in _party:
				m.recalculate(_types)
			var map: GeoMap = _maps[_map_index].map
			var script: EclScript = null
			var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % maxi(_vm_file, 1)))
			if ecl and ecl.blocks.has(_vm_block):
				script = EclScript.decode(ecl.blocks[_vm_block])
			_combat.open_test(_game_path, map, _pos.x, _pos.y, int(_facing), _party, maxi(_vm_file, 1), script)
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_M:
			_sheet.open(_all_monsters(), "MONSTERS")
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_N:
			var night := _vm.read_byte(EclVM.CLOCK_HOUR) >= 14
			_vm.write_byte(EclVM.CLOCK_HOUR, 8 if night else 20)
		elif key == KEY_O:
			_dungeon.show_slots = not _dungeon.show_slots
		elif key == KEY_C:
			_capture()
			return
		elif key == KEY_E:
			_dump_script()
			return
		elif key == KEY_G:
			_goto.text = ""
			_goto.visible = true
			_goto.grab_focus()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action("ui_up"):
			_try_move(_facing)
		elif event.is_action("ui_down"):
			_try_move((_facing + 2) % 4)
		elif event.is_action("ui_left"):
			_facing = ((_facing + 3) % 4) as DungeonView.Dir
		elif event.is_action("ui_right"):
			_facing = ((_facing + 1) % 4) as DungeonView.Dir
		else:
			return
	elif _mode == Mode.MAPS and event.is_action("ui_accept"):
		_mode = Mode.WALK
	elif event.is_action("ui_right"):
		_step(1)
	elif event.is_action("ui_left"):
		_step(-1)
	elif event.is_action("ui_down") and _mode == Mode.PICTURES:
		_jump_file(1)
	elif event.is_action("ui_up") and _mode == Mode.PICTURES:
		_jump_file(-1)
	else:
		return
	get_viewport().set_input_as_handled()
	_show()


func _step(delta: int) -> void:
	if _mode == Mode.PICTURES and not _pictures.is_empty():
		_pic_index = (_pic_index + delta + _pictures.size()) % _pictures.size()
	elif _mode == Mode.MAPS and not _maps.is_empty():
		_map_index = (_map_index + delta + _maps.size()) % _maps.size()


func _jump_file(step: int) -> void:
	if _pictures.is_empty():
		return
	# Indices where each file's pictures begin.
	var starts: Array[int] = []
	for i in _pictures.size():
		if i == 0 or _pictures[i].file != _pictures[i - 1].file:
			starts.append(i)
	var current := 0
	for k in starts.size():
		if starts[k] <= _pic_index:
			current = k
	_pic_index = starts[(current + step + starts.size()) % starts.size()]


func _on_goto_closed() -> void:
	_goto.visible = false


func _on_goto_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		_goto.release_focus()


func _on_goto(text: String) -> void:
	_goto.visible = false
	var parts := text.strip_edges().split(" ", false)
	if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		_pos = Vector2i(clampi(parts[0].to_int(), 0, 15), clampi(parts[1].to_int(), 0, 15))
		if parts.size() >= 3:
			var d := "NESW".find(parts[2].substr(0, 1).to_upper())
			if d >= 0:
				_facing = d as DungeonView.Dir
	_show()


## Writes the area's event script, disassembled, to <project>/captures/.
func _dump_script() -> void:
	var e: Dictionary = _maps[_map_index]
	var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null or not ecl.blocks.has(e.id):
		_status.text = "No event script with this map's id in ECL%d.DAX" % file_no
		return
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("ECL%d_%d.txt" % [file_no, e.id])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(_script(file_no, e.id, ecl).disassemble() + "\n")
	_status.text = "Wrote %s" % path.get_file()


## Saves the current view (4x, PNG) and its slot report to <project>/captures/.
func _capture() -> void:
	if _walls == null:
		return
	var e: Dictionary = _maps[_map_index]
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var base := dir.path_join("%s_%d-%d-%s_%s" % [
		String(e.file).get_basename(), _pos.x, _pos.y, DungeonView.DIR_NAMES[_facing], stamp])
	var img := DungeonView.to_image(_dungeon.render(e.map, _walls, _pos.x, _pos.y, _facing))
	img.resize(DungeonView.SIZE * 4, DungeonView.SIZE * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(base + ".png")
	var f := FileAccess.open(base + ".txt", FileAccess.WRITE)
	if f:
		f.store_string("%s block %d (%s)\n" % [e.file, e.id, GeoMap.AREA_NAMES.get(e.id, "unnamed area")])
		f.store_string(_dungeon.report(e.map, _walls, _pos.x, _pos.y, _facing) + "\n")
	_status.text = "Captured %s.png / .txt" % base.get_file()


## Quick save (F2) / quick load (F3): the whole game state in one file, so a test can
## start exactly where it's needed. Saved in the project's saves/ folder when run from the
## editor (git-ignored), otherwise in Godot's user folder.
func _save_path() -> String:
	# Testing aid for the lab: --save=<path> uses that quick save file instead.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			return arg.trim_prefix("--save=")
	if OS.has_feature("editor"):
		var dir := ProjectSettings.globalize_path("res://saves")
		DirAccess.make_dir_recursive_absolute(dir)
		return dir.path_join("quicksave.cfg")
	return "user://quicksave.cfg"


func _quick_save() -> void:
	if _busy or _vm.state == EclVM.State.MENU or _vm.ecl == null:
		_status.text = "Can't save in the middle of an event; finish it first."
		return
	var cfg := ConfigFile.new()
	cfg.set_value("place", "map_file", String(_maps[_map_index].file))
	cfg.set_value("place", "map_id", int(_maps[_map_index].id))
	cfg.set_value("place", "x", _pos.x)
	cfg.set_value("place", "y", _pos.y)
	cfg.set_value("place", "facing", int(_facing))
	cfg.set_value("script", "file", _vm_file)
	cfg.set_value("script", "block", _vm_block)
	cfg.set_value("script", "memory", _vm.mem)
	var members := []
	for m in _party:
		var items := []
		for it in m.items:
			var rec := it.raw.duplicate()
			rec[52] = 1 if it.readied else 0
			items.append(rec)
		members.append({"name": m.name, "money": m.money, "items": items})
	cfg.set_value("party", "members", members)
	var err := cfg.save(_save_path())
	_status.text = "Saved." if err == OK else "Save failed (error %d)." % err


func _battle_check(spec: String) -> void:
	var a := spec.split(":")
	var image_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battle-image="):
			image_path = arg.trim_prefix("--battle-image=")
	for i in _maps.size():
		if _maps[i].file == a[0] and _maps[i].id == int(a[1]):
			var facing := "NESW".find(a[4])
			_combat.run_check(_game_path, _maps[i].map, int(a[2]), int(a[3]), facing, _party,
				int(a[5]), [[int(a[6]), int(a[7]), int(a[8])]], int(a[9]), image_path)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--battle-fight="):
					_combat.run_fight(int(arg.trim_prefix("--battle-fight=")))
	get_tree().quit()


func _quick_load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		_status.text = "No quick save yet (F2 in walk mode saves)."
		return
	var map_file: String = cfg.get_value("place", "map_file", "")
	var map_id: int = cfg.get_value("place", "map_id", -1)
	var index := -1
	for i in _maps.size():
		if _maps[i].file == map_file and _maps[i].id == map_id:
			index = i
	if index < 0:
		_status.text = "Quick save names a map that isn't here."
		return
	# Stop anything in progress.
	_timer.stop()
	_busy = false
	_walk_path.clear()
	_held_message = ""
	_pending_move = -1
	_event_image = null
	_message.text = ""
	if _shop.visible:
		_shop.visible = false
	# Place and script.
	_mode = Mode.WALK
	_map_index = index
	_walls_for = -1
	_pos = Vector2i(cfg.get_value("place", "x", 8), cfg.get_value("place", "y", 8))
	_facing = int(cfg.get_value("place", "facing", 0)) as DungeonView.Dir
	_vm_file = cfg.get_value("script", "file", 0)
	_vm_block = cfg.get_value("script", "block", -1)
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % _vm_file))
	if ecl != null and ecl.blocks.has(_vm_block):
		_vm.load_script(ecl.blocks[_vm_block])
	var memory: PackedByteArray = cfg.get_value("script", "memory", PackedByteArray())
	if memory.size() == _vm.mem.size():
		_vm.mem = memory
	_vm.state = EclVM.State.DONE
	_vm.clear_output()
	_vm.sprite_id = -1
	_vm_map = _map_index
	_sync_position_to_vm(_facing)
	# Party: money and items as saved.
	var members: Array = cfg.get_value("party", "members", [])
	for i in mini(members.size(), _party.size()):
		var saved: Dictionary = members[i]
		_party[i].money = saved.get("money", _party[i].money)
		var items: Array[GameItem] = []
		for rec in saved.get("items", []):
			items.append(GameItem.from_record(rec))
		_party[i].items = items
		_party[i].recalculate(_types)
	_status.text = "Loaded."
	_show()


## A step: the area's on-move script runs first (it can refuse the move, e.g. a locked
## door), then the party moves and the on-step script runs for the new square.
func _try_move(direction: int) -> void:
	_event_image = null
	_message.text = ""
	if _vm.ecl != null:
		var map: GeoMap = _maps[_map_index].map
		_sync_position_to_vm(direction)
		_vm.write_byte(EclVM.WALL_AHEAD, map.wall(_pos.x, _pos.y, direction))
		_vm.write_byte(EclVM.MOVEMENT_BLOCK, 0)
		_vm.clear_output()
		_vm.start(0)
		_pending_move = direction
		_after_vm()
		return
	_finish_move(direction)


## Completes a move once the on-move script has finished without refusing it.
func _finish_move(direction: int) -> void:
	_pending_move = -1
	if _vm.read_byte(EclVM.MOVEMENT_BLOCK) == 255:
		return
	var map: GeoMap = _maps[_map_index].map
	# A wall blocks unless it carries a door.
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) == 0:
		return
	var next := _pos + DungeonView.DELTA[direction]
	if next.x < 0 or next.y < 0 or next.x >= GeoMap.SIZE or next.y >= GeoMap.SIZE:
		return
	_pos = next
	if _vm.ecl != null:
		_sync_position_to_vm(_facing)
		_vm.clear_output()
		_vm.start(1)
		_after_vm()


var _synced := Vector3i(-1, -1, -1)   # x, y, direction last written to the VM


func _sync_position_to_vm(direction: int) -> void:
	var map: GeoMap = _maps[_map_index].map
	_vm.write_byte(EclVM.PARTY_X, _pos.x)
	_vm.write_byte(EclVM.PARTY_Y, _pos.y)
	_vm.write_byte(EclVM.PARTY_DIR, direction)
	_vm.write_byte(EclVM.SQUARE_INFO, map.flag(_pos.x, _pos.y))
	_synced = Vector3i(_pos.x, _pos.y, direction)


## Scripts can move the party (a guided tour, a trap door): adopt what they wrote.
## A target reachable on foot is walked to step by step, as the original does; anything
## else is a jump.
func _adopt_position_from_vm() -> void:
	var now := Vector3i(_vm.read_byte(EclVM.PARTY_X), _vm.read_byte(EclVM.PARTY_Y), _vm.read_byte(EclVM.PARTY_DIR))
	if now == _synced:
		return
	var moved := now.x != _synced.x or now.y != _synced.y
	var turned := now.z != _synced.z and now.z < 4
	_synced = now
	if now.x >= GeoMap.SIZE or now.y >= GeoMap.SIZE:
		return
	var target := Vector2i(now.x, now.y)
	var walk := moved and not _jump_next and _mode == Mode.WALK and _vm_map == _map_index
	_jump_next = false
	if walk:
		var path := _find_path(_pos, target)
		if path.size() > 1:
			_walk_path = path.slice(1)
			_walk_final_dir = now.z if turned else _facing
			_busy = true
			_timer.start(WALK_STEP_SECONDS)
			return
	if moved:
		_pos = target
	if turned:
		_facing = now.z as DungeonView.Dir


## Shortest walk between two squares (walls stop you unless they carry a door).
func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var map: GeoMap = _maps[_map_index].map
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for d in 4:
			if map.wall(cur.x, cur.y, d) > 0 and map.door(cur.x, cur.y, d) == 0:
				continue
			var nxt: Vector2i = cur + DungeonView.DELTA[d]
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= GeoMap.SIZE or nxt.y >= GeoMap.SIZE or came.has(nxt):
				continue
			came[nxt] = cur
			queue.append(nxt)
	var path: Array[Vector2i] = []
	if not came.has(to):
		return path
	var p := to
	while p != from:
		path.push_front(p)
		p = came[p]
	path.push_front(from)
	return path


func _on_timer() -> void:
	if not _walk_path.is_empty():
		# One step of a script-driven walk: face the way you go, then step.
		var next: Vector2i = _walk_path.pop_front()
		var delta := next - _pos
		var d := DungeonView.DELTA.find(delta)
		if d >= 0:
			_facing = d as DungeonView.Dir
		_pos = next
		if _walk_path.is_empty():
			_facing = _walk_final_dir as DungeonView.Dir
			_sync_position_to_vm(_facing)
			_busy = false
			if _held_message != "":
				_message.text = _held_message
				_held_message = ""
			if _vm.state == EclVM.State.WAIT:
				_busy = true
				_timer.start(DELAY_SECONDS)
		else:
			_timer.start(WALK_STEP_SECONDS)
		_show()
		return
	# End of a script DELAY: an approaching figure that has arrived becomes its portrait.
	_busy = false
	if _vm.sprite_id >= 0 and _vm.sprite_distance == 0:
		_event_image = _event_picture(_vm.sprite_head, _vm.sprite_picture)
		_vm.sprite_id = -1
	_vm.resume()
	_after_vm()
	_show()


## Shows what a script run produced and carries on with whatever it was waiting for.
func _after_vm() -> void:
	if _vm.text_changed:
		# PRINT_CLEAR "" clears the box, as between the stops of Rolf's tour.
		_message.text = _vm.text
		_vm.text_changed = false
	if _vm.picture >= 0:
		_event_image = null if _vm.picture == 255 else _event_picture(_vm.picture_head, _vm.picture)
		_vm.picture = -1
	if not _vm.notes.is_empty():
		_message.text += "\n[not built yet: %s]" % ", ".join(_vm.notes)
		_vm.notes = []
	_adopt_position_from_vm()
	if not _walk_path.is_empty() and _held_message == "":
		# Show the text once the walk arrives.
		_held_message = _message.text
		_message.text = ""
	match _vm.state:
		EclVM.State.WAIT:
			if not _busy:
				_busy = true
				_timer.start(DELAY_SECONDS)
			return
		EclVM.State.MENU:
			var lines := PackedStringArray()
			for i in _vm.menu.size():
				lines.append(("%d) %s" % [i + 1, _vm.menu[i]]) if _vm.menu.size() > 1 else "Enter) %s" % _vm.menu[i])
			var options := "\n\n" + "    ".join(lines)
			if _held_message != "":
				_held_message += options
			else:
				_message.text += options
			return
		EclVM.State.SHOP:
			_open_shop()
			return
		EclVM.State.COMBAT:
			_start_event_fight()
			return
		EclVM.State.NEW_ECL:
			_enter_script(_vm_file, _vm.new_ecl)
		EclVM.State.ERROR:
			_message.text += "\n[script error: %s]" % _vm.error
	if _pending_move >= 0 and _vm.state == EclVM.State.DONE:
		_finish_move(_pending_move)


## Opens the shop for the script's TREASURE item list (ITEM<n>.DAX block, shown in
## reverse of stored order, as the original lists it).
func _open_shop() -> void:
	var list_id: int = _vm.treasure[_vm.treasure.size() - 1] if not _vm.treasure.is_empty() else 255
	var items: Array[GameItem] = []
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "ITEM%d.DAX" % n
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(list_id):
			items = GameItem.list_from(dax.blocks[list_id])
			items.reverse()
			break
	_shop.open(items, _party)


## Runs the fight an event script asked for, then lets the script carry on.
func _start_event_fight() -> void:
	for m in _party:
		m.recalculate(_types)
	var map: GeoMap = _maps[_map_index].map
	_combat.open_event(_game_path, map, _pos.x, _pos.y, int(_facing), _party, maxi(_vm_file, 1),
		_vm.monsters, _vm.encounter_max, _vm.encounter_advances)


func _on_event_fight_finished(result: int) -> void:
	if result == 2:
		_message.text = "THE PARTY HAS FALLEN.\n\n(F3 loads the quick save.)"
		_vm.state = EclVM.State.DONE
		_show()
		return
	_message.text = ""
	_vm.end_combat(0)
	_after_vm()
	_show()


## Every monster record in MON1CHA..MON8CHA, for the monster sheets.
func _all_monsters() -> Array[PartyMember]:
	var out: Array[PartyMember] = []
	for n in range(1, 9):
		var path := _game_path.path_join("MON%dCHA.DAX" % n)
		if not FileAccess.file_exists(path):
			continue
		var dax := DaxFile.open(path)
		for id in dax.ids():
			var m := PartyMember.load_monster(_game_path, n, id)
			if m != null:
				m.name = "%s  (MON%d block %d)" % [m.name, n, id]
				m.recalculate(_types)
				out.append(m)
	return out


func _on_shop_closed() -> void:
	for m in _party:
		m.recalculate(_types)
	_message.text = ""
	_vm.close_shop()
	_after_vm()
	_show()


## Loads the event script for the current map (when it changes) and runs its init.
func _ensure_area_script() -> void:
	if _vm_map == _map_index:
		return
	_vm_map = _map_index
	var e: Dictionary = _maps[_map_index]
	var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	var block_id := -1
	if ecl != null:
		if ecl.blocks.has(e.id):
			block_id = e.id
		else:
			for id in ecl.ids():
				if _script(file_no, id, ecl).loads_map(e.id):
					block_id = id
					break
	if block_id < 0:
		_vm.ecl = null
		return
	_enter_script(file_no, block_id, false)


## Switches to another ECL block (NEW_ECL or area change) and runs its init.
func _enter_script(file_no: int, block_id: int, follow_map: bool = true) -> void:
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null or not ecl.blocks.has(block_id):
		# Look in the other script files.
		ecl = null
		for n in range(1, 9):
			var other := DaxFile.open(_game_path.path_join("ECL%d.DAX" % n))
			if other != null and other.blocks.has(block_id):
				ecl = other
				file_no = n
				break
	if ecl == null:
		_message.text += "\n[script %d not found]" % block_id
		_vm.ecl = null
		return
	_vm_file = file_no
	_vm_block = block_id
	_vm.load_script(ecl.blocks[block_id])
	_sync_position_to_vm(_facing)
	_jump_next = true
	_vm.clear_output()
	_vm.area_map = []
	_vm.start(4)
	# The init script may load a different map and place the party.
	if follow_map and not _vm.area_map.is_empty() and _vm.area_map[0] < 127:
		for i in _maps.size():
			if _maps[i].id == _vm.area_map[0]:
				_map_index = i
				_vm_map = i
				break
		_pos = Vector2i(_vm.read_byte(EclVM.PARTY_X) & 15, _vm.read_byte(EclVM.PARTY_Y) & 15)
		_facing = (_vm.read_byte(EclVM.PARTY_DIR) & 3) as DungeonView.Dir
	_pending_move = -1
	_after_vm()


## Frames of sprite `id` (SPRIT files, preferring the current script's file number).
func _sprite_frames(id: int) -> Array:
	var key := "%d:%d" % [_vm_file, id]
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var frames := []
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "SPRIT%d.DAX" % n
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(id):
			frames = EgaPicture.frame_indices(dax.blocks[id])
			break
	_sprite_cache[key] = frames
	return frames


## An event picture: a head and body portrait when a head is set, else a PIC picture.
func _event_picture(head: int, id: int) -> Image:
	var img := Image.create_empty(DungeonView.SIZE, DungeonView.SIZE, false, Image.FORMAT_RGB8)
	if head != 255:
		var h := _find_picture("HEAD", head)
		var b := _find_picture("BODY", id)
		if h != null:
			img.blit_rect(h, Rect2i(Vector2i.ZERO, h.get_size()), Vector2i.ZERO)
		if b != null:
			img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, 40))
		return img
	var p := _find_picture("PIC", id)
	return p if p != null else img


## First frame of picture block `id` from PREFIX<n>.DAX, preferring the current script's file.
func _find_picture(prefix: String, id: int) -> Image:
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "%s%d.DAX" % [prefix, n]
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(id):
			var pic := EgaPicture.decode_any(dax.blocks[id])
			if pic != null and not pic.frames.is_empty():
				return pic.frames[0]
	return null


## The area's LOAD_AREA_DECO operands, from its event script: the ECL block with the
## map's id in the same-numbered file, else any block there that loads the map, else the
## first wall setting in that file.
func _area_deco(file_no: int, area_id: int) -> Array:
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null:
		return []
	if ecl.blocks.has(area_id):
		var own := _script(file_no, area_id, ecl)
		var deco := own.wall_ids_for_map(area_id)
		if not deco.is_empty():
			return deco
	for id in ecl.ids():
		var other := _script(file_no, id, ecl)
		if other.loads_map(area_id):
			var deco := other.wall_ids_for_map(area_id)
			if not deco.is_empty():
				return deco
	for id in ecl.ids():
		var deco := _script(file_no, id, ecl).wall_ids_for_map(-1)
		if not deco.is_empty():
			return deco
	return []


var _scripts := {}   # "file:id" -> EclScript


func _script(file_no: int, id: int, ecl: DaxFile = null) -> EclScript:
	var key := "%d:%d" % [file_no, id]
	if not _scripts.has(key):
		if ecl == null:
			ecl = DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
		_scripts[key] = EclScript.decode(ecl.blocks.get(id, PackedByteArray()))
	return _scripts[key]


func _layout() -> void:
	# Walk mode: view on the left, map on the right. Otherwise one panel fills the screen.
	var walk := _mode == Mode.WALK
	_picture.anchor_right = 0.5 if walk else 1.0
	_map_view.anchor_left = 0.5 if walk else 0.0
	_picture.visible = _mode != Mode.MAPS
	_map_view.visible = _mode != Mode.PICTURES
	_message.visible = walk
	# Leave room under the view for event text.
	_picture.offset_bottom = -236.0 if walk else -60.0
	if not walk:
		_map_view.set_marker(Vector2i(-1, -1), 0)


func _show() -> void:
	_layout()
	if _mode == Mode.PICTURES:
		if _pictures.is_empty():
			_status.text = "No pictures decoded."
			return
		var e: Dictionary = _pictures[_pic_index]
		var pic: EgaPicture = e.pic
		_picture.texture = ImageTexture.create_from_image(pic.sheet())
		_status.text = "PICTURES  %s block %d   %dx%d   %d frame(s)   [%d/%d]\n←/→ picture   ↑/↓ file   Tab maps" % [
			e.file, e.id, pic.width, pic.height, pic.frames.size(), _pic_index + 1, _pictures.size()]
		return
	if _maps.is_empty():
		_status.text = "No maps decoded."
		return
	var e: Dictionary = _maps[_map_index]
	_map_view.map = e.map
	var area: String = GeoMap.AREA_NAMES.get(e.id, "unnamed area")
	if _mode == Mode.MAPS:
		var hint: String = _area_text.get(e.id, "")
		if hint.length() > 70:
			hint = hint.substr(0, 70) + "..."
		_status.text = "MAPS  %s — %s block %d  [%d/%d]   %s\nwalls coloured by type, doors gold, shaded = flag bit 7 (unknown)    ←/→ map   Enter walk   Tab walk" % [
			area, e.file, e.id, _map_index + 1, _maps.size(), hint]
		return
	# Walk mode
	if _walls_for != _map_index:
		var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
		_deco = _area_deco(file_no, e.id)
		_walls = WallSet.build_for_area(_game_path, file_no, _deco)
		_walls_for = _map_index
	if _walls == null or _walls.walls.is_empty():
		_status.text = "WALK  %s — no wall graphics found" % area
		return
	_ensure_area_script()
	e = _maps[_map_index]
	var sky := _vm.read_byte(EclVM.SKY_OUTDOORS)
	_dungeon.sky_color = sky if sky > 0 and sky < 16 else 11
	if _event_image != null:
		_picture.texture = ImageTexture.create_from_image(_event_image)
	else:
		var view := _dungeon.render(e.map, _walls, _pos.x, _pos.y, _facing)
		if _vm.sprite_id >= 0:
			var frames := _sprite_frames(_vm.sprite_id)
			if not frames.is_empty():
				# A figure can't stand beyond a wall right in front of you.
				var distance := _vm.sprite_distance
				var map0: GeoMap = e.map
				var ahead := _pos + DungeonView.DELTA[_facing]
				if map0.wall(_pos.x, _pos.y, _facing) > 0:
					distance = 0
				elif distance > 1 and ahead.x >= 0 and ahead.y >= 0 and ahead.x < GeoMap.SIZE \
						and ahead.y < GeoMap.SIZE and map0.wall(ahead.x, ahead.y, _facing) > 0:
					distance = 1
				DungeonView.draw_sprite(view, frames[mini(distance, frames.size() - 1)])
		_picture.texture = ImageTexture.create_from_image(DungeonView.to_image(view))
	_map_view.set_marker(_pos, _facing)
	var facing_name: String = ["North", "East", "South", "West"][_facing]
	var map: GeoMap = e.map
	var night := _vm.read_byte(EclVM.CLOCK_HOUR) >= 14
	var script_name := "ECL%d block %d" % [_vm_file, _vm_block] if _vm.ecl != null else "no script"
	_status.text = "WALK  %s   %d,%d facing %s   event %d   %s   %s\n↑ forward  ↓ back  ←/→ turn   F2 save  F3 load   N day/night  O outlines  C capture  G go to  E script   Tab pictures" % [
		area, _pos.x, _pos.y, facing_name, map.flag(_pos.x, _pos.y) & 127, "night" if night else "day", script_name]

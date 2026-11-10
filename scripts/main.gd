extends Control
## M1/M2 data browser.
##   Tab          : pictures -> maps -> walk -> pictures
##   Pictures     : Left/Right picture, Up/Down file
##   Maps         : Left/Right map, Enter to walk the map
##   Walk         : Up forward, Down back, Left/Right turn,
##                  O slot outlines, C capture (PNG + slot report to captures/), G go to "x y dir"
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
	_game_path = GameData.find_game_path()
	if _game_path == "":
		_status.text = (
			"Pool of Radiance (DOS) data not found.\n"
			+ "Place the GOG install folder \"Pool of Radiance\" next to the project,\n"
			+ "or run with --game-path=\"<folder containing GEO1.DAX>\"."
		)
		return
	for file_name in GameData.list_files(_game_path, "DAX"):
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
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if _game_path == "" or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		_mode = ((_mode + 1) % 3) as Mode
	elif _mode == Mode.WALK:
		var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
		if key == KEY_O:
			_dungeon.show_slots = not _dungeon.show_slots
		elif key == KEY_C:
			_capture()
			return
		elif key == KEY_G:
			_goto.text = ""
			_goto.visible = true
			_goto.grab_focus()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action("ui_up"):
			_move(_facing)
		elif event.is_action("ui_down"):
			_move((_facing + 2) % 4)
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


## Moves one square if no closed wall is in the way. Door handling is provisional:
## any side with a door value is treated as passable.
func _move(direction: int) -> void:
	var map: GeoMap = _maps[_map_index].map
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) == 0:
		return
	var next := _pos + DungeonView.DELTA[direction]
	if next.x < 0 or next.y < 0 or next.x >= GeoMap.SIZE or next.y >= GeoMap.SIZE:
		return
	_pos = next


## Which WALLDEF blocks an area uses is set by its event script (not decoded yet).
## Until then: a 15-wall block with the area's own id if there is one (New Phlan),
## otherwise the file's 5-wall blocks in order.
func _wall_ids_for(file_no: int, area_id: int) -> Array:
	var walldef := DaxFile.open(_game_path.path_join("WALLDEF%d.DAX" % file_no))
	if walldef == null:
		return []
	if walldef.blocks.has(area_id) and walldef.blocks[area_id].size() >= WallSet.BYTES_PER_WALL * 15:
		return [area_id]
	var ids := []
	for id in walldef.ids():
		if walldef.blocks[id].size() == WallSet.BYTES_PER_WALL * 5 and ids.size() < 3:
			ids.append(id)
	return ids


func _layout() -> void:
	# Walk mode: view on the left, map on the right. Otherwise one panel fills the screen.
	var walk := _mode == Mode.WALK
	_picture.anchor_right = 0.5 if walk else 1.0
	_map_view.anchor_left = 0.5 if walk else 0.0
	_picture.visible = _mode != Mode.MAPS
	_map_view.visible = _mode != Mode.PICTURES
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
		_walls = WallSet.build(_game_path, file_no, _wall_ids_for(file_no, e.id))
		_walls_for = _map_index
	if _walls == null or _walls.walls.is_empty():
		_status.text = "WALK  %s — no wall graphics found" % area
		return
	var view := _dungeon.render(e.map, _walls, _pos.x, _pos.y, _facing)
	_picture.texture = ImageTexture.create_from_image(DungeonView.to_image(view))
	_map_view.set_marker(_pos, _facing)
	var facing_name: String = ["North", "East", "South", "West"][_facing]
	_status.text = "WALK  %s   %d,%d facing %s   (wall set provisional except New Phlan; doors always open)\n↑ forward  ↓ back  ←/→ turn   O outlines  C capture  G go to   Tab pictures" % [
		area, _pos.x, _pos.y, facing_name]

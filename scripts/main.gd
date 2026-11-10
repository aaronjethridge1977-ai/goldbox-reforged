extends Control
## M1 picture browser: decodes every EGA picture block in the game's .DAX files.
##   Left / Right : previous / next picture
##   Up / Down    : previous / next file
## Starts on the title screen.

@onready var _picture: TextureRect = $Picture
@onready var _status: Label = $Status

var _entries: Array = []   # [{file, id, pic}]
var _index := 0


func _ready() -> void:
	var path := GameData.find_game_path()
	if path == "":
		_status.text = (
			"Pool of Radiance (DOS) data not found.\n"
			+ "Place the GOG install folder \"Pool of Radiance\" next to the project,\n"
			+ "or run with --game-path=\"<folder containing GEO1.DAX>\"."
		)
		return
	for file_name in GameData.list_files(path, "DAX"):
		var dax := DaxFile.open(path.path_join(file_name))
		if dax == null:
			continue
		for id in dax.ids():
			var pic := EgaPicture.decode(dax.blocks[id])
			if pic != null:
				_entries.append({"file": file_name, "id": id, "pic": pic})
	# Start on the main title screen (TITLE.DAX block 2).
	for i in _entries.size():
		if _entries[i].file == "TITLE.DAX" and _entries[i].id == 2:
			_index = i
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if _entries.is_empty() or not event.is_pressed():
		return
	if event.is_action("ui_right"):
		_index = (_index + 1) % _entries.size()
	elif event.is_action("ui_left"):
		_index = (_index - 1 + _entries.size()) % _entries.size()
	elif event.is_action("ui_down"):
		_jump_file(1)
	elif event.is_action("ui_up"):
		_jump_file(-1)
	else:
		return
	_show()


func _jump_file(step: int) -> void:
	# Indices where each file's pictures begin.
	var starts: Array[int] = []
	for i in _entries.size():
		if i == 0 or _entries[i].file != _entries[i - 1].file:
			starts.append(i)
	var current := 0
	for k in starts.size():
		if starts[k] <= _index:
			current = k
	_index = starts[(current + step + starts.size()) % starts.size()]


func _show() -> void:
	var e: Dictionary = _entries[_index]
	var pic: EgaPicture = e.pic
	_picture.texture = ImageTexture.create_from_image(pic.sheet())
	_status.text = "%s  block %d   %dx%d   %d frame(s)    [%d / %d]    ←/→ picture   ↑/↓ file" % [
		e.file, e.id, pic.width, pic.height, pic.frames.size(), _index + 1, _entries.size()]

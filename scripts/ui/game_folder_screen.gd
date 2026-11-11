class_name GameFolderScreen
extends Control
## Shown when the player's Pool of Radiance files aren't found: asks for them, checks them
## and remembers the answer (GameData). The player's own GOG copy is the only source of
## game data; nothing from it ships with the engine.
##
## Desktop: a folder dialog. Either the GOG install folder ("Pool of Radiance") or the
## POOLRAD folder inside it will do.
## Web: the browser can't open a folder by path, so a folder picker (an <input> with
## webkitdirectory) reads the chosen folder's files and they are copied into the browser's
## own storage for the game (user://poolrad, IndexedDB behind Godot's file system), once.
## Only the files the game reads are kept (see WANTED).

signal ready_to_start(path: String)

const WEB_FOLDER := "user://poolrad"
## Extensions the engine reads from the game folder (plus a few named files).
const WANTED := ["DAX", "OVR", "EXE", "SAV", "ITM", "SPC", "DAT", "TXT", "CFG"]
const WANTED_NAMES := ["ITEMS"]

var _label: Label
var _button: Button
var _dialog: FileDialog
var _js_callback = null        # keeps the JavaScript callback alive
var _expected := 0
var _received := 0


func _ready() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = vp
	add_child(bg)
	var box := VBoxContainer.new()
	box.size = Vector2(900, 0)
	box.position = Vector2((vp.x - 900) / 2, vp.y / 2 - 140)
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(900, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.text = (
		"Gold Box Reforged plays Pool of Radiance from your own copy of the game.\n\n"
		+ ("Choose the game's folder (the GOG \"Pool of Radiance\" folder, or POOLRAD inside it)."
			if not OS.has_feature("web") else
			"Choose your \"Pool of Radiance\" folder (or POOLRAD inside it). Its files are copied into "
			+ "this browser's storage for the game and stay on your computer.")
	)
	box.add_child(_label)
	_button = Button.new()
	_button.text = "Choose folder..."
	_button.custom_minimum_size = Vector2(300, 56)
	_button.add_theme_font_size_override("font_size", 22)
	_button.pressed.connect(_choose)
	var center := CenterContainer.new()
	center.add_child(_button)
	box.add_child(center)
	if OS.has_feature("web") and GameData.is_valid_game_path(WEB_FOLDER):
		ready_to_start.emit.call_deferred(WEB_FOLDER)


func _choose() -> void:
	if OS.has_feature("web"):
		_choose_web()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = OS.get_name() in ["Windows", "macOS"]
		_dialog.title = "Pool of Radiance folder"
		_dialog.dir_selected.connect(_on_dir)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


## Accepts the GOG folder or the POOLRAD folder itself.
static func resolve(path: String) -> String:
	for p in [path, path.path_join("POOLRAD"), path.path_join("Pool of Radiance/POOLRAD")]:
		if GameData.is_valid_game_path(p):
			return p
	return ""


func _on_dir(path: String) -> void:
	var found := resolve(path)
	if found == "":
		_label.text = "That folder doesn't hold Pool of Radiance's files (GEO1.DAX wasn't found).\nTry again."
		return
	GameData.save_game_path(found)
	ready_to_start.emit(found)


# --- Web ------------------------------------------------------------------------------------

func _choose_web() -> void:
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window = JavaScriptBridge.get_interface("window")
	window.gbrFile = _js_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.webkitdirectory = true;
			input.multiple = true;
			input.onchange = async function () {
				var files = Array.from(input.files);
				window.gbrFile('count', files.length, '');
				for (var f of files) {
					var buf = new Uint8Array(await f.arrayBuffer());
					var bin = '';
					for (var i = 0; i < buf.length; i += 8192)
						bin += String.fromCharCode.apply(null, buf.subarray(i, i + 8192));
					window.gbrFile('file', f.name, btoa(bin));
				}
				window.gbrFile('done', 0, '');
			};
			input.click();
		})();
	""", true)
	_label.text = "Waiting for the folder..."


func _on_web_file(args: Array) -> void:
	var kind := str(args[0])
	match kind:
		"count":
			_expected = int(args[1])
			_received = 0
			DirAccess.make_dir_recursive_absolute(WEB_FOLDER)
		"file":
			_received += 1
			var name := str(args[1]).to_upper()
			if name.get_extension() in WANTED or name in WANTED_NAMES:
				var f := FileAccess.open(WEB_FOLDER.path_join(name), FileAccess.WRITE)
				if f != null:
					f.store_buffer(Marshalls.base64_to_raw(str(args[2])))
					f.close()
			_label.text = "Copying the game's files... %d of %d" % [_received, _expected]
		"done":
			if GameData.is_valid_game_path(WEB_FOLDER):
				GameData.save_game_path(WEB_FOLDER)
				ready_to_start.emit(WEB_FOLDER)
			else:
				_label.text = "That folder doesn't hold Pool of Radiance's files (GEO1.DAX wasn't found).\nTry again."

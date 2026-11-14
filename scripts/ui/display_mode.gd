class_name DisplayMode
extends RefCounted
## QoL (decided 2026-11-14, Methods 3): full screen. Alt+Enter or F11 switch it anywhere in the
## game (the original reads neither: Turbo Pascal's ReadKey asks the BIOS for the old keys
## only, which have no F11 and no Alt+Enter; DOSBox itself uses Alt+Enter the same way). The
## choice is remembered (user://settings.cfg, [qol] fullscreen) and is a SETTINGS item.
## The picture keeps its 16:10 shape (black bars) and its pixels sharp (nearest filtering).
##
## How the 1280x800 picture is scaled up on a bigger screen is Jeremy's pick (shown to him
## side by side, 2026-11-14): FRACTIONAL fills the height (1.35 at 1080 lines, uneven pixels),
## INTEGER keeps whole pixels (x1 at 1080 lines: a smaller picture with wide bars).

const SETTINGS_KEY := "fullscreen"
const SCALE_KEY := "fullscreen_scale"       # "fractional" or "integer" (lab: --scale=)


static func load_on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return false
	return bool(c.get_value("qol", SETTINGS_KEY, false))


static func save_on(on: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", SETTINGS_KEY, on)
	c.save(GameData.SETTINGS_PATH)


static func scale_mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			return a.trim_prefix("--scale=")
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return "fractional"
	return str(c.get_value("qol", SCALE_KEY, "fractional"))


## Puts the window in the saved mode (at start-up, and after SETTINGS changes it).
static func apply(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root := tree.root
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if scale_mode() == "integer" \
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	# Godot's own --fullscreen on the command line wins over the setting (lab screenshots).
	var on := load_on() or "--fullscreen" in OS.get_cmdline_args()
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


static func toggle(tree: SceneTree) -> void:
	save_on(not load_on())
	apply(tree)
	tree.call_group("display_mode", "display_mode_changed")    # SETTINGS redraws its value


## Alt+Enter or F11, from anywhere (main.gd's _input). True when it was one of them.
static func handle_key(tree: SceneTree, event: InputEvent) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return false
	if k.keycode == KEY_F11 or (k.alt_pressed and k.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		toggle(tree)
		return true
	return false

class_name FeatureText
extends RefCounted
## P21 (decided 2026-11-14): the text of SETTINGS' help, ABOUT -> FEATURES and ABOUT -> CREDITS,
## all from one content file (content/features.json), so wording changes never touch code.
## The engine only knows each setting's id and how to read and change it (StartMenu).

const PATH := "res://content/features.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"features": []}
	return _data


static func text(key: String, fallback: String = "") -> String:
	return String(data().get(key, fallback))


static func menu(key: String) -> Array:
	return data().get("menus", {}).get(key, ["EXIT"])


static func features() -> Array:
	return data().get("features", [])


## The features that are SETTINGS items, in the file's order.
static func settings() -> Array:
	return features().filter(func(f): return String(f.get("setting", "")) != "")


static func heading(key: String) -> String:
	return String(data().get("page_headings", {}).get(key, key.to_upper() + ":"))


static func color(name: String) -> int:
	match name:
		"YELLOW": return GameScreen.YELLOW
		"CYAN": return GameScreen.CYAN
		"GREEN": return GameScreen.GREEN
		"RED": return GameScreen.RED
	return GameScreen.WHITE


## The text box under SETTINGS and FEATURES (rows 17..22, columns 1..38): the help in green,
## then (when `with_note`) a blank line and the note in cyan; the blank line goes first when
## it would not all fit.
static func box_lines(f: Dictionary, with_note: bool) -> Array:
	var out: Array = []
	for l in GameScreen.wrap(String(f.get("help", "")), 38):
		out.append([l, GameScreen.GREEN])
	var note := String(f.get("note", "")) if with_note else ""
	if note != "":
		var n := GameScreen.wrap(note, 38)
		if out.size() + n.size() < BOX_ROWS:
			out.append(["", 0])
		for l in n:
			out.append([l, GameScreen.CYAN])
	return out.slice(0, BOX_ROWS)

const BOX_ROWS := 6

class_name AreaNames
extends RefCounted
## The area names table (content/poolrad/areas.json; Q10, chat 39): an area's name by its ECL data
## set and script block, for ours' additions (the save/load menu). The original shows no area names.
## Each entry: name, source (the game's text or the cluebook), confirmed (Jeremy confirmed it).

const DEFAULT_PATH := "res://content/poolrad/areas.json"

static var _tables := {}


## {"name", "source", "confirmed"} for the area, or {} when the table has none.
static func lookup(data_set: int, block: int, path: String = DEFAULT_PATH) -> Dictionary:
	var areas: Dictionary = _table(path)
	var a = areas.get("%d:%d" % [data_set, block], null)
	if not a is Dictionary:
		return {}
	return {"name": String(a.get("name", "")), "source": String(a.get("source", "")),
		"confirmed": bool(a.get("confirmed", false))}


static func _table(path: String) -> Dictionary:
	if not _tables.has(path):
		var areas := {}
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary and data.get("areas") is Dictionary:
				areas = data.areas
		_tables[path] = areas
	return _tables[path]

class_name ScriptCoverage
extends RefCounted
## Which parts of the game's event scripts have run (M6, decided 2026-11-12: script coverage is
## the main measure of the playthrough). Dev-only: the engine records only when started with
## --coverage=<file>; runs add to the same file, so coverage is the union of every run.
##
## Per script block ("file:block", as the plans name areas, e.g. "7:17"):
##   ins   offsets of the instructions that ran
##   br    branch outcomes taken: "<offset>:T"/":F" for IF_xx (the next instruction ran or
##         was skipped), "<offset>:<n>" for ON_GOTO/ON_GOSUB (n = the index, "out" when it
##         falls through), "<offset>:c<n>" for a menu choice (MENU_HORIZONTAL/VERTICAL, the
##         encounter menu's COMBAT WAIT FLEE ADVANCE PARLAY as 0-4, PARLAY's five)
##   extra offsets that ran but the static decoder never reached (a decoder gap: a bug)
## The denominators come from the static decode (EclScript._follow): tools/coverage_report.gd.

var path := ""
var blocks := {}        # key -> {"ins": {offset: true}, "br": {"o:x": true}, "extra": {offset: true}}
var _dirty := false
var _last_save := 0


func _init(file: String = "") -> void:
	path = file
	_merge_file()


## Adds what the file holds (other runs share it: saving merges first, so none is lost).
func _merge_file() -> void:
	if path != "" and FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for key in (data as Dictionary).get("blocks", {}):
				var b: Dictionary = data.blocks[key]
				var e := _block(key)
				for o in b.get("ins", []):
					e.ins[int(o)] = true
				for s in b.get("br", []):
					e.br[String(s)] = true
				for o in b.get("extra", []):
					e.extra[int(o)] = true


func _block(key: String) -> Dictionary:
	if not blocks.has(key):
		blocks[key] = {"ins": {}, "br": {}, "extra": {}}
	return blocks[key]


## An instruction at `offset` (into the block's code) ran; `known` is whether the static
## decoder has it.
func hit(key: String, offset: int, known: bool) -> void:
	if key == "":
		return
	var b := _block(key)
	if not b.ins.has(offset):
		b.ins[offset] = true
		_dirty = true
		if not known:
			b.extra[offset] = true
	_autosave()


func branch(key: String, offset: int, outcome: String) -> void:
	if key == "":
		return
	var b := _block(key)
	var s := "%d:%s" % [offset, outcome]
	if not b.br.has(s):
		b.br[s] = true
		_dirty = true


func _autosave() -> void:
	var now := Time.get_ticks_msec()
	if _dirty and now - _last_save > 10000:
		save()


func save() -> void:
	_last_save = Time.get_ticks_msec()
	if path == "" or not _dirty:
		return
	_merge_file()
	var out := {}
	for key in blocks:
		var b: Dictionary = blocks[key]
		var ins: Array = b.ins.keys()
		ins.sort()
		var br: Array = b.br.keys()
		br.sort()
		var extra: Array = b.extra.keys()
		extra.sort()
		out[key] = {"ins": ins, "br": br, "extra": extra}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"blocks": out}))
	f.close()
	_dirty = false

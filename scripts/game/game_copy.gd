class_name GameCopy
extends RefCounted
## Names the copy of the game a player's folder holds, for their reports (Jeremy, 2026-11-16:
## "the game names the copy it reads"): where it came from where that can be told (GOG, Steam, or
## neither: the disks or another source), the game's version as its credits give it, and short
## hashes of the key files (the executables and every DAX file). Shown on ABOUT, written to the log
## at start, and given as one line a tester copies into the issue form.
##
## Pool of Radiance: GAME.OVR's credits hold the version as a counted string ("version 1.3").
## GOG installs put goggame-<id>.info in the folder above POOLRAD; Steam's are under steamapps.

## Copies we have seen, by START.EXE and GAME.OVR (MD5): what they are.
const KNOWN := {
	"4c28d37e6d94930e865dd59b528f4cfc 2ac38b4b35a33dafd375b76957463804": "GOG 1.3",
}

static var _cache := {}
## The hashing started at launch on its own thread (start), and the folder it reads.
static var _thread: Thread = null
static var _thread_path := ""


## Starts reading the copy in `path` on a thread of its own, so the start isn't held up (the
## hashes take seconds on a slow disk: Lead, 2026-11-17). When it ends, the report line goes to
## the log ("Copy this into your report: ..."). describe() on the same folder waits for it.
static func start(path: String) -> void:
	if _cache.has(path) or _thread != null:
		return
	_thread = Thread.new()
	_thread_path = path
	_thread.start(_read.bind(path), Thread.PRIORITY_LOW)


## Waits for the thread start() began, if any (on quitting, so it doesn't outlive the game).
static func finish() -> void:
	if _thread == null:
		return
	var info: Dictionary = _thread.wait_to_finish()
	_cache[_thread_path] = info
	info.line = report_line(info)
	_thread = null
	print("Copy this into your report: ", info.line)


## The copy in `path` (the folder with GEO1.DAX): source, version, hashes and the report line.
## Read once per folder; waits for start()'s thread when it reads the same folder.
static func describe(path: String) -> Dictionary:
	if _thread != null and _thread_path == path:
		finish()
	if _cache.has(path):
		return _cache[path]
	var info := _read(path)
	info.line = report_line(info)
	_cache[path] = info
	return info


## Called on the main thread when start()'s thread is done: writes the log line.
static func _done() -> void:
	finish()


## Reads the folder (any thread): everything but the report line.
static func _read(path: String) -> Dictionary:
	var info := {}
	info.source = source_of(path)
	info.version = version_of(path)
	info.exe = _md5(path.path_join("START.EXE"))
	info.ovr = _md5(path.path_join("GAME.OVR"))
	var dax := GameData.list_files(path, "DAX")
	var all := ""
	for f in dax:
		all += f.to_upper() + " " + _md5(path.path_join(f)) + "\n"
	info.dax_count = dax.size()
	info.dax = all.md5_text()
	info.known = String(KNOWN.get("%s %s" % [info.exe, info.ovr], ""))
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		_done.call_deferred()
	return info


## "GOG", "STEAM" or "OTHER" (the original disks, or a source we can't tell).
static func source_of(path: String) -> String:
	var lower := path.replace("\\", "/").to_lower()
	if lower.contains("/steamapps/"):
		return "STEAM"
	var dir := path
	for i in 3:
		var d := DirAccess.open(dir)
		if d != null:
			for f in d.get_files():
				var lf := f.to_lower()
				if lf.begins_with("goggame-") or lf == "gog.ico":
					return "GOG"
				if lf == "steam_appid.txt" or lf == "steam_api.dll" or lf == "steam_api64.dll":
					return "STEAM"
		var up := dir.get_base_dir()
		if up == dir or up == "":
			break
		dir = up
	return "OTHER"


## The version GAME.OVR's credits name ("1.3"), or "" if none is found.
static func version_of(path: String) -> String:
	var d := GameData.read_bytes(path.path_join("GAME.OVR"))
	var key := "version ".to_ascii_buffer()
	for i in mini(d.size() - key.size(), 8192):
		var hit := true
		for j in key.size():
			if d[i + j] != key[j]:
				hit = false
				break
		if not hit:
			continue
		var s := ""
		var k := i + key.size()
		while k < d.size() and s.length() < 12 and ((d[k] >= 0x30 and d[k] <= 0x39) or d[k] == 0x2E \
				or (d[k] >= 0x61 and d[k] <= 0x7A)):
			s += char(d[k])
			k += 1
		return s
	return ""


## The one line for a report: our build, the copy's source and version, the files' hashes.
static func report_line(info: Dictionary) -> String:
	var build := str(ProjectSettings.get_setting("application/config/version", ""))
	return "GBR %s | POOLRAD %s %s | START.EXE %s GAME.OVR %s DAX(%d) %s%s" % [
		build if build != "" else "dev", info.source, info.version if info.version != "" else "?",
		String(info.exe).substr(0, 8), String(info.ovr).substr(0, 8), info.dax_count,
		String(info.dax).substr(0, 8), (" | SAME AS " + info.known) if info.known != "" else " | NEW FILES"]


## The lines ABOUT shows (37 columns at most each).
static func about_lines(info: Dictionary) -> PackedStringArray:
	var v := String(info.version) if info.version != "" else "UNKNOWN"
	var from: String = {"GOG": "GOG", "STEAM": "STEAM"}.get(info.source, "THE DISKS OR ELSEWHERE")
	return PackedStringArray([
		"YOUR COPY: %s, VERSION %s" % [from, v.to_upper()] if from.length() < 10 else "YOUR COPY: %s" % from,
		"START.EXE %s GAME.OVR %s" % [String(info.exe).substr(0, 8).to_upper(), String(info.ovr).substr(0, 8).to_upper()],
		"%d DAX FILES %s" % [info.dax_count, String(info.dax).substr(0, 8).to_upper()],
		("SAME FILES AS %s" % info.known) if info.known != "" else ("VERSION %s, FILES NEW TO US" % v.to_upper()),
	])


static func _md5(file: String) -> String:
	file = GameData.real_path(file)
	return FileAccess.get_md5(file) if FileAccess.file_exists(file) else "--------"

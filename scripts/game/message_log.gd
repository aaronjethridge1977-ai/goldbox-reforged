class_name MessageLog
extends RefCounted
## P58, the message log (QoL; Jeremy's Q37 A1, 2026-11-24, and Q43, 2026-11-28 07:28: the mockup as drawn, H to open it,
## Esc too because the original's Esc does nothing on the walking screen, every blow, grouped by area). The original
## keeps no history: a script's text is gone once the next one clears the box. Ours keeps every script text (PRINT,
## PRINT_CLEAR, an encounter's line, a script's damage lines) and every fight line (each blow, the result, the
## experience), each with its area and game time, kept in the save (each save its own; the newest CAP lines).
## Nothing here changes a frame or a key: the screen (MessageScreen) only opens on H or Esc.

const CAP := 2000
const SCRIPT := "s"
const FIGHT := "f"

## The lines, oldest first: {"a": area name, "d": day number, "m": minute of the day, "k": SCRIPT / FIGHT, "x": text}.
var entries: Array = []
## Where and when a line is now: returns [area name, day number, minute of the day] (main sets it).
var where := Callable()
var _open := false       # the newest script line still takes a PRINT's text (the box wasn't cleared)
var _raw := ""           # that line's text as printed (PRINTs run on with no space between, as on the screen)


## A script's text. `fresh`: the box was empty or cleared before it (PRINT_CLEAR, or a PRINT onto an empty box); otherwise
## it continues the newest script line, as it continues the box on the screen.
func script_text(s: String, fresh: bool) -> void:
	if not fresh and _open and not entries.is_empty() and String(entries[-1].k) == SCRIPT:
		_raw += s
		entries[-1].x = tidy(_raw)
		return
	var t := tidy(s)
	if t == "":
		return
	_add(SCRIPT, t)
	_raw = s
	_open = true


## PRINT_RETURN: a line break in the newest script line (a space in the log).
func script_break() -> void:
	if _open:
		_raw += "\n"


## A line that stands alone (a script's damage line, an encounter's line): its own entry; the next PRINT starts afresh.
func script_line(s: String) -> void:
	var t := tidy(s)
	if t != "":
		_add(SCRIPT, t)
	_open = false


## A fight's line (a blow, a spell's result, the fight's result); "ROUND n" isn't kept.
func fight_line(s: String) -> void:
	var t := tidy(s)
	_open = false
	if t == "" or t.begins_with("ROUND "):
		return
	_add(FIGHT, t)


func _add(kind: String, t: String) -> void:
	var w: Array = where.call() if where.is_valid() else ["", 0, 0]
	entries.append({"a": String(w[0]), "d": int(w[1]), "m": int(w[2]), "k": kind, "x": t})
	if entries.size() > CAP:
		entries = entries.slice(entries.size() - CAP)


## One line of text: line breaks and runs of spaces as one space, in capitals (the game's font has no small letters).
static func tidy(s: String) -> String:
	var t := s.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.to_upper()


## The areas, newest first: {"name", "d", "m" (its newest line's time), "count", "last" (its newest line's index)}.
func areas() -> Array:
	var by := {}
	var order: Array = []
	for i in range(entries.size() - 1, -1, -1):
		var a := String(entries[i].a)
		if not by.has(a):
			by[a] = {"name": a, "d": int(entries[i].d), "m": int(entries[i].m), "count": 0, "last": i}
			order.append(a)
		by[a].count += 1
	var out: Array = []
	for a in order:
		out.append(by[a])
	return out


## An area's lines, newest first.
func lines_of(area: String) -> Array:
	var out: Array = []
	for i in range(entries.size() - 1, -1, -1):
		if String(entries[i].a) == area:
			out.append(entries[i])
	return out


## "18:36" for a line of `today`, else "DAY n".
static func when(d: int, m: int, today: int) -> String:
	if d == today:
		return "%02d:%02d" % [m / 60, m % 60]
	return "DAY %d" % d


func clear() -> void:
	entries = []
	_open = false


func to_save() -> Array:
	return entries.duplicate(true)


func from_save(a: Variant) -> void:
	clear()
	if a is Array:
		for e in a:
			if e is Dictionary and e.has("x"):
				entries.append({"a": String(e.get("a", "")), "d": int(e.get("d", 0)), "m": int(e.get("m", 0)),
					"k": String(e.get("k", SCRIPT)), "x": String(e.x)})
	if entries.size() > CAP:
		entries = entries.slice(entries.size() - CAP)

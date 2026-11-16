class_name QuestLog
extends RefCounted
## The quest tracker's data side (QoL 3, chat 37): reads a content pack's quests.json and tells,
## from the game's own story flags, which quests the party knows of and how far each has gone.
## The screen (Combat's lane) draws what evaluate() returns; this class draws nothing.
##
## The data (content/poolrad/quests.json) was read from Pool of Radiance's scripts: City Hall's
## commission list and report loop (ECL3 block 8) and the field events that write each report flag
## (254: done, the reward due at City Hall; 255: reported). See the file's "conditions" entry for
## the condition strings. Nothing here changes the game: the original shows no quest list.

const DEFAULT_PATH := "res://content/poolrad/quests.json"

## Quest states, in the order a screen would sort them.
const OPEN := "open"            # known (offered, or a first step taken), not yet done
const DONE := "done"            # done in the field; the reward waits at City Hall
const FAILED := "failed"        # can no longer be done (the Bivant heir left behind)
const REPORTED := "reported"    # reported and paid
const HIDDEN := "hidden"        # not known to the party yet

var game := ""
var quests: Array = []


static func load_file(path: String = DEFAULT_PATH) -> QuestLog:
	var ql := QuestLog.new()
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("QuestLog: no quest data at %s" % path)
		return ql
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_warning("QuestLog: %s is not a quest file" % path)
		return ql
	ql.game = str(data.get("game", ""))
	ql.quests = data.get("quests", [])
	return ql


## Every quest's state. `read_byte` is a Callable(addr: int) -> int over ECL memory
## (EclVM.read_byte); `shown` holds the "A:B ADDR" keys of offer texts the engine has shown
## (offers that set no flag: EclVM.shown_texts, recorded since chat 39).
## Returns one Dictionary per quest: id, title, giver, where, offer, state, steps
## ([{text, done}]), report (the clerk's words once reported, else ""), offered (the party has
## heard the offer: one of its "shown" texts, or, for a quest with none, the quest is known).
## Jeremy's spoiler rules (Q11, 2026-11-16) for a screen: a step is shown only once done; WHERE
## only when offered.
func evaluate(read_byte: Callable, shown: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q in quests:
		var state := HIDDEN
		if _all(q.get("reported", []), read_byte, shown):
			state = REPORTED
		elif q.has("failed") and _all(q["failed"], read_byte, shown):
			state = FAILED
		elif _all(q.get("done", []), read_byte, shown):
			state = DONE
		elif _any(q.get("start", []), read_byte, shown):
			state = OPEN
		var offered := state != HIDDEN
		var offer_ways := []
		for way in q.get("start", []):
			for c in way:
				if str(c).begins_with("shown "):
					offer_ways.append(way)
					break
		if not offer_ways.is_empty():
			offered = _any(offer_ways, read_byte, shown)
		var steps: Array[Dictionary] = []
		for s in q.get("steps", []):
			steps.append({"text": str(s.get("text", "")), "done": _all(s.get("when", []), read_byte, shown)})
		out.append({
			"id": str(q.get("id", "")),
			"title": str(q.get("title", "")),
			"giver": str(q.get("giver", "")),
			"where": str(q.get("where", "")),
			"offer": str(q.get("offer", "")),
			"state": state,
			"steps": steps,
			"report": str(q.get("report", "")) if state == REPORTED else "",
			"offered": offered,
		})
	return out


## The "shown A:B ADDR" keys the data uses, so the engine knows which texts to record.
func shown_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for q in quests:
		for way in q.get("start", []):
			for c in way:
				var t := str(c)
				if t.begins_with("shown ") and not keys.has(t.trim_prefix("shown ")):
					keys.append(t.trim_prefix("shown "))
	return keys


## One condition (see quests.json "conditions").
static func holds(cond: String, read_byte: Callable, shown: Dictionary = {}) -> bool:
	var parts := cond.strip_edges().split(" ", false)
	if parts.size() == 3 and parts[0] == "shown":
		return shown.has(parts[1] + " " + parts[2])
	if parts.size() != 3:
		push_warning("QuestLog: bad condition '%s'" % cond)
		return false
	var v: int = read_byte.call(parts[0].hex_to_int())
	var n := parts[2].to_int()
	match parts[1]:
		"==": return v == n
		"!=": return v != n
		">=": return v >= n
		"<=": return v <= n
		">": return v > n
		"<": return v < n
		"&": return (v & n) == n
	push_warning("QuestLog: bad operator in '%s'" % cond)
	return false


static func _all(conds: Array, read_byte: Callable, shown: Dictionary) -> bool:
	if conds.is_empty():
		return false
	for c in conds:
		if not holds(str(c), read_byte, shown):
			return false
	return true


## `ways` is a list of condition lists: true when any of them holds in full.
static func _any(ways: Array, read_byte: Callable, shown: Dictionary) -> bool:
	for way in ways:
		if _all(way, read_byte, shown):
			return true
	return false

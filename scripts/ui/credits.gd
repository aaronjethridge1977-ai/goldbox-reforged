class_name Credits
extends RefCounted
## Two credits screens for the start menu:
##  - the original game's own credits, read from the player's GAME.OVR (the text and where the
##    original's code puts each line), so nothing of it ships with the engine;
##  - Gold Box Reforged's credits (Jeremy's wording, 2026-11-13) and the Godot Engine license,
##    which the engine's MIT license asks every game built with it to show.


## The original's credits layout: {"frames": [[x1, y1, x2, y2], ...], "texts": [[col, row,
## color, text], ...]} in drawing order, or {} when the game has none we can read.
##
## Pool of Radiance (lab, 2026-11-13): GAME.OVR holds the credits as Pascal strings (a length
## byte, then the text) starting with "scenario created by:", followed by the routine that draws
## them. That routine pushes byte arguments (MOV AL,n / PUSH AX = B0 nn 50) and the string's
## offset (MOV DI,nnnn / PUSH CS = BF lo hi 0E) for each call: six arguments draw a frame
## (interior x1, y1, x2, y2, then two zeros), three draw a string (column, row, colour). The
## routine ends with MOV SP,BP / POP BP (89 EC 5D).
static func original_layout(game_path: String) -> Dictionary:
	var d := FileAccess.get_file_as_bytes(game_path.path_join("GAME.OVR"))
	if d.is_empty():
		return {}
	var mark := "scenario created by:".to_ascii_buffer()
	var s0 := _find(d, mark, 1)
	if s0 < 1:
		return {}
	s0 -= 1   # the length byte
	var p := _find(d, PackedByteArray([0x55, 0x89, 0xE5]), s0)   # the drawing routine
	if p < 0:
		return {}
	var frames: Array = []
	var texts: Array = []
	var pushes: Array[int] = []
	var base := -1
	var stop := mini(p + 4096, d.size() - 4)
	while p < stop:
		if d[p] == 0x89 and d[p + 1] == 0xEC and d[p + 2] == 0x5D:
			break
		if d[p] == 0xB0 and d[p + 2] == 0x50:
			pushes.append(d[p + 1])
			p += 3
			continue
		if d[p] == 0xBF and d[p + 3] == 0x0E:
			var off := d[p + 1] | d[p + 2] << 8
			if pushes.size() >= 6:
				var a := pushes.slice(pushes.size() - 6)
				frames.append([a[0], a[1], a[2], a[3]])
				texts.append(["frame", frames.size() - 1])
			elif pushes.size() >= 3:
				if base < 0:
					base = s0 - off   # the first string drawn is the first in the table
				var at := base + off
				if at >= 0 and at < d.size():
					var n := d[at]
					var s := d.slice(at + 1, at + 1 + n).get_string_from_ascii()
					var a := pushes.slice(pushes.size() - 3)
					texts.append([a[0], a[1], a[2], s])
			pushes.clear()
			p += 4
			continue
		p += 1
	if texts.is_empty():
		return {}
	return {"frames": frames, "texts": texts}


## Draws the first `upto` steps of the original's credits (all of them by default).
static func draw_original(g: GameScreen, layout: Dictionary, upto: int = 1 << 30) -> void:
	g.clear()
	var steps: Array = layout.get("texts", [])
	for i in mini(upto, steps.size()):
		var t: Array = steps[i]
		if t[0] is String and t[0] == "frame":
			_frame(g, layout.frames[t[1]])
		else:
			g.text(t[0], t[1], t[3], t[2])
	g.update()


static func _frame(g: GameScreen, f: Array) -> void:
	var x1: int = f[0] - 1
	var y1: int = f[1] - 1
	var x2: int = f[2] + 1
	var y2: int = f[3] + 1
	for c in range(x1 + 1, x2):
		g.tile(c, y1, 22)
		g.tile(c, y2, 22)
	for r in range(y1 + 1, y2):
		g.tile(x1, r, 21)
		g.tile(x2, r, 21)
	for p in [Vector2i(x1, y1), Vector2i(x2, y1), Vector2i(x1, y2), Vector2i(x2, y2)]:
		g.tile(p.x, p.y, 20)


static func _find(d: PackedByteArray, what: PackedByteArray, from: int) -> int:
	var first := what[0]
	var i := d.find(first, from)
	while i >= 0 and i + what.size() <= d.size():
		if d.slice(i, i + what.size()) == what:
			return i
		i = d.find(first, i + 1)
	return -1


# Gold Box Reforged's credits, as [text, colour] lines; "" is a blank line. Wording settled
# with Jeremy on 2026-11-13.
const OURS := [
	["GOLD BOX REFORGED", GameScreen.YELLOW],
	["", 0],
	["BUILT BY PEOPLE USING AI,", GameScreen.CYAN],
	["NOT BY AI USING PEOPLE.", GameScreen.CYAN],
	["", 0],
	["ENGINE DESIGN AND CODE:", GameScreen.YELLOW],
	["CLAUDE (ANTHROPIC)", GameScreen.CYAN],
	["", 0],
	["THANKS TO THE PEOPLE AT ANTHROPIC WHO MAKE CLAUDE, AND ALL THOSE EXPLORING WHAT MANKIND AND AI CAN DO TOGETHER.", GameScreen.GREEN],
	["", 0],
	["FORMAT RESEARCH OWED TO:", GameScreen.YELLOW],
	["SSI-ENGINE", GameScreen.CYAN],
	["SIMEON PILGRIM'S CURSE OF THE AZURE BONDS RECONSTRUCTION", GameScreen.CYAN],
	["", 0],
	["SPECIAL THANKS TO AARON J. ETHRIDGE, WHO KEPT IT ALL POINTED IN THE RIGHT DIRECTION.", GameScreen.WHITE],
]
# Heads the legal pages, before the Godot license.
const DISCLAIMER := "AN UNOFFICIAL FAN PROJECT, FREE AND NOT FOR SALE. NOT AFFILIATED WITH OR ENDORSED BY ANTHROPIC OR THE OWNERS OF THE ORIGINAL GAMES."

const WIDTH := 36        # text columns inside the frame, a column of margin each side
const PAGE_ROWS := 21    # rows 2..22


## Our credits (one page), then the legal notices: the disclaimer and the Godot license, as
## pages of centred [text, colour] lines.
static func pages() -> Array:
	var lines: Array = []
	for l in OURS:
		if l[0] == "":
			lines.append(["", 0])
		else:
			for w in GameScreen.wrap(l[0], WIDTH):
				lines.append([w, l[1]])
	var out := _paginate(lines)
	# The Godot Engine license (the engine's own text, so it stays right when Godot is updated)
	# and where the third-party notices are: godotengine.org/license.
	var lic: Array = []
	for w in GameScreen.wrap(DISCLAIMER, WIDTH):
		lic.append([w, GameScreen.GREEN])
	lic.append(["", 0])
	lic.append_array([["THIS GAME USES GODOT ENGINE,", GameScreen.YELLOW],
		["AVAILABLE UNDER THE FOLLOWING LICENSE:", GameScreen.YELLOW], ["", 0]])
	for para in Engine.get_license_text().strip_edges().split("\n\n"):
		for w in GameScreen.wrap(_plain(para.replace("\n", " ")), WIDTH):
			lic.append([w, GameScreen.CYAN])
		lic.append(["", 0])
	lic.append(["THIRD-PARTY LICENSES:", GameScreen.YELLOW])
	lic.append(["GODOTENGINE.ORG/LICENSE", GameScreen.CYAN])
	out.append_array(_paginate(lic))
	return out


## Upper case, and only characters the original's font has.
static func _plain(s: String) -> String:
	var o := ""
	for ch in s.to_upper():
		var c := ch.unicode_at(0)
		o += ch if c >= 0x20 and c <= 0x5A else ("\"" if ch == "“" or ch == "”" else " ")
	return o


static func _paginate(lines: Array) -> Array:
	var out: Array = []
	var page: Array = []
	for l in lines:
		if page.size() >= PAGE_ROWS:
			out.append(page)
			page = []
		if page.is_empty() and l[0] == "":
			continue
		page.append(l)
	if not page.is_empty():
		out.append(page)
	return out


## One page of our credits in the start menu's frame, with NEXT / EXIT on the bottom line.
static func draw_page(g: GameScreen, page: Array, last: bool) -> void:
	g.clear()
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	var top := 2 + maxi(0, (PAGE_ROWS - page.size()) / 2)
	for i in page.size():
		var s: String = page[i][0]
		g.text((40 - s.length()) / 2, top + i, s, page[i][1])
	g.menu_line(24, ["EXIT"] if last else ["NEXT", "EXIT"])
	g.update()

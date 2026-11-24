class_name Automap
extends Control
## QoL (decided 2026-11-11): the automap. A mini-map in the corner of the walking screen
## (M opens and closes it) and a full map of the area (F), both showing only squares the
## party has stood on, with their walls and doors; the party is an arrow. It can be turned
## off for good in SETTINGS (start menu). The original's own AREA view is separate and stays
## as the original has it (off where ECL 0x49FB is set).
##
## Visited squares are kept per map (GEO file and block) and saved with quick saves: a byte a square, 1 walked,
## and bit 1 << (side + 1) for each side (0 N, 1 E, 2 S, 3 W) the party has stepped across.
## P100 (Jeremy's Q37 B1, 2026-11-24): a door mark only on a side the party has stepped through; every other
## door-bit side draws as the wall the 3D view shows (the map's door bits can't tell a secret door: Kuto's Well's
## 5,8 N showed a door the party couldn't use; the original's AREA draws no door marks at all).
##
## The look (Jeremy, 2026-11-16 20:55, from Combat Chat 15's mockups M2 and F1, the original's own AREA view
## as the model): drawn on the game's 320 x 200 grid with the game's own rope, gold blocks and font. The
## mini-map is a roped window in the bottom-right corner under the party list (its bottom and right ropes the
## screen's own, gold blocks at the joints), as tall as the party leaves room (6 members: 9 x 5 squares, 7 or 8:
## 9 x 3); the full map a roped screen with the area's name and ESC CLOSES on row 24. Squares walked are filled
## dark grey, the rest black; walls white, two pixels across the square edge (as AREA draws them), doors a
## brown stretch in the middle; the party the red arrow of the earlier parchment map (Jeremy, 21:00).

const SETTINGS_KEY := "automap"
const MINI_CELL := 8            # game pixels a square on the mini-map (the original AREA's size)
const FULL_CELL := 10           # on the full map: 16 x 16 squares = 160 x 160
const MINI_COLS := 9
const FLOOR := Color8(85, 85, 85)          # EGA dark grey
const WALL := Color8(255, 255, 255)
const DOOR := Color8(170, 85, 0)           # EGA brown
const ARROW := Color8(176, 32, 24)
const ARROW_LIGHT := Color8(232, 72, 48)
## The party, facing west ('R' red, 'H' highlight); turned for the other directions (the parchment map's).
const ARROW_W := ["....RR...", "..RRR....", ".RRHRRRRR", "RRRHHHHHR", ".RRHRRRRR", "..RRR....", "....RR..."]

var enabled := true             # the setting
var mini_open := true
var party_rows := 6          # members in the party list (main sets it): the mini-map stays below them
var full_open := false
var visited := {}               # map key -> PackedByteArray(256)
var map: GeoMap
var map_key := ""
var pos := Vector2i.ZERO
var facing := 0
var title := ""


static func load_enabled() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", SETTINGS_KEY, true))


static func save_enabled(on: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", SETTINGS_KEY, on)
	c.save(GameData.SETTINGS_PATH)


## Whether the walking screen is showing (set by the game); checked every frame.
var gate: Callable = Callable()


var _g: GameScreen                 # the overlay: a transparent 320 x 200 picture over the game's


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enabled = load_enabled()
	_g = GameScreen.new()
	_g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_g)


func _process(_delta: float) -> void:
	var show := enabled and gate.is_valid() and bool(gate.call())
	if show != visible:
		visible = show
		queue_redraw()
	elif show:
		# The party can grow while the window shows (an NPC joins, a save with 7 or 8 loads): _draw repaints
		# only when what it shows changed, the party's size included (Combat Chat 32: an 8-member save kept the
		# 6-member window over members 7 and 8).
		queue_redraw()
	if not show:
		full_open = false
		# _draw doesn't run while hidden: the place line no longer makes room for the window (Combat Chat 58: the
		# camp drew CAMPING above the time; DOSBox "E 17:04 CAMPING" on one row).
		mini_shown = false


## Where the party is now; marks the square visited.
func place(m: GeoMap, key: String, at: Vector2i, dir: int, name: String) -> void:
	var from := pos
	var same := map_key == key
	map = m
	map_key = key
	pos = at
	facing = dir
	title = name
	if not visited.has(key):
		var b := PackedByteArray()
		b.resize(256)
		visited[key] = b
	if at.x >= 0 and at.x < 16 and at.y >= 0 and at.y < 16:
		visited[key][at.y * 16 + at.x] |= 1
		var side := STEPS.find(at - from)
		if same and side >= 0 and from.x >= 0 and from.x < 16 and from.y >= 0 and from.y < 16:
			visited[key][from.y * 16 + from.x] |= 2 << side
			visited[key][at.y * 16 + at.x] |= 2 << ((side + 2) % 4)
	queue_redraw()


const STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   # a step across side 0-3


## Has the party stepped across this side of the square?
func crossed(x: int, y: int, side: int) -> bool:
	if x < 0 or y < 0 or x > 15 or y > 15 or not visited.has(map_key):
		return false
	return visited[map_key][y * 16 + x] & (2 << side) != 0


func seen(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x > 15 or y > 15 or not visited.has(map_key):
		return false
	return visited[map_key][y * 16 + x] != 0


## For quick saves: {key: "0101..."} as hex strings.
func to_save() -> Dictionary:
	var out := {}
	for k in visited:
		out[k] = (visited[k] as PackedByteArray).hex_encode()
	return out


func from_save(d: Dictionary) -> void:
	visited.clear()
	for k in d:
		visited[k] = String(d[k]).hex_decode()


var _shown := ""                   # what the overlay shows now: it is repainted only when this changes
static var mini_shown := false     # P78: the mini-map's window is up (GameScreen.draw_walk moves SEARCH above it)


func _draw() -> void:
	if _g == null:
		return
	var what := "%s|%s|%s|%s|%d|%s|%d|%s|%s|%d" % [enabled and map != null and visible, full_open, mini_open,
		map_key, party_rows, pos, facing, title, visited.get(map_key, PackedByteArray()).hex_encode(), map.get_instance_id() if map != null else 0]
	if what == _shown:
		return
	_shown = what
	_g.img.fill(Color(0, 0, 0, 0))
	mini_shown = false
	if enabled and map != null and visible:
		if full_open:
			_draw_full()
		elif mini_open:
			_draw_mini()
	_g.update()


## The mini-map's window: cols 29-39, its top rope under the last party row, the bottom rope row 16.
func _draw_mini() -> void:
	var top := maxi(4 + maxi(party_rows, 6), 10)        # the first free row under the list
	if top > 12:
		return
	mini_shown = true
	_rope_box(29, top, 39, 16)
	var inner := Rect2i(30 * 8, (top + 1) * 8, 9 * 8, (15 - top) * 8)
	_g.img.fill_rect(inner, Color.BLACK)
	var rows := inner.size.y / MINI_CELL
	if rows % 2 == 0:
		rows -= 1
	var origin := inner.position + Vector2i((inner.size.x - MINI_COLS * MINI_CELL) / 2, (inner.size.y - rows * MINI_CELL) / 2)
	_paint(origin, MINI_CELL, pos - Vector2i(MINI_COLS / 2, rows / 2), Vector2i(MINI_COLS, rows), inner)


## The full map: a roped screen, the area's name on row 1, the 16 x 16 squares, ESC CLOSES on row 24.
func _draw_full() -> void:
	_g.img.fill(Color.BLACK)
	_rope_box(0, 0, 39, 23)
	var name := title.substr(0, 38)
	_g.text((40 - name.length()) / 2, 1, name, GameScreen.YELLOW)
	var origin := Vector2i((320 - 16 * FULL_CELL) / 2, 16 + (168 - 16 * FULL_CELL) / 2)
	_paint(origin, FULL_CELL, Vector2i.ZERO, Vector2i(16, 16), Rect2i(8, 16, 304, 168))
	_g.text(0, 24, "ESC", GameScreen.WHITE)
	_g.text(4, 24, "CLOSES", GameScreen.GREEN)


func _rope_box(c0: int, r0: int, c1: int, r1: int) -> void:
	for c in range(c0 + 1, c1):
		_g.tile(c, r0, 22)
		_g.tile(c, r1, 22)
	for r in range(r0 + 1, r1):
		_g.tile(c0, r, 21)
		_g.tile(c1, r, 21)
	for p in [Vector2i(c0, r0), Vector2i(c1, r0), Vector2i(c0, r1), Vector2i(c1, r1)]:
		_g.tile(p.x, p.y, 20)


## Squares `first` .. first + n - 1 at `cell` pixels each from `origin`, clipped to `clip`: the walked ones
## filled, their walls and doors, the party's arrow.
func _paint(origin: Vector2i, cell: int, first: Vector2i, n: Vector2i, clip: Rect2i) -> void:
	var img := _g.img
	for cy in n.y:
		for cx in n.x:
			var sq := first + Vector2i(cx, cy)
			if seen(sq.x, sq.y):
				img.fill_rect(Rect2i(origin + Vector2i(cx, cy) * cell, Vector2i(cell, cell)).intersection(clip), FLOOR)
	for cy in n.y:
		for cx in n.x:
			var sq := first + Vector2i(cx, cy)
			if not seen(sq.x, sq.y):
				continue
			var p := origin + Vector2i(cx, cy) * cell
			for side in 4:
				if map.wall(sq.x, sq.y, side) == 0:
					continue
				# Two pixels across the edge (one each side), as the original's AREA draws walls.
				var r: Rect2i = [Rect2i(p.x - 1, p.y - 1, cell + 2, 2), Rect2i(p.x + cell - 1, p.y - 1, 2, cell + 2),
					Rect2i(p.x - 1, p.y + cell - 1, cell + 2, 2), Rect2i(p.x - 1, p.y - 1, 2, cell + 2)][side]
				img.fill_rect(r.intersection(clip), WALL)
				if map.door(sq.x, sq.y, side) != 0 and crossed(sq.x, sq.y, side):
					var m := cell / 4
					var d: Rect2i = [Rect2i(p.x + m, p.y - 1, cell - 2 * m, 2), Rect2i(p.x + cell - 1, p.y + m, 2, cell - 2 * m),
						Rect2i(p.x + m, p.y + cell - 1, cell - 2 * m, 2), Rect2i(p.x - 1, p.y + m, 2, cell - 2 * m)][side]
					img.fill_rect(d.intersection(clip), DOOR)
	var rel := pos - first
	if rel.x < 0 or rel.y < 0 or rel.x >= n.x or rel.y >= n.y:
		return
	var c := origin + rel * cell + Vector2i(cell / 2, cell / 2)
	for j in ARROW_W.size():
		for i in ARROW_W[j].length():
			var ch: String = ARROW_W[j][i]
			if ch == ".":
				continue
			# (i, j) in the west-facing sprite, centred, turned to face the party's way.
			var v := Vector2i(i - 4, j - 3)
			match facing:
				0: v = Vector2i(v.y, v.x)            # north
				1: v = Vector2i(-v.x, v.y)           # east
				2: v = Vector2i(v.y, -v.x)           # south
			var q := c + v
			if clip.has_point(q):
				img.set_pixel(q.x, q.y, ARROW if ch == "R" else ARROW_LIGHT)

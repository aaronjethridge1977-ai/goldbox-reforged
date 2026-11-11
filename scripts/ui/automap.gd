class_name Automap
extends Control
## QoL (decided 2026-11-11): the automap. A mini-map in the corner of the walking screen
## (M opens and closes it) and a full map of the area (F), both showing only squares the
## party has stood on, with their walls and doors; the party is an arrow. It can be turned
## off for good in SETTINGS (start menu). The original's own AREA view is separate and stays
## as the original has it (off where ECL 0x49FB is set).
##
## Visited squares are kept per map (GEO file and block) and saved with quick saves.

const SETTINGS_KEY := "automap"
const MINI_RADIUS := 3          # the mini-map shows 7x7 squares around the party
const MINI_CELL := 20           # window pixels per square on the mini-map
const FULL_CELL := 40

var enabled := true             # the setting
var mini_open := true
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enabled = load_enabled()


func _process(_delta: float) -> void:
	var show := enabled and gate.is_valid() and bool(gate.call())
	if show != visible:
		visible = show
		queue_redraw()
	if not show:
		full_open = false


## Where the party is now; marks the square visited.
func place(m: GeoMap, key: String, at: Vector2i, dir: int, name: String) -> void:
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
		visited[key][at.y * 16 + at.x] = 1
	queue_redraw()


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


func _draw() -> void:
	if not enabled or map == null or not visible:
		return
	var vp := get_viewport_rect().size
	if full_open:
		var side := FULL_CELL * 16
		var cell := float(mini(int(vp.y * 0.9), side)) / 16.0
		var origin := Vector2((vp.x - cell * 16) / 2, (vp.y - cell * 16) / 2)
		var box := Rect2(origin - Vector2(12, 40), Vector2(cell * 16 + 24, cell * 16 + 52))
		draw_rect(box, Color.BLACK)
		draw_rect(box, Color(GameScreen.EGA[14]), false, 2.0)
		draw_string(ThemeDB.fallback_font, origin + Vector2(0, -14), "%s   (F or Esc closes)" % title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GameScreen.EGA[14]))
		_draw_area(origin, cell, Rect2i(0, 0, 16, 16))
	elif mini_open:
		var n := MINI_RADIUS * 2 + 1
		var size := Vector2(n * MINI_CELL, n * MINI_CELL)
		# Bottom right of the upper panel, under the party list (the free rows above the
		# place line), in window pixels of the scaled 320x200 screen.
		var scale := minf(vp.x / 320.0, vp.y / 200.0)
		var screen := Vector2(320, 200) * scale
		var top_left := (vp - screen) / 2
		var origin := top_left + Vector2(312 * scale - size.x, 118 * scale - size.y)
		draw_rect(Rect2(origin - Vector2(3, 3), size + Vector2(6, 6)), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(origin - Vector2(3, 3), size + Vector2(6, 6)), Color(GameScreen.EGA[8]), false, 1.0)
		_draw_area(origin - Vector2(pos.x - MINI_RADIUS, pos.y - MINI_RADIUS) * MINI_CELL, MINI_CELL,
			Rect2i(pos.x - MINI_RADIUS, pos.y - MINI_RADIUS, n, n))


## Draws the visited squares of `area` (in map squares) with square (0,0) at `origin`.
func _draw_area(origin: Vector2, cell: float, area: Rect2i) -> void:
	var floor_c := Color(GameScreen.EGA[8]).darkened(0.35)
	var wall_c := Color(GameScreen.EGA[7])
	var door_c := Color(GameScreen.EGA[14])
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not seen(x, y):
				continue
			var p := origin + Vector2(x, y) * cell
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(cell - 2, cell - 2)), floor_c)
			for side in 4:
				if map.wall(x, y, side) == 0:
					continue
				var c := door_c if map.door(x, y, side) != 0 else wall_c
				var a: Vector2
				var b: Vector2
				match side:
					0: a = p; b = p + Vector2(cell, 0)
					1: a = p + Vector2(cell, 0); b = p + Vector2(cell, cell)
					2: a = p + Vector2(0, cell); b = p + Vector2(cell, cell)
					_: a = p; b = p + Vector2(0, cell)
				draw_line(a, b, c, maxf(2.0, cell / 10.0))
	# The party: an arrow pointing the way it faces.
	var centre := origin + (Vector2(pos) + Vector2(0.5, 0.5)) * cell
	var d := Vector2(DungeonView.DELTA[facing])
	var side_v := Vector2(-d.y, d.x)
	var tip := centre + d * cell * 0.38
	var back := centre - d * cell * 0.3
	draw_colored_polygon(PackedVector2Array([tip, back + side_v * cell * 0.28, back - side_v * cell * 0.28]),
		Color(GameScreen.EGA[12]))

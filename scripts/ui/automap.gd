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
const MINI_CELL := 10           # art pixels (640x400 grain) per square on the mini-map
const FULL_CELL := 18

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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enabled = load_enabled()


func _process(_delta: float) -> void:
	var show := enabled and gate.is_valid() and bool(gate.call())
	if show != visible:
		visible = show
		queue_redraw()
	if not show:
		full_open = false
	elif not _inked.is_empty():
		queue_redraw()             # a new square's walls are being inked in


## Where the party is now; marks the square visited.
func place(m: GeoMap, key: String, at: Vector2i, dir: int, name: String) -> void:
	map = m
	if key != map_key:
		_inked.clear()
	map_key = key
	pos = at
	facing = dir
	title = name
	if not visited.has(key):
		var b := PackedByteArray()
		b.resize(256)
		visited[key] = b
	if at.x >= 0 and at.x < 16 and at.y >= 0 and at.y < 16:
		if visited[key][at.y * 16 + at.x] == 0:
			_inked["%s:%d,%d" % [key, at.x, at.y]] = Time.get_ticks_msec()
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
	var scale := minf(vp.x / 320.0, vp.y / 200.0)
	var px := scale / 2.0            # window pixels per art pixel: the 640x400 grain
	if full_open:
		var n := FULL_CELL * 16 + FULL_MARGIN * 2
		var k := maxf(1.0, floorf(vp.y * 0.9 / (n * px))) * px
		var size := Vector2(n, n) * k
		var origin := ((vp - size) / 2).floor()
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.8))
		draw_string(ThemeDB.fallback_font, origin + Vector2(0, -10), "%s   (F or Esc closes)" % title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GameScreen.EGA[14]))
		_blit(_paint(n, FULL_CELL, FULL_MARGIN, Vector2i.ZERO, 16), origin, size)
	elif mini_open:
		var w := MINI_RADIUS * 2 + 1
		var n := MINI_CELL * w + MINI_MARGIN * 2
		var size := Vector2(n, n) * px
		# Bottom right of the upper panel, under the party list (the free rows above the
		# place line), in window pixels of the scaled 320x200 screen.
		var screen := Vector2(320, 200) * scale
		var top_left := (vp - screen) / 2
		var origin := (top_left + Vector2(313 * scale - size.x, 119 * scale - size.y)).floor()
		_blit(_paint(n, MINI_CELL, MINI_MARGIN, pos - Vector2i(MINI_RADIUS, MINI_RADIUS), w), origin, size)


func _blit(img: Image, origin: Vector2, size: Vector2) -> void:
	var key := img.get_width()
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(img)
	else:
		(_textures[key] as ImageTexture).update(img)
	draw_texture_rect(_textures[key], Rect2(origin, size), false)


# --- The parchment (QoL look, Jeremy 2026-11-13: VGA-style torn parchment being drawn on,
# 640x400 pixels; Ultima's VGA maps as the model). Generated, no art files. --------------------

## Browns from light to dark, as a 256-colour palette would hold them: smooth bands, no dither.
const RAMP: Array[Color] = [Color8(252, 236, 196), Color8(244, 224, 180), Color8(236, 212, 164),
	Color8(226, 198, 148), Color8(214, 182, 130), Color8(198, 164, 112), Color8(180, 144, 94),
	Color8(160, 124, 76), Color8(138, 104, 60), Color8(114, 82, 46), Color8(88, 62, 34),
	Color8(64, 44, 24), Color8(44, 30, 16)]
const INK := Color8(56, 36, 20)
const INK_SHADOW := Color8(104, 74, 44)
const DOOR := Color8(168, 96, 36)
const ARROW := Color8(176, 32, 24)
const ARROW_LIGHT := Color8(232, 72, 48)
const MINI_MARGIN := 3             # art pixels of torn edge around the mini-map's squares
const FULL_MARGIN := 8
const INK_SECONDS := 0.35          # a newly visited square's walls are inked in over this
## The party, facing west ('R' red, 'H' highlight); turned for the other directions.
const ARROW_W := ["....RR...", "..RRR....", ".RRHRRRRR", "RRRHHHHHR", ".RRHRRRRR", "..RRR....", "....RR..."]

var _sheets := {}                  # art size -> {"img": Image, "shade": PackedByteArray}
var _textures := {}                # art size -> ImageTexture
var _inked := {}                   # "key:x,y" -> msec the square was first visited (being inked)


## A blank torn sheet `n` art pixels square, the same every time (fixed seed): shade per pixel
## is a RAMP index, 255 off the paper.
func _sheet(n: int, cell: int, margin: int) -> Dictionary:
	if _sheets.has(n):
		return _sheets[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1989 + n
	# The tear: each side steps in and out every half square (pixel art, not noise).
	var edges: Array = []
	for side in 4:
		var e := PackedInt32Array()
		e.resize(n)
		var v := 0
		for i in n:
			if i % maxi(2, cell / 2) == 0:
				v = rng.randi_range(0, maxi(1, margin - 1))
			e[i] = v
		edges.append(e)
	var cut: Array = []
	for c in 4:
		cut.append(margin + rng.randi_range(1, margin + 1))
	var inside := PackedByteArray()
	inside.resize(n * n)
	for y in n:
		for x in n:
			var ok: bool = y >= edges[0][x] and y < n - 1 - edges[2][x] and x >= edges[3][y] \
				and x < n - 1 - edges[1][y]
			ok = ok and x + y >= cut[0] and (n - 1 - x) + y >= cut[1] \
				and x + (n - 1 - y) >= cut[2] and (n - 1 - x) + (n - 1 - y) >= cut[3]
			inside[y * n + x] = 1 if ok else 0
	# Distance in from the tear (up to 8), by peeling the paper a ring at a time.
	var dist := PackedByteArray()
	dist.resize(n * n)
	var cur := inside.duplicate()
	for k in range(1, 9):
		var next := cur.duplicate()
		for y in n:
			for x in n:
				var i := y * n + x
				if cur[i] == 0:
					continue
				if x == 0 or y == 0 or x == n - 1 or y == n - 1 or cur[i - 1] == 0 or cur[i + 1] == 0 \
						or cur[i - n] == 0 or cur[i + n] == 0:
					next[i] = 0
					dist[i] = k
		cur = next
	for i in n * n:
		if cur[i] != 0:
			dist[i] = 9
	var big := FastNoiseLite.new()
	big.seed = rng.randi()
	big.frequency = 3.0 / n
	var fine := FastNoiseLite.new()
	fine.seed = rng.randi()
	fine.frequency = 14.0 / n
	var shade := PackedByteArray()
	shade.resize(n * n)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			if inside[i] == 0:
				shade[i] = 255
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t := (big.get_noise_2d(x, y) + 1.0) * 1.6 + (fine.get_noise_2d(x, y) + 1.0) * 0.6
			t += pow(maxf(0.0, 7.0 - dist[i]), 1.3) * 0.75     # browner toward the tear
			var r := clampi(int(t), 0, RAMP.size() - 2)
			if dist[i] == 1:
				r = RAMP.size() - 1                            # the tear's dark rim
			elif dist[i] == 2:
				r = maxi(r, RAMP.size() - 4)
			shade[i] = r
			img.set_pixel(x, y, RAMP[r])
	_sheets[n] = {"img": img, "shade": shade}
	return _sheets[n]


## The sheet with the visited squares of the w x w squares from `first` drawn on it.
func _paint(n: int, cell: int, margin: int, first: Vector2i, w: int) -> Image:
	var sheet := _sheet(n, cell, margin)
	var shade: PackedByteArray = sheet["shade"]
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.copy_from(sheet["img"])
	var off := (n - cell * w) / 2
	var now := Time.get_ticks_msec()
	var lw := 2
	# Floors: three bands darker where the party has been.
	for cy in w:
		for cx in w:
			var sq := first + Vector2i(cx, cy)
			if not seen(sq.x, sq.y) or _ink(sq, now) < 0.3:
				continue
			for y in range(off + cy * cell, off + (cy + 1) * cell + 1):
				for x in range(off + cx * cell, off + (cx + 1) * cell + 1):
					if x >= n or y >= n:
						continue
					var s := shade[y * n + x]
					if s != 255:
						img.set_pixel(x, y, RAMP[mini(s + 3, RAMP.size() - 1)])
	# Walls in ink (a lighter line beside, the ink soaking in); doors leave a gap with an
	# amber mark across it.
	for cy in w:
		for cx in w:
			var sq := first + Vector2i(cx, cy)
			if not seen(sq.x, sq.y):
				continue
			var f := _ink(sq, now)
			if f <= 0.0:
				continue
			var p := Vector2i(off + cx * cell, off + cy * cell)
			for side in 4:
				if map.wall(sq.x, sq.y, side) == 0:
					continue
				var a: Vector2i = [p, p + Vector2i(cell, 0), p + Vector2i(cell, cell), p + Vector2i(0, cell)][side]
				var b: Vector2i = [p + Vector2i(cell, 0), p + Vector2i(cell, cell), p + Vector2i(0, cell), p][side]
				_wall(img, shade, a, b, f, map.door(sq.x, sq.y, side) != 0, lw)
	# The party.
	var rel := pos - first
	if rel.x >= 0 and rel.y >= 0 and rel.x < w and rel.y < w:
		var big := 2 if cell >= 16 else 1
		var c := Vector2i(off + rel.x * cell + cell / 2, off + rel.y * cell + cell / 2)
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
				for dy in big:
					for dx in big:
						var q := c + v * big + Vector2i(dx, dy)
						if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
							img.set_pixel(q.x, q.y, ARROW if ch == "R" else ARROW_LIGHT)
	return img


## How far a square's ink has got: 0..1 (1 for squares visited before).
func _ink(sq: Vector2i, now: int) -> float:
	var k := "%s:%d,%d" % [map_key, sq.x, sq.y]
	if not _inked.has(k):
		return 1.0
	var f := (now - int(_inked[k])) / (INK_SECONDS * 1000.0)
	if f >= 1.0:
		_inked.erase(k)
		return 1.0
	return f


func _wall(img: Image, shade: PackedByteArray, a: Vector2i, b: Vector2i, f: float, door: bool, lw: int) -> void:
	var n := img.get_width()
	var d := b - a
	var len := maxi(absi(d.x), absi(d.y))
	var step := Vector2i(signi(d.x), signi(d.y))
	var across := Vector2i(absi(step.y), absi(step.x))   # thickness grows right / down
	var upto := int(len * f)
	for i in upto + 1:
		var q := a + step * i
		var gap := door and i > len * 0.3 and i < len * 0.7
		for t in lw + 1:
			var r := q + across * t
			if r.x < 0 or r.y < 0 or r.x >= n or r.y >= n or shade[r.y * n + r.x] == 255:
				continue
			if gap:
				continue          # the door's gap (its mark is drawn below)
			if t < lw:
				img.set_pixel(r.x, r.y, INK)
			elif img.get_pixel(r.x, r.y) != INK:
				img.set_pixel(r.x, r.y, INK_SHADOW)
	if door and f >= 0.5:
		var mid := a + step * (len / 2)
		for k in range(-(len / 5), len / 5 + 1):
			for t in lw:
				var r := mid + across * k + step * t
				if r.x >= 0 and r.y >= 0 and r.x < n and r.y < n and shade[r.y * n + r.x] != 255:
					img.set_pixel(r.x, r.y, DOOR)

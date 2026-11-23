class_name OverlandMap
extends RefCounted
## Pool of Radiance's wilderness map (the overland), as the original keeps it: one 44x36
## grid of bytes in START.EXE's data segment (EXEPACK-compressed, so unpacked first), each
## byte a terrain tile number plus one; the tiles are SQRPACI.DAX's 24x24 pictures (block 1
## frames 0-127, block 2 frames 128-255). Found in the lab by matching the original's
## overland view tile for tile; rendered whole it is the map of the Moonsea's north shore.
##
## Three event scripts share the map (ECL6:25, ECL7:26, ECL8:27), each covering a band of
## columns: LOAD_AREA_MAP 4,4,0 / 5,5,0 / 6,6,0 selects the band, and the party's x
## (ECL 0x49C3) is counted from the band's left edge. The bands' left edges are the bytes
## right after the map (0, 13, 26); the original's display shows x plus that edge.
##
## How the original uses it (GAME.OVR):
## - the view (0x2DE38): the 5x5 squares around the party, top-left at (x-2, y-2), each
##   square's tile drawn at 24-pixel steps from (8, 8); a few squares show another tile
##   while game flags say so (the table at DS:0x0C30, see `tile`).
## - a step (0x16EE3): the target is clamped to the band (x 0..15, y 0..35); open water
##   (0x4E and the coast tiles listed in `water`) stops the party; so does the poisoned
##   river (0x66-0x6C, 0x72) until ECL 0x4AA2 is set (the code holds the line "The river's
##   stench drives you back.", but the lab shows nothing on screen); otherwise the party
##   moves and 12 hours pass.
## - the scripts' CALL 0xC01B / 0xC018 (read or change a square) do nothing in the original
##   (see EclVM); the squares they would change are the view's redrawn ones (`tile`).

const WIDTH := 44
const HEIGHT := 36
const DS_MAP := 0x3648        # the map's offset in the data segment
const DS_OVERRIDES := 0x0C30  # 6-byte entries: x, y, byte (16-bit words); 1..9 used

var cells := PackedByteArray()
var band_left := PackedByteArray()   # left edge of each band (LOAD_AREA_MAP 4, 5, 6)
var overrides: Array[Vector3i] = []  # entry 1..9 -> (x, y, byte); index 0 unused
var tiles: Array[Image] = []         # 256 tiles, RGBA8
## The party's mark (chat 120): ICON.DAX's galloping rider, 24x24, six frames in the order drawn
## (blocks 0, 128, 1, 129, 2, 130), RGBA8 with colour 0 see-through. Empty if the file is missing.
var rider: Array[Image] = []

static var _shared: OverlandMap = null
static var _shared_path := ""


## The game's map, read once per game folder.
static func shared(game_path: String) -> OverlandMap:
	if _shared == null or _shared_path != game_path:
		_shared = OverlandMap.load_from(game_path)
		_shared_path = game_path
	return _shared


static func load_from(game_path: String) -> OverlandMap:
	var o := OverlandMap.new()
	var exe := GameData.read_bytes(game_path.path_join("START.EXE"))
	var image := Exepack.unpack(exe)
	if image.is_empty():
		return null
	# The bands' edges (0, 13, 26) follow the map, whose last rows are open sea (0x4E).
	var end := -1
	for i in range(WIDTH * HEIGHT, image.size() - 3):
		if image[i] == 0 and image[i + 1] == 13 and image[i + 2] == 26 and image[i - 1] == 0x4E \
				and image[i - WIDTH] == 0x4E:
			end = i
			break
	if end < 0:
		return null
	var start := end - WIDTH * HEIGHT
	o.cells = image.slice(start, end)
	o.band_left = image.slice(end, end + 3)
	var ds := start - DS_MAP
	o.overrides.append(Vector3i.ZERO)
	for i in range(1, 10):
		var p := ds + DS_OVERRIDES + i * 6
		o.overrides.append(Vector3i(image.decode_u16(p), image.decode_u16(p + 2), image.decode_u16(p + 4)))
	var dax := DaxFile.open(game_path.path_join("SQRPACI.DAX"))
	if dax == null:
		return null
	for id in [1, 2]:
		var pic := EgaPicture.decode(dax.blocks.get(id, PackedByteArray()))
		if pic == null:
			return null
		for f in pic.frames:
			var t: Image = f.duplicate()
			t.convert(Image.FORMAT_RGBA8)
			o.tiles.append(t)
	o.rider = _load_rider(game_path)
	return o


## GAME.OVR 0x17285 loads ICON blocks 0-2 (and 128-130 beside them) into picture slots 9-11 before the
## wilderness is drawn; 0x2DB87 draws slot 9 + n / 2, picture n % 2, for a counter n (DS:0x6DDC) that steps
## 0..5 at each draw of the view. Colour 0 isn't drawn (lab, chat 120: the original's screen matched pixel
## for pixel at 56,56 with it left out).
static func _load_rider(game_path: String) -> Array[Image]:
	var out: Array[Image] = []
	var dax := DaxFile.open(game_path.path_join("ICON.DAX"))
	if dax == null:
		return out
	for id in [0, 128, 1, 129, 2, 130]:
		var pic := EgaPicture.decode(dax.blocks.get(id, PackedByteArray()))
		if pic == null or pic.frames.is_empty():
			return [] as Array[Image]
		var t: Image = pic.frames[0].duplicate()
		t.convert(Image.FORMAT_RGBA8)
		for y in t.get_height():
			for x in t.get_width():
				var c := t.get_pixel(x, y)
				if c.r8 == 0 and c.g8 == 0 and c.b8 == 0:
					t.set_pixel(x, y, Color(0, 0, 0, 0))
		out.append(t)
	return out


func band_x(band: int) -> int:
	return band_left[clampi(band, 0, band_left.size() - 1)]


## The byte at map square (x, y), counted from the map's left edge.
func value(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return 0x4E
	return cells[y * WIDTH + x]


static func water(v: int) -> bool:
	return v == 0x4E or (v >= 0x7E and v <= 0x80) or (v >= 0x82 and v <= 0x84) \
		or (v >= 0xA8 and v <= 0xAC) or (v >= 0xAE and v <= 0xB3) or v == 0xBC \
		or (v >= 0xDD and v <= 0xDE) or (v >= 0xE1 and v <= 0xE9) or v == 0xF5


static func river(v: int) -> bool:
	return (v >= 0x66 and v <= 0x6C) or v == 0x72


## The tile drawn at (x, y): the byte less one, unless the square is one the original
## redraws while game flags say so (ECL memory read through `mem`):
##   entry 3 while 0x4A8C != 255, entry 4 unless 0x4AD2 = 0 with bit 8 of 0x4A7C clear and
##   0x4A9F set, entry 5 while bit 2 of 0x4AA0 is clear, entry 6 always, entry 7 while
##   bit 1 of 0x4AA0 is clear, entries 8 and 9 once 0x4AB3 > 253 (entries 1, 2 never).
func tile(x: int, y: int, mem: Callable) -> int:
	var t := value(x, y) - 1
	for i in range(1, overrides.size()):
		var o := overrides[i]
		if o.x != x or o.y != y:
			continue
		var on := false
		match i:
			3: on = mem.call(0x4A8C) != 0xFF
			4: on = mem.call(0x4AD2) != 0 or (mem.call(0x4A7C) & 8) != 0 or mem.call(0x4A9F) == 0
			5: on = (mem.call(0x4AA0) & 2) == 0
			6: on = true
			7: on = (mem.call(0x4AA0) & 1) == 0
			8, 9: on = mem.call(0x4AB3) > 0xFD
		if on:
			t = o.z - 1
	return t & 0xFF


## The view's top-left square: two up and left of the party's, kept inside the map (GAME.OVR 0x2DDBF: x 0..39,
## y 0..31). At the map's edges the party is drawn off the middle (0x2DB87 places it the same way).
static func view_origin(cx: int, cy: int) -> Vector2i:
	return Vector2i(clampi(cx - 2, 0, WIDTH - 5), clampi(cy - 2, 0, HEIGHT - 5))


## The 120x120 view around map square (cx, cy): 5x5 squares from view_origin.
func view(cx: int, cy: int, mem: Callable) -> Image:
	var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var o := view_origin(cx, cy)
	for row in 5:
		for col in 5:
			var t := tile(o.x + col, o.y + row, mem)
			if t < tiles.size():
				img.blit_rect(tiles[t], Rect2i(0, 0, 24, 24), Vector2i(col * 24, row * 24))
	return img

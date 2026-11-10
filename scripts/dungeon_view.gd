class_name DungeonView
extends RefCounted
## Renders the 88x88 first-person view the way the Gold Box games compose it:
## a backdrop, then wall pictures at three distances (far, middle, near) and three
## placements (ahead, left side, right side), far to near.
##
## Slot geometry (in 8-pixel tiles, relative to the 11x11-tile view window) follows
## the original screen layout as documented by the ssi-engine project.

const SIZE := 88

enum Dir { NORTH, EAST, SOUTH, WEST }
const DELTA: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# Slot order: ahead (far, middle, near), left (far, middle, near), right (far, middle, near).
# Screen x/y are in tiles on the original 320x200 screen, where the view starts at tile 3.
const START_X := [2, 1, -2, 3, 2, 3, 9, 10, 12]
const START_Y := [7, 6, 4, 6, 4, 3, 6, 4, 3]
const SPACING := [2, 3, 7, 2, 3, 0, 2, 3, 0]
const MAX_HEIGHT := [16, 32, 64, 32, 64, 88, 32, 64, 88]
const VIEW_ORIGIN := 3

## Backdrop colours (EGA indices). Provisional: the real values come from the area scripts.
var sky_color := 11
var ground_color := 6


## Returns the view as colour indices (88 * 88 bytes).
func render(map: GeoMap, walls: WallSet, x: int, y: int, facing: int) -> PackedByteArray:
	var px := PackedByteArray()
	px.resize(SIZE * SIZE)
	_backdrop(px)
	var visible := _visible_walls(map, x, y, facing)
	for distance in 3:          # 0 far, 1 middle, 2 near
		for placement in 3:     # 0 ahead, 1 left, 2 right
			var slot := placement * 3 + distance
			var values: Array = visible[slot]
			var tx: int = START_X[slot]
			for i in values.size():
				var w: int = values[i]
				if w > 0 and w <= walls.walls.size():
					var wall: Dictionary = walls.walls[w - 1]
					_blit_part(px, wall, distance * 3 + placement, tx, slot)
					# Far walls ahead are one tile wide; a filler joins them to the next wall.
					if distance == 0 and placement == 0 and i + 1 < values.size() and values[i + 1] > 0:
						_blit_part(px, wall, WallSet.FILLER, tx + 1, slot)
				tx += SPACING[slot]
	return px


## Converts colour indices to an RGB image.
static func to_image(px: PackedByteArray) -> Image:
	var rgb := PackedByteArray(EgaPicture.PALETTE_RGB)
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 3)
	for i in px.size():
		var c := px[i] * 3
		data[i * 3] = rgb[c]
		data[i * 3 + 1] = rgb[c + 1]
		data[i * 3 + 2] = rgb[c + 2]
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, data)


func _backdrop(px: PackedByteArray) -> void:
	# Sky to row 43, a white and a grey horizon line, then ground.
	for row in SIZE:
		var c := sky_color
		if row == 43:
			c = 15
		elif row == 44 or row == 45:
			c = 7
		elif row > 45:
			c = ground_color
		for col in SIZE:
			px[row * SIZE + col] = c


func _blit_part(px: PackedByteArray, wall: Dictionary, part_index: int, tile_x: int, slot: int) -> void:
	var part: Dictionary = wall.parts[part_index]
	var tiles: Array = wall.tiles
	var size: Vector2i = part.size
	var cells: PackedByteArray = part.cells
	var left := (tile_x - VIEW_ORIGIN) * 8
	# Pictures are bottom-aligned within the slot's height.
	var top: int = (START_Y[slot] - VIEW_ORIGIN) * 8 + MAX_HEIGHT[slot] - size.y * 8
	for ty in size.y:
		for tx in size.x:
			var ti := cells[ty * size.x + tx]
			var tile: PackedByteArray = tiles[ti] if ti < tiles.size() else tiles[0]
			for py in 8:
				var sy := top + ty * 8 + py
				if sy < 0 or sy >= SIZE:
					continue
				for pxl in 8:
					var sx := left + tx * 8 + pxl
					if sx < 0 or sx >= SIZE:
						continue
					var c := tile[py * 8 + pxl]
					if c != WallSet.TRANSPARENT:
						px[sy * SIZE + sx] = c


## Wall values seen from (x, y) facing a direction, per slot (see START_X order).
func _visible_walls(map: GeoMap, x: int, y: int, facing: int) -> Array:
	var left := (facing + 3) % 4
	var right := (facing + 1) % 4
	var f := DELTA[facing]
	var r := DELTA[right]
	# Wall on side `face` of the square `ahead` steps forward and `side` steps to the right.
	var at := func(ahead: int, side: int, face: int) -> int:
		var p := Vector2i(x, y) + f * ahead + r * side
		if p.x < 0 or p.y < 0 or p.x >= GeoMap.SIZE or p.y >= GeoMap.SIZE:
			return 0
		return map.wall(p.x, p.y, face)
	var slots := []
	slots.resize(9)
	slots[0] = [at.call(2, -3, facing), at.call(2, -2, facing), at.call(2, -1, facing), at.call(2, 0, facing),
		at.call(2, 1, facing), at.call(2, 2, facing), at.call(2, 3, facing)]
	slots[1] = [at.call(1, -2, facing), at.call(1, -1, facing), at.call(1, 0, facing),
		at.call(1, 1, facing), at.call(1, 2, facing)]
	slots[2] = [at.call(0, -1, facing), at.call(0, 0, facing), at.call(0, 1, facing)]
	slots[3] = [at.call(2, -2, left), at.call(2, -1, left), at.call(2, 0, left)]
	slots[4] = [at.call(1, -1, left), at.call(1, 0, left)]
	slots[5] = [at.call(0, 0, left)]
	slots[6] = [at.call(2, 0, right), at.call(2, 1, right), at.call(2, 2, right)]
	slots[7] = [at.call(1, 0, right), at.call(1, 1, right)]
	slots[8] = [at.call(0, 0, right)]
	return slots

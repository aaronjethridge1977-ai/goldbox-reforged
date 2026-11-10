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
# Far side walls start at the edge of the middle wall in the same column, so they are
# spaced 3 tiles like the middle walls. (ssi-engine has them 2 tiles apart starting at
# tiles 3 and 9; corrected 2026-11-09 against the original at New Phlan 12,6 W, where the
# far-left wall with the blue door sits at view x 8, not 16.)
const START_X := [2, 1, -2, 1, 2, 3, 9, 10, 12]
const START_Y := [7, 6, 4, 6, 4, 3, 6, 4, 3]
const SPACING := [2, 3, 7, 3, 3, 0, 3, 3, 0]
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
	var size: Vector2i = part["size"]
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
					if show_slots and (ty * 8 + py == 0 or tx * 8 + pxl == 0 \
							or ty * 8 + py == size.y * 8 - 1 or tx * 8 + pxl == size.x * 8 - 1):
						px[sy * SIZE + sx] = 12
					elif c != WallSet.TRANSPARENT:
						px[sy * SIZE + sx] = c


## For each slot (START_X order), the squares it shows: [steps ahead, steps right, face],
## where face 0 = the side facing away from the viewer, 1 = left side, 2 = right side.
const SLOT_CELLS := [
	[[2, -3, 0], [2, -2, 0], [2, -1, 0], [2, 0, 0], [2, 1, 0], [2, 2, 0], [2, 3, 0]],
	[[1, -2, 0], [1, -1, 0], [1, 0, 0], [1, 1, 0], [1, 2, 0]],
	[[0, -1, 0], [0, 0, 0], [0, 1, 0]],
	[[2, -2, 1], [2, -1, 1], [2, 0, 1]],
	[[1, -1, 1], [1, 0, 1]],
	[[0, 0, 1]],
	[[2, 0, 2], [2, 1, 2], [2, 2, 2]],
	[[1, 0, 2], [1, 1, 2]],
	[[0, 0, 2]],
]
const SLOT_NAMES := ["far ahead", "middle ahead", "near ahead", "far left", "middle left", "near left",
	"far right", "middle right", "near right"]
const DIR_NAMES := ["N", "E", "S", "W"]

## Debug: outline every drawn wall piece (colour 12) in the rendered view.
var show_slots := false


## Wall values seen from (x, y) facing a direction, per slot (see START_X order).
func _visible_walls(map: GeoMap, x: int, y: int, facing: int) -> Array:
	var slots := []
	for cells in SLOT_CELLS:
		var values := []
		for c in cells:
			var info := _cell_for(x, y, facing, c)
			var p: Vector2i = info[0]
			var value := 0
			if p.x >= 0 and p.y >= 0 and p.x < GeoMap.SIZE and p.y < GeoMap.SIZE:
				value = map.wall(p.x, p.y, info[1])
			values.append(value)
		slots.append(values)
	return slots


## [square, map side] for a SLOT_CELLS entry.
func _cell_for(x: int, y: int, facing: int, c: Array) -> Array:
	var right := (facing + 1) % 4
	var p: Vector2i = Vector2i(x, y) + DELTA[facing] * int(c[0]) + DELTA[right] * int(c[1])
	var face: int = [facing, (facing + 3) % 4, right][int(c[2])]
	return [p, face]


## Text report of every slot: square, side, wall value and where its picture lands
## in the 88x88 view (x, y, width, height). For comparing against the original.
func report(map: GeoMap, walls: WallSet, x: int, y: int, facing: int) -> String:
	var lines := PackedStringArray()
	lines.append("position %d,%d facing %s" % [x, y, DIR_NAMES[facing]])
	lines.append("slot           i  square  side  wall  view rect (x,y,w,h)")
	var visible := _visible_walls(map, x, y, facing)
	for distance in 3:
		for placement in 3:
			var slot := placement * 3 + distance
			var cells: Array = SLOT_CELLS[slot]
			var tx: int = START_X[slot]
			for i in cells.size():
				var info := _cell_for(x, y, facing, cells[i])
				var p: Vector2i = info[0]
				var w: int = visible[slot][i]
				var rect := ""
				if w > 0 and w <= walls.walls.size():
					var size: Vector2i = walls.walls[w - 1].parts[distance * 3 + placement]["size"]
					var left := (tx - VIEW_ORIGIN) * 8
					var top: int = (START_Y[slot] - VIEW_ORIGIN) * 8 + MAX_HEIGHT[slot] - size.y * 8
					rect = "%d,%d,%d,%d" % [left, top, size.x * 8, size.y * 8]
				lines.append("%-14s %d  %2d,%-2d   %s     %2d    %s" % [
					SLOT_NAMES[slot], i, p.x, p.y, DIR_NAMES[info[1]], w, rect])
				tx += SPACING[slot]
	return "\n".join(lines)

class_name Battlefield
extends RefCounted
## The combat grid: 50 x 25 cells of 24x24 tiles, built from the area map around the party.
##
## The original draws the battlefield in an oblique view. Each map square becomes a block of
## cells: one square east is 6 cells right; one square south is 5 cells down and 5 right, so
## walls running north-south appear as diagonals. The party's square sits at cells
## (21..27, 10..14); the 13 x 5 squares around it (6 each side, 2 north and south) are drawn.
## Within a square's block, rows 0-1 hold its north wall and corners, rows 2-4 its floor
## and west wall.
##
## A side of a square is open, a wall, or a doorway; a side counts as walled if either
## square says so. Beyond the map's edge everything is wall except east and west along the
## party's own row. Tile numbers index the area's combat tile set (DUNGCOM for dungeons
## and towns): 22 is bare floor; 5/10 are the two rows of an east-west wall; 4, 3, 13 make
## the diagonal of a north-south wall; 7/8 and 0 are door posts; the rest are corners.
##
## Checked against two fights in the Slums (13,1 facing west; 14,9 facing south): every
## visible tile matches the original's screen.
##
## Placement uses straightened coordinates: u = x - y, v = y. In (u, v) the grid is square:
## north is v - 1, east is u + 1, and a map square is 6 u by 5 v.

const WIDTH := 50
const HEIGHT := 25
const FLOOR := 22

const OPEN := 0
const WALL := 1
const DOOR := 3

const _DU := [0, 1, 0, -1]   # N E S W in map squares
const _DV := [-1, 0, 1, 0]

var cells := PackedByteArray()
var _map: GeoMap
var _px := 0
var _py := 0


static func build(map: GeoMap, px: int, py: int) -> Battlefield:
	var f := Battlefield.new()
	f._map = map
	f._px = px
	f._py = py
	f.cells.resize(WIDTH * HEIGHT)
	f.cells.fill(FLOOR)
	for dy in range(-2, 3):
		for dx in range(-6, 7):
			f._draw_square(dx, dy)
	return f


## Tiles a combatant can stand on (dungeon/town set): bare floor and the floor-side halves
## of walls and door posts. From the original's tile table as documented by Pilgrim's
## reconstruction (move cost 1; the rest cost 0xFF, impassable); the lab saw a character
## step onto a door post's base (tile 8) in the original.
## The original's ground table (DS:0x2744, 4 bytes a ground id: move cost (1, or 0xFF
## impassable), 0, sight (2 blocks), picture; read in the lab, Combat Chat 3) agrees, and adds
## ground 0x1E and 0x1F (pictures 0x26, 0x27: tiles 38 and 39, cost 1, see-through): 0x1F is a
## fallen party member's square (P40).
const WALKABLE := [4, 8, 10, 12, 14, 16, 22, 23, 34, 35, 36, 37, 38, 39]

## Clutter (GAME.OVR 0x0C5D2, read in side chat 2): when a fight starts, every bare floor cell
## (x 0..49, then y 0..24) rolls d100: 98 pebbles, 99 two stones, 100 a d100 of 1 and then
## d10 1-6 a bone, 7-10 a potted flower (all four walkable). The pictures are RANDCOM.DAX's
## first four (the original's tile ids 0x1A-0x1D, pictures 0x22-0x25: tiles 34-37 here).
## (The original skips the 100 branch when DS:0x84DC is 10; not yet known what that is.)
const CLUTTER := [34, 35, 36, 37]


## `roll` is the fight's die: roll.call(n) gives 1..n.
func scatter(roll: Callable) -> void:
	for x in WIDTH:
		for y in HEIGHT:
			var i := y * WIDTH + x
			if cells[i] != FLOOR:
				continue
			var r: int = roll.call(100)
			if r == 98:
				cells[i] = CLUTTER[0]
			elif r == 99:
				cells[i] = CLUTTER[1]
			elif r == 100 and roll.call(100) == 1:
				cells[i] = CLUTTER[2] if roll.call(10) <= 6 else CLUTTER[3]


func walkable(x: int, y: int) -> bool:
	return tile(x, y) in WALKABLE


func tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return -1
	return cells[y * WIDTH + x]


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT


## Cell of the top-left of map square (party + dx, party + dy).
static func square_origin(dx: int, dy: int) -> Vector2i:
	return Vector2i(dx * 6 + dy * 5 + 21, dy * 5 + 10)


static func to_cell(u: int, v: int) -> Vector2i:
	return Vector2i(u + v, v)


static func to_uv(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - cell.y, cell.y)


# --- Sides ------------------------------------------------------------------------------

func _own_side(x: int, y: int, side: int) -> int:
	if x < 0 or y < 0 or x >= GeoMap.SIZE or y >= GeoMap.SIZE:
		if y == _py and (side == GeoMap.Side.EAST or side == GeoMap.Side.WEST):
			return OPEN
		return WALL
	if _map.wall(x, y, side) == 0:
		return OPEN
	return DOOR if _map.door(x, y, side) != 0 else WALL


## A side as both squares see it.
func side(x: int, y: int, s: int) -> int:
	return _own_side(x, y, s) | _own_side(x + _DU[s], y + _DV[s], (s + 2) % 4)


# --- Drawing a square -------------------------------------------------------------------

func _put(o: Vector2i, row: int, col: int, t: int) -> void:
	var x := o.x + col
	var y := o.y + row
	if in_bounds(x, y):
		cells[y * WIDTH + x] = t


func _draw_square(dx: int, dy: int) -> void:
	var x := _px + dx
	var y := _py + dy
	var o := square_origin(dx, dy)
	var n := side(x, y, GeoMap.Side.NORTH)
	var e := side(x, y, GeoMap.Side.EAST)
	var w := side(x, y, GeoMap.Side.WEST)

	# Floor, and the west wall as a diagonal (or door posts)
	for row in range(2, 5):
		for col in 6:
			_put(o, row, col, FLOOR)
	if w == WALL:
		for row in range(2, 5):
			_put(o, row, row - 1, 4)
			_put(o, row, row, 3)
			_put(o, row, row + 1, 13)
	elif w == DOOR:
		_put(o, 2, 1, 8)
		_put(o, 4, 5, 0)

	# North wall, middle
	var top := 5 if n == WALL else FLOOR
	var bottom := 10 if n == WALL else FLOOR
	for col in [3, 4]:
		_put(o, 0, col, top)
		_put(o, 1, col, bottom)

	# North-west corner: does anything else meet there?
	var nw_clear := side(x, y - 1, GeoMap.Side.WEST) == OPEN and side(x - 1, y, GeoMap.Side.NORTH) == OPEN
	var a: int
	if n == OPEN:
		a = FLOOR if w == OPEN else (13 if w == DOOR else (0 if nw_clear else 13))
	elif w == OPEN:
		a = 15 if nw_clear else 5
	else:
		a = 18 if nw_clear else 2
	var b: int = {OPEN: FLOOR, DOOR: 17, WALL: 5}[n]
	var c: int
	if w == OPEN:
		c = FLOOR if n == OPEN else (16 if nw_clear else 10)
	elif w == DOOR:
		c = 20 if nw_clear else 7
	else:
		c = 1 if nw_clear else 3
	var d: int
	if w == WALL:
		d = {OPEN: 13, DOOR: 21, WALL: 6}[n]
	else:
		d = {OPEN: FLOOR, DOOR: 23, WALL: 10}[n]
	_put(o, 0, 1, a)
	_put(o, 0, 2, b)
	_put(o, 1, 1, c)
	_put(o, 1, 2, d)

	# North-east corner: the east side of the square to the north, and the north side of
	# the square to the east
	var ne := side(x, y - 1, GeoMap.Side.EAST)
	var en := side(x + 1, y, GeoMap.Side.NORTH)
	var f5: int
	var f6: int
	var g5: int
	var g6: int
	if n == OPEN:
		f5 = 4 if ne == WALL else FLOOR
		g5 = FLOOR
		if ne == OPEN:
			f6 = FLOOR
			g6 = FLOOR
		else:
			if ne == DOOR:
				f6 = 24 if (e == OPEN and en != OPEN) else 1
			elif e == OPEN:
				f6 = 11 if en != OPEN else 7
			else:
				f6 = 3
			if e != OPEN:
				g6 = 4
			else:
				g6 = 8 if en == OPEN else 12
	else:
		f5 = 15 if n == DOOR else 5
		g5 = 16 if n == DOOR else 10
		if e != OPEN:
			f6 = 9
			g6 = 14
		elif en != OPEN:
			f6 = 5
			g6 = 10
		else:
			f6 = 17 if ne == OPEN else 19
			g6 = 23
	_put(o, 0, 5, f5)
	_put(o, 0, 6, f6)
	_put(o, 1, 5, g5)
	_put(o, 1, 6, g6)

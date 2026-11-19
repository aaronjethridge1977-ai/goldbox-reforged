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
## The original skips the 100 branch, with no more draws, when DS:0x84DC is 10: its copy of
## the area's ECL block (0x49F2; Combat Chat 5: 4:10, the graveyard's spectres, matched only so).
const CLUTTER := [34, 35, 36, 37]


## `roll` is the fight's die: roll.call(n) gives 1..n. `no_bones`: the area's block is 10.
func scatter(roll: Callable, no_bones: bool = false) -> void:
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
			elif r == 100 and not no_bones and roll.call(100) == 1:
				cells[i] = CLUTTER[2] if roll.call(10) <= 6 else CLUTTER[3]


# --- The wilderness field (Combat Chat 30) -----------------------------------------------
#
# GAME.OVR 0xD8A2 builds the dungeon field (0xCDE1) when the view DS:0x49FA is 1 and the
# wilderness one (0xD785) otherwise (2-4: the bands 6:25, 7:26, 8:27). The field holds ground
# ids; ground 0x20-0x41 show WILDCOM.DAX block 1's pictures 0x00-0x21 and ground 0x17 its
# picture 0x16 (START.EXE's ground table DS:0x2744, 4 bytes an id: move cost 1 or 0xFF, 0,
# sight 0 or 2 (2 blocks the line walk 0x2FF74), picture). Cells here keep the picture, as
# for the dungeon: ground 0x17 and 0x36 (both "01 00 00 16") are both 22 = FLOOR.
# 0xD785: fill with 0x17; the terrain byte DS:0x465A = the overland map's byte at the party's
# band square (ECL 0x49C3 + the band's edge, 0x49C4; OverlandMap); then the river 0xD1AF, the
# trees 0xD2E4, the ground scatter 0xD46F, then the clutter 0xC5D1 (scatter above).

## Pictures a figure can stand on outdoors (cost 1): WILDCOM 4-7, 10-17, 20-22, 25-27, 32 and
## RANDCOM's six.
const WILD_WALKABLE := [4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 25, 26, 27, 32,
		34, 35, 36, 37, 38, 39]
## Pictures the line walk sees through outdoors (sight 0): the walkable ones and the river
## (18, 19) and the other impassable low ground (8, 9, 23, 24, 28).
const WILD_CLEAR := [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
		25, 26, 27, 28, 32, 34, 35, 36, 37, 38, 39]

## GAME.OVR 0xCE75: the terrain byte's flags (a chain of range tests, run by the lab's
## combat30/ce75.py on every byte). 0x02 light woods, 0x04 woods, 0x08 forest, 0x10 / 0x20 a
## river's chance, 0x40 its own trees, 0x80 bare. Bytes no case covers (0x00, 0x05, 0x86, 0xBB,
## 0xF7-0xF9, 0xFB, 0xFD-0xFF) leave the result unset (a stack byte): 0 here.
const TERRAIN_FLAGS := [
	0x00, 0x01, 0x01, 0x03, 0x03, 0x00, 0x03, 0x03, 0x03, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,   # 0x00
	0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x02, 0x03, 0x03, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,   # 0x10
	0x02, 0x02, 0x02, 0x02, 0x02, 0x04, 0x41, 0x05, 0x01, 0x01, 0x05, 0x01, 0x05, 0x44, 0x44, 0x40,   # 0x20
	0x40, 0x40, 0x40, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x04, 0x48, 0x48, 0x48, 0x08, 0x08, 0x08,   # 0x30
	0x04, 0x48, 0x48, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x20, 0x01,   # 0x40
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x88, 0x88, 0x88, 0x88, 0x01, 0x01, 0x44, 0x44, 0x44,   # 0x50
	0x44, 0x44, 0x40, 0x40, 0x40, 0x40, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x80, 0x81, 0x81,   # 0x60
	0x81, 0x81, 0x90, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x08, 0x08, 0x08, 0x08, 0x09, 0x28, 0x28,   # 0x70
	0x28, 0x28, 0x28, 0x28, 0x28, 0x28, 0x00, 0x08, 0x08, 0x08, 0x09, 0x08, 0x09, 0x08, 0x09, 0x09,   # 0x80
	0x08, 0x08, 0x08, 0x08, 0x09, 0x08, 0x09, 0x08, 0x08, 0x05, 0x04, 0x04, 0x04, 0x04, 0x04, 0x05,   # 0x90
	0x08, 0x08, 0x08, 0x88, 0x04, 0x04, 0x08, 0x08, 0x21, 0x21, 0x21, 0x21, 0x21, 0x21, 0x21, 0x21,   # 0xA0
	0x21, 0x21, 0x60, 0x60, 0x04, 0x14, 0x14, 0x14, 0x14, 0x11, 0x14, 0x00, 0x11, 0x11, 0x11, 0x11,   # 0xB0
	0x11, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,   # 0xC0
	0x02, 0x12, 0x12, 0x12, 0x12, 0x12, 0x08, 0x08, 0x08, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,   # 0xD0
	0x88, 0xA0, 0xA0, 0xA0, 0xA0, 0x28, 0x28, 0x28, 0x20, 0x20, 0xA0, 0xA0, 0xA0, 0xA0, 0x08, 0x04,   # 0xE0
	0x04, 0x01, 0x40, 0x04, 0x80, 0x20, 0x80, 0x00, 0x00, 0x00, 0x04, 0x00, 0x04, 0x00, 0x00, 0x00,   # 0xF0
]

var outdoors := false


## The flags of the terrain byte (0xCE75 with its end, 0xD139): a bare terrain (0x80) counts
## as 0x01 instead while ECL word 0x4AB3 ([0x49D2] + 0x366) is 0xFF.
static func terrain_flags(terrain: int, ecl_4ab3: int) -> int:
	var f: int = TERRAIN_FLAGS[terrain & 0xFF]
	if f & 0x80 and ecl_4ab3 == 0xFF:
		f = (f - 0x80) | 0x01
	return f


## Turns this field into the wilderness one (0xD785, before the clutter): `flags` from
## terrain_flags, `roll` the fight's die (1..n). The map squares (side) stay as built.
func make_wild(flags: int, roll: Callable) -> void:
	outdoors = true
	cells.fill(FLOOR)
	_river(flags, roll)
	_trees(flags, roll)
	_wild_scatter(flags, roll)


## A cell's ground is open (ground table class 0x16: ground 0x17 or 0x36).
func _open(x: int, y: int) -> bool:
	return cells[y * WIDTH + x] == FLOOR


## Sets ground id g (0x20-0x41) at the flat index i (the original indexes y * 50 + x, so x 50
## is the next row's first cell; past the field's end nothing is written).
func _ground(i: int, g: int) -> void:
	if i >= 0 and i < cells.size():
		cells[i] = g - 0x20


## 0xD1AF: a river (ground 0x32 / 0x33, impassable, seen across) running down and right one
## cell a row from a start column 12, 19 or 26, with fords (0x34 / 0x35, 0xD168) where a d20
## comes up 1 and on the row after each; with no ford, one at row 16 - d9.
func _river(flags: int, roll: Callable) -> void:
	var chance := 0
	if flags & 0x20:
		chance = 0x23
	if flags & 0x10:
		chance = 0x4B
	if roll.call(100) > chance:
		return
	var x := 0x22
	for k in 5:
		x -= roll.call(4)
	while (x + 2) % 7 > 0:
		x -= 1
	var start := x
	var fords := 0
	for y in 25:
		if x <= 0x31:
			_ground(y * WIDTH + x, 0x32)
			_ground(y * WIDTH + x + 1, 0x33)
			if roll.call(20) == 1 or fords & 1:
				_ground(y * WIDTH + x, 0x34)
				_ground(y * WIDTH + x + 1, 0x35)
				fords += 1
			x += 1
	if fords == 0:
		var y: int = 16 - roll.call(9)
		x = start + y
		_ground(y * WIDTH + x, 0x34)
		_ground(y * WIDTH + x + 1, 0x35)
		_ground((y + 1) * WIDTH + x + 1, 0x34)
		_ground((y + 1) * WIDTH + x + 2, 0x35)


## 0xD2E4: trees on two open cells one above the other; the density (d100 at most) 1, 3 for
## 0x04, 4 for 0x40, 7 for 0x08, none for 0x80 (later flags win).
func _trees(flags: int, roll: Callable) -> void:
	var dens := 1
	if flags & 0x04:
		dens = 3
	if flags & 0x40:
		dens = 4
	if flags & 0x08:
		dens = 7
	if flags & 0x80:
		dens = 0
	for x in WIDTH:
		for y in range(1, HEIGHT):
			if not _open(x, y) or not _open(x, y - 1):
				continue
			if roll.call(100) > dens:
				continue
			var k: int = roll.call(10)
			k = 4 + roll.call(2) if k > 8 else (k + 1) / 2
			if flags & 0x40:
				k = 3 + roll.call(3)
			_ground(y * WIDTH + x, 0x1F + 4 + k)
			if k < 5:
				_ground((y - 1) * WIDTH + x, 0x1F + k)


## 0xD46F: each open cell draws a d255 for the ground's small things.
func _wild_scatter(flags: int, roll: Callable) -> void:
	var a := 0
	var b := 6
	var c := 0x0F
	var d := 0x28
	var e := 0
	if flags & 0x02:
		c = 0x2D
		d = 0x0A
	if flags & 0x04:
		c = 0x19
	if flags & 0x40:
		d = 5
		e = 0x1E
	if flags & 0x80:
		a = 0x0F
		d = 0x19
		c = 0x0A
	for x in WIDTH:
		for y in HEIGHT:
			if not _open(x, y):
				continue
			var i := y * WIDTH + x
			var r: int = roll.call(255)
			if r <= a:
				var k: int = roll.call(4)
				if k == 4 and y > 0 and _open(x, y - 1):
					_ground(i - WIDTH, 0x41)
					_ground(i, 0x40)
				if k < 4:
					_ground(i, 0x3C + k)
			elif r <= a + b:
				_ground(i, 0x36 + roll.call(3))
			elif r <= a + b + c:
				_ground(i, 0x29 + roll.call(4))
			elif r <= a + b + c + e:
				_ground(i, 0x38 + (roll.call(10) - 1) / 3 + 1)
			elif r <= a + b + c + e + d:
				var k: int = roll.call(4)
				if k == 4 and not flags & 0x40:
					k = roll.call(3)
				_ground(i, 0x2D + k)


func walkable(x: int, y: int) -> bool:
	if outdoors:
		return tile(x, y) in WILD_WALKABLE
	return tile(x, y) in WALKABLE


## The line walk's test (0x2FF74: the ground's sight byte): as walkable but outdoors, where
## the river and some low ground block a step, not the view.
func see_through(x: int, y: int) -> bool:
	if outdoors:
		return tile(x, y) in WILD_CLEAR
	return walkable(x, y)


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


## A side as both squares see it. Outdoors there are no walls (the wilderness field has no map).
func side(x: int, y: int, s: int) -> int:
	if outdoors:
		return OPEN
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

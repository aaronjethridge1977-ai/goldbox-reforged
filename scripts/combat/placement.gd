class_name Placement
extends RefCounted
## Where each side starts a fight.
##
## Each team has an anchor square: the party's own square, and for the monsters the square
## `distance` squares ahead (the encounter distance: open squares ahead of the party, at most
## 2 indoors, capped by the event's own maximum; 2 outdoors). Around its anchor a team
## places its members in a slot grid of 11 x 6 cells, cell = (col + 6 sx + 5 sy + 22,
## row + 5 sy + 10) for anchor (sx, sy) relative to the party. Only the slots inside the
## facing's footprint are used (SLOT_SPAN: first and last column per row).
##
## Lines: the first line starts at the facing's base slot and alternates outwards to the
## right and left of it (along the facing's sideways diagonal), holding half the team
## (rounded up); later lines step back one cell each and hold up to 11 tries. A party
## facing east or west leaves one empty line after its front line when any side of its
## square (other than the front) is open. If the lines run off the grid, the team tries
## its alternative anchors: one square to each side or behind, if that side is open, with
## their own base slots. A slot is used only if its cell is free and one a figure can stand
## on (Battlefield.WALKABLE: floor and the floor-side halves of walls and door posts); for a
## large creature every cell it fills must be (Combat.FOOTPRINT, from the slot's cell).
##
## Learned from the original's behaviour as documented by Simeon Pilgrim's reconstruction
## of the engine (tables of base slots and footprints), and checked against the original:
## the Slums fights at 13,1 W (4 orcs, distance 0), 13,7 W (6 orcs, distance 2) and
## 14,6 S (6 kobolds, distance 1) match cell for cell. Large monsters (lab, chat 8): the
## Slums' event 20 at 0,14 N (2 ogres, 4 trolls, distance 0) matches every figure the
## original shows: ogres at 25,11 and 26,11, trolls at 27,11 (its top cell is a wall's
## floor-side half), 24,10 and 25,9; bare floor alone had left the trolls in one diagonal.

# The eight directions in combat cells (0 = north, clockwise). On the slanted battlefield
# map north is up-left, east is right, south is down-right, west is left.
const DX := [0, 1, 1, 1, 0, -1, -1, -1]
const DY := [-1, -1, 0, 1, 1, 1, 0, -1]
## Map facing (0..3 = N E S W) to combat direction.
const FACING_TO_DIR := [7, 2, 3, 6]
## Base slot per facing; entries 4..7 for alternative anchors.
const BASE_COL := [5, 4, 5, 6, 3, 8, 7, 2]
const BASE_ROW := [3, 2, 2, 3, 0, 2, 5, 3]
## Usable columns [first, last] for each of the 6 slot rows: one table per facing, and a
## fifth for an alternative anchor behind the team.
const SLOT_SPAN := [
	[[1, 0], [1, 0], [1, 0], [2, 9], [3, 10], [4, 10]],
	[[0, 2], [0, 3], [1, 4], [2, 5], [3, 6], [4, 7]],
	[[0, 6], [0, 7], [1, 8], [1, 0], [1, 0], [1, 0]],
	[[3, 6], [4, 7], [5, 8], [6, 9], [7, 10], [8, 10]],
	[[0, 6], [0, 7], [1, 8], [2, 9], [3, 10], [4, 10]],
]
## Alternative anchors per team facing: the map facing (0..3) of the neighbouring square
## to use, for tries 1..3 (try 0 is the anchor itself).
const ALT_SIDE := [[-1, 2, 3, 1], [-1, 3, 2, 0], [-1, 0, 3, 1], [-1, 1, 0, 2]]
## Facing used for the lines at each try.
const ALT_FACING := [[0, 0, 1, 3], [1, 1, 0, 2], [2, 2, 1, 3], [3, 3, 2, 0]]
const SQUARE_STEP := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var _field: Battlefield
var _px := 0
var _py := 0
var _used := {}


func _init(field: Battlefield, px: int, py: int) -> void:
	_field = field
	_px = px
	_py = py


## Encounter distance from (px, py) facing `facing`: open squares ahead, at most `maximum`
## (and at most 2). Outdoors it is 2.
static func encounter_distance(field: Battlefield, px: int, py: int, facing: int, maximum: int = 2,
		outdoors: bool = false) -> int:
	var d := 2
	if not outdoors:
		d = 0
		var x := px
		var y := py
		while d < 2 and field.side(x, y, facing) == Battlefield.OPEN:
			d += 1
			x += SQUARE_STEP[facing].x
			y += SQUARE_STEP[facing].y
	return mini(d, maximum)


## Places `count` members of a team facing `facing` (map facing 0..3) whose anchor is
## `anchor` squares from the party. Returns their cells (Vector2i(-1, -1) if one finds no
## room). Call for the party first, then the monsters, on the same Placement. `sizes`
## gives each member's footprint (Combat.foot_size); missing entries count as 1.
func place_team(count: int, facing: int, anchor: Vector2i, is_party: bool,
		sizes: Array = []) -> Array[Vector2i]:
	var free := []
	for t in 4:
		var span: Array = SLOT_SPAN[4 if t == 1 else facing]
		var slots := {}
		for row in 6:
			for col in range(span[row][0], span[row][1] + 1):
				slots[Vector2i(col, row)] = true
		free.append(slots)
	var half := (count + 1) / 2
	var out: Array[Vector2i] = []
	for i in count:
		out.append(_place_one(facing, anchor, is_party, half, free,
			int(sizes[i]) if i < sizes.size() else 1))
	return out


func _place_one(facing: int, anchor: Vector2i, is_party: bool, half: int, free: Array,
		fp: int = 1) -> Vector2i:
	var state := 0           # 0 = start a line, 1 = next to the right, 2 = next to the left
	var line := 0
	var reach := 0
	var tries := 0           # 0 = the anchor itself, 1..3 = alternative anchors
	var first_line := true
	var visited := 0
	var square := anchor
	var base := Vector2i.ZERO
	var cur := Vector2i.ZERO
	for guard in 4000:   # a team that doesn't fit would otherwise search forever
		var f: int = ALT_FACING[facing][tries]
		match state:
			0:
				var back: int = FACING_TO_DIR[(f + 2) % 4]
				var b := (4 if tries > 0 else 0) + f
				base = Vector2i(BASE_COL[b] + line * DX[back], BASE_ROW[b] + line * DY[back])
				cur = base
				reach = 1
				visited = 1
				state = 1
			1:
				var right: int = FACING_TO_DIR[(f + 1) % 4]
				cur = base + Vector2i(DX[right], DY[right]) * reach
				visited += 1
				state = 2
			2:
				var left: int = FACING_TO_DIR[(f + 3) % 4]
				cur = base + Vector2i(DX[left], DY[left]) * reach
				reach += 1
				visited += 1
				state = 1
		var col_ok := cur.x >= 0 and cur.x <= 10
		var row_ok := cur.y >= 0 and cur.y <= 5
		var outside := not (col_ok and row_ok)
		var lost := not col_ok and not row_ok
		if (outside and not lost) or (first_line and visited >= half) or (not first_line and visited > 11):
			line += 1
			if is_party and facing % 2 == 1 and tries == 0 and line == 1:
				for t in range(1, 4):
					if _side_of(anchor, ALT_SIDE[facing][t]) != Battlefield.WALL:
						line += 1
						break
			state = 0
			first_line = false
		if lost:
			var found := false
			while tries < 3 and not found:
				tries += 1
				var side: int = ALT_SIDE[facing][tries]
				if _side_of(anchor, side) != Battlefield.WALL:
					square = anchor + SQUARE_STEP[side]
					line = 0
					state = 0
					found = true
			if not found:
				return Vector2i(-1, -1)
			continue
		if not outside and free[tries].has(cur):
			var cell := Vector2i(cur.x + square.x * 6 + square.y * 5 + 22, cur.y + square.y * 5 + 10)
			var foot := Combat.cells_at(cell, fp)
			var ok := true
			for p in foot:
				if not _field.tile(p.x, p.y) in Battlefield.WALKABLE or _used.has(p):
					ok = false
			if ok:
				free[tries].erase(cur)
				for p in foot:
					_used[p] = true
				return cell
	return Vector2i(-1, -1)


func _side_of(square: Vector2i, side: int) -> int:
	return _field.side(_px + square.x, _py + square.y, side)

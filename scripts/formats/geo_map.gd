class_name GeoMap
extends RefCounted
## Decoder for Gold Box area maps (GEO*.DAX blocks, 1,026 bytes each).
##
## Layout:
##   u8[2]      header (always 00 04 in Pool of Radiance; meaning unknown)
##   u8[256]    north wall (high nibble) and east wall (low nibble), one byte per cell, row-major 16x16
##   u8[256]    south wall (high nibble) and west wall (low nibble)
##   u8[256]    per-cell flags (bit 7 plus a small value; meaning not yet known)
##   u8[256]    doors, 2 bits per side: bits 0-1 north, 2-3 east, 4-5 south, 6-7 west
##
## A wall value of 0 means open; 1-15 selects a wall graphic from the area's WALLDEF set.
## Side assignment was confirmed statistically: a cell's east side matches its neighbour's
## west side 84% of the time for walls and 92% for doors (Gold Box walls can be one-sided).

const SIZE := 16
const BLOCK_SIZE := 1026

## Area names by block id. GEO, ECL (events) and WALLDEF/8X8D (graphics) share block ids.
## 0 confirmed by Jeremy against the cluebook; the rest are named in the area's own event text.
const AREA_NAMES := {
	0: "New Phlan",
	1: "Buccaneer base",
	10: "Graveyard",
	20: "Slums",
	21: "Sokal Keep",
	28: "Zhentil Outpost",
	29: "Kuto's Well",
}

enum Side { NORTH, EAST, SOUTH, WEST }

var header: PackedByteArray
## walls[side][y * 16 + x] -> 0..15
var walls: Array[PackedByteArray] = []
## doors[side][y * 16 + x] -> 0..3
var doors: Array[PackedByteArray] = []
## flags[y * 16 + x] -> raw byte
var flags: PackedByteArray


static func decode(block: PackedByteArray) -> GeoMap:
	if block.size() != BLOCK_SIZE:
		return null
	var m := GeoMap.new()
	m.header = block.slice(0, 2)
	m.flags = block.slice(2 + 512, 2 + 768)
	var n := SIZE * SIZE
	var wn := PackedByteArray(); wn.resize(n)
	var we := PackedByteArray(); we.resize(n)
	var ws := PackedByteArray(); ws.resize(n)
	var ww := PackedByteArray(); ww.resize(n)
	var dn := PackedByteArray(); dn.resize(n)
	var de := PackedByteArray(); de.resize(n)
	var ds := PackedByteArray(); ds.resize(n)
	var dw := PackedByteArray(); dw.resize(n)
	for i in SIZE * SIZE:
		var a := block[2 + i]
		var b := block[2 + 256 + i]
		var door := block[2 + 768 + i]
		wn[i] = a >> 4
		we[i] = a & 15
		ws[i] = b >> 4
		ww[i] = b & 15
		dn[i] = door & 3
		de[i] = (door >> 2) & 3
		ds[i] = (door >> 4) & 3
		dw[i] = (door >> 6) & 3
	m.walls.assign([wn, we, ws, ww])
	m.doors.assign([dn, de, ds, dw])
	return m


func wall(x: int, y: int, side: int) -> int:
	return walls[side][y * SIZE + x]


func door(x: int, y: int, side: int) -> int:
	return doors[side][y * SIZE + x]


func set_door(x: int, y: int, side: int, value: int) -> void:
	doors[side][y * SIZE + x] = value


func flag(x: int, y: int) -> int:
	return flags[y * SIZE + x]

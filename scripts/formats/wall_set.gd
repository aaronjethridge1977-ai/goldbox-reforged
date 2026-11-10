class_name WallSet
extends RefCounted
## The wall graphics an area uses in the first-person view.
##
## WALLDEF blocks hold walls of 156 bytes each. Every byte is an index into the area's
## 8x8 tile list, and the 156 bytes are ten tile grids, one per view slot:
##   far ahead 1x2, far left 1x4, far right 1x4, middle ahead 3x4, middle left 2x8,
##   middle right 2x8, near ahead 7x8, near left 2x11, near right 2x11, far filler 1x2
## (width x height in tiles, rows top to bottom).
##
## Tile list: index 0 is a fully transparent tile, then the 45 shared tiles in
## 8X8D1.DAX block 203, then the area's own tiles (8X8D block with the WALLDEF id;
## sets of 15 walls add blocks 10*id+1..3, with id 0 counted as 10).
## Colour 13 (light magenta) is transparent in wall tiles.
##
## Layout from the ssi-engine project's documentation of the format; verified by
## rendering New Phlan (WALLDEF3 block 0, 15 walls, 256 tiles).

const TRANSPARENT := 13
const PART_SHAPES: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(1, 4), Vector2i(1, 4),
	Vector2i(3, 4), Vector2i(2, 8), Vector2i(2, 8),
	Vector2i(7, 8), Vector2i(2, 11), Vector2i(2, 11),
	Vector2i(1, 2),
]
const FILLER := 9
const BYTES_PER_WALL := 156

## walls[w] -> {"tiles": Array[PackedByteArray] (64 colour indices each, the tile list
## of the block the wall came from), "parts": [{"size": Vector2i, "cells": PackedByteArray}] x 10}
var walls: Array = []


## Builds the wall set from WALLDEF<file_no>.DAX, using the given block ids in order
## (each block adds 5 or 15 walls; map wall values 1..15 index into the result).
static func build(game_path: String, file_no: int, wall_ids: Array) -> WallSet:
	var ws := WallSet.new()
	var walldef := DaxFile.open(game_path.path_join("WALLDEF%d.DAX" % file_no))
	var tilesets := DaxFile.open(game_path.path_join("8X8D%d.DAX" % file_no))
	var shared := DaxFile.open(game_path.path_join("8X8D1.DAX"))
	if walldef == null or tilesets == null or shared == null:
		return null
	for id in wall_ids:
		if not walldef.blocks.has(id):
			continue
		var data: PackedByteArray = walldef.blocks[id]
		var count := data.size() / BYTES_PER_WALL
		# Each WALLDEF block indexes its own tile list.
		var tiles: Array[PackedByteArray] = [_transparent_tile()]
		tiles.append_array(_tiles_from(shared.blocks.get(203, PackedByteArray())))
		tiles.append_array(_tiles_from(tilesets.blocks.get(id, PackedByteArray())))
		if count > 5:
			var base: int = 10 * (id if id != 0 else 10)
			for extra in [base + 1, base + 2, base + 3]:
				tiles.append_array(_tiles_from(tilesets.blocks.get(extra, PackedByteArray())))
		for w in count:
			var parts := []
			var o := w * BYTES_PER_WALL
			for shape in PART_SHAPES:
				var n := shape.x * shape.y
				parts.append({"size": shape, "cells": data.slice(o, o + n)})
				o += n
			ws.walls.append({"tiles": tiles, "parts": parts})
	return ws


static func _transparent_tile() -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(64)
	t.fill(TRANSPARENT)
	return t


## Splits an 8x8 tile-set picture block into colour-index tiles.
static func _tiles_from(block: PackedByteArray) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if not EgaPicture.is_picture(block) or block.decode_u16(0) != 8 or block.decode_u16(2) != 1:
		return out
	var count := block.decode_u8(8)
	for f in count:
		var t := PackedByteArray()
		t.resize(64)
		var start := EgaPicture.HEADER_SIZE + f * 32
		for i in 32:
			var b := block[start + i]
			t[i * 2] = b >> 4
			t[i * 2 + 1] = b & 15
		out.append(t)
	return out

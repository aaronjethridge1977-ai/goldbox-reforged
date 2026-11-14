class_name CombatArt
extends RefCounted
## Pictures for the combat screen: the battlefield tiles and combatant icons.
##
## Tiles: DUNGCOM.DAX block 1 (25 tiles, dungeons and towns) or WILDCOM.DAX block 1 (34,
## outdoors), 24x24 each. In combat the original swaps colours 0 and 8: the black of the
## art shows as the dark grey of the field, and dark grey becomes black (wall mortar).
##
## Icons, 24x24 (some 24x48 or 48x48), colour 0 transparent; block + 128 is the attack pose:
##   Monsters: CPIC<area>.DAX, block = the monster's block id in MON<area>CHA.
##   Characters: the body from CBODY.DAX (record 0xBE) with the head from CHEAD.DAX (0xBD)
##   laid over it; normal-sized characters (record 0xC0 = 2) use blocks + 64. Six colour
##   bytes (0xC1..0xC6) recolour the icon: for the six base colours 1, 2, 3, 4, 6, 7, the
##   low nibble replaces the colour itself and the high nibble its bright twin (+8).

const COMBAT_SWAP := {0: 8, 8: 0}
const BASE_COLOURS := [1, 2, 3, 4, 6, 7]

var tiles: Array[Image] = []
var _game_path := ""
var _cache := {}


static func load_set(game_path: String, outdoors: bool = false) -> CombatArt:
	var art := CombatArt.new()
	art._game_path = game_path
	var dax := DaxFile.open(game_path.path_join("WILDCOM.DAX" if outdoors else "DUNGCOM.DAX"))
	if dax and dax.blocks.has(1):
		for px in _frames(dax.blocks[1]):
			art.tiles.append(_to_image(px, 24, 24, false))
	# RANDCOM.DAX's six pictures (clutter, see Battlefield.CLUTTER) follow at 34.
	art.tiles.resize(maxi(art.tiles.size(), 34))
	var rnd := DaxFile.open(game_path.path_join("RANDCOM.DAX"))
	if rnd and rnd.blocks.has(1):
		for px in _frames(rnd.blocks[1]):
			art.tiles.append(_to_image(px, 24, 24, false))
	return art


func tile(t: int) -> Image:
	return tiles[t] if t >= 0 and t < tiles.size() else null


## Icon for a monster of MON<file_no>CHA block `id`.
func monster_icon(file_no: int, id: int, attack: bool = false) -> Image:
	var key := "m%d:%d:%d" % [file_no, id, int(attack)]
	if _cache.has(key):
		return _cache[key]
	var img: Image = null
	var dax := _dax("CPIC%d.DAX" % file_no)
	var block := id + (128 if attack else 0)
	if dax and dax.blocks.has(block):
		var b: PackedByteArray = dax.blocks[block]
		var frames := _frames(b)
		if not frames.is_empty():
			img = _to_image(frames[0], b.decode_u16(2) * 8, b.decode_u16(0), true)
	_cache[key] = img
	return img


## Icon for a party character, built from body, head and colours.
func character_icon(m: PartyMember, attack: bool = false) -> Image:
	var key := "c%s:%d" % [m.name, int(attack)]
	if _cache.has(key):
		return _cache[key]
	var img := record_icon(m.raw, attack)
	_cache[key] = img
	return img


## The icon a character record describes (no caching: the icon editor changes it).
func record_icon(d: PackedByteArray, attack: bool = false) -> Image:
	var offset := (64 if d[0xC0] == 2 else 0) + (128 if attack else 0)
	var body_dax := _dax("CBODY.DAX")
	var head_dax := _dax("CHEAD.DAX")
	var img: Image = null
	if body_dax and body_dax.blocks.has(d[0xBE] + offset):
		var bb: PackedByteArray = body_dax.blocks[d[0xBE] + offset]
		var w := bb.decode_u16(2) * 8
		var h := bb.decode_u16(0)
		var px: PackedByteArray = _frames(bb)[0]
		if head_dax and head_dax.blocks.has(d[0xBD] + offset):
			var hb: PackedByteArray = head_dax.blocks[d[0xBD] + offset]
			var hw := hb.decode_u16(2) * 8
			var hh := hb.decode_u16(0)
			var hp: PackedByteArray = _frames(hb)[0]
			for y in mini(hh, h):
				for x in mini(hw, w):
					var c := hp[y * hw + x]
					if c != 0:
						var under := px[y * w + x]
						px[y * w + x] = c if under == 0 else (under | c)
		# Recolour
		var remap := PackedByteArray()
		for i in 16:
			remap.append(i)
		for i in 6:
			var cb := d[0xC1 + i]
			remap[BASE_COLOURS[i]] = cb & 15
			remap[BASE_COLOURS[i] + 8] = cb >> 4
		for i in px.size():
			if px[i] != 0:
				px[i] = remap[px[i]]
		img = _to_image(px, w, h, true)
	return img


## Block ids (below 64) a part file has: the choices the icon editor steps through.
func part_ids(file_name: String) -> Array[int]:
	var out: Array[int] = []
	var dax := _dax(file_name)
	if dax != null:
		for id in dax.ids():
			if id < 64:
				out.append(id)
	out.sort()
	return out


func _dax(file_name: String) -> DaxFile:
	var key := "dax:" + file_name
	if not _cache.has(key):
		var path := _game_path.path_join(file_name)
		_cache[key] = DaxFile.open(path) if FileAccess.file_exists(path) else null
	return _cache[key]


## Colour indices for every frame of a plain picture block.
static func _frames(block: PackedByteArray) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if block.size() < EgaPicture.HEADER_SIZE:
		return out
	var h := block.decode_u16(0)
	var w := block.decode_u16(2) * 8
	var n := block.decode_u8(8)
	var size := w * h / 2
	for f in n:
		var start := EgaPicture.HEADER_SIZE + f * size
		if start + size > block.size():
			break
		var px := PackedByteArray()
		px.resize(w * h)
		for i in size:
			var b := block[start + i]
			px[i * 2] = b >> 4
			px[i * 2 + 1] = b & 15
		out.append(px)
	return out


## Colour indices to an image in the combat palette (0 and 8 swapped).
## With `transparent`, colour 0 is see-through instead.
static func _to_image(px: PackedByteArray, w: int, h: int, transparent: bool) -> Image:
	var rgb := EgaPicture.PALETTE_RGB
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for i in w * h:
		var c := px[i]
		var a := 255
		if transparent and c == 0:
			a = 0
		c = COMBAT_SWAP.get(c, c)
		data[i * 4] = rgb[c * 3]
		data[i * 4 + 1] = rgb[c * 3 + 1]
		data[i * 4 + 2] = rgb[c * 3 + 2]
		data[i * 4 + 3] = a
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)

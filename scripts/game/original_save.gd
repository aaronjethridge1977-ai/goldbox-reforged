class_name OriginalSave
extends RefCounted
## Writes a saved game in Pool of Radiance's own format, so a game saved here loads in the
## original and the other way round (Jeremy, 2026-11-12: support the original format for in-game
## saves). The reader is main.gd's load_original_save.
##
## SAVGAM<letter>.DAT (13,137 bytes), as the original writes it (lab, chat 10: a save made in
## DOSBox matched this layout byte for byte apart from the unused name slots):
##   0          the data set (ECLn/GEOn)
##   1..0x1400  the ECL memory cells, one word each (low byte first; EclVM.is_cell): 0x4900-0x4CFF,
##              then 0x6B00-0x6EFF, then 0x9700-0x98FF (GAME.OVR 0x1FE77-0x1FF60 writes the three
##              arrays at [0x49D2], [0x49D6], [0x49DA], 0x800, 0x800 and 0x400 bytes; chat 25: earlier
##              notes read the whole stretch as 0x4900-0x52FF). 0x6E3E is the party's size, 0x6E12 the
##              data set (both written at save time)
##   0x1401..   the current block's script as it stands in memory, from 0x9900, 0x1E00 bytes
##   0x3201     x, y, facing x 2, the wall ahead and the square's info byte (ECL 0xC04B-0xC04F: the
##              engine's five bytes at DS 0x6AAD)
##   0x3206     the view (DS 0x49FA): 1 a 3D area, 2-4 the wilderness bands 6:25, 7:26, 8:27 (chat 25:
##              ours wrote 1 in the wilderness and the original stopped with "Unable to load geo in
##              Load3DMap"); then the game mode (DS 0x49F3): 2, or 0 in a game saved before the
##              adventure starts (from the party menu after PARTY CREATION): with 2 there the original
##              goes straight to walking; then the party's size
##   0x3209     eight character file names, a length byte and 40 bytes each
## CHRDAT<letter><n>.SAV: the 285-byte character record (PartyMember.to_record) with its far
## pointers zeroed: the original rebuilds them from the files (lab: a save with every pointer
## zeroed loads with the items, readied weapon and armour all in place). 0xC7 holds the
## number of items. .ITM: the 63-byte item records (the next-item pointer at 42-45 zeroed).
## .SPC: the standing effects, 9 bytes each (type, minutes u16, power, 5 bytes of pointer).

const SIZE := 0x3351
const CELLS := 0xA00            # words from byte 1
const SCRIPT_AT := 0x1401
const SCRIPT_BYTES := 0x1E00
const POS_AT := 0x3201
const PARTY_SIZE_AT := 0x6E3E


## The ECL address of the save's word k (from byte 1).
static func cell_address(k: int) -> int:
	if k < 0x400:
		return 0x4900 + k
	if k < 0x800:
		return 0x6B00 + k - 0x400
	return 0x9700 + k - 0x800
const NAMES_AT := 0x3209


static func write(game_path: String, letter: String, set_no: int, mem: PackedByteArray,
		x: int, y: int, facing: int, party: Array[PartyMember], started: bool = true, hi: Dictionary = {},
		view: int = 1, ahead: int = 0, square: int = 0) -> bool:
	letter = letter.to_upper()
	var s := PackedByteArray()
	s.resize(SIZE)
	s[0] = set_no
	for k in CELLS:
		var a := cell_address(k)
		s[1 + 2 * k] = mem[a] if a < mem.size() else 0
		s[2 + 2 * k] = int(hi.get(a, 0)) & 0xFF
	for i in SCRIPT_BYTES:
		var a := EclScript.BASE + i
		s[SCRIPT_AT + i] = mem[a] if a < mem.size() else 0
	# The party's size in the engine's own memory (lab: dropping one, the original's re-save
	# of our save changed only this word, 6 to 5).
	s[1 + 2 * (0x400 + PARTY_SIZE_AT - 0x6B00)] = party.size()
	s[POS_AT] = x
	s[POS_AT + 1] = y
	s[POS_AT + 2] = (facing & 3) * 2
	s[POS_AT + 3] = ahead & 0xFF
	s[POS_AT + 4] = square & 0xFF
	s[POS_AT + 5] = view
	s[POS_AT + 6] = 2 if started else 0
	s[POS_AT + 7] = party.size()
	for k in mini(party.size(), 8):
		var stem := "CHRDAT%s%d" % [letter, k + 1]
		s[NAMES_AT + k * 41] = stem.length()
		for i in stem.length():
			s[NAMES_AT + k * 41 + 1 + i] = stem.unicode_at(i)
		if not _write_character(game_path.path_join(stem), party[k]):
			return false
	return _put(game_path.path_join("SAVGAM%s.DAT" % letter), s)


static func _write_character(stem: String, m: PartyMember) -> bool:
	var d := m.to_record()
	if d.size() < 285:
		return false
	for o in range(0x7F, 0x83):
		d[o] = 0
	d[0xC7] = mini(m.items.size(), 255)
	for o in range(0xC8, 0x100):
		d[o] = 0
	for o in range(0x104, 0x108):
		d[o] = 0
	var itm := PackedByteArray()
	for it in m.items:
		var r := (it as GameItem).to_record()
		if r.size() < GameItem.SIZE:
			continue
		for o in range(42, 46):
			r[o] = 0
		itm.append_array(r.slice(0, GameItem.SIZE))
	var spc := PackedByteArray()
	for a in m.affects:
		var r := PackedByteArray()
		r.resize(9)
		r[0] = int(a.effect) & 255
		r.encode_u16(1, clampi(int(a.get("minutes", 0)), 0, 65535))
		r[3] = int(a.get("value", 0)) & 255
		spc.append_array(r)
	return _put(stem + ".SAV", d) and _put(stem + ".ITM", itm) and _put(stem + ".SPC", spc)


static func _put(path: String, data: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return true

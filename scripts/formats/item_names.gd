class_name ItemNames
extends RefCounted
## Item names as the original builds them: up to three words from a table of 21-byte
## Pascal strings in START.EXE (EXEPACK-compressed, so it is unpacked first). An item
## record names its words by number at offsets 47..49 and hides unidentified ones with
## the bits of offset 53 (4 hides word 47, 2 word 48, 1 word 49). The name reads word 49,
## then 48, then 47 ("Clerical Scroll" + "With 2 Spells"); a stack of two or more gets an
## "s" on one word.
##
## The table is found by its second entry, "Battle Axe". Checked: all 28 items carried by
## the twelve shipped characters come out as their cached names, and the Slums orc leader's
## loot as the original shows it ("CLERICAL SCROLL WITH 2 SPELLS").

const ENTRY := 21

static var _shared: ItemNames = null
static var _shared_path := ""

var _words: PackedStringArray = []


static func shared(game_path: String) -> ItemNames:
	if _shared == null or _shared_path != game_path:
		_shared = ItemNames.load_from(game_path)
		_shared_path = game_path
	return _shared


static func load_from(game_path: String) -> ItemNames:
	var n := ItemNames.new()
	var exe := GameData.read_bytes(game_path.path_join("START.EXE"))
	var image := Exepack.unpack(exe)
	if image.is_empty():
		return n
	var key := "\nBattle Axe".to_ascii_buffer()
	var at := _find(image, key)
	if at < ENTRY:
		return n
	var base := at - ENTRY
	for i in 256:
		var p := base + i * ENTRY
		if p + ENTRY > image.size():
			break
		var length := mini(image[p], ENTRY - 1)
		n._words.append(image.slice(p + 1, p + 1 + length).get_string_from_ascii())
	return n


static func _find(hay: PackedByteArray, needle: PackedByteArray) -> int:
	var first := needle[0]
	for i in hay.size() - needle.size():
		if hay[i] != first:
			continue
		var ok := true
		for j in range(1, needle.size()):
			if hay[i + j] != needle[j]:
				ok = false
				break
		if ok:
			return i
	return -1


func is_loaded() -> bool:
	return not _words.is_empty()


func word(i: int) -> String:
	return _words[i] if i > 0 and i < _words.size() else ""


## The item's name as the original shows it, with the stack count in front ("11 Darts").
func name_of(it: GameItem) -> String:
	if _words.is_empty() or it.raw.size() < GameItem.SIZE:
		return it.name
	var ids := [it.raw[47], it.raw[48], it.raw[49]]   # word 1, 2, 3
	var hidden: int = it.raw[53]
	var shown := 0
	if ids[0] != 0 and (hidden & 4) == 0:
		shown |= 1
	if ids[1] != 0 and (hidden & 2) == 0:
		shown |= 2
	if ids[2] != 0 and (hidden & 1) == 0:
		shown |= 4
	var parts := PackedStringArray()
	var plural_done := false
	for v in [3, 2, 1]:
		if (shown >> (v - 1)) & 1 == 0:
			continue
		var w := word(ids[v - 1])
		if it.count >= 2 and not plural_done and (
				(1 << (v - 1)) == shown or (v == 1 and shown > 4) or (v == 2 and (shown & 1) == 0)):
			w += "s"
			plural_done = true
		parts.append(w)
	var text := " ".join(parts)
	if it.count > 0:
		text = "%d %s" % [it.count, text]
	return text

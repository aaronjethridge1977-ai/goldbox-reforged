class_name GameItem
extends RefCounted
## One item, from a 63-byte record. The same layout is used in ITEM*.DAX lists (treasure
## and shop stock) and in a character's .ITM file.
##
## Record (partly known):
##   0       name length          1..41  name text (a cached display string)
##   42..45  links (in-memory list pointers; ignore)
##   46      item type            47..49 name word ids (into ITEMS; not decoded yet)
##   52      readied (1) or not   55..56 weight (coins)   57 count (arrows, darts...)
##   58..59  price in gold
## Verified against the New Phlan silver shop (names, prices, counts) and the purchase
## test (Silver Mace weight 100), and against the starting party's daggers and armour.

const SIZE := 63

var name := ""
var type := 0
var readied := false
var weight := 0
var count := 0
var price := 0
var raw := PackedByteArray()


static func from_record(rec: PackedByteArray) -> GameItem:
	var it := GameItem.new()
	it.raw = rec.duplicate()
	var n := mini(rec[0], 41)
	it.name = rec.slice(1, 1 + n).get_string_from_ascii().strip_edges()
	# The cached name can carry a leftover "Yes"/"No" readied column; drop it.
	for prefix in ["Yes ", "No "]:
		if it.name.begins_with(prefix):
			it.name = it.name.substr(prefix.length()).strip_edges()
	it.type = rec[46]
	it.readied = rec[52] != 0
	it.weight = rec.decode_u16(55)
	it.count = rec[57]
	it.price = rec.decode_u16(58)
	return it


## All records in a block or file, in stored order.
static func list_from(data: PackedByteArray) -> Array[GameItem]:
	var out: Array[GameItem] = []
	for i in range(0, data.size() - SIZE + 1, SIZE):
		out.append(from_record(data.slice(i, i + SIZE)))
	return out


func copy() -> GameItem:
	var it := GameItem.from_record(raw)
	it.readied = false
	return it

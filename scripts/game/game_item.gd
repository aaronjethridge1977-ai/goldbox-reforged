class_name GameItem
extends RefCounted
## One item, from a 63-byte record. The same layout is used in ITEM*.DAX lists (treasure
## and shop stock) and in a character's .ITM file.
##
## Record (partly known):
##   0       name length          1..41  name text (a cached display string)
##   42..45  links (in-memory list pointers; ignore)
##   46      item type            47..49 name word ids (into ITEMS; not decoded yet)
##   50      magic plus (signed)  51 saving-throw plus
##   52      readied (1) or not   54 cursed
##   55..56  weight (coins, per piece)   57 count (arrows, darts...; 0 = a single item)
##   58..59  price in gold
## Verified against the New Phlan silver shop (names, prices, counts) and the purchase
## test (Silver Mace weight 100), and against the starting party's daggers and armour.

const SIZE := 63

var name := ""
var type := 0
var plus := 0
var readied := false
var cursed := false
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
	it.plus = rec[50] - 256 if rec[50] > 127 else rec[50]
	it.readied = rec[52] != 0
	it.cursed = rec[54] != 0
	it.weight = rec.decode_u16(55)
	it.count = rec[57]
	it.price = rec.decode_u16(58)
	return it


## The record with what changes in play written back (readied, count, charges are in raw).
func to_record() -> PackedByteArray:
	var rec := raw.duplicate()
	if rec.size() < SIZE:
		return rec
	rec[52] = 1 if readied else 0
	rec[54] = 1 if cursed else 0
	rec[57] = clampi(count, 0, 255)
	return rec


## All records in a block or file, in stored order.
static func list_from(data: PackedByteArray) -> Array[GameItem]:
	var out: Array[GameItem] = []
	for i in range(0, data.size() - SIZE + 1, SIZE):
		out.append(from_record(data.slice(i, i + SIZE)))
	return out


## Whether Detect Magic marks the item: START.EXE 0xBA:0x443 (an item list's line) puts "* " before the
## name when any party member has effect 5 and the item's byte 50 (plus) or 51 is above 0 (signed),
## or byte 54 (cursed) is set (lab, chat 26: Darkstar's Detect Magic in camp, VIEW, ITEMS showed
## " YES  * FLAIL" for a +1 flail, the banded mail unmarked).
func detect_magic_marks() -> bool:
	var b := func(i: int) -> int:
		if raw.size() <= i:
			return 0
		return raw[i] - 256 if raw[i] > 127 else raw[i]
	return b.call(50) > 0 or b.call(51) > 0 or (raw.size() > 54 and raw[54] != 0)


## Weight of the whole stack, in coins (11 darts at 5 weigh 55).
func total_weight() -> int:
	return weight * maxi(count, 1)


func copy() -> GameItem:
	var it := GameItem.from_record(raw)
	it.readied = false
	return it

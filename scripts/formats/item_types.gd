class_name ItemTypes
extends RefCounted
## The ITEMS file: what each item type does (weapon dice, armour value, hands, range).
##
## Layout: u16 header (0x0076), then one 16-byte record per item type, indexed by the
## type byte of an item record (GameItem.type):
##   0  slot           0 weapon, 1 shield, 2 body armour, others: helm, gauntlets, rings...
##   1  hands          hands needed to use it
##   2  large_count    damage dice against large creatures: count, size, bonus (signed)
##   3  large_size
##   4  large_bonus
##   5  half_attacks   missile attacks per round x2 (darts 6 = 3 per round); 0 = normal
##   6  armor          bit 7 set: the item adds to AC. Low 7 bits are the AC value on the
##                     game's 60-based scale (AC = 60 - value): leather 0x34 = AC 8,
##                     splint and banded 0x38 = AC 4, plate 0x39 = AC 3. For a shield
##                     (slot 1) the low bits are its bonus (1). With low bits 0, only the
##                     item's magic plus counts (rings, cloaks...).
##   7, 8               not yet known
##   9  normal_count   damage dice against small and man-sized creatures: count, size, bonus
##   10 normal_size
##   11 normal_bonus
##   12 range          in squares (dagger 1, dart 6)
##   13 class_flags    which classes may use it
##   14 flags          see FLAG_*
##   15                 not yet known
## Checked: Dagger 1d4 / 1d3, Mace 1d6+1 / 1d6, Flail 1d6+1 / 2d4, Broad Sword 2d4 / 1d6+1,
## Long Sword 1d8 / 1d12, Two-Handed Sword 1d10 / 3d6 (AD&D 1st edition values), and the
## armour order leather < scale < chain < banded/splint < plate.

const FLAG_ARROWS := 0x01     # fires arrows
const FLAG_DEX_TO_HIT := 0x02 # missile weapon: DEX reaction bonus applies to hit
const FLAG_MELEE := 0x04      # melee weapon: STR bonuses apply
const FLAG_QUARRELS := 0x80   # fires quarrels

const SLOT_WEAPON := 0
const SLOT_SHIELD := 1
const SLOT_ARMOR := 2

var records: Array[PackedByteArray] = []


static func load_file(game_path: String) -> ItemTypes:
	var data := FileAccess.get_file_as_bytes(game_path.path_join("ITEMS"))
	var t := ItemTypes.new()
	for p in range(2, data.size() - 15, 16):
		t.records.append(data.slice(p, p + 16))
	return t


func has(type: int) -> bool:
	return type >= 0 and type < records.size()


func slot(type: int) -> int:
	return records[type][0] if has(type) else -1


func hands(type: int) -> int:
	return records[type][1] if has(type) else 0


func flags(type: int) -> int:
	return records[type][14] if has(type) else 0


func armor_byte(type: int) -> int:
	return records[type][6] if has(type) else 0


func range_squares(type: int) -> int:
	return records[type][12] if has(type) else 0


## Damage dice as [count, size, bonus]; `large` picks the dice against large creatures.
func damage(type: int, large: bool = false) -> Array[int]:
	if not has(type):
		return [0, 0, 0]
	var r := records[type]
	var o := 2 if large else 9
	var bonus := r[o + 2]
	if bonus > 127:
		bonus -= 256
	return [r[o], r[o + 1], bonus]

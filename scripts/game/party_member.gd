class_name PartyMember
extends RefCounted
## A Pool of Radiance character, from CHRDATxn.SAV (285 bytes) and its .ITM item file.
##
## Offsets follow the ssi-engine project's documentation and were checked by decoding
## the twelve characters that ship with the game (Thrender Grone, Bakshi, Rhiannon,
## Brother Sean, Darkstar, Phineas): names, races, classes, ages, stats and starting gear
## all come out sensibly.

const RACES := ["MONSTER", "DWARF", "ELF", "GNOME", "HALF-ELF", "HALFLING", "HALF-ORC", "HUMAN"]
const CLASSES := ["CLERIC", "DRUID", "FIGHTER", "PALADIN", "RANGER", "MAGE", "THIEF", "KNIGHT",
	"CLERIC/FIGHTER", "CLERIC/FIGHTER/MAGE", "CLERIC/RANGER", "CLERIC/MAGE", "CLERIC/THIEF",
	"FIGHTER/MAGE", "FIGHTER/THIEF", "FIGHTER/MAGE/THIEF", "MAGE/THIEF"]
const ALIGNMENTS := ["LAWFUL GOOD", "LAWFUL NEUTRAL", "LAWFUL EVIL", "NEUTRAL GOOD", "TRUE NEUTRAL",
	"NEUTRAL EVIL", "CHAOTIC GOOD", "CHAOTIC NEUTRAL", "CHAOTIC EVIL"]
const MONEY_NAMES := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM"]
## Coin values in copper (AD&D: 1 pp = 5 gp = 10 ep = 100 sp = 1000 cp).
const COIN_VALUE := [1, 10, 100, 200, 1000]

var name := ""
var race := ""
var char_class := ""
var alignment := ""
var gender := ""
var age := 0
var stats := PackedInt32Array()     # STR INT WIS DEX CON CHA
var strength_exceptional := 0
var hp := 0
var hp_max := 0
var experience := 0
## cp, sp, ep, gp, pp, gems, jewelry
var money := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var items: Array[GameItem] = []
var raw := PackedByteArray()


static func load_files(sav_path: String, itm_path: String) -> PartyMember:
	var d := FileAccess.get_file_as_bytes(sav_path)
	if d.size() < 285:
		return null
	var m := PartyMember.new()
	m.raw = d
	m.name = d.slice(1, 1 + mini(d[0], 15)).get_string_from_ascii().strip_edges()
	m.race = RACES[d[0x2E]] if d[0x2E] < RACES.size() else "?"
	m.char_class = CLASSES[d[0x2F]] if d[0x2F] < CLASSES.size() else "?"
	m.age = d[0x30]
	m.alignment = ALIGNMENTS[d[0xA0]] if d[0xA0] < ALIGNMENTS.size() else "?"
	m.gender = "FEMALE" if d[0x9E] & 1 else "MALE"
	m.stats = PackedInt32Array([d[0x10], d[0x11], d[0x12], d[0x13], d[0x14], d[0x15]])
	m.strength_exceptional = d[0x16]
	m.hp_max = d[0x32]
	m.hp = d[0x11B]
	m.experience = d.decode_u32(0xAC)
	for i in 7:
		m.money[i] = d.decode_u16(0x88 + i * 2)
	if FileAccess.file_exists(itm_path):
		m.items = GameItem.list_from(FileAccess.get_file_as_bytes(itm_path))
	return m


## Coins on hand, in copper.
func wealth_copper() -> int:
	var total := 0
	for i in 5:
		total += money[i] * COIN_VALUE[i]
	return total


## Pays `gold` gold pieces. The change is regrouped into the largest coins, as the original
## shows it (140 gold, after an 80-gold purchase, became 12 platinum).
func pay_gold(gold: int) -> bool:
	var left := wealth_copper() - gold * 200
	if left < 0:
		return false
	for i in range(4, -1, -1):
		money[i] = left / COIN_VALUE[i]
		left -= money[i] * COIN_VALUE[i]
	return true


## Encumbrance in coins: every coin weighs 1, plus item weights.
func encumbrance() -> int:
	var total := 0
	for i in 5:
		total += money[i]
	for it in items:
		total += it.weight
	return total


func money_text() -> String:
	var parts := PackedStringArray()
	for i in range(4, -1, -1):
		if money[i] > 0:
			parts.append("%s %d" % [MONEY_NAMES[i], money[i]])
	return ", ".join(parts) if not parts.is_empty() else "no money"

class_name PartyMember
extends RefCounted
## A combatant: a party character (CHRDATxn.SAV, 285 bytes, plus its .ITM item file) or a
## monster (a block of MONnCHA.DAX plus the same block of MONnITM.DAX). Monsters use the
## very same 285-byte record, so one model serves both sides of a fight.
##
## Record offsets (checked on the twelve shipped characters and every monster block):
##   0x00 name (length byte + text)   0x10..0x15 STR INT WIS DEX CON CHA   0x16 STR 18/xx
##   0x2D THAC0 (60-based: THAC0 = 60 - value)   0x2E race   0x2F class   0x30 age
##   0x32 max HP   0x6B attack level   0x6D..0x71 saving throws   0x72 base movement
##   0x84 morale   0x88 coins (u16 x 7)   0x96..0x9D levels   0x9E gender   0xA0 alignment
##   0xA1 attacks per round x2   0xA3/0xA4 unarmed or natural damage dice count (two attacks)
##   0xA5/0xA6 dice size   0xA7/0xA8 damage bonus
##   0xA9 base AC (60-based: AC = 60 - value)   0xAA 1 = STR bonuses apply (characters and
##   humanoids with a strength score; 0 for most monsters)   0xAC experience
##   0xB1 hit points rolled   0xB8 experience value (s16)   0xBA experience per hit point
##   (a monster is worth 0xBA x 0xB1 + 0xB8: an orc 1 x 5 + 10 = 15; checked in the lab)
##   0x102 total weight carried (cached)   0x10C status   0x11B current HP
##   0x17..0x2B spells in memory (21 spell ids, the first in the last byte)
##   0x33..0x6A spell book (56 bytes, one per spell id 1..56: 1 = known)
##   0xB2..0xB4 cleric spells per day at levels 1-3   0xB5..0xB7 magic-user spells per day
##
## Derived stats (recalculate()) follow AD&D 1st edition, which the game implements:
## STR to-hit and damage, DEX defensive adjustment, armour, shield, magic pluses, and
## movement slowed by armour and by load. Everything is kept on the game's 60-based scale
## internally and shown as ordinary AC and THAC0.
##
## The answer key: a character record also caches the values the original last worked
## out (0x110 THAC0, 0x111 AC, 0x112 AC from behind, 0x115..0x11A damage dice, 0x11C
## movement). recalculate() reproduces them exactly for all twelve shipped characters
## (CHRDATA1-6 and CHRDATJ1-6). Monster records' cached values are stale editor leftovers
## (THAC0 -91 and the like), so they can't be used to check monsters.

const RACES := ["MONSTER", "DWARF", "ELF", "GNOME", "HALF-ELF", "HALFLING", "HALF-ORC", "HUMAN"]
const CLASSES := ["CLERIC", "DRUID", "FIGHTER", "PALADIN", "RANGER", "MAGE", "THIEF", "KNIGHT",
	"CLERIC/FIGHTER", "CLERIC/FIGHTER/MAGE", "CLERIC/RANGER", "CLERIC/MAGE", "CLERIC/THIEF",
	"FIGHTER/MAGE", "FIGHTER/THIEF", "FIGHTER/MAGE/THIEF", "MAGE/THIEF"]
const ALIGNMENTS := ["LAWFUL GOOD", "LAWFUL NEUTRAL", "LAWFUL EVIL", "NEUTRAL GOOD", "TRUE NEUTRAL",
	"NEUTRAL EVIL", "CHAOTIC GOOD", "CHAOTIC NEUTRAL", "CHAOTIC EVIL"]
const MONEY_NAMES := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM"]
## Coin values in copper (AD&D: 1 pp = 5 gp = 10 ep = 100 sp = 1000 cp).
const COIN_VALUE := [1, 10, 100, 200, 1000]
const RACE_ELF := 2
## Item types an elf gets +1 to hit with: long and short swords and bows.
const ELF_WEAPONS := [36, 37, 41, 42, 43, 44]

var name := ""
var race_id := 0
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
## Health, as the record stores it (0x10C): OKAY, UNCONSCIOUS (0 HP), DYING (bleeding;
## combat only), DEAD and the rest. Only an OKAY character with HP above 0 fights.
var status := 0
var weapon_ranged := false          # readied weapon reaches more than 1 square
var weapon_ranged_melee := false    # ... and can also be used hand to hand
var missile_range := 1              # squares a missile weapon reaches (its range - 1)
var missile_half_attacks := 0       # missile attacks per round x2 (2 at least)
var ammo: GameItem = null           # what each shot uses up: the arrows, the quarrels or
                                    # the thrown weapon itself (null: a sling's stones)
var missile_ready := false          # has what it needs to shoot
var class_flags := 0                # 0xB0: which item classes the character may use
var size := 0                       # 0x6C: over 0x80, or low 3 bits over 1 = large
var half_attacks_2 := 0             # 0xA2: second attack type per round x2 (claw/bite...)
var class_id := 0
var hp_rolled := 0
var xp_value := 0                   # a monster's worth: xp_per_hp x hp_rolled + xp_value
var xp_per_hp := 0
## cp, sp, ep, gp, pp, gems, jewelry
var money := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var items: Array[GameItem] = []
var raw := PackedByteArray()
var is_monster := false

# Base values from the record (60-based where noted)
var base_thac0_60 := 40
var base_ac_60 := 50
var base_movement := 12
var half_attacks := 2
var base_damage := [1, 2, 0]        # unarmed / natural attack dice: count, size, bonus
var base_damage_2 := [0, 0, 0]      # second natural attack (claw/claw/bite monsters)
var strength_applies := true
var morale := 0
var saves := PackedInt32Array()

# Spells (see the record notes above and "Spells" below)
var spell_book := PackedByteArray()   # by id - 1: known
var memorized: Array[int] = []        # spell ids; + LEARNING while still being memorized
var spell_slots := [[0, 0, 0], [0, 0, 0]]   # [cleric, magic-user][level - 1]
var affects: Array = []               # [{effect, spell, minutes, value}]
var learn_hours := 0                  # resting: hours still to go before memorizing starts

# Derived by recalculate()
var ac := 10
var rear_ac := 10
var thac0 := 20
var damage := [1, 2, 0]             # against small and man-sized
var damage_large := [1, 2, 0]       # against large
var movement := 12
var weapon: GameItem = null
var armor: GameItem = null
var shield: GameItem = null
var weight := 0


static func load_files(sav_path: String, itm_path: String) -> PartyMember:
	var d := FileAccess.get_file_as_bytes(sav_path)
	if d.size() < 285:
		return null
	var item_data := PackedByteArray()
	if FileAccess.file_exists(itm_path):
		item_data = FileAccess.get_file_as_bytes(itm_path)
	var m := from_bytes(d, item_data)
	var spc_path := sav_path.get_basename() + ".SPC"
	if m != null and FileAccess.file_exists(spc_path):
		SpecialAffects.add_records(m, FileAccess.get_file_as_bytes(spc_path))
	return m


## A monster: block `id` of MON<file_no>CHA.DAX, with its items from MON<file_no>ITM.DAX.
static func load_monster(game_path: String, file_no: int, id: int) -> PartyMember:
	var cha := DaxFile.open(game_path.path_join("MON%dCHA.DAX" % file_no))
	if cha == null or not cha.blocks.has(id):
		return null
	var item_data := PackedByteArray()
	var itm_path := game_path.path_join("MON%dITM.DAX" % file_no)
	if FileAccess.file_exists(itm_path):
		var itm := DaxFile.open(itm_path)
		if itm and itm.blocks.has(id):
			item_data = itm.blocks[id]
	var m := from_bytes(cha.blocks[id], item_data)
	if m:
		m.is_monster = true
		m.affects.clear()
		var spc := DaxFile.open(game_path.path_join("MON%dSPC.DAX" % file_no))
		if spc and spc.blocks.has(id):
			SpecialAffects.add_records(m, spc.blocks[id])
		var names := ItemNames.shared(game_path)
		for it in m.items:
			if it.name == "":
				it.name = names.name_of(it)
	return m


static func from_bytes(d: PackedByteArray, item_data: PackedByteArray) -> PartyMember:
	if d.size() < 285:
		return null
	var m := PartyMember.new()
	m.raw = d
	m.name = d.slice(1, 1 + mini(d[0], 15)).get_string_from_ascii().strip_edges()
	m.race_id = d[0x2E]
	m.race = RACES[d[0x2E]] if d[0x2E] < RACES.size() else "?"
	m.class_id = d[0x2F]
	m.char_class = CLASSES[d[0x2F]] if d[0x2F] < CLASSES.size() else "?"
	m.age = d[0x30]
	m.alignment = ALIGNMENTS[d[0xA0]] if d[0xA0] < ALIGNMENTS.size() else "?"
	m.gender = "FEMALE" if d[0x9E] & 1 else "MALE"
	m.stats = PackedInt32Array([d[0x10], d[0x11], d[0x12], d[0x13], d[0x14], d[0x15]])
	m.strength_exceptional = d[0x16]
	m.hp_max = d[0x32]
	m.hp = d[0x11B]
	m.experience = d.decode_u32(0xAC)
	m.status = d[0x10C]
	m.class_flags = d[0xB0]
	m.size = d[0x6C]
	m.half_attacks_2 = d[0xA2]
	m.hp_rolled = d[0xB1]
	m.xp_value = d.decode_s16(0xB8)
	m.xp_per_hp = d[0xBA]
	for i in 7:
		m.money[i] = d.decode_u16(0x88 + i * 2)
	m.base_thac0_60 = d[0x2D]
	m.base_ac_60 = d[0xA9]
	m.base_movement = d[0x72]
	m.half_attacks = d[0xA1]
	m.base_damage = [d[0xA3], d[0xA5], _signed(d[0xA7])]
	m.base_damage_2 = [d[0xA4], d[0xA6], _signed(d[0xA8])]
	m.strength_applies = d[0xAA] != 0
	m.morale = d[0x84]
	m.saves = PackedInt32Array([d[0x6D], d[0x6E], d[0x6F], d[0x70], d[0x71]])
	m.spell_book = d.slice(0x33, 0x6B)
	for i in range(0x2B, 0x16, -1):
		if d[i] > 0:
			m.memorized.append(d[i])
	m.spell_slots = [[d[0xB2], d[0xB3], d[0xB4]], [d[0xB5], d[0xB6], d[0xB7]]]
	if not item_data.is_empty():
		m.items = GameItem.list_from(item_data)
	m.thac0 = 60 - m.base_thac0_60
	m.ac = 60 - m.base_ac_60
	m.rear_ac = m.ac + 2
	m.damage = m.base_damage.duplicate()
	m.damage_large = m.base_damage.duplicate()
	m.movement = m.base_movement
	# Racial abilities are standing effects, as character creation gives them.
	SpecialAffects.add(m, SpecialAffects.RACIAL.get(m.race_id, []))
	return m


## The readied weapon (slot 0), or null.
func readied_weapon(types: ItemTypes) -> GameItem:
	for it in items:
		if it.readied and types != null and types.slot(it.type) == ItemTypes.SLOT_WEAPON:
			return it
	return null


## An independent copy (for several monsters of one kind).
func clone() -> PartyMember:
	var m := from_bytes(raw, PackedByteArray())
	m.is_monster = is_monster
	m.hp = hp
	m.status = status
	m.experience = experience
	m.money = money.duplicate()
	m.memorized = memorized.duplicate()
	m.affects = affects.duplicate(true)
	for it in items:
		var c := GameItem.from_record(it.raw)
		c.name = it.name
		m.items.append(c)
	return m


const STATUS_OKAY := 0
## Missile weapons, as the original handles them: a thrown weapon (darts, axes, spears)
## is its own ammunition; a bow needs readied arrows and a crossbow readied quarrels (their
## plus adds to hit and damage); a sling needs nothing. A missile weapon reaches its range
## less 1 and attacks per round from the ITEMS table (darts 3, bows 2), never more than
## the ammunition left.
func _missiles(types: ItemTypes) -> void:
	ammo = null
	missile_ready = false
	missile_range = 1
	missile_half_attacks = 0
	if weapon == null or not weapon_ranged:
		return
	var f := types.flags(weapon.type)
	missile_range = maxi(types.range_squares(weapon.type) - 1, 1)
	missile_half_attacks = maxi(types.half_attacks(weapon.type), 2)
	if f & ItemTypes.FLAG_THROWN:
		ammo = weapon
	elif f & ItemTypes.FLAG_LAUNCHER:
		var want := -1
		if f & ItemTypes.FLAG_ARROWS:
			want = ItemTypes.TYPE_ARROW
		elif f & ItemTypes.FLAG_QUARRELS:
			want = ItemTypes.TYPE_QUARREL
		if want < 0:
			missile_ready = true      # a sling
			return
		for it in items:
			if it.readied and it.type == want:
				ammo = it
				break
	missile_ready = ammo != null


## Shots left with the readied missile weapon (a big number for a sling).
func shots_left() -> int:
	if not missile_ready:
		return 0
	if ammo == null:
		return 99
	return maxi(ammo.count, 1)


## Uses up one shot. Returns the item if it is now gone (thrown or used up).
func use_shot() -> GameItem:
	if ammo == null:
		return null
	if ammo.count > 1:
		ammo.count -= 1
		return null
	items.erase(ammo)
	var gone := ammo
	ammo = null
	return gone


# --- Spells -------------------------------------------------------------------------------
# As the original does it (rules as documented by Pilgrim's reconstruction; screens and
# timings checked in the lab, save J: Brother Sean memorized Resist Cold in 4 hours 15
# minutes, the rest time MAGIC's REST offered):
# - The spells per day at each level are kept in the record (set when a level is gained).
# - MEMORIZE picks spells from the book into free slots; they wait, marked "*", until the
#   party rests. Resting to memorize takes 4 hours (6 if any is above 2nd level), then 15
#   minutes per spell level, one spell after another ("<NAME> HAS MEMORIZED <SPELL>").
# - Casting removes the spell from memory.
const LEARNING := 0x100
const LEVEL_INDEX := [0, 5]        # record levels (0x96..) of cleric and magic-user


func class_level(spell_class: int) -> int:
	if raw.size() < 0x9E or spell_class < 0 or spell_class > 1:
		return 0
	return raw[0x96 + LEVEL_INDEX[spell_class]]


## The caster's level for a spell (the original's spellMaxTargetCount): its cleric or
## magic-user level, or a paladin's level - 8; 6 for anyone who casts no spells (items).
func caster_level(table: SpellTable, id: int) -> int:
	var cl := class_level(0)
	var mu := class_level(1)
	var paladin: int = raw[0x99] if raw.size() > 0x99 else 0
	var ranger: int = raw[0x9A] if raw.size() > 0x9A else 0
	if cl == 0 and mu == 0 and paladin < 9 and ranger < 8:
		return 6
	match table.spell_class(id):
		SpellTable.CLERIC:
			return maxi(cl, paladin - 8)
		SpellTable.MAGE:
			return mu
	return 6


func knows(id: int) -> bool:
	return id > 0 and id <= spell_book.size() and spell_book[id - 1] != 0


func ready_spells() -> Array[int]:
	var out: Array[int] = []
	for s in memorized:
		if s < LEARNING:
			out.append(s)
	return out


## SCRIBE: magic-user spells on this member's scrolls marked for copying into the spell
## book (the original sets bit 7 of the scroll's spell byte, record bytes 60..62). Resting
## copies them after any memorizing, a spell at a time ("<NAME> HAS SCRIBED <SPELL>").
func scribe_pending() -> Array[int]:
	var out: Array[int] = []
	for it in items:
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] > 0x80:
				out.append(it.raw[k] & 0x7F)
	return out


## Copies the first marked scroll spell into the book; the spell leaves the scroll, and an
## empty scroll is gone. Returns the spell id (0 if none was marked).
func scribe_next() -> int:
	for it in items:
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] > 0x80:
				var id: int = it.raw[k] & 0x7F
				it.raw[k] = 0
				if id <= spell_book.size():
					spell_book[id - 1] = 1
				if it.raw[60] & 0x7F == 0 and it.raw[61] & 0x7F == 0 and it.raw[62] & 0x7F == 0:
					items.erase(it)
				return id
	return 0


## Scroll spells this magic-user could scribe: magic-user spells of levels they have slots
## for, not already in the book, on scrolls whose spells are known (record byte 53 clear).
func scribable(table: SpellTable) -> Array:
	var out: Array = []     # [item, record byte, id]
	if class_level(1) == 0:
		return out
	for it in items:
		if it.raw.size() < 63 or it.raw[53] != 0:
			continue
		for k in [60, 61, 62]:
			var id: int = it.raw[k] & 0x7F
			if id == 0 or id > SpellTable.NAMED or table.spell_class(id) != SpellTable.MAGE:
				continue
			var lvl := table.level(id)
			if lvl >= 1 and lvl <= 3 and spell_slots[1][lvl - 1] > 0 and not knows(id):
				out.append([it, k, id])
	return out


func learning_spells() -> Array[int]:
	var out: Array[int] = []
	for s in memorized:
		if s >= LEARNING:
			out.append(s - LEARNING)
	return out


## Free slots for spells of `spell_class` at `level`, counting those being memorized.
func slots_left(table: SpellTable, spell_class: int, level: int) -> int:
	if spell_class < 0 or spell_class > 1 or level < 1 or level > 3:
		return 0
	var used := 0
	for s in memorized:
		var id := s % LEARNING
		if table.spell_class(id) == spell_class and table.level(id) == level:
			used += 1
	return spell_slots[spell_class][level - 1] - used


func has_slots() -> bool:
	for c in 2:
		for l in 3:
			if spell_slots[c][l] > 0:
				return true
	return false


func cancel_learning() -> void:
	memorized = memorized.filter(func(s): return s < LEARNING)
	learn_hours = 0


## Minutes of rest this character needs to memorize what it has picked.
func learn_minutes(table: SpellTable) -> int:
	var total := 0
	var top := 0
	for id in learning_spells() + scribe_pending():
		total += table.level(id)
		top = maxi(top, table.level(id))
	if total == 0:
		return 0
	return (6 if top > 2 else 4) * 60 + total * 15


## Removes one memorized copy of `id` (after casting it, or losing it).
func forget(id: int) -> void:
	var i := memorized.find(id)
	if i >= 0:
		memorized.remove_at(i)


func has_affect(effect_id: int) -> bool:
	for a in affects:
		if int(a.effect) == effect_id:
			return true
	return false


func is_large() -> bool:
	return size > 0x80 or (size & 7) > 1


func thief_level() -> int:
	return raw[0x9C] if raw.size() > 0x9C else 0


const STATUS_RUNNING := 3
const STATUS_UNCONSCIOUS := 4
const STATUS_DYING := 5
const STATUS_DEAD := 6
const STATUS_NAMES := ["OKAY", "ANIMATED", "TEMP GONE", "RUNNING", "UNCONSCIOUS", "DYING",
	"DEAD", "STONED", "GONE"]


func can_fight() -> bool:
	return status == STATUS_OKAY and hp > 0


func status_name() -> String:
	return STATUS_NAMES[status] if status < STATUS_NAMES.size() else "?"


## What this monster is worth in experience when defeated.
func experience_worth() -> int:
	return xp_per_hp * hp_rolled + xp_value


## Adds a share of a fight's experience the way the original does: +10% for a single-
## classed character whose prime requisite(s) are over 15, half for two classes, a third
## for three. (The original's table leaves mage/thief out of the split, so a mage/thief
## gets the whole share; kept as the original does it.) Returns what was added.
func gain_experience(share: int) -> int:
	var st := stats
	var add := share
	match class_id:
		0:
			if st[2] > 15: add += share / 10
		2:
			if st[0] > 15: add += share / 10
		3:
			if st[0] > 15 and st[2] > 15: add += share / 10
		4:
			if st[0] > 15 and st[1] > 15 and st[2] > 15: add += share / 10
		5:
			if st[1] > 15: add += share / 10
		6:
			if st[3] > 15: add += share / 10
		8, 10, 11, 12, 13, 14:
			add = share / 2
		9, 15:
			add = share / 3
	experience += add
	return add


static func _signed(b: int) -> int:
	return b - 256 if b > 127 else b


## Attacks per round (the record keeps half-attacks: 3 = three attacks every two rounds).
func attacks_text() -> String:
	if half_attacks % 2 == 0:
		return str(half_attacks / 2)
	return "%d/2" % half_attacks


static func dice_text(d: Array) -> String:
	if d[0] == 0 or d[1] == 0:
		return "-"
	var s := "%dd%d" % [d[0], d[1]]
	if d[2] > 0:
		s += "+%d" % d[2]
	elif d[2] < 0:
		s += str(d[2])
	return s


## What the original last worked out, from the record's cache (characters only; the
## monster files' caches are stale). Shown on the sheet beside our values.
func cached_text() -> String:
	var d := raw
	return "AC %d   THAC0 %d   DAMAGE %s   MOVE %d" % [60 - d[0x111], 60 - d[0x110],
		dice_text([d[0x115], d[0x117], _signed(d[0x119])]), d[0x11C]]


# --- Ability tables (AD&D 1st edition) ---------------------------------------------

## Strength as one number: 3..17 as is, 18 = 18, 18/01-50 = 19, /51-75 = 20, /76-90 = 21,
## /91-99 = 22, 18/00 = 23, and 19..25 = 24..30.
func strength_group() -> int:
	var s := stats[0]
	if s < 18:
		return s
	if s > 18:
		return s + 5
	var e := strength_exceptional
	if e == 0:
		return 18
	if e <= 50:
		return 19
	if e <= 75:
		return 20
	if e <= 90:
		return 21
	if e <= 99:
		return 22
	return 23


func strength_hit_bonus() -> int:
	if not strength_applies:
		return 0
	var g := strength_group()
	if g <= 3:
		return -3
	if g <= 5:
		return -2
	if g <= 7:
		return -1
	if g <= 16:
		return 0
	if g <= 19:
		return 1
	if g <= 22:
		return 2
	if g <= 25:
		return 3
	if g <= 27:
		return 4
	return g - 23


func strength_damage_bonus() -> int:
	if not strength_applies:
		return 0
	var g := strength_group()
	if g <= 2:
		return -2
	if g <= 5:
		return -1
	if g <= 15:
		return 0
	if g == 16:
		return 1
	if g <= 19:
		return g - 16
	if g <= 29:
		return g - 17
	return 14


## Coins of load before movement suffers (negative for the very weak).
func load_allowance() -> int:
	var g := strength_group()
	if g <= 3:
		return -350
	if g <= 5:
		return -250
	if g <= 7:
		return -150
	if g <= 11:
		return 0
	if g <= 13:
		return 100
	if g <= 15:
		return 200
	if g == 16:
		return 350
	if g <= 21:
		return (g - 17) * 250 + 500
	if g <= 26:
		return (g - 22) * 1000 + 2000
	if g == 27:
		return 7500
	return (g - 28) * 3000 + 9000


## DEX defensive adjustment, as AC points gained (positive = better AC).
func dex_ac_bonus() -> int:
	var x := stats[3]
	if x <= 3:
		return -4
	if x <= 6:
		return x - 7
	if x <= 14:
		return 0
	if x <= 18:
		return x - 14
	if x <= 20:
		return 4
	if x <= 23:
		return 5
	return 6


## DEX reaction/missile adjustment to hit.
func dex_missile_bonus() -> int:
	var x := stats[3]
	if x <= 2:
		return -4
	if x <= 5:
		return x - 6
	if x <= 15:
		return 0
	if x <= 18:
		return x - 15
	if x <= 20:
		return 3
	if x <= 23:
		return 4
	return 5


# --- Derived stats -------------------------------------------------------------------

## Works out AC, THAC0, damage and movement from the record and the readied items.
func recalculate(types: ItemTypes) -> void:
	weapon = null
	armor = null
	shield = null
	weight = 0
	for i in 5:
		weight += money[i]
	var ring_plus := 0           # best ring/protection plus (slot 9); doesn't stack
	var other_plus := 0          # helms, cloaks, bracers... (plus only)
	var armor_60 := 0            # best body armour, 60-based, including its plus
	var magic_armor := false
	var shield_bonus := 0
	for it in items:
		weight += it.total_weight()
		if not it.readied or not types.has(it.type):
			continue
		var slot := types.slot(it.type)
		if slot == ItemTypes.SLOT_WEAPON and weapon == null:
			weapon = it
		var a := types.armor_byte(it.type)
		if (a & 0x80) == 0:
			continue
		a &= 0x7F
		if slot == ItemTypes.SLOT_SHIELD:
			shield = it
			shield_bonus = a + it.plus
		elif a == 0:
			if slot == 9:
				ring_plus = maxi(ring_plus, it.plus)
			else:
				other_plus += it.plus
		elif a + it.plus > armor_60:
			armor_60 = a + it.plus
			armor = it
			magic_armor = it.plus > 0 and slot == ItemTypes.SLOT_ARMOR
	if magic_armor:
		ring_plus = 0   # magic armour and a ring of protection don't combine
	var body := maxi(armor_60, base_ac_60)
	ac = 60 - (body + shield_bonus + other_plus + ring_plus + dex_ac_bonus())
	# From behind, the shield and DEX don't help, and the defender is 2 worse.
	rear_ac = 60 - (body + other_plus + ring_plus - 2)

	# To hit and damage
	var hit_60 := base_thac0_60
	weapon_ranged = weapon != null and types.range_squares(weapon.type) > 1
	weapon_ranged_melee = weapon_ranged and (types.flags(weapon.type) & 0x14) == 0x14
	_missiles(types)
	if weapon == null:
		damage = base_damage.duplicate()
		damage_large = base_damage.duplicate()
		hit_60 += strength_hit_bonus()
		damage[2] += strength_damage_bonus()
		damage_large[2] += strength_damage_bonus()
	else:
		var t := weapon.type
		var f := types.flags(t)
		damage = types.damage(t, false)
		damage_large = types.damage(t, true)
		if f & ItemTypes.FLAG_DEX_TO_HIT:
			hit_60 += dex_missile_bonus()
		if f & ItemTypes.FLAG_MELEE:
			hit_60 += strength_hit_bonus()
			damage[2] += strength_damage_bonus()
			damage_large[2] += strength_damage_bonus()
		var ammo_plus := ammo.plus if ammo != null and ammo != weapon else 0
		damage[2] += weapon.plus + ammo_plus
		damage_large[2] += weapon.plus + ammo_plus
		var hit_plus := weapon.plus + ammo_plus
		if race_id == RACE_ELF and t in ELF_WEAPONS:
			hit_plus += 1
		hit_60 += hit_plus
	thac0 = 60 - hit_60

	# Movement: heavy armour first, then the load beyond what STR allows.
	# (Checked against the original's cached values: banded mail, 350 coins, gives 9;
	# splint mail, 400, gives 6.) Monsters keep the movement in their record until a
	# fight in the original shows otherwise: their items and loads aren't verified yet.
	movement = base_movement
	if is_monster:
		return
	if armor != null:
		var w := armor.weight
		if w > 150:
			movement = 9 if w < 400 else 6
	var over := weight - load_allowance()
	var by_load := movement
	if over > 0x400:
		by_load = 3
	elif over > 0x300:
		by_load = 6
	elif over > 0x200:
		by_load = 9
	movement = mini(movement, by_load)


# --- Money ---------------------------------------------------------------------------

## Coins on hand, in copper.
func wealth_copper() -> int:
	var total := 0
	for i in 5:
		total += money[i] * COIN_VALUE[i]
	return total


## Pays `gold` gold pieces. The change is regrouped into the largest coins but never
## electrum, as the original shows it (140 gold, after an 80-gold purchase, became 12
## platinum; lab 2026-11-11: 144 silver and 500 platinum, after 1000 gold of training,
## became 301 platinum, 2 gold, 4 silver).
func pay_gold(gold: int) -> bool:
	var left := wealth_copper() - gold * 200
	if left < 0:
		return false
	for i in range(4, -1, -1):
		if i == 2:
			money[i] = 0
			continue
		money[i] = left / COIN_VALUE[i]
		left -= money[i] * COIN_VALUE[i]
	return true


## Encumbrance in coins: every coin weighs 1, plus item weights (stacks count each piece).
## Matches the record's cached weight on all six shipped characters.
func encumbrance() -> int:
	var total := 0
	for i in 5:
		total += money[i]
	for it in items:
		total += it.total_weight()
	return total


func money_text() -> String:
	var parts := PackedStringArray()
	for i in range(4, -1, -1):
		if money[i] > 0:
			parts.append("%s %d" % [MONEY_NAMES[i], money[i]])
	return ", ".join(parts) if not parts.is_empty() else "no money"


# --- Training (the training halls' TRAIN CHARACTER) --------------------------------------
# The original's rules (Pool of Radiance's own texts and tables; the rule order as Pilgrim's
# reconstruction of the engine documents it):
# - Only conscious characters train ("WE ONLY TRAIN CONSCIOUS PEOPLE"), and training costs
#   1000 gold pieces' worth of the trainee's own money ("TRAINING COSTS 1000 GP.").
# - A class can advance when the character's experience reaches the next level's total
#   and the class isn't at its cap. If several classes can, the original trains only the
#   one whose next level costs the most experience.
# - The hall trains only its own classes ("WE DON'T TRAIN THAT CLASS HERE"), and only if
#   that class has the experience ("NOT ENOUGH EXPERIENCE").
# - On training: the level goes up; THAC0, saving throws, spells per day and attacks are
#   recalculated from the class tables; hit points go up by the better of two rolls of the
#   class's hit die (summed over the classes trained), divided among all the character's
#   classes, plus constitution (1 at least); clerics learn every cleric spell of the levels
#   they can now cast; a magic-user who gained a level picks one new spell to learn.

## Who controls this member, as scripts see it at 0x6BB8: 0 a player character; 128 and
## up an NPC (128 + morale / 2), whom the computer runs in fights and who won't pay for
## the party ("THAT PERSON WON'T PAY.").
var npc := 0
## 0x6C0C: 0x80 the computer runs this member in the fight, 0x81 it turns against the party.
var script_team := 0


func thief_skill(t: ClassTables, k: int) -> int:
	return t.thief_skill(k, level_in(6), race_id, stats[3])


## Constitution's hit point adjustment per class (index = constitution).
## Hit points from constitution, per class the character has (GAME.OVR 0x1D8B0): the
## table, and for a (single-class) fighter one more at CON 17 and another at 18.
static func con_hp_bonus(con: int, whole_class: int) -> int:
	var b: int = CON_HP[clampi(con, 0, CON_HP.size() - 1)]
	if whole_class == 2:
		b += (1 if con > 16 else 0) + (1 if con > 17 else 0)
	return b


const CON_HP := [0, 0, 0, -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]


func level_in(c: int) -> int:
	return raw[0x96 + c] if raw.size() > 0x96 + c else 0


func set_level(c: int, value: int) -> void:
	raw[0x96 + c] = value


func class_indices() -> Array[int]:
	var out: Array[int] = []
	for c in ClassTables.CLASS_COUNT:
		if level_in(c) > 0:
			out.append(c)
	return out


## What the hall (its class bits) would do with this character: {"error": text} or
## {"classes": [class indices that would advance]}.
func training_plan(t: ClassTables, hall_mask: int) -> Dictionary:
	if status != STATUS_OKAY:
		return {"error": "WE ONLY TRAIN CONSCIOUS PEOPLE"}
	if wealth_copper() < 1000 * 200:
		return {"error": "TRAINING COSTS 1000 GP."}
	var have_mask := 0
	var exp_mask := 0
	var last_level := 0
	for c in class_indices():
		have_mask |= ClassTables.CLASS_MASKS[c]
		last_level = level_in(c)
		var need := t.needed(c, level_in(c) + 1)
		if need > 0 and experience >= need:
			exp_mask |= ClassTables.CLASS_MASKS[c]
	# Several classes ready: the original keeps the one whose table entry (for the level
	# after the last class it looked at) is the largest, so a multi-class character trains
	# its slowest class first.
	var best := -1
	var best_exp := 0
	for c in class_indices():
		if exp_mask & ClassTables.CLASS_MASKS[c]:
			var e := t.needed(c, last_level + 1)
			if e > best_exp:
				best_exp = e
				best = c
	if best >= 0:
		exp_mask = ClassTables.CLASS_MASKS[best]
	if have_mask & hall_mask == 0:
		return {"error": "WE DON'T TRAIN THAT CLASS HERE"}
	if exp_mask & hall_mask == 0:
		return {"error": "NOT ENOUGH EXPERIENCE"}
	var classes: Array[int] = []
	for c in class_indices():
		if ClassTables.CLASS_MASKS[c] & exp_mask & hall_mask:
			classes.append(c)
	return {"classes": classes}


## Trains: pays, raises the levels in `classes` and recalculates everything that depends
## on level. Returns true if the character is a magic-user who should now learn a spell.
func train(t: ClassTables, table: SpellTable, classes: Array[int], rng: RandomNumberGenerator) -> bool:
	pay_gold(1000)
	var old_mu := level_in(5)
	for c in classes:
		set_level(c, level_in(c) + 1)
	apply_class_tables(t, table)
	# Hit points.
	var count := class_indices().size()
	var rolled := 0
	for c in classes:
		var die: int = t.hit_die[c]
		rolled += maxi(rng.randi_range(1, die), rng.randi_range(1, die))
	hp_rolled += maxi(rolled / count, 1)
	var con := 0
	for c in class_indices():
		con += con_hp_bonus(stats[4], class_id)
	var gain := maxi((rolled + con) / count, 1)
	var lost := hp_max - hp
	hp_max += gain
	hp = hp_max - lost
	raw[0x32] = hp_max
	raw[0xB1] = hp_rolled
	return level_in(5) > old_mu


## THAC0, saving throws, attacks and spells per day from the levels (and clerics' spell
## books), as the original recalculates them after training.
func apply_class_tables(t: ClassTables, table: SpellTable) -> void:
	var best_thac0 := 0
	var best_saves := PackedInt32Array([20, 20, 20, 20, 20])
	for c in class_indices():
		best_thac0 = maxi(best_thac0, t.thac0_at(c, level_in(c)))
		var s := t.saves_at(c, level_in(c))
		for k in 5:
			best_saves[k] = mini(best_saves[k], s[k])
	base_thac0_60 = best_thac0
	saves = best_saves
	raw[0x2D] = base_thac0_60
	for k in 5:
		raw[0x6D + k] = saves[k]
	if level_in(2) >= 7 or level_in(3) >= 7 or level_in(4) >= 8:
		half_attacks = 3
		raw[0xA1] = 3
	var cl := t.slots_at(0, level_in(0))
	if level_in(0) > 0:
		var wis := stats[2]
		if wis > 12 and cl[0] > 0: cl[0] += 1
		if wis > 13 and cl[0] > 0: cl[0] += 1
		if wis > 14 and cl[1] > 0: cl[1] += 1
		if wis > 15 and cl[1] > 0: cl[1] += 1
		if wis > 16 and cl[2] > 0: cl[2] += 1
	var mu := t.slots_at(5, level_in(5))
	spell_slots = [cl, mu]
	for k in 3:
		raw[0xB2 + k] = cl[k]
		raw[0xB5 + k] = mu[k]
	# Clerics know every cleric spell of the levels they have slots for.
	if table != null and level_in(0) > 0:
		for id in range(1, mini(spell_book.size(), SpellTable.NAMED) + 1):
			if table.spell_class(id) == SpellTable.CLERIC and table.level(id) <= 3 \
					and cl[table.level(id) - 1] > 0:
				spell_book[id - 1] = 1


## Magic-user spells this character could learn now (levels it has slots for, not known).
func learnable_spells(table: SpellTable) -> Array[int]:
	var out: Array[int] = []
	for id in range(1, mini(spell_book.size(), SpellTable.NAMED) + 1):
		if table.spell_class(id) == SpellTable.MAGE and table.level(id) <= 3 \
				and spell_slots[1][table.level(id) - 1] > 0 and spell_book[id - 1] == 0:
			out.append(id)
	return out


## The character record with everything that changes in play written back (for saves).
func to_record() -> PackedByteArray:
	var d := raw.duplicate()
	if d.size() < 285:
		return d
	d[0x32] = hp_max
	d[0x11B] = clampi(hp, 0, 255)
	d.encode_u32(0xAC, experience)
	d[0x10C] = status
	for i in 7:
		d.encode_u16(0x88 + i * 2, clampi(money[i], 0, 65535))
	for i in spell_book.size():
		d[0x33 + i] = spell_book[i]
	for i in range(0x17, 0x2C):
		d[i] = 0
	for k in memorized.size():
		if 0x2B - k >= 0x17:
			d[0x2B - k] = memorized[k]
	return d

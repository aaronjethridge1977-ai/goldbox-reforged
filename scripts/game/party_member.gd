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
var quick_order := 0                  # B3: SmartQuick.FREE/NOSPELL/MELEE/HOLD/HEAL (ours only, quick saves)

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

# The record's cached THAC0 and AC (+0x110, +0x111, 60-based) as the original keeps them (main chat 82).
# The original works them out again only at its refresh (START.EXE 0xba:0xbb8): VIEW, READY, TRADE, DROP,
# a gem's SELL, a fight's start and end; TRAIN raises the base THAC0 (+0x2D) and leaves the cache, and a
# load keeps the save's. PARTY_STRENGTH (GAME.OVR 0x200C) reads the cache: p36h1's band at 7:26 found
# ARN's and LIRA's stale after the fighters' hall (49, not ours' 51). Ours keeps the cache equal to the
# live values (recalculate()) except while frozen: from TRAIN, or a loaded record whose cache differs,
# until refresh_cache().
var cache_frozen := false
var cache_thac0 := 0
var cache_ac := 0
var _cache_from_record := false
var weight := 0
## The load the original keeps in the record (+0x102, a word): START.EXE 0x1924 writes it when GAME.OVR asks
## for the record to be worked out again (0xBA:0xBB8 -> 0x1758, 22 sites; ours: refresh_load_word() at
## each, not in every recalculate()), the coin sites raise and lower it (GAME.OVR 0x24CC3 / 0x24CA9: raise_load /
## lower_load), payments and item purchases leave it, and the coin tests read it (0x24CDD). Read from and
## written to saves (Q28 (a), chat 63: main's part; Combat Chat 29: the sites and the tests).
var load_word := 0


static func load_files(sav_path: String, itm_path: String) -> PartyMember:
	sav_path = GameData.real_path(sav_path)
	itm_path = GameData.real_path(itm_path)
	var d := FileAccess.get_file_as_bytes(sav_path)
	if d.size() < 285:
		return null
	var item_data := PackedByteArray()
	if FileAccess.file_exists(itm_path):
		item_data = FileAccess.get_file_as_bytes(itm_path)
	var m := from_bytes(d, item_data)
	if m != null:
		m.raise_highest()     # a character joining the party: the recount (0x1F55A)
		# Chat 31 (Player 5): record byte 0xB8 is who controls a character (the scripts' 0x6BB8: 128 + morale / 2
		# for an NPC, 0 a player character; a monster record's experience value is the same byte). An original's
		# save loaded without it made DIRTEN a player character (the finale's vote asked him).
		m.npc = d[0xB8]
	var spc_path := GameData.real_path(sav_path.get_basename() + ".SPC")
	if m != null and FileAccess.file_exists(spc_path):
		SpecialAffects.add_records(m, FileAccess.get_file_as_bytes(spc_path))
	return m


## Lab dice (TpDice): icon colours the original drew as the script's LOAD_MON loaded the
## record (GAME.OVR 0x1EF8B under the LOAD_MON handler, before a TREASURE's random items and
## the fight), by monster id, oldest first; load_monster takes them instead of drawing.
static var colours_drawn := {}


## LOAD_MON's draws: five d6 for the record's colours (lab dice only, as load_monster's).
static func draw_colours(id: int) -> void:
	if not TpDice.on:
		return
	var five := []
	for k in 5:
		five.append(TpDice.random(6, "monster colour") + 1)
	if not colours_drawn.has(id):
		colours_drawn[id] = []
	colours_drawn[id].append(five)


## A monster: block `id` of MON<file_no>CHA.DAX, with its items from MON<file_no>ITM.DAX.
static func load_monster(game_path: String, file_no: int, id: int) -> PartyMember:
	var cha := DaxFile.open(game_path.path_join("MON%dCHA.DAX" % file_no))
	if cha == null or not cha.blocks.has(id):
		return null
	var item_data := PackedByteArray()
	var itm_path := game_path.path_join("MON%dITM.DAX" % file_no)
	if GameData.exists(itm_path):
		var itm := DaxFile.open(itm_path)
		if itm and itm.blocks.has(id):
			item_data = itm.blocks[id]
	var m := from_bytes(cha.blocks[id], item_data)
	if m and TpDice.on:
		# As GAME.OVR loads a monster record (0x1EF8B, side chat 2): 0xC0 from the race (1,
		# 3, 5: 1; 2, 4, 6, 7: 2), then five icon colours, each (d6 + 8) * 16 + the same d6,
		# in 0xC1-0xC3 and 0xC5-0xC6, 0xC4 = 0xC4. Lab dice only for now: whether 0xC0 changes
		# which icon some monsters show is not yet checked.
		var race: int = m.raw[0x2E]
		if race in [1, 3, 5]:
			m.raw[0xC0] = 1
		elif race in [2, 4, 6, 7]:
			m.raw[0xC0] = 2
		var drawn: Array = colours_drawn[id].pop_front() if not colours_drawn.get(id, []).is_empty() else []
		var j := 0
		for k in [0xC1, 0xC2, 0xC3, 0xC5, 0xC6]:
			var r: int = drawn[j] if j < drawn.size() else TpDice.random(6, "monster colour") + 1
			j += 1
			m.raw[k] = ((r + 8) * 16 + r) & 0xFF
			if k == 0xC3:
				m.raw[0xC4] = 0xC4
	if m:
		m.is_monster = true
		m.affects.clear()
		var spc_path := game_path.path_join("MON%dSPC.DAX" % file_no)
		var spc := DaxFile.open(spc_path) if GameData.exists(spc_path) else null
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
	m._cache_from_record = true
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
	m.load_word = d.decode_u16(0x102)
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
## Chat 33: the record is duplicated: a Packed array assigned in Godot 4 is the same array
## (from_bytes keeps it), so a copy's record writes went into the original's. The bot's
## branch explorer forks the script VM with cloned members; its tries of JOIN TYRANTHRAXUS
## (5:7 0xA771, side byte 0x10C -> record 0x10E) turned the real ARN, BRAM and CEDRIC against
## the party in every full run's Tyranthraxus fight; the arena's ROLF set the duelist's 0x84.
func clone() -> PartyMember:
	var m := from_bytes(raw.duplicate(), PackedByteArray())
	m.is_monster = is_monster
	m.hp = hp
	m.status = status
	m.experience = experience
	m.load_word = load_word
	m.money = money.duplicate()
	m.memorized = memorized.duplicate()
	m.affects = affects.duplicate(true)
	m.spell_book = spell_book.duplicate()
	m.npc = npc
	m.cache_frozen = cache_frozen
	m.cache_thac0 = cache_thac0
	m.cache_ac = cache_ac
	m._cache_from_record = _cache_from_record
	for it in items:
		var c := GameItem.from_record(it.to_record())
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
	# START.EXE 0xba:0x26c2 (chat 80, check 186): the item spells (class 2, ids 57-67: Speed, Giant
	# Strength, Healing...) are cast at a fixed 12, whoever uses the item (DOSBox: LIRA, magic-user 1,
	# drinks a Potion of Speed in camp: haste with power 12).
	if table.spell_class(id) == SpellTable.MONSTER:
		return 12
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
const READ_MAGIC := 18


## A scroll: its type's slot is 11-13 (GAME.OVR 0x2A255). Every SCRIBE path asks it first (REST's time
## 0x17831, the rest's copying 0x247EE, SCRIBE's list 0x184BE): other items' bytes 60-62 hold other
## things (Player 18: LIRA's Cloak, byte 62 = 0x85, made ours offer 4:15 at the inn; the original 0:00).
static func is_scroll(it: GameItem) -> bool:
	var t: ItemTypes = CharacterSheet.types
	if t == null:
		return true
	var s := t.slot(it.type)
	return s >= 11 and s <= 13


func scribe_pending() -> Array[int]:
	var out: Array[int] = []
	for it in items:
		if not is_scroll(it):
			continue
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] > 0x80:
				out.append(it.raw[k] & 0x7F)
	return out


## Copies the first marked scroll spell into the book and spends it from the scroll
## (spend_scroll_spell). Returns the spell id (0 if none was marked).
func scribe_next() -> int:
	for it in items:
		if not is_scroll(it):
			continue
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] > 0x80:
				var id: int = it.raw[k] & 0x7F
				it.raw[k] = id       # unmarked (spend_scroll_spell empties the spell's last slot)
				it.raw[53] = 0       # the scroll has been read (lab: "MAGIC USER SCROLL WITH 2 SPELLS" after)
				if id <= spell_book.size():
					spell_book[id - 1] = 1
				spend_scroll_spell(it, id)
				return id
	return 0


## A scroll gives up a spell (GAME.OVR 0x2A2A2): the last of its bytes 60-62 holding the spell
## is emptied, its name word 48 ("WITH n SPELLS": 212, 211, 210) counts one down, and below 210
## the scroll is gone, whatever its slots still hold (lab, chat 76: SCRIBE from a 211 scroll
## leaves it 210 with the other spell; a 210 scroll is gone; a 212 scroll with one spell stays,
## 211 and empty).
func spend_scroll_spell(it: GameItem, id: int) -> void:
	var slot := 0
	for k in [60, 61, 62]:
		if it.raw.size() > k and it.raw[k] & 0x7F == id:
			slot = k
	if slot == 0:
		return
	it.raw[slot] = 0
	it.raw[48] = (it.raw[48] + 255) & 0xFF
	if it.raw[48] < 210:
		items.erase(it)
	else:
		it.name = ""           # named again from its words (ItemNames): one spell fewer


## SCRIBE's list (lab, chat 22, save J's Darkstar with a scroll from the treasure): every
## magic-user spell on the member's scrolls that the member can read: a scroll read before
## (record byte 53 = 0, "... WITH n SPELLS"), or any scroll while Read Magic is on the member
## (an unread scroll, byte 53 = 6: "HAS NO COPYABLE SCROLLS" without it). Whatever the
## spell's level and whether it is known: choosing it says why not (CampScreen). The
## original's checks: GAME.OVR 0x1838D (SCRIBE), 0x17B9D (the member's condition).
func scribable(table: SpellTable) -> Array:
	var out: Array = []     # [item, record byte, id]
	if class_level(1) == 0:
		return out
	var reading := table.effect(READ_MAGIC) > 0 and has_affect(table.effect(READ_MAGIC))
	for it in items:
		if it.raw.size() < 63 or not is_scroll(it) or (it.raw[53] != 0 and not reading):
			continue
		for k in [60, 61, 62]:
			var id: int = it.raw[k] & 0x7F
			if id == 0 or id > SpellTable.NAMED or table.spell_class(id) != SpellTable.MAGE:
				continue
			out.append([it, k, id])
	return out


## Why SCRIBE refuses a spell on the list ("" if it can be marked): the original's messages.
func scribe_refusal(table: SpellTable, it: GameItem, k: int) -> String:
	var id: int = it.raw[k] & 0x7F
	if knows(id):
		return "YOU ALREADY KNOW THAT SPELL"
	if it.raw[k] > 0x80:
		return "YOU ARE ALREADY SCIBING THAT SPELL"     # sic, the original's spelling
	var lvl := table.level(id)
	if lvl < 1 or lvl > 3 or spell_slots[1][lvl - 1] == 0:
		return "YOU CAN NOT SCRIBE THAT SPELL."
	return ""


## Unmarks every scroll spell marked for SCRIBE (NO at "SCRIBE THESE SPELLS?").
func cancel_scribing() -> void:
	for it in items:
		if not is_scroll(it):
			continue
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] > 0x80:
				it.raw[k] &= 0x7F


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


## The hours of study before the spells themselves (4, or 6 with a 3rd-level spell); the
## 15 minutes a spell level come after them (learn_minutes is the whole).
func learn_study_hours(table: SpellTable) -> int:
	var top := 0
	for id in learning_spells() + scribe_pending():
		top = maxi(top, table.level(id))
	if top == 0:
		return 0
	return 6 if top > 2 else 4


## After each MEMORIZE pick the original sorts the record's spell bytes 0x17..0x2B by spell id (GAME.OVR
## 0x18055, called from 0x1827E: a selection sort, ascending, the being-memorized bit ignored; empties go to
## 0x17's end). `memorized` runs from 0x2B down, so the list then reads highest id first (Combat Chat 19,
## c18c7: CEDRIC's two new Cure Light Wounds listed above his Bless; ours had appended them below it).
func sort_memorized() -> void:
	var b: Array[int] = []
	b.resize(21)
	b.fill(0)
	for k in memorized.size():
		if k < 21:
			b[20 - k] = memorized[k]
	for i in 20:
		for j in range(i, 21):
			if b[i] % LEARNING > b[j] % LEARNING:
				var t := b[i]
				b[i] = b[j]
				b[j] = t
	var out: Array[int] = []
	for k in range(20, -1, -1):
		if b[k] != 0:
			out.append(b[k])
	memorized = out


## A script's write into the record (the character window's 0x20..0x70, GAME.OVR 0x7F6C: record byte
## `r` = offset - 8): the memorized spells 0x17..0x2B (`memorized` from 0x2B down; a 0 between them drops
## out, as our list keeps no gaps), the maximum HP at 0x32, the spell book from 0x33, else the raw byte.
func set_record_byte(r: int, v: int) -> void:
	if r >= 0x17 and r <= 0x2B:
		var b: Array[int] = []
		b.resize(21)
		b.fill(0)
		for k in mini(memorized.size(), 21):
			b[20 - k] = memorized[k]
		b[r - 0x17] = v
		var out: Array[int] = []
		for i in range(20, -1, -1):
			if b[i] != 0:
				out.append(b[i])
		memorized = out
	elif r == 0x32:
		hp_max = v
	elif r >= 0x33 and r < 0x33 + spell_book.size():
		spell_book[r - 0x33] = v
	elif r < raw.size():
		raw[r] = v


## Removes one memorized copy of `id` (after casting it, or losing it).
func forget(id: int) -> void:
	# The copy lowest in the record goes (Combat Chat 18, DOSBox: ELWEN's Bless cast with the list's last
	# Bless lit took the first one listed); `memorized` runs from the record's top down, so the last here.
	var i := memorized.rfind(id)
	if i >= 0:
		memorized.remove_at(i)


func has_affect(effect_id: int) -> bool:
	for a in affects:
		if int(a.effect) == effect_id:
			return true
	for it in items:
		if it.readied and it.raw.size() > 62 and it.raw[62] in ItemPowers.LENDS and it.raw[61] == effect_id:
			return true     # a readied item lends it (ItemPowers)
	return false


func is_large() -> bool:
	return size > 0x80 or (size & 7) > 1


func thief_level() -> int:
	return raw[0x9C] if raw.size() > 0x9C else 0


const STATUS_ANIMATED := 1
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


## DEX defensive adjustment, as AC points gained (positive = better AC). The game's table (START.EXE
## 0xBA:0x10E6) has nothing outside 1-25: a DEX of 0 (monsters such as the hill giants, Combat Chat 8: AC 4
## in the original's record, 8 in ours) or above 25 gives 0.
func dex_ac_bonus() -> int:
	var x := stats[3]
	if x <= 0 or x > 25:
		return 0
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
	# The load counts all seven kinds of coins, gems and jewellery too, as a word (START.EXE 0x1924: record
	# +0x102; Combat Chat 16, p11t1: ARN's 1290 jewellery put him at his ceiling and moved him 3).
	weight = 0
	for i in 7:
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
		# START.EXE 0x1847: each readied item's slot pointer (record +0xCC + slot x 4) is set in list order, so
		# with two weapons readied (a monster's) the last is "the readied weapon" (Combat Chat 19, c18c7's orc leader).
		if slot == ItemTypes.SLOT_WEAPON:
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
	# splint mail, 400, gives 6.) Monsters too (lab, side chat 2: a goblin guard, 6 in its
	# record, had 9 in the original's fight record, +0x11C, and walked 18 half-moves).
	movement = base_movement
	if armor != null:
		var w := armor.weight
		if w > 150:
			movement = 9 if w < 400 else 6
		# Magic body armour (any plus or minus, item byte 0x32) lightens the step: +3 when
		# the movement is 9 or less here (START.EXE 0xDF4-0xE19, body armour only, slot 2).
		if armor.plus != 0 and movement <= 9 and types.slot(armor.type) == ItemTypes.SLOT_ARMOR:
			movement += 3
	weight &= 0xFFFF
	# START.EXE 0xF40: the load over the allowance is a 16-bit word tested signed, a negative one taken
	# as 0 (no limit): above 32767 over it, the original lets a member walk unburdened (Combat Chat 25:
	# main's 5:6 priest check, DORN at 47338 with an allowance of 2000 walked his splint mail's 6).
	var over := (weight - load_allowance()) & 0xFFFF
	if over >= 0x8000:
		over = 0
	var by_load := movement
	if over > 0x400:
		by_load = 3
	elif over > 0x300:
		by_load = 6
	elif over > 0x200:
		by_load = 9
	movement = mini(movement, by_load)
	if _cache_from_record:
		_cache_from_record = false
		# A loaded record keeps its cache (a load doesn't refresh it): stale after a TRAIN in the original.
		if not is_monster and raw.size() > 0x111 and raw[0x110] != 0 \
				and (raw[0x110] != clampi(60 - thac0, 0, 255) or raw[0x111] != clampi(60 - ac, 0, 255)):
			cache_thac0 = raw[0x110]
			cache_ac = raw[0x111]
			cache_frozen = true


## The cache as the original holds it now (60-based THAC0 and AC).
func cached_thac0_60() -> int:
	return cache_thac0 if cache_frozen else clampi(60 - thac0, 0, 255)


func cached_ac_60() -> int:
	return cache_ac if cache_frozen else clampi(60 - ac, 0, 255)


## Keep the cache as it stands while the live values change (TRAIN).
func freeze_cache() -> void:
	if not cache_frozen:
		cache_thac0 = cached_thac0_60()
		cache_ac = cached_ac_60()
		cache_frozen = true


## The original's refresh (START.EXE 0xba:0xbb8): the cache follows the live values again.
func refresh_cache() -> void:
	cache_frozen = false


# --- Money ---------------------------------------------------------------------------

## Coins on hand, in copper.
func wealth_copper() -> int:
	var total := 0
	for i in 5:
		total += money[i] * COIN_VALUE[i]     # coins only: gems and jewellery are not money
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


## A shop's purchase: all the coins together pay, and what is left comes back in platinum
## and gold only, the part under a gold piece lost (lab, chat 10, New Phlan's arms shop:
## 144 silver and 2 platinum paying 1 gold left 3 platinum and 1 gold; 3 platinum paying 1
## gold left 2 platinum and 4 gold). Training gives silver change (pay_gold).
func pay_gold_in_shop(gold: int) -> bool:
	var left := wealth_copper() - gold * 200
	if left < 0:
		return false
	var whole := left / COIN_VALUE[3]
	for i in 5:
		money[i] = 0
	money[4] = whole * COIN_VALUE[3] / COIN_VALUE[4]
	money[3] = whole - money[4] * COIN_VALUE[4] / COIN_VALUE[3]
	return true


## A shop pays `gold` gold pieces in the largest coins, keeping the purse's other coins as
## they are (lab, chat 8: selling a Two-Handed Sword for 15 gold added 3 platinum, a Flail
## for 1 gold added 1 gold; silver untouched).
func receive_gold(gold: int) -> void:
	money[4] += gold / 5
	money[3] += gold % 5


## What Raise Dead costs the raised (the temple's RAISE DEAD, GAME.OVR 0x4B76-0x4C9D, after it sets HP 1
## and status 0): one point of constitution (if above 0); then, only when the new constitution is still
## 14 or more, max HP drops by (max HP - HP rolled) / w, where w sums each class's level x its new
## per-level bonus (fighters CON - 14, other classes 2 above 15, else 1), all in bytes as the original
## computes them; no drop at constitution 17 or more for a character without fighter levels.
func raised_from_dead() -> void:
	if stats[4] > 0:
		stats[4] -= 1
	if raw.size() > 0x14:
		raw[0x14] = stats[4]
	var con := stats[4]
	if con < 14:
		return
	var cut := (hp_max - hp_rolled) & 0xFF if hp_max > hp_rolled else 0
	var w := 0
	for c in 8:
		var lv := level_in(c)
		if lv > 127 or lv == 0:
			continue
		if c == 2:
			w += lv * (con - 14)
		elif con > 15:
			w += lv * 2
		else:
			w += lv
		w &= 0xFF
	if w > 0:
		cut = (cut / w) & 0xFF
	if con >= 17 and level_in(2) == 0:
		return
	hp_max = (hp_max - cut) & 0xFF
	if raw.size() > 0x32:
		raw[0x32] = hp_max


## Detect Magic (spells 5 and 11, effect 5) is on while any member of the party has its effect; the
## item lists then mark magic items (GameItem.detect_magic_marks). The effect's handler does nothing else.
const DETECT_MAGIC := 5

static func party_detects_magic(party: Array) -> bool:
	for m in party:
		if m != null and m.has_affect(DETECT_MAGIC):
			return true
	return false


## The most a character may carry, in coins of load: the strength allowance + 1500 (GAME.OVR
## 0x24C89 calls START.EXE 0xBA:0x13AB, the same table as load_allowance, and adds 0x5DC).
func max_load() -> int:
	return load_allowance() + 1500


## Whether the character can take an item (treasure TAKE, a shop's BUY, TRADE): GAME.OVR 0x23795
## refuses ("OVERLOADED") a 17th item (record byte 0xC7 above 15) or one whose weight (x its count
## when that is above 0) takes the load above max_load().
func can_take_item(it: GameItem) -> bool:
	if items.size() > 15:
		return false
	return encumbrance() + it.total_weight() <= max_load()


## Whether `n` coins (any kind: each weighs 1) fit: GAME.OVR 0x24CDD. The treasure's TAKE of money
## (0x2570F) takes nothing at all when they don't ("OVERLOADED"); coins_room() is what still fits.
## (Combat Chat 29: both read the cached word, load_word, as the original does.)
func can_take_coins(n: int) -> bool:
	if not OriginalBugs.on():
		return encumbrance() + n <= max_load()       # bug #10's fix: the load as carried
	return ((load_word + n) & 0xFFFF) <= (max_load() & 0xFFFF)


func coins_room() -> int:
	if not OriginalBugs.on():
		return maxi(max_load() - encumbrance(), 0)  # bug #10's fix
	return maxi((max_load() & 0xFFFF) - load_word, 0)


## The original's recompute of the cached load (START.EXE 0x1924, from GAME.OVR's 22 calls of 0xBA:0xBB8):
## a fight's setup for every figure (0xD8DA) and each figure's turn (0x9A8A), the character VIEW on entry and
## after its item actions (0x2165C, 0x224AF, 0x2280B), the treasure's item TAKE (0x237A1), APPRAISE (0x26ECA),
## ADD_NPC (0x3933), creation and MODIFY (0x1C22C / 0x1C23B), a level or strength change (0x10FE9, 0xF568,
## 0xF715, 0x2C14D), 0x7018.
func refresh_load_word() -> void:
	load_word = encumbrance()


## GAME.OVR 0x24CC3 / 0x24CA9: the coin sites' changes to the cached load (a word: it wraps).
func raise_load(n: int) -> void:
	load_word = (load_word + n) & 0xFFFF


func lower_load(n: int) -> void:
	load_word = (load_word - n) & 0xFFFF


## Encumbrance in coins: every coin, gem and piece of jewelry weighs 1, plus item weights (stacks count each piece).
## Matches the record's cached weight on all six shipped characters.
func encumbrance() -> int:
	var total := 0
	for i in 7:
		total += money[i]     # gems and jewelry weigh 1 each too (lab chat 11: save I)
	for it in items:
		total += it.total_weight()
	return total & 0xFFFF     # a word, as the original keeps it (record +0x102): a count wrapped below 0 cancels out


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


## Record byte 0x73, the highest level the character has had: the original's level recount
## (GAME.OVR 0x2AA87, after training and as a character joins the party, 0x1F55A) raises it
## to the highest class level and never lowers it. A level drain kills "forever" below 2
## (0x10F15), so a trained character left at creation's 1 died forever at the first drain
## (chat 26's full run, Valhingen Graveyard).
func raise_highest() -> void:
	if raw.size() <= 0x9E:
		return
	var top := 0
	for c in 8:
		top = maxi(top, level_in(c))
	if raw[0x73] < top:
		raw[0x73] = top


func class_indices() -> Array[int]:
	var out: Array[int] = []
	for c in ClassTables.CLASS_COUNT:
		if level_in(c) > 0:
			out.append(c)
	return out


## What the hall (its class bits) would do with this character: {"error": text} or
## {"classes": [class indices that would advance]}. As the original's TRAIN (GAME.OVR 0x1C32B;
## Player 3 played each hall, chat 28): once the fee can be paid, every class not at its race's
## cap whose next level the experience reaches is ready, and the experience is lowered at once
## (trained or not) to the largest "experience for the level after next, less 1" among the ready
## classes that it reaches (0x1C5A3..0x1C61C: no carrying two levels' worth); then the hall
## trains every ready class it teaches (a cleric/fighter/magic-user trains fighter in the
## fighters' hall when that class is ready).
func training_plan(t: ClassTables, hall_mask: int) -> Dictionary:
	if status != STATUS_OKAY:
		return {"error": "WE ONLY TRAIN CONSCIOUS PEOPLE"}
	if wealth_copper() < 1000 * 200:
		return {"error": "TRAINING COSTS 1000 GP."}
	var have_mask := 0
	var exp_mask := 0
	var cap := 0
	for c in class_indices():
		have_mask |= ClassTables.CLASS_MASKS[c]
		if LevelDrain.race_capped(self, c):
			continue
		var need := t.needed(c, level_in(c) + 1)
		if need <= 0 or experience < need:
			continue
		exp_mask |= ClassTables.CLASS_MASKS[c]
		var after := t.needed(c, level_in(c) + 2)
		if after > 0 and experience >= after and after - 1 > cap:
			cap = after - 1
	if cap > 0:
		experience = cap
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
## Hit points (0x1C923): one roll of each trained class's dice (DS:0x8B6 count, 0x8BE size,
## the game's dice at 0x1DC04; at level 1 at least two thirds of the die), summed; record 0xB1
## gains that / the number of classes (at least 1), max HP that plus the CON bonus, / classes.
func train(t: ClassTables, table: SpellTable, classes: Array[int], rng: RandomNumberGenerator) -> bool:
	freeze_cache()     # the original's TRAIN leaves +0x110/+0x111 as they were (main chat 82)
	pay_training(1000)
	var old_mu := level_in(5)
	for c in classes:
		set_level(c, level_in(c) + 1)
		# GAME.OVR 0x1C89C: a level trained while drained pays back one drained level's share
		# of the drain's record (0x75 less 0x75 / 0x74, 0x74 - 1); the hit points come from the
		# roll below, not from the drain.
		if raw[0x74] > 0:
			raw[0x75] -= raw[0x75] / raw[0x74]
			raw[0x74] -= 1
	apply_class_tables(t, table)
	# Hit points.
	var count := class_indices().size()
	var rolled := 0
	for c in classes:
		var die: int = t.hit_die[c]
		var r := 0
		for k in maxi(int(t.first_dice[c]), 1):
			r += (TpDice.random(die, "training HP") + 1) if TpDice.on else rng.randi_range(1, die)
		if level_in(c) == 1:
			r = maxi(r, die * 2 / 3)
		rolled += r
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


## Training's fee as the original takes it (GAME.OVR 0x1DC6C): coin by coin from copper up,
## each kind giving what it has up to one coin past the rest of the fee; what was paid over
## comes back as change from platinum down (1500 gold pays 1001 and gets 1 back: 500 left;
## 144 silver and 500 platinum: 144 silver and 199 platinum, change 2 gold 4 silver).
func pay_training(gold: int) -> bool:
	var left := gold * 200
	if wealth_copper() < left:
		return false
	for i in 5:
		if left <= 0:
			break
		var n := mini(left / COIN_VALUE[i] + 1, money[i])
		left -= n * COIN_VALUE[i]
		money[i] -= n
	if left < 0:
		left = -left
		for i in range(4, -1, -1):
			if left <= 0:
				break
			var n: int = left / COIN_VALUE[i]
			left -= n * COIN_VALUE[i]
			money[i] += n
	return true


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
	raise_highest()
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
	# Chat 27 (Player 2's request): the combat cache the original keeps in the record, from
	# recalculate() (which reproduces the shipped characters' caches); left 0 for a member made
	# in ours, the original's party list showed AC 60 until a fight worked it out.
	if not is_monster:
		d[0x110] = cached_thac0_60()
		d[0x111] = cached_ac_60()
		d[0x112] = clampi(60 - rear_ac, 0, 255)
		d[0x115] = clampi(int(damage[0]), 0, 255)
		d[0x117] = clampi(int(damage[1]), 0, 255)
		d[0x119] = int(damage[2]) & 0xFF
		d[0x11C] = clampi(movement, 0, 255)
	for i in 7:
		d.encode_u16(0x88 + i * 2, clampi(money[i], 0, 65535))
	d.encode_u16(0x102, load_word & 0xFFFF)
	for i in spell_book.size():
		d[0x33 + i] = spell_book[i]
	for i in range(0x17, 0x2C):
		d[i] = 0
	for k in memorized.size():
		if 0x2B - k >= 0x17:
			d[0x2B - k] = memorized[k]
	return d

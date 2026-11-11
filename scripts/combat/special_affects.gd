class_name SpecialAffects
extends RefCounted
## Standing effects ("affects") that carry racial abilities and monsters' special powers, as
## the original runs them. Characters keep them in CHRDATxn.SPC, monsters in MONnSPC.DAX
## (same block id as the monster), as 9-byte records with the effect type first; character
## creation gives each race its own (GAME.OVR 0x1A12E). GAME.OVR fills a table of handlers
## per effect type (DS:0x682C, set up at file 0x11E00); the handlers decoded so far:
##
##   0x12 gnome    +1 to hit KOBOLD, KOBOLD LEADER, GOBLIN, GOBLIN LEADER (type 1, size 1)
##   0x1A dwarf    +1 to hit ORC, ORC LEADER, GOBLIN, GOBLIN LEADER, HOBGOBLIN,
##                 HOBGOBLIN CHIEF, GAGOOL, MACE (type 1, size 1)
##   0x2F dwarf, gnome: OGRE, OGRE LEADER, TROLL, FIRE GIANT, HILL GIANT of type 1 and
##                 size 2 hit them at -4
##   0x30 gnome    BUGBEAR and GNOLL (type 1) hit them at -4
##   0x5A dwarf, halfling: CON bonus to saves of kind 0 (poison)  (CON 4-6 +1, 7-10 +2,
##   0x61 dwarf, halfling, gnome: CON bonus to kinds 2 and 4      11-13 +3, 14-17 +4, 18+ +5)
##   0x6B elf      90% to throw off Sleep and Charm       0x7C half-elf  30%
##   0x6C          no Sleep or Charm                      0x6D  no Hold/paralysis
##   0x6F          no Hold or poison, always saves against kind 0
##   0x7D          no Charm, Sleep, Hold or poison, always saves against kind 0
##   0x6E          no cold damage      0x70  no fire damage      0x76  half cold damage
##   0x73          half damage from weapons that aren't blunt (item type field 7 not 128)
##   0x77          only magic weapons hurt it (or monsters of 4+ levels: record 0x73)
##   0x40 / 0x41 / 0x42 / 0x46  a hit poisons: save vs kind 0 at +0 / +4 / +2 / -2 or
##                 "IS POISONED", "IS KILLED"
##   0x43          a hit paralyses for 2d8 rounds unless the target saves (kind 0)
##   0x44          a hit paralyses (63 rounds) unless the target saves; elves are immune
##   0x55 / 0x56   a hit drains 1 / 2 levels ("IS DRAINED A LEVEL" / " 2 LEVELS")

const POISONED := 0x37
const PARALYZED := 0x34
const SLEEP := 0x35
const CHARM := 0x0B

const RACIAL := {1: [0x5A, 0x61, 0x1A, 0x2F], 2: [0x6B], 3: [0x61, 0x12, 0x2F, 0x30],
	4: [0x7C], 5: [0x5A, 0x61]}

const DWARF_FOES := ["ORC", "ORC LEADER", "GOBLIN", "GOBLIN LEADER", "HOBGOBLIN",
	"HOBGOBLIN CHIEF", "GAGOOL", "MACE"]
const GNOME_FOES := ["KOBOLD", "KOBOLD LEADER", "GOBLIN", "GOBLIN LEADER"]
const BIG_FOES := ["OGRE", "OGRE LEADER", "TROLL", "FIRE GIANT", "HILL GIANT"]
const GNOME_BIG_FOES := ["BUGBEAR", "GNOLL"]
const POISON_BONUS := {0x40: 0, 0x41: 4, 0x42: 2, 0x46: -2}


## Adds standing effects (0 minutes = for good) of the given types, skipping ones present.
static func add(m: PartyMember, types: Array) -> void:
	for t in types:
		if int(t) > 0 and not m.has_affect(int(t)):
			m.affects.append({"effect": int(t), "spell": 0, "minutes": 0, "value": 0xFF})


## The effects in a .SPC file or MONnSPC block: 9-byte records of type, minutes left
## (u16, 0 = for good), power, then the game's own list pointers. A saved character keeps
## spells still running this way (the shipped party carries a Bless with 2 minutes left).
static func add_records(m: PartyMember, data: PackedByteArray) -> void:
	for o in range(0, data.size() - 8, 9):
		var type := data[o]
		if type == 0 or m.has_affect(type):
			continue
		m.affects.append({"effect": type, "spell": 0, "minutes": data.decode_u16(o + 1), "value": data[o + 3]})


static func _raw(m: PartyMember, off: int) -> int:
	return m.raw[off] if m.raw.size() > off else 0


static func _named(m: PartyMember, names: Array) -> bool:
	return m.name.strip_edges().to_upper() in names


## Bonus to a saving throw of `kind` from standing effects.
static func save_bonus(m: PartyMember, kind: int) -> int:
	var b := 0
	var con: int = m.stats[4] if m.stats.size() > 4 else 0
	var con_bonus := 0
	if con >= 18:
		con_bonus = 5
	elif con >= 14:
		con_bonus = 4
	elif con >= 11:
		con_bonus = 3
	elif con >= 7:
		con_bonus = 2
	elif con >= 4:
		con_bonus = 1
	if kind == 0 and m.has_affect(0x5A):
		b += con_bonus
	if (kind == 2 or kind == 4) and m.has_affect(0x61):
		b += con_bonus
	if kind == 0 and (m.has_affect(0x6F) or m.has_affect(0x7D)):
		b += 100
	return b


## Whether `m` throws off an effect of `type` (SLEEP, CHARM, PARALYZED, POISONED);
## `roll_d100` gives the elves' and half-elves' chance roll.
static func blocks(m: PartyMember, type: int, roll_d100: Callable) -> bool:
	if type == SLEEP or type == CHARM:
		if m.has_affect(0x6C) or m.has_affect(0x7D):
			return true
		if m.has_affect(0x6B) and int(roll_d100.call()) <= 90:
			return true
		if m.has_affect(0x7C) and int(roll_d100.call()) <= 30:
			return true
	if type == PARALYZED and (m.has_affect(0x6D) or m.has_affect(0x6F) or m.has_affect(0x7D)):
		return true
	if type == POISONED and (m.has_affect(0x6F) or m.has_affect(0x7D)):
		return true
	return false


## To-hit adjustment for `attacker` against `target` from either side's standing effects.
static func hit_bonus(attacker: PartyMember, target: PartyMember) -> int:
	var b := 0
	if _raw(target, 0x9F) == 1 and _raw(target, 0x6C) == 1:
		if attacker.has_affect(0x1A) and _named(target, DWARF_FOES):
			b += 1
		if attacker.has_affect(0x12) and _named(target, GNOME_FOES):
			b += 1
	if _raw(attacker, 0x9F) == 1:
		if target.has_affect(0x2F) and (_raw(attacker, 0x6C) & 0x7F) == 2 and _named(attacker, BIG_FOES):
			b -= 4
		if target.has_affect(0x30) and _named(attacker, GNOME_BIG_FOES):
			b -= 4
	return b


## Weapon damage after the target's standing effects. `weapon` is the attacker's readied
## weapon or null; `types` the ITEMS table.
static func weapon_damage(attacker: PartyMember, target: PartyMember, weapon: GameItem,
		types: ItemTypes, dmg: int) -> int:
	if target.has_affect(0x77):
		var magic_weapon := weapon != null and weapon.plus != 0
		var strong_monster := attacker.is_monster and _raw(attacker, 0x73) >= 4
		if not magic_weapon and not strong_monster:
			return 0
	if target.has_affect(0x73) and weapon != null and types != null:
		var kind := types.field(weapon.type, 7)
		if kind == 0 or (kind & 1) != 0:
			dmg /= 2
	return dmg


## Spell damage of an element (1 fire, 2 cold) after the target's standing effects.
static func element_damage(target: PartyMember, element: int, dmg: int) -> int:
	if element == 1 and target.has_affect(0x70):
		return 0
	if element == 2 and target.has_affect(0x6E):
		return 0
	if element == 2 and target.has_affect(0x76):
		return dmg / 2
	return dmg

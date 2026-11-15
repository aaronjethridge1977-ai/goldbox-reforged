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
##   0x03          (a readied Two-Handed Sword +1 +3 vs Undead) +2 to hit and damage
##                 against undead (record 0x9F = 4)
##   0x45          (drider) a hit paralyses for 1d9+10 rounds unless the target saves
##   0x55 / 0x56   a hit drains 1 / 2 levels ("IS DRAINED A LEVEL" / " 2 LEVELS")
##   0x4F          a hit burns for 2d10 more (fire): Tyranthraxus
##   0x51          (Tyranthraxus) at the start of a fight every enemy saves vs spells (kind
##                 4): of levels 0-3 "IS PARALYZED WITH FEAR" (held for good), 4-5 "IS
##                 WEAKENED BY FEAR" (Curse); "IS UNAFFECTED" on a save (handler 0x10705)
##   0x52          (mummy) at the start of a fight, once: every enemy saves vs paralysis
##                 (+2 humans, +1 if its side has six or more) or is held 1d4 rounds
##                 "IS PARALYZED WITH FEAR" (0x10803)
##   0x53 + 0x7F   (basilisk, medusa) at the start of each of its turns it "GAZES..." at the
##                 figure it last aimed at; a readied Mirror sends it back ("REFLECTS IT!");
##                 a failed save vs petrification (kind 1): "IS STONED" (status 7) (0x10908)
##   0x54          (vampire) each turn, a gaze at its target in sight: Charm unless it saves
##                 vs spells at -2 (0x10AD2)
##   0x7E          (vampire) never attacks anyone with a readied Mirror or Wooden Holy
##                 Symbol (0x11A92)
##   0x57          (mummy) a hit gives disease, no save, "IS DISEASED" (0x11047): 0x32 for
##                 10 days (no healing but 1 HP each 10 days) and 0x39 for 30 days with
##                 1d6 months in its high nibble ("ROTS...": CHA -2, never below 3; at the
##                 last month "DIES ROTS AWAY", status 8). Cure Disease removes both.
##   0x62          regenerates 3 HP at the start of every round (vampires; trolls gain it)
##   0x65          (troll) on its first damage, after 3 rounds it gains 0x62 (via 0x3B)
##   0x64          (troll) going down to anything but fire or acid: after 3d6 rounds it
##                 "STANDS UP AND GRINS" at full HP if its square is free (0x66, 0x2C753)
##   0x67          (vampire) going down: "TURNS GASEOUS AND ESCAPES" (status 3, fled)
##   0x63          (wild boar) going down dying or unconscious: back up with 6 - rounds
##                 bled HP, then "FALLS DEAD" 1d4+1 rounds later (0x1138B, 0x5F)
##   0x59          (Tyranthraxus) once a fight, the first attack roll against it misses
##   0x48          (6th level thief) 95% to be invisible for the round, at the start of the
##                 fight and of each round
##   0x50 / 0x79   (ankheg) a bite burns 1d4 more (acid); at the start of a turn, 25% and a
##                 target within 3: "SPITS ACID" 8d4, half on a save vs breath (kind 3),
##                 once (both powers are then gone)
## Weapon hits (category 5, in this order): 0x78 (giants) 50% to avoid a Boulder thrown
## from range ("AVOIDS IT"); 0x73; 0x74 (mummy) magic weapons half; 0x77; 0x7B (wraith)
## magic full, silver half, others nothing; 0x60 (wight) only magic or silver weapons;
## 0x5E (juju zombie) arrows and quarrels half; 0x7A (mummy) a flask of oil does 3d8;
## 0x75 (undead) holy water does 1d6+1. Damage types (GAME.OVR's 0x6819 bits): 1 fire,
## 2 cold, 4 electricity, 8 magic, 0x10 acid; 0x72 halves electricity, 0x5D fire, 0x5B
## (juju zombie) ignores electricity and Magic Missile.
##   0x58          (Tyranthraxus) at the start of its turn, 50%: "BREATHES!" a line of
##                 lightning toward its target, damage = its HP (record 0x32), half on a save
##                 vs breath; its power byte counts the breaths (0xFF: three) (0x2A0F1)
## Damage messages (GAME.OVR 0x2C27B): "TAKES n POINTS OF DAMAGE" or "TAKES 1 POINT OF
## DAMAGE", then by type FROM FIRE / COLD / ELECTRICITY / ACID, or FROM MAGIC when the
## damage is only magic.
##   0x49          (tiger) both claws hit: "RAKES..." and two more attacks of 2d4
##   0x4D          (giant mantis) a hit on anyone with STR under 19: "IS HELD FAST"; each of
##                 its turns it attacks the one it holds (3d4) until they fall
##   0x4C          (stirge) a hit latches it on: at the start of each of its turns it "SUCKS
##                 SOME BLOOD" for 1d4 instead of attacking, until it has had ~12 or a side falls
##   0x68          (thri-kreen) avoids 60% of missiles ("AVOIDS IT")
##   0x71          (efreeti) fire: one less a die
##   0x69, 0x6A    magic resistance (magic_resists; Combat Chat 4: the byte wraps, so 0x6A
##                 resists every Pool spell).
## Categories (when each type runs) are the lists of the dispatcher at GAME.OVR 0x2B1E4.

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

# Damage types, as GAME.OVR's 0x6819 bits.
const FIRE := 1
const COLD := 2
const ELECTRIC := 4
const MAGIC := 8
const ACID := 0x10

const STONED := 7
const GONE := 8
const DISEASE := 0x32       # no healing; 1 HP every 10 days
const ROT := 0x39           # months left in the high nibble of its power
const DISEASE_MINUTES := 14400
const ROT_MINUTES := 43200
const CURES_DISEASE := [0x32, 0x39, 0x1F, 0x2B, 0x2C]

# Item name words (START.EXE's word table) and item types the powers look for.
const WORD_MIRROR := 0x76
const WORD_HOLY_SYMBOL := 0x98
const WORD_WOODEN := 0xFC
const WORD_SILVER := 0xB1
const TYPE_HOLY_WATER := 0x55
const TYPE_OIL := 0x56
const TYPE_BOULDER := 0x57


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
## `roll_d100` gives the elves' and half-elves' chance roll. The original's add-effect routine
## (GAME.OVR 0x2C540) runs category 9 for every effect it adds, saved or not, so an elf or
## half-elf draws its d100 whatever the effect (handlers 0x115ED, 0x11A3F), and only Sleep or
## Charm is thrown off by it (lab, Combat Chat 2: Bakshi, a half-elf, drew one after a
## wand's paralysis in 7:23).
static func blocks(m: PartyMember, type: int, roll_d100: Callable, spell_level: int = 0) -> bool:
	if magic_resists(m, spell_level, roll_d100):
		return true
	var mind := type == SLEEP or type == CHARM
	if mind and (m.has_affect(0x6C) or m.has_affect(0x7D)):
		return true
	if m.has_affect(0x6B) and int(roll_d100.call()) <= 90 and mind:
		return true
	if m.has_affect(0x7C) and int(roll_d100.call()) <= 30 and mind:
		return true
	if type == PARALYZED and (m.has_affect(0x6D) or m.has_affect(0x6F) or m.has_affect(0x7D)):
		return true
	if type == POISONED and (m.has_affect(0x6F) or m.has_affect(0x7D)):
		return true
	return false


## Magic resistance (Combat Chat 4; GAME.OVR 0x11570, types 0x69 at 50 and 0x6A at 15, first in
## the add-effect list, category 9, and among the damage ones, category 6): the chance is
## base - 5 x (11 - the spell's level), worked out in a byte, so it wraps; a d100 at or under it
## resists (0xEC5B clears the effect being added, DS:0x6817). So 0x6A (Tyranthraxus) resists
## every spell of levels 1-7 and every effect with no spell behind it (level 0: 216), each time
## with a draw; 0x69 resists level 1 never (but draws), level 2 5%, level 3 10%.
static func magic_resists(m: PartyMember, spell_level: int, roll_d100: Callable) -> bool:
	for pair in [[0x69, 50], [0x6A, 15]]:
		if m.has_affect(pair[0]):
			var chance: int = (int(pair[1]) - 5 * (11 - spell_level)) & 0xFF
			if int(roll_d100.call()) <= chance:
				return true
	return false


## To-hit adjustment for `attacker` against `target` from either side's standing effects.
static func hit_bonus(attacker: PartyMember, target: PartyMember) -> int:
	var b := 0
	if attacker.has_affect(0x03) and _raw(target, 0x9F) == 4:
		b += 2      # a weapon +3 against undead (handler 0x03: also +2 damage)
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


## Weapon damage after the target's standing effects, in the original's order (category
## 5). `weapon` is the attacker's readied weapon or null; `types` the ITEMS table; `ranged`
## for a missile from more than a square away; `roll(count, size)` rolls dice; messages
## ("AVOIDS IT") are added to `notes`.
static func weapon_damage(attacker: PartyMember, target: PartyMember, weapon: GameItem,
		types: ItemTypes, dmg: int, roll: Callable = Callable(), ranged: bool = false,
		notes: Array = []) -> int:
	var wtype := weapon.type if weapon != null else -1
	if attacker.has_affect(0x03) and _raw(target, 0x9F) == 4:
		dmg += 2
	if target.has_affect(0x78) and ranged and wtype == TYPE_BOULDER and roll.is_valid() \
			and int(roll.call(1, 100)) <= 50:
		notes.append("%s AVOIDS IT" % target.name)
		return 0
	# 0x29 Protection from Normal Missiles: a missile without a plus; 0x68 (thri-kreen) 60%
	# of missiles (GAME.OVR 0xFCE1, 0x1155C, both through 0xFC07: "AVOIDS IT").
	if ranged and weapon != null and roll.is_valid():
		var avoid := 0
		if target.has_affect(0x68):
			avoid = 60
		if target.has_affect(0x29) and weapon.plus == 0:
			avoid = 100
		if avoid > 0 and int(roll.call(1, 100)) <= avoid:
			notes.append("%s AVOIDS IT" % target.name)
			return 0
	if target.has_affect(0x73) and weapon != null and types != null:
		var kind := types.field(weapon.type, 7)
		if kind == 0 or (kind & 1) != 0:
			dmg /= 2
	if target.has_affect(0x74) and weapon != null and weapon.plus > 0:
		dmg /= 2
	if target.has_affect(0x77):
		var magic_weapon := weapon != null and weapon.plus != 0
		var strong_monster := attacker.is_monster and _raw(attacker, 0x73) >= 4
		if not magic_weapon and not strong_monster:
			dmg = 0
	if target.has_affect(0x7B):
		if weapon == null:
			dmg = 0
		elif weapon.plus == 0:
			dmg = dmg / 2 if has_word(weapon, WORD_SILVER) else 0
	if target.has_affect(0x60):
		if weapon == null or (weapon.plus == 0 and not has_word(weapon, WORD_SILVER)):
			dmg = 0
	if target.has_affect(0x5E) and weapon != null and types != null and (types.flags(wtype) & 0x81) != 0:
		dmg /= 2
	if target.has_affect(0x7A) and wtype == TYPE_OIL and roll.is_valid():
		dmg = int(roll.call(3, 8))
	if target.has_affect(0x75) and wtype == TYPE_HOLY_WATER and roll.is_valid():
		dmg = int(roll.call(1, 6)) + 1
	return dmg


## "<NAME> TAKES n POINTS OF DAMAGE FROM FIRE" as the original words it.
static func damage_words(name: String, dmg: int, kind: int) -> String:
	var t := "%s TAKES 1 POINT OF DAMAGE" % name if dmg == 1 else "%s TAKES %d POINTS OF DAMAGE" % [name, dmg]
	match kind & ~MAGIC:
		FIRE:
			return t + " FROM FIRE"
		COLD:
			return t + " FROM COLD"
		ELECTRIC:
			return t + " FROM ELECTRICITY"
		ACID:
			return t + " FROM ACID"
	return t + " FROM MAGIC" if kind == MAGIC else t


## Does this item's name use word `word` (record bytes 47..49)?
static func has_word(it: GameItem, word: int) -> bool:
	for o in [0x2F, 0x30, 0x31]:
		if it.raw.size() > o and it.raw[o] == word:
			return true
	return false


## A readied item with this name word, or null.
static func readied_with(m: PartyMember, word: int) -> GameItem:
	for it in m.items:
		if it.readied and has_word(it, word):
			return it
	return null


## Does `attacker` (a vampire, 0x7E) shy away from `target`: a readied Mirror, or a readied
## Wooden Holy Symbol?
static func repels(attacker: PartyMember, target: PartyMember) -> bool:
	if not attacker.has_affect(0x7E):
		return false
	for it in target.items:
		if not it.readied:
			continue
		if has_word(it, WORD_MIRROR):
			return true
		if has_word(it, WORD_HOLY_SYMBOL) and it.raw.size() > 0x31 and it.raw[0x31] == WORD_WOODEN:
			return true
	return false


## The level the powers compare against: record 0x73 (a monster's hit dice; for characters
## the original keeps it at the highest class level).
static func level_of(m: PartyMember) -> int:
	var lvl := _raw(m, 0x73)
	if not m.is_monster:
		for c in 8:
			lvl = maxi(lvl, m.level_in(c))
	return lvl


# --- Disease (mummy rot) ---------------------------------------------------------------------

static func diseased(m: PartyMember) -> bool:
	return m.has_affect(DISEASE)


## A mummy's touch (0x57): nothing if already diseased; `months` is the 1d6 roll.
static func infect(m: PartyMember, months: int) -> bool:
	if m.has_affect(DISEASE):
		return false
	m.affects.append({"effect": DISEASE, "spell": 0, "minutes": DISEASE_MINUTES, "value": 0xFF})
	m.affects.append({"effect": ROT, "spell": 0, "minutes": ROT_MINUTES, "value": (months << 4) + 15})
	return true


## Cure Disease (spell or temple): removes the diseases; true if there was one.
static func cure_disease(m: PartyMember) -> bool:
	var keep: Array = []
	var had := false
	for a in m.affects:
		if int(a.effect) in CURES_DISEASE:
			had = had or int(a.effect) == DISEASE or int(a.effect) == ROT
		else:
			keep.append(a)
	m.affects = keep
	return had


## What happens when a disease's time runs out (GAME.OVR 0xFF56 / 0xFFF4); returns the
## lines to show, and whether the effect carries on (it is then given new time).
static func disease_expires(m: PartyMember, a: Dictionary, out: PackedStringArray) -> bool:
	match int(a.effect):
		DISEASE:
			a.minutes = int(a.minutes) + DISEASE_MINUTES
			if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
					and m.hp < m.hp_max:
				m.hp += 1
				if m.status == PartyMember.STATUS_DYING:
					m.status = PartyMember.STATUS_UNCONSCIOUS
			return true
		ROT:
			out.append("%s ROTS..." % m.name)
			if m.stats.size() > 5:
				m.stats[5] = maxi(m.stats[5] - 2, 3)
				if m.raw.size() > 0x15:
					m.raw[0x15] = m.stats[5]
			if (int(a.value) >> 4) > 1:
				a.value = int(a.value) - 0x10
				a.minutes = int(a.minutes) + ROT_MINUTES
				return true
			if not m.status in [PartyMember.STATUS_DEAD, STONED, GONE]:
				out.append("%s DIES ROTS AWAY" % m.name)
				m.status = GONE
				m.hp = 0
			return false
	return false


## Spell damage of an element (FIRE, COLD, ELECTRIC...) after the target's standing effects.
static func element_damage(target: PartyMember, element: int, dmg: int) -> int:
	if (element & FIRE) and target.has_affect(0x70):
		return 0
	if (element & COLD) and target.has_affect(0x6E):
		return 0
	if (element & ELECTRIC) and target.has_affect(0x5B):
		return 0
	if (element & COLD) and target.has_affect(0x76):
		dmg /= 2
	if (element & ELECTRIC) and target.has_affect(0x72):
		dmg /= 2
	if (element & FIRE) and target.has_affect(0x5D):
		dmg /= 2
	return dmg


## Fire after an efreeti's 0x71: one less a die, never below one a die (GAME.OVR 0x11683).
static func efreeti_fire(target: PartyMember, element: int, dmg: int, dice: int) -> int:
	if (element & FIRE) and target.has_affect(0x71):
		for k in dice:
			dmg = maxi(dmg - 1, dice)
	return dmg

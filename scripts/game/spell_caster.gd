class_name SpellCaster
extends RefCounted
## What a spell does when it is cast. Out of combat (CAST from the camp's MAGIC menu or the
## adventure menu) only spells aimed at the caster or the party can be cast; one meant
## for combat asks "<SPELL> CAN'T BE CAST HERE... LOSE IT?".
##
## As the original does it (rules as documented by Pilgrim's reconstruction; spell data
## from Pool of Radiance's own table, see SpellTable):
## - The caster says "<NAME> CASTS <SPELL>"; the spell leaves its memory.
## - A spell for one party member asks "CAST SPELL ON WHOM"; one for the party covers
##   everyone; one for the caster covers the caster.
## - A spell with a lasting effect puts it on each target for its duration (fixed + per
##   caster level, in rounds of a minute) with the spell's own words ("IS BLESSED",
##   "IS PROTECTED"...). The camp's DISPLAY lists those effects by spell name.
## - Cure Light Wounds heals 1d8 ("IS FULLY HEALED" / "IS PARTIALLY HEALED"), waking the
##   unconscious and stopping the dying from bleeding.
## - Enlarge, Strength and Giant Strength raise STR (Strength); Potion of Healing heals 2d4+2
##   ("IS HEALED", 0x29FE8); Potion of Speed hastes unless slowed ("IS SPEEDY"); Dust of
##   Disappearance makes the party invisible; the Manual of Bodily Health: "IS READING"
##   for a day, then "STARTS TO TRAIN" for 30 days, then CON + 1 ("IS HARDIER", 0xEDDA,
##   0xEE8E; the hit point recount for CON 15+ is not built).
## Not yet: Knock and Find Traps outside doors. Remove Curse: chat 81. Dispel Magic outside fights: chat 81 (0x293A0).

const CURE_LIGHT := 3
const CURE_BLINDNESS := 37
const CURE_DISEASE := 39
const REMOVE_CURSE := 43
const KNOCK := 31
const SLOW_POISON := 26
const POISONED := 0x37        # a failed save against poison: dead, until slowed or neutralized
const SLOWED_POISON := 0x16   # Slow Poison's effect (table effect 22)
const POISON_TICK := 0x0F     # while slowed: 1 HP every 10 minutes, never below 1

## Words for each spell that leaves an effect on its target.
const WORDS := {1: "IS BLESSED", 2: "IS CURSED", 5: "IS AFFECTED", 6: "IS PROTECTED",
	7: "IS PROTECTED", 8: "IS COLD-RESISTANT", 10: "IS CHARMED", 11: "IS AFFECTED",
	12: "IS STRONGER", 14: "IS FRIENDLY", 16: "IS PROTECTED", 17: "IS PROTECTED",
	18: "IS AFFECTED", 19: "IS SHIELDED", 21: "FALLS ASLEEP", 22: "IS AFFECTED",
	23: "IS HELD", 24: "IS FIRE RESISTANT", 25: "IS SILENCED", 26: "IS AFFECTED",
	29: "IS AFFECTED", 30: "IS INVISIBLE", 31: "KNOCK-KNOCK", 32: "IS DUPLICATED",
	33: "IS WEAKENED", 35: "IS STRONGER", 38: "IS BLIND", 40: "IS DISEASED",
	42: "IS PRAYING", 44: "IS CURSED", 48: "IS HASTED", 49: "IS HELD", 50: "IS INVISIBLE",
	52: "IS PROTECTED", 53: "IS PROTECTED", 54: "IS PROTECTED", 55: "IS SLOWED",
	61: "IS PARALYZED", 63: "IS INVISIBLE"}


## Does this spell need a party member chosen as its target (out of combat)?
static func needs_member(table: SpellTable, id: int) -> bool:
	return table.target(id) == SpellTable.TARGET_MEMBER


## Can it be cast outside a fight at all?
static func castable_outside(table: SpellTable, id: int) -> bool:
	return table.target(id) != SpellTable.TARGET_COMBAT


## Casts `id` outside combat. `target` is the chosen member for one-member spells.
## Returns the lines to show.
static func cast_outside(table: SpellTable, caster: PartyMember, id: int, party: Array,
		target: PartyMember, rng: RandomNumberGenerator, from_item: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	if from_item:
		out.append("%s USES AN ITEM" % caster.name)
	else:
		caster.forget(id)
		out.append("%s CASTS %s" % [caster.name, table.name_of(id)])
	var targets: Array = []
	match table.target(id):
		SpellTable.TARGET_SELF:
			targets = [caster]
		SpellTable.TARGET_MEMBER:
			targets = [target if target != null else caster]
		SpellTable.TARGET_PARTY:
			targets = party.duplicate()
	# A spell from an item (a scroll) is cast at level 6, whatever the reader's level (chat 79,
	# check 179, DOSBox: LIRA at magic-user 1 and at 8 both gave PROTECTION FROM GOOD 12
	# minutes, power 6; chat 80, check 185: a clerical scroll too). The item spells (class 2) keep
	# their fixed 12 (START.EXE 0xba:0x26c2 gives 6 for an item in use only below class 2; check 186).
	var lvl := caster.caster_level(table, id)
	if from_item and table.spell_class(id) != SpellTable.MONSTER:
		lvl = 6
	match id:
		CURE_LIGHT:
			var t: PartyMember = targets[0]
			if _heal(t, _roll(rng, 1, 8)):     # GAME.OVR 0x28083: one d8
				out.append("%s %s" % [t.name, "IS FULLY HEALED" if t.hp >= t.hp_max else "IS PARTIALLY HEALED"])
			return out
		CURE_DISEASE:
			# GAME.OVR 0x29347 -> 0x292A2 (chat 75, DOSBox: effect 0x22 alone is lifted too,
			# "IS CURED"; the mummy's disease and rot: one "IS CURED"; nothing on the healthy).
			for t in targets:
				_cure_292a2(t, out)
			return out
		CURE_BLINDNESS:
			# The first blindness effect (0x21) only, as the temple's (main chat 82, check 217: of two, the
			# second stays).
			for t in targets:
				for a in t.affects:
					if int(a.effect) == 0x21:
						t.affects.erase(a)
						ended(t, a, PackedStringArray())
						break
			return out
		REMOVE_CURSE:
			# GAME.OVR 0x29558 (as the temple's, temple_screen.gd): effect 0x24 (Bestow Curse) goes if
			# there is one ("IS UN-CURSED"), else the first carried item with its curse byte (54) set
			# loses it ("'S ITEM IS UN-CURSED"). Chat 81, check 211 (DOSBox: CEDRIC at cleric 5 on ARN's
			# cursed Long Sword: byte 54 cleared, the sword still readied).
			for t in targets:
				var m: PartyMember = t
				var gone := false
				for b in m.affects:
					if int(b.effect) == 0x24:
						m.affects.erase(b)
						gone = true
						break
				if gone:
					out.append("%s IS UN-CURSED" % m.name)
					continue
				for it in m.items:
					if it.cursed:
						it.cursed = false
						out.append("%s'S ITEM IS UN-CURSED" % m.name)
						break
			return out
		SLOW_POISON:
			# GAME.OVR 0x28873 (lab, chat 23: save J's Thrender poisoned, Brother Sean casts in
			# camp: "IS AFFECTED", "GETS BACK UP", HP 1, OKAY; resting, about an hour later
			# "DIES FROM POISON"): only on the poisoned; HP 0 becomes 1, the effect for its
			# duration (60 minutes a level), the member back up, and the 10-minute tick.
			var t: PartyMember = targets[0]
			if t.status == PartyMember.STATUS_ANIMATED or not t.has_affect(POISONED):
				return out
			if t.hp <= 0:
				t.hp = 1
			add_affect(t, SLOWED_POISON, id, table.duration_for(id, lvl), lvl)
			out.append("%s IS AFFECTED" % t.name)
			if t.status != PartyMember.STATUS_OKAY:
				t.status = PartyMember.STATUS_OKAY
				out.append("%s GETS BACK UP" % t.name)
			add_affect(t, POISON_TICK, id, 10, 0xFF)
			return out
		12, 35, 59:         # Enlarge, Strength, Giant Strength
			var t: PartyMember = targets[0]
			var v := Strength.enlarge_target(lvl) if id == 12 else Vector2i(21, 0)
			if id == 35:
				v = Strength.spell_target(t, func(n, d): return _roll(rng, n, d))
			var minutes := special_duration(table, id, lvl, rng, false)
			if Strength.add(t, table.effect(id), id, v.x, v.y, minutes):
				out.append("%s IS STRONGER" % t.name)
			return out
		58:                 # Neutralize Poison (an item's power): GAME.OVR 0x29E65
			# The poison and Slow Poison's effects go, "IS CURED" (0x2BF6B: a found effect is
			# named cured and removed); a member dead of it stays dead. Chat 27: not poisoned,
			# the other cures (0x292A2): effect 0x22; 0x2B (with 0x2C and 0x1F); 0x32, the
			# mummy's disease (with 0x39, the rot), each "IS CURED"; none of them: 1d4 + 8 HP
			# (0x2BCCD, the heal 0x2C647), "IS HEALED" when it heals.
			var t: PartyMember = targets[0]
			if t.has_affect(POISONED):
				for b in t.affects.duplicate():
					if int(b.effect) in [POISONED, SLOWED_POISON, POISON_TICK]:
						t.affects.erase(b)
				out.append("%s IS CURED" % t.name)
				return out
			if not _cure_292a2(t, out) and _heal(t, _roll(rng, 1, 4) + 8):
				out.append("%s IS HEALED" % t.name)
			return out
		57:                 # Potion of Speed: haste, unless slowed
			var t: PartyMember = targets[0]
			if not t.has_affect(42):
				add_affect(t, 39, id, special_duration(table, id, lvl, rng, false), lvl)
				out.append("%s IS SPEEDY" % t.name)
			return out
		41, 46:             # Dispel Magic: GAME.OVR 0x293A0
			# Each of the target's effects with a power below 255 (not the racial ones) goes on a
			# d100 at most 50, plus 5 a level the caster is above the power's low four bits, or
			# minus 2 a level below; an effect that goes runs its end. Chat 81, checks 202, 203
			# (DOSBox: ARN's Protection from Evil, power 6 against cleric 5 (48%) stays; power 1
			# against cleric 6 (75%) goes, the d100 71).
			for t in targets:
				var m: PartyMember = t
				var gone := false
				for a in m.affects.duplicate():
					var p := int(a.value)
					if p >= 0xFF:
						continue
					p &= 0x0F
					var chance := 50
					if lvl > p:
						chance = 50 + 5 * (lvl - p)
					elif lvl < p:
						chance = 50 - 2 * (p - lvl)
					if _roll(rng, 1, 100) <= (chance & 0xFF):
						m.affects.erase(a)
						ended(m, a, out)
						gone = true
				if gone:
					out.append("%s IS AFFECTED" % m.name)
			return out
		48:                 # Haste (the magic-user's)
			# Chat 81, checks 204, 205 (DOSBox: LIRA at magic-user 5 hastes the first five in
			# party order, DORN not; at 3 the first three, herself not): effect 39 for 3 + level
			# minutes, and the effect's handler (GAME.OVR 0xF8A5) runs at once: a power without
			# bit 0x10 gets it ("AGES") and the member's age (record word 0x30) goes up a year,
			# once per effect (power 5 -> 21). A slowed member's Slow ends instead (as combat's).
			for t in targets.slice(0, maxi(lvl, 0)):
				var m: PartyMember = t
				if m.status == PartyMember.STATUS_DEAD:
					continue
				if m.has_affect(42):
					remove_effect(m, 42)
					continue
				if SpecialAffects.blocks(m, table.effect(id), func(): return _roll(rng, 1, 100), table.level(id)):
					out.append("%s IS UNAFFECTED" % m.name)
					continue
				add_affect(m, table.effect(id), id, special_duration(table, id, lvl, rng, false), lvl)
				out.append("%s %s" % [m.name, WORDS[id]])
				# The handler gets the member's first record of the type: one already aged (bit
				# 0x10) ages nobody and the new record keeps its plain power (chat 84, check 236,
				# DOSBox: ARN hasted [39, 8, 21], a second HASTE of 8 minutes: [39, 8, 21] and
				# [39, 8, 5], his age unchanged; check 235: a shorter old one goes, he ages).
				for a in m.affects:
					if int(a.effect) == table.effect(id):
						if int(a.value) & 0x10 == 0:
							a.value = int(a.value) + 0x10
							_age_up(m)
							out.append("%s AGES" % m.name)
						break
			return out
		36:                 # Animate Dead: GAME.OVR 0x29087
			# Up to the caster's level of the dead (status 6, record +0x9F 0), in party order, rise: each joins the
			# caster's side (+0x10E, +0x10F 1), +0x76 2, +0x6B 0, base movement (+0x72) 6, no spells in memory,
			# morale (+0x84) 0xB2 (over 0x7F) or 0xB3, +0x9F 4; stood up at full HP (0x2C753: +0x10D 1); then the
			# effect 0x20 for no time at power (old +0x10E << 4) + level through the common add (0x2C540, "IS
			# ANIMATED") and status 1, ANIMATED. Nobody else is touched (chat 83, check 231, DOSBox: CEDRIC at
			# cleric 5 with ARN dead: ARN ANIMATED, HP 14 of 14, [0x20, 0, 5]; ours had put 0x20 on the living).
			var n := lvl
			for t in party:
				var m: PartyMember = t
				if n <= 0:
					break
				if m.status != PartyMember.STATUS_DEAD or (m.raw.size() > 0x9F and m.raw[0x9F] != 0):
					continue
				n -= 1
				var power := lvl
				if m.raw.size() > 0x10F:
					power = ((m.raw[0x10E] << 4) + lvl) & 0xFF
					m.raw[0x10E] = caster.raw[0x10E] if caster.raw.size() > 0x10E else 0
					m.raw[0x10F] = 1
					m.raw[0x76] = 2
					m.raw[0x6B] = 0
					m.raw[0x72] = 6
					m.raw[0x84] = 0xB2 if m.raw[0x84] > 0x7F else 0xB3
					m.raw[0x9F] = 4
					m.raw[0x10D] = 1
					m.base_movement = 6
					m.morale = m.raw[0x84]
				m.memorized.clear()
				m.hp = m.hp_max
				m.status = PartyMember.STATUS_OKAY
				if SpecialAffects.blocks(m, 0x20, func(): return _roll(rng, 1, 100), table.level(id)):
					out.append("%s IS UNAFFECTED" % m.name)
				else:
					add_affect(m, 0x20, id, 0, power)
					out.append("%s IS ANIMATED" % m.name)
				m.status = PartyMember.STATUS_ANIMATED
			return out
		13:                 # Reduce: GAME.OVR 0x28387
			# The target saves against spells (0x2BC4D: a d20, kind 4, no bonus; a natural 1 fails, 20 saves).
			# Failing, an Enlarge on it is lifted through 0x2BF6B ("<NAME> IS CURED", its first record removed,
			# the end handler giving the strength back) and "<NAME> HAS BEEN REDUCED". Reduce adds no effect of
			# its own (chat 83, checks 225, 226, DOSBox: LIRA's REDUCE on the enlarged CEDRIC leaves him no
			# record; on ARN, not enlarged, nothing).
			var t: PartyMember = targets[0]
			if t.status == PartyMember.STATUS_DEAD:
				return out
			var d := _roll(rng, 1, 20)
			var need: int = t.saves[4] if t.saves.size() > 4 else 20
			if d != 1 and (d == 20 or d + SpecialAffects.save_bonus(t, 4) >= need):
				return out
			for a in t.affects:
				if int(a.effect) == Strength.ENLARGE:
					t.affects.erase(a)
					ended(t, a, PackedStringArray())
					out.append("%s IS CURED" % t.name)
					out.append("%s HAS BEEN REDUCED" % t.name)
					break
			return out
		14:                 # Friends: GAME.OVR 0x283F1
			# The caster's charisma (record 0x15) goes up 2d4, at most 25, before the effect is
			# added through the common cast (0x278DB); the effect's power holds the old charisma,
			# which comes back when it ends (0xF231). Chat 81, check 199 (DOSBox: LIRA 18 -> 24,
			# [14, 3 minutes, 18]).
			var t: PartyMember = targets[0]
			if t.stats.size() <= 5 or t.status == PartyMember.STATUS_DEAD:
				return out
			var old: int = t.stats[5]
			_set_charisma(t, mini(old + _roll(rng, 2, 4), 25))
			if SpecialAffects.blocks(t, table.effect(id), func(): return _roll(rng, 1, 100), table.level(id)):
				out.append("%s IS UNAFFECTED" % t.name)
				return out
			add_affect(t, table.effect(id), id, special_duration(table, id, lvl, rng, false), old)
			out.append("%s %s" % [t.name, WORDS[id]])
			return out
		62:                 # Potion of Healing
			var t: PartyMember = targets[0]
			if _heal(t, _roll(rng, 2, 4) + 2):
				out.append("%s IS HEALED" % t.name)
			return out
		67:                 # Manual of Bodily Health
			var t: PartyMember = targets[0]
			add_affect(t, MANUAL_READING, id, 1440, 0xFF)
			out.append("%s IS READING" % t.name)
			return out
	var effect := table.effect(id)
	if effect == 0 and not WORDS.has(id):
		return out
	for t in targets:
		var m: PartyMember = t
		if m.status == PartyMember.STATUS_DEAD:
			continue
		if effect > 0:
			# The original adds it through its add-effect routine (GAME.OVR 0x2C540) here too, which runs
			# the target's race and resistance handlers for any effect: an elf (0x115ED) and a half-elf
			# (0x11A3F) each draw a d100 even for a camp's Bless (chat 65, DOSBox: CEDRIC's Bless, d100s
			# for ELWEN and LIRA, then the cure's d8; check 102).
			var minutes := special_duration(table, id, lvl, rng, false)
			if SpecialAffects.blocks(m, effect, func(): return _roll(rng, 1, 100), table.level(id)):
				out.append("%s IS UNAFFECTED" % m.name)
				continue
			add_affect(m, effect, id, minutes, lvl)
			if effect == SPIRITUAL_HAMMER:
				_hammer_on(m)
		if WORDS.has(id):
			out.append("%s %s" % [m.name, WORDS[id]])
	return out


const MANUAL_READING := 4
const MANUAL_TRAINING := 7
const FRIENDS := 14


const SPIRITUAL_HAMMER := 23


static func _is_hammer(it: GameItem) -> bool:
	return it.raw.size() >= GameItem.SIZE and it.type == 0x14 and it.raw[49] == 0xF3


## Spiritual Hammer's effect handler (GAME.OVR 0xF420) runs as the effect is added: unless the
## member already has the spell's hammer (type 0x14, name word 49 = 0xF3) or carries 16 items, a
## new record goes on the end of the list: type 0x14, name words 0x14 0xF3, +1, bytes 61-62
## 0x17 0x89, nothing else (no name, weight or price), not readied. Chat 81, check 209 (DOSBox:
## CEDRIC, cleric 3, in camp: [23, 3 minutes, power 3] and the hammer, his mace still readied).
static func _hammer_on(m: PartyMember) -> void:
	if m.items.size() >= 16:
		return
	for it in m.items:
		if _is_hammer(it):
			return
	var rec := PackedByteArray()
	rec.resize(GameItem.SIZE)
	rec[46] = 0x14
	rec[48] = 0x14
	rec[49] = 0xF3
	rec[50] = 1
	rec[61] = 0x17
	rec[62] = 0x89
	m.items.append(GameItem.from_record(rec))


static func _age_up(m: PartyMember) -> void:
	if m.raw.size() > 0x31:
		var w := (m.raw[0x30] | m.raw[0x31] << 8) + 1
		m.raw[0x30] = w & 0xFF
		m.raw[0x31] = (w >> 8) & 0xFF
		m.age = w
	else:
		m.age += 1


static func _set_charisma(m: PartyMember, v: int) -> void:
	m.stats[5] = v
	if m.raw.size() > 0x15:
		m.raw[0x15] = v


## Dice of a spell cast outside a fight: from the original's dice when a replay runs on them (tpseed), so a
## segment's draws stay in step past a camp's cure (Combat Chat 18: Player 15's p15c7, the d8 at 0x280A2).
static func _roll(rng: RandomNumberGenerator, n: int, d: int) -> int:
	var t := 0
	for i in n:
		t += TpDice.between(1, d, "spell outside a fight") if TpDice.on else rng.randi_range(1, d)
	return t


## A spell's duration in minutes: the original's own for some item spells, otherwise the
## table's (fixed + per caster level).
static func special_duration(table: SpellTable, id: int, lvl: int, rng: RandomNumberGenerator,
		in_combat: bool) -> int:
	var d := SpellTable.special_duration(id, func(n, s): return _roll(rng, n, s), in_combat)
	return d if d >= 0 else table.duration_for(id, lvl)


## Removes every effect of `type` from `m`, running its end (strength comes back).
static func remove_effect(m: PartyMember, type: int) -> void:
	for a in m.affects.duplicate():
		if int(a.effect) == type:
			m.affects.erase(a)
			ended(m, a, PackedStringArray())


## What happens when effect `a` ends (it is already out of m.affects). Lines go to `out`.
static func ended(m: PartyMember, a: Dictionary, out: PackedStringArray) -> void:
	match int(a.effect):
		Strength.ENLARGE, Strength.STRENGTH:
			Strength.ended(m, a)
		SPIRITUAL_HAMMER:
			# 0xF420 with its end flag: the hammer the effect made goes.
			for it in m.items:
				if _is_hammer(it):
					m.items.erase(it)
					break
		FRIENDS:
			# 0xF231: the charisma the effect held comes back.
			if m.stats.size() > 5 and int(a.value) < 0xFF:
				_set_charisma(m, int(a.value))
		MANUAL_READING:
			out.append("%s STARTS TO TRAIN" % m.name)
			m.affects.append({"effect": MANUAL_TRAINING, "spell": 67, "minutes": 43200, "value": 0xFF})
		SLOWED_POISON:
			# 0xF3D0: still poisoned when it ends, the member dies; the tick stops.
			if m.has_affect(POISONED):
				m.hp = 0
				m.status = PartyMember.STATUS_DEAD
				out.append("%s DIES FROM POISON" % m.name)
			for b in m.affects.duplicate():
				if int(b.effect) == POISON_TICK:
					m.affects.erase(b)
		POISON_TICK:
			# 0xF246: every 10 minutes while slowed, 1 point of damage above 1 HP.
			if m.has_affect(SLOWED_POISON):
				m.affects.append({"effect": POISON_TICK, "spell": int(a.get("spell", 0)), "minutes": 10, "value": 0xFF})
				if m.hp > 1:
					m.hp -= 1
					out.append("%s TAKES 1 POINT OF DAMAGE" % m.name)
		MANUAL_TRAINING:
			out.append("%s IS HARDIER" % m.name)
			if m.stats.size() > 4:
				m.stats[4] += 1
				if m.raw.size() > 0x14:
					m.raw[0x14] = m.stats[4]


## As the original's common add (GAME.OVR 0x2C540): the member's first record of the type (0xba:0x2199) is
## removed (0x2AF10) only when the new one lasts longer (the old one not 0) or the new one is 0; the new record
## is always appended (0x2BD3C). So an equal or shorter one is a second record (chat 83, DOSBox: CEDRIC's
## BLESS cast twice in camp leaves two [1, 6 minutes, 1] records on each member; check 218).
static func add_affect(m: PartyMember, effect: int, spell: int, minutes: int, value: int) -> void:
	for a in m.affects:
		if int(a.effect) == effect:
			if (int(a.minutes) > 0 and minutes > int(a.minutes)) or minutes == 0:
				m.affects.erase(a)
				ended(m, a, PackedStringArray())
			break
	m.affects.append({"effect": effect, "spell": spell, "minutes": minutes, "value": value})


## Lets `minutes` of game time pass for everyone's effects; those that run out end, except
## diseases, which run their course (SpecialAffects.disease_expires). Returns the lines
## to show ("ROTS...").
static func pass_time(party: Array, minutes: int) -> PackedStringArray:
	var out := PackedStringArray()
	for p in party:
		var m: PartyMember = p
		var keep: Array = []
		var ending: Array = []
		for a in m.affects:
			if int(a.minutes) == 0:
				keep.append(a)          # 0 = until removed
				continue
			a.minutes = int(a.minutes) - minutes
			var lasts := true
			while lasts and int(a.minutes) <= 0:
				if int(a.effect) in [SpecialAffects.DISEASE, SpecialAffects.ROT]:
					lasts = SpecialAffects.disease_expires(m, a, out)
				else:
					lasts = false
			if lasts:
				keep.append(a)
			else:
				ending.append(a)
		m.affects = keep
		for a in ending:
			ended(m, a, out)
	return out


## The cures of GAME.OVR 0x292A2 (Cure Disease's handler 0x29347, and Neutralize Poison's
## on the unpoisoned): each of effects 0x22, 0x2B (with 0x2C and 0x1F) and 0x32 (with 0x39,
## the rot) found is named cured (0x2BF6B: "<NAME> IS CURED") and removed with its partners;
## true if any was found.
static func _cure_292a2(t: PartyMember, out: PackedStringArray) -> bool:
	var cured := false
	for pair in [[0x22, []], [0x2B, [0x2C, 0x1F]], [0x32, [0x39]]]:
		if t.has_affect(pair[0]):
			cured = true
			out.append("%s IS CURED" % t.name)
			for b in t.affects.duplicate():
				if int(b.effect) == pair[0] or int(b.effect) in pair[1]:
					t.affects.erase(b)
	return cured


static func _heal(m: PartyMember, amount: int) -> bool:
	if not m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
		return false
	if SpecialAffects.diseased(m) and m.hp < m.hp_max:
		return false    # the original's heal (GAME.OVR 0x2C647) skips the diseased
	m.hp = mini(m.hp + amount, m.hp_max)
	if m.hp > 0:
		m.status = PartyMember.STATUS_OKAY
	return true

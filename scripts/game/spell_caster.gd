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
## Not yet: Knock and Find Traps outside doors, Remove Curse, Dispel Magic outside fights.

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
	var lvl := caster.caster_level(table, id)
	match id:
		CURE_LIGHT:
			var t: PartyMember = targets[0]
			if _heal(t, _roll(rng, 1, 8)):     # GAME.OVR 0x28083: one d8
				out.append("%s %s" % [t.name, "IS FULLY HEALED" if t.hp >= t.hp_max else "IS PARTIALLY HEALED"])
			return out
		CURE_DISEASE:
			for t in targets:
				SpecialAffects.cure_disease(t)
			return out
		CURE_BLINDNESS:
			for t in targets:
				remove_effect(t, 0x21)
			return out
		REMOVE_CURSE:
			return out      # cursed items: not built yet
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
			var cured := false
			for pair in [[0x22, []], [0x2B, [0x2C, 0x1F]], [0x32, [0x39]]]:
				if t.has_affect(pair[0]):
					cured = true
					out.append("%s IS CURED" % t.name)
					for b in t.affects.duplicate():
						if int(b.effect) == pair[0] or int(b.effect) in pair[1]:
							t.affects.erase(b)
			if not cured and _heal(t, _roll(rng, 1, 4) + 8):
				out.append("%s IS HEALED" % t.name)
			return out
		57:                 # Potion of Speed: haste, unless slowed
			var t: PartyMember = targets[0]
			if not t.has_affect(42):
				add_affect(t, 39, id, special_duration(table, id, lvl, rng, false), lvl)
				out.append("%s IS SPEEDY" % t.name)
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
			add_affect(m, effect, id, special_duration(table, id, lvl, rng, false), lvl)
		if WORDS.has(id):
			out.append("%s %s" % [m.name, WORDS[id]])
	return out


const MANUAL_READING := 4
const MANUAL_TRAINING := 7


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


static func add_affect(m: PartyMember, effect: int, spell: int, minutes: int, value: int) -> void:
	for a in m.affects:
		if int(a.effect) == effect:
			a.minutes = maxi(int(a.minutes), minutes)
			return
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


static func _heal(m: PartyMember, amount: int) -> bool:
	if not m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
		return false
	if SpecialAffects.diseased(m) and m.hp < m.hp_max:
		return false    # the original's heal (GAME.OVR 0x2C647) skips the diseased
	m.hp = mini(m.hp + amount, m.hp_max)
	if m.hp > 0:
		m.status = PartyMember.STATUS_OKAY
	return true

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
## Not yet: what the effects do in a fight (C5 continues), strength changes from Enlarge
## and Strength, Knock and Find Traps on doors and traps, Remove Curse, Dispel Magic.

const CURE_LIGHT := 3
const CURE_BLINDNESS := 37
const CURE_DISEASE := 39
const REMOVE_CURSE := 43
const KNOCK := 31

## Words for each spell that leaves an effect on its target.
const WORDS := {1: "IS BLESSED", 2: "IS CURSED", 5: "IS AFFECTED", 6: "IS PROTECTED",
	7: "IS PROTECTED", 8: "IS COLD-RESISTANT", 10: "IS CHARMED", 11: "IS AFFECTED",
	12: "IS STRONGER", 14: "IS FRIENDLY", 16: "IS PROTECTED", 17: "IS PROTECTED",
	18: "IS AFFECTED", 19: "IS SHIELDED", 21: "FALLS ASLEEP", 22: "IS AFFECTED",
	23: "IS HELD", 24: "IS FIRE RESISTANT", 25: "IS SILENCED", 26: "IS AFFECTED",
	29: "IS AFFECTED", 30: "IS INVISIBLE", 31: "KNOCK-KNOCK", 32: "IS DUPLICATED",
	33: "IS WEAKENED", 35: "IS STRONGER", 38: "IS BLIND", 40: "IS DISEASED",
	42: "IS PRAYING", 44: "IS CURSED", 48: "IS HASTED", 49: "IS HELD", 50: "IS INVISIBLE",
	52: "IS PROTECTED", 53: "IS PROTECTED", 54: "IS PROTECTED", 55: "IS SLOWED"}


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
			if _heal(t, rng.randi_range(1, 8)):
				out.append("%s %s" % [t.name, "IS FULLY HEALED" if t.hp >= t.hp_max else "IS PARTIALLY HEALED"])
			return out
		CURE_BLINDNESS, CURE_DISEASE, REMOVE_CURSE:
			return out      # nothing our characters can suffer from yet
	var effect := table.effect(id)
	if effect == 0 and not WORDS.has(id):
		return out
	for t in targets:
		var m: PartyMember = t
		if m.status == PartyMember.STATUS_DEAD:
			continue
		if effect > 0:
			add_affect(m, effect, id, table.duration_for(id, lvl), lvl)
		if WORDS.has(id):
			out.append("%s %s" % [m.name, WORDS[id]])
	return out


static func add_affect(m: PartyMember, effect: int, spell: int, minutes: int, value: int) -> void:
	for a in m.affects:
		if int(a.effect) == effect:
			a.minutes = maxi(int(a.minutes), minutes)
			return
	m.affects.append({"effect": effect, "spell": spell, "minutes": minutes, "value": value})


## Lets `minutes` of game time pass for everyone's effects; those that run out end.
static func pass_time(party: Array, minutes: int) -> void:
	for p in party:
		var m: PartyMember = p
		var keep: Array = []
		for a in m.affects:
			if int(a.minutes) == 0:
				keep.append(a)          # 0 = until removed
				continue
			a.minutes = int(a.minutes) - minutes
			if int(a.minutes) > 0:
				keep.append(a)
		m.affects = keep


static func _heal(m: PartyMember, amount: int) -> bool:
	if not m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
		return false
	m.hp = mini(m.hp + amount, m.hp_max)
	if m.hp > 0:
		m.status = PartyMember.STATUS_OKAY
	return true

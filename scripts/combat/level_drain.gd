class_name LevelDrain
extends RefCounted
## Level drain and Restoration, as GAME.OVR does them (Combat Chat 5, read from the code and
## checked in the lab with Restoration scrolls in camp).
##
## The character record keeps what a drain took, for Restoration to give back:
##   0x74  levels drained (one more per level lost)
##   0x75  hit points drained (one more per point taken off the maximum)
## Both are in the saved record (the original's saves: back to 0 once restored).
##
## Drain (0x10D7D, a hit by effects 0x55 / 0x56): "<NAME> IS DRAINED A LEVEL" (" 2 LEVELS");
## an animated character (status 1) "IS DEAD FOREVER" at once. For each level: 0x74 + 1; the
## loss is the maximum HP / the sum of all class levels, taken one point at a time off the
## maximum, rolled and current HP (none below 0), 0x75 + 1 for each point; then, if the
## highest level (0x73) is under 2, "IS DEAD FOREVER" (status 8, maximum HP 0; on a 2-level
## drain the drained class's level is zeroed); otherwise the class picked by 0x10C5D loses a
## level and, at 0 current HP, "IS KILLED" (status 6), and the level recount runs. Either
## way 0x73 becomes the picked class's level and the experience that level's minimum.
##   The pick (0x10C5D): over classes 0-7, the highest level; on equal levels, the one whose
##   level's experience total is the same or more (a later class wins a tie).
##
## Restoration (spell 56, cast handler 0x29C5B): nothing on a record with 0x74 = 0 (no
## message; the spell is spent). Otherwise HP back = 0x75 / 0x74, added to the current,
## maximum and rolled HP; 0x75 less that, 0x74 - 1. Then the class whose next level costs
## the least experience gains a level (over classes 0-7 with a level of 1 or more, the level
## not above the best so far, the next level's total above 0 and below the best so far, not
## at its race's cap: 0x3AF7), and the experience rises to that total if below it. The level
## recount, then "<NAME> IS RESTORED". Lab (camp, a lab party): a dwarf fighter 3 drained
## once (4 HP) back to fighter 4, HP 20 -> 24, experience 8001; a half-elf cleric/fighter/
## magic-user 1/1/1 back to cleric 2 (1501, the cheapest), HP + 2; an elf fighter/magic-user
## 3/2 drained twice (6 HP) to magic-user 3 (5001 < 8001), HP + 3, one level still drained.
##
## The level recount (0x2AA87): THAC0 the best of the classes', 0x73 raised to the highest
## level, a fighter above level 6 attacks 3 times in 2 rounds (everyone else: 2), the cleric's
## spells per day (with wisdom) and spell book only above level 1, the magic-user's spells
## per day only above level 1, the saving throws.

const DRAINED_LEVELS := 0x74
const DRAINED_HP := 0x75
const HIGHEST := 0x73
const STATUS_GONE := 8


## The race level caps (START.EXE 0x3AF7): true when this class can't go up from its level.
## Races: 1 dwarf, 2 elf, 3 gnome, 4 half-elf, 5 halfling; classes 0 cleric, 2 fighter;
## strength is record byte 0x10.
static func race_capped(m: PartyMember, c: int) -> bool:
	var lv := m.level_in(c)
	if lv <= 0:
		return false
	var st: int = m.stats[0] if m.stats.size() > 0 else 0
	match m.race_id:
		1:
			return c == 2 and ((lv == 8 and st == 17) or (lv == 7 and st < 17))
		2:
			return c == 2 and (lv == 7 or (lv == 6 and st == 17) or (lv == 5 and st < 17))
		3:
			return c == 2 and (lv == 6 or (lv == 5 and st < 18))
		4:
			if c == 0:
				return lv == 5
			return c == 2 and (lv == 8 or (lv == 7 and st == 17) or (lv == 6 and st < 17))
		5:
			return c == 2 and (lv == 6 or (lv == 5 and st == 17) or (lv == 4 and st < 17))
	return false


## 0x10C5D: the class a drain takes a level from, and that class's level's experience total.
static func _drain_pick(m: PartyMember, t: ClassTables) -> Array:
	var best := 0
	var best_lv := 0
	var best_exp := 0
	for c in 8:
		var lv := m.level_in(c)
		var e := t.needed(c, lv) if lv > 1 else 0
		if lv < best_lv:
			continue
		if e >= best_exp or e == -1:
			best_exp = e
			best = c
			best_lv = lv
	return [best, best_exp]


## A hit that drains `levels` (1 or 2). Returns the messages, in order.
static func drain(m: PartyMember, levels: int, t: ClassTables, spells: SpellTable) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("%s IS DRAINED %s" % [m.name, "A LEVEL" if levels == 1 else "%d LEVELS" % levels])
	if m.status == PartyMember.STATUS_ANIMATED:
		m.status = STATUS_GONE
		out.append("%s IS DEAD FOREVER" % m.name)
		m.hp = 0
		m.hp_max = 0
		m.raw[0x32] = 0
		return out
	for k in levels:
		if m.status == STATUS_GONE:
			break
		m.raw[DRAINED_LEVELS] = (m.raw[DRAINED_LEVELS] + 1) & 255
		var total := 0
		for c in 8:
			total += m.level_in(c)
		var per := m.hp_max / total if total > 0 else 0
		for i in per:
			m.hp_max = maxi(m.hp_max - 1, 0)
			m.hp_rolled = maxi(m.hp_rolled - 1, 0)
			m.hp = maxi(m.hp - 1, 0)
			m.raw[DRAINED_HP] = (m.raw[DRAINED_HP] + 1) & 255
		m.raw[0x32] = m.hp_max
		m.raw[0xB1] = m.hp_rolled
		if m.raw[HIGHEST] < 2:
			m.status = STATUS_GONE
			out.append("%s IS DEAD FOREVER" % m.name)
			m.hp_max = 0
			m.raw[0x32] = 0
			var p := _drain_pick(m, t)
			if m.level_in(p[0]) > 0 and levels == 2:
				m.set_level(p[0], 0)
		else:
			var p := _drain_pick(m, t)
			m.set_level(p[0], m.level_in(p[0]) - 1)
			if m.hp == 0 and m.status != PartyMember.STATUS_DEAD:
				m.status = PartyMember.STATUS_DEAD
				out.append("%s IS KILLED" % m.name)
			recount(m, t, spells)
		var q := _drain_pick(m, t)
		m.raw[HIGHEST] = m.level_in(q[0])
		m.experience = maxi(int(q[1]), 0)
	return out


## Restoration on `m`. Returns its message, or "" when nothing was drained.
static func restore(m: PartyMember, t: ClassTables, spells: SpellTable) -> String:
	if m.raw.size() <= DRAINED_HP or m.raw[DRAINED_LEVELS] == 0:
		return ""
	var back: int = m.raw[DRAINED_HP] / m.raw[DRAINED_LEVELS]
	m.hp = (m.hp + back) & 255
	m.hp_max = (m.hp_max + back) & 255
	m.hp_rolled = (m.hp_rolled + back) & 255
	m.raw[0x32] = m.hp_max
	m.raw[0xB1] = m.hp_rolled
	m.raw[DRAINED_HP] = (m.raw[DRAINED_HP] - back) & 255
	m.raw[DRAINED_LEVELS] -= 1
	var best_lv := 13
	var least := 10000000
	var chosen := -1
	for c in 8:
		var lv := m.level_in(c)
		if lv <= 0 or lv > best_lv:
			continue
		var need := t.needed(c, lv + 1)
		if need > 0 and need < least and not race_capped(m, c):
			best_lv = lv
			least = need
			chosen = c
	# With no class able to go up the original raises an unset class index and the
	# experience to 10,000,000; not reachable in Pool (cleric 6, fighter 8...): left out.
	if chosen >= 0:
		m.set_level(chosen, m.level_in(chosen) + 1)
		if m.experience < least:
			m.experience = least
	recount(m, t, spells)
	return "%s IS RESTORED" % m.name


## The level recount (GAME.OVR 0x2AA87), from ours' class tables.
static func recount(m: PartyMember, t: ClassTables, spells: SpellTable) -> void:
	var old_slots: Array = m.spell_slots.duplicate(true)
	m.apply_class_tables(t, spells)
	# The original rewrites spells per day only for a cleric / magic-user above level 1.
	if old_slots.size() == 2:
		if m.level_in(0) <= 1:
			m.spell_slots[0] = old_slots[0]
			for k in 3:
				m.raw[0xB2 + k] = old_slots[0][k]
		if m.level_in(5) <= 1:
			m.spell_slots[1] = old_slots[1]
			for k in 3:
				m.raw[0xB5 + k] = old_slots[1][k]
	m.half_attacks = 3 if m.level_in(2) > 6 else 2
	m.raw[0xA1] = m.half_attacks
	var top := 0
	for c in 8:
		top = maxi(top, m.level_in(c))
	m.raw[HIGHEST] = maxi(m.raw[HIGHEST], top)
	if CharacterSheet.types != null:
		m.recalculate(CharacterSheet.types)      # THAC0 and the rest from the new levels

class_name SmartQuick
extends RefCounted
## SETTINGS: TACTICS FOR QUICK, SMARTER (Jeremy's B1, decided 2026-11-14; off by default).
## The party's own QUICK members (not computer-run NPC allies, not monsters) play more like
## a careful player. With the switch off, every rule here is skipped and QUICK plays as the
## original's. Headless runs (the bot, the lab) and the lab dice keep it off.
##
## - Heal and bandage: bandage a dying ally first (as QUICK BANDAGES); a caster with Cure
##   Light Wounds heals the most hurt ally within touch (itself included) once that one is
##   at half its hit points or less.
## - No wasted spells: only spells that work in a fight; no Magic Missile that would do
##   nothing (level 1, the original's own rule); an area spell only where it catches at
##   least two enemies who aren't already helpless and none of the party; a picked spell at
##   the weakest enemies in range. Spells that don't hurt enemies are left for the player.
## - Focus fire: a new target is the enemy with the fewest hit points (nearest first on a
##   tie), not a random one.
## - Archers hang back: already the original's rule (a missile user shoots once in range).
## - When hurt (a quarter of its hit points or less), it doesn't walk up to an enemy; next to
##   one it fights on (stepping away would invite free attacks).
## - The whole party flees when the fight looks hopeless: the enemies standing have more
##   than four times the party's standing hit points.

const KEY := "smart_quick"
const CURE_LIGHT_WOUNDS := 3
const MAGIC_MISSILE := 15


static func on() -> bool:
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return false
	return bool(cf.get_value("qol", KEY, false))


static func save(enabled: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", KEY, enabled)
	cf.save(GameData.SETTINGS_PATH)


## Combatant i is one of the party's own members (QUICK) and the switch is on.
static func applies(cb: Combat, i: int) -> bool:
	if not cb.smart_quick or i < 0:
		return false
	var c: Dictionary = cb.combatants[i]
	var m: PartyMember = c.who
	return c.team == 0 and m.npc < 128 and m.script_team != 0x80


## Casting is allowed for QUICK members (Alt-M MAGIC ON, or the caller's party_casts).
static func _may_cast(cb: Combat) -> bool:
	return cb.magic != null and (CombatSpells.party_casts or cb.magic_on)


## Cure Light Wounds on the most hurt ally within touch at half its hit points or less.
static func heal(cb: Combat, i: int) -> bool:
	if not _may_cast(cb):
		return false
	var me: Dictionary = cb.combatants[i]
	var m: PartyMember = me.who
	if not CURE_LIGHT_WOUNDS in m.ready_spells():
		return false
	var best := -1
	var worst := 1.0
	for j in cb.combatants.size():
		var e: Dictionary = cb.combatants[j]
		var w: PartyMember = e.who
		if e.down or e.team != me.team or w.hp_max <= 0:
			continue
		if j != i and not cb.touching(me, e):
			continue
		var part := float(w.hp) / w.hp_max
		if part <= 0.5 and part < worst:
			worst = part
			best = j
	if best < 0:
		return false
	var one: Array[int] = [best]
	cb.magic.cast(i, CURE_LIGHT_WOUNDS, cb.combatants[best].cell, one)
	return true


## An attack spell where it does the most good, or false.
static func cast(cb: Combat, i: int) -> bool:
	if not _may_cast(cb):
		return false
	var ms: CombatSpells = cb.magic
	var me: Dictionary = cb.combatants[i]
	var m: PartyMember = me.who
	var list := ms.castable(i)
	list.sort_custom(func(a, b): return ms.table.field(a, 13) > ms.table.field(b, 13))
	for id in list:
		if ms.table.field(id, 14) == 0:
			continue                  # not meant for enemies: left for the player
		if id == MAGIC_MISSILE and m.caster_level(ms.table, id) / 2 == 0:
			continue
		var kind := ms.aim_kind(id)
		if kind == "self":
			continue
		var targets: Array[int] = []
		for j in cb.combatants.size():
			var e: Dictionary = cb.combatants[j]
			if not e.down and e.team != me.team and not CombatSpells.held(e.who) \
					and ms.why_not(i, id, e.cell) == "":
				targets.append(j)
		if targets.is_empty():
			continue
		_weakest_first(cb, me, targets)
		if kind == "pick":
			var picked: Array[int] = []
			for j in targets:
				if picked.size() < ms.max_picks(id):
					picked.append(j)
			me.target = picked[0]
			ms.cast(i, id, cb.combatants[picked[0]].cell, picked)
			return true
		# An area: the enemy's cell that catches the most enemies and none of the party.
		var best_cell := Vector2i(-1, -1)
		var best_n := 1
		for j in targets:
			var cell: Vector2i = cb.combatants[j].cell
			var area := ms.area_cells(i, id, cell)
			var n := 0
			var ours := false
			for e in cb.combatants:
				if e.down:
					continue
				var inside := false
				for p in cb.cells(e):
					if p in area:
						inside = true
				if not inside:
					continue
				if e.team == me.team:
					ours = true
				elif not CombatSpells.held(e.who):
					n += 1
			if not ours and n > best_n:
				best_n = n
				best_cell = cell
		if best_cell.x >= 0:
			var none: Array[int] = []
			ms.cast(i, id, best_cell, none)
			return true
	return false


## The list sorted fewest hit points first, nearest first on a tie.
static func _weakest_first(cb: Combat, me: Dictionary, list: Array[int]) -> void:
	cb._by_distance(me, list)
	var order := {}
	for k in list.size():
		order[list[k]] = k
	list.sort_custom(func(a, b):
		var ha: int = cb.combatants[a].who.hp
		var hb: int = cb.combatants[b].who.hp
		return ha < hb or (ha == hb and order[a] < order[b]))


## The weakest of `pool` (a copy of the list is sorted).
static func weakest(cb: Combat, i: int, pool: Array[int]) -> int:
	var list: Array[int] = pool.duplicate()
	_weakest_first(cb, cb.combatants[i], list)
	return list[0]


## A quarter of its hit points or less.
static func hurt(cb: Combat, i: int) -> bool:
	var m: PartyMember = cb.combatants[i].who
	return m.hp * 4 <= m.hp_max


## The enemies standing have more than four times the party's standing hit points.
static func hopeless(cb: Combat) -> bool:
	var ours := 0
	var theirs := 0
	for e in cb.combatants:
		if e.down or CombatSpells.held(e.who):
			continue
		if e.team == 0:
			ours += e.who.hp
		else:
			theirs += e.who.hp
	return theirs > 4 * ours

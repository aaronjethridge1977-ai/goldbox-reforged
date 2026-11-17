class_name Rememorize
extends RefCounted
## RE-MEMORIZE ON REST (QoL, Jeremy's Q11 / C11-2, a SETTINGS switch, default ON; the later Gold Box
## games' behaviour). Each caster keeps a plan: the spells it last chose under MEMORIZE. When the
## player picks REST, every copy of the plan no longer in memory (cast since) is put back as if
## picked again ("*", memorized while resting, in the original's time: no shortcut). OFF is the
## original: a cast spell's slot stays empty until MEMORIZE picks it again.
##
## The plan lives in the member's metadata for the session and goes into the save's companion
## file ([qol] rememorize: name -> spell ids). A member with no plan yet takes the spells in its
## memory the first time the camp opens.

const KEY := "rememorize"
const META := &"gbr_rememorize"


static func on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", KEY, true))


static func save_on(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", KEY, value)
	c.save(GameData.SETTINGS_PATH)


static func plan(m: PartyMember) -> Array:
	return m.get_meta(META, []) if m.has_meta(META) else []


## The camp opens: a member with no plan takes what it has in memory now.
static func note_camp(party: Array) -> void:
	for m: PartyMember in party:
		if not m.has_meta(META):
			var now := _ids(m)
			if not now.is_empty():
				m.set_meta(META, now)


## MEMORIZE picked a spell: the plan becomes the memory as it now stands, plus the old plan's
## spells for which slots of their class and level are still free (a new pick replaces the
## remembered spell of its own level only).
static func note_pick(m: PartyMember, table: SpellTable) -> void:
	var now := _ids(m)
	var spare := {}
	for c in 2:
		for l in 3:
			spare[Vector2i(c, l + 1)] = int(m.spell_slots[c][l]) if c < m.spell_slots.size() else 0
	for id in now:
		var k := Vector2i(table.spell_class(id), table.level(id))
		spare[k] = int(spare.get(k, 0)) - 1
	var left := now.duplicate()
	var out := now.duplicate()
	for id in plan(m):
		var i := left.find(id)
		if i >= 0:
			left.remove_at(i)
			continue
		var k := Vector2i(table.spell_class(id), table.level(id))
		if int(spare.get(k, 0)) > 0:
			spare[k] = int(spare[k]) - 1
			out.append(id)
	m.set_meta(META, out)


## REST: puts back every copy of the plan that is missing from memory, while slots allow.
## Returns how many spells were put back.
static func refill(party: Array, table: SpellTable) -> int:
	if not on() or table == null:
		return 0
	var n := 0
	for m: PartyMember in party:
		if m.status != PartyMember.STATUS_OKAY:
			continue
		var have := m.memorized.map(func(s): return int(s) % PartyMember.LEARNING)
		for id in plan(m):
			var i := have.find(id)
			if i >= 0:
				have.remove_at(i)
				continue
			if m.slots_left(table, table.spell_class(id), table.level(id)) > 0:
				m.memorized.append(id + PartyMember.LEARNING)
				m.sort_memorized()     # as a MEMORIZE pick (GAME.OVR 0x1827E)
				n += 1
	return n


## The companion file's value: name -> plan.
static func to_save(party: Array) -> Dictionary:
	var d := {}
	for m: PartyMember in party:
		if m.has_meta(META):
			d[m.name] = PackedInt32Array(m.get_meta(META))
	return d


static func from_save(party: Array, d: Variant) -> void:
	if not d is Dictionary:
		return
	for m: PartyMember in party:
		if m.has_meta(META):
			m.remove_meta(META)
		if (d as Dictionary).has(m.name):
			m.set_meta(META, Array(d[m.name]))


static func _ids(m: PartyMember) -> Array:
	return m.memorized.map(func(s): return int(s) % PartyMember.LEARNING)

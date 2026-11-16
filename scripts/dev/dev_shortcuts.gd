class_name DevShortcuts
extends RefCounted
## Dev-only shortcuts for the M6 progression run (decided 2026-11-12): when the bot fails it
## uses the smallest shortcut that works and moves on. Never in a player build: every entry
## point refuses unless OS.is_debug_build() (an exported release build is not one).
## Every use is logged by the caller (PlayBot), and a fight won by shortcut goes on the list
## for the combat test suite.

static func allowed() -> bool:
	return OS.is_debug_build()


## Restore: every member alive, conscious, at full hit points, free of conditions, and with
## every spell it is memorizing memorized. Returns what changed, for the log.
static func restore(party: Array) -> String:
	if not allowed():
		return ""
	var done: PackedStringArray = []
	for m in party:
		var p := m as PartyMember
		var what: PackedStringArray = []
		if p.status != PartyMember.STATUS_OKAY:
			what.append(p.status_name())
			p.status = PartyMember.STATUS_OKAY
		if p.hp < p.hp_max:
			what.append("%d/%d HP" % [p.hp, p.hp_max])
			p.hp = p.hp_max
		# Chat 34: the racial abilities stay (standing effects only a load gives back): c33b's
		# retries after a restore had DORN fight 5:4's fire giants without the dwarf's 0x2F.
		var racial: Array = SpecialAffects.RACIAL.get(p.race_id, [])
		var kept := p.affects.filter(func(a): return int(a.effect) in racial and int(a.get("spell", 0)) == 0)
		if kept.size() < p.affects.size():
			what.append("%d effects" % (p.affects.size() - kept.size()))
			p.affects = kept
		var learned := 0
		for i in p.memorized.size():
			if p.memorized[i] >= PartyMember.LEARNING:
				p.memorized[i] -= PartyMember.LEARNING
				learned += 1
		if learned > 0:
			what.append("%d spells" % learned)
		p.learn_hours = 0
		if not what.is_empty():
			done.append("%s (%s)" % [p.name, ", ".join(what)])
	return "; ".join(done)


## Grant a level: the member gets the experience for its next level (the class that trains
## first, as the hall picks it) and trains at once, free. Nothing past the game's caps (the
## class tables end there). Returns the new levels, or "" if it can't go further.
## `pick` chooses a magic-user's new spell from those offered (-1: the first).
static func grant_level(m: PartyMember, tables: ClassTables, spells: SpellTable,
		rng: RandomNumberGenerator, pick: Callable = Callable()) -> String:
	if not allowed() or m.status != PartyMember.STATUS_OKAY:
		return ""
	var need := 0
	for c in m.class_indices():
		var n := tables.needed(c, m.level_in(c) + 1)
		if n > 0 and (need == 0 or n < need):
			need = n
	if need <= 0:
		return ""
	m.experience = maxi(m.experience, need)
	var copper := m.money.duplicate()
	m.receive_gold(1000)
	var plan := m.training_plan(tables, 0xFF)
	if not plan.has("classes"):
		m.money = copper
		return ""
	var learns := m.train(tables, spells, plan.classes, rng)
	m.money = copper           # free: the shortcut doesn't spend the party's money
	if learns:
		var offered := m.learnable_spells(spells)
		if not offered.is_empty():
			var id: int = pick.call(offered) if pick.is_valid() else offered[0]
			if id > 0 and id <= m.spell_book.size():
				m.spell_book[id - 1] = 1
	var levels: PackedStringArray = []
	for c in m.class_indices():
		levels.append(str(m.level_in(c)))
	return "/".join(levels)

class_name CombatSpells
extends RefCounted
## Spells in a fight: choosing them, aiming them, what they do, and their effects on the
## fight while they last.
##
## As the original does it (rules as documented by Pilgrim's reconstruction of the same
## engine; spell data from Pool of Radiance's own table, see SpellTable):
## - CAST lists the caster's memorized spells; camp-only ones are refused ("CAMP ONLY
##   SPELL"). Casting uses the caster's whole turn and removes the spell from memory.
##   "<NAME> CASTS A SPELL" / "SPELL: <SPELL>".
## - Aiming, by the spell's area code (table byte 6, low 4 bits): 0 = the caster; 8..14 =
##   a point within range, and everyone within (code & 7) squares of it with a clear line
##   from it is a target (Fireball 3 squares, 2 outdoors; Sleep and Stinking Cloud 1;
##   Bless, Curse, Haste and Slow 2); otherwise up to (code & 3) + 1 figures picked one by
##   one (Hold Person 3, the magic-user's Hold Person 4, most spells 1). Range: the
##   table's range + range per caster level; touch spells reach the next square.
## - Saving throws: d20 + bonuses against the target's own save number for the table's
##   save type (1 always fails, 20 always succeeds). On a save the spell does nothing (or
##   half damage, by the table). Large creatures and non-humanoids always resist Hold
##   Person and Charm Person.
## - Touch attacks (Cause Light Wounds, Shocking Grasp) need a hit roll.
## - Effects that matter in a fight: Bless and Prayer +1 to hit (Prayer also +1 to saves),
##   Curse -1; Protection from Evil/Good: evil/good attackers -2 to hit and +2 to saves;
##   Shield: AC no worse than 3, +1 to saves, stops Magic Missile; Invisibility: -4 to hit
##   it, ends when it attacks or casts; Mirror Image: each attack may hit an image instead;
##   Ray of Enfeeblement: its damage less a quarter; Haste doubles moves and attacks, Slow
##   halves them (each cancels the other first); Sleep, Hold Person and Stinking Cloud
##   leave a figure helpless: it can't act, and any attack slays it ("SLAYS HELPLESS ...
##   WITH ONE CRUEL BLOW"). Durations count down a round at a time.
## - The computer casts (monsters with spells): each turn it tries up to d7 priority levels
##   from 7 down, three random memorized spells at each; a spell qualifies if its
##   priority is high enough and, if it is meant for enemies, one is in range.
## - Item spells (ids 57-67, SpellTable.from_item), from their handlers in GAME.OVR's table
##   at DS:0x6B88: Speed (haste unless slowed, "IS SPEEDY"), Giant Strength (STR 21),
##   Javelin of Lightning (1d6+20 electricity, half on a save), Paralyzation (Hold, "IS
##   PARALYZED"), Healing (2d4+2, "IS HEALED"), Disappearance (effect 0x47: -4 to hit, as
##   Invisibility), Necklace of Missiles (Fireball's handler), Magic Missiles (2d4+2).
## - Element damage (handlers 0x0A, 0x14, 0x3D): Resist Cold halves cold and Resist Fire
##   fire, each +3 to the save; a Ring of Fire Resistance takes 2 off each die of fire
##   (never below 1 a die) and +4 to the save. Blindness (0x21) and Bestow Curse (0x24):
##   -4 to hit and -4 to saves; blindness also 4 worse AC. A silenced caster (0x15) loses
##   the spell ("IS SILENCED"). Protection from Normal Missiles (0x29): missiles without a
##   plus are avoided (SpecialAffects.weapon_damage). Haste ages its target a year, once
##   ("AGES", handler 0x27).
## Not yet: Stinking Cloud's lasting cloud, Lightning Bolt bouncing off walls (it runs
## straight), Spiritual Hammer's weapon, Charm Person lasting beyond the fight, Blink,
## Silence's own area and save.

const EFFECT_BLESS := 1
const EFFECT_CURSE := 2
const EFFECT_PROT_EVIL := 8
const EFFECT_PROT_GOOD := 9
const EFFECT_SHIELD := 17
const EFFECT_INVISIBLE := 25
const EFFECT_MIRROR := 28
const EFFECT_ENFEEBLED := 29
const EFFECT_HELPLESS := 31
const EFFECT_HASTE := 39
const EFFECT_SLOW := 42
const EFFECT_PROT_EVIL_10 := 45
const EFFECT_PROT_GOOD_10 := 46
const EFFECT_PRAYER := 49
const EFFECT_SNAKE_CHARM := 51
const EFFECT_PARALYZE := 52
const EFFECT_SLEEP := 53
const HELD := [EFFECT_SNAKE_CHARM, EFFECT_PARALYZE, EFFECT_SLEEP, EFFECT_HELPLESS]

const EFFECT_RESIST_COLD := 0x0A
const EFFECT_RESIST_FIRE := 0x14
const EFFECT_SILENCED := 0x15
const EFFECT_BLIND := 0x21
const EFFECT_BESTOW_CURSE := 0x24
const EFFECT_PNM := 0x29
const EFFECT_DISAPPEAR := 0x47
const RING_FIRE := 0x3D
const NECKLACE := 64

const MAGIC_MISSILE := 15
const LIGHTNING := 51
const FIREBALL := 47
const EVIL := [2, 5, 8]
const GOOD := [0, 3, 6]

var c: Combat
var table: SpellTable
var outdoors := false
## Lab (PlayBot): let the party's computer-run members cast as the monsters do, standing in
## for a player choosing spells. Off in normal play.
static var party_casts := false
## Lab (PlayBot): a player's own choice of spell for a party member, asked before the
## computer's random picks: planner(spells, i) returns {id, cell, picked}, {} for none
## (the member then fights), or {"random": true} to let the computer pick.
static var party_planner: Callable


func _init(combat: Combat, spells: SpellTable) -> void:
	c = combat
	table = spells


# --- Effects in the fight -------------------------------------------------------------------

static func held(m: PartyMember) -> bool:
	for e in HELD:
		if m.has_affect(e):
			return true
	return false


func _affect(m: PartyMember, effect: int) -> Dictionary:
	for a in m.affects:
		if int(a.effect) == effect:
			return a
	return {}


static func _alignment(m: PartyMember) -> int:
	return m.raw[0xA0] if m.raw.size() > 0xA0 else 4


## To-hit adjustment for attacker am against target tm from spell effects.
func hit_bonus(am: PartyMember, tm: PartyMember) -> int:
	var b := 0
	if am.has_affect(EFFECT_BLESS):
		b += 1
	if am.has_affect(EFFECT_CURSE):
		b -= 1
	if am.has_affect(EFFECT_PRAYER):
		b += 1
	if _protected_from(tm, am):
		b -= 2
	if tm.has_affect(EFFECT_INVISIBLE) or tm.has_affect(EFFECT_DISAPPEAR):
		b -= 4
	if am.has_affect(EFFECT_BLIND):
		b -= 4
	if am.has_affect(EFFECT_BESTOW_CURSE):
		b -= 4
	return b


func _protected_from(tm: PartyMember, am: PartyMember) -> bool:
	var al := _alignment(am)
	if (tm.has_affect(EFFECT_PROT_EVIL) or tm.has_affect(EFFECT_PROT_EVIL_10)) and al in EVIL:
		return true
	if (tm.has_affect(EFFECT_PROT_GOOD) or tm.has_affect(EFFECT_PROT_GOOD_10)) and al in GOOD:
		return true
	return false


## AC as spells leave it (Shield: no worse than 3).
func armour(tm: PartyMember, ac: int) -> int:
	if tm.has_affect(EFFECT_BLIND):
		ac += 4
	return mini(ac, 3) if tm.has_affect(EFFECT_SHIELD) else ac


func damage_after(am: PartyMember, dmg: int) -> int:
	if am.has_affect(EFFECT_ENFEEBLED):
		dmg -= dmg / 4
	return dmg


## An attack aimed at a figure with mirror images may strike an image instead.
func image_takes_it(tm: PartyMember) -> bool:
	var a := _affect(tm, EFFECT_MIRROR)
	if a.is_empty():
		return false
	var images: int = int(a.value) >> 4
	if c.roll(1, images + 1, "%s's images" % tm.name) <= 1:
		return false
	images -= 1
	c.message.emit("%s LOST AN IMAGE" % tm.name)
	if images <= 0:
		tm.affects.erase(a)
	else:
		a.value = images << 4
	return true


func reveal(m: PartyMember) -> void:
	for e in [EFFECT_INVISIBLE, EFFECT_DISAPPEAR]:
		var a := _affect(m, e)
		if not a.is_empty():
			m.affects.erase(a)


## Moves and attacks at the start of a round, after Haste and Slow.
func adjust_round(entry: Dictionary) -> void:
	var m: PartyMember = entry.who
	if m.has_affect(EFFECT_HASTE):
		entry.moves *= 2
		entry.attacks *= 2
		var h := _affect(m, EFFECT_HASTE)
		if not h.is_empty() and (int(h.value) & 0x10) == 0:
			h.value = int(h.value) + 0x10
			c.message.emit("%s AGES" % m.name)
			if m.raw.size() > 0x31:
				m.raw.encode_u16(0x30, m.raw.decode_u16(0x30) + 1)
	if m.has_affect(EFFECT_SLOW):
		entry.moves /= 2
		entry.attacks /= 2


## A round passes for every effect on the field.
func tick() -> void:
	var people: Array = []
	for e in c.combatants:
		people.append(e.who)
	SpellCaster.pass_time(people, 1)


## Saving throw for `m` against save type `kind` (0..4), with `bonus`; `caster` for
## Protection from Evil/Good.
func save(m: PartyMember, kind: int, bonus: int, caster: PartyMember) -> bool:
	var d := c.roll(1, 20, "%s saves" % m.name)
	if d == 1:
		return false
	if d == 20:
		return true
	d += bonus
	if m.has_affect(EFFECT_SHIELD):
		d += 1
	if m.has_affect(EFFECT_PRAYER):
		d += 1
	if caster != null and _protected_from(m, caster):
		d += 2
	d += racial_save_bonus(m, kind)
	if m.has_affect(EFFECT_BLIND) or m.has_affect(EFFECT_BESTOW_CURSE):
		d -= 4
	var need: int = m.saves[kind] if kind < m.saves.size() else 20
	return d >= need


## Save bonus from standing effects (SpecialAffects: racial CON bonuses, undead that
## always save against poison).
static func racial_save_bonus(m: PartyMember, kind: int) -> int:
	return SpecialAffects.save_bonus(m, kind)


## Whether `t` throws off Sleep, Charm, Hold or poison (SpecialAffects.blocks).
func resists(t: PartyMember, type: int) -> bool:
	return SpecialAffects.blocks(t, type, func(): return c.roll(1, 100, "%s resists" % t.name))


# --- Choosing and aiming ------------------------------------------------------------------

func castable(i: int) -> Array[int]:
	var out: Array[int] = []
	var m: PartyMember = c.combatants[i].who
	for id in m.ready_spells():
		if table.when(id) != SpellTable.WHEN_CAMP:
			out.append(id)
	return out


func area_code(id: int) -> int:
	return table.field(id, 6) & 0x0F


## "self", "area" (radius) or "pick" (several figures).
func aim_kind(id: int) -> String:
	var code := area_code(id)
	if code == 0 or table.target(id) == SpellTable.TARGET_SELF or id == 63:
		return "self"
	if code >= 8 and code <= 14:
		return "area"
	return "pick"


func radius(id: int) -> int:
	if (id == FIREBALL or id == NECKLACE) and outdoors:
		return 2
	return area_code(id) & 7


func max_picks(id: int) -> int:
	return (area_code(id) & 3) + 1


func spell_range(i: int, id: int) -> int:
	var m: PartyMember = c.combatants[i].who
	return maxi(table.range_for(id, m.caster_level(table, id)), 1)


## Why combatant i can't aim spell `id` at `cell` ("" if it can).
func why_not(i: int, id: int, cell: Vector2i) -> String:
	if not c.field.in_bounds(cell.x, cell.y):
		return "OUT OF RANGE"
	var me: Dictionary = c.combatants[i]
	var best := 1 << 30
	var clear := false
	for p in c.cells(me):
		var l := c.line_steps(p, cell)
		best = mini(best, c.line_steps(p, cell, false).x / 2)
		clear = clear or l.y == 1
	if best > spell_range(i, id):
		return "OUT OF RANGE"
	if not clear:
		return "NO CLEAR SHOT"
	return ""


## Cells an area spell aimed at `cell` covers (for the preview and its targets).
func area_cells(i: int, id: int, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if id == LIGHTNING:
		return _bolt_cells(i, cell)
	var r := radius(id)
	for y in range(cell.y - r * 2 - 1, cell.y + r * 2 + 2):
		for x in range(cell.x - r * 2 - 1, cell.x + r * 2 + 2):
			var p := Vector2i(x, y)
			if c.field.in_bounds(x, y) and c.range_between(cell, p) <= r and c.line_steps(cell, p).y == 1:
				out.append(p)
	return out


## Lightning Bolt: a straight line from the caster through the aim point, as far as the
## spell's range takes it (it stops at walls).
func _bolt_cells(i: int, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from: Vector2i = c.combatants[i].cell
	var d := cell - from
	if d == Vector2i.ZERO:
		return out
	var far := from + d * 50
	var reach := spell_range(i, LIGHTNING) * 2
	var dx := absi(far.x - from.x)
	var dy := absi(far.y - from.y)
	var sx := signi(far.x - from.x)
	var sy := signi(far.y - from.y)
	var cur := from
	var err := 0
	var steps := 0
	while steps < reach:
		if dx >= dy:
			cur.x += sx
			err += dy * 2
			steps += 2
			if err >= dx:
				cur.y += sy
				err -= dx * 2
				steps += 1
		else:
			cur.y += sy
			err += dx * 2
			steps += 2
			if err >= dy:
				cur.x += sx
				err -= dy * 2
				steps += 1
		if not c.field.walkable(cur.x, cur.y):
			break
		out.append(cur)
	return out


func _people_in(cells: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = []
	for j in c.combatants.size():
		var e: Dictionary = c.combatants[j]
		if e.down:
			continue
		for p in c.cells(e):
			if p in cells:
				out.append(j)
				break
	return out


# --- Casting ------------------------------------------------------------------------------

## Combatant i casts `id` at `cell` (area spells) or at the figures in `picked`.
func cast(i: int, id: int, cell: Vector2i, picked: Array[int], item: GameItem = null) -> void:
	var me: Dictionary = c.combatants[i]
	var m: PartyMember = me.who
	var d := 0 if item != null else table.field(id, 12) / 3
	if d > 0 and not me.get("resolving", false):
		# Casting time (GAME.OVR 0x14C0F): "BEGINS CASTING", the turn ends, and the spell goes
		# off at the caster's next turn (resolve_pending) unless a wound spoils it first.
		# (Spells from items: assumed instant; not yet checked.)
		var keep: Array[int] = picked.duplicate()
		me.pending = {"id": id, "cell": cell, "picked": keep}
		me.moves = 0
		me.attacks = 0
		c.message.emit("%s BEGINS CASTING" % m.name)
		c.delay_cast(i, d)
		return
	if item != null:
		CharacterSheet.spend_use(m, item, id)
	else:
		m.forget(id)
	reveal(m)
	me.moves = 0
	me.attacks = 0
	if m.has_affect(EFFECT_SILENCED) and item == null:
		c.message.emit("%s IS SILENCED" % m.name)
		return
	c.message.emit(("%s USES %s" % [m.name, item.name.to_upper()]) if item != null else "%s CASTS A SPELL" % m.name)
	c.message.emit("SPELL: %s" % table.name_of(id))
	var targets: Array[int] = []
	match aim_kind(id):
		"self":
			targets = [i]
		"area":
			targets = _people_in(area_cells(i, id, cell))
			if id == LIGHTNING:
				targets.erase(i)
		"pick":
			targets = picked.duplicate()
	if targets.size() > 0 and id != LIGHTNING:
		me.dir = c.dir_between(me, c.combatants[targets[0]]) if targets[0] != i else me.dir
	_resolve(i, id, targets)


func _resolve(i: int, id: int, targets: Array[int]) -> void:
	var me: Dictionary = c.combatants[i]
	var m: PartyMember = me.who
	var lvl := m.caster_level(table, id)
	var dur := SpellTable.special_duration(id, func(n, d): return c.roll(n, d, "duration"), true)
	if dur < 0:
		dur = table.duration_for(id, lvl)
	match id:
		1, 42:      # Bless, Prayer: the caster's side (Bless: not those next to an enemy)
			var side: Array[int] = []
			for j in (targets if id == 1 else range(c.combatants.size())):
				var e: Dictionary = c.combatants[j]
				if e.down or e.team != me.team:
					continue
				if id == 1 and c.enemy_adjacent(j):
					continue
				side.append(j)
			_effects(i, id, side, dur, lvl)
		2:          # Curse: the other side
			_effects(i, id, targets.filter(func(j): return c.combatants[j].team != me.team), dur, lvl)
		3:          # Cure Light Wounds
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var amount := c.roll(1, 8, "cure")
				if not SpecialAffects.diseased(t):
					t.hp = mini(t.hp + amount, t.hp_max)
					if c.combatants[j].down and t.status == PartyMember.STATUS_DYING:
						# A fallen figure stops dying but stays down this fight (lab: the orc
						# Bakshi healed rolled no initiative the next round; assumed: whether
						# the original shows it unconscious is not yet checked).
						t.status = PartyMember.STATUS_UNCONSCIOUS
						c.combatants[j].bleeding = 0
				c.message.emit("%s %s" % [t.name, "IS FULLY HEALED" if t.hp >= t.hp_max else "IS PARTIALLY HEALED"])
		4, 20:      # Cause Light Wounds, Shocking Grasp: touch attacks
			for j in targets:
				if not _touch_hits(i, j):
					c.message.emit("%s MISSES" % m.name)
					continue
				var dmg := c.roll(1, 8, "spell damage") + (lvl if id == 20 else 0)
				_damage(i, id, j, dmg)
		9:          # Burning Hands: the caster's level in damage
			for j in targets:
				_damage(i, id, j, lvl)
		10, 23, 49: # Charm Person, Hold Person
			var bonus := 0
			if id != 10:
				bonus = [0, -3 if id == 49 else -2, -1, 0, 0][mini(targets.size(), 4)]
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var immune: bool = (t.raw[0x9F] if t.raw.size() > 0x9F else 0) > 1
				if not immune:
					immune = resists(t, SpecialAffects.CHARM if id == 10 else SpecialAffects.PARALYZED)
				if t.is_large() or immune or save(t, table.field(id, 9), bonus, m):
					c.message.emit("%s IS UNAFFECTED" % t.name)
					continue
				if id == 10:
					c.combatants[j].team = me.team
					c.combatants[j].quick = true
					c.combatants[j].target = -1
					c.message.emit("%s IS CHARMED" % t.name)
				else:
					SpellCaster.add_affect(t, EFFECT_PARALYZE, id, dur, lvl)
					c.message.emit("%s IS HELD" % t.name)
		15:         # Magic Missile: the original's handler (GAME.OVR 0x28451) rolls (level / 2)d4
			# + level / 2, not the rule book's (level + 1) / 2 missiles: at level 1 no damage
			# and no dice (lab 2026-11-14, a QUICK Bakshi's missile drew nothing).
			var n := lvl / 2
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				if t.has_affect(EFFECT_SHIELD):
					c.message.emit("%s IS UNAFFECTED" % t.name)
					continue
				_damage(i, id, j, n + c.roll(n, 4, "magic missile"))
		21:         # Sleep: 4d4 worth of hit dice, the weakest first in the order hit
			var power := c.roll(4, 4, "sleep")
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var cost := _sleep_cost(t)
				if t.has_affect(EFFECT_SLEEP) or power < cost:
					continue
				power -= cost
				if resists(t, SpecialAffects.SLEEP):
					c.message.emit("%s IS UNAFFECTED" % t.name)
					continue
				SpellCaster.add_affect(t, EFFECT_SLEEP, id, dur, lvl)
				c.message.emit("%s FALLS ASLEEP" % t.name)
		34:         # Stinking Cloud: a failed save against poison leaves one helpless
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				if save(t, 0, 0, m):
					c.message.emit("%s IS COUGHING" % t.name)
					continue
				SpellCaster.add_affect(t, EFFECT_HELPLESS, id, c.roll(1, 4, "nausea") + 1, 0)
				c.message.emit("%s CHOKES AND GAGS FROM NAUSEA" % t.name)
		32:         # Mirror Image: d4 images
			SpellCaster.add_affect(m, EFFECT_MIRROR, id, dur, c.roll(1, 4, "images") << 4)
			c.message.emit("%s IS DUPLICATED" % m.name)
		47, 51, NECKLACE:   # Fireball, Lightning Bolt: the caster's level in d6, half on a save
			var dmg := c.roll(lvl, 6, "%s damage" % (table.name_of(id).to_lower()))
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var hit := dmg
				if save(t, table.field(id, 9), element_save_bonus(t, kind_of(id)), m):
					hit /= 2
				_damage(i, id, j, hit, lvl)
		60:         # Javelin of Lightning: 1d6+20, half on a save
			var dmg := c.roll(1, 6, "javelin") + 20
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var hit := dmg
				if save(t, table.field(id, 9), element_save_bonus(t, kind_of(id)), m):
					hit /= 2
				_damage(i, id, j, hit)
		65:         # Wand of Magic Missiles: 2d4+2
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				if t.has_affect(EFFECT_SHIELD):
					c.message.emit("%s IS UNAFFECTED" % t.name)
					continue
				_damage(i, id, j, c.roll(2, 4, "magic missiles") + 2)
		12, 35, 59: # Enlarge, Strength, Giant Strength
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var v := Strength.enlarge_target(lvl) if id == 12 else Vector2i(21, 0)
				if id == 35:
					v = Strength.spell_target(t, func(n, d): return c.roll(n, d, "strength"))
				var minutes := SpellTable.special_duration(id, func(n, d): return c.roll(n, d, "duration"), true)
				if Strength.add(t, table.effect(id), id, v.x, v.y, minutes if minutes >= 0 else dur):
					c.message.emit("%s IS STRONGER" % t.name)
				if c.types != null:
					t.recalculate(c.types)
		57:         # Potion of Speed
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				if t.has_affect(EFFECT_SLOW):
					continue
				SpellCaster.add_affect(t, EFFECT_HASTE, id, c.roll(5, 4, "speed"), lvl)
				c.message.emit("%s IS SPEEDY" % t.name)
		63:         # Dust of Disappearance: the caster's whole side
			var side: Array[int] = []
			for j in range(c.combatants.size()):
				if not c.combatants[j].down and c.combatants[j].team == me.team:
					side.append(j)
			for j in side:
				var t: PartyMember = c.combatants[j].who
				SpellCaster.add_affect(t, EFFECT_DISAPPEAR, id, c.roll(2, 10, "duration") * 10, lvl)
				c.message.emit("%s IS INVISIBLE" % t.name)
		62:         # Potion of Healing
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				var amount := c.roll(2, 4, "healing") + 2
				if not SpecialAffects.diseased(t):
					t.hp = mini(t.hp + amount, t.hp_max)
					if c.combatants[j].down and t.status == PartyMember.STATUS_DYING:
						# A fallen figure stops dying but stays down this fight (lab: the orc
						# Bakshi healed rolled no initiative the next round; assumed: whether
						# the original shows it unconscious is not yet checked).
						t.status = PartyMember.STATUS_UNCONSCIOUS
						c.combatants[j].bleeding = 0
					c.message.emit("%s IS HEALED" % t.name)
		48, 55:     # Haste, Slow: up to the caster's level of figures, the other cancelled first
			var other := EFFECT_SLOW if id == 48 else EFFECT_HASTE
			var left := lvl
			for j in targets:
				var e: Dictionary = c.combatants[j]
				if (id == 48) != (e.team == me.team) or left <= 0:
					continue
				left -= 1
				var t: PartyMember = e.who
				var a := _affect(t, other)
				if not a.is_empty():
					t.affects.erase(a)
					continue
				SpellCaster.add_affect(t, table.effect(id), id, dur, lvl)
				c.message.emit("%s %s" % [t.name, "IS HASTED" if id == 48 else "IS SLOWED"])
		41, 46:     # Dispel Magic: spell effects end on everyone in the area
			for j in targets:
				var t: PartyMember = c.combatants[j].who
				if not t.affects.is_empty():
					var gone: Array = t.affects.duplicate()
					t.affects.clear()
					for a in gone:
						SpellCaster.ended(t, a, PackedStringArray())
					c.message.emit("%s IS AFFECTED" % t.name)
		_:
			_effects(i, id, targets, dur, lvl)


func _effects(i: int, id: int, targets: Array, dur: int, lvl: int) -> void:
	var m: PartyMember = c.combatants[i].who
	var effect := table.effect(id)
	for j in targets:
		var t: PartyMember = c.combatants[j].who
		var no_save := table.field(id, 8) == 0
		if not no_save and table.field(id, 8) == 1 and save(t, table.field(id, 9), 0, m):
			c.message.emit("%s IS UNAFFECTED" % t.name)
			continue
		if effect in [SpecialAffects.SLEEP, SpecialAffects.CHARM, SpecialAffects.PARALYZED] and resists(t, effect):
			c.message.emit("%s IS UNAFFECTED" % t.name)
			continue
		if effect > 0:
			SpellCaster.add_affect(t, effect, id, dur, lvl)
		if SpellCaster.WORDS.has(id):
			c.message.emit("%s %s" % [t.name, SpellCaster.WORDS[id]])


func _touch_hits(i: int, j: int) -> bool:
	var a: PartyMember = c.combatants[i].who
	var t: PartyMember = c.combatants[j].who
	if held(t):
		return true
	var need: int = a.thac0 - armour(t, t.ac) - hit_bonus(a, t)
	var d := c.roll(1, 20, "%s touches %s (needs %d)" % [a.name, t.name, need])
	return d != 1 and (d == 20 or d >= need)


func _damage(i: int, id: int, j: int, dmg: int, dice: int = 1) -> void:
	var t: PartyMember = c.combatants[j].who
	if c.combatants[j].down:
		return
	var kind := kind_of(id)
	dmg = SpecialAffects.element_damage(t, kind, dmg)
	dmg = resisted(t, kind, dmg, dice)
	dmg = SpecialAffects.efreeti_fire(t, kind, dmg, dice)
	if (id == 15 or id == 65) and t.has_affect(0x5B):
		dmg = 0                 # juju zombies ignore Magic Missile
	if dmg <= 0:
		c.message.emit("%s IS UNAFFECTED" % t.name)
		return
	var words := kind if kind != SpecialAffects.MAGIC or id == 15 or id == 65 else 0
	c.message.emit(SpecialAffects.damage_words(t.name, dmg, words))
	c.hurt(j, dmg, kind)


## Save bonus against an element (Resist Fire / Cold +3, a Ring of Fire Resistance +4).
static func element_save_bonus(t: PartyMember, kind: int) -> int:
	var b := 0
	if (kind & SpecialAffects.COLD) and t.has_affect(EFFECT_RESIST_COLD):
		b += 3
	if (kind & SpecialAffects.FIRE) and t.has_affect(EFFECT_RESIST_FIRE):
		b += 3
	if (kind & SpecialAffects.FIRE) and t.has_affect(RING_FIRE):
		b += 4
	return b


## Element damage after Resist Fire / Cold and a Ring of Fire Resistance (`dice`: how many
## dice the damage was rolled with).
static func resisted(t: PartyMember, kind: int, dmg: int, dice: int) -> int:
	if (kind & SpecialAffects.COLD) and t.has_affect(EFFECT_RESIST_COLD):
		dmg /= 2
	if (kind & SpecialAffects.FIRE) and t.has_affect(EFFECT_RESIST_FIRE):
		dmg /= 2
	if (kind & SpecialAffects.FIRE) and t.has_affect(RING_FIRE):
		for k in dice:
			dmg -= 2
			dmg = maxi(dmg, dice)
	return dmg


static func kind_of(id: int) -> int:
	match id:
		9, 47, NECKLACE:
			return SpecialAffects.FIRE
		20, 51, 60:
			return SpecialAffects.ELECTRIC
	return SpecialAffects.MAGIC


func _sleep_cost(t: PartyMember) -> int:
	var hd: int = t.raw[0x73] if t.raw.size() > 0x73 else 1
	match hd:
		0, 1:
			return 1
		2:
			return 2
		3:
			return 4
		4:
			return 6
		5:
			return 10 if t.race_id == 0 else 20
	return 20


# --- The computer's spells ------------------------------------------------------------------

## Tries to cast a spell for computer-run combatant i. Returns true if it did.
## The spell combatant i began casting goes off (its turn then ends). The computer aims it
## now (the original's 0x96:0x39 at that turn, GAME.OVR 0xACEE); a player's keeps the aim
## chosen when it was begun (assumed: not yet checked in the lab). False if none.
func resolve_pending(i: int) -> bool:
	var me: Dictionary = c.combatants[i]
	var p: Dictionary = me.get("pending", {})
	if p.is_empty():
		return false
	me.pending = {}
	var id: int = p.id
	var cell: Vector2i = p.cell
	var picked: Array[int] = p.picked
	var smart_kept: bool = SmartQuick.applies(c, i) and (picked.is_empty() or not c.combatants[picked[0]].down)
	if (me.get("quick", false) or me.team == 1) and not smart_kept:
		var plan := _ai_plan(i, id, true)
		if plan.is_empty():
			# Nothing to aim it at any more: the spell is spent (assumed: no message).
			(me.who as PartyMember).forget(id)
			return true
		cell = plan.cell
		picked = plan.picked
	me.resolving = true
	cast(i, id, cell, picked)
	me.resolving = false
	return true


## `tries` is the d7 already drawn in TP mode (-1: draw it here).
func ai_cast(i: int, tries: int = -1) -> bool:
	var me: Dictionary = c.combatants[i]
	var m: PartyMember = me.who
	if me.team == 0 and not (party_casts or c.magic_on):
		return false
	# The original lists every memorized spell, camp spells too, and leaves them to the
	# priority test (GAME.OVR 0xB105, 0xAEAB), so its d-list range counts them; it reads the
	# record's slots from 0x17 up, the reverse of ours's `memorized`. (All play since
	# 2026-11-14, Jeremy's A1; before, only with the lab dice.)
	var list: Array[int] = m.ready_spells()
	list.reverse()
	if me.get("no_spells", false):
		list.clear()
	# With every enemy down the original picks no spell, but a goblin that surrendered still
	# counts: the turns that play out the round pick spells then (lab 2026-11-14, Slums orcs
	# and goblin patrol); only the plans find nothing to aim at.
	if list.is_empty() or not _enemy_left(i):
		return false
	if me.team == 0 and party_planner.is_valid():
		var p: Dictionary = party_planner.call(self, i)
		if not p.has("random"):
			if p.is_empty():
				return false
			cast(i, p.id, p.cell, p.picked)
			return true
	if tries < 0:
		tries = c.roll(1, 7, "%s thinks of spells" % m.name)
	var priority := 7
	for k in tries:
		for n in 3:
			var id: int = list[c.roll(1, list.size(), "%s picks a spell" % m.name) - 1]
			if table.field(id, 13) < priority:
				continue
			var plan := _ai_plan(i, id)
			if plan.is_empty():
				continue
			if plan.get("weighed", false) and table.field(id, 12) / 3 == 0:
				# An instant attack spell is aimed now.
				plan = _ai_plan(i, id, true)
				if plan.is_empty():
					m.forget(id)
					return true
			cast(i, id, plan.cell, plan.picked)
			return true
		priority -= 1
	return false


## An enemy of i still standing, or one that surrendered.
func _enemy_left(i: int) -> bool:
	var me: Dictionary = c.combatants[i]
	for e in c.combatants:
		if e.team != me.team and (not e.down or e.get("surrendered", false)):
			return true
	return false


## How many standing enemies of i are within `reach` squares (GAME.OVR 0xBA:0x2433, with
## the spell's range from 0x27741: range + per level x level, at least 1 for a touch).
func _enemies_within(i: int, reach: int) -> int:
	var me: Dictionary = c.combatants[i]
	var n := 0
	for e in c.combatants:
		if not e.down and e.team != me.team and c.range_of(me, e) <= reach:
			n += 1
	return n


## Whom the computer heals with Cure Light Wounds (GAME.OVR 0x143F3): looking at the eight
## cells round the caster (up first, clockwise) and then its own, the standing figure of its
## side with the fewest hit points below its maximum (the caster too); a figure of
## either side lying there unconscious or dying instead (the original's list of fallen
## figures, DS:0x66D6, has no side check; lab: Bakshi healed a fallen orc), but only when
## nobody standing has fewer than 8 hit points. -1: nobody.
func cure_target(i: int) -> int:
	var me: Dictionary = c.combatants[i]
	var best := -1
	var low := 0xFF
	var body := -1
	for k in 9:
		var cell: Vector2i = me.cell + (Combat.DIRS[k] if k < 8 else Vector2i.ZERO)
		var j := c.occupant(cell, -1)
		if j >= 0 and not c.combatants[j].down:
			var e: Dictionary = c.combatants[j]
			var w: PartyMember = e.who
			# (0x144A2: the fewest hit points so far wins; the caster itself also wins a tie
			# or worse while below half, which the original checks only then.)
			if e.team == me.team and w.hp < w.hp_max and (w.hp < low or (j == i and w.hp < w.hp_max / 2)):
				best = j
				low = w.hp
			continue
		for d in c.combatants.size():
			var e: Dictionary = c.combatants[d]
			if e.down and e.cell == cell and e.who.status in [PartyMember.STATUS_UNCONSCIOUS,
					PartyMember.STATUS_DYING]:
				body = d
	if low < 8 or body < 0:
		return best
	return body


## Where the computer would aim `id`: {cell, picked}, or {} if there is no use for it.
## `aiming`: the spell is going off now (not just being weighed).
func _ai_plan(i: int, id: int, aiming: bool = false) -> Dictionary:
	var me: Dictionary = c.combatants[i]
	var offensive := table.field(id, 14) != 0
	if not offensive:
		if id == 3:
			var j := cure_target(i)
			if j < 0:
				# Nobody to heal: the original's check (GAME.OVR 0xAEEA) then falls through to
				# the general one, an enemy within the spell's reach, and takes the spell
				# (lab: Brother Sean began a Cure Light Wounds with no one wounded by him).
				# Going off with nobody to heal, it is spent for nothing (lab: no healing
				# roll in the original).
				if aiming or _enemies_within(i, spell_range(i, id)) == 0:
					return {}
				j = i
			var one: Array[int] = [j]
			return {"cell": c.combatants[j].cell, "picked": one}
		var mine: Array[int] = [i]
		return {"cell": me.cell, "picked": mine}
	if not aiming:
		# Weighing an attack spell (GAME.OVR 0xAF05): some enemy within the spell's range,
		# and for an area spell (table byte 15 = its reach) none of those enemies so placed
		# that the area round it would catch a figure of the caster's side, the caster
		# included (0xAE15). No dice (lab: Bakshi passed over Sleep with Thrender next to
		# the orcs).
		var reach := spell_range(i, id)
		var kind := table.field(id, 15)
		var any := false
		for t in c.combatants:
			if t.down or t.team == me.team or c.range_of(me, t) > reach:
				continue
			any = true
			if kind > 0:
				for e in c.combatants:
					if not e.down and e.team == me.team and c.range_of(e, t) <= kind:
						return {}
		if not any:
			return {}
		var none: Array[int] = []
		return {"cell": me.cell, "picked": none, "weighed": true}
	# Aiming it: a random enemy in range with a clear shot, from the list nearest first, the
	# same pick (GAME.OVR 0x160DB) as a target for a blow, and it becomes the caster's
	# target (lab 2026-11-14: a QUICK Bakshi's Magic Missile, then its next blow drew no
	# new pick).
	var near: Array[int] = []
	for j in c.combatants.size():
		var e: Dictionary = c.combatants[j]
		if not e.down and e.team != me.team and why_not(i, id, e.cell) == "":
			near.append(j)
	if near.is_empty():
		return {}
	c._by_distance(me, near)
	var t: int = near[c.roll(1, near.size(), "%s aims" % me.who.name) - 1]
	me.target = t
	if held(c.combatants[t].who):
		for j in near:
			if not held(c.combatants[j].who):
				t = j
				break
	var picked: Array[int] = [t]
	if aim_kind(id) == "pick":
		for j in near:
			if picked.size() >= max_picks(id):
				break
			if not j in picked:
				picked.append(j)
	return {"cell": c.combatants[t].cell, "picked": picked}

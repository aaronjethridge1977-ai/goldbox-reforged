class_name Combat
extends RefCounted
## The rules of a fight, apart from the screen: turn order, movement, melee and the end.
##
## As the original does it (rules as documented by Pilgrim's reconstruction; checked against
## the original in the test lab as each part lands):
## - Each round every combatant rolls initiative: d6 + DEX reaction adjustment, at least 1;
##   a surprised side gets -6 (0 or less: no action that round). Highest acts first, ties
##   broken at random.
## - Moves and attacks are set for everyone when the round starts. Movement points are
##   half-moves: twice MOVE. A step costs 2, a diagonal step 3; walls and other figures block.
##   Attacks per round come from the half-attack count (3 = 1 and 2 on alternate rounds).
## - Moving into an enemy attacks it with all the attacks left (until it falls). To hit:
##   d20 >= THAC0 - target AC; a natural 1 always misses, a natural 20 always hits. Damage:
##   weapon (or natural) dice + bonuses, at least 0. Attacking ends the combatant's movement.
## - Facing: everyone faces one of eight directions. An attacker turns to its target; the
##   target turns to face the attacker unless it has already been attacked twice this round.
##   A combatant hit from directly behind after being attacked from several sides that
##   round (more than 4 eighth-turns of attacks in all) is attacked "from behind".
## - Free attacks: stepping away from an adjacent enemy (to a cell no longer next to it)
##   gives that enemy an attack from behind, against the rear AC (no shield or DEX, 2
##   worse). It uses all the attacks it has left this round, or one if it has none, so it
##   happens even after the enemy has attacked. It is skipped only if that enemy has
##   already taken its turn, has been attacked this round, and the mover is behind it (the
##   three cells at its back). A mover who falls stops where it is. (Checked in the lab:
##   an orc's free attack on Bakshi stepping away, "(FROM BEHIND)", after it had attacked
##   him that round.)
## - Guarding: a combatant on guard attacks the first enemy that steps next to it, once,
##   with the attacks it saved; guarding ends at its next turn.
## - Going down (party and monsters alike): damage that leaves exactly 0 HP knocks the
##   target out (UNCONSCIOUS, "GOES DOWN"); damage past 0 by 1-9 leaves it DYING ("GOES
##   DOWN AND IS DYING"), bleeding that many points; more than 9 past 0 kills it ("IS
##   KILLED"). HP shows 0 for anyone down. Each new round a dying combatant bleeds one
##   point more and dies past 9; while a party member is dying the round opens with
##   "YOUR TEAMMATE IS DYING". (The lab saw all four messages in the original.)
## - Bandage: a party member can spend its turn bandaging the first dying party member
##   (anywhere on the field), who becomes UNCONSCIOUS and stops bleeding ("IS BANDAGED").
##   Party members on Quick bandage before anything else. The original offers it under
##   DONE: GUARD DELAY QUIT BANDAGE SPEED EXIT (GUARD only with a melee weapon).
## - The fight ends when one side has nobody standing. (QoL: when the last enemy falls the
##   battle ends at once; the original asks "Continue Battle?".)
## Every die roll goes through roll(), which uses a seedable generator and logs the roll, so
## a fight can be replayed and compared rule by rule.
##
## Not yet: missiles, spells, morale and fleeing, surprise from the encounter,
## large monsters filling two cells.

signal message(text: String)

const DIRS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

var field: Battlefield
var combatants: Array = []     # dictionaries from CombatScreen: who, team, cell, icon, dir, ...
var rng := RandomNumberGenerator.new()
var roll_log := PackedStringArray()
var round_no := 0
var order: Array[int] = []
var active := -1
var surprised_team := -1


func _init(battlefield: Battlefield, people: Array, seed_value: int = 0) -> void:
	field = battlefield
	combatants = people
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in combatants:
		c["down"] = false
		c["quick"] = c.team == 1
		c["moves"] = 0
		c["attacks"] = 0
		c["acted"] = false
		c["received"] = 0     # attacks received since its own turn (or last step)
		c["guarding"] = false # guarding until its next turn
		c["bleeding"] = 0     # points past 0 while dying
		c["target"] = -1
		c["pattern"] = 0      # the computer's movement pattern (see below)
		c["turned"] = 0       # eighth-turns of those attacks, as the original counts them


func roll(count: int, size: int, why: String) -> int:
	var total := 0
	for i in count:
		total += rng.randi_range(1, size)
	roll_log.append("%s: %dd%d = %d" % [why, count, size, total])
	return total


# --- Rounds and turns -------------------------------------------------------------------

func standing(team: int) -> int:
	var n := 0
	for c in combatants:
		if c.team == team and not c.down:
			n += 1
	return n


## 0 = fight on, 1 = the party won, 2 = the party lost.
func outcome() -> int:
	if standing(1) == 0:
		return 1
	if standing(0) == 0:
		return 2
	return 0


func start_round() -> void:
	if round_no > 0:
		_bleed()
	round_no += 1
	var delays := {}
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if c.down:
			continue
		var m: PartyMember = c.who
		c.moves = maxi(m.movement, 1) * 2
		var half: int = m.half_attacks
		if round_no % 2 == 1:
			half += 1
		c.attacks = half / 2
		c.acted = false
		var d := roll(1, 6, "initiative %s" % m.name) + m.dex_missile_bonus()
		d = maxi(d, 1)
		if c.team == surprised_team and round_no == 1:
			d -= 6
		if d <= 0 or d > 20:
			continue
		delays[i] = d * 1000 + rng.randi_range(0, 999)   # ties at random
	order.clear()
	for i in delays.keys():
		order.append(i)
	order.sort_custom(func(a, b): return delays[a] > delays[b])
	message.emit("ROUND %d" % round_no)


## Advances to the next combatant who can act; starts new rounds as needed.
## Returns their index, or -1 if the fight is over.
func next_turn() -> int:
	while outcome() == 0:
		if order.is_empty():
			start_round()
			if order.is_empty():
				return -1
		active = order.pop_front()
		var c: Dictionary = combatants[active]
		if c.down:
			continue
		c.acted = true
		c.received = 0
		c.turned = 0
		c.guarding = false
		c.ai = false
		return active
	active = -1
	return -1


## The end of a round: the dying bleed; anyone past 9 dies.
func _bleed() -> void:
	for c in combatants:
		var m: PartyMember = c.who
		if m.status == PartyMember.STATUS_DYING:
			c.bleeding += 1
			if c.bleeding > 9:
				m.status = PartyMember.STATUS_DEAD
				c.bleeding = 0
	if first_dying(0) >= 0:
		message.emit("YOUR TEAMMATE IS DYING")


## The first dying combatant of a team, or -1.
func first_dying(team: int) -> int:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if c.team == team and (c.who as PartyMember).status == PartyMember.STATUS_DYING:
			return i
	return -1


## The active combatant bandages the first dying party member; its turn ends.
func bandage() -> bool:
	if active < 0:
		return false
	var j := first_dying(combatants[active].team)
	if j < 0:
		return false
	var t: Dictionary = combatants[j]
	(t.who as PartyMember).status = PartyMember.STATUS_UNCONSCIOUS
	t.bleeding = 0
	message.emit("%s IS BANDAGED" % t.who.name)
	done()
	return true


## Can the active combatant guard? (Not with a missile weapon, as in the original.)
func can_guard() -> bool:
	if active < 0:
		return false
	var m: PartyMember = combatants[active].who
	return not m.weapon_ranged or m.weapon_ranged_melee


## Applies damage the way the original does (see "Going down" above).
func _hurt(j: int, dmg: int) -> void:
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	if tm.hp >= dmg:
		tm.hp -= dmg
		if tm.hp > 0:
			return
		tm.status = PartyMember.STATUS_UNCONSCIOUS
		t.down = true
		message.emit("%s GOES DOWN" % tm.name)
		return
	var past := dmg - tm.hp
	tm.hp = 0
	t.down = true
	if past > 9:
		tm.status = PartyMember.STATUS_DEAD
		message.emit("%s GOES DOWN" % tm.name)
		message.emit("%s IS KILLED" % tm.name)
	else:
		tm.status = PartyMember.STATUS_DYING
		t.bleeding = past
		message.emit("%s GOES DOWN AND IS DYING" % tm.name)


## After the fight, as the original does: the dying stop bleeding (UNCONSCIOUS, 0 HP).
func finish() -> void:
	for c in combatants:
		var m: PartyMember = c.who
		if m.status == PartyMember.STATUS_DYING:
			m.status = PartyMember.STATUS_UNCONSCIOUS
		c.bleeding = 0


# --- Actions ----------------------------------------------------------------------------

func occupant(cell: Vector2i) -> int:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if not c.down and c.cell == cell:
			return i
	return -1


func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


## The direction (0..7) in which `to` lies from `from`, as the original works it out:
## eight sectors split at about 22.5 and 67.5 degrees.
static func dir_to(from: Vector2i, to: Vector2i) -> int:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var steep := (0x26A * dx) / 0x100      # tan 67.5 * dx
	var flat := (0x6A * dx) / 0x100        # tan 22.5 * dx
	for d in 8:
		var ok := false
		match d:
			0: ok = to.y <= from.y and steep <= dy
			2: ok = to.x >= from.x and flat >= dy
			4: ok = to.y >= from.y and steep <= dy
			6: ok = to.x <= from.x and flat >= dy
			1: ok = to.y <= from.y and to.x >= from.x and steep >= dy and flat <= dy
			3: ok = to.y >= from.y and to.x >= from.x and steep >= dy and flat <= dy
			5: ok = to.y >= from.y and to.x <= from.x and steep >= dy and flat <= dy
			7: ok = to.y <= from.y and to.x <= from.x and steep >= dy and flat <= dy
		if ok:
			return d
	return 0


## Steps the active combatant one cell in direction `dir` (0..7, 0 = up, clockwise), or
## attacks whoever stands there. Returns "moved", "attacked", "fell" (brought down by a
## free attack on the way), "blocked" or "no moves".
func step(dir: int) -> String:
	if active < 0:
		return "blocked"
	var c: Dictionary = combatants[active]
	var to: Vector2i = c.cell + DIRS[dir]
	var other := occupant(to)
	if other >= 0:
		if combatants[other].team == c.team or c.attacks <= 0:
			return "blocked"
		attack(active, other)
		return "attacked"
	if not field.walkable(to.x, to.y):
		return "blocked"
	var cost := 3 if dir % 2 == 1 else 2
	if cost > c.moves:
		return "no moves"
	free_attacks(active, to)
	if c.down:
		c.moves = 0
		c.attacks = 0
		return "fell"
	c.moves -= cost
	c.cell = to
	c.dir = dir
	c.received = 0
	c.turned = 0
	guard_attacks(active)
	if c.down:
		c.moves = 0
		c.attacks = 0
		return "fell"
	return "moved"


## Enemies guarding next to combatant `i`'s new cell attack it (each once).
func guard_attacks(i: int) -> void:
	var c: Dictionary = combatants[i]
	for j in combatants.size():
		var e: Dictionary = combatants[j]
		if c.down:
			return
		if e.down or e.team == c.team or not e.guarding or not adjacent(e.cell, c.cell):
			continue
		e.guarding = false
		if int(e.get("guard_attacks", 0)) <= 0:
			continue
		e.attacks = e.guard_attacks
		e.guard_attacks = 0
		attack(j, i)
		e.attacks = 0


## Free attacks on combatant `i` as it leaves its cell for `to` (see the rules above).
func free_attacks(i: int, to: Vector2i) -> void:
	var c: Dictionary = combatants[i]
	for j in combatants.size():
		var e: Dictionary = combatants[j]
		if c.down:
			return
		if e.down or e.team == c.team or not adjacent(e.cell, c.cell) or adjacent(e.cell, to):
			continue
		var seen := false
		for k in range(-2, 3):
			if e.cell + DIRS[(e.dir + k + 8) % 8] == c.cell:
				seen = true
		if e.acted and e.received > 0 and not seen:
			continue
		if e.attacks <= 0:
			e.attacks = 1
		var moves: int = e.moves
		attack(j, i, true)
		e.moves = moves        # a free attack doesn't cost the attacker its movement


## Counts an attack on `t` from `a` the way the original does (attacks received this round
## and how far they have turned it), before the attack is made.
func _note_attack(a: Dictionary, t: Dictionary) -> void:
	t.received += 1
	var diff := (dir_to(t.cell, a.cell) - int(t.dir) + 8) % 8
	if diff > 4:
		diff = 8 - diff
	t.turned = (t.turned + diff) % 8


## Combatant i attacks combatant j with all its attacks left this round, stopping when j
## falls. `free` marks a free attack (from behind, and the target doesn't turn).
func attack(i: int, j: int, free: bool = false) -> void:
	var a: Dictionary = combatants[i]
	var t: Dictionary = combatants[j]
	var am: PartyMember = a.who
	var tm: PartyMember = t.who
	var behind := free
	if not free:
		_note_attack(a, t)
		if t.received > 1 and dir_to(a.cell, t.cell) == t.dir and t.turned > 4:
			behind = true
		if t.received < 2:
			t.dir = dir_to(t.cell, a.cell)
	a.dir = dir_to(a.cell, t.cell)
	a.moves = 0
	var ac: int = tm.rear_ac if behind else tm.ac
	var how := " (FROM BEHIND)" if behind else ""
	while a.attacks > 0 and not t.down:
		a.attacks -= 1
		var need: int = am.thac0 - ac
		var d20 := roll(1, 20, "%s to hit %s%s (needs %d)" % [am.name, tm.name, how.to_lower(), need])
		var hit := d20 != 1 and (d20 == 20 or d20 >= need)
		if not hit:
			message.emit("%s ATTACKS %s%s AND MISSES" % [am.name, tm.name, how])
			continue
		var dice: Array = am.damage
		var dmg := roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2])
		dmg = maxi(dmg, 0)
		message.emit("%s ATTACKS %s%s HITTING FOR %d" % [am.name, tm.name, how, dmg])
		_hurt(j, dmg)


## Ends the active combatant's turn.
func done() -> void:
	if active >= 0:
		combatants[active].moves = 0
		combatants[active].attacks = 0


# --- Computer-controlled turns ----------------------------------------------------------
# The original's computer-controlled turn (monsters, and party members on Quick), melee
# only, as documented by Pilgrim's reconstruction of the engine:
# - Each combatant keeps a movement pattern (1..6), rerolled at the start of its turn when it
#   is 0 or 4, or on a 1 in 4: d8, then d2 + 4 (on 1-7) or d4 (on 8).
# - Target: it keeps its target while that one is standing; otherwise it picks one at
#   random among the enemies it has a line of sight to (walls block; figures don't), or
#   among all enemies if it sees none. No target: it guards.
# - Each action: a monster attacks a random adjacent enemy (its own target is ignored once
#   adjacent, as in the original); a party member attacks its target if adjacent, else a
#   random adjacent enemy. With no enemy adjacent it steps towards its target: the
#   direction to the target turned by the pattern's offsets, the first of five that is free.
#   A step needs more movement left than it costs (the computer never spends its last
#   half-move). Stepping straight back counts as a failure, as does finding no step; after
#   two failures it picks a new target, after three it stops. A step can draw free attacks.
# - A combatant that cannot attack or move ends its turn guarding: the first enemy to step
#   next to it before its next turn is attacked. An unarmoured magic-user guards rather
#   than closing in.
# - At most 20 tries per turn.

const PATTERN_TURNS := [[8, 7, 6, 1, 2, 8], [8, 1, 2, 7, 6, 7], [7, 1, 8, 6, 2, 1],
	[1, 7, 8, 2, 6, 8], [8, 7, 6, 5, 4, 8], [8, 1, 2, 3, 4, 8], [8, 4, 6, 2, 8, 6]]
const CLASS_MAGE := 5


func _enemy_of(c: Dictionary, j: int) -> bool:
	return j >= 0 and j < combatants.size() and not combatants[j].down and combatants[j].team != c.team


## Line of sight between two cells: a straight line across the grid (the original's own
## line walk: the longer axis steps every cell, the shorter one when the error builds up)
## with no wall tile on it.
func can_see(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := signi(b.x - a.x)
	var sy := signi(b.y - a.y)
	var cur := a
	var err := 0
	while true:
		if not field.walkable(cur.x, cur.y):
			return false
		if cur == b:
			return true
		if dx >= dy:
			cur.x += sx
			err += dy * 2
			if err >= dx:
				cur.y += sy
				err -= dx * 2
		else:
			cur.y += sy
			err += dx * 2
			if err >= dy:
				cur.x += sx
				err -= dy * 2
	return false


## Keeps the combatant's target if it still stands, else picks a new one (see above).
func find_target(i: int) -> bool:
	var c: Dictionary = combatants[i]
	if _enemy_of(c, c.get("target", -1)):
		return true
	c.target = -1
	var seen: Array[int] = []
	var all: Array[int] = []
	for j in combatants.size():
		if _enemy_of(c, j):
			all.append(j)
			if can_see(c.cell, combatants[j].cell):
				seen.append(j)
	var pool := seen if not seen.is_empty() else all
	if pool.is_empty():
		return false
	c.target = pool[roll(1, pool.size(), "%s picks a target" % c.who.name) - 1]
	return true


## Ends combatant `i`'s turn on guard, keeping its unused attacks for a guard attack.
func guard(i: int) -> void:
	var c: Dictionary = combatants[i]
	c.moves = 0
	c.guarding = true
	c.guard_attacks = c.attacks
	c.attacks = 0
	message.emit("%s IS GUARDING" % c.who.name)


func _ai_begin(i: int) -> void:
	var c: Dictionary = combatants[i]
	c.ai = true
	c.tries = 0
	c.fails = 0
	c.last_step = 8
	var p: int = c.get("pattern", 0)
	if p == 0 or p == 4 or roll(1, 4, "%s keeps its pattern?" % c.who.name) == 1:
		var r := roll(1, 8, "%s pattern" % c.who.name)
		p = roll(1, 2, "%s pattern" % c.who.name) + 4 if r != 8 else roll(1, 4, "%s pattern" % c.who.name)
	c.pattern = p


## Could the computer step in direction `dir`? It needs more movement left than the cost.
func _can_step(c: Dictionary, dir: int) -> bool:
	var to: Vector2i = c.cell + DIRS[dir]
	if occupant(to) >= 0 or not field.walkable(to.x, to.y):
		return false
	var cost := 3 if dir % 2 == 1 else 2
	return cost < c.moves


## One step towards the target. Returns "moved", "retry" or "end".
func _approach(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if c.moves / 2 <= 0 or (m.class_id == CLASS_MAGE and m.armor == null):
		guard(i)
		return "end"
	var base := dir_to(c.cell, combatants[c.target].cell)
	var turns: Array = PATTERN_TURNS[c.pattern]
	var k := 0
	while k < 5 and not _can_step(c, (base + int(turns[k])) % 8):
		k += 1
	var dir := (base + int(turns[k])) % 8
	if k == 5 or (dir + 4) % 8 == c.last_step:
		c.fails += 1
		c.pattern = c.pattern % 6 + 1
		if c.fails > 1:
			c.target = -1
			if c.fails > 2:
				c.moves = 0
				return "retry"
			if not find_target(i):
				guard(i)
				return "end"
	if k == 5:
		return "retry"
	c.last_step = dir
	var what := step(dir)
	return "moved" if what == "moved" else "end"


## One action of a computer-controlled turn. Returns false when the turn is over.
func ai_act() -> bool:
	if active < 0:
		return false
	var c: Dictionary = combatants[active]
	if c.down:
		return false
	if not c.get("ai", false):
		_ai_begin(active)
		if c.team == 0 and bandage():
			return false
		if not find_target(active):
			guard(active)
			return false
	while true:
		c.tries += 1
		if c.tries > 20 or c.down:
			guard(active)
			return false
		var t: int = c.get("target", -1)
		if not _enemy_of(c, t) or combatants[t].team == 0 or not adjacent(c.cell, combatants[t].cell):
			t = -1
		if t < 0:
			var near: Array[int] = []
			for j in combatants.size():
				if _enemy_of(c, j) and adjacent(c.cell, combatants[j].cell):
					near.append(j)
			if near.is_empty():
				if not find_target(active):
					guard(active)
					return false
				var r := _approach(active)
				if r == "moved":
					return true
				if r == "end":
					return false
				continue
			t = near[roll(1, near.size(), "%s picks who to hit" % c.who.name) - 1]
		if c.attacks <= 0:
			return false
		c.target = t
		attack(active, t)
		c.moves = 0
		if c.attacks <= 0 or not combatants[t].down:
			c.attacks = 0
			return false
		return true
	return false

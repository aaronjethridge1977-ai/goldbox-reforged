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
## - At 0 HP or below a character drops (dying); a monster is killed.
## - The fight ends when one side has nobody standing. (QoL: when the last enemy falls the
##   battle ends at once; the original asks "Continue Battle?".)
## Every die roll goes through roll(), which uses a seedable generator and logs the roll, so
## a fight can be replayed and compared rule by rule.
##
## Not yet: guarding, missiles, spells, morale and fleeing, surprise from the encounter,
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
		return active
	active = -1
	return -1


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
	return "moved"


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
		tm.hp -= dmg
		message.emit("%s ATTACKS %s%s HITTING FOR %d" % [am.name, tm.name, how, dmg])
		if tm.hp <= 0:
			t.down = true
			message.emit("%s IS %s" % [tm.name, "KILLED" if t.team == 1 else "DOWN"])


## Ends the active combatant's turn.
func done() -> void:
	if active >= 0:
		combatants[active].moves = 0
		combatants[active].attacks = 0


# --- Computer-controlled turns ----------------------------------------------------------

func nearest_enemy(i: int) -> int:
	var c: Dictionary = combatants[i]
	var best := -1
	var best_d := 1 << 30
	for j in combatants.size():
		var o: Dictionary = combatants[j]
		if o.down or o.team == c.team:
			continue
		var d: int = maxi(absi(o.cell.x - c.cell.x), absi(o.cell.y - c.cell.y))
		if d < best_d:
			best_d = d
			best = j
	return best


## One action of a computer-controlled turn: attack an adjacent enemy, else step towards
## the nearest. Returns false when the turn is over.
func ai_act() -> bool:
	if active < 0:
		return false
	var c: Dictionary = combatants[active]
	var target := nearest_enemy(active)
	if target < 0:
		return false
	var tc: Vector2i = combatants[target].cell
	var d: int = maxi(absi(tc.x - c.cell.x), absi(tc.y - c.cell.y))
	if d == 1:
		if c.attacks <= 0:
			return false
		attack(active, target)
		return c.attacks > 0
	# Step to the free neighbour that brings us closest (straight steps preferred).
	var best_dir := -1
	var best := d
	for dir in [0, 2, 4, 6, 1, 3, 5, 7]:
		var to: Vector2i = c.cell + DIRS[dir]
		if occupant(to) >= 0 or not field.walkable(to.x, to.y):
			continue
		var cost := 3 if dir % 2 == 1 else 2
		if cost > c.moves:
			continue
		var nd: int = maxi(absi(tc.x - to.x), absi(tc.y - to.y))
		if nd < best:
			best = nd
			best_dir = dir
	if best_dir < 0:
		return false
	return step(best_dir) == "moved"

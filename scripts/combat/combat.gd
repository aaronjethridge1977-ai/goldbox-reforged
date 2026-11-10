class_name Combat
extends RefCounted
## The rules of a fight, apart from the screen: turn order, movement, melee and the end.
##
## As the original does it (rules as documented by Pilgrim's reconstruction; checked against
## the original in the test lab as each part lands):
## - Each round every combatant rolls initiative: d6 + DEX reaction adjustment, at least 1;
##   a surprised side gets -6 (0 or less: no action that round). Highest acts first, ties
##   broken at random.
## - Movement points are half-moves: twice MOVE. A step costs 2, a diagonal step 3; walls
##   and other figures block.
## - Moving into an enemy attacks it. To hit: d20 >= THAC0 - target AC; a natural 1 always
##   misses, a natural 20 always hits. Damage: weapon (or natural) dice + bonuses, at least 0.
##   Attacking ends the combatant's movement. Attacks per round come from the half-attack
##   count (3 = 1 and 2 on alternate rounds).
## - At 0 HP or below a character drops (dying); a monster is killed.
## - The fight ends when one side has nobody standing. (QoL: when the last enemy falls the
##   battle ends at once; the original asks "Continue Battle?".)
## Every die roll goes through roll(), which uses a seedable generator and logs the roll, so
## a fight can be replayed and compared rule by rule.
##
## Not yet: free attacks when stepping away from an enemy, missiles, spells, morale and
## fleeing, surprise from the encounter, large monsters filling two cells.

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
		var m: PartyMember = c.who
		c.moves = maxi(m.movement, 1) * 2
		var half: int = m.half_attacks
		if round_no % 2 == 1:
			half += 1
		c.attacks = half / 2
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


## Steps the active combatant one cell in direction `dir` (0..7, 0 = up, clockwise), or
## attacks whoever stands there. Returns "moved", "attacked", "blocked" or "no moves".
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
	if field.tile(to.x, to.y) != Battlefield.FLOOR:
		return "blocked"
	var cost := 3 if dir % 2 == 1 else 2
	if cost > c.moves:
		return "no moves"
	c.moves -= cost
	c.cell = to
	if DIRS[dir].x != 0:
		c.dir = 2 if DIRS[dir].x > 0 else 6
	return "moved"


func attack(i: int, j: int) -> void:
	var a: Dictionary = combatants[i]
	var t: Dictionary = combatants[j]
	var am: PartyMember = a.who
	var tm: PartyMember = t.who
	a.attacks -= 1
	a.moves = 0
	if t.cell.x != a.cell.x:
		a.dir = 2 if t.cell.x > a.cell.x else 6
	var d20 := roll(1, 20, "%s to hit %s (needs %d)" % [am.name, tm.name, am.thac0 - tm.ac])
	var hit := d20 != 1 and (d20 == 20 or d20 >= am.thac0 - tm.ac)
	if not hit:
		message.emit("%s ATTACKS %s AND MISSES" % [am.name, tm.name])
		return
	var dice: Array = am.damage
	var dmg := roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2])
	dmg = maxi(dmg, 0)
	tm.hp -= dmg
	message.emit("%s HITS %s FOR %d" % [am.name, tm.name, dmg])
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
		return c.attacks > 0 and not combatants[target].down
	# Step to the free neighbour that brings us closest (straight steps preferred).
	var best_dir := -1
	var best := d
	for dir in [0, 2, 4, 6, 1, 3, 5, 7]:
		var to: Vector2i = c.cell + DIRS[dir]
		if occupant(to) >= 0 or field.tile(to.x, to.y) != Battlefield.FLOOR:
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
	step(best_dir)
	return true

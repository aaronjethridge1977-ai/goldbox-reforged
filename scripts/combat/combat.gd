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
## Morale, fleeing, surrender and surprise: see the sections below and start_round().
## Large creatures fill more than one cell (see "Size" below). Spells and their effects:
## CombatSpells (helpless figures lose their turns; attacks on them slay).

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
var surprise_flags := 0      # the script's ambush flag: bit 1 the party, bit 2 the monsters
var morale_base := 99        # the encounter's morale (0x6DC6)
var flee_dir := 0            # where the monsters run: the party's facing on the grid
var enemy_health := 100      # the monsters' remaining HP, percent in fives
var types: ItemTypes = null  # for re-readying weapons (missiles, the computer's choices)
var dropped: Array[GameItem] = []   # thrown weapons left on the field (found after a win)
var magic: CombatSpells = null      # spells and their effects (when the spell table is loaded)


func _init(battlefield: Battlefield, people: Array, seed_value: int = 0) -> void:
	field = battlefield
	combatants = people
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in combatants:
		c["down"] = false
		# The computer runs monsters, NPCs (0x6BB8 128+) and members a script set to 0x80.
		c["quick"] = c.team == 1 or c.who.npc >= 128 or c.who.script_team == 0x80
		c["moves"] = 0
		c["attacks"] = 0
		c["acted"] = false
		c["received"] = 0     # attacks received since its own turn (or last step)
		c["second"] = 0       # of this round's attacks, how many are the second kind (used first)
		c["guarding"] = false # guarding until its next turn
		c["bleeding"] = 0     # points past 0 while dying
		c["target"] = -1
		c["pattern"] = 0      # the computer's movement pattern (see below)
		c["turned"] = 0       # eighth-turns of those attacks, as the original counts them
		c["fp"] = foot_size(c.who)


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


## 0 = fight on, 1 = the party won, 2 = the party lost, 3 = the party ran away (no one
## left standing, but some got off the field).
func outcome() -> int:
	if standing(1) == 0:
		return 1
	if standing(0) == 0:
		for c in combatants:
			if c.team == 0 and c.get("fled", false):
				return 3
		return 2
	return 0


func start_round() -> void:
	if round_no > 0:
		_bleed()
		if magic:
			magic.tick()
	round_no += 1
	_count_enemy_health()
	var delays := {}
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if c.down:
			continue
		var m: PartyMember = c.who
		c.moves = maxi(m.movement, 1) * 2
		c.attacks = attacks_for(m)
		c.second = (m.half_attacks_2 + (1 if round_no % 2 == 1 else 0)) / 2
		c.attacks += c.second
		c.acted = false
		if magic:
			magic.adjust_round(c)
			if CombatSpells.held(m):
				continue
		var d := roll(1, 6, "initiative %s" % m.name) + m.dex_missile_bonus()
		d = maxi(d, 1)
		if round_no == 1 and (c.team == surprised_team or ((c.team + 1) & surprise_flags) != 0):
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
			# The original's end of round: with every enemy still standing on the run, it
			# asks "CONTINUE BATTLE:" (answered by continue_battle()).
			if round_no > 0 and asked_round != round_no and enemies_all_running():
				asked_round = round_no
				return ASK_CONTINUE
			start_round()
			if order.is_empty():
				return -1
		active = order.pop_front()
		var c: Dictionary = combatants[active]
		if c.down or (magic and CombatSpells.held(c.who)):
			continue
		c.acted = true
		c.received = 0
		c.turned = 0
		c.guarding = false
		c.ai = false
		return active
	active = -1
	return -1


const ASK_CONTINUE := -2
var asked_round := -1


func enemies_all_running() -> bool:
	var any := false
	for c in combatants:
		if c.team == 1 and not c.down:
			any = true
			if not c.get("fleeing", false):
				return false
	return any


## The answer to "CONTINUE BATTLE:": no ends the fight, the runners getting away (no
## experience or treasure for them).
func continue_battle(yes: bool) -> void:
	if yes:
		return
	for c in combatants:
		if c.team == 1 and not c.down:
			c.down = true
			c.fled = true
			(c.who as PartyMember).status = PartyMember.STATUS_RUNNING


## Attacks this round with the readied weapon: half-attacks (missile weapons: the ITEMS
## table's) rounded up on odd rounds, and never more shots than are left.
func attacks_for(m: PartyMember) -> int:
	var half: int = m.half_attacks
	var shooting := m.weapon_ranged and m.missile_ready
	if shooting:
		half = m.missile_half_attacks
	if round_no % 2 == 1:
		half += 1
	var n := half / 2
	if shooting:
		n = mini(n, m.shots_left())
	return n


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


## The monsters' remaining HP as a percentage (in fives), as the original works it out
## each round for morale.
func _count_enemy_health() -> void:
	var now := 0
	var full := 0
	for c in combatants:
		if c.team != 1:
			continue
		var m: PartyMember = c.who
		if not c.down:
			now += m.hp
		full += m.hp_max
	if full > 0:
		enemy_health = (20 * now / full) * 5


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


# --- Missiles ----------------------------------------------------------------------------
# As the original does it (rules as documented by Pilgrim's reconstruction; the weapons'
# ranges, attacks and flags from Pool of Radiance's ITEMS file):
# - Distance is counted along the original's line walk: 2 per straight cell, 3 per
#   diagonal one, halved. A target needs a clear line of sight (walls block) and to be
#   within the weapon's range less 1.
# - Nobody fires a missile weapon with an enemy next to them, unless the weapon can also be
#   used in melee (axes, spears): then an adjacent target is simply hit with it.
# - Beyond a third of the range the target counts 2 better in AC, beyond two thirds 5.
# - Each shot uses one arrow, quarrel or thrown weapon; a thrown axe or spear lands on the
#   field and is found after a win, darts and arrows are gone.

## Steps (2 straight, 3 diagonal) along the line from a to b, and whether walls allow it.
func line_steps(a: Vector2i, b: Vector2i, walls: bool = true) -> Vector2i:
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := signi(b.x - a.x)
	var sy := signi(b.y - a.y)
	var cur := a
	var err := 0
	var steps := 0
	while true:
		if walls and not field.walkable(cur.x, cur.y):
			return Vector2i(steps, 0)
		if cur == b:
			return Vector2i(steps, 1)
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
	return Vector2i(steps, 0)


## Range in squares, as the original reports it ("RANGE = n").
func range_between(a: Vector2i, b: Vector2i) -> int:
	return line_steps(a, b, false).x / 2


## The line between two combatants, over every pair of their cells: the shortest clear
## one (steps, 1), or if none is clear, the shortest (steps, 0).
func clear_line(a: Dictionary, b: Dictionary) -> Vector2i:
	var best := Vector2i(1 << 30, 0)
	for p in cells(a):
		for q in cells(b):
			var l := line_steps(p, q)
			var steps := line_steps(p, q, false).x
			if l.y == 1 and (best.y == 0 or steps < best.x):
				best = Vector2i(steps, 1)
			elif l.y == 0 and best.y == 0 and steps < best.x:
				best = Vector2i(steps, 0)
	return best


func enemy_adjacent(i: int) -> bool:
	var c: Dictionary = combatants[i]
	for j in combatants.size():
		if _enemy_of(c, j) and touching(c, combatants[j]):
			return true
	return false


## Can combatant i shoot j with its readied missile weapon? "" if so, else why not.
func why_not_shoot(i: int, j: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if not m.weapon_ranged:
		return "NO MISSILE WEAPON READY"
	if not m.missile_ready:
		return "OUT OF AMMUNITION"
	if c.attacks <= 0:
		return "NO ATTACKS LEFT"
	if not _enemy_of(c, j):
		return "NOT AN ENEMY"
	if enemy_adjacent(i) and not m.weapon_ranged_melee:
		return "CAN'T FIRE WITH AN ENEMY NEXT TO YOU"
	var line := clear_line(c, combatants[j])
	if line.y == 0:
		return "NO CLEAR SHOT"
	if line.x / 2 > m.missile_range:
		return "OUT OF RANGE"
	return ""


## Combatant i shoots j with all its attacks left (stopping when j falls or the
## ammunition runs out). An adjacent target of a melee-capable missile weapon is hit
## hand to hand instead.
func shoot(i: int, j: int) -> void:
	var a: Dictionary = combatants[i]
	var t: Dictionary = combatants[j]
	var am: PartyMember = a.who
	var tm: PartyMember = t.who
	if am.weapon_ranged_melee and touching(a, t):
		attack(i, j)
		return
	_note_attack(a, t)
	var behind: bool = t.received > 1 and dir_between(a, t) == t.dir and t.turned > 4
	if t.received < 2:
		t.dir = dir_between(t, a)
	a.dir = dir_between(a, t)
	a.moves = 0
	var reach: int = range_of(a, t)
	var third: int = (am.missile_range) / 3
	var penalty := 0
	if reach > third:
		reach -= third
		penalty += 2
	if reach > third:
		penalty += 3
	var ac: int = (tm.rear_ac if behind else tm.ac) + penalty
	var bonus := 0
	if magic:
		magic.reveal(am)
		ac = magic.armour(tm, (tm.rear_ac if behind else tm.ac)) + penalty
		bonus = magic.hit_bonus(am, tm)
	var how := " (FROM BEHIND)" if behind else ""
	while a.attacks > 0 and not t.down and am.shots_left() > 0:
		a.attacks -= 1
		var gone := am.use_shot()
		if gone != null and types != null:
			if (types.flags(gone.type) & 0x14) == 0x14:
				var copy := gone.copy()
				copy.name = gone.name
				dropped.append(copy)
		if magic and magic.image_takes_it(tm):
			continue
		var need: int = am.thac0 - ac - bonus
		need -= SpecialAffects.hit_bonus(am, tm)
		var d20 := roll(1, 20, "%s shoots %s%s (needs %d)" % [am.name, tm.name, how.to_lower(), need])
		var hit := d20 != 1 and (d20 == 20 or d20 >= need)
		if not hit:
			message.emit("%s ATTACKS %s%s AND MISSES" % [am.name, tm.name, how])
		else:
			var dice: Array = am.damage_large if tm.is_large() else am.damage
			var dmg := maxi(roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2]), 0)
			dmg = SpecialAffects.weapon_damage(am, tm, am.readied_weapon(types), types, dmg)
			if dmg == 0 and tm.has_affect(0x77):
				message.emit("%s ATTACKS %s%s AND MISSES" % [am.name, tm.name, how])
			else:
				message.emit("%s ATTACKS %s%s HITTING FOR %d" % [am.name, tm.name, how, dmg])
				_hurt(j, dmg)
		if gone != null and types != null:
			am.recalculate(types)
	if not am.missile_ready or am.shots_left() <= 0:
		a.attacks = 0


# --- The computer's choice of weapon -----------------------------------------------------
# As the original does it at the start of each computer-run turn (rules as documented by
# Pilgrim's reconstruction): every weapon the combatant may use (its class bits, record
# 0xB0) is rated: dice count x size, + 8 per plus, + 2 per point of damage bonus, + 2 per
# extra missile attack for a launcher, + 3 if one-handed; cursed ones count 0. The best
# missile weapon (thrown or launcher) is readied if it rates over half the best melee
# weapon (or bare hands), has its ammunition, and either no enemy is adjacent or it can
# also be used in melee; otherwise the best melee weapon (none: bare hands). A two-handed
# weapon puts the shield away; a one-handed one takes it up again. (The lab saw this:
# Phineas on Quick switches between his dagger and his darts; a kobold readies its sword.)

func _rate(m: PartyMember, it: GameItem) -> int:
	if it.cursed:
		return 0
	var dmg := types.damage(it.type, false)
	var r: int = dmg[0] * dmg[1]
	if it.plus > 0:
		r += it.plus * 8
	if dmg[2] > 0:
		r += dmg[2] * 2
	if types.flags(it.type) & ItemTypes.FLAG_LAUNCHER:
		r += (maxi(types.half_attacks(it.type), 2) / 2 - 1) * 2
	if types.hands(it.type) <= 1:
		r += 3
	return r


func choose_weapon(i: int) -> void:
	if types == null:
		return
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if m.weapon != null and m.weapon.cursed:
		return
	var bare: int = m.base_damage[0] * m.base_damage[1] + maxi(int(m.base_damage[2]), 0) * 2
	var best_melee: GameItem = null
	var melee_rate := bare
	var best_missile: GameItem = null
	var missile_rate := 1
	for it in m.items:
		if not types.has(it.type) or types.slot(it.type) != ItemTypes.SLOT_WEAPON:
			continue
		if (types.class_flags(it.type) & m.class_flags) == 0:
			continue
		var f := types.flags(it.type)
		var r := _rate(m, it)
		if f & (ItemTypes.FLAG_LAUNCHER | ItemTypes.FLAG_THROWN):
			if r > missile_rate:
				best_missile = it
				missile_rate = r
		if (f & ItemTypes.FLAG_LAUNCHER) == 0 and r > melee_rate:
			best_melee = it
			melee_rate = r
	var pick := best_melee
	if best_missile != null and missile_rate > melee_rate / 2:
		var f := types.flags(best_missile.type)
		var has_ammo := (f & ItemTypes.FLAG_THROWN) != 0 or f == 0x0A
		if f & ItemTypes.FLAG_LAUNCHER and not has_ammo:
			var want := ItemTypes.TYPE_ARROW if f & ItemTypes.FLAG_ARROWS else ItemTypes.TYPE_QUARREL
			for it in m.items:
				if it.readied and it.type == want:
					has_ammo = true
		var melee_too := (f & 0x14) == 0x14
		if has_ammo and (melee_too or not enemy_adjacent(i)):
			pick = best_missile
	if pick == m.weapon:
		return
	if m.weapon != null:
		m.weapon.readied = false
	var shield: GameItem = null
	for it in m.items:
		if types.has(it.type) and types.slot(it.type) == ItemTypes.SLOT_SHIELD:
			if shield == null or it.readied:
				shield = it
	if pick != null:
		pick.readied = true
		if shield != null:
			shield.readied = types.hands(pick.type) <= 1 and (types.class_flags(shield.type) & m.class_flags) != 0
	m.recalculate(types)
	if c.attacks > 0:
		c.attacks = attacks_for(m)
		c.second = (m.half_attacks_2 + (1 if round_no % 2 == 1 else 0)) / 2
		c.attacks += c.second


## Applies damage the way the original does (see "Going down" above).
func hurt(j: int, dmg: int) -> void:
	_hurt(j, dmg)


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
		if c.team == 0 and m.status == PartyMember.STATUS_RUNNING:
			m.status = PartyMember.STATUS_OKAY
		c.bleeding = 0


# --- Actions ----------------------------------------------------------------------------

# --- Size ---------------------------------------------------------------------------------
# As the original does it (rules as documented by Pilgrim's reconstruction; sizes and icon
# shapes read from Pool of Radiance's MON*CHA and CPIC files): the low 3 bits of record
# byte 0x6C give the cells a combatant fills, counted from its own cell (top left):
# 1 = one cell; 2 = that cell and the one below (24x48 icons: ogres, trolls, giants,
# minotaurs, gnolls); 3 = that cell and the one to the right (48x24: scorpions, snakes,
# centaurs, boars); 4 = a 2x2 block (48x48: wyverns, Tyranithraxus).
# - Placement: every cell of the footprint must be bare floor and free.
# - Moving: every cell of the moved footprint must be walkable; anyone found in it (other
#   than the mover) blocks the step, or is attacked if an enemy.
# - Distance, adjacency, sight and direction between two combatants use their closest
#   pair of cells.
const FOOTPRINT := [[], [Vector2i(0, 0)], [Vector2i(0, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]


static func foot_size(m: PartyMember) -> int:
	return clampi(m.size & 7, 1, 4)


static func cells_at(at: Vector2i, fp: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in FOOTPRINT[clampi(fp, 1, 4)]:
		out.append(at + d)
	return out


func cells(c: Dictionary) -> Array[Vector2i]:
	return cells_at(c.cell, int(c.get("fp", 1)))


func occupant(cell: Vector2i, ignore: int = -1) -> int:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if i != ignore and not c.down and cell in cells(c):
			return i
	return -1


## Can combatant i stand with its top-left cell at `at`? Returns [ok, who's in the way]:
## ok is false if a cell is not walkable or someone else is there (who = their index).
func fits(i: int, at: Vector2i) -> Array:
	var who := -1
	var ok := true
	for p in cells_at(at, int(combatants[i].get("fp", 1))):
		var o := occupant(p, i)
		if o >= 0:
			who = o
			ok = false
		elif not field.walkable(p.x, p.y):
			ok = false
	return [ok, who]


## The closest pair of cells between combatants a and b (by range): [a's cell, b's cell].
func closest(a: Dictionary, b: Dictionary, a_at = null) -> Array:
	var ac: Array[Vector2i] = cells_at(a.cell if a_at == null else a_at, int(a.get("fp", 1)))
	var best := [ac[0], b.cell]
	var best_r := 1 << 30
	for p in ac:
		for q in cells(b):
			var r := line_steps(p, q, false).x
			if r < best_r:
				best_r = r
				best = [p, q]
	return best


## Are combatants a and b next to each other (a optionally at another cell)?
func touching(a: Dictionary, b: Dictionary, a_at = null) -> bool:
	var ac: Array[Vector2i] = cells_at(a.cell if a_at == null else a_at, int(a.get("fp", 1)))
	for p in ac:
		for q in cells(b):
			if adjacent(p, q):
				return true
	return false


## Direction from a to b, from their closest cells.
func dir_between(a: Dictionary, b: Dictionary) -> int:
	var pr := closest(a, b)
	return dir_to(pr[0], pr[1])


## Range from a to b in squares, from their closest cells.
func range_of(a: Dictionary, b: Dictionary) -> int:
	var pr := closest(a, b)
	return range_between(pr[0], pr[1])


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
	var fit := fits(active, to)
	var other: int = fit[1]
	if other >= 0:
		if combatants[other].team == c.team or c.attacks <= 0:
			return "blocked"
		attack(active, other)
		return "attacked"
	if not fit[0]:
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
		if e.down or e.team == c.team or not e.guarding or not touching(e, c):
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
		if e.down or e.team == c.team or not touching(e, c) or touching(c, e, to):
			continue
		var off := (dir_between(e, c) - int(e.dir) + 8) % 8
		var seen := off <= 2 or off >= 6    # not one of the three cells at its back
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
	var diff := (dir_between(t, a) - int(t.dir) + 8) % 8
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
		if t.received > 1 and dir_between(a, t) == t.dir and t.turned > 4:
			behind = true
		if t.received < 2:
			t.dir = dir_between(t, a)
	a.dir = dir_between(a, t)
	a.moves = 0
	var stab := not free and _can_backstab(a, t)
	var ac: int = tm.rear_ac if behind else tm.ac
	if stab:
		ac = tm.rear_ac + 4
	var bonus := 0
	if magic:
		magic.reveal(am)
		ac = magic.armour(tm, ac)
		bonus = magic.hit_bonus(am, tm)
		if CombatSpells.held(tm):
			a.attacks = 0
			message.emit("%s SLAYS HELPLESS %s WITH ONE CRUEL BLOW" % [am.name, tm.name])
			_hurt(j, tm.hp + 5)
			return
	var how := " (FROM BEHIND)" if behind and not stab else ""
	var verb := "BACKSTABS" if stab else "ATTACKS"
	while a.attacks > 0 and not t.down:
		a.attacks -= 1
		var second: bool = int(a.get("second", 0)) > 0
		if second:
			a.second -= 1
		if magic and magic.image_takes_it(tm):
			continue
		var need: int = am.thac0 - ac - bonus - SpecialAffects.hit_bonus(am, tm)
		var d20 := roll(1, 20, "%s to hit %s%s (needs %d)" % [am.name, tm.name, how.to_lower(), need])
		var hit := d20 != 1 and (d20 == 20 or d20 >= need)
		if not hit:
			message.emit("%s %s %s%s AND MISSES" % [am.name, verb, tm.name, how])
			continue
		var dice: Array = am.base_damage_2 if second else (am.damage_large if tm.is_large() else am.damage)
		var dmg := roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2])
		dmg = maxi(dmg, 0)
		if stab:
			dmg *= (am.thief_level() - 1) / 4 + 2
		if magic:
			dmg = magic.damage_after(am, dmg)
		dmg = SpecialAffects.weapon_damage(am, tm, am.readied_weapon(types), types, dmg)
		if dmg == 0 and tm.has_affect(0x77):
			# Only magic hurts it: the original reports the blow as a miss (lab: a party with
			# THAC0 1 "ATTACKS FERRAN MARTINEZ AND MISSES" round after round).
			message.emit("%s %s %s%s AND MISSES" % [am.name, verb, tm.name, how])
			continue
		message.emit("%s %s %s%s HITTING FOR %d" % [am.name, verb, tm.name, how, dmg])
		_hurt(j, dmg)
		if not t.down:
			_on_hit_specials(i, j)


## What a hit does besides damage, from the attacker's standing effects (SpecialAffects):
## poison, paralysis, level drain.
func _on_hit_specials(i: int, j: int) -> void:
	var am: PartyMember = combatants[i].who
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	if t.down:
		return
	for type in SpecialAffects.POISON_BONUS:
		if am.has_affect(type) and not t.down:
			if SpecialAffects.blocks(tm, SpecialAffects.POISONED, func(): return roll(1, 100, "resists")):
				continue
			if not _save(tm, 0, int(SpecialAffects.POISON_BONUS[type])):
				message.emit("%s IS POISONED" % tm.name)
				SpellCaster.add_affect(tm, SpecialAffects.POISONED, 0, 0, 0)
				tm.hp = 0
				tm.status = PartyMember.STATUS_DEAD
				t.down = true
				message.emit("%s IS KILLED" % tm.name)
	var paralysis := 0
	if am.has_affect(0x43):
		paralysis = roll(2, 8, "paralysis rounds")
	if am.has_affect(0x44) and tm.race_id != 2:
		paralysis = 63
	if paralysis > 0 and not t.down and not CombatSpells.held(tm) \
			and not SpecialAffects.blocks(tm, SpecialAffects.PARALYZED, func(): return roll(1, 100, "resists")) \
			and not _save(tm, 0, 0):
		message.emit("%s IS PARALYZED" % tm.name)
		SpellCaster.add_affect(tm, SpecialAffects.PARALYZED, 0, paralysis, 12)
	for type in [0x55, 0x56]:
		if am.has_affect(type) and not t.down:
			drain(j, 1 if type == 0x55 else 2)
	if am.has_affect(0x4F) and not t.down:
		# Tyranthraxus's fiery blows (handler at GAME.OVR 0x10674): 2d10 more, as fire.
		var burn := SpecialAffects.element_damage(tm, 1, roll(2, 10, "fire"))
		if burn > 0:
			message.emit("%s TAKES %d POINTS OF DAMAGE" % [tm.name, burn])
			_hurt(j, burn)


func _save(m: PartyMember, kind: int, bonus: int) -> bool:
	if magic:
		return magic.save(m, kind, bonus, null)
	var d := roll(1, 20, "%s saves" % m.name)
	return d != 1 and (d == 20 or d + bonus + SpecialAffects.save_bonus(m, kind) >= (m.saves[kind] if kind < m.saves.size() else 20))


## Level drain as GAME.OVR does it (overlay 0x10D7D): "<NAME> IS DRAINED A LEVEL" (or
## " 2 LEVELS"); for each level the HP lost is max HP / total levels (max, rolled and
## current HP all drop), and the highest class loses a level; someone with fewer than two
## levels left "IS DEAD FOREVER".
func drain(j: int, levels: int) -> void:
	var t: Dictionary = combatants[j]
	var m: PartyMember = t.who
	message.emit("%s IS DRAINED %s" % [m.name, "A LEVEL" if levels == 1 else "%d LEVELS" % levels])
	for k in levels:
		var total := 0
		var top := -1
		for c in 8:
			total += m.level_in(c)
			if top < 0 or m.level_in(c) > m.level_in(top):
				top = c
		if total < 2:
			m.hp = 0
			m.hp_max = 0
			m.status = 8      # GONE
			t.down = true
			message.emit("%s IS DEAD FOREVER" % m.name)
			return
		var per := m.hp_max / total
		m.hp_max = maxi(m.hp_max - per, 0)
		m.hp_rolled = maxi(m.hp_rolled - per, 0)
		m.hp = maxi(m.hp - per, 0)
		m.set_level(top, m.level_in(top) - 1)
		if m.hp == 0:
			m.status = PartyMember.STATUS_DEAD
			t.down = true
			message.emit("%s IS KILLED" % m.name)
			return


## A thief's backstab (as the original): a thief with no weapon or a club, dagger or sword
## strikes a man-sized target from directly behind after it has been attacked more than
## once this round: +4 to hit and damage x2 (levels 1-4), x3 (5-8)...
const BACKSTAB_WEAPONS := [7, 8, 35, 36, 37, 97]

func _can_backstab(a: Dictionary, t: Dictionary) -> bool:
	var am: PartyMember = a.who
	var tm: PartyMember = t.who
	if am.thief_level() <= 0 or (tm.size & 0x7F) > 1:
		return false
	if am.weapon != null and not am.weapon.type in BACKSTAB_WEAPONS:
		return false
	return int(t.received) > 1 and dir_between(a, t) == int(t.dir)


## Ends the active combatant's turn.
func done() -> void:
	if active >= 0:
		combatants[active].moves = 0
		combatants[active].attacks = 0
		combatants[active].second = 0


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


## Is j within `reach` squares of i with a clear line (1 = adjacent)?
func _within(i: int, j: int, reach: int) -> bool:
	if reach <= 1:
		return touching(combatants[i], combatants[j])
	var line := clear_line(combatants[i], combatants[j])
	return line.y == 1 and line.x / 2 <= reach


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
			if clear_line(c, combatants[j]).y == 1:
				seen.append(j)
	var pool := seen if not seen.is_empty() else all
	if pool.is_empty():
		return false
	c.target = pool[roll(1, pool.size(), "%s picks a target" % c.who.name) - 1]
	return true


## Ends combatant `i`'s turn on guard, keeping its unused attacks for a guard attack.
func guard(i: int, computer: bool = true) -> void:
	var c: Dictionary = combatants[i]
	c.moves = 0
	if computer and (c.who as PartyMember).weapon_ranged:
		# With a missile weapon the original just ends the turn: no guard.
		c.attacks = 0
		return
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


# --- Turning undead ----------------------------------------------------------------------
# Clerics, and paladins from 3rd level as a cleric two levels lower, can try once a fight
# (TURN on the fight menu; quick clerics do it when undead are in sight). The undead's
# kind is record byte 0x76 (1 skeleton, 2 zombie, 3 ghoul, 5 wight, 7 wraith, 8 mummy,
# 9 spectre, 10 vampire: the rule book's turning table order) and undead have 0x9F = 4.
# One d20 against the table for the turner's level; 2d6 undead are affected, the weakest
# first: turned ones run for the rest of the fight, destroyed ones are gone. The table is
# the AD&D one the rule book prints; the original's own code is not yet traced.
const T := -1
const D := -2
const TURN_TABLE := [
	[10, 13, 16, 19, 20, 0, 0, 0, 0, 0, 0, 0, 0],
	[7, 10, 13, 16, 19, 20, 0, 0, 0, 0, 0, 0, 0],
	[4, 7, 10, 13, 16, 19, 20, 0, 0, 0, 0, 0, 0],
	[T, 4, 7, 10, 13, 16, 19, 20, 0, 0, 0, 0, 0],
	[T, T, 4, 7, 10, 13, 16, 19, 20, 0, 0, 0, 0],
	[D, T, T, 4, 7, 10, 13, 16, 19, 20, 0, 0, 0],
	[D, D, T, T, 4, 7, 10, 13, 16, 19, 20, 0, 0],
	[D, D, D, T, T, 4, 7, 10, 13, 16, 19, 20, 0],
	[D, D, D, D, T, T, 4, 7, 10, 13, 16, 19, 20]]


static func turn_level(m: PartyMember) -> int:
	if m == null or m.is_monster:
		return 0
	return maxi(m.level_in(0), m.level_in(3) - 2)


static func is_undead(m: PartyMember) -> bool:
	return m.raw.size() > 0x9F and m.raw[0x9F] == 4


func _undead_in_sight(i: int) -> Array[int]:
	var out: Array[int] = []
	for j in combatants.size():
		var e: Dictionary = combatants[j]
		if _enemy_of(combatants[i], j) and not e.get("turned_undead", false) and is_undead(e.who) \
				and can_see(combatants[i].cell, e.cell):
			out.append(j)
	return out


func can_turn(i: int) -> bool:
	var c: Dictionary = combatants[i]
	return turn_level(c.who) > 0 and not c.get("tried_turning", false) and not _undead_in_sight(i).is_empty()


func turn_undead(i: int) -> void:
	var c: Dictionary = combatants[i]
	c.tried_turning = true
	var undead := _undead_in_sight(i)
	undead.sort_custom(func(a, b): return combatants[a].who.raw[0x76] < combatants[b].who.raw[0x76])
	var row: Array = TURN_TABLE[clampi(turn_level(c.who), 1, 9) - 1]
	var d20 := roll(1, 20, "%s turns undead" % c.who.name)
	var count := roll(2, 6, "how many undead")
	var any := false
	for j in undead:
		if count <= 0:
			break
		var e: Dictionary = combatants[j]
		var need: int = row[clampi(int(e.who.raw[0x76]), 1, 13) - 1]
		if need == 0 or (need > 0 and d20 < need):
			continue
		count -= 1
		any = true
		if need == D:
			e.down = true
			(e.who as PartyMember).hp = 0
			(e.who as PartyMember).status = PartyMember.STATUS_DEAD
			message.emit("%s IS DESTROYED" % e.who.name)
		else:
			e.turned_undead = true
			e.fleeing = true
			message.emit("%s IS TURNED" % e.who.name)
	if not any:
		message.emit("NOTHING HAPPENS...")   # the original's line (lab: a turn at Ferran Martinez)
	c.moves = 0
	c.attacks = 0


# --- Morale, fleeing and surrender -------------------------------------------------------
# As the original does it (rules as documented by Pilgrim's reconstruction; names of the
# script variables from ssi-engine; "KOBOLD SURRENDERS" seen in the lab):
# - Each computer-run monster checks its morale at the start of its turn. Its morale is
#   the low 7 bits of record byte 0x84 doubled (over 102 counts as 0). If that is below
#   the share of its own HP it has lost (or 0), the side's morale is tried: the monsters'
#   remaining HP percentage against 100 - the encounter's morale (0x6DC6; the scripts use
#   99 for steady foes, 60 for skittish ones).
# - Failing both, it runs if no party member moves faster than it ("FLEES IN PANIC"),
#   otherwise surrenders if its INT is over 5 ("SURRENDERS": out of the fight, beaten).
# - Running: its whole turn goes into steps away from the party (the direction the party
#   faces, by a random one of the first two movement patterns). Reaching the edge of the
#   field it gets away ("GOT AWAY": no experience, no loot) if faster than every party
#   member, or on an even roll if as fast; otherwise "ESCAPE IS BLOCKED" and it stops
#   running. Out of movement, it fights whatever is next to it.

func _fastest(team: int) -> int:
	var best := 0
	for c in combatants:
		if c.team == team and not c.down:
			best = maxi(best, (c.who as PartyMember).movement)
	return best


## The morale check (see above). Returns "", "flee" or "surrender".
func _morale_check(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if c.team != 1 or m.morale < 0x80 or m.hp_max <= 0:
		return ""
	var own := (m.morale & 0x7F) * 2
	if own > 102:
		own = 0
	var lost := 100 - (m.hp * 100) / m.hp_max
	if not (own < lost or own == 0):
		return ""
	if not (enemy_health < 100 - morale_base or enemy_health == 0):
		return ""
	if _fastest(0) <= m.movement:
		return "flee"
	if m.stats.size() > 1 and m.stats[1] > 5:
		return "surrender"
	return ""


## One step of a running combatant. Returns "moved", "gone" or "stop".
func _flee_step(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if c.moves / 2 <= 0:
		return "stop"
	var base := flee_dir if c.team == 1 else (flee_dir + 4) % 8
	var turns: Array = PATTERN_TURNS[roll(1, 2, "%s runs" % m.name)]
	for k in 5:
		var dir := (base + int(turns[k])) % 8
		var off_field := false
		for p in cells_at(c.cell + DIRS[dir], int(c.fp)):
			if not field.in_bounds(p.x, p.y):
				off_field = true
		if off_field:
			if _gets_away(i):
				return "gone"
			c.fleeing = false
			c.moves = 0
			return "blocked"
		if _can_step(c, dir):
			return "moved" if step(dir) == "moved" else "stop"
	c.moves = 0
	return "stop"


func _gets_away(i: int) -> bool:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	var foes := _fastest(1 - c.team)
	var away := standing(1 - c.team) == 0 or foes < m.movement
	if not away and foes == m.movement:
		away = roll(1, 2, "%s gets away?" % m.name) == 1
	if away:
		c.down = true
		c.fled = true
		m.status = PartyMember.STATUS_RUNNING
		message.emit("%s GOT AWAY" % m.name)
	else:
		message.emit("ESCAPE IS BLOCKED")
	return away


## Could the computer step in direction `dir`? It needs more movement left than the cost.
func _can_step(c: Dictionary, dir: int) -> bool:
	var fit := fits(combatants.find(c), c.cell + DIRS[dir])
	if not fit[0]:
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
	var base := dir_between(c, combatants[c.target])
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
		choose_weapon(active)
		var morale := _morale_check(active)
		if morale == "surrender":
			var sm: PartyMember = c.who
			c.down = true
			sm.status = PartyMember.STATUS_UNCONSCIOUS
			sm.hp = 0
			message.emit("%s SURRENDERS" % sm.name)
			return false
		c.fleeing = morale == "flee" or c.get("turned_undead", false)
		if c.get("turned_undead", false):
			pass
		elif c.team == 0 and can_turn(active):
			turn_undead(active)
			return false
		elif c.fleeing:
			message.emit("%s FLEES IN PANIC" % c.who.name)
		elif magic and magic.ai_cast(active):
			return false
		if not find_target(active):
			guard(active)
			return false
	if c.get("fleeing", false):
		var fr := _flee_step(active)
		if fr == "moved":
			return true
		c.fleeing = false
		if fr == "gone" or fr == "blocked" or c.down:
			c.moves = 0
			c.attacks = 0
			return false
	while true:
		c.tries += 1
		if c.tries > 20 or c.down:
			guard(active)
			return false
		var m: PartyMember = c.who
		var shooting: bool = m.weapon_ranged and m.missile_ready
		var reach: int = m.missile_range if shooting else 1
		var t: int = c.get("target", -1)
		if not _enemy_of(c, t) or combatants[t].team == 0 or not _within(active, t, reach):
			t = -1
		if t < 0:
			var near: Array[int] = []
			for j in combatants.size():
				if _enemy_of(c, j) and _within(active, j, reach):
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
			if shooting and not m.weapon_ranged_melee and enemy_adjacent(active):
				# Someone is next to it: it changes weapons, and that is its turn.
				choose_weapon(active)
				c.moves = 0
				c.attacks = 0
				return false
		if c.attacks <= 0:
			return false
		c.target = t
		if shooting:
			shoot(active, t)
		else:
			attack(active, t)
		c.moves = 0
		if c.attacks <= 0 or not combatants[t].down:
			c.attacks = 0
			return false
		return true
	return false

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
##   (The original's QUICK doesn't bandage; the lab bot does, as a player.) The original offers it under
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
# A script's modifiers for the next fight (ECL 0x6E70 monsters' to-hit, 0x6E71 the party's
# to-hit, 0x6E72 the party's movement; signed bytes, zeroed after every COMBAT). The kobold
# caves' traps write +2 / -2 / -4 (8:13: "A NET ENTANGLES YOU"), the lizard men's swamp -4.
# GAME.OVR: the to-hit roll 0x2BBF2 (d20 + 0x6E71 for a party figure, 0x6E70 for a monster,
# a natural 20 always hits), each round's movement 0x1291E.
var monster_hit_mod := 0
var party_hit_mod := 0
var party_move_mod := 0
var flee_dir := 0            # where the monsters run: the party's facing on the grid
var enemy_health := 100      # the monsters' remaining HP, percent in fives
var types: ItemTypes = null  # for re-readying weapons (missiles, the computer's choices)
var dropped: Array[GameItem] = []   # thrown weapons left on the field (found after a win)
var magic_on := false                # Alt-M: the party's QUICK members cast (the original's DS:0x6E30)
## Lab (Combat Chat 25): `magicat=<draw>` turns MAGIC ON at the first computer turn opening at or
## after that draw: a replay's Alt-M lands in the original when its harness's key arrives, a real-time
## matter (p18b7: read after CEDRIC's weighing at draw 989, not at the turn it was sent).
## Combat Chat 26: a queue, in draw order, so a replay can send every fight's key before the fights
## (ours plays in real time: a key sent at the Alt-M's place could reach ours after its draw, p19d1).
static var magic_at_draws: Array[int] = []
## The anti-magic shell (ECL 0x49E5 above 0, the ruined castle's): in a fight the original hides CAST on the menu
## (GAME.OVR 0x9F59) and USE in the item list (0x21FD6), and computer-run figures use no items (0xAFF6); their
## spells (0xB105) are not stopped.
var anti_magic := false
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
		(c.who as PartyMember).refresh_load_word()     # the fight's setup (GAME.OVR 0xD8DA): the cached load
		# The computer runs monsters, NPCs (0x6BB8 128+) and members a script set to 0x80.
		c["quick"] = c.team == 1 or c.who.npc >= 128 or c.who.script_team == 0x80 or record_quick(c.who)
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
		c["last_kind"] = 0    # damage type of the last blow taken (SpecialAffects.FIRE...)
		c["regen_in"] = 0     # rounds until a troll starts regenerating (0x65)
		c["revive_in"] = 0    # rounds until a downed troll gets up (0x64)
		c["dies_in"] = 0      # rounds until a wild boar falls dead (0x63)
		c["first_miss"] = false   # Tyranthraxus's one free miss used (0x59)
	_setup_free_miss()


func roll(count: int, size: int, why: String) -> int:
	var total := 0
	for i in count:
		total += (TpDice.random(size, why) + 1) if TpDice.on else rng.randi_range(1, size)
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
	# Every enemy dead or gone: the fight ends at once (QoL, decided 2026-11-10). With some
	# only down (dying, unconscious) the original plays out the round and then asks
	# CONTINUE BATTLE (next_turn; checked roll for roll in the lab, 2026-11-14); NO wins.
	if standing(1) == 0 and (decided or (enemies_all_gone() and not lab_play_out())):
		return 1
	if standing(0) == 0:
		for c in combatants:
			if c.team == 0 and c.get("fled", false):
				return 3
		# With the whole party down the original also plays out the round before the fight is
		# lost (lab, Combat Chat 2: 7:23, the party held by Yarash's wand, the last one slain,
		# then the round's remaining turns and picks, 29 draws).
		if not order.is_empty():
			return 0
		return 2
	return 0


## The fight was ended by NO at CONTINUE BATTLE.
var decided := false


## Lab (Combat Chat 25): with GBR_PLAYOUT=1 in the environment a fight whose enemies are all dead or
## gone plays out its round and asks CONTINUE BATTLE, as the original does, instead of ending at once
## (the QoL rule above): segment replays of the original's runs go on past such fights.
static func lab_play_out() -> bool:
	return OS.has_environment("GBR_PLAYOUT")


## No enemy left on the field alive: each is dead or got away.
func enemies_all_gone() -> bool:
	for c in combatants:
		if c.team == 1 and not (c.get("fled", false) or (c.who as PartyMember).status == PartyMember.STATUS_DEAD):
			return false
		# A troll down with its rounds still running gets up again (0x64's 3d6 rounds): not gone, so the QoL
		# end at once doesn't apply (Combat Chat 34, the spell lab's Hold Person on 2:20's trolls: the original
		# fought on and the trolls rose; ours ended the fight with THE PARTY WINS).
		if c.team == 1 and not c.get("fled", false) and int(c.get("revive_in", 0)) > 0:
			return false
	return true


## The original's end of round (GAME.OVR 0xA087): the effects' clocks (0x241A1), then each
## figure's bleeding, before the enemies are counted for CONTINUE BATTLE (0xA139). Once a round.
## (Combat Chat 10, Player 8's 2:20 0,14 seed 2468ace1: a troll whose 3d6 rounds ran out stood
## up at that round's end and the fight went on, where ours asked CONTINUE BATTLE first.)
func _end_round() -> void:
	if round_no <= 0 or ended_round == round_no:
		return
	ended_round = round_no
	_bleed()
	if magic:
		magic.tick()
	_power_timers()
	# Then the round counter (DS:0x6DE3), the enemies' health (0x15074) and, for each figure,
	# affect category 0x13: a troll's regeneration (0x62, 0x1135B), so after the count.
	# (Combat Chat 29: ours regenerated at the next round's start; the troll fight seed 98e616ec,
	# the original's troll 21 HP at draw 2972 where ours' had 24.)
	_count_enemy_health()
	_regenerate()
	if magic:
		magic.cloud_round()      # each figure in a Stinking Cloud saves (GAME.OVR 0xA0CE, after category 0x13)


func start_round() -> void:
	if round_no > 0:
		_end_round()
	else:
		_battle_start_powers()
		_count_enemy_health()     # the fight's setup (GAME.OVR 0xE550)
	round_no += 1
	_round_start_powers()
	var delays := {}
	for c in combatants:
		c["init"] = 0
		# Each round (GAME.OVR 0x127FB, for every figure): a spell still being cast is
		# dropped (not forgotten), and a wounded figure may cast again.
		c["pending"] = {}
		c["no_spells"] = false
		c["no_items"] = false      # combat byte +2 (Combat Chat 33: the cough clears it)
		c.erase("kept_attacks")
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if c.down:
			continue
		var m: PartyMember = c.who
		c.moves = _round_movement(m) * 2
		c.attacks = attacks_for(m)
		c.second = second_for(m)
		c.attacks += c.second
		c.acted = false
		if magic:
			magic.adjust_round(c)
		# A held figure still draws its initiative (GAME.OVR 0x1289F tests only record +0x10d,
		# the figure in the fight; lab, Combat Chat 2: Brother Sean paralysed by Yarash's wand
		# in 7:23) and is picked in the turn order (next_turn passes it by).
		var d := roll(1, 6, "initiative %s" % m.name) + m.dex_missile_bonus()
		d = maxi(d, 1)
		if round_no == 1 and (c.team == surprised_team or ((c.team + 1) & surprise_flags) != 0):
			d -= 6
		if d <= 0 or d > 20:
			continue
		c["init"] = d
		delays[i] = d
	order.clear()
	for i in delays.keys():
		order.append(i)
	order.sort_custom(func(a, b): return delays[a] > delays[b])
	# next_turn picks from "init" itself (_pick_next); order only says the round has
	# someone left to act. (The original's rule in all play since 2026-11-14, Jeremy's A1;
	# before, only with the lab dice.)
	message.emit("ROUND %d" % round_no)


## Advances to the next combatant who can act; starts new rounds as needed.
## Returns their index, or -1 if the fight is over.
func next_turn() -> int:
	while outcome() == 0:
		if order.is_empty():
			# The original's end of round (GAME.OVR 0xA163): with no enemy left in the fight
			# (START.EXE 0xBA:0x23DB counts record +0x10D, which falling and getting away clear,
			# running doesn't), it asks "CONTINUE BATTLE:" (answered by continue_battle()). YES
			# plays another round. (Combat Chat 8: ours also asked when every enemy standing was
			# on the run; Tyranthraxus, his morale failed, breathed and fought on.)
			_end_round()
			if round_no > 0 and asked_round != round_no and standing(1) == 0:
				asked_round = round_no
				return ASK_CONTINUE
			start_round()
			# A round where no one can act (everyone left asleep, held or choking, chat 13:
			# the driders' Sleep and Stinking Cloud) still passes: the effects wear off and the
			# dying bleed, round by round, until someone acts or the fight is decided.
			var idle := 0
			while order.is_empty() and outcome() == 0 and idle < 500:
				idle += 1
				start_round()
			if order.is_empty():
				return -1
		active = _pick_next()
		if active < 0:
			order.clear()          # nobody has initiative left: the round is over
			continue
		var c: Dictionary = combatants[active]
		(c.who as PartyMember).refresh_load_word()     # each figure's turn (0x99FD: 0x9A8A)
		if c.down:
			continue
		if magic and CombatSpells.held(c.who):
			# Its turn comes, but the holding effects' handler (GAME.OVR 0xFF9A: sleep, hold, snake charm,
			# nausea) ends it at once with the turn end 0xBA:0x2637: its guard (combat byte +7) and any spell
			# it was casting (+0, left in memory) are gone (Combat Chat 33, the spell lab's Hold Person on the
			# net trap's kobolds: a kobold held while guarding struck nobody once free; ours kept the guard).
			c.guarding = false
			c.pending = {}
			continue
		if magic and (c.who as PartyMember).has_affect(CombatSpells.EFFECT_COUGH):
			magic.cough(active)      # its turn start's handlers (category 15, GAME.OVR 0x9AA3)
		c.acted = true
		c.received = 0
		c.turned = 0
		c.guarding = false
		c.ai = false
		if c.has("kept_attacks"):
			c.attacks = c.kept_attacks      # back for the turn after BEGINS CASTING (CombatSpells.cast)
			c.erase("kept_attacks")
		return active
	active = -1
	return -1


const ASK_CONTINUE := -2


## The original's choice of who acts next (GAME.OVR 0x9938, read in side chat 2; the rule in
## all play since 2026-11-14, Jeremy's A1): every combatant in the fight, standing or not,
## rolls d100; the highest initiative left acts, a tie going to the higher roll and an equal
## roll to the later one. Nobody with initiative left: -1 (the round is over). The one chosen
## has none left after its turn.
func _pick_next() -> int:
	var best_init := 0
	var best_roll := 0
	var chosen := -1
	for f in _figure_order():
		if f is String:
			roll(1, 100, "who acts next: %s (aside)" % f)
			continue
		var i: int = f
		var c: Dictionary = combatants[i]
		var r := roll(1, 100, "who acts next: %s" % c.who.name)
		var init: int = c.get("init", 0) if not c.down else 0
		if init > best_init:
			best_roll = r
		if init >= best_init and r >= best_roll:
			best_roll = r
			best_init = init
			chosen = i
	if best_init == 0:
		return -1
	combatants[chosen]["init_was"] = best_init
	combatants[chosen]["init"] = 0
	return chosen


## The members standing aside in a duel (CALL 0x8000 / 0x8001), and (Combat Chat 16) anyone down, dying or
## dead as the fight starts: [party position, name] each. The original keeps them in its figure list, so
## they roll the d100 above in their party places, but they get no initiative (0x1289F rolls for figures in
## the fight only), no square and are never picked as targets (Player 1's segment check, 1:18's tavern duel:
## seven d100s, two d6s, the target picks d1; Player 15's p15f6: DORN at 0 HP, 17 d6s and 18 d100s).
var aside: Array = []


## Who rolls the d100 above, in the original's figure order: the party in party order (the members
## standing aside at their places, as their names), then everyone else.
func _figure_order() -> Array:
	var out: Array = []
	if aside.is_empty():
		out.assign(range(combatants.size()))
		return out
	var party: Array = []
	var rest: Array = []
	for i in combatants.size():
		# (a party member fighting on the monsters' side keeps his party place: the party list, 0x5D96)
		if combatants[i].who is PartyMember and not combatants[i].who.is_monster:
			party.append(i)
		else:
			rest.append(i)
	var places := {}
	for a in aside:
		places[int(a[0])] = String(a[1])
	var k := 0
	while not party.is_empty() or places.has(k):
		if places.has(k):
			out.append(places[k])
			places.erase(k)
		else:
			out.append(party.pop_front())
		k += 1
	out.append_array(rest)
	return out


## A spell with a casting time (GAME.OVR 0x14C0F: the table's delay / 3, here `d`) goes off
## on the caster's next turn: its initiative drops by d (to 1 if that is all it has), so it
## acts again later this round.
func delay_cast(i: int, d: int) -> void:
	var c: Dictionary = combatants[i]
	var was: int = c.get("init_was", c.init)
	var now := was - d if was > d else 1
	c.init = now
	if order.is_empty():
		order.append(i)      # someone is left to act this round


var ended_round := -1           # the round whose end has been played (_end_round)
## DELAY (the original's DONE menu): the active combatant acts again after everyone else
## this round, keeping what it has left. Once a round.
func delay() -> bool:
	if active < 0 or combatants[active].get("delayed_round", 0) == round_no:
		return false
	combatants[active].delayed_round = round_no
	# Initiative 1: after everyone with more, ties by the d100 (assumed, not yet checked in
	# the lab; the original's DELAY is still to trace).
	combatants[active].init = 1
	order.append(active)
	return true
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
	decided = true
	for c in combatants:
		if c.team == 1 and not c.down:
			c.down = true
			c.fled = true
			(c.who as PartyMember).status = PartyMember.STATUS_RUNNING


## Attacks this round with the readied weapon: half-attacks (missile weapons: the ITEMS
## table's) rounded up on even rounds, and never more shots than are left. The original rounds
## up when its round counter (DS:0x6DE3) is odd (GAME.OVR 0x1364D), and that counter is 0 at the
## fight's start and counts up at the end of each round (0xA098): odd in rounds 2, 4, ... (lab,
## Combat Chat 1: 5:7's 8TH LVL FIGHTERs, 3/2 attacks, struck once in round 1; ours twice).
func attacks_for(m: PartyMember) -> int:
	var half: int = m.half_attacks
	var shooting := m.weapon_ranged and m.missile_ready
	if shooting:
		half = m.missile_half_attacks
	half = speed_half(m, half)
	if round_no % 2 == 0:
		half += 1
	var n := half / 2
	if shooting:
		n = mini(n, m.shots_left())
	return n


## Haste and Slow work on the half-attacks before the round's rounding (category 0x12 between GAME.OVR 0x135A7
## and 0x1364D, and 0x12850 for the second count): Haste's handler (0xF8A6) doubles them, Slow's (0xFD1C) halves
## them (shr), so a slowed one-attack figure strikes every other round (Combat Chat 33, the spell lab's Slow on
## the net trap's kobolds: ours took the attack away every round).
func speed_half(m: PartyMember, half: int) -> int:
	if m.has_affect(CombatSpells.EFFECT_HASTE):
		return (half * 2) & 0xFF
	if m.has_affect(CombatSpells.EFFECT_SLOW):
		return half >> 1
	return half


## The second attack count this round (record +0xA2 -> +0x114, GAME.OVR 0x12843-0x12869).
func second_for(m: PartyMember) -> int:
	return (speed_half(m, m.half_attacks_2) + (1 if round_no % 2 == 0 else 0)) / 2


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


## SETTINGS: QUICK BANDAGES (QoL, Jeremy's P18). On: a QUICK party member bandages a dying
## ally first, as a player would from the DONE menu. Off by default, as the original (its
## QUICK never bandages). CombatScreen sets it for each fight; headless runs (the bot, the
## lab) and the lab dice keep it off, so they play as before.
## QUICK is kept in the character record, byte 0x10F (Combat Chat 6, GAME.OVR): QUICK sets it
## (0xAA38), Space in a fight clears it for members who aren't NPCs (0x9D16; 0xBC26 during a
## computer-run turn, not for status 1), a script's team change sets or clears it (0x808F-0x80C5);
## nothing clears it when a fight ends, so the party stays on QUICK into the next fight (check 5:
## Tyranthraxus's fight played itself after the guards'). The record goes into saves with it.
const RECORD_QUICK := 0x10F

static func record_quick(m) -> bool:
	return m is PartyMember and not m.is_monster and m.raw.size() > RECORD_QUICK and m.raw[RECORD_QUICK] != 0


static func set_record_quick(m, on: bool) -> void:
	if m is PartyMember and not m.is_monster and m.raw.size() > RECORD_QUICK:
		m.raw[RECORD_QUICK] = 1 if on else 0


var quick_bandages := false
const QUICK_BANDAGES_KEY := "quick_bandages"
## SETTINGS: TACTICS FOR QUICK, SMARTER (B1; SmartQuick). Set like quick_bandages.
var smart_quick := false
## SETTINGS: MONSTER TACTICS, SMARTER (B2; SmartQuick). Set like quick_bandages.
var smart_monsters := false


static func quick_bandages_on() -> bool:
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return false
	return bool(cf.get_value("qol", QUICK_BANDAGES_KEY, false))


static func save_quick_bandages(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", QUICK_BANDAGES_KEY, on)
	cf.save(GameData.SETTINGS_PATH)


## SETTINGS: MAGIC ON DONE (decided, Methods 3): DONE's menu gains MAGIC after SPEED, showing
## whether QUICK party members may cast (the original's Alt-M). Off: the original's DONE menu.
const MAGIC_MENU_KEY := "magic_menu"


static func magic_menu_on() -> bool:
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(cf.get_value("qol", MAGIC_MENU_KEY, true))


static func save_magic_menu(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", MAGIC_MENU_KEY, on)
	cf.save(GameData.SETTINGS_PATH)


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
		if walls and not field.see_through(cur.x, cur.y):
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
	a.target = j
	_note_attack(a, t)
	if t.received < 3:
		t.dir = face_dir(t, a)
	var behind: bool = t.received > 1 and face_dir(a, t) == t.dir and t.turned > 4
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
	# Range makes the shot harder (lab, side chat 2: the original's to-hit threshold for
	# Phineas's darts at an orc was 59, its melee one 54 = 60 - AC; ours had the penalty
	# the other way, making long shots easier).
	var ac: int = (tm.rear_ac if behind else tm.ac) - penalty
	var bonus := 0
	if magic:
		magic.reveal(am)
		ac = magic.armour(tm, (tm.rear_ac if behind else tm.ac)) - penalty
		bonus = magic.hit_bonus(am, tm)
		# A helpless target (asleep, held, ...) is slain by the shot, no dice: the attack routine
		# (GAME.OVR 0x13C01) tests it first (0xBA:0xB73) for missiles as for blows, after the flight
		# (0x14EAB); one missile is counted (DS:0x6E2D, spent at 0x141EF) and both attack slots
		# cleared (Combat Chat 25: p19e6 draw 21571, a nomad's arrow at a sleeping kobold).
		if CombatSpells.held(tm) and am.shots_left() > 0:
			_spend_shot(am)
			a.attacks = 0
			message.emit("%s SLAYS HELPLESS %s WITH ONE CRUEL BLOW" % [am.name, tm.name])
			_hurt(j, tm.hp + 5)
			return
	var how := " (FROM BEHIND)" if behind else ""
	while a.attacks > 0 and not t.down and am.shots_left() > 0:
		a.attacks -= 1
		var gone := _spend_shot(am)
		var need: int = am.thac0 - ac - bonus
		need -= SpecialAffects.hit_bonus(am, tm)
		need -= script_hit_mod(am)
		var d20 := roll(1, 20, "%s shoots %s%s (needs %d)" % [am.name, tm.name, how.to_lower(), need])
		var free_miss := _free_miss(t, d20)     # to-hit category 16, on every roll above 1
		var hit := d20 != 1 and (d20 == 20 or d20 >= need) and not free_miss
		if not hit:
			message.emit("%s ATTACKS %s%s AND MISSES" % [am.name, tm.name, how])
		else:
			var dice: Array = am.damage_large if tm.is_large() else am.damage
			var dmg := maxi(roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2]), 0)
			if magic:
				magic.image_die(tm)
			var weapon: GameItem = gone if gone != null else am.readied_weapon(types)
			var notes: Array = []
			var before := dmg
			dmg = SpecialAffects.weapon_damage(am, tm, weapon, types, dmg, _dice, range_of(a, t) > 1, notes)
			for n in notes:
				message.emit(n)
			if dmg == 0 and before > 0:
				if notes.is_empty():
					message.emit("%s ATTACKS %s%s AND MISSES" % [am.name, tm.name, how])
			else:
				message.emit("%s ATTACKS %s%s HITTING FOR %d" % [am.name, tm.name, how, dmg])
				_hurt(j, dmg)
		if gone != null and types != null:
			am.recalculate(types)
	if not am.missile_ready or am.shots_left() <= 0:
		a.attacks = 0


## One missile used (thrown ones land on the field, picked up after the fight). Returns the item
## the shot came from (null: the launcher's own, e.g. a sling's stone).
func _spend_shot(am: PartyMember) -> GameItem:
	var gone := am.use_shot()
	if gone != null and types != null:
		if (types.flags(gone.type) & 0x14) == 0x14:
			var copy := gone.copy()
			copy.name = gone.name
			dropped.append(copy)
	return gone


# --- The computer's choice of weapon -----------------------------------------------------
# As the original does it at the start of each computer-run turn (rules as documented by
# Pilgrim's reconstruction; read in GAME.OVR by Combat Chat 7: 0xBF8A, the rating 0xBE4D):
# every weapon the combatant may use (its class bits, record 0xB0) is rated: dice count x
# size, + 8 per plus, + 2 per point of damage bonus, + (ITEMS byte 5 - 1) x 2 for a
# launcher, + 3 if one-handed; cursed ones count 0, and so does one the hands held by other
# readied items would leave no room for (past 3). (Not built, rare: item type 85's
# rating 8 against some targets, 0 for an item whose bytes 61/62 mark it.) The best
# missile weapon (thrown or launcher) is readied if it rates over half the best melee
# weapon (or bare hands), has its ammunition, and either no enemy is adjacent or it can
# also be used in melee; otherwise the best melee weapon (none: bare hands). Readying it
# follows the game's hands rule (see choose_weapon's end): a two-handed weapon puts the
# shield away, a one-handed one takes the best shield up again, and with a hand held by
# something else (a mirror) a two-handed weapon can't be held at all. (The lab saw this:
# Phineas on Quick switches between his dagger and his darts; a kobold readies its sword.)

func _rate(m: PartyMember, it: GameItem, hands_left: int = 0) -> int:
	if it.cursed:
		return 0
	var dmg := types.damage(it.type, false)
	var r: int = dmg[0] * dmg[1]
	if it.plus > 0:
		r += it.plus * 8
	if dmg[2] > 0:
		r += dmg[2] * 2
	# GAME.OVR 0xBEF4: a launcher adds (ITEMS byte 5 - 1) x 2, byte 5 as it is (bows 4 -> 6;
	# javelins, flagged thrown and launcher, 2 -> 2). Combat Chat 7: ours halved byte 5 first,
	# so 6:1's ELWEN kept her +1 melee weapon (19) over her javelins (9; the original's 11).
	if types.flags(it.type) & ItemTypes.FLAG_LAUNCHER:
		r += (types.half_attacks(it.type) - 1) * 2
	if types.hands(it.type) <= 1:
		r += 3
	# 0xBF22: 0 when the hands held by other readied items (record 0x100 less the readied weapon's and
	# shield's) and the weapon's own would pass 3.
	if hands_left + types.hands(it.type) > 3:
		return 0
	return r & 0xFF                 # the original keeps the rating in a byte


func choose_weapon(i: int) -> void:
	if types == null:
		return
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	# A cursed weapon stays (no change below), but the shield rule still runs (0xC3E1).
	var bare: int = m.base_damage[0] * m.base_damage[1] + maxi(int(m.base_damage[2]), 0) * 2
	var best_melee: GameItem = null
	var melee_rate := bare
	var best_missile: GameItem = null
	var missile_rate := 1
	# Hands held by readied items other than the weapon and the shield (record 0x100, less theirs: 0xBF8A).
	var other_hands := hands_used(m)
	if m.weapon != null:
		other_hands -= types.hands(m.weapon.type)
	if m.shield != null:
		other_hands -= types.hands(m.shield.type)
	for it in m.items:
		if not types.has(it.type) or types.slot(it.type) != ItemTypes.SLOT_WEAPON:
			continue
		if (types.class_flags(it.type) & m.class_flags) == 0:
			continue
		var f := types.flags(it.type)
		var r := _rate(m, it, other_hands)
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
		if SmartQuick.order(self, i) == SmartQuick.MELEE:
			has_ammo = false           # B3: MELEE keeps a hand weapon
		if has_ammo and (melee_too or not enemy_adjacent(i)):
			pick = best_missile
	if OS.has_environment("APDBG"):
		print("   @%d choose_weapon %s attacks %d moves %d melee %s=%d missile %s=%d pick %s (had %s)" % [TpDice.calls, m.name, c.attacks, c.moves,
			best_melee.type if best_melee else -1, melee_rate, best_missile.type if best_missile else -1,
			missile_rate, pick.type if pick else -1, m.weapon.type if m.weapon else -1])
	# Readying (0xC2EC on; Combat Chat 8): unless the readied weapon is the pick or cursed, it is put away
	# and the pick readied through the game's ready routine (0x2250A), which refuses it when the hands in
	# use (the shield's not counted) and its own would pass 2 ("Your hands are full!"). Then, with more than
	# 2 hands in use, the readied shield goes away (one not cursed), else the pick itself; with fewer than 2
	# and the readied shield the best one (or none readied), the best shield is taken up. Player 5/6: LIRA
	# with a Brass Mirror readied (1 hand) puts her sword away for her bow and can't hold the bow: she
	# fights bare-handed (one step, one blow), where ours shot twice.
	var weapon_before: GameItem = m.weapon
	var readied_before := m.items.map(func(it): return it.readied)
	var shield: GameItem = m.shield
	var best_shield: GameItem = null
	var shield_rate := 0
	for it in m.items:
		if types.has(it.type) and types.slot(it.type) == ItemTypes.SLOT_SHIELD \
				and (types.class_flags(it.type) & m.class_flags) != 0:
			var sr := it.plus + 1 if it.plus >= 0 else 0
			if sr > shield_rate:
				best_shield = it
				shield_rate = sr
	if m.weapon == null or (m.weapon != pick and not m.weapon.cursed):
		if m.weapon != null:
			m.weapon.readied = false
		var hands := hands_used(m)
		if shield != null and not shield.cursed:
			hands -= types.hands(shield.type)
		if pick != null:
			_toggle_ready(i, pick, hands)
	var held := hands_used(m)
	var keep_shield := shield == null or (shield == best_shield and not shield.cursed)
	if held > 2:
		if shield != null and not shield.cursed:
			shield.readied = false
		elif pick != null:
			_toggle_ready(i, pick, hands_used(m))
	elif held < 2 and keep_shield:
		if shield != null:
			shield.readied = false
		if best_shield != null:
			_toggle_ready(i, best_shield, hands_used(m))
	if m.items.map(func(it): return it.readied) == readied_before:
		return                     # nothing changed (ours' recalculate would rebuild a monster's AC)
	m.recalculate(types)
	if m.weapon != weapon_before and c.attacks > 0:
		c.attacks = attacks_for(m)
		c.second = second_for(m)
		c.attacks += c.second


## Hands held by `m`'s readied items (record 0x100: ITEMS byte 1 of each, START.EXE 0xBA:0xBB8).
func hands_used(m: PartyMember) -> int:
	var n := 0
	for it in m.items:
		if it.readied and types.has(it.type):
			n += types.hands(it.type)
	return n


## The game's ready/put-away routine (GAME.OVR 0x2250A) as the computer's choice uses it: a readied item
## is put away (not a cursed one); another is readied unless the hands in use (`hands`) and its own pass
## 2 ("Your hands are full!"), its slot is taken, or its class doesn't match.
func _toggle_ready(i: int, it: GameItem, hands: int) -> void:
	var m: PartyMember = combatants[i].who
	if it.readied:
		if not it.cursed:
			it.readied = false
		return
	if hands + types.hands(it.type) > 2:
		message.emit("YOUR HANDS ARE FULL!")
		return
	var slot := types.slot(it.type)
	for o in m.items:
		if o != it and o.readied and types.has(o.type) and types.slot(o.type) == slot and slot <= 9:
			return
	if (types.class_flags(it.type) & m.class_flags) == 0:
		return
	it.readied = true


## Applies damage the way the original does (see "Going down" above).
func hurt(j: int, dmg: int, kind: int = 0) -> void:
	_hurt(j, dmg, kind)


func _hurt(j: int, dmg: int, kind: int = 0) -> void:
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	t.last_kind = kind
	if dmg > 0 and tm.has_affect(0x65) and not tm.has_affect(0x62) and int(t.regen_in) == 0:
		t.regen_in = 3      # a troll's wounds start closing three rounds later (0x65, 0x3B)
	if dmg > 0:
		# A wound spoils a spell being cast ("LOST A SPELL", forgotten) and keeps the figure
		# from starting another for the rest of the round (GAME.OVR 0x12CDA: record bytes 0
		# and 1, set again at each round's start, 0x127FB).
		t.no_spells = true
		if not t.get("pending", {}).is_empty():
			# The spell is dropped (combat byte +0), but START.EXE 0xBA:0x148B takes it out of the memory of
			# the figure whose turn it is (DS:0x5D92), not the wounded caster's: the caster keeps it, an attacker
			# with the same spell memorized loses one (Combat Chat 33, the spell lab's Prayer: BAKSHI's 19 kept).
			if active >= 0 and active < combatants.size():
				(combatants[active].who as PartyMember).forget(int(t.pending.id))
			t.pending = {}
			message.emit("%s LOST A SPELL" % tm.name)
	if tm.hp >= dmg:
		tm.hp -= dmg
		if tm.hp > 0:
			return
		tm.status = PartyMember.STATUS_UNCONSCIOUS
		t.down = true
		message.emit("%s GOES DOWN" % tm.name)
		_went_down(j)
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
	_went_down(j)


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
## The direction from a to b for facing and attacks from behind: the original's wedges
## (GAME.OVR 0x14E38, which every facing and behind test calls), from their closest cells.
func dir_between(a: Dictionary, b: Dictionary) -> int:
	var pr := closest(a, b)
	return wedge_dir(pr[0], pr[1])


## The direction the original's facing rules use (GAME.OVR 0x14E38 from 0x13FF1, 0x1407F, 0x13DDC, 0x14D6F):
## from a's own cell to b's (DS:0x5F27 / 0x5F28, a large figure's anchor), not their closest cells
## (Combat Chat 28: the troll fight, seed 98e616ec draw 2972: the original's troll faced 5 and had turned 4,
## so PHINEAS's blow was a plain one; ours, from the closest cells, had it facing 6, turned 5, struck from behind).
func face_dir(a: Dictionary, b: Dictionary) -> int:
	return wedge_dir(a.cell, b.cell)


## Range from a to b in squares, from their closest cells.
func range_of(a: Dictionary, b: Dictionary) -> int:
	var pr := closest(a, b)
	return range_between(pr[0], pr[1])


func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


## Pool of Radiance's own direction from `from` to `to` (GAME.OVR 0x14E38 with its test at
## 0x300CD, read in side chat 2): the first d (0 up, clockwise) for which `to` lies in d's
## region seen from the cell one step that way (n): up/right/down/left are 90-degree wedges
## opening out from n (north: n.y - to.y >= |to.x - n.x|), the diagonals the quarter beyond n
## (north-east: to.x >= n.x and to.y <= n.y). `to` on `from` or on n counts. The computer's
## approach steps from it (lab: Rhiannon at 29,14 went west for an orc at 25,12, which these
## wedges call west and dir_to north-west), and so do facing and attacks from behind.
static func wedge_dir(from: Vector2i, to: Vector2i) -> int:
	for d in 8:
		var n: Vector2i = from + DIRS[d]
		if to == from or to == n:
			return d
		var ok := false
		match d:
			0: ok = n.y - to.y >= absi(to.x - n.x)
			1: ok = to.x >= n.x and to.y <= n.y
			2: ok = to.x - n.x >= absi(to.y - n.y)
			3: ok = to.x >= n.x and to.y >= n.y
			4: ok = to.y - n.y >= absi(to.x - n.x)
			5: ok = to.x <= n.x and to.y >= n.y
			6: ok = n.x - to.x >= absi(to.y - n.y)
			7: ok = to.x <= n.x and to.y <= n.y
		if ok:
			return d
	return 0


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
		if not sweep(active, other):
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
	if TpDice.on:
		TpDice.log.append("pos %d:%d,%d" % [active, to.x, to.y])
	c.dir = dir
	c.received = 0
	c.turned = 0
	guard_attacks(active)
	if c.down:
		c.moves = 0
		c.attacks = 0
		return "fell"
	if magic:
		magic.cloud_save(active)     # a step into a Stinking Cloud (GAME.OVR 0xA4ED, 0xB6E2)
	return "moved"


## Enemies guarding next to combatant `i`'s new cell attack it (each once), in the order of the
## mover's reach-1 list, nearest first (GAME.OVR 0x12E22: 0xBA:0x2433 from the mover, as the free
## attacks), not by figure number (Combat Chat 24, Player 20's p19e6 draw 1347: a gnoll fleeing to
## 23,13 between ARN at 24,12 and CEDRIC at 24,14; CEDRIC's mace struck first, d6+2, then ARN's sword;
## the original's HOLD dump: the gnoll 10 HP, 4 after CEDRIC's blow).
func guard_attacks(i: int) -> void:
	var c: Dictionary = combatants[i]
	var near: Array[int] = []
	for j in combatants.size():
		if not combatants[j].down and combatants[j].team != c.team and touching(combatants[j], c):
			near.append(j)
	_by_distance(c, near)
	for j in near:
		var e: Dictionary = combatants[j]
		if c.down:
			return
		if e.down or e.team == c.team or not e.guarding or not touching(e, c):
			continue
		if CombatSpells.held(e.who):
			continue       # asleep or held: no strike (GAME.OVR 0x13263, see free_attacks)
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
	# In the order of the mover's reach-1 list (GAME.OVR 0x130AD: 0xBA:0x2433, nearest first
	# from the mover), not by figure number (Combat Chat 7, 6:1's draw 6519: DORN's long sword
	# struck the runner before BRAM's mace).
	var near: Array[int] = []
	for j in combatants.size():
		if not combatants[j].down and combatants[j].team != c.team and touching(combatants[j], c):
			near.append(j)
	_by_distance(c, near)
	for j in near:
		var e: Dictionary = combatants[j]
		if c.down:
			return
		if e.down or e.team == c.team or not touching(e, c) or touching(c, e, to):
			continue
		# A figure asleep, held, charmed by a snake or helpless strikes nobody: GAME.OVR 0x13263 skips any
		# attacker with one of the four effects of DS:0x286C (START.EXE 0xBA:0xB73) before the free and the
		# guard attacks (Player 18, p18a5 draw 11293: a goblin guard asleep struck BRAM in ours; Jeremy's P79).
		if CombatSpells.held(e.who):
			continue
		var off := (dir_between(e, c) - int(e.dir) + 8) % 8
		var seen := off <= 2 or off >= 6    # not one of the three cells at its back
		# GAME.OVR 0x132F8: it strikes if it still has initiative this round (combat byte +3), or has taken no
		# blow (+0xF), or the mover is in front of it. Not "has had its turn" (Combat Chat 34, the spell lab's
		# sl44 and Player 32's p19c2: a figure whose turn passed while it was asleep or sick has no initiative
		# left but never acted, and ours gave it a blow at a runner from behind).
		if int(e.get("init", 0)) <= 0 and e.received > 0 and not seen:
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
	var diff := (face_dir(t, a) - int(t.dir) + 8) % 8
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
		# Whoever it attacks becomes its target (GAME.OVR 0x14126; a free attack puts the old
		# one back, 0x13402).
		a.target = j
		# The original (GAME.OVR 0x12EDB: 0x13FF1 then 0x1407F) counts the attack, turns
		# the target to face the attacker on its first two attacks of the round, and only
		# then asks whether the attacker stands behind it (0x13DCF), so a second attacker
		# never strikes from behind (lab, side chat 2: a goblin's d20 of 16 at Rhiannon's
		# back missed against her front AC 0). The count (0x13FF1, from the attack at 0x15519)
		# was left out here from Combat Chat 3 to 10, so a melee target always turned and was
		# never struck from behind (Combat Chat 11, 4:2 seed 2468ace1 draw 2506: GRISHNAK, DORN's
		# third attacker of the round, hits his rear AC 56; a probe in the to-hit showed it).
		_note_attack(a, t)
		if t.received < 3:
			t.dir = face_dir(t, a)
		if t.received > 1 and face_dir(a, t) == t.dir and t.turned > 4:
			behind = true
	a.dir = dir_between(a, t)
	a.moves = 0
	var stab := not free and _can_backstab(a, t)
	var ac: int = tm.rear_ac if behind else tm.ac
	if stab:
		# GAME.OVR 0x13DA8: a backstab (0x14D6F) strikes the target's record +0x112 less 2, its rear AC + 2
		# (Combat Chat 26: p22a2 draw 4127, a thief's 10 at BRAM, rear AC 6, missed; ours had + 4 and hit).
		ac = tm.rear_ac + 2
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
		var need: int = am.thac0 - ac - bonus - SpecialAffects.hit_bonus(am, tm) - script_hit_mod(am)
		var d20 := roll(1, 20, "%s to hit %s%s (needs %d)" % [am.name, tm.name, how.to_lower(), need])
		var free_miss := _free_miss(t, d20)     # to-hit category 16, on every roll above 1
		var hit := d20 != 1 and (d20 == 20 or d20 >= need) and not free_miss
		if not hit:
			message.emit("%s %s %s%s AND MISSES" % [am.name, verb, tm.name, how])
			continue
		var dice: Array = am.base_damage_2 if second else (am.damage_large if tm.is_large() else am.damage)
		var dmg := roll(dice[0], dice[1], "%s damage" % am.name) + int(dice[2])
		dmg = maxi(dmg, 0)
		if magic:
			magic.image_die(tm)
		if stab:
			dmg *= (am.thief_level() - 1) / 4 + 2
		if magic:
			dmg = magic.damage_after(am, dmg)
		var before := dmg
		dmg = SpecialAffects.weapon_damage(am, tm, am.readied_weapon(types), types, dmg, _dice)
		if dmg == 0 and before > 0:
			# Only magic (or silver) hurts it: the original reports the blow as a miss (lab: a
			# party with THAC0 1 "ATTACKS FERRAN MARTINEZ AND MISSES" round after round).
			message.emit("%s %s %s%s AND MISSES" % [am.name, verb, tm.name, how])
			continue
		message.emit("%s %s %s%s HITTING FOR %d" % [am.name, verb, tm.name, how, dmg])
		_hurt(j, dmg)
		a["hits"] = int(a.get("hits", 0)) + 1
		if not t.down:
			_on_hit_specials(i, j, second)
		if am.has_affect(0x49) and int(a.hits) == 2 and not t.down:
			# A tiger whose two claws both hit rakes with its rear claws: two more attacks of
			# 2d4 (GAME.OVR 0x161CD sets the second attack to 2 x 2d4 and attacks).
			message.emit("%s RAKES..." % am.name)
			_extra_attacks(i, j, 2, 2, 4)
	if i != active and a.attacks <= 0:
		# Out of turn (a guard's strike, a free attack) with its attacks spent: that is its
		# turn for this round (GAME.OVR 0x142AB ends the attacker's turn, 0xBA:0x2637; lab:
		# Thrender, on guard, struck a goblin and didn't act again that round).
		_spend_turn(i)


## The sweep (GAME.OVR 0x1367D, "<NAME> SWEEPS"), tried before every blow at an adjacent
## target (the computer's attack 0xBA3C, AIM 0xA5BD, 0x154F2): when the target is of level 0
## (record 0x73 = 0: the buccaneers, the city's thugs), the attacker's attacks (its first
## weapon's, +0x113) are below its sweep level (fight record +5 = record 0x6B, START.EXE
## 0xBA:0x1003: the fighter level, record 0x98, for a character of a race, else 1), and more
## level-0 enemies stand next to it (the reach-1 list 0xBA:0x2433, nearest first) than it has
## attacks: it strikes min(that many, its sweep level) of them once each, the target first
## (swapped to the list's front), each turned to face it (0x13FF1), and its turn ends.
## Combat Chat 7, 6:1's draw 1772: DORN (fighter 5) swept the two buccaneers beside him.
func sweep(i: int, j: int) -> bool:
	var a: Dictionary = combatants[i]
	var am: PartyMember = a.who
	var tm: PartyMember = combatants[j].who
	var fighter: int = am.raw[0x98] if am.raw.size() > 0x98 else 0
	var race: int = am.raw[0x2E] if am.raw.size() > 0x2E else 0
	var cap: int = fighter if fighter > 0 and fighter < 128 and race > 0 and race < 128 else 1
	var first: int = a.attacks - int(a.get("second", 0))
	if first >= cap or tm.raw.size() <= 0x73 or tm.raw[0x73] != 0 or not touching(a, combatants[j]):
		return false
	var near: Array[int] = []
	for k in combatants.size():
		if _enemy_of(a, k) and touching(a, combatants[k]):
			near.append(k)
	_by_distance(a, near)
	var low := 0
	for k in near:
		if combatants[k].who.raw.size() > 0x73 and combatants[k].who.raw[0x73] == 0:
			low += 1
	if low <= first:
		return false
	low = mini(low, cap)
	message.emit("%s SWEEPS" % am.name)
	var p := near.find(j)
	if p > 0:
		near[p] = near[0]
		near[0] = j
	for k in near:
		if low <= 0:
			break
		if combatants[k].who.raw[0x73] != 0:
			continue
		a.attacks = 1
		a.second = 0
		if not combatants[k].down:
			attack(i, k)
		low -= 1
	a.attacks = 0
	a.second = 0
	return true


## Figures down in the fight, not counting those that got away.
func fallen_count() -> int:
	var n := 0
	for e in combatants:
		if e.down and not e.get("fled", false):
			n += 1
	return n


## Ends combatant i's turn out of turn: no initiative left this round, guard and any
## spell being cast gone (the original's 0xBA:0x2637).
func _spend_turn(i: int) -> void:
	var c: Dictionary = combatants[i]
	c.init = 0
	c.guarding = false
	c.pending = {}
	c.moves = 0
	order.erase(i)


## Attacks a power adds (a tiger's rake, a mantis's hold): `n` rolls to hit, `count`d`size` each.
func _extra_attacks(i: int, j: int, n: int, count: int, size: int) -> void:
	var am: PartyMember = combatants[i].who
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	for k in n:
		if t.down:
			return
		var need: int = am.thac0 - tm.ac - script_hit_mod(am)
		var d20 := roll(1, 20, "%s to hit %s (needs %d)" % [am.name, tm.name, need])
		if d20 == 1 or (d20 != 20 and d20 < need):
			message.emit("%s ATTACKS %s AND MISSES" % [am.name, tm.name])
			continue
		var dmg := roll(count, size, "%s damage" % am.name)
		message.emit("%s ATTACKS %s HITTING FOR %d" % [am.name, tm.name, dmg])
		_hurt(j, dmg)


## What a hit does besides damage, from the attacker's standing effects (SpecialAffects):
## poison, paralysis, level drain. The original runs them per hit (GAME.OVR 0x13F49) as the
## effect category of the attack's slot + 1 (0x2B1E4): a hit from the first slot runs
## category 2 (0x44, 0x4C, 0x4D, 0x4F, 0x50, 0x55-0x57), from the second (`slot2`, the slot
## the original's attack loop uses first) category 3 (0x40-0x46, 0x4F, 0x55-0x57). (Combat
## Chat 10, Player 9's 4:21 2,11: the huge scorpion's d3 sting poisons, its d8 claws don't.)
const HIT_SLOT1 := [0x44, 0x4C, 0x4D, 0x4F, 0x50, 0x55, 0x56, 0x57]
const HIT_SLOT2 := [0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x4F, 0x55, 0x56, 0x57]

func _on_hit_specials(i: int, j: int, slot2: bool = false) -> void:
	var am: PartyMember = combatants[i].who
	var allowed: Array = HIT_SLOT2 if slot2 else HIT_SLOT1
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	if t.down:
		return
	for type in SpecialAffects.POISON_BONUS:
		if _hit_has(am, allowed, type) and not t.down:
			# The poison routine (GAME.OVR 0x101A0): the save, and on a failure the effect goes on
			# through 0x2BD3C, not the add-effect routine 0x2C540, so no resistance (no d100s:
			# Combat Chat 10, Player 9's 4:21 2,11, LIRA's elven d100 is not drawn).
			if not _save(tm, 0, int(SpecialAffects.POISON_BONUS[type])):
				message.emit("%s IS POISONED" % tm.name)
				SpellCaster.add_affect(tm, SpecialAffects.POISONED, 0, 0, 0xFF)   # power 0xFF (GAME.OVR 0x10204; main chat 68)
				tm.hp = 0
				tm.status = PartyMember.STATUS_DEAD
				t.down = true
				message.emit("%s IS KILLED" % tm.name)
				_went_down(j)
	if _hit_has(am, allowed, 0x4D) and int(combatants[i].get("gripping", -1)) < 0 and not t.down \
			and tm.stats[0] < 19:
		# A giant mantis grips anyone with STR under 19 ("IS HELD FAST", GAME.OVR 0x10590).
		combatants[i]["gripping"] = j
		message.emit("%s IS HELD FAST" % tm.name)
	if _hit_has(am, allowed, 0x4C) and int(combatants[i].get("latched", -1)) < 0 and not t.down:
		combatants[i]["latched"] = j        # a stirge latches on (0x4C)
		combatants[i]["drink"] = 207 >> 4
	var paralysis := 0
	if _hit_has(am, allowed, 0x43):
		paralysis = roll(2, 8, "paralysis rounds")
	if _hit_has(am, allowed, 0x44) and tm.race_id != 2:
		paralysis = 63
	if _hit_has(am, allowed, 0x45):
		paralysis = roll(1, 9, "paralysis rounds") + 10     # drider (GAME.OVR 0x10341)
	if paralysis > 0 and not t.down and not CombatSpells.held(tm) \
			and not SpecialAffects.blocks(tm, SpecialAffects.PARALYZED, func(): return roll(1, 100, "resists")) \
			and not _save(tm, 0, 0):
		message.emit("%s IS PARALYZED" % tm.name)
		SpellCaster.add_affect(tm, SpecialAffects.PARALYZED, 0, paralysis, 12)
	for type in [0x55, 0x56]:
		if _hit_has(am, allowed, type) and not t.down:
			drain(j, 1 if type == 0x55 else 2)
	if _hit_has(am, allowed, 0x57) and not t.down:
		# A mummy's touch (GAME.OVR 0x11047): disease, no save.
		if SpecialAffects.infect(tm, roll(1, 6, "months of rot")):
			message.emit("%s IS DISEASED" % tm.name)
	if _hit_has(am, allowed, 0x4F) and not t.down:
		# Tyranthraxus's fiery blows (handler at GAME.OVR 0x10674): 2d10 more, as fire.
		var burn := SpecialAffects.element_damage(tm, SpecialAffects.FIRE, roll(2, 10, "fire"))
		if burn > 0:
			message.emit(SpecialAffects.damage_words(tm.name, burn, SpecialAffects.FIRE | SpecialAffects.MAGIC))
			_hurt(j, burn, SpecialAffects.FIRE | SpecialAffects.MAGIC)
	if _hit_has(am, allowed, 0x50) and not t.down:
		# An ankheg's acid (0x106A7): 1d4 more.
		var acid := roll(1, 4, "acid")
		message.emit(SpecialAffects.damage_words(tm.name, acid, SpecialAffects.ACID))
		_hurt(j, acid, SpecialAffects.ACID)


## Has `m` effect `type` among the ones this hit's category runs (`_on_hit_specials`)?
func _hit_has(m: PartyMember, allowed: Array, type: int) -> bool:
	return type in allowed and m.has_affect(type)


func _save(m: PartyMember, kind: int, bonus: int) -> bool:
	if magic:
		return magic.save(m, kind, bonus, null)
	var d := roll(1, 20, "%s saves" % m.name)
	return d != 1 and (d == 20 or d + bonus + SpecialAffects.save_bonus(m, kind) >= (m.saves[kind] if kind < m.saves.size() else 20))


## Level drain as GAME.OVR does it (overlay 0x10D7D): LevelDrain.drain (the record keeps
## the drained levels and HP for Restoration). A figure left dead or gone falls.
func drain(j: int, levels: int) -> void:
	var t: Dictionary = combatants[j]
	var m: PartyMember = t.who
	var ct := ClassTables.shared(CharacterSheet.game_path) if CharacterSheet.game_path != "" else null
	if ct == null or m.raw.size() <= LevelDrain.DRAINED_HP:
		message.emit("%s IS DRAINED %s" % [m.name, "A LEVEL" if levels == 1 else "%d LEVELS" % levels])
		return
	for line in LevelDrain.drain(m, levels, ct, CharacterSheet.spells):
		message.emit(line)
	if m.status == LevelDrain.STATUS_GONE or m.status == PartyMember.STATUS_DEAD:
		t.down = true


## A thief's backstab (GAME.OVR 0x14D6F): a thief (record +0x9C) in no body armour or leather (the slot-2
## pointer +0xD4: none or item type 0x32) with no weapon or one of types 7, 8, 35-37 (+0xCC), striking a target
## already attacked more than once this round (its combat byte +0xF) from directly behind (0x14E38's direction,
## the figures' own cells, equal to the target's facing +0x9). No size test: a troll is backstabbed too. Strikes
## rear AC + 2 (0x13DA8) and damage x2 (levels 1-4), x3 (5-8)... (Combat Chat 29, seen: the troll fight seed
## 31872a7a draw 3687, PHINEAS in leather with a dagger behind a troll, roll 15; the original's fight follows the
## backstab's doubled damage through all 4329 draws. Ours had a man-sized test, took weapon type 97, any armour.)
const BACKSTAB_WEAPONS := [7, 8, 35, 36, 37]
const LEATHER_ARMOUR := 0x32

func _can_backstab(a: Dictionary, t: Dictionary) -> bool:
	var am: PartyMember = a.who
	if am.thief_level() <= 0:
		return false
	var body := _body_armour(am)
	if body != null and body.type != LEATHER_ARMOUR:
		return false
	if am.weapon != null and not am.weapon.type in BACKSTAB_WEAPONS:
		return false
	return int(t.received) > 1 and face_dir(a, t) == int(t.dir)


## The readied item in the body-armour slot (START.EXE 0x1847 sets record +0xD4 in list order: the last).
func _body_armour(m: PartyMember) -> GameItem:
	if types == null:
		return m.armor
	var found: GameItem = null
	for it in m.items:
		if it.readied and types.has(it.type) and types.slot(it.type) == ItemTypes.SLOT_ARMOR:
			found = it
	return found


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
#   is 0, 5 or 6, or (1-4) on a 1 in 4: d8, then d4 (on 1-7) or d2 + 4 (on 8). (Read from
#   GAME.OVR in side chat 2, 2026-11-13; this note had it the other way round.)
# - Target: it keeps its target while that one is standing; otherwise it picks one at
#   random among the enemies it has a line of sight to (walls block; figures don't), or
#   among all enemies if it sees none. No target: it guards.
# - Each action: a monster attacks a random adjacent enemy (its own target is ignored once
#   adjacent, as in the original: d count, even for one, GAME.OVR 0xB951); a party member
#   attacks its target if adjacent, else a random adjacent enemy. Lists of figures go
#   nearest first (_by_distance). With no enemy adjacent it steps towards its target: the
#   direction to the target turned by the pattern's offsets, the first of five that is free.
#   A step needs movement left at least its cost (GAME.OVR 0xB235; side chat 2 corrected
#   "the computer never spends its last half-move"). Stepping straight back counts as a failure, as does finding no step; after
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


## Can figure i attack figure j (GAME.OVR 0x13880: the effect dispatcher's category 1 on the
## target, then category 0 on the attacker, either setting DS:0x681E; Combat Chat 4): not a
## figure under Invisibility (0x19) unless the attacker sees invisible (0x18, Tyranthraxus),
## nor one under Disappearance (0x47); a vampire (0x7E) not one with a readied mirror or wooden
## holy symbol. (0x25, the phase spider's blink, also refuses when its fight record's +3 is
## above 0: not built.)
func targetable(i: int, j: int) -> bool:
	if i == j:
		return true
	var a: PartyMember = combatants[i].who
	var t: PartyMember = combatants[j].who
	if t.has_affect(0x19) and not a.has_affect(0x18):
		return false
	if t.has_affect(0x47):
		return false
	return not SpecialAffects.repels(a, t)


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
		if not field.see_through(cur.x, cur.y):
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


## Is j within `reach` squares of i with a clear line (1 = adjacent)? As the original checks
## a kept target (GAME.OVR 0xB88C-0xB8F8): from the two figures' own squares (their top-left
## cells, 0x31321 / 0x31349), not their closest cells: a clear line (0x2FF74) whose length in
## half-moves, halved, is at most the reach. (Lab, side chat 5: Brother Sean, beside a
## basilisk's second cell, picked again with a d1 at 0xB951.)
func _within(i: int, j: int, reach: int) -> bool:
	var a: Vector2i = combatants[i].cell
	var b: Vector2i = combatants[j].cell
	return line_steps(a, b).y == 1 and line_steps(a, b, false).x / 2 <= maxi(reach, 1)


## Keeps the combatant's target if it still stands and can be attacked, else picks a new one
## (GAME.OVR 0x15FDF, Combat Chat 4): first among the enemies in sight, then, if that found
## nobody, among all of them; each pass up to 20 tries of a die the size of the list, a figure
## that can't be attacked (targetable) struck off and the die rolled again (its size kept),
## until the list is empty. (Check 5's Tyranthraxus drew his d6 twice at 0x160DB: draw 794.)
func find_target(i: int) -> bool:
	var c: Dictionary = combatants[i]
	var keep: int = c.get("target", -1)
	if _enemy_of(c, keep) and targetable(i, keep):
		return true
	c.target = -1
	var seen: Array[int] = []
	var all: Array[int] = []
	for j in combatants.size():
		if _enemy_of(c, j):
			all.append(j)
			if clear_line(c, combatants[j]).y == 1:
				seen.append(j)
	for blind in [false, true]:
		var pool: Array[int] = (all if blind else seen).duplicate()
		if pool.is_empty():
			continue
		_by_distance(c, pool, blind)
		if OS.has_environment("APDBG"):
			var ps := ""
			for j in pool:
				ps += " %d@%s" % [j, combatants[j].cell]
			print("   @%d find_target %d at %s seen %d pool%s" % [TpDice.calls, i, c.cell, seen.size(), ps])
		if SmartQuick.smart(self, i):
			var left: Array[int] = pool.filter(func(j): return targetable(i, j))
			if not left.is_empty():
				c.target = SmartQuick.weakest(self, i, left)
				return true
			continue
		var n := pool.size()
		var tries := 20
		while tries > 0 and n > 0:
			tries -= 1
			var k := roll(1, n, "%s picks a target" % c.who.name) - 1
			if pool[k] < 0:
				continue
			if targetable(i, pool[k]):
				c.target = pool[k]
				return true
			pool[k] = -1
			if pool.all(func(j): return j < 0):
				n = 0
	return false


## The original lists figures nearest first (GAME.OVR 0x3045B builds the list of every
## figure in sight in combatant order, 0x2FB80 sorts it, then the caller keeps the ones it
## wants; read in side chat 2): the distance in half-moves (2 a straight step, 3 a diagonal
## one) between the closest cells; the sort is an exchange sort (each entry against every
## later one) that swaps when the later one is nearer, or equally near with a lower direction
## (wedge_dir from the chooser) unless that one is diagonal and the other straight.
## What goes into the sort (lab, Combat Chat 1, fitted to all 230 target picks of the kobold
## net trap): every standing figure in sight, both sides, and the chooser itself (distance 0,
## direction 0, so it moves to the front and the figures it passes change places); the caller
## then keeps the ones it wants. With no enemy in sight (`any_sight`, find_target's fallback)
## every standing figure goes in, seen or not. Side chat 6's "enemies alone" matched more
## picks than ours did then (it left the chooser out), 33 differing ties against 1 now.
func _by_distance(c: Dictionary, list: Array[int], any_sight := false) -> void:
	var me := combatants.find(c)
	var full: Array = []          # [index, distance, direction]
	for j in combatants.size():
		if combatants[j].down and j != me:
			continue
		if j != me and not (j in list) and not any_sight and clear_line(c, combatants[j]).y != 1:
			continue
		# The distance and direction come from the nearest pair of cells with a clear line between
		# them (GAME.OVR 0x3045B: each pair through 0x3FF74, the least distance kept with its pair);
		# with none clear, the nearest pair. (Combat Chat 7, 2:9: an ettin on 33,19-33,20 sees
		# Phineas at 29,12 only from its lower cell: 20, not 18.)
		var pr := closest(c, combatants[j])
		if j != me:
			var best_r := 1 << 30
			for p in cells(c):
				for q in cells(combatants[j]):
					if line_steps(p, q).y == 1:
						var r := line_steps(p, q, false).x
						if r < best_r:
							best_r = r
							pr = [p, q]
		var d: Vector2i = (pr[1] - pr[0]).abs()
		full.append([j, 2 * (maxi(d.x, d.y) - mini(d.x, d.y)) + 3 * mini(d.x, d.y), wedge_dir(pr[0], pr[1])])
	for a in range(full.size() - 1):
		for b in range(a + 1, full.size()):
			var x: Array = full[a]
			var y: Array = full[b]
			var swap: bool = y[1] < x[1]
			if y[1] == x[1] and y[2] < x[2] and not (y[2] % 2 > x[2] % 2):
				swap = true
			if swap:
				full[a] = y
				full[b] = x
	var keep := list.duplicate()
	list.clear()
	for e in full:
		if e[0] in keep:
			list.append(e[0])
	for j in keep:            # (anyone the scan left out keeps its place at the end)
		if not (j in list):
			list.append(j)


## `list` in the order GAME.OVR 0x3045B gives figures seen from a square (an area spell's aim point, 0x14A64:
## the area's figures, its target list 0x6C91 in that order): nearest first, the distance to each figure's
## nearest cell with a clear line, ties by direction as in _by_distance (Combat Chat 33, the spell lab's Slow:
## a level 1 caster's one figure is the aimed kobold, not the first in figure order).
func by_distance_from(cell: Vector2i, list: Array[int]) -> void:
	var full: Array = []
	for j in list:
		var best_r := 1 << 30
		var pr := [cell, combatants[j].cell]
		for q in cells(combatants[j]):
			if line_steps(cell, q).y == 1:
				var r := line_steps(cell, q, false).x
				if r < best_r:
					best_r = r
					pr = [cell, q]
		var d: Vector2i = (pr[1] - pr[0]).abs()
		full.append([j, 2 * (maxi(d.x, d.y) - mini(d.x, d.y)) + 3 * mini(d.x, d.y), wedge_dir(pr[0], pr[1])])
	for a in range(full.size() - 1):
		for b in range(a + 1, full.size()):
			var x: Array = full[a]
			var y: Array = full[b]
			var swap: bool = y[1] < x[1]
			if y[1] == x[1] and y[2] < x[2] and not (y[2] % 2 > x[2] % 2):
				swap = true
			if swap:
				full[a] = y
				full[b] = x
	list.clear()
	for e in full:
		list.append(e[0])


## A figure's movement for the round (GAME.OVR 0x1291E): a party figure's gets the script's
## modifier (0x6E72), added as a byte; anything outside 1-96 becomes 1.
func _round_movement(m: PartyMember) -> int:
	var mv := m.movement
	if not m.is_monster:
		mv = (mv + party_move_mod) & 0xFF
	return mv if mv >= 1 and mv <= 0x60 else 1


## The script's to-hit modifier for an attacker (GAME.OVR 0x2BBF2).
func script_hit_mod(m: PartyMember) -> int:
	return monster_hit_mod if m.is_monster else party_hit_mod


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
	# GAME.OVR 0xABF0 (read in side chat 2; ours had the d8 and the keep rule the other way
	# round): 0, 5 or 6 is always rerolled, 1-4 on a d4 of 1; d8, then 8: d2 + 4, else d4.
	if p == 0 or p > 4 or roll(1, 4, "%s keeps its pattern?" % c.who.name) == 1:
		var r := roll(1, 8, "%s pattern" % c.who.name)
		p = roll(1, 2, "%s pattern" % c.who.name) + 4 if r == 8 else roll(1, 4, "%s pattern" % c.who.name)
	c.pattern = p


# --- Turning undead ----------------------------------------------------------------------
# Clerics, and paladins from 3rd level as a cleric two levels lower, can try once a fight
# (TURN on the fight menu; quick clerics do it when undead are in sight). As GAME.OVR 0x13965
# does it (Combat Chat 5, the graveyard's spectres roll for roll): a d12 for how many, then
# one d20 for all of them. The column is the cleric level (record 0x96): 1-8, 9 for 9-13,
# else 10. Again and again it takes, from the nearest-first list of the standing figures in
# sight (0xBA:0x2433 with no range limit), the one with the lowest undead kind (record 0x76,
# above 0; 1 skeleton, 2 zombie, 3 ghoul, 5 wight, 7 wraith, 8 mummy, 9 spectre, 10 vampire)
# not yet turned; the game's table (DS:0x447 + kind x 10 + column) gives a value: the d20
# must reach its size, or the turning stops; above 0 the figure IS TURNED (it runs), 0 or
# below it IS DESTROYED (gone, status 8). Each success spends one of the d12; a destroyed one
# gives it back while the six extra last. None: "NOTHING HAPPENS...".
const TURN_VALUES := [
	[],
	[10, 7, 4, 1, 1, 0, 0, -1, -1, -1],
	[13, 10, 7, 1, 1, 0, 0, 0, -1, -1],
	[16, 13, 10, 4, 1, 1, 0, 0, 0, -1],
	[19, 16, 13, 7, 4, 1, 1, 0, 0, -1],
	[20, 19, 16, 10, 7, 4, 1, 1, 0, 0],
	[99, 20, 19, 13, 10, 7, 4, 1, 1, 0],
	[99, 99, 20, 16, 13, 10, 7, 4, 1, 0],
	[99, 99, 99, 20, 16, 13, 10, 7, 4, 1],
	[99, 99, 99, 99, 20, 16, 13, 10, 7, 1],
	[99, 99, 99, 99, 99, 20, 16, 13, 10, 4]]


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
	var m: PartyMember = c.who
	var count := roll(1, 12, "how many undead")
	var d20 := roll(1, 20, "%s turns undead" % m.name)
	var lv := m.level_in(0)
	var col := lv if lv >= 1 and lv <= 8 else (9 if lv >= 9 and lv <= 13 else 10)
	var extra := 6
	var any := false
	while count > 0:
		var j := _turn_pick(i)
		if j < 0:
			break
		var e: Dictionary = combatants[j]
		var kind: int = clampi(int(e.who.raw[0x76]), 1, TURN_VALUES.size() - 1)
		var v: int = TURN_VALUES[kind][col - 1]
		if d20 < absi(v):
			break
		any = true
		if v > 0:
			e.turned_undead = true
			e.fleeing = true
			message.emit("%s IS TURNED" % e.who.name)
		else:
			e.down = true
			(e.who as PartyMember).hp = 0
			(e.who as PartyMember).status = LevelDrain.STATUS_GONE
			message.emit("%s IS DESTROYED" % e.who.name)
		if extra > 0:
			extra -= 1
		count -= 1
		if count == 0 and extra > 0 and v < 0:
			count += 1
	if not any:
		message.emit("NOTHING HAPPENS...")   # the original's line (lab: a turn at Ferran Martinez)
	c.moves = 0
	c.attacks = 0


## 0x13B4C: the next figure to turn (-1: none).
func _turn_pick(i: int) -> int:
	var list: Array[int] = []
	for j in combatants.size():
		var e: Dictionary = combatants[j]
		if not e.down and (j == i or clear_line(combatants[i], e).y == 1):
			list.append(j)
	_by_distance(combatants[i], list)
	var best := 13
	var pick := -1
	for j in list:
		var e: Dictionary = combatants[j]
		var raw: PackedByteArray = (e.who as PartyMember).raw
		var kind: int = raw[0x76] if raw.size() > 0x76 else 0
		if e.get("turned_undead", false) or kind <= 0 or kind >= best:
			continue
		best = kind
		pick = j
	return pick


# --- Morale, fleeing and surrender -------------------------------------------------------
# As the original does it (rules as documented by Pilgrim's reconstruction; names of the
# script variables from ssi-engine; "KOBOLD SURRENDERS" seen in the lab):
# - Each computer-run figure (a monster, or an NPC/QUICK member with morale over 127) checks its morale at the start of its turn. Its morale is
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

## The fastest figure of a side still in the fight, in whole squares (GAME.OVR 0x15103: the round's
## movement, 0x1291E, halved; Combat Chat 16, p11t1 draw 5430: a goblin guard leaving the field drew the
## d2 at 0x134C6 where ours, comparing whole movements, let it go).
func _fastest(team: int) -> int:
	var best := 0
	for c in combatants:
		if c.team == team and not c.down:
			best = maxi(best, _round_movement(c.who as PartyMember) >> 1)
	return best


## A figure's own speed for the same comparisons (morale 0xBDC4, the getaway 0x1348E): the round's
## movement halved.
func _speed(m: PartyMember) -> int:
	return _round_movement(m) >> 1


## The morale check (see above). Returns "", "flee" or "surrender".
func _morale_check(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	# The arena's double (morale 0xB2) takes this same test (Combat Chat 30, main's 3:11 ready check:
	# ROLF hurt by 1 fought on in the original, draw 1021; ours had it run once hurt).
	# GAME.OVR 0x0BC97 runs for every computer-run figure with morale over 127, on either side
	# (Combat Chat 9: DIRTEN, an NPC with the party, 0x84 = 0xFF, surrenders on his first turn
	# at 4:10 9,1 and Tyranthraxus). The side's morale (0xBDA5) can hold only a monster-side
	# figure (record 0x10E != 0); the enemies' speed is the other side's (0x15103).
	if m.morale < 0x80 or m.hp_max <= 0:
		return ""
	var own := (m.morale & 0x7F) * 2
	if own > 102:
		own = 0
	var lost := 100 - (m.hp * 100) / m.hp_max
	if not (own < lost or own == 0):
		return ""
	if c.team == 1 and not (enemy_health < 100 - morale_base or enemy_health == 0):
		return ""
	if _fastest(1 - c.team) <= _speed(m):
		return "flee"
	if m.stats.size() > 1 and m.stats[1] > 5:
		return "surrender"
	return ""


## One step of a running combatant. Returns "moved", "retry", "gone", "blocked", "stop" or "end" (the turn ends).
func _flee_step(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if c.moves / 2 <= 0:
		# GAME.OVR's run loop (0xB75F) steps only while the movement is above 0; out of it, the action
		# goes on to its blow (`fleeing_was`). With one half-move left the step (0xB3B2) ends the turn
		# instead (0xBB0F: on guard, or done with a missile weapon) and the action strikes nothing
		# (Player 23's p22c4, draw 1745: a KOBOLD LEADER stopped with 1 left; ours shot DORN).
		return "stop" if c.moves <= 0 else "end"
	var base := flee_dir if c.team == 1 else (flee_dir + 4) % 8
	# The d2 becomes the figure's pattern (GAME.OVR 0xB49A): the next turn's pattern check reads it.
	c.pattern = roll(1, 2, "%s runs" % m.name)
	var turns: Array = PATTERN_TURNS[c.pattern - 1]   # patterns 1-2 (rows 0-1)
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
			# A step straight back is a failure too (0xB5A7), but the step is still taken.
			if (dir + 4) % 8 == c.last_step and _step_failed(i):
				return "stop"
			c.last_step = dir
			return "moved" if step(dir) == "moved" else "stop"
	# No step fits (GAME.OVR 0xB5CA, the same code as an approach; Combat Chat 5, the
	# graveyard's turned spectre): a failure, and the run goes on with a new d2 unless the
	# failures end the moving.
	if _step_failed(i):
		return "stop"
	return "retry"


## A failed step (all five directions blocked, or straight back): the pattern moves on; the
## second clears the target and picks again (none: guard), the third ends the movement.
## True: this turn's moving is over.
func _step_failed(i: int) -> bool:
	var c: Dictionary = combatants[i]
	c.fails += 1
	c.pattern = c.pattern % 6 + 1
	if c.fails > 1:
		c.target = -1
		if c.fails > 2:
			c.moves = 0
			return true
		if not find_target(i):
			guard(i)
			return true
	return false


func _gets_away(i: int) -> bool:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	var foes := _fastest(1 - c.team)
	# GAME.OVR 0x1346F: first the list of the other side's figures in sight (START.EXE 0xBA:0x2433 with
	# range 0xFF: 0x3045B's gather, each pair of cells through 0x3FF74's clear line); with none, away at
	# once, no speeds, no dice (Player 18, p18a5 draw 10129: a goblin guard leaving Podol's field out of
	# everyone's sight; ours compared speeds and drew the d2).
	var seen := false
	for j in combatants.size():
		var o: Dictionary = combatants[j]
		if o.team != c.team and not o.down and clear_line(c, o).y == 1:
			seen = true
			break
	var away := not seen or foes < _speed(m)
	if not away and foes == _speed(m):
		away = roll(1, 2, "%s gets away?" % m.name) == 1
	if away:
		# Still counted in the fight (DS:0x6814, START.EXE 0xBA:0x23DB) until the next recount: the
		# round's end or a figure falling (CombatSpells._enemy_left; Combat Chat 7, 2:9's last ettin).
		c.away_round = round_no
		c.away_fallen = fallen_count()
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
	# GAME.OVR 0xB235 (side chat 2): the step is allowed when the movement left is at least its
	# cost (2, or 3 diagonally); the original's computer does spend its last half-moves (lab:
	# Phineas used all 20 of his).
	var cost := 3 if dir % 2 == 1 else 2
	# Into a Stinking Cloud (ground 0x1E) the step costs the moves left + 1, so the computer never takes it,
	# unless the mover already has effect 0x20, 0x1E, 0x6F or 0x7D (GAME.OVR 0xB304-0xB375; Combat Chat 34:
	# the spell lab's Slums orcs walked round the cloud).
	if magic and field != null:
		var in_cloud := false
		for p in cells_at(c.cell + DIRS[dir], int(c.get("fp", 1))):     # every cell of a large figure
			if field.tile(p.x, p.y) == CombatSpells.CLOUD_GROUND:
				in_cloud = true
		if in_cloud:
			var m: PartyMember = c.who
			if not (m.has_affect(0x20) or m.has_affect(0x1E) or m.has_affect(0x6F) or m.has_affect(0x7D)):
				return false
	return cost <= c.moves


## One step towards the target. Returns "moved", "retry" or "end".
func _approach(i: int) -> String:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	if c.moves / 2 <= 0 or (m.class_id == CLASS_MAGE and m.armor == null):
		guard(i)
		return "end"
	# The base direction is GAME.OVR 0x14E38's (called at 0xB47D): from the mover's own square
	# to the target's (their positions 0x5F27/0x5F28; a large figure's first cell), not between
	# their nearest cells (Combat Chat 7, the troll fight: Brother Sean at 28,14 went NE for a troll
	# on 24,10-24,11, its own square NW of him, where ours aimed W at 24,11).
	var pair := [c.cell, combatants[c.target].cell]
	var base := wedge_dir(pair[0], pair[1])
	# Pattern p is row p - 1 (the original's table at DS:0x02AE, read in side chat 2: pattern p
	# takes bytes p * 5 + 1 .. p * 5 + 5; ours read the row of p + 1).
	var turns: Array = PATTERN_TURNS[c.pattern - 1]
	var k := 0
	while k < 5 and not _can_step(c, (base + int(turns[k])) % 8):
		k += 1
	var dir := (base + int(turns[k])) % 8
	if OS.has_environment("APDBG"):       # lab: APDBG=1 prints each computer step's choice
		var tried := ""
		for kk in k:
			var dd := (base + int(turns[kk])) % 8
			var f := fits(i, c.cell + DIRS[dd])
			tried += " d%d:%s/%d" % [dd, f[0], f[1]]
		print(tried)
		print("   @%d approach %d at %s target %d at %s base %d pattern %d k %d dir %d last %d fails %d moves %d pair %s" % [TpDice.calls, i, c.cell, c.target, combatants[c.target].cell, base, c.pattern, k, dir, c.last_step, c.fails, c.moves, pair])
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
## Lab (PlayBot): a player's call for a computer-run party member at the start of its turn:
## party_judge(combat, i) returns "flee" to run for the edge, as a player would.
static var party_judge: Callable


func ai_act() -> bool:
	if active < 0:
		return false
	var c: Dictionary = combatants[active]
	if c.down:
		return false
	if not c.get("ai", false):
		# Lab (`magicat=<draw>`): the original read the replay's Alt-M at this turn's opening poll
		# (GAME.OVR 0xABDC calls 0xBB81, before the item and spell weighing).
		if not magic_at_draws.is_empty() and TpDice.on and TpDice.calls >= magic_at_draws[0]:
			magic_at_draws.pop_front()
			magic_on = true
		c.powers_done = false
		_ai_begin(active)
		_turn_start_powers(active)
		if c.down:
			return false
		if c.get("drank", false):
			c.drank = false
			return false
		# The original's QUICK never bandages (lab, side chat 2: Bakshi lay dying through the
		# rest of the orc fight while Thrender and Brother Sean fought on). The bot still does,
		# as a player would from the DONE menu (party_judge is its hook).
		var smart := SmartQuick.smart(self, active)
		if c.team == 0 and (party_judge.is_valid() or quick_bandages or smart) and bandage():
			return false
		choose_weapon(active)
		var morale := _morale_check(active)
		if c.team == 0 and party_judge.is_valid() and party_judge.call(self, active) == "flee":
			morale = "flee"
		elif SmartQuick.applies(self, active) and morale == "" and SmartQuick.hopeless(self):
			morale = "flee"
		if morale == "surrender":
			var sm: PartyMember = c.who
			c.down = true
			c.surrendered = true
			sm.status = PartyMember.STATUS_UNCONSCIOUS
			sm.hp = 0
			# Counted among the enemies left until the next recount, as one that got away
			# (CombatSpells._enemy_left).
			c.surrender_round = round_no
			c.surrender_fallen = fallen_count()
			message.emit("%s SURRENDERS" % sm.name)
			return false
		# After its morale check (a goblin that surrendered drew nothing more) the original's
		# computer turn weighs its items with d7 tries (GAME.OVR 0xAFA4), then turning undead
		# (0xADC3), then its spells with d7 tries (0xB105; the d7 is drawn even with nothing
		# memorized).
		var spell_d7 := -1
		var item_d7 := roll(1, 7, "%s weighs an item" % c.who.name)
		if magic and not (smart and SmartQuick.order(self, active) in [SmartQuick.NOSPELL, SmartQuick.MELEE]) \
				and magic.ai_use_item(active, item_d7):
			return false
		# A spell begun last turn goes off now (GAME.OVR 0xACEE, after the item weighing).
		if magic and magic.resolve_pending(active):
			return false
		c.fleeing = morale == "flee" or c.get("turned_undead", false)
		if c.team == 0 and not c.get("turned_undead", false) and can_turn(active):
			turn_undead(active)
			return false
		spell_d7 = roll(1, 7, "%s weighs a spell" % c.who.name)
		if c.get("turned_undead", false):
			pass
		elif c.fleeing:
			message.emit("%s FLEES IN PANIC" % c.who.name)
		elif smart and SmartQuick.order(self, active) in [SmartQuick.NOSPELL, SmartQuick.MELEE]:
			pass                       # B3: this one doesn't cast
		elif smart and (SmartQuick.heal(self, active) or
				(SmartQuick.order(self, active) != SmartQuick.HEAL and SmartQuick.cast(self, active))):
			return false
		elif magic and not smart and magic.ai_cast(active, spell_d7):
			return false
		if not find_target(active):
			guard(active)
			return false
		# The action (GAME.OVR 0xB6FC) runs the powers category (0x0E: breath, spit) before a
		# runner's steps too (Combat Chat 8: Tyranthraxus failed his morale and breathed, seed
		# 12345678 draw 1216; ours ran).
		if c.get("fleeing", false) and c.moves > 0:
			c.powers_done = true
			_act_powers(active)
			if c.down or (c.moves <= 0 and c.attacks <= 0):
				return false
	if c.get("fleeing", false):
		var fr := _flee_step(active)
		if fr == "moved" or fr == "retry":
			return true
		c.fleeing_was = fr == "stop" and c.moves <= 0
		c.fleeing = false
		if fr == "end":
			guard(active)
			return false
		if fr == "gone" or fr == "blocked" or c.down:
			c.moves = 0
			c.attacks = 0
			return false
	# Out of movement while running, it strikes an enemy within reach at once (GAME.OVR
	# 0xB75F-0xB958: the action's run loop, then the blow's d-count pick; no target pick:
	# Combat Chat 5, the graveyard's turned spectre).
	var ran_out: bool = c.get("fleeing_was", false)
	c.fleeing_was = false
	while true:
		c.tries += 1
		if c.tries > 20 or c.down:
			guard(active)
			return false
		# The original's turn loop (GAME.OVR 0xAD72) finds a target first each time round
		# (0x15FDF: kept if it still stands, else a new pick); ours did only when nothing was in
		# reach (lab, side chat 5: Darkstar's dart killed its kobold mid-volley, and the next
		# dart's d17 target pick was missing).
		if not ran_out and not _enemy_of(c, c.get("target", -1)) and not find_target(active):
			guard(active)
			return false
		ran_out = false
		# Once an action (GAME.OVR 0xB6FC dispatches category 0x0E before its own loop of steps
		# and blows): at the turn's first step or blow and again after a kill (Combat Chat 8:
		# ours checked Tyranthraxus's breath before every step; seed 2468ace1 draw 910).
		if c.moves > 0 and _enemy_of(c, c.get("target", -1)) and not c.get("powers_done", false):
			c.powers_done = true
			_act_powers(active)
			if c.down:
				return false
			if c.moves <= 0 and c.attacks <= 0:
				return false
		var m: PartyMember = c.who
		var shooting: bool = m.weapon_ranged and m.missile_ready
		var reach: int = m.missile_range if shooting else 1
		var t: int = c.get("target", -1)
		# A monster strikes a random enemy within reach (d count, even for one; GAME.OVR
		# 0xB951); a party member its own target if in reach, else a random one. (Checked roll
		# for roll in side chat 2, with the target lists nearest first.)
		if not _enemy_of(c, t) or combatants[t].team == 0 or not _within(active, t, reach):
			t = -1
		if t < 0:
			# The ones to pick from: every enemy within reach, clear shot or not (GAME.OVR
			# 0xB90F, the same count as for spells; lab: Phineas's darts had four to pick
			# from where ours saw three). The target kept above needs a clear shot (0xB8DF).
			# A missile's list holds only figures in sight (lab, side chat 5: in the kobold caves
			# the original's count left out the one kobold in range behind a wall; START.EXE
			# 0x2433 counts the in-sight list 0x3DB:0x3E builds).
			var near: Array[int] = []
			for j in combatants.size():
				if _enemy_of(c, j) and (touching(c, combatants[j]) if reach <= 1 else
						range_of(c, combatants[j]) <= reach and clear_line(c, combatants[j]).y == 1):
					near.append(j)
			if near.is_empty():
				if not find_target(active):
					guard(active)
					return false
				if SmartQuick.applies(self, active) and ((not shooting and SmartQuick.hurt(self, active))
						or SmartQuick.stays(self, active)):
					guard(active)          # hurt, or ordered to HOLD / HEAL: it doesn't walk up (SmartQuick)
					return false
				var r := _approach(active)
				if r == "moved":
					return true
				if r == "end":
					return false
				continue
			_by_distance(c, near)
			if SmartQuick.smart(self, active):
				t = SmartQuick.weakest(self, active, near)
			else:
				t = near[roll(1, near.size(), "%s picks who to hit" % c.who.name) - 1]
			if OS.has_environment("APDBG"):
				var ns := ""
				for j in near:
					ns += " %s@%s" % [combatants[j].who.name, combatants[j].cell]
				print("   @%d hit list%s" % [TpDice.calls, ns])
			if shooting and not m.weapon_ranged_melee and enemy_adjacent(active):
				# Someone is next to it: it changes weapons, and that is its turn.
				choose_weapon(active)
				c.moves = 0
				c.attacks = 0
				return false
		if OS.has_environment("APDBG"):
			print("   @%d strike %s t %d attacks %d moves %d" % [TpDice.calls, c.who.name, t, c.attacks, c.moves])
		if c.attacks <= 0:
			return false
		c.target = t
		if sweep(active, t):
			# The sweep ends the action loop (0xB6FC) as "not done", so the turn loop (0xAD72)
			# finds a target once more (kept if the last one swept still stands, else a pick:
			# 6:1's d23 at draw 3563) before the turn ends (initiative 0: 0xBB0F).
			c.moves = 0
			if not _enemy_of(c, c.get("target", -1)):
				find_target(active)
			return false
		var moves_left: int = c.moves
		if shooting:
			shoot(active, t)
		else:
			attack(active, t)
		c.moves = 0
		if c.attacks <= 0 or not combatants[t].down:
			c.attacks = 0
			return false
		# The target fell with attacks to spare: the original's attack loop (GAME.OVR 0x13C01)
		# ends the turn (0xBA:0x2637, which clears the movement) only when no attacks are left, so
		# the turn loop goes on with the movement it had: a new target, the powers (a breath
		# check), a step and the next blow (Combat Chat 8: Tyranthraxus after BRAM fell, seed
		# 2468ace1 draw 907).
		c.moves = moves_left
		c.powers_done = false
		return true
	return false


# --- Monsters' powers outside the blow itself ---------------------------------------------
# The standing effects GAME.OVR runs at set moments (SpecialAffects has the full list):
# at the start of the fight (category 8), of each round (19), of a computer-run turn (14),
# and when a figure goes down (13).

func _dice(count: int, size: int) -> int:
	return roll(count, size, "power")


## Tyranthraxus (0x59; handler GAME.OVR 0x110EB, Combat Chat 4; read again in Combat Chat 8). The
## handler looks at DS:0x6822, which is the attack's d20 (0x2BBBF; 20 counts 100), as the attacker's
## and the target's earlier to-hit handlers left it (0x19 and 0x47 take 4), and the round counter
## DS:0x6DE3: with the counter 0 (ours' round 1) and that value 0 it clears bit 0x10 of the effect's
## power; otherwise, with the bit clear, the attack misses and the bit is set. A natural 1 runs no
## handlers. The fight's setup (0xE461 sets 0x6822 = 0, then category 8 runs 0x59 for each figure,
## 0xE536) clears the bit, so the first attack on him that rolls above 1 misses. Player 6's seed
## 2468ace1, draw 860: BRAM's 11 missed in the original (Combat Chat 4 had read 0x6822 as "another
## to-hit change" and cleared the bit through round 1).
func _free_miss(t: Dictionary, d20: int) -> bool:
	if d20 <= 1:
		return false
	var tm: PartyMember = t.who
	for a in tm.affects:
		if int(a.effect) != 0x59:
			continue
		var v := 100 if d20 == 20 else d20
		if tm.has_affect(0x19) or tm.has_affect(0x47):
			v -= 4
		if round_no <= 1 and v == 0:
			a.value = int(a.value) & 0x0F
			return false
		if (int(a.value) & 0x10) == 0:
			a.value = int(a.value) | 0x10
			return true
		return false
	return false


## The fight's setup (GAME.OVR 0xE400): DS:0x6822 = 0, then category 8 for every figure; for 0x59
## that clears its bit (see _free_miss).
func _setup_free_miss() -> void:
	for c in combatants:
		for a in (c.who as PartyMember).affects:
			if int(a.effect) == 0x59:
				a.value = int(a.value) & 0x0F


## Adds a condition the way the original's add-effect routine (GAME.OVR 0x2C540) does:
## immunities first, then the save; "IS UNAFFECTED" when either stops it.
func _afflict(j: int, effect: int, rounds: int, saved: bool, words: String) -> void:
	var tm: PartyMember = combatants[j].who
	# The effect goes on through the add-effect routine (GAME.OVR 0x2C540), saved or not, which runs
	# the race handlers for any effect: a half-elf draws its d100 even for fear's weakening
	# (Player 5's request, Combat Chat 7: ELWEN at Tyranthraxus, draw 743).
	var blocked := SpecialAffects.blocks(tm, effect, func(): return roll(1, 100, "resists"))
	if blocked or saved:
		message.emit("%s IS UNAFFECTED" % tm.name)
		return
	SpellCaster.add_affect(tm, effect, 0, rounds, 12)
	message.emit("%s %s" % [tm.name, words])


func _battle_start_powers() -> void:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		var m: PartyMember = c.who
		if m.has_affect(0x51):
			# Tyranthraxus's fear (GAME.OVR 0x10705): every enemy saves vs spells.
			for j in combatants.size():
				var t: Dictionary = combatants[j]
				if t.down or t.team == c.team:
					continue
				var saved := _save(t.who, 4, 0)
				# The tier by record 0x73, the highest level the character has had (0x10705).
				var tw: PartyMember = t.who
				var lvl: int = tw.raw[0x73] if tw.raw.size() > 0x73 else SpecialAffects.level_of(tw)
				if lvl <= 3:
					_afflict(j, SpecialAffects.PARALYZED, 0, saved, "IS PARALYZED WITH FEAR")
				elif lvl <= 5:
					_afflict(j, CombatSpells.EFFECT_CURSE, 0, saved, "IS WEAKENED BY FEAR")
		if m.has_affect(0x52):
			# A mummy's fear (0x10803), once a fight: save vs paralysis, +2 for humans, +1
			# when the side numbers six or more; else held 1d4 rounds.
			for e in combatants:
				var em: PartyMember = e.who
				em.affects = em.affects.filter(func(a): return int(a.effect) != 0x52)
			for j in combatants.size():
				var t: Dictionary = combatants[j]
				if t.down or t.team == c.team:
					continue
				var bonus := 0
				if _side_size(t.team) >= 6:
					bonus += 1
				if (t.who as PartyMember).race_id == 7:
					bonus += 2
				var saved := _save(t.who, 0, bonus)
				_afflict(j, SpecialAffects.PARALYZED, roll(1, 4, "fear rounds"), saved, "IS PARALYZED WITH FEAR")
		if m.has_affect(0x48):
			_hide(i)


func _side_size(team: int) -> int:
	var n := 0
	for c in combatants:
		if c.team == team:
			n += 1
	return n


## A thief who hides (0x48): 95% to be invisible for the round.
func _hide(i: int) -> void:
	var m: PartyMember = combatants[i].who
	if roll(1, 100, "%s hides" % m.name) <= 95:
		SpellCaster.add_affect(m, CombatSpells.EFFECT_INVISIBLE, 0, 1, 12)


func _round_start_powers() -> void:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if c.down:
			continue
		var m: PartyMember = c.who
		if m.has_affect(0x48):
			_hide(i)


## A troll's regeneration (0x62, GAME.OVR 0x1135B: +3 HP up to its most), at the round's end.
func _regenerate() -> void:
	for c in combatants:
		if c.down:
			continue
		var m: PartyMember = c.who
		if m.has_affect(0x62):
			m.hp = mini(m.hp + 3, m.hp_max)


## The powers' own clocks, a round at a time (in the original, effects that run out).
func _power_timers() -> void:
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		var m: PartyMember = c.who
		if int(c.regen_in) > 0:
			c.regen_in -= 1
			if c.regen_in == 0:
				SpecialAffects.add(m, [0x62])
		if int(c.revive_in) > 0 and c.down:
			c.revive_in -= 1
			if c.revive_in == 0 and not _revive(i, m.hp_max):
				c.revive_in = 1     # its square is taken: it tries again next round
		if int(c.dies_in) > 0 and not c.down:
			c.dies_in -= 1
			if c.dies_in == 0:
				m.hp = 0
				m.status = PartyMember.STATUS_DEAD
				c.down = true
				message.emit("%s FALLS DEAD" % m.name)


## A fallen party member's body on `cell`, or -1 (Combat Chat 4, GAME.OVR 0x157B9): a spell's
## aim on a square whose ground is 0x1F takes the member at that square from the fallen list
## (DS:0x66D6: party members only); an attack's aim never targets a body (0x15889). Under a
## Stinking Cloud the ground stays 0x1E, so no body is found there (ground 38 in ours).
func body_at(cell: Vector2i) -> int:
	if field != null and field.tile(cell.x, cell.y) == 38:
		return -1
	for d in combatants.size():
		var e: Dictionary = combatants[d]
		if e.down and not e.get("fled", false) and not e.who.is_monster and e.cell == cell:
			return d
	return -1


## Slow Poison's "back up" (Combat Chat 4): `_revive` with 1 hit point, for CombatSpells.
func stand_up(i: int, hp: int) -> bool:
	return _revive(i, hp)


## Gets a downed figure back up with `hp` (GAME.OVR 0x2C753), if its square is free.
func _revive(i: int, hp: int) -> bool:
	var c: Dictionary = combatants[i]
	for p in cells(c):
		if occupant(p, i) >= 0:
			return false
	var m: PartyMember = c.who
	m.status = PartyMember.STATUS_OKAY
	m.hp = hp
	c.down = false
	c.bleeding = 0
	message.emit("%s %s" % [m.name, "STANDS UP AND GRINS" if c.team == 1 else "GETS BACK UP"])
	return true


## The affects a figure loses as it goes down (GAME.OVR 0x2BEF4, the table DS:0xC14), before
## category 13 runs: among them a troll's regeneration (0x62) and its wait (0x3B, ours' regen_in),
## so a troll that stands up again must be wounded again and wait 3 rounds (Combat Chat 29: the
## troll fight seed 98e616ec, the original's troll down at draw 3086 where ours' kept 0x62).
const DOWN_STRIPS := [0x07, 0x0B, 0x1E, 0x1F, 0x20, 0x33, 0x34, 0x35, 0x36, 0x3A, 0x3B, 0x5F, 0x62,
		0x89, 0x4A, 0x4B]


## What happens as a figure goes down (0x12DE7 / 0xED1B: the strip, then category 13).
func _went_down(j: int) -> void:
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	tm.affects = tm.affects.filter(func(a): return not DOWN_STRIPS.has(int(a.effect)))
	t.regen_in = 0      # 0x3B
	t.dies_in = 0       # 0x5F
	if tm.has_affect(0x63) and tm.status in [PartyMember.STATUS_DYING, PartyMember.STATUS_UNCONSCIOUS]:
		# A wild boar fights on (0x1138B): back up with 6 less the rounds it bled.
		var hp := 6 if tm.status == PartyMember.STATUS_UNCONSCIOUS else maxi(6 - int(t.bleeding), 0)
		if hp > 0 and _revive(j, hp):
			t.dies_in = roll(1, 4, "boar rounds") + 1
			tm.affects = tm.affects.filter(func(a): return int(a.effect) != 0x63)
			return
	if tm.has_affect(0x64) and (int(t.last_kind) & (SpecialAffects.FIRE | SpecialAffects.ACID)) == 0:
		t.revive_in = roll(3, 6, "troll rounds")    # 0x11434, then 0x114C1
	if tm.has_affect(0x67) and tm.status != PartyMember.STATUS_RUNNING:
		tm.status = PartyMember.STATUS_RUNNING      # 0x1151A
		t.fled = true
		message.emit("%s TURNS GASEOUS AND ESCAPES" % tm.name)


## Turns `j` to stone (status 7), as the original's kill routine (0xECB3) does.
func stone(j: int) -> void:
	var t: Dictionary = combatants[j]
	var tm: PartyMember = t.who
	if tm.status in [PartyMember.STATUS_DEAD, SpecialAffects.STONED, SpecialAffects.GONE]:
		return
	message.emit("%s IS STONED" % tm.name)
	tm.status = SpecialAffects.STONED
	tm.hp = 0
	t.down = true
	_went_down(j)


## At the start of a computer-run turn: a mantis's grip and a stirge's drinking (the gazes,
## spit and breath are _act_powers, before each step or blow).
func _turn_start_powers(i: int) -> void:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	var gripping: int = c.get("gripping", -1)
	c["hits"] = 0
	if gripping >= 0:
		# The mantis attacks whoever it holds: one attack of 3d4 a turn (0x16281).
		if combatants[gripping].down:
			c.gripping = -1
		else:
			_extra_attacks(i, gripping, 1, 3, 4)
			c.moves = 0
			c.attacks = 0
			c["drank"] = true
			return
	var latched: int = c.get("latched", -1)
	if latched >= 0:
		# A stirge (0x4C/0x4B, GAME.OVR 0x10510 / 0x103CA) that has latched on drinks 1d4 at
		# the start of each of its turns instead of attacking, until it has had about 12
		# (its effect's 207 >> 4) or one of them falls.
		if combatants[latched].down:
			c.latched = -1
		else:
			message.emit("%s SUCKS SOME BLOOD" % m.name)
			var d := roll(1, 4, "blood")
			hurt(latched, d)
			if int(c.drink) > d:
				c.drink = int(c.drink) - d
			else:
				c.latched = -1
			c.moves = 0
			c.attacks = 0
			c["drank"] = true
			return


## Category 14 (GAME.OVR 0xB6FC calls it first, each time the computer's turn loop has found
## a target and has movement left, so before every step or blow): gazes, the ankheg's spit
## and Tyranthraxus's breath, at the figure it goes for. (Lab, side chat 5: a basilisk's
## first turn picked its target, then gazed; the save came before anything else.)
func _act_powers(i: int) -> void:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	var j: int = c.get("target", -1)
	if j < 0 or j >= combatants.size() or combatants[j].down:
		return
	var t: Dictionary = combatants[j]
	if m.has_affect(0x53):
		# Stoning gaze (0x10908): a readied Mirror turns it back on the gazer.
		message.emit("%s GAZES..." % m.name)
		var victim := j
		if m.has_affect(0x7F) and SpecialAffects.readied_with(t.who, SpecialAffects.WORD_MIRROR) != null:
			message.emit("%s REFLECTS IT!" % t.who.name)
			victim = i
		if not _save(combatants[victim].who, 1, 0):
			stone(victim)
		if c.down:
			return
	if m.has_affect(0x54) and not t.down and t.team != c.team and clear_line(c, t).y == 1:
		# A vampire's charming gaze (0x10AD2): save vs spells at -2.
		message.emit("%s GAZES..." % m.name)
		var tm: PartyMember = t.who
		var immune: bool = magic != null and magic.resists(tm, SpecialAffects.CHARM)
		if immune or _save(tm, 4, -2):
			message.emit("%s IS UNAFFECTED" % tm.name)
		else:
			t.team = c.team
			t.quick = true
			t.target = -1
			message.emit("%s IS CHARMED" % tm.name)
	if m.has_affect(0x79) and not t.down and roll(1, 100, "spit?") <= 25 and range_of(c, t) < 4:
		# An ankheg's acid spit (0x11877), once: 8d4, half on a save vs breath. The spit is its whole turn: the
		# original ends the turn (0xBA:0x2637 at 0x118C6) before the message (Combat Chat 32: Player 30's p25j10,
		# draw 4108: ours went on to a bite).
		c.moves = 0
		c.attacks = 0
		message.emit("%s SPITS ACID" % m.name)
		var dmg := roll(8, 4, "acid spit")
		if _save(t.who, 3, 0):
			dmg /= 2
		m.affects = m.affects.filter(func(a): return not int(a.effect) in [0x79, 0x50])
		if dmg > 0:
			message.emit(SpecialAffects.damage_words(t.who.name, dmg, SpecialAffects.ACID))
			hurt(j, dmg, SpecialAffects.ACID)
	# Tyranthraxus's breath (GAME.OVR 0x2A0F1): the 50% d100 (it breathes on 51-100) only once the round counter
	# DS:0x6DE3 is past 0 (it counts at each round's end, so not before or in round 1: ours'
	# round_no is that counter + 1); then the breath aims as a spell does, with a fresh target
	# pick (0x15FDF from the spell's aim, which becomes its target). Lab, Combat Chat 4: check
	# 5's Tyranthraxus drew his d6 twice in round 1 and no d100 (draws 793-794).
	if m.has_affect(0x58) and not t.down and (round_no <= 1 or roll(1, 100, "breathe?") > 50):
		c.target = -1
		if find_target(i):
			_breathe(i, int(c.target))


## Tyranthraxus's breath (GAME.OVR 0x2A0F1; Combat Chat 4): its max HP (record 0x32) in
## lightning, half on a save vs breath, as Lightning Bolt goes (0x298D4, 0x29973): it starts on
## the square beside it towards its target (one step each way, past its own 2x2 body), hits
## the figure there, then walks a Bresenham line (0x2FCF2 / 0x2FE1E: 2 a straight step, 3 a
## diagonal one) on from there, away from it, with 20 half-moves; it stops at each new figure
## (hit), at a wall (it bounces back: a new line from the wall the other way, the budget less
## the half-moves walked) or when the budget is spent. Three breaths a fight (the effect's power
## counts down from 0xFF). Check 5's breath at draw 1147 hit three where ours' straight line hit two.
func _breathe(i: int, j: int) -> void:
	var c: Dictionary = combatants[i]
	var m: PartyMember = c.who
	message.emit("%s BREATHES!" % m.name)
	var dmg := m.hp_max
	var from: Vector2i = c.cell
	var to: Vector2i = combatants[j].cell
	var aim := Vector2i(from.x + signi(to.x - from.x), from.y + signi(to.y - from.y))
	if aim.x == from.x + 1:
		aim.x += 1
	if aim.y == from.y + 1:
		aim.y += 1
	_bolt_hit(aim, dmg)
	_bolt(from, aim, 10, dmg)
	for a in m.affects:
		if int(a.effect) == 0x58:
			if int(a.value) > 0xFD:
				a.value = int(a.value) - 1
			else:
				m.affects.erase(a)
			break
	c.moves = 0
	c.attacks = 0


## The bolt's hit on one square (0x298D4): the figure standing there, if any, takes `dmg`
## (half on a save vs breath). True if the square is a wall.
func _bolt_hit(p: Vector2i, dmg: int) -> bool:
	var k := occupant(p)
	if k >= 0:
		var t: Dictionary = combatants[k]
		var hit := dmg / 2 if _save(t.who, 3, 0) else dmg
		hit = SpecialAffects.element_damage(t.who, SpecialAffects.ELECTRIC, hit)
		# The hit's damage type is electricity and magic (DS:0x6819 = 0x0C), so the damage
		# routine (0x2C22E) runs magic resistance (0x11570) after the save: Tyranthraxus's own
		# breath bouncing back on him draws a d100 and he takes nothing (Player 6, seed
		# 12345678, draws 786 and 788).
		if hit > 0 and SpecialAffects.magic_resists(t.who, 0,
				func(): return roll(1, 100, "%s resists" % t.who.name)):
			hit = 0
		if hit <= 0:
			message.emit("%s IS UNAFFECTED" % t.who.name)
			return field != null and field.tile(p.x, p.y) > 0 and not field.walkable(p.x, p.y)
		message.emit(SpecialAffects.damage_words(t.who.name, hit, SpecialAffects.ELECTRIC | SpecialAffects.MAGIC))
		hurt(k, hit, SpecialAffects.ELECTRIC | SpecialAffects.MAGIC)
	return field != null and field.tile(p.x, p.y) > 0 and not field.walkable(p.x, p.y)


## The bolt's walk on from `aim` (0x29973): see _breathe. `from` is the caster's square.
func _bolt(from: Vector2i, aim: Vector2i, reach: int, dmg: int) -> void:
	if from == aim:
		return
	var budget := reach * 2
	var sgn := 1
	var last := occupant(aim)
	while budget > 0:
		var end := aim + (aim - from) * sgn * budget
		var w := _walker(aim, end)
		while true:
			while true:
				if w.cur == end:
					break
				var moved := _walk_step(w)
				var fig := occupant(w.cur)
				var ground: int = field.tile(w.cur.x, w.cur.y) if field != null else 1
				if not moved or (fig >= 0 and fig != last) or ground <= 0 \
						or (field != null and not field.walkable(w.cur.x, w.cur.y)):
					break
				if int(w.steps) >= budget:
					break
			var cur: Vector2i = w.cur
			last = occupant(cur)
			var ground2: int = field.tile(cur.x, cur.y) if field != null else 1
			if ground2 <= 0:
				budget = 0
			var wall := _bolt_hit(cur, dmg)
			if wall:
				aim = cur
				sgn = -sgn
				last = -1
			budget = 0 if int(w.steps) >= budget else budget - int(w.steps)
			if wall or budget <= 0:
				break
	return


## A Bresenham walker as the original's (0x2FCF2): x-major only when |dx| > |dy|.
func _walker(a: Vector2i, b: Vector2i) -> Dictionary:
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var w := {"a": a, "b": b, "dx": dx, "dy": dy, "sx": signi(b.x - a.x), "sy": signi(b.y - a.y),
		"cur": a, "steps": 0}
	if dx > dy:
		w.err = dy * 2 - dx
		w.d1 = (dy - dx) * 2
		w.d2 = dy * 2
	else:
		w.err = dx * 2 - dy
		w.d1 = (dx - dy) * 2
		w.d2 = dx * 2
	return w


## One step (0x2FE1E): false at the end of the line.
func _walk_step(w: Dictionary) -> bool:
	var cur: Vector2i = w.cur
	if int(w.dx) > int(w.dy):
		if cur.x == w.b.x:
			return false
		if int(w.err) >= 0:
			cur.y += int(w.sy)
			w.err = int(w.err) + int(w.d1)
			w.steps = int(w.steps) + 3
		else:
			w.err = int(w.err) + int(w.d2)
			w.steps = int(w.steps) + 2
		cur.x += int(w.sx)
	else:
		if cur.y == w.b.y:
			return false
		if int(w.err) >= 0:
			cur.x += int(w.sx)
			w.err = int(w.err) + int(w.d1)
			w.steps = int(w.steps) + 3
		else:
			w.err = int(w.err) + int(w.d2)
			w.steps = int(w.steps) + 2
		cur.y += int(w.sy)
	w.cur = cur
	return true

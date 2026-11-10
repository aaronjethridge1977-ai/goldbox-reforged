class_name CombatScreen
extends Control
## The combat screen: a 7 x 7 window onto the battlefield (as the original shows it), the
## selected combatant's details on the right, and the command line below.
##
## Setting up (test battles):
##   Arrows: move the view    Tab: next combatant (the view centres on them)
##   PgUp/PgDn: previous/next set battle of this area    +/-: monsters nearer/further
##   F: fight    Esc: leave
## Fighting (rules in Combat; the party here is a copy, so test fights hurt nobody):
##   Arrows, Home/PgUp/End/PgDn (or the keypad): step, or attack the enemy in that direction
##   Space: done    Q: let the computer fight for this character    Esc: leave
## The monsters come from the area's own set battles (LOAD_MON ... COMBAT in its event
## script: monster, count, icon); an area without any falls back to each monster in turn.

signal closed
## After a real (event) fight: 1 = the party won, 2 = the party fell.
signal finished(result: int)

const VIEW_CELLS := 7
const CELL := 24
const SCALE := 3

var _field: Battlefield
var _art: CombatArt
var _party: Array[PartyMember] = []
var _monsters: Array[PartyMember] = []
var _combatants: Array = []      # [{who: PartyMember, team: 0 party / 1 monsters, cell: Vector2i, icon: Image}]
var _selected := 0
var _last_dropped: Array[GameItem] = []
var _aiming := false          # AIM: choosing a target
var _aim_list: Array[int] = []
var _aim_index := 0
# CAST: "" (not casting), "choose" (the spell list) or "aim" (where it goes)
var _casting := ""
var _spell_list: Array[int] = []
var _spell_index := 0
var _spell_id := 0
var _spell_cell := Vector2i.ZERO
var _spell_picks: Array[int] = []
var _view := Vector2i.ZERO       # top-left cell of the 7x7 window
var _facing := 0
var _morale_base := 99      # the encounter's morale (from the script)
var _surprise := 0          # the script's ambush flag
var _px := 0
var _py := 0
var _distance := 0
var _mon_file := 1
var _encounters: Array = []      # [{monsters: [[id, count, picture]], text}]
var _enc_index := 0
var _pictures: Array[int] = []   # icon id for each of _monsters
var _types: ItemTypes
var _game_path := ""

var _combat: Combat = null
var _messages := PackedStringArray()
var _ai_timer: Timer
var _result := 0
var _event_fight := false

var _picture: TextureRect
var _info: Label
var _prompt: Label


## Starts a test battle at map square (px, py) facing `facing` (0..3 = N E S W) against
## the set battles in `script` (monsters from MON<mon_file>CHA).
func open_test(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, script: EclScript) -> void:
	_game_path = game_path
	_field = Battlefield.build(map, px, py)
	_px = px
	_py = py
	_art = CombatArt.load_set(game_path)
	_party = party
	_morale_base = 99
	_surprise = 0
	_facing = facing
	_mon_file = mon_file
	if _types == null:
		_types = ItemTypes.load_file(game_path)
	_encounters.clear()
	if script:
		for e in script.encounters():
			var rows := []
			for row in e.monsters:
				if row[0] >= 0:
					rows.append([row[0], maxi(row[1], 1), row[2] if row[2] >= 0 else row[0]])
			if not rows.is_empty():
				_encounters.append({"monsters": rows, "text": e.text})
	if _encounters.is_empty():
		var cha := DaxFile.open(game_path.path_join("MON%dCHA.DAX" % mon_file))
		var ids: Array = cha.ids() if cha else []
		ids.sort()
		for id in ids:
			_encounters.append({"monsters": [[id, 6, id]], "text": ""})
	_enc_index = 0
	_distance = Placement.encounter_distance(_field, px, py, facing)
	_combat = null
	_result = 0
	_event_fight = false
	_messages.clear()
	if _picture == null:
		_build()
	_load_monsters()
	visible = true


## A fight started by an event script: the real party against `rows` ([[id, count,
## picture], ...]) from MON<mon_file>, `max_distance` and `advances` from the script's
## SPRITE_START / SPRITE_ADVANCE. Emits `finished` when it is over.
func open_event(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, rows: Array, max_distance: int, advances: int,
		morale_base: int = 99, surprise: int = 0) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null)
	_event_fight = true
	_morale_base = morale_base
	_surprise = surprise
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	var open_ahead := Placement.encounter_distance(_field, px, py, facing, 2)
	_distance = maxi(mini(open_ahead, max_distance) - advances, 0)
	_load_monsters()
	_start_fight(0, false)
	_advance()


## Testing aid: a battle with given monsters ([[id, count, picture], ...]) and distance;
## writes the whole battlefield with everyone on it to `image_path` and prints each
## combatant's cell. Used by the lab to compare with the original.
func run_check(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, rows: Array, distance: int, image_path: String) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null)
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	_load_monsters()
	if distance >= 0:
		_distance = distance
		_load_monsters()
	for e in _combatants:
		print("%s %s %d %d  move %d morale 0x%02X int %d classes 0x%02X size 0x%02X att2 %d weapon %s" % ["party" if e.team == 0 else "monster",
			e.who.name, e.cell.x, e.cell.y, e.who.movement, e.who.morale,
			e.who.stats[1] if e.who.stats.size() > 1 else 0, e.who.class_flags, e.who.size, e.who.half_attacks_2,
			e.who.weapon.name if e.who.weapon else "-"])
	if image_path != "":
		var full := Image.create_empty(Battlefield.WIDTH * CELL, Battlefield.HEIGHT * CELL, false, Image.FORMAT_RGBA8)
		full.fill(Color8(85, 85, 85))
		for y in Battlefield.HEIGHT:
			for x in Battlefield.WIDTH:
				var ti := _art.tile(_field.tile(x, y))
				if ti:
					full.blit_rect(ti, Rect2i(0, 0, CELL, CELL), Vector2i(x * CELL, y * CELL))
		for e in _combatants:
			var icon: Image = e.icon
			if icon:
				var src := icon
				if Placement.DX[e.dir] < 0:
					src = icon.duplicate() as Image
					src.flip_x()
				full.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), e.cell * CELL)
		full.save_png(image_path)


## Thrown weapons left lying on the field (found with the treasure after a win).
func dropped_items() -> Array[GameItem]:
	return _combat.dropped if _combat != null else _last_dropped


## Testing aid: the encounter's morale for the next fight.
func set_morale_base(value: int) -> void:
	_morale_base = value


## The monsters brought down in the fight just finished (for experience and treasure).
## Rounds fought (a minute of game time each).
func rounds() -> int:
	return _combat.round_no if _combat != null else 0


func defeated() -> Array:
	var out := []
	for c in _combatants:
		if c.team == 1 and c.get("down", false) and not c.get("fled", false):
			out.append(c.who)
	return out


## Testing aid: fights the check battle to the end with the computer on both sides and the
## given dice seed, printing every roll and message (for the lab).
## `plan` "away" replays the lab's free-attack check: party members wait until a monster
## attacks them, then the attacked one steps straight back (away from the monsters).
func run_fight(seed_value: int, plan: String = "") -> void:
	_start_fight(seed_value)
	for c in _combat.combatants:
		c.quick = c.team == 1 or plan == ""
	var attacked := {}
	_combat.message.connect(func(t: String) -> void:
		for c in _combat.combatants:
			if c.team == 0 and t.contains(" ATTACKS %s" % c.who.name):
				attacked[c.who.name] = true)
	var guard := 0
	var stop := false
	while not stop and _combat.next_turn() >= 0 and guard < 5000:
		guard += 1
		var c: Dictionary = _combatants[_combat.active]
		if plan == "cast" and c.team == 0 and _combat.magic != null:
			# Lab check: each caster casts its first combat spell at the nearest enemy (or
			# itself), then fights on Quick.
			var list := _combat.magic.castable(_combat.active)
			if not list.is_empty():
				var id: int = list[0]
				var best := -1
				for j in _combatants.size():
					if _combatants[j].team != 0 and not _combatants[j].down and (best < 0 or
							_combat.range_of(c, _combatants[j]) < _combat.range_of(c, _combatants[best])):
						best = j
				var picks: Array[int] = [best if _combat.magic.table.field(id, 14) != 0 else _combat.active]
				var at: Vector2i = _combatants[picks[0]].cell
				print("== %s casts %s at %s (%s)" % [c.who.name, _combat.magic.table.name_of(id), at,
					_combat.magic.why_not(_combat.active, id, at)])
				if _combat.magic.why_not(_combat.active, id, at) == "":
					_combat.magic.cast(_combat.active, id, at, picks)
					continue
			c.quick = true
		if c.quick:
			while _combat.ai_act():
				guard += 1
			continue
		if attacked.has(c.who.name):
			var back: int = (Placement.FACING_TO_DIR[_facing] + 4) % 8
			print("== ", c.who.name, " steps away")
			for k in 3:
				var what := _combat.step(back)
				print("step: ", what, " at ", c.cell)
				if what != "moved":
					for y in range(c.cell.y - 2, c.cell.y + 3):
						var row := ""
						for x in range(c.cell.x - 3, c.cell.x + 4):
							row += "%3d" % _field.tile(x, y)
						print(row)
					break
			stop = true
		else:
			_combat.done()
	for line in _combat.roll_log:
		print("roll ", line)
	print("result ", ["", "party won", "party lost"][_combat.outcome()], " after ", _combat.round_no, " rounds")
	_combat.finish()
	for m in _party:
		print("  %s %s HP %d" % [m.name, m.status_name(), m.hp])
	if _combat.outcome() == 1:
		var sp := Spoils.gather(defeated(), [], [])
		var standing := []
		for m in _party:
			if m.can_fight():
				standing.append(m)
		var before := {}
		for m in _party:
			before[m.name] = m.experience
		var share := sp.award(standing)
		var names := PackedStringArray()
		for it in sp.items:
			names.append(it.name)
		print("spoils: experience %d, %d standing, %d each; money %s; items %s" % [
			sp.experience, standing.size(), share, sp.money, ", ".join(names)])
		for m in _party:
			print("  %s %d -> %d" % [m.name, before[m.name], m.experience])


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color8(85, 85, 85)
	ShopScreen._fill(bg, 0)
	add_child(bg)
	_picture = TextureRect.new()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.position = Vector2(24, 24)
	_picture.size = Vector2(VIEW_CELLS * CELL * SCALE, VIEW_CELLS * CELL * SCALE)
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_picture)
	_info = Label.new()
	_info.position = Vector2(VIEW_CELLS * CELL * SCALE + 64, 24)
	_info.size = Vector2(600, 500)
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_color", Color8(85, 255, 85))
	add_child(_info)
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_ai_step)
	add_child(_ai_timer)
	_prompt = Label.new()
	_prompt.position = Vector2(24, VIEW_CELLS * CELL * SCALE + 40)
	_prompt.size = Vector2(1200, 120)
	_prompt.add_theme_font_size_override("font_size", 18)
	add_child(_prompt)


func _load_monsters() -> void:
	_monsters.clear()
	_pictures.clear()
	if not _encounters.is_empty():
		for row in _encounters[_enc_index].monsters:
			var first := PartyMember.load_monster(_game_path, _mon_file, row[0])
			if first == null:
				continue
			first.recalculate(_types)
			for i in int(row[1]):
				if _monsters.size() >= 63:   # the original's limit
					break
				var m := first if i == 0 else first.clone()
				if i > 0:
					m.recalculate(_types)
				_monsters.append(m)
				_pictures.append(int(row[2]))
	_place()
	_selected = 0
	_centre_on_selected()
	_refresh()


# --- Placement --------------------------------------------------------------------------

## Both sides placed by the original's rule (see Placement): the party around its own
## square, the monsters around the square `_distance` squares ahead, facing the party.
func _place() -> void:
	_combatants.clear()
	var placer := Placement.new(_field, _px, _py)
	var party_sizes := _party.map(func(m): return Combat.foot_size(m))
	var party_cells := placer.place_team(_party.size(), _facing, Vector2i.ZERO, true, party_sizes)
	var party_dir: int = Placement.FACING_TO_DIR[_facing]
	for i in _party.size():
		if party_cells[i].x < 0:
			continue
		_combatants.append({"who": _party[i], "team": 0, "cell": party_cells[i],
			"icon": _art.character_icon(_party[i]), "dir": party_dir})
	var ahead: Vector2i = Placement.SQUARE_STEP[_facing] * _distance
	var mon_sizes := _monsters.map(func(m): return Combat.foot_size(m))
	var mon_cells := placer.place_team(_monsters.size(), (_facing + 2) % 4, ahead, false, mon_sizes)
	for i in _monsters.size():
		if mon_cells[i].x < 0:
			continue
		_combatants.append({"who": _monsters[i], "team": 1, "cell": mon_cells[i],
			"icon": _art.monster_icon(_mon_file, _pictures[i]), "dir": (party_dir + 4) % 8})


# --- Fighting ---------------------------------------------------------------------------

func _start_fight(seed_value: int = 0, copy_party: bool = true) -> void:
	if copy_party:
		# Test fights use copies of the party, so nobody gets hurt for real.
		var copies: Array[PartyMember] = []
		for m in _party:
			var c := m.clone()
			c.recalculate(_types)
			copies.append(c)
		_party = copies
	# Characters who are down don't take part.
	var standing: Array[PartyMember] = []
	for m in _party:
		if m.can_fight():
			standing.append(m)
	_party = standing
	_place()
	_combat = Combat.new(_field, _combatants, seed_value)
	_combat.types = _types
	var table := SpellTable.shared(_game_path)
	if table.is_loaded():
		_combat.magic = CombatSpells.new(_combat, table)
	_combat.flee_dir = Placement.FACING_TO_DIR[_facing]
	_combat.morale_base = _morale_base
	_combat.surprise_flags = _surprise
	_combat.message.connect(_on_message)
	_messages.clear()
	_result = 0


func _on_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 6:
		_messages = _messages.slice(_messages.size() - 6)
	print(text)


## Moves on to whoever acts next; computer-controlled turns play out on a timer.
func _advance() -> void:
	var i := _combat.next_turn()
	if i < 0:
		_result = _combat.outcome()
		_combat.finish()
		_on_message("THE PARTY WINS." if _result == 1 else "THE PARTY HAS FALLEN.")
		_refresh()
		if _event_fight and _result == 1:
			# Straight on to the results (the original's "Continue Battle?" is skipped).
			await get_tree().create_timer(1.0).timeout
			if visible and _event_fight and _result == 1:
				_leave()
		return
	_selected = i
	_centre_on_selected()
	_refresh()
	if _combatants[i].quick:
		_ai_timer.start(0.35)


func _ai_step() -> void:
	if _combat == null or not visible:
		return
	var more := _combat.ai_act()
	_centre_on_selected()
	_refresh()
	if more:
		_ai_timer.start(0.3)
	else:
		await get_tree().create_timer(0.2).timeout
		if _combat != null:
			_advance()


func _after_player_action(what: String) -> void:
	if what == "blocked":
		_on_message("CAN'T GO THERE")
	elif what == "no moves":
		_on_message("NO MOVES LEFT")
	elif what == "fell":
		if _combatants[_selected].team == 0:
			_on_message("YOUR TEAMMATE IS DOWN")
	var c: Dictionary = _combatants[_selected]
	if _combat.outcome() != 0 or (c.moves <= 0 and c.attacks <= 0) or (what == "attacked" and c.attacks <= 0):
		_advance()
	else:
		_centre_on_selected()
		_refresh()


# --- AIM ---------------------------------------------------------------------------------
# The original's AIM: NEXT / PREV step through the figures nearest first, showing each
# one's sheet and "RANGE = n"; TARGET (offered only when the shot is allowed) attacks it.
# Modern controls: A aims, ←/→ or Tab change target, Enter attacks, Esc goes back.

func _start_aim() -> void:
	var me: int = _combat.active
	_aim_list = []
	for j in _combatants.size():
		if j != me and not _combatants[j].get("down", false) and _combatants[j].team != _combatants[me].team:
			_aim_list.append(j)
	if _aim_list.is_empty():
		_on_message("NO TARGETS")
		_refresh()
		return
	_aim_list.sort_custom(func(a, b): return _combat.range_of(_combatants[me], _combatants[a]) \
		< _combat.range_of(_combatants[me], _combatants[b]))
	_aiming = true
	_aim_index = 0
	_show_aim()


func _show_aim() -> void:
	_selected = _aim_list[_aim_index]
	_centre_on_selected()
	_refresh()


func _aim_why(j: int) -> String:
	var me: int = _combat.active
	var m: PartyMember = _combatants[me].who
	if m.weapon_ranged:
		var why := _combat.why_not_shoot(me, j)
		if why == "" or (m.weapon_ranged_melee and _combat.touching(_combatants[me], _combatants[j])):
			return ""
		return why
	if not _combat.touching(_combatants[me], _combatants[j]):
		return "OUT OF RANGE"
	return "" if _combatants[me].attacks > 0 else "NO ATTACKS LEFT"


func _aim_input(event: InputEvent, key: Key) -> void:
	if event.is_action("ui_cancel"):
		_aiming = false
		_selected = _combat.active
		_centre_on_selected()
		_refresh()
	elif event.is_action("ui_right") or key == KEY_TAB or key == KEY_N:
		_aim_index = (_aim_index + 1) % _aim_list.size()
		_show_aim()
	elif event.is_action("ui_left") or key == KEY_P:
		_aim_index = (_aim_index + _aim_list.size() - 1) % _aim_list.size()
		_show_aim()
	elif event.is_action("ui_accept") or key == KEY_T:
		var j: int = _aim_list[_aim_index]
		var why := _aim_why(j)
		if why != "":
			_on_message(why)
			_refresh()
			return
		_aiming = false
		_selected = _combat.active
		var me: int = _combat.active
		if (_combatants[me].who as PartyMember).weapon_ranged:
			_combat.shoot(me, j)
		else:
			_combat.attack(me, j)
		_after_player_action("attacked")


# --- CAST ---------------------------------------------------------------------------------
# The original's CAST: the caster's memorized spells, then (for a spell that isn't on the
# caster alone) the aim, with "ABORT SPELL?" on leaving. QoL: the cells an area spell will
# cover are shaded while aiming. Modern controls: C casts, ↑/↓ choose the spell, Enter
# picks it; arrows move the aim, Tab jumps to the next figure, Enter casts (or picks a
# figure, D when done picking), Esc aborts and the spell is kept.

func _start_cast() -> void:
	if _combat.magic == null:
		return
	_spell_list = _combat.magic.castable(_combat.active)
	if _spell_list.is_empty():
		_on_message("NO SPELLS MEMORIZED")
		_refresh()
		return
	_casting = "choose"
	_spell_index = 0
	_refresh()


func _cast_input(event: InputEvent, key: Key) -> void:
	var me: int = _combat.active
	if _casting == "choose":
		if event.is_action("ui_cancel"):
			_casting = ""
		elif event.is_action("ui_up") or event.is_action("ui_left"):
			_spell_index = (_spell_index + _spell_list.size() - 1) % _spell_list.size()
		elif event.is_action("ui_down") or event.is_action("ui_right"):
			_spell_index = (_spell_index + 1) % _spell_list.size()
		elif event.is_action("ui_accept"):
			_spell_id = _spell_list[_spell_index]
			_spell_picks = []
			if _combat.magic.aim_kind(_spell_id) == "self":
				_finish_cast()
				return
			_casting = "aim"
			_spell_cell = _combatants[me].cell
			_aim_next_figure()
		_refresh()
		return
	var moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0),
		KEY_RIGHT: Vector2i(1, 0), KEY_HOME: Vector2i(-1, -1), KEY_PAGEUP: Vector2i(1, -1),
		KEY_END: Vector2i(-1, 1), KEY_PAGEDOWN: Vector2i(1, 1)}
	if event.is_action("ui_cancel"):
		_casting = ""
		_selected = me
	elif moves.has(key):
		_spell_cell += moves[key]
		_view = _spell_cell - Vector2i(3, 3)
	elif key == KEY_TAB:
		_aim_next_figure()
	elif key == KEY_D and not _spell_picks.is_empty():
		_finish_cast()
		return
	elif event.is_action("ui_accept"):
		var why := _combat.magic.why_not(me, _spell_id, _spell_cell)
		if why != "":
			_on_message(why)
		elif _combat.magic.aim_kind(_spell_id) == "area":
			_finish_cast()
			return
		else:
			var who := _combat.occupant(_spell_cell)
			if who < 0:
				_on_message("NO TARGET THERE")
			elif who in _spell_picks:
				_on_message("ALREADY BEEN TARGETED")
			else:
				_spell_picks.append(who)
				if _spell_picks.size() >= _combat.magic.max_picks(_spell_id):
					_finish_cast()
					return
	_refresh()


## Moves the aim to the next standing figure (nearest first), enemies before friends for
## spells meant for enemies.
func _aim_next_figure() -> void:
	var me: int = _combat.active
	var offensive := _combat.magic.table.field(_spell_id, 14) != 0
	var list: Array[int] = []
	for j in _combatants.size():
		if not _combatants[j].get("down", false):
			list.append(j)
	list.sort_custom(func(a, b):
		var fa: int = 0 if (_combatants[a].team != _combatants[me].team) == offensive else 1
		var fb: int = 0 if (_combatants[b].team != _combatants[me].team) == offensive else 1
		if fa != fb:
			return fa < fb
		return _combat.range_of(_combatants[me], _combatants[a]) < _combat.range_of(_combatants[me], _combatants[b]))
	if list.is_empty():
		return
	var at := _combat.occupant(_spell_cell)
	var k := list.find(at)
	var next: int = list[(k + 1) % list.size()] if k >= 0 else list[0]
	_spell_cell = _combatants[next].cell
	_selected = next
	_centre_on_selected()


func _finish_cast() -> void:
	var me: int = _combat.active
	_casting = ""
	_selected = me
	_combat.magic.cast(me, _spell_id, _spell_cell, _spell_picks)
	_refresh()
	_advance()


# --- Drawing ----------------------------------------------------------------------------

func _centre_on_selected() -> void:
	if _combatants.is_empty():
		return
	var c: Vector2i = _combatants[_selected].cell
	_view = c - Vector2i(3, 3)


var _tint: Image = null


func _refresh() -> void:
	if _tint == null:
		_tint = Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		_tint.fill(Color(1.0, 0.45, 0.1, 0.45))
	var size := VIEW_CELLS * CELL
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color8(85, 85, 85))
	for r in VIEW_CELLS:
		for c in VIEW_CELLS:
			var t := _field.tile(_view.x + c, _view.y + r)
			var ti := _art.tile(t)
			if ti:
				img.blit_rect(ti, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
	# Casting: the aim cursor and (QoL) the cells the spell will cover.
	if _casting == "aim":
		var cells: Array[Vector2i] = []
		if _combat.magic.aim_kind(_spell_id) == "area":
			cells = _combat.magic.area_cells(_combat.active, _spell_id, _spell_cell)
		for p in cells:
			var at := (p - _view) * CELL
			if at.x >= 0 and at.y >= 0 and at.x < size and at.y < size:
				img.blend_rect(_tint, Rect2i(0, 0, CELL, CELL), at)
		var cur := (_spell_cell - _view) * CELL
		if cur.x >= 0 and cur.y >= 0 and cur.x < size and cur.y < size:
			for k in CELL:
				for edge in [Vector2i(k, 0), Vector2i(k, CELL - 1), Vector2i(0, k), Vector2i(CELL - 1, k)]:
					img.set_pixelv(cur + edge, Color8(255, 255, 85))
	# The art faces right; combatants facing a westward direction are drawn mirrored.
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		if e.get("down", false):
			continue
		var icon: Image = e.icon
		var at: Vector2i = (e.cell - _view) * CELL
		if i == _selected:
			var box := Rect2i(at, Vector2i(CELL, CELL))
			img.fill_rect(box, Color8(170, 170, 170))
		if icon:
			var src := icon
			if Placement.DX[e.dir] < 0:
				src = icon.duplicate() as Image
				src.flip_x()
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	_picture.texture = ImageTexture.create_from_image(img)
	if _combatants.is_empty():
		_info.text = ""
	else:
		var e: Dictionary = _combatants[_selected]
		var m: PartyMember = e.who
		var weapon := m.weapon.name if m.weapon else ""
		_info.text = "%s\n\nHITPOINTS %d\n\nAC %d\n\n%s" % [m.name, m.hp, m.ac, weapon]
		if _combat != null:
			_info.text += "\n\nMOVES %d  ATTACKS %d\n\n%s" % [e.moves / 2, e.attacks, "\n".join(_messages)]
	if _combat != null:
		if _result != 0:
			_prompt.text = ("THE PARTY WINS." if _result == 1 else "THE PARTY HAS FALLEN.") + "   Esc or Enter: leave"
		elif _casting == "choose":
			var names := PackedStringArray()
			for k in _spell_list.size():
				names.append(("[%s]" if k == _spell_index else "%s") % _combat.magic.table.name_of(_spell_list[k]))
			_prompt.text = "CAST: %s\n↑/↓ choose   Enter cast   Esc back" % "  ".join(names)
		elif _casting == "aim":
			var why := _combat.magic.why_not(_combat.active, _spell_id, _spell_cell)
			var kind := _combat.magic.aim_kind(_spell_id)
			_prompt.text = "%s: %s   Arrows: aim   Tab: next figure   %s%sEsc: abort" % [
				_combat.magic.table.name_of(_spell_id), why if why != "" else "RANGE %d" % _combat.magic.spell_range(_combat.active, _spell_id),
				"Enter: cast   " if why == "" else "",
				("D: done (%d of %d picked)   " % [_spell_picks.size(), _combat.magic.max_picks(_spell_id)]) if kind == "pick" else ""]
		elif _aiming:
			var j: int = _aim_list[_aim_index]
			var why := _aim_why(j)
			_prompt.text = "AIM: RANGE = %d   %s   ←/→ next/prev   %sEsc: back" % [
				_combat.range_of(_combatants[_combat.active], _combatants[j]),
				why if why != "" else "", "Enter: target   " if why == "" else ""]
		else:
			_prompt.text = ("ROUND %d   Arrows / Home PgUp End PgDn: move or attack   Space: done   "
				+ "A: aim   C: cast   G: guard   B: bandage   Q: quick   Esc: leave") % _combat.round_no
		return
	var summary := PackedStringArray()
	var text := ""
	if not _encounters.is_empty():
		var e: Dictionary = _encounters[_enc_index]
		text = e.text
		for row in e.monsters:
			var n := "?"
			for i in _monsters.size():
				if _pictures[i] == row[2]:
					n = _monsters[i].name
					break
			summary.append("%s x%d" % [n, row[1]])
	_prompt.text = ("Battle %d of %d: %s   (%d square(s) away)\n%s\n"
		+ "Arrows: move view   Tab: next combatant   PgUp/PgDn: battle   +/-: distance   F: fight   Esc: leave") % [
		_enc_index + 1, _encounters.size(), ", ".join(summary), _distance, text]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _aiming:
		_aim_input(event, key)
		get_viewport().set_input_as_handled()
		return
	if _casting != "":
		_cast_input(event, key)
		get_viewport().set_input_as_handled()
		return
	if _event_fight and _result == 0 and _combat != null:
		_fight_input(event, key)
		return
	if event.is_action("ui_cancel") or (_result != 0 and event.is_action("ui_accept")):
		_leave()
	elif _combat != null:
		_fight_input(event, key)
		return
	elif key == KEY_F:
		_start_fight()
		_advance()
	elif event.is_action("ui_left"):
		_view.x -= 1
	elif event.is_action("ui_right"):
		_view.x += 1
	elif event.is_action("ui_up"):
		_view.y -= 1
	elif event.is_action("ui_down"):
		_view.y += 1
	elif key == KEY_TAB:
		if not _combatants.is_empty():
			_selected = (_selected + 1) % _combatants.size()
			_centre_on_selected()
	elif key == KEY_PAGEDOWN or key == KEY_PAGEUP:
		if not _encounters.is_empty():
			var step := 1 if key == KEY_PAGEDOWN else -1
			_enc_index = (_enc_index + step + _encounters.size()) % _encounters.size()
			_load_monsters()
	elif key == KEY_EQUAL or key == KEY_KP_ADD:
		_distance = mini(_distance + 1, 2)
		_load_monsters()
	elif key == KEY_MINUS or key == KEY_KP_SUBTRACT:
		_distance = maxi(_distance - 1, 0)
		_load_monsters()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh()


func _leave() -> void:
	_ai_timer.stop()
	var was_event := _event_fight
	var result := _result
	_last_dropped = _combat.dropped if _combat != null else ([] as Array[GameItem])
	_combat = null
	_event_fight = false
	visible = false
	if was_event:
		finished.emit(result)
	else:
		closed.emit()


const _STEP_KEYS := {KEY_UP: 0, KEY_KP_8: 0, KEY_PAGEUP: 1, KEY_KP_9: 1, KEY_RIGHT: 2, KEY_KP_6: 2,
	KEY_PAGEDOWN: 3, KEY_KP_3: 3, KEY_DOWN: 4, KEY_KP_2: 4, KEY_END: 5, KEY_KP_1: 5,
	KEY_LEFT: 6, KEY_KP_4: 6, KEY_HOME: 7, KEY_KP_7: 7}


func _fight_input(event: InputEvent, key: Key) -> void:
	get_viewport().set_input_as_handled()
	if _result != 0 or _combat.active < 0 or _combatants[_combat.active].quick:
		return
	if _STEP_KEYS.has(key):
		_after_player_action(_combat.step(_STEP_KEYS[key]))
	elif key == KEY_SPACE or key == KEY_D:
		_combat.done()
		_advance()
	elif key == KEY_A:
		_start_aim()
	elif key == KEY_C:
		_start_cast()
	elif key == KEY_G:
		if _combat.can_guard():
			_combat.guard(_combat.active, false)
			_refresh()
			_advance()
		else:
			_on_message("CAN'T GUARD WITH A MISSILE WEAPON")
			_refresh()
	elif key == KEY_B:
		if _combat.bandage():
			_refresh()
			_advance()
		else:
			_on_message("NOBODY NEEDS BANDAGING")
			_refresh()
	elif key == KEY_Q:
		_combatants[_combat.active].quick = true
		_ai_timer.start(0.2)
